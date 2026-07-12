# ADR: Gameplay Feel Pass — Movement, Camera, Impact

**Date:** 2026-07-12
**Status:** Accepted
**Files:** `src/player/player.gd`, `src/player/input_handler.gd`, `src/player/player_camera.gd` (new), `src/player/player.tscn`

## Context

Movement worked but felt "engine-default": symmetric jump arc (floaty), instant
accelerate/stop (digital), a camera that trailed the player, knockback that got
overwritten by input on the next frame, and a dash barely faster than running.
Target feel: classic 16-bit platformer (SMB/GBA-era) — snappy, forgiving, punchy.

## Decisions & numbers

| Parameter | Before | After | Why |
|---|---|---|---|
| Jump force / gravity | -420 / 980 | -430 / 1000 | Same ~92px jump height (level gaps safe) |
| Fall gravity | 1.0× | **1.65×** rise gravity | Asymmetric arc: rise 0.43s, fall 0.33s → ~0.76s full-jump airtime (was 0.86s symmetric). Kills float without shrinking height |
| Terminal velocity | none | 720 px/s | Falls stay readable; no warp-speed plummets |
| Ground accel | instant | 2000 px/s² (~0.1s to max) | Arcade ramp — responsive but not twitchy |
| Ground decel | ~instant* | 2800 px/s² (~0.07s stop) | Crisp stops with one frame of slide |
| Air accel / decel | instant / broken* | 1400 / 900 px/s² | Less air control than ground, classic |
| Momentum friction | n/a (overwritten) | 1200 floor / 350 air px/s² | Dash/knockback/wall-jump momentum decays instead of vanishing next frame |
| Coyote time | 0.08s | **0.10s** (~6 frames) | Standard forgiveness window |
| Jump buffer | 0.08s | **0.12s** | Early presses fire on landing |
| Double jump | -350 | -370 | Keeps proportion with new gravity |
| Air dash | 300 px/s, kept fall speed | **400 px/s, zeroes vertical** | 2× run speed + flat trajectory = reads as a punch |
| Wall slide | uncapped | capped 160 px/s | Entering a slide at speed now actually slides |
| Knockback | 200/-250 | 240/-260 + **hitstop** (70ms @ 5% timescale) | Hits land with impact; momentum system lets knockback play out |
| Landing squash | dead code | wired: falls > 380 px/s | `_play_land_squash()` existed but was never called |
| Camera | trailing (smoothing only) | **velocity lookahead** ±56px + 34px fall-peek | See where you're going. Applied via `position`, not `offset` — ScreenShake owns `offset` |

*Two latent bugs fixed in passing: deceleration used `move_toward` without
`delta` (full stop in one physics frame), and the movement read keyboard input
directly, ignoring the mobile-override direction computed earlier in the frame.

## Consequences

- Jump **height** is preserved, so no existing platform gap breaks; jump
  **duration** is ~12% shorter — pure feel, no level redesign needed.
- All values are `@export`s on Player — tunable per-scene or live in-editor.
- Hitstop uses `Engine.time_scale`; the restore timer ignores time scale, so
  the freeze can't stick. Guarded against re-entry.
- `PlayerCamera` assumes its parent is the `CharacterBody2D`; Blaze Rush mode
  builds its own camera and is unaffected.

## Rollback

Every change is either an exported constant or an isolated function
(`_hitstop`, `_try_air_dash`, `player_camera.gd`). Revert the commit or re-zero
the exports; no data migration.

## ADR Dependencies

None — self-contained player/camera tuning. Coexists with ScreenShake
(offset-based) and Blaze Rush (own camera) by design.

## Engine Compatibility

Godot 4.3 (pinned, `docs/engine-reference/godot/VERSION.md`). Uses only
stable 4.x APIs: `move_toward`, `CharacterBody2D.velocity`,
`SceneTree.create_timer(time, process_always, process_in_physics,
ignore_time_scale)`, `Engine.time_scale`.

## GDD Requirements Addressed

Core feel pillar — "fun, polished, and true to Lil Blunt's chill personality"
(CLAUDE.md Global Rules); STATUS.md known-gap #2 "Gameplay feel pass".
