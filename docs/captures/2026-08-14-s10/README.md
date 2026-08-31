# Session 10 — real browser capture of the S2 & S3 boss fights

Captured with the new **test-only `?boss=N` warp** (added this session) against a
locally-served **non-threaded** web export, driven by Playwright with a
weaving+hopping kite (`scripts/playtest-boss-warp.mjs`). This is the first time
either boss fight has been reached in a capture — every prior attempt died on
Level 1 because a blind driver can't beat the Auditor.

## Stage 2 — The Distributor (`?boss=2`)
- `s2-01-arena-reached.png` — warp drops the player straight into the Crystal
  Caverns arena; "THE DISTRIBUTOR" health bar full, boss on his diamond surfboard.
- `s2-02-tracks-overhead.png` — after the player kited right across the arena,
  the boss **tracked horizontally** and is now directly above the player (not
  frozen, not idle).
- `s2-03-hoard-gravity.png` — the boss actively running **Hoard Gravity** (the
  pull ring) while tracking.

**Honest verdict:** the Distributor **tracks the player horizontally and uses its
mechanics** — it is NOT the "idle/frozen" boss. But it holds its overhead ride
height by design (it's a flying boss; body contact = instant run restart, so it
cannot land on the player). The S9 climb-lock hysteresis + this session's 0.5
in-lock horizontal bump improve the horizontal tracking, but whether "hovers
overhead while tracking" reads as "chasing" to the founder is a **design call
that needs the founder's eyes** — NOT claimed definitively fixed.

## Stage 3 — The Claim Jumper (`?boss=3`) — the "frozen statue" fix
- `s3-01-boss-far-right.png` — warp reaches the Gold Rush arena; boss in his TNT
  cart on the far right, health full.
- `s3-02-advanced-toward-player.png` — ~13s later the boss has **advanced from the
  far right (x≈1020) to centre (x≈820), moving toward the player**, throwing
  dynamite (the orange blast telegraphs); health down to ~40%.
- `s3-03-boss-killed-player.png` — the boss's attack **killed the blind driver**
  ("YOU DIED / Respawning…") — it is active, mobile, and dangerous.

**Verdict:** the "frozen statue" regression is **fixed** — the boss moves toward
the player, attacks, deals damage, and takes damage. Backed by a fails-on-pre-fix
regression gate (`tests/s10_final_boss_wall_freeze_test.gd`).

The `ERR_TUNNEL_CONNECTION_FAILED` console errors in the run JSON are the wallet
RPC / analytics calls blocked by the sandbox egress proxy — benign, gameplay is
unaffected.
