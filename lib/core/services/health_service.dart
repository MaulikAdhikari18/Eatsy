import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

/// One aggregated day of health data, after combining however many raw
/// samples HealthKit/Health Connect returned for that calendar day.
/// Every field is nullable — a day with no data of a given type (e.g.
/// no weigh-in that day) is a completely normal, expected outcome, not
/// an error.
@immutable
class DailyHealthSummary {
  final int? steps;
  final double? activeCalories;
  final double? heartRateAvg;
  final int? sleepMinutes;
  final double? weightKg;

  const DailyHealthSummary({
    this.steps,
    this.activeCalories,
    this.heartRateAvg,
    this.sleepMinutes,
    this.weightKg,
  });

  /// True if every field is null — i.e. genuinely nothing was recorded
  /// this day, as opposed to zero being a real recorded value.
  bool get isEmpty =>
      steps == null &&
          activeCalories == null &&
          heartRateAvg == null &&
          sleepMinutes == null &&
          weightKg == null;
}

/// Thin wrapper around the `health` package (Apple HealthKit / Google
/// Health Connect) — configuration, permission handling, and read-only
/// fetch + per-day aggregation for the data types Eatsy actually uses.
/// See pubspec.yaml for why this package specifically, rather than
/// hand-writing separate native platform channels for each OS.
///
/// v1 is read-only: Eatsy never calls writeHealthData or similar —
/// only reads. The Info.plist / AndroidManifest.xml permission
/// descriptions reflect that.
class HealthService {
  final Health _health = Health();
  bool _configured = false;

  /// health.configure() must complete before any other call to the
  /// package — but it's async, and constructors can't be. Every public
  /// method below calls this first; it's idempotent (a second call is
  /// a no-op) so it's safe to call unconditionally rather than making
  /// every call site remember to do it.
  Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  /// The data types Eatsy reads. Sleep is split into 4 stage types
  /// (rather than one "total sleep" type) because HealthKit/Health
  /// Connect model sleep as separate, non-overlapping stage segments —
  /// see _aggregateDay below for how these get summed into one total.
  static const List<HealthDataType> dataTypes = [
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.HEART_RATE,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_REM,
    HealthDataType.WEIGHT,
  ];

  // Every type above is read-only for v1 — one HealthDataAccess.READ
  // per type, matching dataTypes 1:1 (the package requires the two
  // lists to be the same length and order).
  static List<HealthDataAccess> get _permissions =>
      List.filled(dataTypes.length, HealthDataAccess.READ);

  /// Android only: whether the Health Connect *app* itself is
  /// installed and up to date on this device — a separate concern from
  /// whether Eatsy has permission to read from it. iOS has no
  /// equivalent concept (HealthKit ships as part of the OS, not a
  /// separate installable app), so this always returns true there.
  Future<bool> isHealthConnectAvailable() async {
    if (!Platform.isAndroid) return true;
    await _ensureConfigured();
    final status = await _health.getHealthConnectSdkStatus();
    return status == HealthConnectSdkStatus.sdkAvailable;
  }

  Future<bool> hasPermissions() async {
    await _ensureConfigured();
    final result =
    await _health.hasPermissions(dataTypes, permissions: _permissions);
    return result ?? false;
  }

  /// Triggers the OS-level permission prompt. Returns false rather than
  /// throwing if the person denies — that's a normal, expected outcome
  /// here, not an error state. See connect_health_screen.dart for how
  /// the denial path is surfaced in the UI.
  Future<bool> requestAuthorization() async {
    await _ensureConfigured();
    try {
      return await _health.requestAuthorization(dataTypes,
          permissions: _permissions);
    } catch (e) {
      debugPrint('Health authorization error: $e');
      return false;
    }
  }

  /// Fetches raw samples between [start] and [end], then aggregates
  /// them into one DailyHealthSummary per calendar day. Returns a map
  /// keyed by the start-of-day DateTime for each day that had any data
  /// at all — days with nothing recorded simply won't have a key,
  /// rather than an entry full of nulls.
  Future<Map<DateTime, DailyHealthSummary>> fetchDailySummaries({
    required DateTime start,
    required DateTime end,
  }) async {
    await _ensureConfigured();
    final rawPoints = await _health.getHealthDataFromTypes(
      types: dataTypes,
      startTime: start,
      endTime: end,
    );

    // The same sample can come back more than once if it's visible via
    // multiple sources (e.g. the phone's own step counter AND a paired
    // watch both reporting to HealthKit) — dedupe before aggregating so
    // totals aren't inflated for people with multiple data sources.
    final points = _health.removeDuplicates(rawPoints);

    final byDay = <DateTime, List<HealthDataPoint>>{};
    for (final point in points) {
      final day = DateTime(
          point.dateFrom.year, point.dateFrom.month, point.dateFrom.day);
      byDay.putIfAbsent(day, () => []).add(point);
    }

    final result = <DateTime, DailyHealthSummary>{};
    byDay.forEach((day, dayPoints) {
      final summary = _aggregateDay(dayPoints);
      if (!summary.isEmpty) result[day] = summary;
    });
    return result;
  }

  DailyHealthSummary _aggregateDay(List<HealthDataPoint> points) {
    int? steps;
    double activeCalories = 0;
    final heartRates = <double>[];
    int sleepMinutes = 0;
    double? weightKg;
    // Tracks the most recent weight reading's timestamp for THIS day
    // only — kept local to this call, not an instance field, since
    // this method runs once per day and must never carry state across
    // different days' aggregation.
    DateTime? latestWeightAt;

    for (final point in points) {
      final value = point.value;
      final numeric =
      value is NumericHealthValue ? value.numericValue.toDouble() : null;
      if (numeric == null) continue;

      switch (point.type) {
        case HealthDataType.STEPS:
          steps = (steps ?? 0) + numeric.round();
          break;
        case HealthDataType.ACTIVE_ENERGY_BURNED:
          activeCalories += numeric;
          break;
        case HealthDataType.HEART_RATE:
          heartRates.add(numeric);
          break;
        case HealthDataType.SLEEP_ASLEEP:
        case HealthDataType.SLEEP_DEEP:
        case HealthDataType.SLEEP_LIGHT:
        case HealthDataType.SLEEP_REM:
        // Each stage type is a distinct, non-overlapping segment in
        // HealthKit/Health Connect's own data model, so summing every
        // stage's duration gives total sleep time without double
        // counting the same minutes twice.
          sleepMinutes += point.dateTo.difference(point.dateFrom).inMinutes;
          break;
        case HealthDataType.WEIGHT:
        // Multiple weigh-ins on the same day should show the most
        // recent one, not just whichever the API happened to return
        // first — order isn't guaranteed.
          if (latestWeightAt == null || point.dateFrom.isAfter(latestWeightAt)) {
            weightKg = numeric;
            latestWeightAt = point.dateFrom;
          }
          break;
        default:
          break;
      }
    }

    return DailyHealthSummary(
      steps: steps,
      activeCalories: activeCalories == 0 ? null : activeCalories,
      heartRateAvg: heartRates.isEmpty
          ? null
          : heartRates.reduce((a, b) => a + b) / heartRates.length,
      sleepMinutes: sleepMinutes == 0 ? null : sleepMinutes,
      weightKg: weightKg,
    );
  }
}

final healthService = HealthService();