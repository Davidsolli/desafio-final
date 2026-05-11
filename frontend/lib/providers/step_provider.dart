import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:omniconnect_fitness/models/step_models.dart';
import 'package:omniconnect_fitness/services/step_service.dart';

enum StepProviderState {
  idle,
  loading,
  ready,
  permissionDenied,
  sensorUnavailable,
}

/// Meta padrão de passos por dia (usada na barra de progresso da home).
const int kDailyStepGoal = 10000;

/// Provider que conecta o sensor nativo de passos do dispositivo,
/// mantém o total do dia em memória e sincroniza com o backend.
///
/// Lógica do baseline:
///   `Pedometer.stepCountStream` retorna o total acumulado desde o último
///   reboot do dispositivo. Para descobrir os passos do dia, guardamos um
///   "baseline" na primeira leitura do dia em `SharedPreferences`. Os passos
///   do dia = leitura atual - baseline.
class StepProvider extends ChangeNotifier {
  final StepService _stepService;

  StepProvider({required StepService stepService}) : _stepService = stepService;

  // Estado público
  StepProviderState _state = StepProviderState.idle;
  StepProviderState get state => _state;

  int _stepsToday = 0;
  int get stepsToday => _stepsToday;

  double _distanceTodayMeters = 0;
  double get distanceTodayMeters => _distanceTodayMeters;
  double get distanceTodayKm => _distanceTodayMeters / 1000.0;

  StepHistory _history = StepHistory.empty();
  StepHistory get history => _history;

  String? _error;
  String? get error => _error;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  // Internos
  String? _userId;
  double _strideMeters = 0.75; // fallback (homem ~1.80m)
  StreamSubscription<StepCount>? _stepSub;
  Timer? _syncTimer;
  DateTime _currentDay = _today();

  static const String _baselineKeyPrefix = 'steps_baseline_';
  static const String _stepsTodayKeyPrefix = 'steps_today_';
  static const Duration _syncInterval = Duration(minutes: 15);

  /// Inicializa o provider com o usuário autenticado e seus dados antropométricos.
  /// `heightCm` e `gender` são opcionais e usados para refinar o stride.
  Future<void> initialize({
    required String userId,
    double? heightCm,
    String? gender,
  }) async {
    _userId = userId;
    _strideMeters = _computeStride(heightCm: heightCm, gender: gender);

    _state = StepProviderState.loading;
    notifyListeners();

    // 1. Pedir permissão (Android 10+ e iOS)
    final granted = await _ensurePermission();
    if (!granted) {
      _state = StepProviderState.permissionDenied;
      _error = 'Permissão para acessar o sensor de passos foi negada.';
      notifyListeners();
      return;
    }

    // 2. Carregar último valor armazenado para a UI já mostrar algo enquanto o
    //    sensor não emite o primeiro evento.
    await _loadCachedTodaySteps();

    // 3. Buscar histórico do backend (independe do sensor)
    await refreshHistory();

    // 4. Conectar ao stream do sensor
    _subscribeToSensor();

    // 5. Iniciar sync periódico
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(_syncInterval, (_) => syncToBackend());

    _state = StepProviderState.ready;
    notifyListeners();
  }

  /// Atualiza o histórico (puxa do backend).
  Future<void> refreshHistory() async {
    try {
      _history = await _stepService.getMyHistory();
      notifyListeners();
    } catch (e) {
      // Histórico vazio é aceitável; mantém estado atual.
      _error = 'Erro ao carregar histórico: $e';
      notifyListeners();
    }
  }

  /// Envia os passos atuais do dia para o backend.
  Future<void> syncToBackend() async {
    if (_userId == null || _isSyncing) return;
    if (_stepsToday <= 0) return;

    _isSyncing = true;
    notifyListeners();
    try {
      final updated = await _stepService.syncSteps(
        date: _currentDay,
        steps: _stepsToday,
        distanceMeters: _distanceTodayMeters,
      );
      // Atualiza o histórico em memória com o registro mais recente
      final logs = List<StepLog>.from(_history.logs);
      final idx = logs.indexWhere((l) => _isSameDay(l.date, _currentDay));
      if (idx >= 0) {
        logs[idx] = updated;
      } else {
        logs.add(updated);
      }
      logs.sort((a, b) => a.date.compareTo(b.date));
      _history = StepHistory(
        logs: logs,
        weeklyBest: _history.weeklyBest,
        currentWeekTotal: _history.currentWeekTotal,
        isNewWeekRecord: _history.isNewWeekRecord,
      );
      // Buscar estatísticas atualizadas em segundo plano
      unawaited(refreshHistory());
    } catch (e) {
      _error = 'Erro ao sincronizar passos: $e';
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Chamado quando o app vai pra background — faz uma última sync.
  Future<void> onAppPaused() async {
    await syncToBackend();
  }

  /// Cálculo do stride length em metros.
  /// Fórmula: altura(m) * fator (0.415 homem, 0.413 mulher).
  double _computeStride({double? heightCm, String? gender}) {
    if (heightCm == null || heightCm <= 0) return 0.75;
    final factor = (gender?.toLowerCase().startsWith('f') ?? false)
        ? 0.413
        : 0.415;
    return (heightCm / 100.0) * factor;
  }

  Future<bool> _ensurePermission() async {
    // iOS solicita Motion automaticamente ao acessar o sensor.
    // No Android (10+), precisamos de ACTIVITY_RECOGNITION.
    if (kIsWeb) return false;
    try {
      if (Platform.isAndroid) {
        final status = await Permission.activityRecognition.request();
        return status.isGranted;
      }
      if (Platform.isIOS) {
        final status = await Permission.sensors.request();
        return status.isGranted || status.isLimited;
      }
    } catch (_) {
      return false;
    }
    return true;
  }

  void _subscribeToSensor() {
    try {
      _stepSub?.cancel();
      _stepSub = Pedometer.stepCountStream.listen(
        _handleStepEvent,
        onError: (Object error) {
          _state = StepProviderState.sensorUnavailable;
          _error = 'Sensor de passos indisponível neste dispositivo.';
          notifyListeners();
        },
        cancelOnError: true,
      );
    } catch (_) {
      _state = StepProviderState.sensorUnavailable;
      _error = 'Sensor de passos indisponível neste dispositivo.';
      notifyListeners();
    }
  }

  Future<void> _handleStepEvent(StepCount event) async {
    final today = _today();
    // Detecta virada de dia: zera o contador e cria novo baseline.
    if (!_isSameDay(today, _currentDay)) {
      // Sync final do dia anterior antes de resetar
      await syncToBackend();
      _currentDay = today;
      _stepsToday = 0;
      _distanceTodayMeters = 0;
      await _setBaseline(event.steps, today);
    }

    final baseline = await _getOrCreateBaseline(event.steps, today);
    final raw = event.steps - baseline;
    final steps = raw < 0 ? 0 : raw;

    _stepsToday = steps;
    _distanceTodayMeters = steps * _strideMeters;
    await _persistTodaySteps();

    notifyListeners();
  }

  // --- SharedPreferences helpers ---

  String _baselineKey(DateTime day) {
    final dateStr = _formatDate(day);
    return '$_baselineKeyPrefix${_userId ?? "anon"}_$dateStr';
  }

  String _stepsTodayKey(DateTime day) {
    final dateStr = _formatDate(day);
    return '$_stepsTodayKeyPrefix${_userId ?? "anon"}_$dateStr';
  }

  Future<int> _getOrCreateBaseline(int currentSensorValue, DateTime day) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _baselineKey(day);
    final stored = prefs.getInt(key);
    if (stored != null) {
      // Caso o dispositivo tenha sido reiniciado, o sensor pode retornar valor
      // menor que o baseline. Nesse caso, redefinimos o baseline.
      if (currentSensorValue < stored) {
        await prefs.setInt(key, currentSensorValue);
        return currentSensorValue;
      }
      return stored;
    }
    await prefs.setInt(key, currentSensorValue);
    return currentSensorValue;
  }

  Future<void> _setBaseline(int currentSensorValue, DateTime day) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_baselineKey(day), currentSensorValue);
  }

  Future<void> _persistTodaySteps() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_stepsTodayKey(_currentDay), _stepsToday);
  }

  Future<void> _loadCachedTodaySteps() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getInt(_stepsTodayKey(_currentDay));
    if (cached != null) {
      _stepsToday = cached;
      _distanceTodayMeters = cached * _strideMeters;
      notifyListeners();
    }
  }

  // --- Utils ---

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static String _formatDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  @override
  void dispose() {
    _stepSub?.cancel();
    _syncTimer?.cancel();
    super.dispose();
  }
}
