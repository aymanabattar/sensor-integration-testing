# Setup

Standing up a fresh copy of this dashboard against a new Supabase project.

## 1. Create the Supabase project

Create a project at [supabase.com](https://supabase.com) (or use an existing one).

## 2. Run the schema

In the Supabase SQL Editor, run the entire contents of [`supabase/schema.sql`](supabase/schema.sql). This creates:

- The `device_readings` table, with RLS enabled and **zero** policies (deny-all direct access).
- `ingest_reading(...)` — the only way to write a row.
- `get_readings(p_device_id, p_limit)` — the only way to read rows, scoped to one device.
- `list_devices()` — returns the distinct `device_id` values the dashboard uses to populate its device picker.

All three functions are `security definer`, with `search_path` pinned to `public`, and granted to the `anon` role.

## 3. Get your URL and anon key

In the Supabase dashboard: **Project Settings → API**. Copy:

- **Project URL** → `SUPABASE_URL`
- **anon / public key** → `SUPABASE_ANON_KEY`

## 4. Set the config constants

Open `index.html` and set the two constants near the top of the `<script>` block:

```js
const SUPABASE_URL = "https://YOUR-PROJECT-REF.supabase.co";
const SUPABASE_ANON_KEY = "YOUR-ANON-KEY";
```

## 5. Open it

No build step. Open `index.html` directly in a browser, or deploy it (see [`DEPLOY.md`](DEPLOY.md)).

## On the anon key's access model

The anon key is meant to be public — it's embedded in client-side code here on purpose. What makes that safe is scope, not secrecy:

- It has **no direct access to the `device_readings` table** at all (RLS is enabled with no policies).
- It can **only** call the three RPC functions above — nothing else.

That said, this is *access scoping*, not *device authentication*. `ingest_reading` and `get_readings` don't verify who is calling them or check the `device_id` against any identity — anyone holding the anon key (which, again, is public by design) can write a reading under any `device_id`, or read any device's history by guessing/knowing its ID. That's an acceptable tradeoff for a test/integration dashboard, but don't reuse this schema as-is for anything where device impersonation or data privacy actually matters — that would need per-device tokens checked inside the functions, not just table-level RLS.

Two things intentionally were **not** added, to keep this at test-dashboard scope rather than production scope:
- **Rate limiting** on `ingest_reading` — there's a payload-size cap (`raw_payload` capped under 10KB via a table constraint) but no per-device write-frequency throttle. Add one (e.g. reject inserts within N seconds of the device's last row) if this ever sees real/adversarial traffic.
- **Realtime updates** — the dashboard polls every 2 minutes rather than subscribing to Supabase Realtime. Fine for a test feed; swap in Realtime if you need sub-minute latency later.
