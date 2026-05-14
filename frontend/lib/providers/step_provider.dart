import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:omniconnect_fitness/models/step_models.dart';
import 'package:omniconnect_fitness/services/step_service.dart';
import 'package:omniconnect_fitness/services/health_connect_service.dart';

enum StepProviderState {
  idle,
  loading,
  ready,
  permissionDenied,
  sensorUnavailable,
}

/// Provider de contagem de passos.
///
/// Fonte primária: Health Connect (Android API 28+) / HealthKit (iOS).
/// Fallback: pedômetro via sensor físico (pedometer package).
class StepProvider extends ChangeNotifier {
  final StepService _stepService;
  final HealthConnectService _hcService;

  StepProvider({
    required StepService stepService,
    HealthConnectService? healthConnectService,
  })  : _stepService = stepService,
        _hcService = healthConnectService ?? HealthConnectService();

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

  int? _selectedHandicapLevel;
  int? get selectedHandicapLevel => _selectedHandicapLevel;

  bool _usingHealthConnect = false;
  /// Indica se a contagem está vindo do Health Connect (true) ou pedômetro (false).
  bool get usingHealthConnect => _usingHealthConnect;

  bool _isStepsFromSmartwatch = false;
  /// True quando os passos foram contados por um smartwatch/fitness tracker.
  bool get isStepsFromSmartwatch => _isStepsFromSmartwatch;

  String _stepsSourceName = '';
  /// Nome legível da fonte dos passos (ex: "Garmin Connect", "Samsung Health").
  String get stepsSourceName => _stepsSourceName;

  // Getters derivados do histórico
  int get dailyGoal => _history.dailyGoal;
  int get currentStreak => _history.currentStreak;
  int get allTimeRecord => _history.allTimeRecord;

  double get caloriesToday {
    if (_history.totalCaloriesToday > 0) return _history.totalCaloriesToday;
    return double.parse((_stepsToday * 0.04).toStringAsFixed(1));
  }

  // Internos
  String? _userId;
  double _strideMeters = 0.75;
  StreamSubscription<StepCount>? _stepSub;
  Timer? _syncTimer;
  Timer? _hcPollTimer;
  DateTime _currentDay = _today();

  static const String _baselineKeyPrefix = 'steps_baseline_';
  static const String _stepsTodayKeyPrefix = 'steps_today_';
  static const String _handicapKeyPrefix = 'steps_handicap_';
  static const Duration _syncInterval = Duration(minutes: 15);

  /// Inicializa o provider com o usuário autenticado e seus dados antropométricos.
  Future<void> initialize({
    required String userId,
    double? heightCm,
    String? gender,
  }) async {
    _userId = userId;
    _strideMeters = _computeStride(heightCm: heightCm, gender: gender);

    _state = StepProviderState.loading;
    notifyListeners();

    await _loadCachedHandicap();
    await _loadCachedTodaySteps();
    await refreshHistory();

    final hcAvailable = await _hcService.isAvailable();
    if (hcAvailable) {
      final granted = await _hcService.requestPermissions();
      // requestAuthorization pode retornar false em relançamentos mesmo com
      // permissões já concedidas — verificar hasPermissions() como fallback.
      final hasPerms = granted || await _hcService.hasPermissions();
      if (hasPerms) {
        _usingHealthConnect = true;
        await _readFromHealthConnect();
        _startHealthConnectPolling();
      } else {
        await _startPedometer();
      }
    } else {
      await _startPedometer();
    }

    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(_syncInterval, (_) => syncToBackend());

    _state = StepProviderState.ready;
    notifyListeners();
  }

  /// Lê passos do Health Connect para o dia atual, incluindo fonte.
  Future<void> _readFromHealthConnect() async {
    final start = DateTime(_currentDay.year, _currentDay.month, _currentDay.day);
    final end = DateTime.now();
    final result = await _hcService.readStepsWithSource(start, end);
    if (result.steps > _stepsToday) {
      _stepsToday = result.steps;
      _distanceTodayMeters = result.steps * _strideMeters;
      await _persistTodaySteps();
    }
    _isStepsFromSmartwatch = result.isFromSmartwatch;
    _stepsSourceName = result.sourceName;
    notifyListeners();
  }

  void _startHealthConnectPolling() {
    _hcPollTimer?.cancel();
    // Polling a cada 5 minutos para atualizar passos do Health Connect
    _hcPollTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      final today = _today();
      if (!_isSameDay(today, _currentDay)) {
        await syncToBackend();
        _currentDay = today;
        _stepsToday = 0;
        _distanceTodayMeters = 0;
        _selectedHandicapLevel = null;
      }
      await _readFromHealthConnect();
    });
  }

  Future<void> _startPedometer() async {
    final granted = await _ensurePedometerPermission();
    if (!granted) {
      _state = StepProviderState.permissionDenied;
      _error = 'Permissão para acessar o sensor de passos foi negada.';
      notifyListeners();
      return;
    }
    _subscribeToSensor();
  }

  /// Atualiza o histórico (puxa do backend).
  Future<void> refreshHistory() async {
    try {
      _history = await _stepService.getMyHistory();
      notifyListeners();
    } catch (e) {
      _error = 'Erro ao carregar histórico: $e';
      notifyListeners();
    }
  }

  /// Define o nível de handicap para o dia atual e sincroniza.
  Future<void> setHandicapLevel(int? level) async {
    _selectedHandicapLevel = level;
    final prefs = await SharedPreferences.getInstance();
    final key = _handicapKey(_currentDay);
    if (level == null) {
      await prefs.remove(key);
    } else {
      await prefs.setInt(key, level);
    }
    notifyListeners();
    await syncToBackend();
  }

  /// Atualiza a meta diária de passos e sincroniza com o backend.
  Future<void> setGoal(int goal) async {
    try {
      await _stepService.updateMyGoal(goal);
      _history = StepHistory(
        logs: _history.logs,
        allTimeRecord: _history.allTimeRecord,
        currentWeekTotal: _history.currentWeekTotal,
        currentStreak: _history.currentStreak,
        dailyGoal: goal,
        totalCaloriesToday: _history.totalCaloriesToday,
      );
      notifyListeners();
    } catch (e) {
      _error = 'Erro ao atualizar meta: $e';
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
        handicapLevel: _selectedHandicapLevel,
      );
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
        allTimeRecord: _history.allTimeRecord,
        currentWeekTotal: _history.currentWeekTotal,
        currentStreak: _history.currentStreak,
        dailyGoal: _history.dailyGoal,
        totalCaloriesToday: updated.caloriesBurned,
      );
      unawaited(refreshHistory());
    } catch (e) {
      _error = 'Erro ao sincronizar passos: $e';
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Chamado quando o app vai pra background.
  Future<void> onAppPaused() async {
    await syncToBackend();
  }

  double _computeStride({double? heightCm, String? gender}) {
    if (heightCm == null || heightCm <= 0) return 0.75;
    final factor =
        (gender?.toLowerCase().startsWith('f') ?? false) ? 0.413 : 0.415;
    return (heightCm / 100.0) * factor;
  }

  Future<bool> _ensurePedometerPermission() async {
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
    if (!_isSameDay(today, _currentDay)) {
      await syncToBackend();
      _currentDay = today;
      _stepsToday = 0;
      _distanceTodayMeters = 0;
      _selectedHandicapLevel = null;
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

  String _baselineKey(DateTime day) =>
      '$_baselineKeyPrefix${_userId ?? "anon"}_${_formatDate(day)}';

  String _stepsTodayKey(DateTime day) =>
      '$_stepsTodayKeyPrefix${_userId ?? "anon"}_${_formatDate(day)}';

  String _handicapKey(DateTime day) =>
      '$_handicapKeyPrefix${_userId ?? "anon"}_${_formatDate(day)}';

  Future<int> _getOrCreateBaseline(
      int currentSensorValue, DateTime day) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _baselineKey(day);
    final stored = prefs.getInt(key);
    if (stored != null) {
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

  Future<void> _loadCachedHandicap() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getInt(_handicapKey(_currentDay));
    _selectedHandicapLevel = stored;
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
    _hcPollTimer?.cancel();
    super.dispose();
  }
}
