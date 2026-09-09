-- Device Readings Dashboard — schema, RLS lockdown, and RPC functions.
-- This file is the source of truth: it must match exactly what has been
-- run against the live Supabase project. Re-run the whole file top to
-- bottom against a fresh project to reproduce the setup.

-- ── Table ────────────────────────────────────────────────────────────────

create table if not exists device_readings (
  id            bigserial primary key,
  raw_payload   jsonb not null,
  device_id     text not null,
  temp_c        float,
  humidity_pct  float,
  rssi          float,
  snr           float,
  filtered_rssi float,
  -- First-class fault reporting, alongside raw_payload (kept for full raw
  -- context/debugging). error_code 0 or null means a nominal reading.
  error_code    integer,
  error_message text,
  received_at   timestamptz not null default now(),
  -- Caps payload size so a malicious/misbehaving caller (anon key is public,
  -- embedded client-side by design) can't push arbitrarily large blobs.
  constraint device_readings_raw_payload_size check (pg_column_size(raw_payload) < 10000)
);

create index if not exists device_readings_device_id_received_at_idx
  on device_readings (device_id, received_at desc);

-- ── Lock the table down completely ──────────────────────────────────────
-- No direct access at all, not even via the anon key. RLS is enabled and
-- no policies are created — deny-all. All access goes through the two
-- security-definer functions below.

alter table device_readings enable row level security;

-- ── Write function ───────────────────────────────────────────────────────
-- `set search_path = public` pins the function's search path so it can't
-- be hijacked by a malicious search_path at call time — required hardening
-- for any `security definer` function (Supabase's own linter flags this).

create or replace function ingest_reading(
  p_device_id text,
  p_raw jsonb,
  p_temp_c float default null,
  p_humidity_pct float default null,
  p_rssi float default null,
  p_snr float default null,
  p_filtered_rssi float default null,
  p_error_code int default null,
  p_error_message text default null
) returns void as $$
begin
  if p_device_id is null or length(trim(p_device_id)) = 0 then
    raise exception 'p_device_id must not be empty';
  end if;

  insert into device_readings (device_id, raw_payload, temp_c, humidity_pct, rssi, snr, filtered_rssi, error_code, error_message)
  values (p_device_id, p_raw, p_temp_c, p_humidity_pct, p_rssi, p_snr, p_filtered_rssi, p_error_code, p_error_message);
end;
$$ language plpgsql security definer set search_path = public;

grant execute on function ingest_reading to anon;

-- ── Read function ─────────────────────────────────────────────────────────
-- Scoped by device_id; never returns the whole table in one call. p_limit
-- is clamped server-side so a caller can't request an unbounded result set.

create or replace function get_readings(p_device_id text, p_limit int default 50)
returns setof device_readings as $$
  select * from device_readings
  where device_id = p_device_id
  order by received_at desc
  limit least(greatest(p_limit, 1), 500);
$$ language sql security definer set search_path = public;

grant execute on function get_readings to anon;

-- ── Device list function ─────────────────────────────────────────────────
-- Small addition from Action Item 2: lets the dashboard populate a device
-- picker without ever reading the raw table directly.

create or replace function list_devices()
returns table(device_id text) as $$
  select distinct device_id from device_readings order by device_id;
$$ language sql security definer set search_path = public;

grant execute on function list_devices to anon;
