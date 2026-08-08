<!-- dispatched: deepseek/deepseek-v4-flash
     prompt: prompts/deepseek-mobile-spec-and-compliance.md
     files inlined: 3
     tokens: 6425 in / 2253 out
     cost: $0.0015
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
## Section 1 — MOBILE CONTROLS + ONBOARDING SPEC

### Architecture: One‑Path TouchScreenButton → InputMap

Every on‑screen control is a `TouchScreenButton` bound to an existing `InputMap` action.  
- **Pressed** → `Input.action_press(action)`  
- **Released** → `Input.action_release(action)`  

This guarantees **desktop parity by construction** – touch flows through the same code paths as keyboard (movement, jump, double‑jump, climb, dash, sprint, interact, attack).  
**Multitouch** is native: each `TouchScreenButton` tracks its own finger, so the player can hold LEFT + JUMP + ATK simultaneously – impossible with `emulate_mouse_from_touch` on plain `Button` nodes.

### Detection Rule

```gdscript
is_touch = OS.get_name() in ["Android", "iOS"] or DisplayServer.is_touchscreen_available()
```

The Web export always reports `OS.get_name() == "Web"`, so `has_feature("mobile")` is **always false** in a browser. `DisplayServer.is_touchscreen_available()` is the only reliable signal for mobile browsers. The same rule is used in `MobileInputHandler` for consistency.

### ASCII‑Only Labels

The pixel font has **no arrow glyphs** (◄ ► ▲ ▼ render as tofu boxes). All labels use basic‑Latin characters: `<`, `>`, `UP`, `DOWN`, `GRAB`, `RUN`, `DASH`, `JUMP`, `ATK`.

### Layout Map (viewport fractions)

| Zone | Controls | Position (x, y, w, h) | Tint |
|------|----------|-----------------------|------|
| **Left thumb** | `<` (move_left) | `[0.02, 0.62, 0.13, 0.31]` | Green |
| | `>` (move_right) | `[0.16, 0.62, 0.13, 0.31]` | Green |
| | `UP` (move_up) | `[0.04, 0.34, 0.10, 0.15]` | Light blue |
| | `DOWN` (move_down) | `[0.04, 0.50, 0.10, 0.12]` | Light blue |
| **Right thumb** | `ATK` (attack) | `[0.71, 0.58, 0.22, 0.32]` | Red |
| | `JUMP` (jump) | `[0.79, 0.30, 0.19, 0.26]` | Blue |
| | `DASH` (dash) | `[0.58, 0.60, 0.12, 0.22]` | Purple |
| | `RUN` (sprint) | `[0.58, 0.36, 0.11, 0.20]` | Orange |
| | `GRAB` (interact) | `[0.44, 0.85, 0.12, 0.12]` | Yellow |

All positions recompute on `get_viewport().size_changed` (fixes stale layout on rotate).

### First‑Run Onboarding

- `how_to_play_panel.gd` shows a dismissible panel with keyboard + touch hints per action.
- Auto‑shown once on first run (persisted via `user://how_to_play_shown.txt`).
- Re‑openable from the main menu and pause menu.
- Uses `ScrollContainer` so it fits any viewport (including short landscape phones).
- Dismissed by tapping the dimmed backdrop, pressing `GOT IT`, or pressing `ui_cancel`.

### DO NOT List (from Kimi K3 findings)

- **DO NOT** use `has_feature("mobile")` for detection – always false on Web export.
- **DO NOT** create separate touch‑input parsing or invisible tap zones – use `TouchScreenButton` → `InputMap` only.
- **DO NOT** use arrow symbols (◄►▲▼) in labels – use `< > UP DOWN` etc.
- **DO NOT** use `emulate_mouse_from_touch` – breaks multitouch and causes double‑fire.
- **DO NOT** compute layout only in `_ready` – connect `size_changed` for resize/rotate.
- **DO NOT** keep dead touch scripts (`touch_controls.gd`) – delete them.
- **DO NOT** emit old `touch_*` signals – the action path supersedes them; keep declarations only for backward‑compatible `.connect()` calls.

---

## Section 2 — MINIMAL TEST CHECKLIST (mobile viewport + desktop parity)

After any input/UI change, run these checks:

### Touch Controls (on a real touch device or Playwright with touch emulation)
- [ ] Tap each touch button: `<`, `>`, `UP`, `DOWN`, `JUMP`, `ATK`, `DASH`, `RUN`, `GRAB` – each triggers the correct action (movement, jump, attack, etc.).
- [ ] Multitouch: hold `<` + `JUMP` + `ATK` simultaneously – player moves left, jumps, and attacks without dropping any input.
- [ ] Hold `RUN` while moving – sprint activates.
- [ ] On a ladder, tap `UP` / `DOWN` – player climbs (was previously broken).
- [ ] Release all fingers – all actions stop (no stuck movement).
- [ ] Rotate device – controls reposition correctly (no off‑screen buttons).
- [ ] Overlay is invisible on desktop (no touch screen) – confirm via `visible == false`.

### Desktop Parity
- [ ] Keyboard still works: WASD/arrows, Space/J/K/Shift/E – all actions respond.
- [ ] No double‑fire: pressing a keyboard key and tapping the same touch button does not trigger the action twice.

### Onboarding Panel
- [ ] First run: panel auto‑shows before the main menu.
- [ ] Dismiss by tapping backdrop, pressing `GOT IT`, or pressing Escape.
- [ ] Second run: panel does **not** auto‑show (persisted flag).
- [ ] Re‑open from menu button – panel appears.
- [ ] ScrollContainer works on a 844×390 viewport – all rows reachable, `GOT IT` button visible.

### No Errors
- [ ] No script errors in console during all the above.
- [ ] `verify-game.mjs` desktop gate passes (boots to PLAYING, dismisses panel, clicks PLAY).

---

## Section 3 — THREE‑LAYER COMPLIANCE

| Criterion | Assessment |
|-----------|------------|
| **1. Intent clear + scope respected** | Yes. Goal: mobile controls + onboarding. Out‑of‑scope items (PostHog, CI, etc.) untouched. |
| **2. Context loaded before implementation** | Yes. Layer 2 context (STATUS.md, UI scripts, distributor, prior logs, gdscript‑gotchas, bootstrap script) was fetched and read before any code was written. |
| **3. Models used in their roles** | Yes. Grok → design briefs (mobile scheme, titles/onboarding). Kimi → audits (input path, font sizes). DeepSeek → spec/process (this document). |
| **4. Working layer rebuilt vs extended** | Rebuilt. The old three‑overlapping‑touch‑system was replaced with a single `TouchScreenButton` → `InputMap` architecture. Dead `touch_controls.gd` deleted. `MobileInputHandler` reduced to a shim. |
| **5. Verdict** | **COMPLIANT** – all three layers respected, scope contained, models used correctly, and the working layer was rebuilt rather than patched over bugs. |