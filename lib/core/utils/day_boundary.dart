/// Local-day/week boundary helpers for querying `timestamptz` columns
/// (`logged_at`, `created_at`, etc. — every one of them in this schema).
///
/// The bug this exists to fix: `DateTime(now.year, now.month, now.day)`
/// builds a DateTime in the device's *local* timezone, but calling
/// `.toIso8601String()` directly on it (with no `.toUtc()` first)
/// produces a string with no 'Z'/offset suffix at all — just the raw
/// local wall-clock numbers. Postgres/PostgREST interprets an
/// offset-less timestamp as UTC, not local time, so that string gets
/// stored/compared as if "local midnight" were "UTC midnight". For a
/// user in IST (UTC+5:30) that silently shifts every day/week boundary
/// by 5.5 hours — most visible for anything logged late at night,
/// which can land in the wrong day's bucket.
///
/// The fix is always the same: build the boundary from local calendar
/// components (so "today" means the user's actual today), then convert
/// to UTC with `.toUtc()` before it ever becomes a string sent to
/// Supabase. Reading a value back works in reverse — `DateTime.parse`
/// on a Postgres-returned timestamptz string (which always includes an
/// explicit offset) yields a UTC-flagged DateTime, so `.toLocal()` is
/// needed before pulling calendar properties like `.weekday`, `.day`,
/// or `.month` off it, or those will reflect the UTC calendar day
/// instead of the user's.
class DayBoundary {
  /// UTC instant marking the start (00:00) of the local calendar day
  /// containing `at` (defaults to now). Use with `.gte('logged_at', ...)`.
  static DateTime startOfLocalDay([DateTime? at]) {
    final local = at ?? DateTime.now();
    return DateTime(local.year, local.month, local.day).toUtc();
  }

  /// UTC instant marking the start of the *next* local calendar day.
  /// Use with `.lt('logged_at', ...)` as the exclusive upper bound.
  static DateTime endOfLocalDay([DateTime? at]) =>
      startOfLocalDay(at).add(const Duration(days: 1));

  /// UTC instant marking local Monday 00:00 of the week containing
  /// `at` — matches weekly_trends_controller's Mon–Sun week definition.
  static DateTime startOfLocalWeek([DateTime? at]) {
    final local = at ?? DateTime.now();
    final localToday = DateTime(local.year, local.month, local.day);
    final localMonday =
    localToday.subtract(Duration(days: localToday.weekday - 1));
    return localMonday.toUtc();
  }

  /// UTC instant marking the start of the local Monday one week after
  /// `startOfLocalWeek` — the exclusive upper bound for a Mon–Sun range.
  static DateTime endOfLocalWeek([DateTime? at]) =>
      startOfLocalWeek(at).add(const Duration(days: 7));

  /// A UTC instant `daysAgo` days before the local start-of-day for
  /// `at` — for rolling lookback windows (e.g. "last 7 days") rather
  /// than calendar-week ones.
  static DateTime daysAgoLocal(int daysAgo, [DateTime? at]) =>
      startOfLocalDay(at).subtract(Duration(days: daysAgo));

  /// The correct, timezone-safe replacement for
  /// `DateTime.now().toIso8601String()` when writing a `logged_at` /
  /// `created_at` / `updated_at` value — always converts to UTC first
  /// so the stored instant is actually correct, not just "happens to
  /// look consistent" because every reader made the same mistake.
  static String nowUtcIso() => DateTime.now().toUtc().toIso8601String();

  /// Converts a timestamptz string read back from Supabase into a
  /// DateTime whose calendar properties (`.day`, `.weekday`, `.month`,
  /// `.hour`) reflect the *user's local* day rather than UTC. Always
  /// use this instead of a bare `DateTime.parse` when the result will
  /// be bucketed or displayed by calendar day.
  static DateTime parseToLocal(String isoString) =>
      DateTime.parse(isoString).toLocal();
}