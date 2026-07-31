# Mobile Controls + Onboarding — Spec

Landed 2026-08-01. Drafted by DeepSeek V4 Flash from the shipped
implementation (`docs/model-responses/2026-08-01-deepseek-mobile-spec-compliance.md`),
reviewed and corrected by Claude against the real files. Design inputs: Grok
4.5 (control scheme + title hierarchy), Kimi K3 (input-path + font audits) —
see `docs/model-responses/2026-08-01-*`.

This documents the SHIPPED design so a future change doesn't re-introduce the
bugs it fixed. If you touch touch input or early UI, read the DO-NOT list.

## Architecture: one path — TouchScreenButton → InputMap action

Every on-screen control is a `TouchScreenButton` bound to an existing
`InputMap` action (`src/ui/mobile_controls.gd`):
- **pressed** → `Input.action_press(action)`
- **released** → `Input.action_release(action)`

Why:
- **Desktop parity by construction** — touch presses the same actions the
  keyboard does (move_left/right/up/down, jump, dash, sprint, interact,
  attack), so movement, jump, double-jump, climb, dash, sprint, interact, and
  attack (tap + fire-breath hold) all run through one code path. There is no
  separate "mobile" gameplay branch to drift.
- **Native multitouch** — each `TouchScreenButton` tracks its own finger, so
  LEFT + JUMP + ATK can be held at once. Plain `Button` nodes under
  `emulate_mouse_from_touch` collapse to a single mouse pointer and cannot.

`MobileInputHandler` (autoload) is now a thin shim:
`get_movement_input()` returns `Input.get_axis("move_left","move_right")`;
`is_sprint_active()` returns the `sprint` action. The old `touch_*` signals
remain *declared* only so existing `.connect()` calls don't error — they are
no longer emitted.

## Detection rule

```gdscript
is_touch = OS.get_name() in ["Android","iOS"] or DisplayServer.is_touchscreen_available()
```

The Web export always reports `OS.get_name() == "Web"` — even in a phone
browser — so `has_feature("mobile")` is always false. `is_touchscreen_available()`
is the only reliable mobile-web signal. `TouchScreenButton.visibility_mode =
VISIBILITY_TOUCHSCREEN_ONLY` also disables the hit areas on non-touch desktop.

## ASCII-only labels

The pixel font has no arrow glyphs — `◄ ► ▲ ▼ ← →` render as tofu boxes. All
labels are basic-Latin: `<`, `>`, `UP`, `DOWN`, `JUMP`, `ATK`, `DASH`, `RUN`,
`GRAB`.

## Layout map (viewport fractions, landscape)

| Thumb | Control | action | rect [x,y,w,h] |
|-------|---------|--------|----------------|
| Left  | `<`     | move_left  | 0.02, 0.62, 0.13, 0.31 |
| Left  | `>`     | move_right | 0.16, 0.62, 0.13, 0.31 |
| Left  | `UP`    | move_up    | 0.04, 0.34, 0.10, 0.15 |
| Left  | `DOWN`  | move_down  | 0.04, 0.50, 0.10, 0.12 |
| Right | `ATK`   | attack     | 0.71, 0.58, 0.22, 0.32 (primary, biggest) |
| Right | `JUMP`  | jump       | 0.79, 0.30, 0.19, 0.26 |
| Right | `DASH`  | dash       | 0.58, 0.60, 0.12, 0.22 |
| Right | `RUN`   | sprint     | 0.58, 0.36, 0.11, 0.20 |
| Centre| `GRAB`  | interact   | 0.44, 0.85, 0.12, 0.12 |

Layout recomputes on `get_viewport().size_changed` (rotate/resize safe).

## First-run onboarding

`src/ui/how_to_play_panel.gd` — a dismissible "HOW YOU ROLL" panel showing
keyboard AND touch per action in two columns. Auto-shown once on first run
(persisted to `user://how_to_play_shown.txt`), re-openable from the main
menu's **HOW TO PLAY** button. Fits any viewport via a `ScrollContainer`.
Dismissed by tapping the dimmed backdrop, the **GOT IT** button, or `ui_cancel`.
(NOT wired into the pause menu — that scene is currently dead/uninstanced;
see owner notes in the session log.)

## DO NOT (distilled from the Kimi K3 audit)

- **DO NOT** detect mobile with `has_feature("mobile")` — always false on Web.
- **DO NOT** add a second touch-parsing path or invisible tap-zones — one
  `TouchScreenButton` → InputMap-action path only.
- **DO NOT** put arrow glyphs in labels — ASCII only.
- **DO NOT** rely on `emulate_mouse_from_touch` for game controls — it breaks
  multitouch and double-fires.
- **DO NOT** compute control/zone layout only in `_ready()` — connect
  `size_changed`.
- **DO NOT** leave dead touch scripts around (`touch_controls.gd` was deleted).

## Minimal test checklist (run after any input/UI change)

Touch (real device or Playwright touch context, e.g. 844×390 landscape):
- Tap each of `< > UP DOWN JUMP ATK DASH RUN GRAB` → correct action fires.
- Hold `<` + `JUMP` + `ATK` together → moves, jumps, attacks, no dropped input.
- On a ladder, tap `UP`/`DOWN` → climbs.
- Release all → nothing stuck.
- Rotate/resize → controls reposition, none off-screen.

Desktop parity:
- Keyboard (WASD/arrows, Space, J, K, Shift, E) all still respond.
- Touch overlay is invisible on non-touch desktop.

Onboarding:
- First run: panel auto-shows; dismiss via backdrop / GOT IT / Escape.
- Second run: does NOT auto-show (flag persisted).
- Re-open from the menu button works; on 844×390 all rows + GOT IT reachable.

Gates:
- `script_compile`, `distributor_behaviour`, `boss_arena_reachable`,
  `security-sentinel`, and `verify-game.mjs` (desktop, dismisses the first-run
  panel then reaches PLAYING) all pass; console clean.
