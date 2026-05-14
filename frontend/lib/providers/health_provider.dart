import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:omniconnect_fitness/services/health_connect_service.dart';
import 'package:omniconnect_fitness/services/health_service.dart';

enum HealthProviderState { idle, loading, ready, unavailable }

/// Provider para frequência cardíaca e calorias via Health Connect / HealthKit.
class HealthProvider extends ChangeNotifier {
  final HealthConnectService _hcService;
  final HealthService _healthService;

  HealthProvider({
    HealthConnectService? healthConnectService,
    required HealthService healthService,
  })  : _hcService = healthConnectService ?? HealthConnectService(),
        _healthService = healthService;

  HealthProviderState _state = HealthProviderState.idle;
  HealthProviderState get state => _state;

  List<HeartRateSample> _heartRateSamples = [];
  List<HeartRateSample> get heartRateSamples => _heartRateSamples;

  DailyCalories _calories = const DailyCalories(active: 0, total: 0);
  DailyCalories get calories => _calories;

  String? _error;
  String? get error => _error;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  Timer? _refreshTimer;
  Timer? _syncTimer;

  static const _syncInterval = Duration(minutes: 15);

  /// BPM médio das amostras do dia.
  double get averageHeartRateBpm {
    if (_heartRateSamples.isEmpty) return 0;
    final sum = _heartRateSamples.fold<int>(0, (acc, s) => acc + s.bpm);
    return sum / _heartRateSamples.length;
  }

  /// BPM máximo (pico) das amostras do dia.
  int get peakHeartRateBpm {
    if (_heartRateSamples.isEmpty) return 0;
    return _heartRateSamples.map((s) => s.bpm).reduce((a, b) => a > b ? a : b);
  }

  /// True se alguma amostra de FC veio de um smartwatch/fitness tracker.
  bool get isFromSmartwatch =>
      _heartRateSamples.any((s) => s.isFromSmartwatch);

  /// Nome da fonte smartwatch mais recente (vazio se não houver).
  String get smartwatchSourceName {
    final watch = _heartRateSamples
        .where((s) => s.isFromSmartwatch)
        .map((s) => s.sourceName)
        .firstOrNull;
    return watch ?? '';
  }

  /// Inicializa o provider: verifica disponibilidade, pede permissões e carrega dados.
  Future<void> initialize() async {
    _state = HealthProviderState.loading;
    notifyListeners();

    final available = await _hcService.isAvailable();
    if (!available) {
      _state = HealthProviderState.unavailable;
      notifyListeners();
      return;
    }

    final hasPerms = await _hcService.hasPermissions();
    if (!hasPerms) {
      final granted = await _hcService.requestPermissions();
      if (!granted) {
        _state = HealthProviderState.unavailable;
        _error = 'Permissão negada para dados de saúde.';
        notifyListeners();
        return;
      }
    }

    await _loadData();
    await syncToBackend();

    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(minutes: 10), (_) => _loadData());

    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(_syncInterval, (_) async {
      await _loadData();
      await syncToBackend();
    });

    _state = HealthProviderState.ready;
    notifyListeners();
  }

  Future<void> _loadData() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    _heartRateSamples =
        await _hcService.readHeartRateSamples(startOfDay, now);
    _calories = await _hcService.readCalories(startOfDay);
    notifyListeners();
  }

  /// Sincroniza FC e calorias do dia com o backend.
  Future<void> syncToBackend() async {
    if (_isSyncing) return;
    _isSyncing = true;
    notifyListeners();

    try {
      await _healthService.syncHealthData(
        heartRateSamples: _heartRateSamples,
        calories: _calories,
        date: DateTime.now(),
      );
    } catch (e) {
      _error = 'Erro ao sincronizar dados de saúde: $e';
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _syncTimer?.cancel();
    super.dispose();
  }
}
