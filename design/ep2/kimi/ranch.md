# Kimi packet: Dude's ranch - Dude can be talked to, wears glasses, rides a horse; his assistant brushes horses and moves hay; more horses, a water trough, trees; Dude sells the horse for BTC and offers his Chill Buds

You are working in a Godot 4.3 GDScript project (Episode 2 of a first-person Western shooter, web export, **Compatibility
renderer**). Claude reviews every hunk, runs the gates and commits; write production code, not sketches.

## Founder's words (2026-10-27)
- "I love the position of the ranch but i wasnt able to speak with Dude for some reason. We also need more trees around his ranch
  and we should have him interacting more with the horse. He should be able to get on a horse and ride it a bit and his assistant
  should be brushing other horse and moving hay around. There should actually be more horses slightly with a watershed kind of a
  shindig."
- "Dude needs to wear glasses and he needs to offer Lil Blunt some weed. The weed acts as more health for Lil Blunt that he stores
  in his tabs section that he can activate. Dude even sells weed so this gives Lil Blunt the opportunity to buy more."
- Story (locked order): Mike Dean sends Lil Blunt to his friend Dude at the stables. "He speaks with Dude and introduces himself
  saying Minister told him to get a horse here. Dude negotiates a price in BTC ... Dude tells Lil Blunt to 1st go to Logan's lake
  so that his horse can get refreshed in the heat. Logan's lake is on the map." The horse is transport only (no staking, LP or
  "horse protocol" product).
House rule: weed content is positive, chill and good for Lil Blunt; no dealer or stereotyped drug imagery. The item is
"Dude's Chill Buds" (already in the game: `GameManager.chill_buds`, `add_chill_buds(n)`; H in the Tabs panel smokes one for a heart).

## Why Dude could not be talked to (found by Claude - verify)
1. The ranch (`Ep2StableYard`, `STABLE_POS` (-16, 0, 1222)) is on the quad road ~180 m before the town (TOWN_Z 1400), where the
   **woods chamber** (`src/episode2/chamber/woods_quad.gd`) is still the live room: it steps the stable yard, but its E action
   (`start_rig`) only searches bear corpses - it never calls `_stable_yard.try_talk()` - and it shows no "Talk to Dude" prompt.
2. In the **town chamber** (`src/episode2/chamber/gold_town.gd`), `try_talk()` emits `voice_line_requested("dude_greet_01", ...)`
   and the chamber `_speak()`s that id - a placeholder with no recording and no caption ("Placeholder id only"), so pressing E
   only made Dude stop and turn. There is no conversation at all.

## What exists (read the included files)
- `src/episode2/chamber/ep2_stable_yard.gd`: the set (barn facade sprite, fences with a 6 m east gate at x = -4, z 1218-1224),
  `actors` [Dude, assistant] (`Ep2TownFolk`, rigged clips idle/walk/run/turn/jump), 5 horses (`HORSES`, the 5th walks a
  strip: `horses.size() == 5` logic in `step()`), `_solid()` props, `can_talk/try_talk`, `step(delta, player, quiet)`,
  `snapshot/restore` (the woods hand the yard's state to the town). `DUDE_VOICE := "Pe1gOSDKAuczOZqgCiEm"`.
- Horse model `res://src/episode2/assets/town/horse.glb` (clips horse_stand / horse_graze / horse_walk), the assistant and Dude
  rigs stream from the extras pack.
- Captions + voice: in the town, `_caption_steps([[WHO, text], ...])` + `_start_show(steps, blocks_control)` caption a line and
  play its recording when `Ep2TownVoiceBank` has that speaker+text (`_town_speaker(who)` maps "DUDE" etc.; add "DUDE" ->
  "dude" there if missing). The woods have their own show/caption path (read `interlude_base.gd` `_start_show`). New lines go in
  `assets/town-audio.json` `lines` (`{"id", "speaker", "text"}`); add `voices.dude` with `"voice_id": "Pe1gOSDKAuczOZqgCiEm"` if
  it is missing. Claude generates the audio after your change; never edit `src/episode2/audio/town_voice_bank.gd`.
- Purse: `GameManager.purse_balance/purse_spend` and `Ep2ArmoryState.ARMORY_TENDER` (the whole purse pays at Rich's).
- Trees: the woods build trees (`woods_quad.gd` `_build_forest_primitive` / MultiMesh trunks and crowns) - reuse that look; no
  new large textures or models (the main pack has ~0.6 MB of headroom).
- Water: `res://src/episode2/art/water_river.gdshader` (the river) can shade a small trough surface.

## Build
1. **Talk works in both rooms.** In the woods: E near Dude calls the stable yard's conversation and the HUD shows "Talk to Dude
   [E]" (keys hidden when `TouchUi.keys_shown()` is false), exactly like the town; the conversation's state travels in
   `snapshot()/restore()` so walking on into the town keeps it.
2. **The conversation** lives in `Ep2StableYard` (state machine + its lines), the chambers only display it:
   - before the Minister's referral: a friendly greeting (2-3 lines: he is Dude, these are his horses, he sells to folks with
     business, "the Minister knows me"); he offers one free Chill Bud for the road (`add_chill_buds(1)`, once per game) with a
     chill line; after that he sells buds: 2 buds for 1 BTC (any purse token per `ARMORY_TENDER` order if no BTC), repeatable;
   - after `set_referred(true)` (Claude calls it at Mike Dean's second visit): LIL BLUNT introduces himself - the Minister told
     him to get a horse here; Dude names a price in BTC (2 BTC), a short haggle line, the deal: `purse_spend` (tender order as at
     Rich's); if the purse is short, Dude lets him take the horse on credit "until the auction" and records
     `GameManager.dude_credit_btc` (saved with the purse) - never a soft-lock; then Dude: go first to Logan's Lake so the horse
     can drink and cool down in the heat - it is on the map. Emit `horse_bought(paid: int, credit: int)`;
   - every line is spoken (caption + recording when present) - 14-20 short lines total in Dude's laid-back voice; Lil Blunt's
     lines under speaker `lil_blunt`. Never repeat the whole greeting on a second E; give a short "anything else?" instead.
3. **Glasses** on Dude: a procedural pair (two thin round rims, a bridge, temples; dark metal; lenses faintly tinted), on a
   `BoneAttachment3D` of his Head bone, sized and placed from the head bone's measured position (no floating, no clipping into
   the face) - check it in his idle and walk.
4. **Dude rides a bit**: every ~60-90 s (when Lil Blunt is not talking to him) Dude walks to a saddled horse, mounts (a seated
   riding pose built procedurally from his skeleton the way `src/episode2/actors/ep2_drink_pose.gd` builds SitDrink: thighs
   apart and forward, knees bent, hands forward to the reins), rides a short loop inside the paddock at a walk (the horse plays
   horse_walk, its speed matched), dismounts where he mounted and goes back to his routine. He never rides through a fence,
   the barn, the assistant or the player.
5. **The assistant's chores**: brushing (stands at a horse's flank, a brush prop in hand, a procedural stroking arm loop built
   from her skeleton, `hay_rustle.ogg`/brush sound subtly) and moving hay (carries a hay bale prop from a stack to the feeder or
   trough with both hands, walks back) - alternating, never standing idle for more than ~10 s.
6. **More horses + a trough**: 8 horses total (the existing 5 + 3 at the trough/feeder), varied clips and phases (never in
   lock-step), solid like the others; a wooden water trough with a water surface by the barn where horses drink now and then
   (`water_trough.ogg` quietly); keep the 5th horse's walking strip or move it cleanly if the layout needs (update the
   `horses.size() == 5` logic to name that horse instead of counting).
7. **Trees**: 20-30 trees around the ranch (behind and beside the paddock and barn, a few by the trough), in the woods' style,
   none inside the paddock's gate approach (`ACCESS_CLEAR`), on the road, or blocking the facade's view from the road.
8. **Gate** `tests/ep2_ranch_test.gd` + `.tscn` (root Node, script attached; print `EP2_RANCH: ALL PASS` or `EP2_RANCH: N
   FAILURE(S)`; `get_tree().quit(failures)`):
   - in the WOODS chamber and in the TOWN chamber: walk Lil Blunt through movement input (not placing him) from the road through
     the east gate to Dude; the prompt appears; E starts the conversation (a caption with DUDE's text; a voice request with
     Dude's voice id);
   - before referral: the greeting + the free bud once (chill_buds +1, never twice); buying buds (+2 buds, -1 BTC);
   - after `set_referred(true)`: the deal debits 2 BTC exactly once and emits `horse_bought(2, 0)`; with a short purse the credit
     path emits `horse_bought(0, 2)` and records `dude_credit_btc`; the Logan's Lake line is said;
   - Dude has a glasses node under a BoneAttachment3D of his head bone, within 0.2 m of the head;
   - in 3 simulated minutes Dude mounts, rides (his position moves with a horse along the loop) and dismounts; the assistant
     brushes and carries hay; 8 horses; a trough; >= 20 trees within 45 m of STABLE_POS and none in `ACCESS_CLEAR`;
   - snapshot/restore keeps the conversation state from the woods to the town.
9. Keep `tests/ep2_stable_yard_test.gd`, `tests/ep2_gold_town_test.gd`, `tests/seamless_chain_test.gd`,
   `tests/ep2_tabs_ledger_test.gd` passing unchanged unless an assertion is about the old placeholder (then say which and why).

## Rules
GDScript for Godot 4.3: typed variables, `##` doc comments on public functions, no new autoloads, no project.godot edits,
nothing that needs Forward+. No new large assets (procedural or reused meshes only). Weed content stays positive and chill.
Never change existing dialogue text, line ids or voice ids. Keep every existing public signature; keep each file's indentation
(game_manager.gd uses 4 spaces, Episode 2 files tabs). Change existing files only with exact SEARCH/REPLACE edits; new files
as whole files. Then a short NOTES line: the causes you confirmed, what changed per file, what the gate covers.

@include src/episode2/chamber/ep2_stable_yard.gd
@include src/episode2/chamber/woods_quad.gd
@include src/episode2/chamber/gold_town.gd
@include src/episode2/chamber/interlude_base.gd
@include src/episode2/actors/ep2_town_folk.gd
@include src/episode2/actors/ep2_drink_pose.gd
@include src/autoload/game_manager.gd
@include assets/town-audio.json
@include tests/ep2_stable_yard_test.gd
