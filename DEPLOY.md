# Deploy

This is deployed as a [Render Static Site](https://render.com/docs/static-sites), configured entirely through the committed [`render.yaml`](render.yaml) Blueprint.

## Why Static Site

There is no backend server anywhere in this stack — the dashboard calls Supabase RPC functions directly from the browser. A Static Site has no server process, so there's nothing to sleep, unlike Render's free-tier Web Services (which spin down after inactivity and cold-start on the next request). This deploys once and stays up indefinitely at no cost.

## One-time setup: Blueprint import

1. In the Render dashboard, choose **New → Blueprint**.
2. Point it at this repo (`aymanabattar/sensor-integration-testing`).
3. Render reads `render.yaml` and creates the static site with no manual field configuration:
   ```yaml
   services:
     - type: web
       name: device-readings-dashboard
       runtime: static
       staticPublishPath: .
       buildCommand: "true"
   ```
   - `runtime: static` — no build/runtime environment, just files served as-is.
   - `staticPublishPath: .` — serves the repo root, where `index.html` lives.
   - `buildCommand: "true"` — a no-op shell command (`true` always exits 0). Render's Blueprint spec lists `buildCommand` as required for non-Docker services even when there's nothing to build; an empty string isn't guaranteed to satisfy that, so this is the safe no-op instead.
4. Make sure `index.html` already has real `SUPABASE_URL` / `SUPABASE_ANON_KEY` values committed (see [`SETUP.md`](SETUP.md)) before deploying.

## Ongoing deploys

Once imported, pushing to the connected branch auto-redeploys — no extra steps.
