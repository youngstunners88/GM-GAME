# Day-88 river cover stage (founder lock, 2026-11-04)

Lil Blunt reaches a ridge overlook. The Shipment he already bought from Rich & Utah goes into the river and drifts downstream, and he
snipes the bears that try to stop or tip it until it reaches the lower dock. It is one continuous set-piece: not a second open town,
and not a static turret.

## Character placement (hard)
| Place | Present | Never |
|---|---|---|
| Logan's Lake | Logan (liquidity talk; the horse drinks) | Rich, Utah |
| Rich & Utah's Armory | Rich + Utah (the Sharps and the Shipment are bought here) | - |
| Day-88 ridge / river | Lil Blunt on the high ground; bears on the banks and in the water; Utah at the dock | Logan, Rich |

## As built (`src/episode2/chamber/river_cover.gd`, gate `tests/ep2_river_cover_test.tscn`)
- **Chain:** at Logan's overlook, [E] resolves `next_chamber: "river_cover"`. The ridge prebuilds off screen during the shore walk.
- **Prerequisites:** both the Sharps (`sniper_owned`) and the Shipment (`river_gear`) must be owned.
  - Without the Shipment, no crate exists anywhere.
  - Without either item, the marker blocks the run. The objective names Rich & Utah's counter, and [E] at the marker ends the slice
    with `river_blocked`. No free crate is ever spawned.
- **Activation (option A):**
  - Crossing the **DAY 88 / RIVER RUN** cairn and post arms the run.
  - Standing on the first overlook and looking squarely at the launch pool for 0.5 s launches the crate.
  - "DAY-88 RUN LIVE" toast; the Tabs shipment tile pulses while the run is live.
- **Three gates:**

  | Gate | Bears | Drift (m/s) |
  |---|---|---|
  | 1 Launch pool | 2 | 1.1 while bears are on it, 2.4 once clear |
  | 2 The bend / rapids | 4 (densest) | 0.7 / 1.8 (slowest, most exposed) |
  | 3 Dock approach | 3 | 0.9 / 2.0 |

  The HUD ticks "GATE n/3".
- **Bears:**
  - They come off the banks downstream of the crate, wade in and swim at it.
  - Aboard, they heel it over. 5 bear-seconds aboard tip it.
  - The Sharps drops a bear in one shot; the other guns take two.
- **Relocates:**
  - After gates 1 and 2 the crate waits in an eddy until he drops to the next ledge overlook.
  - On each way down, one bear waits on the path and engages within 28 m. These are the short ground scrapes.
  - Ridge cover stays the main verb.
- **The one retry rule:** a tipped crate or Lil Blunt downed both lead to the same reset, never a repurchase:
  - back to the current gate's overlook;
  - the crate back where that gate began;
  - the gate's wave again;
  - full hearts;
  - the ammunition he had when the gate began.
- **Dock:**
  - Utah appears only once the dock approach is clear, and walks out onto the lower dock.
  - The crane takes the crate.
  - Utah's one short line is voiced in his ElevenLabs voice ("Got her! Day-eighty-eight's in, Lil Blunt. Clean shooting up there.").
  - Then `end_session` with `river_complete`, `gates: 3`, the losses and downs. Downstream (train / auction / Fort Knox) is unchanged.
- **One hero crate:** `Ep2ShipmentCrate.model()` serves Rich & Utah's trade case, the Tabs tile (slow Y spin) and the river.
  - It uses the founder's streamed Meshy crate, or the same procedural skiff and crates before the pack mounts.
  - It is logistics, not a firearm; jail confiscation does not touch it.
- **Music:** no new track. The trail/lake bed carries on under the river water loop.

## Definition of done
- [x] Logan's Lake is Logan only (no Rich, no Utah) - test
- [x] The Sharps and the Shipment must be owned before the ridge success path - test
- [x] The ridge marker is readable; crossing it plus holding the overlook activates the shipment in the water - test + captures 01-03
- [x] The package is seen moving through three checkpoints - test + captures 03, 06, 07
- [x] Bears threaten the package; ridge cover is the main verb, with short relocates - test
- [x] Utah is at the dock for the hand-off, not at the lake - test + captures 07-08
- [x] Soft fail / retry needs no second Armory purchase - test
- [x] The same crate mesh in the Tabs spin and the river - test
- [ ] FIXED only after the founder's hard-refresh run, ridge to dock

Captures (real renderer, `tools/ep2_shots/river_cover_shot.tscn`): `docs/episode2-quality/day88-river-20261104/`.

## Changed by the founder's notes the same day (`docs/founder-feedback/2026-11-04_shipment_and_bears.md`)
- **Geography:** the ridge continues the walk out of Logan's overlook, in the lake's own axes (`LAKE_OFFSET`). The river stays on his left, and past the dock it curves right toward the railway. The stage used to be mirrored with the river on his right. The lake, with Logan, comes along behind him (`adopt_lake`).
- **Waves:** swimmers 4 / 7 / 6, plus far-bank archers 1 / 2 / 2 and Hammer's rafts 1 / 1 / 2 (two men each). A raft hooks the crate and drains it until its men are dead. 9 bear-seconds tip it (was 5).
- **Fairness:** one gun on him at a time, a visible tell first, moving always dodges, and a man standing still is not hit by every shot. Each gate tops up the Sharps to what the wave needs.
- **Logan:** he is visible back at his lake from the climb. The "never at the ridge" rule still holds: he does not come up it.

## Texture pass (founder 2026-11-06: "texturing on the level going up the ridge ... looks very cheap")
Gameplay geometry and constants are untouched. Collision stays analytic on `RIDGE_POINTS`, and the gate passes.
- **Ridge skin:** mitred cross-sections every `RIDGE_STEP`. Surfaces: trail (`trail_packed`), grass (`slope_grass`, lake-green tint) and cliff (`cliff_layered`, world triplanar so the strata lie level). Per-segment quads overlapped at bends; that was the seam.
- **Overlooks:** timber stand, sandbag cover upstream (inside the lip) and a landmark rock on the back shoulder. Nothing sits in the view down.
- **Banks:** `_build_banks` gives each bank a wet line under the water's edge (`bank_wet`) and a dry bank (`bank_dry`) that sinks under the valley floor. It starts past the lake's ground.
- **Kit (Tripo P2, `src/episode2/extras/river/`):** `dock_warehouse.glb`, `ridge_rock.glb` (MultiMesh on the cliff, banks and rapids, plus the cairn) and `sandbag_cover.glb`.
- **Dock:** boards, stringers, piles with a waterline stain, cleats, rope, landing pad, crane, and the warehouse at `WAREHOUSE_AT`. Its doorway frames Utah's existing start point.
- **Fallback:** before the streamed pack mounts, `Ep2Pbr.available()` and `Ep2Extras.has()` are false, so the old plain set and dock are built.
- **Captures:** `tools/ep2_shots/ridge_dock_texture_shot.tscn`. Before/after pairs are in `docs/episode2-quality/ridge-dock-texture-20261106/`.
- [ ] FIXED only after the founder's hard-refresh climb and look at the dock.
