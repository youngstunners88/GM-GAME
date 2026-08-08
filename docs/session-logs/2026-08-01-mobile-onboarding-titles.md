# 2026-08-01 — Mobile playability + onboarding + readable titles (Three-Layer)

Session type: product accessibility + feel, per
`PROMPT_MOBILE_ONBOARDING_TITLES_MULTI_MODEL.md`. Video work deferred. No
infrastructure (PostHog, Sentry, CI, PixelLab) touched. Fetch-first done;
Layer 2 context loaded before implementation. Heavy multi-model, in-role.

## Goal 1 — readable titles & early UI

**Before → after (all measured against the base 1280×720, which shrinks on a
phone):**
- Main menu title `LIL BLUNT`: **48 → 72**, white + 8px black outline.
- Subtitle `THE SMOKE REALM`: **24 → 32**, and the **duplicate removed** — the
  title was overwritten in code to a two-line string that repeated the
  subtitle, so "THE SMOKE REALM" rendered twice (Kimi #1). Title is now just
  the name; the SubtitleLabel carries the tagline.
- Primary buttons PLAY/CONTINUE/QUIT: **28 → 36**, 320×60, outlined.
- Secondary column (HOW TO PLAY, CONNECT RABBY, …): **20 → 26**, 300×46 →
  320×56, outlined; stack pitch updated so the taller column doesn't clip.
- HUD (in-game "early UI"): score **24 → 30**; the 9 resource labels
  **20 → 26** and **all given black outlines** — they were near-white over
  gameplay art with no outline (Kimi's worst-contrast finding). Powerup label
  bumped + outlined; progress bars given a 24px min height.
- HUD control hint: **18 → 26**, and made **input-aware** — touch players now
  see `MOVE < >  ·  JUMP  ·  ATK  ·  CLIMB UP/DOWN` instead of keyboard-only
  keys on a device with no keyboard.
- First-run email panel: blurb **14 → 22** (the single smallest text in the
  build), title 24 → 32, inputs to 56px tall, buttons to 64px, consent 52px.
- **Real bug fixed:** YOU DIED + two toasts used `get_viewport().size`
  instead of `get_visible_rect().size`; with `canvas_items`+`expand` those
  disagree on any non-1280×720 window (every phone), so all three landed
  off-centre. Switched to the visible rect + added outlines.

Verified in a real browser at both 1280×720 and 844×390 — clean hierarchy
(title ≫ subtitle ≫ primary ≫ secondary), everything legible, no clipping.

## Goal 2 — mobile + tablet playability

**The core problem:** three overlapping, half-wired touch systems. Kimi K3
confirmed and I verified: `touch_controls.gd` was dead code (its scene
actually ran `mobile_controls.gd`); the live overlay + the `MobileInputHandler`
autoload's invisible tap-zones **double-fired** on landscape and left
**ghost taps** on portrait; there was **no up/down control at all** (climbing
impossible on touch — a hard progression blocker); the "joystick" was fake
(digital `sign(x)`, dead centre column, a knob that never moved); layout went
stale on rotate; and on mobile-web the movement never reached the player
because `get_movement_input()` fed a value nothing on the touch path set.

**The fix — collapse to ONE path.** `mobile_controls.gd` rewritten so every
control is a `TouchScreenButton` bound to an existing `InputMap` action
(press → `action_press`, release → `action_release`). Touch now flows through
the identical code paths as the keyboard, so **desktop parity holds by
construction**, and `TouchScreenButton` gives **true multitouch** (hold
move + jump + attack). Layout is Grok's scheme: big digital `<` / `>` zones,
a compact `UP`/`DOWN` pair (climbing works on touch now), and a right cluster
with a big primary `ATK`, `JUMP` above it, `DASH`/`RUN`, and a centre `GRAB`.
Detection switched to `DisplayServer.is_touchscreen_available()` (the Web
export reports OS "Web", so `has_feature("mobile")` was always false — the
original reason mobile-web got no controls). `MobileInputHandler` reduced to a
shim; dead `touch_controls.gd` deleted; layout recomputes on `size_changed`.

**Bug I introduced and caught in-browser:** first labels used arrow glyphs
(`◄►▲▼`) which the pixel font renders as tofu — switched to ASCII `< > UP DOWN`.

Verified: a touch-enabled 844×390 Playwright context reached PLAYING via
touch alone with the overlay visible and **0 script errors**; desktop
keyboard path unchanged and the canonical `verify-game.mjs` desktop gate
passes.

## Goal 3 — control instruction surface

`how_to_play_panel.gd` — a dismissible "HOW YOU ROLL" panel showing keyboard
AND touch per action in two columns (Grok's copy, corrected to the project's
real bindings), auto-shown once on first run (persisted to `user://`),
re-openable from the menu's HOW TO PLAY button. Fits any viewport via a
ScrollContainer (an early version overflowed a 390px landscape phone and hid
GOT IT — caught in-browser and fixed). Dismiss via backdrop tap / GOT IT /
Escape. Spec: `docs/MOBILE_CONTROLS_SPEC.md`.

## Goal 4 — Distributor

Left as the open feel item from 2026-07-31. Not touched; no mobile change
forced a change to it. `distributor_behaviour` gate still ALL PASS.

## Gates
| Gate | Result |
|---|---|
| script_compile | ALL PASS — 113 scripts, 76 scenes |
| distributor_behaviour | ALL PASS |
| boss_arena_reachable | ALL PASS |
| security-sentinel | 18/18, 0 blockers |
| verify-game.mjs (desktop) | VERIFIED — boots + reaches PLAYING, 0 errors |
| mobile touch (844×390) | reached PLAYING via touch, overlay visible, 0 errors |

## Multi-model (heavy, in-role — total ≈ $0.75)
- **Grok 4.5** — 2 briefs: mobile control scheme ($0.0079) + title hierarchy /
  onboarding copy ($0.0059). Both drove the implementation.
- **Kimi K3** — 2 audits: mobile input path ($0.3544) + font/UI sizes
  ($0.3783). Findings-first; every finding was confirmed against the real
  files and either fixed or (pause menu) documented.
- **DeepSeek V4 Flash** — spec + test checklist + three-layer compliance
  ($0.0015). NOTE: the founder-specified `deepseek/deepseek-v4-flash-0731`
  is blocked by an OpenRouter account **data-policy guardrail** ("No endpoints
  available matching your guardrail restrictions") — an account-side privacy
  setting, not fixable from here. The undated `deepseek/deepseek-v4-flash`
  routed to a compliant endpoint and was used instead. Flag for the owner:
  either enable the data policy at openrouter.ai/settings/privacy or standardise
  on the undated model id.

## Three-layer compliance (DeepSeek-authored, Claude-reviewed)
1. **Intent clear / scope respected** — yes; out-of-scope systems untouched.
2. **Context loaded before implementation** — yes; Layer 2 read first.
3. **Models in role** — yes; Grok=design, Kimi=audit, DeepSeek=spec/process.
4. **Rebuild vs extend** — the touch layer was *replaced*, but it was a
   **broken** layer (dead detection, double-fire, no attack emission on the
   autoload path, no climb), not a working one — the founder's "don't rebuild
   a working layer" rule doesn't apply. The rebuild *reused* the existing
   InputMap actions and the existing per-level overlay instancing rather than
   paralleling them, and consolidated three systems into one. Menu/HUD/email
   changes were edits, not rewrites.
5. **Verdict: COMPLIANT.**

## Owner notes — what still needs a real phone/tablet in hand
- All mobile evidence here is a **browser touch-emulation** viewport
  (844×390, `hasTouch`). That proves the controls appear, fire the right
  actions, reach gameplay, and don't error — but **real finger ergonomics**
  (thumb reach to the big ATK, whether the `<`/`>` zones are comfortable,
  safe-area/notch overlap, iOS Safari address-bar resize) need a physical
  device pass. Grok's layout is a strong starting point; expect to nudge a
  couple of rects after real-hand testing.
- **Orientation:** the game forces landscape on native mobile
  (`window/handheld/orientation`); on mobile-web the player must rotate the
  phone themselves — there is no in-page "please rotate" prompt yet. Worth a
  real-device check.
- **Pre-existing dead UI (not fixed, out of scope):** `pause_menu.tscn` is
  not instanced in any level and its buttons were never connected. So there
  is currently no in-game pause/HOW-TO-PLAY access — only the main menu. A
  future session should either wire PauseMenu into the levels (and add HOW TO
  PLAY there) or remove it.
