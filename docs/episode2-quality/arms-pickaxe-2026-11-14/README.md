# Pickaxe always usable, bow arm, Sharps left arm, auction crowd (founder P0, 2026-11-14)

Existing systems extended; nothing rebuilt. Captures are from Lil Blunt's own eye in the real town room, real web renderer
(`tools/ep2_shots/held_arms_shot.tscn`, `held_view_probe.tscn`, `weapon_tabs_shot.tscn`).

## Pickaxe
- **Key 9**, or the **pickaxe tile in Tabs** (top right; hold Tab / the holster button, point, release), or **Q** back to it. Any Episode 2
  first-person room, no purchase, no jail. Guns stay owned and loaded; 1-8 or Q returns to them.
- Fire swings it. In the **bear woods** and on the **lake trail** a swing hits what is within 2.8 m (bear, bandit, animal) with no round spent.
  In the other rooms it swings but there is nothing wired to hit yet (town, lake, ridge, auction): see residuals.
- Cause of "not usable": `Ep2ArmoryState.select()` refused the pick unless the Sheriff held the guns, no key selected it, and its swing was
  connected to nothing. The first-person model path (`pickaxe_fp.glb`) never existed, so it drew a bare orange stick with no hand; it now
  uses the founder's War Pick in his glove, already in the streamed pack (0 bytes added to the main file).
- `pickaxe_before_after.jpg`, `pickaxe_swing_before_after.jpg`, `tabs_pickaxe_tile_and_sharps_card.jpg`, `tabs_phone.jpg`.

## Bow arm
- Measured cause: the build grew the bow arm's sleeve from the **tip** of a forearm that tapers to a ragged point over its last 0.22 m, so a
  flat olive pipe started beside the arm with its open end in view. The string arm's sleeve swelled to 1.31x the wrist and read as a pole.
- Now both arms wear one sleeve in the forearm's own leafy green: the bow arm's closes over the ragged end and runs out of frame; the string
  arm has a leather wrist cuff and is no fuller than the glove's wrist. Draw, loose and re-nock are unchanged.
- `bow_rest_before_after.jpg`, `bow_draw_before_after.jpg`, `bow_full_before_after.jpg`.

## Sharps left arm and its Tabs card
- Cause: both hands were the Remington's pistol fist. The left one was that fist mirrored and left lying as on the revolver: pointing forward
  under the barrel, holding nothing, its forearm running back along the gun into the trigger hand, both arms cut 0.25 m behind the wrist.
- Now the left hand closes on the fore-end with its forearm leaving down and to his left, and both arms run out of frame in a sleeve.
  The Tabs card was a render of the old pose; it is re-rendered from the fixed view (same 640x320 file).
- `sharps_hip_before_after.jpg`, `sharps_card_before_after.jpg`.

## Auction crowd
- Each person answers a call in his own time (0-0.55 s), choosing cheer / clap / nod, about one in ten only looks on, at slightly different
  speeds. The single cheer recording has a 7 s cooldown and a small pitch change, so three calls no longer stack it three times.

## Gates
`ep2_weapons_test` (25 new checks: pick always selectable, swing counts and lands once, guns restored, Tabs tile, melee reach in the real
woods), `ep2_lake_auction_road_test` (3 new: crowd spread in time, mixed, cheer cooldown), plus bow, weapon consistency, icons, personal
armory, town law, tabs ledger, armory guns/chain/real weapons, weapon drops, residuals 11-01, lake trail, wildlife, bear attacks, tree jumps,
touch controls and script compile: all pass locally.

## Residuals (honest)
- The left hand on the Sharps is still the pistol-fist model turned to grip; it is not the open cupped hand of the Winchester (that hand is
  fused into the Winchester's mesh). A matching open hand needs a Blender pass.
- The grown sleeves are a plain leafy-green cloth, not the sculpted leaves of the forearms.
- Pickaxe melee damage is wired in the woods and on the trail only. On touch the pick is chosen from Tabs (no new HUD button was added).
- The ammo counter still shows the last gun's rounds while the pick is up.
- Not founder-verified; no phone has run it.
