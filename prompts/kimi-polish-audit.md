ROLE: You are a verification engineer auditing a visual/audio polish pass in
a Godot 4.3 2D platformer.

The complete current source of every file under discussion is inlined below.
Base every statement on the code as given.

CONSTRAINT (non-negotiable): Do not invent methods, file paths, node types, or
Godot APIs that do not appear in the inlined files. If you need something that
was not provided, name exactly what is missing instead of guessing.

## What changed this session (polish only — no new mechanics)

1. **`src/dashmode/blaze_rush.gd`** — a Geometry-Dash-style secret auto-
   runner bonus mode got a full visual pass: a 3-layer background (static
   void rect, a true `ParallaxBackground`/`ParallaxLayer` haze layer, and
   two `CPUParticles2D` "speed atmosphere" emitters parented to the
   `Camera2D`), a player speed-trail emitter, retinted obstacles per a
   color-coded glance-test (hazards = warm, safe = cool, collectibles =
   cream), and a new hazard telegraph: a single reusable warning bar
   repositioned every physics frame to whichever lethal hazard (candle or
   floor gap) is next ahead of the player, fading in as it enters a lead
   distance.
2. **`src/enemies/tax_collector.gd`** — one new line: a `tax_alert` sound
   plays the instant the enemy transitions from PATROL to ALERT.
3. **`src/level/secret_realm.gd`** — a small helper,
   `_swap_placeholder_texture()`, checks whether a real texture exists at a
   documented path and swaps it in over the placeholder if so; a no-op
   otherwise. No generic registry system — four known call sites.

## Ground truth about the codebase

- `AudioManager.play_sfx()`/`play_sfx_at()` silently no-op if the named
  file doesn't exist — this is an established, intentional convention, not
  a bug to flag.
- The Tax Collector's PATROL/ALERT/PURSUE state machine and its
  `_player_in_range()` gating were audited in a previous session; this
  session only added one `AudioManager` call inside the existing
  PATROL->ALERT transition, no state-machine logic changed.
- `_camera.position.x = _player.position.x + 240.0` is the existing,
  unchanged camera-follow mechanism — the camera is not smoothed, not a
  child of the player.
- The game targets HTML5 (non-threaded) and Android.

## Files

@include src/dashmode/blaze_rush.gd
@include src/enemies/tax_collector.gd
@include src/level/secret_realm.gd

## Tasks

1. **Telegraph bar correctness.** `_update_telegraph()` runs every physics
   frame, linear-scans `_hazard_x` for the first entry greater than the
   player's x. `_hazard_x` is built once in `_build_obstacles()` from candle
   and gap positions, then `.sort()`ed. Is the scan safe once the player has
   passed every hazard (empty match)? Is there any scenario where the bar's
   alpha could get stuck non-zero (never reset to 0) after the player passes
   a hazard without hitting it?

2. **Camera-attached particle lifetime.** The speed-trail, streak-field, and
   dust emitters are children of `_camera` and `_player` respectively, both
   of which are freed on scene exit (level end / crash-restart uses
   `_reset_player()`, not a fresh scene load — confirm from the inlined
   code what `_reset_player()` actually does to the player node and whether
   the trail emitter attached to it survives a crash/reset correctly or
   needs to be rebuilt).

3. **Performance.** Total live particle count across all emitters
   (background streaks/dust, per-candle embers, player trail, pickup
   bursts) at a moment when several are active simultaneously — does
   anything here read as likely to tank HTML5/Android frame rate given the
   stated constraint of keeping peak particle count under ~120?

4. **`tax_collector.gd`**: does the new `AudioManager.play_sfx_at("tax_alert",
   global_position)` call introduce any new risk (e.g., fires every frame
   instead of once on the transition edge, given the state machine's
   structure)?

5. **`secret_realm.gd`**: is `_swap_placeholder_texture()`'s "hide children,
   don't free them" approach safe if called twice (e.g., scene reload) —
   does it double-add a `TextureRect` or handle re-entry cleanly? Is there
   any null-safety gap in the loop over `container.get_children()`?

6. **Gate compatibility.** Anything about the new code's syntax that would
   fail `gdparse` or Godot's `can_instantiate()`?

7. **One-paragraph verdict**: is this safe to ship?

## Output format

Markdown. For every finding: `severity (high/med/low) — file:line-ish — claim
— why it matters`. No preamble.
