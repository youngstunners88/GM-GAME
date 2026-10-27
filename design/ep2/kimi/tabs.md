# Kimi packet: the Tabs panel becomes Lil Blunt's ledger (runner BTC at Rich's, bear tally, Dude's buds as stored health)

You are working in a Godot 4.3 GDScript project (Episode 2 of a first-person Western shooter). Claude reviews your files, runs the
gates and commits them; write production code, not sketches.

## Founder's words (2026-10-27)
- "when the player decides to start in episode 2 they are still collecting btc in the tunnel of the runner section thus it should
  reflect when he goes to see Rich. i wasnt able to buy one this round of play testing."
- "Everytime Lil Blunt shoots a bear it has to tally up on his tabs section so that the tabs section becomes a data center."
- "Dude ... needs to offer Lil Blunt some weed. The weed acts as more health for Lil Blunt that he stores in his tabs section that he
  can activate. Dude even sells weed so this gives Lil Blunt the opportunity to buy more."
House rule: weed content is always positive, chill and good for Lil Blunt (no aggressive or stereotyped drug imagery). Call the item
"Dude's Chill Buds" (one bud = one item).

## What exists (verified by Claude; read the included files)
- **The runner bug (root cause found):** `src/episode2/runner/runner_graybox.gd` counts the tunnel coins in `_gold` (reset in setup on
  every run / retry), emits `gold_collected`, and the runner HUD shows "BTC N" (`runner_view.gd`). NOTHING credits them to the purse,
  so Rich (`GameManager.purse_balance("btc")`, `Ep2ArmoryState.SHOP` prices 1-3 BTC) never sees them. The run ends on
  `chamber_reached`, handled once by `Ep2SessionRoot._on_chamber_reached()` (`src/episode2/session/ep2_session_root.gd`).
- **Purse:** `src/autoload/game_manager.gd` `purse_balance / purse_add / purse_spend`, `PURSE_TOKENS`, the save/load of the purse.
  NOTE: game_manager.gd is indented with 4 spaces; the Episode 2 files use tabs. Keep each file's own indentation.
- **Bears:** woods kills arrive in `Ep2WoodsQuad._on_bear_died(br)` (`src/episode2/chamber/woods_quad.gd`, `br.get_meta("killed_by")` is
  "player" when Lil Blunt shot it). Runner kills: `runner_graybox.gd` signals `archer_down(id)` and `shovel_bear_down(index)`.
- **Health in Episode 2 is per room:** the woods keep `_health` (HEALTH_MAX 3, `_hurt()`), the base `Ep2Interlude` reports
  `get_health()` to the HUD (`health_max = 3`). The 3-heart cap is a story lock: a bud restores ONE heart and never goes above 3.
- **Tabs:** `src/episode2/chamber/ep2_weapon_selector.gd` (`Ep2WeaponSelector`, the leather-and-brass panel held open with Tab, opened
  by `src/episode2/chamber/ep2_fps_hud.gd`), already draws a purse strip from `GameManager.purse_balance`.

## Build
1. **Runner BTC to the purse, exactly once per finished run:** in `_on_chamber_reached()` credit `GameManager.purse_add("btc", n)` with
   the run's `get_gold()`; a retry or a failed run credits nothing; record the credited amount (e.g. `GameManager.runner_btc_credited`)
   so a re-entered handler cannot pay twice. Starting Episode 2 straight from the menu must work the same.
2. **Bear tally:** in GameManager, `bear_tally: Dictionary` (kind -> count) + `bear_total()` + signal `bear_tallied(kind, total)`,
   `tally_bear(kind)`; call it for every bear Lil Blunt kills - woods (`killed_by == "player"` only; use the bear's kind/role from
   `br.p` if there is one, else "bear"), runner archers ("archer") and shovel bears ("shovel"). Save and load it with the purse.
3. **Chill Buds:** in GameManager `chill_buds: int`, signal `chill_buds_changed(n)`, `add_chill_buds(n)`, `take_chill_bud() -> bool`;
   saved with the purse. In `Ep2Interlude` add `use_chill_bud() -> bool`: calls a new virtual `_heal_one() -> bool` (base: false); it
   only spends a bud when `_heal_one()` healed. Implement `_heal_one()` in `Ep2WoodsQuad` (`_health < HEALTH_MAX` -> +1, HUD updated).
   Rooms without health say so with the HUD toast ("ALREADY FEELING CHILL") and keep the bud.
4. **The Tabs ledger:** in `Ep2WeaponSelector` add a ledger band under the purse strip: BEARS total and per kind, CHILL BUDS count with
   the hint "H - SMOKE A BUD" (hide key names when `TouchUi.keys_shown()` is false), and the runner BTC credited this run if any. In
   `ep2_fps_hud.gd`, while the panel is open, H (`KEY_H`, physical) calls the room's `use_chill_bud()` (find how the HUD reaches the room;
   do not add an InputMap action and do not edit project.godot).
5. **Gate** `tests/ep2_tabs_ledger_test.gd` + `.tscn` (root Node; print `EP2_TABS_LEDGER: ALL PASS` or `N FAILURE(S)`; quit(failures)):
   runner credit once (call the handler twice -> one credit); a fresh purse + a 3-coin run lets Rich's shop take the 3-BTC Sharps
   (use `Ep2ArmoryState` / the town chamber's `buy()` as the game does); a player bear kill in the woods tallies, a Bull kill does not;
   runner archer + shovel signals tally; buds: 2 buds, woods at 2/3 -> use -> 3/3 and 1 bud; at 3/3 -> refused, bud kept; save/load
   round-trips tally and buds; the selector draws headless without errors. Reset GameManager state between cases.

## Rules
GDScript for Godot 4.3, typed variables, `##` doc comments on public functions, no new autoloads, no project.godot edits, nothing that
needs Forward+ (the web build is Compatibility). Do not change anything outside the items above; keep each file's style. Answer with
whole files in the required format, then a short note: what you changed per file and what the test covers.

@include src/autoload/game_manager.gd
@include src/episode2/chamber/ep2_weapon_selector.gd
@include src/episode2/chamber/ep2_fps_hud.gd
@include src/episode2/chamber/interlude_base.gd
@include src/episode2/chamber/woods_quad.gd
@include src/episode2/runner/runner_graybox.gd
@include src/episode2/session/ep2_session_root.gd
@include src/episode2/chamber/ep2_armory_state.gd
@include src/episode2/chamber/gold_town.gd
@include tests/ep2_armory_guns_test.gd
