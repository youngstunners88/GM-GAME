# Weapon tabs, pickaxe, shop order, bow forearm, Sharps scope, Rich at the case (2026-11-07)

Branch `claude/ep2-weapon-tabs`. Gate `tests/ep2_weapons_test.tscn` (48 checks, in CI). ADR `docs/architecture/adr-ep2-weapon-tabs-mystery.md`.
Captures here are from the real Compatibility renderer, in SubViewports on the Wayland display (no xvfb).

## The seven questions (skill ep2-build-logic), item by item

### 1. Bow, the string hand's forearm
1. Before he earns it: n/a (the bow's own look).
2. First thing needed: a forearm that reads as an arm in a sleeve at full draw.
3. Rows, tabs and ids: none. The draw shape keys, the nock empties (`Nock_Rest`/`Nock_Full`), the tip anchors and the RightHand origin (the nock) are untouched.
4. Companion item: n/a.
5. Model: the existing streamed `extras/bow/founder_bow.glb`. Nothing new is shipped. The forearm is built at load time (`Ep2BowView._founder_forearm`).
6. Credits: **0**. The free fix was enough, so the Tripo account was never opened.
7. Proof: `bow/BEFORE_*` against `bow/AFTER_*` and `bow/AB_forearm_closeup.jpg`, at two-thirds and full draw.

**Diagnosis:** it is the forearm shape, not the glove or the string. `build_founder_bow.py` grows a 0.9 m sleeve from the glove's cut. That sleeve is a straight 14-sided frustum that widens slightly (taper 1.12), has every UV on one texel and a flat olive colour. At full draw it is a smooth, even pole across the lower right of the frame. The glove and the string read fine.
**Fix:** that one surface (`SleeveCloth`) is dropped from the string hand's mesh. In its place a forearm is grown from the same cut and axis, following `_add_sleeve`: a rolled leather cuff at the wrist, the sleeve swelling over the forearm, three soft folds that bunch near the cuff, mottled olive cloth (the bow arm's own sleeve shades) and a woven normal. It is 0.95 m long, so its end never reaches the screen; 0.62 m showed its end at two-thirds draw.

### 2. The pickaxe tab
1. Before he earns it: he never earns it. It is his own miner's tool from Episode 1 (see the decision below).
2. First: it shows from the start.
3. `WEAPON_TABS` gains `{key: Ep2ArmoryState.PICK, label: "PICKAXE", row: "", model: showcase/war_pick_held.glb}`. No shop row and no save id are added.
4. Companion item: none (no ammo).
5. Model: `extras/armory/showcase/war_pick_held.glb`, the founder's 500 KB Verdant War Pick (5,999 triangles, streamed). The contact sheet `pickaxe/` shows it renders right, as a pick in Lil Blunt's green glove. The 62 MB Meshy file was not used.
6. Credits: 0.
7. Proof: `tabs/3_pickaxe_tab.jpg`; gate section "THE PICKAXE TAB".

**Smallest correct approach for "a tab needs a row":** a tab whose `row` is `""`. Choosing it puts the pick in the case, captioned "PICKAXE · IN HAND", and the highlight stays on the row it was on. Moving the highlight hands the case back to that row. A "PICKAXE" shop row would have listed something nobody sells, which the build-logic rule forbids.

**Decision: the pickaxe counts as acquired from the start.** Its tab shows on a new save and never leaves. Why, from the code:
- `Ep2ArmoryState.PICK` is "an equipped mode while the Sheriff holds the irons, never a fourth slot". It is never in `owned` and never in `held`.
- `confiscate_firearms()` puts it in his hands.
- The Sheriff's release line is "Your irons stay with me while you're in my town. **Take your pick** and walk soft."
- It is his Episode 1 mining tool, and no row sells it.

### 3. Tabs show only what he has (the mystery rule)
1. Before earning: nothing. On a new save the counter strip shows WINCHESTER and PICKAXE (the town starts with the hideout's Winchester), and Tabs shows one card. No other gun is named anywhere: "SOLD AT RICH & UTAH'S", "NOT YET ACQUIRED" and "RECOVER FROM AN ARCHER" are gone, and the BEAR ARROWS line waits for a bow or an arrow.
2. First: the gun he carries.
3. Changed: `Ep2ArmoryShop._tabs()` (filtered by `tab_owned`, and by the model existing in the extras) and the lazily-built tab buttons; `Ep2WeaponSelector.shown_ids()`/`card_slot()` and its cards. A confiscated gun's tab and card leave until he has it again. The quick-switch key of a gun he does not have does nothing and shows nothing, as before. No ids changed.
4. A "_held" tab follows its gun.
5. A tab whose model is not loadable is not shown (`Ep2Extras.has`).
6. Credits: 0.
7. Proof: `tabs/1,2,6,8,9` and the gate's sections NEW SAVE, BUYING, CONFISCATION.

### 4. Rich & Utah's counter order
1. Before earning: rows may show (a shop shows what is for sale), behind SHIPMENT FIRST and SHARPS FIRST.
2. First: THE SHIPMENT, then the BUFFALO GUN (`sniper`), then SHARPS CARTRIDGES (`sniper_ammo`).
3. Rows moved only: every id unchanged (pinned in the gate).
4. Each gun has its ammo directly under it. After the Sharps, the guns follow the story order: the Winchester (hideout), the Remington (the armed runner leg), the bow (an archer's body in the woods), the Borchardt (the stranger at the draw), then the counter-only Lever Shotgun, Drum SMG and Golden Thompson.
5. n/a.
6. 0.
7. Proof: `tabs/2_new_save_counter.jpg`; gate section COUNTER.

**Order, read top to bottom:** SHIPMENT (the story gate) · BUFFALO GUN (opens every other gun) · SHARPS CARTRIDGES · GM LEVER RIFLE · REPEATER CARTRIDGES · GOLDEN BTC REVOLVER · SIXGUN CARTRIDGES · GM BOW · GM ARROWS · BORCHARDT PISTOL · 7.65 BORCHARDT · LEVER SHOTGUN · BUCKSHOT SHELLS · DRUM SMG · 9MM SNAIL DRUMS · GOLDEN THOMPSON · .45 DRUMS. The lock chain is unchanged and still passes: SHIPMENT FIRST, then SHARPS FIRST for unowned guns, and ammo for a carried gun stays on sale.

### 5. The Sharps scope (founder add-on: "too long")
The tube goes from 0.56 m to **0.36 m**, rebuilt with `tools/ep2_forge/build_scoped_sharps.py --tube-len 0.36 --rings -0.09,0.045`:
- The rings move to the tang and the receiver, as on a period Malcolm mount; before, one sat out on the barrel.
- The eyepiece position and axis height do not move (scope_eye 0.0915 / -0.22), so the aimed lens view and its eye anchor are unchanged.
- The showcase copy (the tab, and the one in Rich's case and hand) is rebuilt the same way. Its body is byte-identical in extent, so Rich's measured grip points still hold (`ep2_rich_grip_test` passes).
- `ep2_weapon_consistency_test`'s "long period sight 0.45-0.60 m" check now pins 0.30-0.40 m, the founder's new call.

Proof: `scope/BEFORE_side.jpg` against `scope/AFTER_side.jpg`, and `scope/AFTER_in_case.jpg`.

### 6. Rich takes the Sharps out of the glass (founder add-on: "not tacky")
**Diagnosed** in the real renderer (`takeout/BEFORE_*`):
- Rich stood behind the case's end, 0.65 m to its side.
- His Reach clip reached away from the case; his hand got no closer than 0.7 m to the glass.
- At 1.3 s the procedural kit rifle vanished through the closed glass, and a different model appeared at his hip.

**Now** (`takeout/AFTER_*`, gate section CASE):
- The case's glass is four walls and a lid of its own (`build_armory2.py`, piece `Arm2_CaseLid`, hinged on the far edge). The rebuilt Armory is otherwise unchanged; the unchanged script reproduced the shipped file to within triangle order.
- One rifle (the scoped showcase Sharps) lies in the case, and it is the one he holds.
- Rich steps to a new spot beside the case. Standing (not bent double), his right hand lifts the lid by its brass pull, takes the grip and raises the rifle clear of the glass. He brings it to his chest, where his left hand takes the fore-end. Only then does it go onto his hand bone.
- Putting it back is the reverse, and he shuts the lid with his hand.
- The arms are solved (`Ep2ArmIK`, now taking Rich's UE bone names); the timing lives in `Ep2ArmoryIntro` and the pose in `Ep2SharpsCase`.

## Family findings (reported, not fixed)
- The bow arm's own grown sleeve (bottom left at the hip) is the same flat frustum as the old string forearm.
- On a landscape phone (844x390), Tabs' "LOADED / RESERVE" line runs past its card, and the Shipment tile label overlaps PURSE. The card widths are unchanged by this work.
- `ep2_weapon_consistency_test` is not in CI (`export-game.yml`).
- Putting the Sharps back, the stock passes close to Rich's hat brim for a few frames (`takeout/frame_b_06`).
- The kit's procedural Sharps (`armory_kit.py`, built into `armory2.glb` and `sharps_1874.glb`) still has the 0.56 m tube. It is hidden in the case now; `sharps_1874.glb` is unchanged and is used only as a fallback.
- An ammo row for a gun he does not own shows its price, greyed, with no reason given.

## One fix outside the four items, and why
`Ep2FpsHud` read `Ep2WeaponSelector.ICONS[armory.equipped]`. While the Sheriff holds the irons, `equipped` is `pickaxe`, which has no icon, so every frame raised a SCRIPT ERROR and aborted the HUD update. This was seen in `weapon_tabs_shot`. It is now `ICONS.get(...)`: one line, in the tabs path this work changes.
