# DeepSeek V4 Flash — mobile-controls spec + 3-layer compliance + test checklist

You are the process/specs co-author for a Claude-run Godot 4.3 game session
(Lil Blunt Adventure, HTML5 export, itch.io). You replace a "Gemini 3.5
Ultra" role that does not exist on OpenRouter. Claude remains the sole
executor of commits and gates; you produce structured docs and a compliance
assessment. Be concise and concrete. Output THREE clearly-separated sections
with the exact headers below.

## What was actually built this session (all verified in a real browser)

Goal 1 — readable titles/UI: menu title 48→72, subtitle 24→32 (removed a
duplicate "THE SMOKE REALM" that rendered twice), primary buttons 28→36,
secondary column font 20→26 / 300x46→320x56, dark outlines added throughout;
HUD resource labels 20→26 + outlines (were unoutlined over gameplay art),
score 24→30, off-centre popup bug fixed (get_viewport().size →
get_visible_rect().size); email first-run panel tiny fonts bumped (blurb
14→22, inputs to 56px tall, etc.).

Goal 2 — mobile playability: the three overlapping touch systems were
collapsed into ONE. mobile_controls.gd rewritten to use `TouchScreenButton`
nodes, each bound to an existing InputMap `action` (move_left/right/up/down,
jump, dash, sprint, interact, attack). Pressing a button calls
Input.action_press(action); releasing calls action_release — so touch flows
through the SAME code paths as the keyboard (guaranteeing desktop parity) and
gets true multitouch (hold move+jump+attack). Layout is Grok's scheme: big
digital LEFT/RIGHT zones, a compact UP/DOWN pair (climbing had NO touch input
before — a hard progression blocker), and a right cluster with a big primary
ATK, JUMP above it, DASH/RUN, and a centre GRAB. Detection uses
DisplayServer.is_touchscreen_available() (the Web export reports OS "Web", so
has_feature("mobile") is always false — the old bug). MobileInputHandler
autoload reduced to a shim (get_movement_input()=Input.get_axis(...),
is_sprint_active()=action). Dead touch_controls.gd deleted. Labels are ASCII
only (the pixel font renders arrow glyphs ◄►▲▼ as tofu). Overlay relays out
on viewport resize.

Goal 3 — controls instruction: how_to_play_panel.gd — a dismissible "HOW YOU
ROLL" panel showing keyboard AND touch per action in two columns, auto-shown
once on first run (persisted to user://), re-openable from a menu button.
Fits any viewport via a ScrollContainer.

Verified: script_compile ALL PASS; distributor_behaviour ALL PASS;
boss_arena_reachable ALL PASS; security-sentinel 0 blockers; verify-game.mjs
desktop VERIFIED (boots + reaches PLAYING, 0 errors); a touch-enabled 844x390
Playwright context reached PLAYING via touch alone with the overlay visible,
0 script errors. The canonical desktop gate (verify-game.mjs) was updated to
dismiss the new first-run panel before clicking PLAY.

Kimi K3 flagged (and these were fixed): dead touch_controls.gd; detection
mismatch; double-fire from the old dual system; no up/down; resize staleness;
worst-contrast unoutlined HUD labels; the popup-centre bug.

## Facts / constraints
- Fetch-first was done; Layer 2 context (STATUS.md, src/ui/, touch scripts,
  distributor.gd, prior session logs, gdscript-gotchas.md, bootstrap-godot.sh)
  loaded before implementation.
- Multi-model used: 2 Grok briefs (mobile scheme + title hierarchy), 2 Kimi
  audits (input path + font sizes), before large implementation. You (DeepSeek)
  are the third model.
- Out of scope (not touched): PostHog, Sentry, CI infra, PixelLab, Smoke
  Lounge video, Thirdweb.
- Pre-existing gap found, NOT fixed (out of scope): the PauseMenu scene is not
  instanced in any level and its buttons were never connected — dead UI.

## Section 1 — MOBILE CONTROLS + ONBOARDING SPEC
Produce a concise spec (markdown, ~1 page) documenting the shipped design so
a future dev doesn't re-introduce the old bugs: the one-path
TouchScreenButton→InputMap-action architecture and WHY (parity + multitouch),
the detection rule, the ASCII-label constraint, the layout map, and the
first-run onboarding behaviour. Include a short "DO NOT" list distilled from
the Kimi findings.

## Section 2 — MINIMAL TEST CHECKLIST (mobile viewport + desktop parity)
A tight, runnable checklist (bullet list) a human or a Playwright script
should run after any input/UI change: what to tap/press, what must happen,
and the desktop-parity checks. Keep it to the essentials.

## Section 3 — THREE-LAYER COMPLIANCE
Assess whether this session followed Router → Workspace Context → Skills:
(1) was intent clear + scope respected; (2) was context loaded before
implementation; (3) were models used only in their roles (Grok=design,
Kimi=audit, you=spec/process); (4) any working layer rebuilt vs extended;
(5) one-line verdict: COMPLIANT / COMPLIANT WITH NOTES / NON-COMPLIANT.

## Files (the shipped implementation)
@include src/ui/mobile_controls.gd
@include src/autoload/mobile_input_handler.gd
@include src/ui/how_to_play_panel.gd
