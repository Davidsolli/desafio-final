import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:health/health.dart';

/// Tipos de dados que o app solicita ao Health Connect / HealthKit.
const _readTypes = [
  HealthDataType.STEPS,
  HealthDataType.HEART_RATE,
  HealthDataType.ACTIVE_ENERGY_BURNED,
  HealthDataType.TOTAL_CALORIES_BURNED,
];

/// Package IDs conhecidos de aplicativos de smartwatch/fitness tracker.
const _smartwatchPackages = [
  'com.garmin.android.apps.connectmobile',
  'com.fitbit.fitbitmobile',
  'com.fitbit.FitbitMobile',
  'com.samsung.health',
  'com.samsung.android.wear.shealth',
  'com.google.android.wearable.app',   // Wear OS / Pixel Watch
  'com.xiaomi.hm.health',
  'com.mi.health',
  'com.huami.midong',                   // Amazfit / Zepp
  'com.amazfit.health',
  'com.huawei.health',
  'fi.polar.polarflow',
  'eu.polar.flow',
  'com.suunto.movescount',
  'com.withings.wiscale2',
  'com.mobvoi.companion',               // TicWatch
  'com.fossil.wearables.fossil',
  'com.whoop.android',
  'nodomain.freeyourgadget.gadgetbridge',
  'com.yingsheng.hayloufun',            // Haylou Fun (Haylou Solar Plus, etc.)
  'com.google.android.apps.healthdata',           // Health Connect (Play Store)
  'com.google.android.healthconnect.controller',  // Health Connect nativo Android 14+
  'com.android.healthconnect',                    // HC variante AOSP
  'androidx.health.connect.client.devtool',       // Health Connect Toolbox (emulador/dev)
];

/// Palavras-chave no nome da fonte que indicam smartwatch/tracker.
const _smartwatchKeywords = [
  'watch', 'band', 'garmin', 'fitbit', 'polar', 'suunto',
  'withings', 'amazfit', 'zepp', 'mi fit', 'mi band',
  'huawei', 'honor', 'ticwatch', 'mobvoi', 'whoop',
  'wahoo', 'fossil', 'galaxy watch', 'wear os', 'haylou',
];

/// Package ID do Google Fit — usado como camada intermediária por alguns smartwatches
/// (ex.: Haylou Fun sincroniza com Google Fit, que então escreve no Health Connect).
const _googleFitPackage = 'com.google.android.apps.fitness';

/// Packages que atuam como intermediários (passthrough) para dados de smartwatch.
/// Quando FC vem via esses packages, é provável origem em smartwatch pois
/// celulares não medem batimentos cardíacos.
/// Nota: health.google.apps.healthdata é o Health Connect Toolbox (testes em emulador).
const _passthroughPackages = [
  _googleFitPackage,
  'com.google.android.apps.healthdata', // Health Connect Toolbox
];

/// Retorna true se a fonte identificada é um smartwatch ou fitness tracker.
///
/// Inclui detecção via passthrough: alguns smartwatches (ex.: Haylou) sincronizam
/// via Google Fit, que escreve no Health Connect. O Toolbox usa o mesmo padrão.
/// Quando [hasHeartRate] é true junto com um package de passthrough, é quase
/// certamente um smartwatch — celulares comuns não medem FC.
///
/// Nota: no Android o plugin `health` sempre retorna sourceId vazio — apenas sourceName
/// (= dataOrigin.packageName) está disponível, por isso as packages são verificadas
/// contra ambos os campos.
bool isSmartwatch(
  String sourceName,
  String sourceId, {
  bool hasHeartRate = false,
}) {
  final name = sourceName.toLowerCase();
  final id = sourceId.toLowerCase();
  if (_smartwatchKeywords.any((k) => name.contains(k))) return true;
  // Android: sourceId é sempre vazio — checar packages contra sourceName também.
  if (_smartwatchPackages.any(
    (p) => name.contains(p.toLowerCase()) || id.contains(p.toLowerCase()),
  )) return true;
  // Passthrough (Google Fit, Toolbox): FC indica origem em smartwatch
  if (hasHeartRate &&
      _passthroughPackages.any(
        (p) => name.contains(p) || id.contains(p),
      )) {
    return true;
  }
  return false;
}

// ---------------------------------------------------------------------------

/// Amostra de frequência cardíaca com metadados da fonte.
class HeartRateSample {
  final DateTime measuredAt;
  final int bpm;
  final String sourceName;
  final bool isFromSmartwatch;

  const HeartRateSample({
    required this.measuredAt,
    required this.bpm,
    this.sourceName = '',
    this.isFromSmartwatch = false,
  });
}

/// Resultado da leitura de passos com informações sobre a fonte.
class StepsResult {
  final int steps;
  final bool isFromSmartwatch;
  final String sourceName;

  const StepsResult({
    required this.steps,
    this.isFromSmartwatch = false,
    this.sourceName = '',
  });
}

/// Calorias do dia.
class DailyCalories {
  final double active;
  final double total;
  const DailyCalories({required this.active, required this.total});
}

// ---------------------------------------------------------------------------

/// Wrapper sobre o package `health` para isolar a dependência do SDK.
class HealthConnectService {
  static final HealthConnectService _instance =
      HealthConnectService._internal();
  factory HealthConnectService() => _instance;
  HealthConnectService._internal();

  final Health _health = Health();
  bool _configured = false;

  /// Configura o SDK (idempotente).
  Future<void> configure() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  /// Retorna true se Health Connect está disponível no dispositivo.
  Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    await configure();
    try {
      if (Platform.isAndroid) {
        return await _health.isHealthConnectAvailable();
      }
      return true; // HealthKit sempre disponível em iOS
    } catch (_) {
      return false;
    }
  }

  /// Solicita permissões de leitura para todos os tipos configurados.
  Future<bool> requestPermissions() async {
    await configure();
    try {
      final permissions = _readTypes
          .map((_) => HealthDataAccess.READ)
          .toList();
      return await _health.requestAuthorization(
        _readTypes,
        permissions: permissions,
      );
    } catch (_) {
      return false;
    }
  }

  /// Verifica se o app já possui as permissões sem exibir diálogo.
  Future<bool> hasPermissions() async {
    await configure();
    try {
      final result = await _health.hasPermissions(_readTypes);
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Passos no intervalo [start, end] com identificação da fonte.
  /// Se múltiplas fontes existem, smartwatch tem prioridade na exibição.
  Future<StepsResult> readStepsWithSource(DateTime start, DateTime end) async {
    await configure();
    try {
      final data = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: [HealthDataType.STEPS],
      );
      final deduped = _health.removeDuplicates(data);

      int total = 0;
      String smartwatchSource = '';
      String anySource = '';

      for (final p in deduped) {
        if (p.value is! NumericHealthValue) continue;
        total += (p.value as NumericHealthValue).numericValue.round();
        anySource = anySource.isEmpty ? p.sourceName : anySource;
        if (isSmartwatch(p.sourceName, p.sourceId)) {
          smartwatchSource = p.sourceName.isNotEmpty ? p.sourceName : p.sourceId;
        }
      }

      final fromWatch = smartwatchSource.isNotEmpty;
      return StepsResult(
        steps: total,
        isFromSmartwatch: fromWatch,
        sourceName: fromWatch ? smartwatchSource : anySource,
      );
    } catch (_) {
      return const StepsResult(steps: 0);
    }
  }

  /// Amostras de frequência cardíaca no intervalo [start, end] com fonte.
  Future<List<HeartRateSample>> readHeartRateSamples(
      DateTime start, DateTime end) async {
    await configure();
    try {
      final data = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: [HealthDataType.HEART_RATE],
      );
      final deduped = _health.removeDuplicates(data);
      return deduped
          .where((p) => p.value is NumericHealthValue)
          .map((p) => HeartRateSample(
                measuredAt: p.dateFrom,
                bpm: (p.value as NumericHealthValue).numericValue.round(),
                sourceName: p.sourceName,
                isFromSmartwatch: isSmartwatch(
                  p.sourceName,
                  p.sourceId,
                  hasHeartRate: true,
                ),
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Calorias ativas e totais do dia [date].
  Future<DailyCalories> readCalories(DateTime date) async {
    await configure();
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));

    double active = 0;
    double total = 0;

    try {
      final data = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: [
          HealthDataType.ACTIVE_ENERGY_BURNED,
          HealthDataType.TOTAL_CALORIES_BURNED,
        ],
      );
      final deduped = _health.removeDuplicates(data);
      for (final p in deduped) {
        if (p.value is! NumericHealthValue) continue;
        final val = (p.value as NumericHealthValue).numericValue.toDouble();
        if (p.type == HealthDataType.ACTIVE_ENERGY_BURNED) {
          active += val;
        } else if (p.type == HealthDataType.TOTAL_CALORIES_BURNED) {
          total += val;
        }
      }
    } catch (_) {}

    return DailyCalories(active: active, total: total);
  }
}
