-- health_daily_summary
--
-- One row per user per calendar day, holding data synced from Apple
-- HealthKit / Google Health Connect via the health package (see
-- lib/core/services/health_service.dart and
-- lib/features/health/controllers/health_sync_controller.dart).
--
-- Deliberately kept SEPARATE from the existing weight_logs table rather
-- than merging synced weight into it — weight_logs is manually-entered
-- (Goals screen), and merging two data sources into one table means
-- handling dedup logic for the same day having both a manual and a
-- synced entry. That's real scope creep for v1; keeping them apart
-- avoids it entirely. The two can be reconciled in the UI layer later
-- if that's ever wanted, without a schema migration.
--
-- One row per (user_id, date) — the unique constraint below is what
-- makes upsert(onConflict: 'user_id,date') from the app work correctly,
-- matching the same upsert-on-conflict convention already used by
-- goals, diet_plans, and user_preferences elsewhere in this schema.
create table if not exists health_daily_summary (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  date date not null,
  steps integer,
  active_calories numeric,
  heart_rate_avg numeric,
  sleep_minutes integer,
  weight_kg numeric,
  -- Which platform this row's data came from — surfaced in the Connect
  -- Health Data screen so the person can see what's actually connected,
  -- and useful for debugging sync issues without guessing.
  source text not null,
  synced_at timestamptz not null default now(),
  unique (user_id, date)
);

comment on table health_daily_summary is
  'Daily health metrics synced from Apple HealthKit / Google Health Connect. Separate from weight_logs (manual entries) by design — see comment above.';

alter table health_daily_summary enable row level security;

-- Same four-policy shape (select/insert/update/delete, all scoped to
-- auth.uid() = user_id) used consistently across every other
-- user-owned table in this schema.
create policy "Users can view their own health data"
  on health_daily_summary for select
  using (auth.uid() = user_id);

create policy "Users can insert their own health data"
  on health_daily_summary for insert
  with check (auth.uid() = user_id);

create policy "Users can update their own health data"
  on health_daily_summary for update
  using (auth.uid() = user_id);

create policy "Users can delete their own health data"
  on health_daily_summary for delete
  using (auth.uid() = user_id);

-- Speeds up the common query pattern: "give me this user's last N
-- days," which both the Connect Health Data screen and any future
-- Dashboard card will do on every load.
create index if not exists health_daily_summary_user_date_idx
  on health_daily_summary (user_id, date desc);