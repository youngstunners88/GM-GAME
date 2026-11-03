---
name: ep2-armory-new-stock
description: Add a new gun (or any sellable item) to Rich & Utah's Armory end to end - Blender model + icon, firing profile, shop row, quick-switch slot, first-person hands, report sounds, the spinning showcase - and the Chill Bud patch shop built on the same cabinet. TRIGGER on "more weapons", "add a shotgun / SMG / Thompson / MP18", the showcase/spin in the armory, a new purchasable, or the weed/Chill Bud patch.
---

# New Armory stock

The founder's 2026-11-01 request added the **coach gun**, **Bergmann MP18** and **golden Thompson** and asked that the highlighted
weapon "appear and spin slowly in the form of a showcase". Follow the same path for any future gun.

1. **Model + icon** - `tools/ep2_blender/build_armory_new_guns.py` (headless Blender only):
   `blender -b --factory-startup -P tools/ep2_blender/build_armory_new_guns.py -- --which all --icons --samples 24`.
   Frame: muzzle -Y, up +Z, trigger at origin (= game muzzle +Z). Real size. Icons 640x320, muzzle left, green mitten hands
   (the card set must stay consistent with the Winchester/Remington/bow icons). Darken wood toward the reference photos.
   Keep the GLB/PNG `.import` presets identical to the folder's (`compress/mode=1`, quality 0.85) - they are tracked on purpose.
2. **State** - `Ep2ArmoryState`: id const, `IDS` (slot order = keys 1..6), `NAMES`, `START_RESERVE`, `PROFILES`
   (capacity, cycle, reload, kick, `automatic`, `drum`, `pellets`/`hit_scale`), `SHOP` row + ammo row, `SHOP_GUNS`/`SHOP_AMMO`.
   Full auto is the session's `_hold_trigger()` (held LMB with pointer captured, or the touch `attack` action).
3. **View** - `Ep2ArmoryGunView`: GLB + `Ep2ViewHands._arm` hands on `grip`/`fore` anchors, metas `hip_offset`, `ads_cam` (eye on
   the rear/front sight line), `muzzle`, `shot_sounds`. Built lazily on first equip.
4. **Sounds** - ffmpeg from existing recordings into `src/assets/sounds/` (short, -1 dB peak, mono 96k).
5. **Town** - `gold_town._deliver` handles `SHOP_GUNS`/`SHOP_AMMO` generically. Selector shows 3x2 (desktop) / 2x3 (phone).
6. **Showcase** - `Ep2ArmoryShop` draws the highlighted row's gun (or the gun its ammo feeds) in an own-world SubViewport, 0.55
   rad/s, rendering only while open. Short screens get a scrolling window with brass ▲/▼ (touch), wheel and Up/Down.
7. **Bud patch** - `Ep2BudPatch` (bed outside Dude's east fence, `STOCK`) + `Ep2BudPatchShop` (same cabinet, Chill Bud plant in
   the case). `gold_town.buy_buds_at_patch` debits the purse then `GameManager.add_chill_buds` - never free.
8. **Gate** - `tests/ep2_founder_residuals_1101_test`, `ep2_personal_armory_test`, `ep2_armory_guns_test`, `ep2_tabs_ledger_test`.
   Watch the main pack budget (`scripts/pack-gate-fresh.sh`, 190 MiB).

## Founder's plants in the patch (2026-11-02)
`Ep2BudPatch.PLANTS` (streamed, `Ep2Extras.PATCH_*`) replaces the drawn stand-ins one load per `upgrade_step`. Shrink with `tools/ep2_forge/meshy_prop_to_game.py`.
Meshy foliage is loose thin leaves: `gltfpack -sa`, Meshy remesh and even thinning all shredded the Grove, so it stays at 47k with a draw distance. ALWAYS look at a contact sheet (Verdant War Pick is a pickaxe, not a plant) and capture in the real town (`tools/ep2_shots/patch_town_shot.tscn`): a test set hid a pine standing on the bed and backlit purple reading brown (`LEAF_GLOW`).

## Weapon tabs and the unlock chain (2026-11-03)
`Ep2ArmoryShop.WEAPON_TABS` is one tab per supplied model (`extras/armory/showcase/`, built with `meshy_prop_to_game.py ... solid`); a tab previews and moves the highlight, it never buys. `Ep2ArmoryState.lock_note` is the one chain rule (Shipment, then Sharps, then the guns), read by the panel and `GoldTownChamber.buy()`; `river_gear` and `sniper_owned` are its saved state. Gate `tests/ep2_armory_chain_test.tscn`; capture `tools/ep2_shots/armory_tabs_shot.tscn` (renders in a SubViewport, because the window manager overrides the window size).
Tripo GLBs carry a marker icosphere and an armature and are unwelded: use `solid`, and look at a contact sheet.
