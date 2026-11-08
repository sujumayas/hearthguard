# To do

## Replay verification, before leaderboards or rewards

Players write their own play logs, so anyone can send made-up numbers with their session token and the REST API. The database limits (`supabase/migrations/20261108070000_play_logs_limits.sql`) stop spam and impossible values, not a plausible fake. That's fine for balance work. A leaderboard or reward needs results checked by something we run.

The plan is to check a play by playing it again. The Sim is deterministic: a seeded `sim_bot` run gives the same game line for line (checked when the play logs went in). So:

1. The game records the seed and, per tick, what each hero did: the commands `Game._on_cmd` takes (attack, cast, learn, talent, drink, buy, ready) and the hero's position from `_on_sync`. Upload it with the play, compressed. Positions change most ticks, so store them as deltas.
2. A small server runs headless Godot (Fly.io or Cloud Run, not a Supabase Edge Function, which can't run Godot). It replays the recording through `Sim` and writes the real result to a table players can't write to.
3. It rejects movement faster than the hero's `speed` stat allows, since the owner sends its own position.
4. Leaderboards read only the checked results.

Test first that a game recorded in the browser (wasm) replays the same in native Godot on Linux. Plain float math matches, but `sin`, `cos`, `atan2` and `pow` may differ between platforms, and a small difference can grow over a long game. If they differ, replace those calls in the Sim with versions that give the same result everywhere.

Co-op makes this easier on a dedicated server we run, since the host already decides everything in the Sim.
