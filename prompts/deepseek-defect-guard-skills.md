# DeepSeek — draft 7 permanent defect-guard skills

You are drafting Claude Code skills (`.claude/skills/<name>/SKILL.md`) for a
Godot 4.3 game project. This project's own convention (see its existing
skills like `boss-fight-auditor`, `gate-battery-runner`) is: **every check
must trace to a real defect that actually shipped**, not a hypothetical one.
Below are real, CONFIRMED defects found and fixed this session — use these
as the concrete grounding for each skill's checklist, in the same voice as
the existing skills (terse, checklist-driven, "run after X, before Y").

## Real defects found this session (ground each skill in these)

1. **Blaze Rush lifecycle**: `blaze_rush.gd._exit_to_level()` called
   `GameManager.save_checkpoint(1, ...)` — HARDCODED level slot `1` — instead
   of the actual level the run launched from. `save_checkpoint(level, id,
   pos)`'s first argument is the dictionary KEY that
   `LevelBase._spawn_player()` looks up via `get_checkpoint(level_data.
   level_index)`. Entering from Level 2/3 silently wrote the checkpoint into
   Level 1's slot, so on return the real level found nothing under its own
   key and fell through to its default spawn point — reading exactly like
   "the game restarted." One-line fix: use the real level index.

2. **Ladder top-exit**: `ladder.gd` has a data-driven `top_exit_offset`
   (default `Vector2(0,-20)` = "stand directly above my own x"). Two of
   three campaign levels' ladders never set a custom offset, so they used
   the default. One (level_01, x=770) happened to still land inside its
   platform's x-range by coincidence. Another (level_01, x=2345) did NOT —
   the nearest platform starts 55px to the right, so topping out drops the
   player in open air short of the platform. Level_02's ladders already had
   this correctly tuned per-instance (with computed offsets), proving the
   MECHANISM works — the bug is missing per-instance DATA tuning, not a
   broken function.

3. **Stage 2/3 camera clamp**: `player.tscn`'s Camera2D ships with a
   hardcoded `limit_right = 3400` — exactly matching Level 1's width
   (`bounds.x = 3400`) by pure coincidence. Level 2 and Level 3 are BOTH
   4400px wide with their boss arenas at x=3700-4400 — entirely past the old
   clamp. `LevelBase` (shared by all 3 campaign levels) never overrode this
   per-level, unlike `secret_realm.gd` and `prototype_room.gd`, which DO set
   their own camera limits from their own bounds. Result: boss spawns beyond
   the camera clamp (boss "unseen" on arrival) and the player walks past the
   frozen camera and off the right edge of the screen ("Lil Blunt
   disappears"). Fixed with a `LevelBase._setup_camera_limits()` call after
   player spawn, setting `limit_right = level_data.bounds.x`.

4. **Collectible walk-through**: token pickups (`coin.gd`, `gold_token.gd`)
   already use `Area2D.body_entered` against the player's real physics body
   — mechanically this should already support walk-through, not just jump-
   on-top. The complaint is most likely LEVEL-DATA token height placement
   (tokens spawned high enough that only a jump's arc reaches them), not a
   code defect in the pickup path itself.

5. **Stomp**: confirmed there is currently NO head-stomp/jump-attack
   mechanic anywhere in the codebase — landing on an enemy does nothing
   special today.

6. **Tax Collector / Auditor boss**: `auditor.gd`'s CHARGE state moves
   toward a Vector2 snapshotted ONCE when the charge began (`charge_target =
   p.global_position`), never updated again — so it does not actually chase
   the live player, and ranged-throw (PATROL only) and charging (CHARGE
   only) are mutually exclusive states, never simultaneous.

7. **Torch hand attachment**: `lil_blunt_visual.gd::set_tool()` already has
   grip-anchored positioning math (comments describe a prior fix for this
   exact "torch at feet" complaint) — this needs BROWSER evidence to confirm
   whether it's actually still broken or the founder saw a stale build,
   rather than a new code fix.

## Your task

Draft all 7 skills below as complete `SKILL.md` files (Claude Code skill
format: YAML frontmatter with `name`, `description` fields, then markdown
body with numbered steps/checklist). Match the terse, checklist style of
this project's existing skills (a static audit skill reads a set of files
and reports PASS/FAIL findings against a checklist — it does not modify
code). Each skill's description must state clearly WHEN to invoke it (e.g.
"run after any edit to a ladder placement" / "run after adding any new
Area2D.tscn collectible").

1. `blaze-rush-lifecycle` — audits any Blaze-Rush-like secret mode for: does
   finish return to the ORIGINATING level+level_index (not a hardcoded
   default)? Is there a visible exit control at all times? Does exiting
   restore the correct checkpoint slot?
2. `ladder-top-exit-guard` — for every `ladder.tscn` instance placed in a
   level script, checks whether a custom `top_exit_offset` was set OR the
   default `(0,-20)` genuinely lands within a nearby platform's x-range at
   the ladder's top_y. Flags any ladder relying on the untuned default
   without verifying it against real platform data.
3. `collectible-walkthrough` — audits any new collectible Area2D: uses
   `body_entered` (not a jump-only/velocity-gated check), collision_mask
   matches the player's real body layer, and the shape's vertical placement
   is reachable while standing/walking (not only via a jump arc).
4. `stomp-attack` — checklist for implementing/verifying a stomp mechanic:
   fires from above only (not side/below), damages the enemy not the
   player, gives the player a bounce, doesn't double-fire with existing
   hazard/boulder contact-damage paths.
5. `boss-chase-ai-auditor` — audits a boss's aggressive-movement state:
   does it re-read the LIVE player position every frame (not a stale
   snapshot)? Can it jump gaps/ledges with a landing-distance gate (like
   `tax_collector.gd`'s `max_jump_gap`)? Is there a telegraph before
   aggression begins? Are ranged attacks possible WHILE moving, or only in
   a separate stationary state?
6. `tool-hold-anchor` — checklist for any held-tool/weapon sprite: anchored
   to a grip point (not sprite-center, which drags long assets to the feet
   on a short character), verified against the ACTUAL exported texture
   dimensions (not assumed), and confirmed with a screenshot before
   claiming fixed.
7. `stage-progress-blocker-scanner` — audits a level for progress-blocking
   defects: does the player's Camera2D limit_right/limit_bottom match this
   LEVEL's own `bounds` (not a stale default from another level)? Are there
   any ladders/platforms placed with data that doesn't match the level's
   actual geometry? Is every ladder/platform/trigger reachable from the
   critical path?

Output each skill as a separate fenced code block, clearly labeled with its
intended file path (`.claude/skills/<name>/SKILL.md`).
