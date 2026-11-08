# Playtest dashboard

A static page that lists every play logged to Supabase, grouped by player, and opens one play in detail. It polls Supabase every 10 s on the list and every 5 s on a play that's still going. A hidden tab stops polling.

Live at https://kingsfoil-hearthguard-dashboard.netlify.app (Netlify project `kingsfoil-hearthguard-dashboard`).

## How it reads the data

RLS keeps each player to their own plays, so the page can't read `plays` directly. It calls two `security definer` functions with the publishable key, from `supabase/migrations/20261108080000_dashboard_reads.sql`:

- `dashboard_plays(lim)` returns the newest plays (up to 2000), with whether each player is a guest.
- `dashboard_play(play)` returns one play and all its events.

Neither returns emails. Anyone with the URL and the publishable key, which ships in the game, can read every play's stats, hero names and events. Drop the functions to close that.

## Files

- `index.html`, `style.css`, `app.js` are the page. No build step.
- `names.js` maps skill slots and talent ids to names. Regenerate it with `python3 dashboards/gen_names.py` from the repo root after changing `scripts/data/class_defs.gd`.
- `netlify.toml` turns off caching and indexing.

## Deploy

`netlify deploy --dir=dashboards --prod --site kingsfoil-hearthguard-dashboard`, or the Netlify MCP's deploy-site run from inside `dashboards/`.
