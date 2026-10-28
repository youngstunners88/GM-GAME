# Episode 2 on touch — full-surface audit

**Date:** 2026-10-29 · **Branch:** `mobile/ep2-full-touch` · **Worktree:** `/data/home/mobile-ep2`
**Base:** `master` @ `575664b1` (clean at audit start and end)
**This pass changed no game code.** One document, committed on the branch.

Read-only audit of every Episode 2 surface a player can reach, measured against
`docs/MOBILE_CONTROLS_SPEC.md`, `docs/architecture/adr-mobile-touch-controls.md`,
`src/input/mobile/` and the profiles in `src/input/mobile/layouts/`.

---

## 1. How this was checked

Static reading of every Episode 2 scene script that takes input, plus every widget that can be
tapped, plus the four touch layouts and the input router. Cross-checked against
`docs/MOBILE_TEST_STEPS_2026-10-23.md` (the founder's runner / film / hideout pass) and the
`ep2-mobile-touch` skill's known-gaps list.

`instabox` box has no GPU and the web build is the only runtime, so nothing here is a device
result: it is code + geometry evidence, with the exact file and line for each claim. The fix
session must confirm on a phone (see §7).

What I verified mechanically rather than by memory:

- every `InputEventMouseButton` / `InputEventKey` / `is_key_pressed` / `mouse_entered` /
  `MOUSE_MODE` / `ui_cancel` / `has_feature("mobile")` in `src/episode2`, `src/ui`, `src/input`;
- every `Button.new` / `TextureButton` / `LineEdit` in Episode 2 (the complete widget list);
- which actions each layout actually presses (`grep 'action = &'` on all 21 layout scenes);
- every string that names a key and whether the HUD gates it on `TouchUi.keys_shown()`.

## 2. The one path, and what a touch player actually gets

`Control -> TouchActions -> InputMap action -> player`. Episode 2 never reads touch directly for
gameplay: `Ep2SessionRoot._unhandled_input` maps actions to room verbs, and the rooms never poll
raw keys. That part is sound and must not change.

Touch control sets, chosen by `Ep2SessionRoot.touch_profile()`:

| profile | when | verbs the player gets |
|---|---|---|
| `ep2_runner` | runner leg running | hop / jump / duck (swipe pad), `attack`, `ep2_touch_swipe` (pickaxe), `pause` |
| `ep2_foot` | chamber, free roam, player in control | stick, look pad, `attack`, `ep2_touch_jump`, `ep2_touch_aim`, `ep2_touch_reload`, `interact`, `sprint`, `pause` |
| `ep2_film` | skippable film | SKIP (hold ring) |
| `ep2_end` | run over | Retry (`jump`), Home (`ui_cancel`) |
| `ep2_rotate` | portrait on a touch device | rotate cue + Home |
| `none` | scripted/control-blocking beat, transition | **nothing — the manager hides and releases everything** |

Two of the defects below are profile-shaped: the Miner Shaft gets `none` where it needs a verb
set, and any control-blocking show drops the player to `none` with no PAUSE left. The shop is the
third shape — profile `ep2_foot`, correctly **suspended** like the weapon selector, but with no
touch affordance that can close it. `ep2_foot` itself has **no `dash` and no `ui_cancel`** in any
of its three variants (phone landscape, phone portrait, tablet landscape) — confirmed by grepping
the layout scenes.

## 3. Reachability first: one surface in this repo never plays

The chain `Ep2Entry` builds is `Episode2Tracks.LEGS` = `[LEG_DESCENT, LEG_DEEPER]`, but the
smelting facility clears with `next_chamber: mine_lift` (`smelting_facility.gd:158,1064`) and the
chain then runs `mine_lift -> woods_quad -> gold_town -> lake_trail -> logans_lake`, which ends the
session (`logans_lake.gd:230`). `_advance_segment()` is therefore never reached, so **leg 2
("Deeper Rails") and its chamber, the Miner Shaft, are dead code in the shipping path**. They are
reachable only by `?leg=1` or a stale save `offset` (`ep2_entry.gd:212-213,254`).

That matters for the audit: the Miner Shaft is the worst touch hole in the project, and today it
is invisible. It is listed as **P0-L latent** below, because the day leg 2 is wired in it is an
instant hard stop.

## 4. Audit table

`Touch?` = can a touch-only player do this, today, with no keyboard or mouse.
`inline code` in the Fix column = the smallest change that closes the hole.

### Entry and cross-cutting surfaces

| # | Surface | File | Input mechanism | Touch? | Minimum fix |
|---|---|---|---|---|---|
| 1 | Access-code gate (menu -> Episode 2) | `src/episode2/ep2_entry.gd:103-157` | `LineEdit` (secret) + `text_submitted`, ENTER/BACK `Button`s; `ui_cancel` to menu | **No** — a phone has no way to type; `html/experimental_virtual_keyboard` is unset (false) in `project.godot` | On-screen 0-9 keypad as Controls writing into `_gate_input.text`, or turn on the web virtual keyboard and verify on device. Keep BACK as the escape (it already works) |
| 2 | Stage 3 -> Episode 2 hand-off | `ep2_entry.gd:_enter_playing`, `TransitionDirector` | none (film + dissolve) | Yes (no input) | — |
| 3 | Pause card | `src/episode2/ep2_touch_overlay.gd` | `VirtualButton` PLAY/HOME over layer 70 | Yes | — |
| 4 | Run-over screen | `ep2_entry.gd:529` + `ep2_end` layouts | `jump` / `ui_cancel` | Yes | — |
| 5 | Portrait "turn your phone" | `ep2_rotate` layouts | cue swallows touches | Yes | — |
| 6 | Region map (M) | `src/episode2/ui/region_map.gd` | corner `TextureButton` (tap), `×` `Button` 48x48, `ui_cancel` | Yes | Enlarge `×` to 44 dp (§5 P2-1) |
| 7 | Pause availability during scripted beats | `ep2_entry.gd:224-226` | `_can_pause()` requires profile RUNNER/FOOT | **No** — during any control-blocking show the profile is `none`, so no pause and no exit (desktop presses Esc) | Suspend rather than hide the profile for timed shows, or let the pause action work while a show runs |
| 8 | Key-name strings reaching the screen | `ep2_fps_hud.gd:379-500` | `_draw` prints `objective` words even when `wordless` | **Partly** — toasts are icon-only on touch, but objectives are drawn verbatim | Gate objectives that name a key (§5 P1-2) |

### Mine runner (leg 1)

| # | Surface | File | Input mechanism | Touch? | Minimum fix |
|---|---|---|---|---|---|
| 9 | Lane hop / jump / duck | `runner_view.gd`, `virtual_swipe_pad.gd` | swipe pad pulses `move_left/right`, `jump`, `move_down` | Yes (founder-tested 2026-10-23) | — |
| 10 | Shoot (auto-aim) | `ep2_session_root.gd:971` | `attack` | Yes | — |
| 11 | Shoot at a tapped point | `ep2_session_root.gd` mouse branch | emulated tap -> `runner_fire_at_screen` | Yes (B6 in the founder's steps) | — |
| 12 | Pickaxe | `session_root` | `ep2_touch_swipe` | Yes | — |
| 13 | Pause / lose run | `ep2_touch_overlay`, `ep2_end` | `pause`, `jump`, `ui_cancel` | Yes | — |

### Cliff film and the hideout

| # | Surface | File | Input mechanism | Touch? | Minimum fix |
|---|---|---|---|---|---|
| 14 | Film skip | `ep2_video_film.gd:85,130`, `cliff_jump_cinematic.gd:769` | hold `jump` (SKIP ring) | Yes | — |
| 15 | Walk / look (hideout) | `smelting_facility.gd:799-820` | stick + `TouchActions.take_look` | Yes | — |
| 16 | Range lesson (reload / ADS / fire / jump) | `smelting_facility.gd:2835-2860` | `ep2_touch_reload`, `ep2_touch_aim`, `attack`, `ep2_touch_jump`; wordless icon path | Yes | — |
| 17 | Weapon selector (armory) | `ep2_fps_hud.gd:174-340`, `ep2_weapon_selector.gd` | raw `InputEventScreenTouch`: hold holster -> drag -> release commits | Yes | Key labels + hint words on a phone (§5 P1-3) |
| 18 | Lava run / death retry | `smelting_facility.gd` | jump, auto-respawn | Yes | — |

### Mine lift, woods, gold town, lake

| # | Surface | File | Input mechanism | Touch? | Minimum fix |
|---|---|---|---|---|---|
| 19 | Mine lift (walk onto the cage) | `mine_lift.gd:877-895` | movement only; beats auto-advance | Yes | — |
| 20 | Woods free roam / sneak | `woods_quad.gd`, `interlude_base.gd:546` | stick (analog speed), look pad | Yes | — |
| 21 | Woods cart shooting | `woods_quad.gd:1402,2152` | `attack`, `has_player_control()` stays true | Yes | — |
| 22 | Woods talk / search body | `interlude_base.gd:593`, `woods_quad.gd:1555` | `interact` (the `[E]` prompt itself is hidden on touch) | Yes | Context cue on the Interact icon (§5 P2-2) |
| 23 | Gold town free roam | `gold_town.gd`, `interlude_base.gd` | stick + look pad, `interact` for every counter/door | Yes | — |
| 24 | Armory gatling intro | `ep2_armory_intro.gd` | timer-driven show; `skip_armory_intro()` has **no callers** | Yes (it ends by itself) | Not skippable on any platform; objective says "click / [E]" (§5 P1-2) |
| 25 | **Rich & Utah's counter (shop)** | `gold_town.gd:846-867,2421-2422`, `ep2_armory_shop.gd:221-249` | tree pauses; profile stays `ep2_foot` **suspended**; `ui_cancel` is the only close, `ui_left/right` the only tender control | **No — softlock** | Wordless close pad + tappable tender (§5 P0-1) |
| 26 | Gatling mount + fire | `gold_town.gd:683-717` | `interact` mount, `attack` fires | Yes | Toast says "click to fire" but is suppressed on touch (fine) |
| 27 | Stable talk / mount horse | `ep2_stable_yard.gd:475-531`, `gold_town.gd:816-821` | `interact` -> `start_rig` | Yes | — |
| 28 | Duel (draw, then shoot) | `gold_town.gd:2124-2170` | `attack` draws on the first press, fires on the second | Yes, but tight: two taps inside 1.45 s (`OPP_REACTION`), +0.3 s per loss, capped | §5 P1-4 |
| 29 | Sheriff law / arrest / fine | `ep2_town_law.gd`, `gold_town.gd:2333-2360` | scripted escort (`blocks_control()`), auto | Yes | No pause during it (§4 row 7) |
| 30 | Loot body / crank / trade prompts | `gold_town.gd:1893-2020` | `set_search_prompt` is hidden when `not TouchUi.keys_shown()` | Verb yes, cue **no** | §5 P2-2 |
| 31 | Lake trail ride | `lake_trail.gd:695-710` | stick -> `_move_input` (analog vertical), `attack` | Yes | — |
| 32 | Lake bandit ambush | `lake_trail.gd:844,1003` | `attack`, auto-aim from the horse | Yes | — |
| 33 | Lake on-foot fallback | `lake_trail.gd:881` | stick forward ("Hold W" wording) | Yes | §5 P1-2 |
| 34 | Logan's Lake stage cargo | `logans_lake.gd:218` | `interact` -> `start_rig` | Yes | Objective names `[E]` (§5 P1-2) |
| 35 | River handoff / end screen | `logans_lake.gd:230`, `ep2_entry.gd:_on_session_complete` | none; retry/home from `ep2_end` | Yes | — |

### Not in the shipping chain (latent)

| # | Surface | File | Input mechanism | Touch? | Minimum fix |
|---|---|---|---|---|---|
| 36 | **Miner Shaft (LEG_DEEPER chamber)** | `miner_shaft.gd` (extends `Node3D`) | room verbs `interact`/`attack`/`move_down` reach it, but the router gives it no profile | **No — total dead stop** | §5 P0-L |
| 37 | Deeper Rails runner leg | `episode2_tracks.gd:189-288` | same as leg 1 | Yes (profile proven by leg 1) | — |

## 5. Ranked list

### P0 — blocks progress or softlocks a touch player

**P0-1. Rich & Utah's counter is a one-way door on touch.**
Following Episode 2's own objective ("Trade with Rich at the counter [E]"), a touch player taps
INTERACT at the counter. `gold_town._open_shop()` (`:846-859`) shows the shop and sets
`get_tree().paused = true`. The shop closes **only** on `ui_cancel`
(`ep2_armory_shop.gd:243`), and no `ep2_foot` layout has a `ui_cancel` control — the only one in
the project is on the run-over screen. The modal handling itself is right: `armory_open()` counts
`_shop_open` (`gold_town.gd:2421-2422`), so `touch_suspended()` (`ep2_session_root.gd:666-667`)
keeps the foot layout up but **inert**, exactly like the weapon selector. The defect is that the
only thing that can dismiss it is a key. Pause cannot rescue it either:
`Ep2Entry._can_pause()` also requires `not get_tree().paused` (`:224-226`). Buying does not close
it (`gold_town.buy()` never calls `_close_shop`). The player must hard-refresh the page. This is
on the critical path, not an optional side room.
*Minimum fix:* a wordless close pad inside `Ep2ArmoryShop` (48–56 dp, top-right, same drawing
language as `region_map`'s `×`) raising the existing `closed` signal. No second input path: it is
a `Control` press calling the signal the keyboard already calls. Consider letting PAUSE work
while a modal is up, so "stuck" can never mean "reload the page".

**P0-2. The access-code gate cannot be typed on a phone.**
`ep2_entry._show_gate()` (`:103-155`) is a `LineEdit` (+ ENTER/BACK buttons). The web export
never enables `html/experimental_virtual_keyboard` (absent from `project.godot`), so focusing the
field shows no keyboard. A touch-only player who has not just beaten Stage 3 boss 3 cannot enter
Episode 2 through the menu at all. The earned route is unaffected
(`GameManager.EP2_STORY_BYPASSES_CODE and ep2_story_unlocked`).
*Minimum fix:* either enable the web virtual keyboard (needs a real-device check on iOS Safari,
which is the risky one) or draw a wordless 0-9 keypad that writes into `_gate_input.text`.
Entry, not gameplay — needs your call because it changes how the code can be shared.

**P0-L (latent). The Miner Shaft has no touch controls of any kind.**
`miner_shaft.gd` extends `Node3D` and implements none of the free-roam contract:
no `set_move_input`, no `has_player_control` (`ep2_session_root.gd:676-680,802-803`). So
`touch_profile()` returns `none` (`:650-662`): no stick, no fire, no INTERACT (the rig can never
be started), no pause, and the only exit is `ui_cancel`, which no layout provides. The room does
not fail — it simply sits there forever. It is unreachable today because leg 2 is not chained
(§3), so it is not a shipping P0; it becomes one the moment "Deeper Rails" is wired in.
*Minimum fix:* give the room the free-roam contract (a no-op `set_move_input` + a real
`has_player_control`) so `ep2_foot` comes up, and add `dash` for EARLY CLAIM (or drop early claim
on touch). Do this before leg 2 ships, not after.

### P1 — playable, but parity or the founder's rules are broken

1. **The shop's tender can never change on touch.** `TENDERS` cycles only on `ui_left/ui_right`
   (`ep2_armory_shop.gd:234-238`), which no touch control presses. A player holding ETH/SOL/WBTC
   but no BTC sees "NOT ENOUGH CRYPTO" on every row and cannot fix it. If the armory beat ever
   *requires* a purchase, this is a second P0. *Fix:* make the purse strip tappable (tap cycles,
   or one chip per token) and keep the same `tender` variable.
2. **Objectives still name keys and the mouse on a phone.** The HUD draws `objective` words even
   when `wordless` (`ep2_fps_hud.gd:460-474`), and these lines are ungated:
   `gold_town.gd:621` and `:1282,1286` ("…at the counter [E]"), `logans_lake.gd:218`
   ("Check the staged cargo beside Logan [E]"), `lake_trail.gd:881` ("Hold W to follow the
   trail"), `ep2_armory_intro.gd:183` ("click to fire, [E] to step away") and `:236` ("Take the
   crank [E]"). Compare `lake_trail.gd:685`, which already does it right with
   `if TouchUi.keys_shown()`.
   *Fix:* same one-line conditional per string, or replace the objective with an icon pulse.
3. **The weapon selector writes keys on a phone.** `ep2_weapon_selector.gd:155-156` draws
   `key_label()` on every card ("1 / 2 / 3", "HOLD Tab"), `:158` writes "EQUIP ON RELEASE", and
   `:162-165` writes "Hold holster · drag to a weapon · release". The bud line two functions later
   (`:234`) is correctly gated, so this is an oversight, not a decision.
4. **The duel needs two taps inside 1.45 s.** `gold_town.shoot()` spends the first touch press on
   the draw and returns false (`:2193-2196`), so a phone has to tap twice while a desktop player
   presses ENTER ahead of the bell and only taps once. It is not a wall (each loss adds 0.3 s to
   the opponent, capped at +0.9 s), but it is a real parity gap and will read as "the duel is
   unfair on my phone". *Fix:* let the draw auto-arm at the bell, or accept the first tap for
   both, and tune on device.
5. **No pause and no exit during scripted beats.** Anything that sets `has_player_control()`
   false (shows, the gatling intro, the arrest escort) drops the profile to `none`, so PAUSE
   disappears; desktop can still press Esc. *Fix:* suspend rather than hide while a show runs, or
   keep the pause action alive with the profile.
6. **EARLY CLAIM has no touch verb.** `dash` is in `ep2_foot` nowhere; the Miner Shaft is its only
   consumer. Latent with P0-L, but list it with the fix so it does not get rediscovered.

### P2 — polish, and things to measure on a real device

1. **Target sizes under 44 dp.** Design canvas is 1280x720 (`project.godot:39-43`), so on a
   390 px-tall landscape phone one canvas unit is ~0.54 CSS px. The FPS HUD holster hold is
   92x60 canvas (`ep2_fps_hud.gd:175`) ≈ 50x32 CSS px; the region-map `×` is 48x48 canvas ≈ 26 CSS
   px; `ep2_foot`'s Reload/Aim/Interact are 28 dp radius (~56 dp across, fine); the pause card's
   HOME is 34 dp. The spec's own HUD keep-out allows 140x80 canvas for the holster, so there is
   room to grow it. Measure on the device before changing numbers.
2. **Context prompts are invisible on touch.** `Ep2FpsHud.set_search_prompt()` hides the button
   when `not TouchUi.keys_shown()` (`:228-231`), so "Take the crank", "Trade with Rich", "Mount
   horse", "Loading interrupted — Retry" never appear on a phone. The verbs still work through
   INTERACT; the player just gets no "you can do something here" cue. *Fix:* pulse or tint the
   Interact icon when a verb is in range — icon, never words.
3. `ep2_entry.gd:431-449` (the debug HUD control strip) is correctly gated by
   `TouchUi.keys_shown()`; no action, recorded so nobody "fixes" it.
4. `ep2_armory_intro.skip()` / `gold_town.skip_armory_intro()` are dead code — the gatling
   introduction cannot be skipped on any platform. If it is long, a hold-SKIP is a desktop *and*
   touch win.
5. The shop row highlight is driven by `mouse_entered` (`ep2_armory_shop.gd:48`) and by mouse motion (`:245-249`); on a phone
   the highlight trails the purchase tap by one event. Cosmetic, but it makes the shop feel
   broken. Reuse `point_at()` on press.
6. `docs/MOBILE_TEST_STEPS_2026-10-23.md` stops at the hideout. When the P0s are fixed, add the
   town / counter / duel / lake steps in the same plain-words style so the founder can accept the
   back half.

## 6. What is already correct (do not regress it)

- One path: no Episode 2 room reads `InputEventMouseButton`/`InputEventKey` for gameplay. The only
  raw input is HUD cram itself (`ep2_fps_hud`'s holster and the weapon selector), and it is
  finger-indexed with release-on-hide.
- Runner: swipe pad, attack, pickaxe, pause, portrait cue — founder-verified.
- Hideout: stick/look/fire/jump/aim/reload/interact/run, wordless lesson icons, ADS hold, auto
  reload icon.
- Film skip ring, run-over retry/home with the 0.8 s arm delay, pause card, rotate cue.
- Emulated mouse is left ON (menus need it) and filtered out of free-roam look/fire by
  `device == DEVICE_ID_EMULATION` (`ep2_session_root.gd:_route_free_roam`).
- Region map closes with a tap, not just `ui_cancel`.
- No `has_feature("mobile")` anywhere; detection is `TouchUi` only.

## 7. Proof required when this gets fixed

Per the mission, each fix lands with:

- `./scripts/ci-gates-local.sh` green, including `touch-tests.log` with
  `MOBILE_TOUCH_CONTROLS: ALL PASS`;
- `tests/mobile_touch_controls_test.tscn` green (it walks the 7-screen geometry list and the
  keep-outs, so the shop's new close pad must not sit under the ammo box);
- `tests/touch_controls_profiles_test.tscn` and `tests/ep2_touch_controls_test.tscn` green;
- desktop keyboard path unchanged — stated as a check, not a claim: replay the keyboard
  equivalents (E at the counter, Esc to leave, 1/2/3 in the armory, Enter+LMB in the duel) and
  say which gate covers each;
- pack gate green (no `.pck` growth from the audit doc or any added art).

Suggested order: P0-1 (shop close + suspend), P1-1 (tender) in the same commit area but a separate
commit, then P1-2/P1-3 (strings, one commit), then P1-5, then P0-2 (gate) once you pick the
mechanism, then P0-L when leg 2 is scheduled.

## 8. What I need from you

1. **P0-2 mechanism:** web virtual keyboard (fast, iOS risk) or a drawn 0-9 keypad (safe, more
   code)? I will not guess on the entry gate.
2. **Is a purchase at Rich's counter required to leave the armory beat?** If yes, P1-1 (tender)
   must ship in the same pass as P0-1 or the shop is still a wall for a player with no BTC.
3. **P0-L now or when leg 2 ships?** It is ~30 lines plus a dash control; doing it now means the
   first time "Deeper Rails" is switched on, a phone is not bricked.
