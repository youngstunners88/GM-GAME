---
name: stage-progress-blocker-scanner
description: Static audit for progress-blocking defects in a level — camera limits that don't match the level's own bounds, ladder/platform data mismatches, and unreachable critical-path elements. Run after adding/modifying any campaign level's geometry, bounds, or triggers, or when a founder reports a soft-lock, invisible wall, or "the boss/player disappears."
user-invocable: true
allowed-tools: Read, Glob, Grep
---

# Stage Progress Blocker Audit

**This is a static audit.** It reads level scripts/data and reports; it does
not fix.

## The defect that shipped (why this exists)

`player.tscn`'s `Camera2D` shipped with a hardcoded `limit_right = 3400` —
exactly matching Level 1's width (`bounds.x = 3400`) by pure coincidence.
Level 2 and Level 3 are BOTH `bounds.x = 4400`, with boss arenas at
`x = 3700-4400` — entirely past the old clamp. `LevelBase` (shared by all
3 campaign levels) never overrode this per level, unlike `secret_realm.gd`
and `prototype_room.gd`, which DO set their own camera limits from their own
bounds. Result: the boss spawned beyond where the camera could ever scroll
(reported as "boss unseen on arrival"), and the player could walk past the
frozen camera and off the right edge of the screen (reported as "Lil Blunt
disappears"). This is exactly the class of bug that compiles perfectly,
passes every other gate, and only a full walkthrough (or this specific
cross-check) catches.

## Check 1 — Camera limits match THIS level's bounds

1. Find where this level's `Camera2D.limit_right`/`limit_left`/
   `limit_bottom` are set (ideally in a per-level setup function called
   after player spawn, e.g. `LevelBase._setup_camera_limits()`).
2. Compare against this level's own `level_data.bounds` (and
   `kill_zone_y` for the bottom limit).
3. **FAIL** if the limits are a hardcoded literal instead of derived from
   `level_data.bounds`, OR if no per-level override exists at all (meaning
   every level silently inherits whatever default ships in `player.tscn`).

## Check 2 — Boss arena falls within the camera's reachable range

If this level has a boss arena (`boss_arena.start_x`/`end_x`), confirm
`end_x <= limit_right` (from Check 1). **FAIL** if any part of the boss
arena sits beyond where the camera can ever scroll.

## Check 3 — Ladder/platform data matches actual geometry

Cross-reference with `ladder-top-exit-guard`: for every ladder/platform
placed in this level's script, confirm the position data is internally
consistent (a ladder's top doesn't dangle over a gap with no platform,
per that skill's detailed check).

## Check 4 — Critical-path reachability

Walk the level's ground_segments/platforms/triggers in x-order from the
spawn point to the boss trigger (or level end). Flag any gap that has no
bridging platform, ladder, one-way, or documented intentional-detour route —
i.e., a point where the authored floor route itself appears to have a hole.
