import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/health_service.dart';
import '../../../core/utils/day_boundary.dart';

enum HealthConnectionStatus {
  /// Not yet checked — the initial state before _checkStatus finishes.
  unknown,

  /// Android only: Health Connect isn't installed or needs an update.
  /// Always "available" on iOS (HealthKit ships with the OS).
  notAvailable,

  /// Available, but Eatsy doesn't have permission (either never asked,
  /// or the person denied/revoked it).
  notConnected,

  /// Eatsy has permission and can sync.
  connected,
}

class HealthSyncState {
  final HealthConnectionStatus status;
  final DateTime? lastSyncedAt;
  final bool isSyncing;
  final String? errorMessage;

  const HealthSyncState({
    this.status = HealthConnectionStatus.unknown,
    this.lastSyncedAt,
    this.isSyncing = false,
    this.errorMessage,
  });
}

/// Manages the connection to Apple HealthKit / Google Health Connect
/// and syncing daily summaries into the health_daily_summary Supabase
/// table (see the migration in supabase/migrations/).
///
/// State transitions are built as fully-explicit new HealthSyncState
/// objects at each call site, rather than a generic copyWith — a
/// copyWith taking nullable params can't distinguish "leave this field
/// alone" from "explicitly set it to null" (errorMessage specifically
/// needs to be clearable on success), and working around that usually
/// means a sentinel-value hack. With only 4 fields, writing each
/// transition out explicitly is simpler and has no ambiguity.
class HealthSyncController extends StateNotifier<HealthSyncState> {
  HealthSyncController() : super(const HealthSyncState()) {
    _checkStatus();
  }

  final _supabase = Supabase.instance.client;

  /// How far back each sync looks. 30 days is enough for any
  /// trend/history view this data will realistically feed, without
  /// pulling a person's entire multi-year HealthKit history on every
  /// sync — the upsert-on-conflict means re-syncing overlapping days
  /// is always safe and cheap regardless of window size, this is
  /// purely about not doing unnecessary work.
  static const int _syncWindowDays = 30;

  Future<void> _checkStatus() async {
    final available = await healthService.isHealthConnectAvailable();
    if (!available) {
      state = const HealthSyncState(status: HealthConnectionStatus.notAvailable);
      return;
    }

    final hasPerms = await healthService.hasPermissions();
    state = HealthSyncState(
      status: hasPerms
          ? HealthConnectionStatus.connected
          : HealthConnectionStatus.notConnected,
    );
  }

  /// Triggers the OS permission prompt, then immediately does a first
  /// sync if granted. Returns false on denial or if Health
  /// Connect/HealthKit isn't available — connect_health_screen.dart
  /// treats both as normal outcomes to explain, not crashes.
  Future<bool> connect() async {
    final granted = await healthService.requestAuthorization();
    if (!granted) {
      state = const HealthSyncState(
        status: HealthConnectionStatus.notConnected,
        errorMessage: 'Permission was not granted.',
      );
      return false;
    }

    // isSyncing deliberately left at its default (false) here — sync()
    // below is the sole owner of that transition, including its own
    // re-entrancy guard. Setting it here too would make that guard
    // immediately bail out and skip the sync this method exists to do.
    state = HealthSyncState(
      status: HealthConnectionStatus.connected,
      lastSyncedAt: state.lastSyncedAt,
    );
    await sync();
    return true;
  }

  /// Stops Eatsy from syncing going forward. Deliberately does NOT
  /// attempt to revoke the OS-level HealthKit/Health Connect
  /// permission — the health package doesn't expose a reliable
  /// cross-platform way to do that, and on iOS specifically, apps
  /// can't programmatically revoke HealthKit access at all; the person
  /// has to do that from the Health app's own Sources settings.
  /// Already-synced rows in Supabase are left as-is — matches the
  /// "disconnect stops future syncing, doesn't retroactively delete
  /// history" decision from planning this feature.
  void disconnect() {
    state = HealthSyncState(
      status: HealthConnectionStatus.notConnected,
      lastSyncedAt: state.lastSyncedAt,
    );
  }

  /// No-op if a sync is already running, rather than starting a second
  /// overlapping fetch — could happen if, say, connect() triggers one
  /// and the person also taps "Sync Now" before it finishes.
  Future<void> sync() async {
    if (state.isSyncing) return;

    state = HealthSyncState(
      status: state.status,
      lastSyncedAt: state.lastSyncedAt,
      isSyncing: true,
    );

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Not signed in');

      final end = DateTime.now();
      final start = end.subtract(const Duration(days: _syncWindowDays));
      final summaries =
      await healthService.fetchDailySummaries(start: start, end: end);

      if (summaries.isNotEmpty) {
        final source = Platform.isIOS ? 'healthkit' : 'health_connect';
        final rows = summaries.entries
            .map((entry) => {
          'user_id': userId,
          'date': _formatDate(entry.key),
          'steps': entry.value.steps,
          'active_calories': entry.value.activeCalories,
          'heart_rate_avg': entry.value.heartRateAvg,
          'sleep_minutes': entry.value.sleepMinutes,
          'weight_kg': entry.value.weightKg,
          'source': source,
          'synced_at': DayBoundary.nowUtcIso(),
        })
            .toList();

        // One batch upsert covering every synced day, rather than one
        // network round-trip per day — health_daily_summary's
        // unique(user_id, date) constraint is what makes this work.
        await _supabase
            .from('health_daily_summary')
            .upsert(rows, onConflict: 'user_id,date');
      }

      state = HealthSyncState(
        status: HealthConnectionStatus.connected,
        lastSyncedAt: DateTime.now(),
        isSyncing: false,
      );
    } catch (e) {
      state = HealthSyncState(
        status: state.status,
        lastSyncedAt: state.lastSyncedAt,
        isSyncing: false,
        errorMessage: e.toString(),
      );
    }
  }

  String _formatDate(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
          '${day.month.toString().padLeft(2, '0')}-'
          '${day.day.toString().padLeft(2, '0')}';
}

final healthSyncControllerProvider =
StateNotifierProvider<HealthSyncController, HealthSyncState>(
        (ref) => HealthSyncController());