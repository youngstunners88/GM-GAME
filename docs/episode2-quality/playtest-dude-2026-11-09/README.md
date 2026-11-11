# Founder playtest presets `dude`, `auction`, `day88_ridge` (2026-11-09, extended 2026-11-11)

| Preset | Where you land | Then |
|---|---|---|
| `dude` | the gold town at Dude's stables (described below) | buy the horse, ride the lake trail |
| `auction` | Logan's Lake **after day-88** (Utah has the Shipment): the horse is at the water, the AUCTION GROUNDS signpost is up beside you | mount the horse, ride to the signpost, interact: the road, the auction grounds and the hall follow as one room |
| `day88_ridge` | the overlook above the river, Shipment bought, Sharps in hand | walk to the marker and launch the Shipment |

All three give the same gear (below). `auction` and `day88_ridge` change no room content: they enter the room through the session's
Continue path with the handoff a save of that moment would carry (`{"after_day88": true}` for the lake).

**How to enter (2026-11-11):**
- Desktop, itch page: press **F3**, then **F8** (dude), **F9** (auction) or **F2** (ridge) - or click the button row F3 puts at the top-left.
- Phone / tablet, itch page: tap the **top-left corner of the screen five times quickly**; the same three buttons appear. Tap one.
  Five more corner taps hide the row.
- The game's own URL: `?playtest=dude`, `?playtest=auction`, `?playtest=day88_ridge`.
- A save at the warped lake is a normal after-day-88 lake checkpoint: Continue opens there again with the signpost up.

The rest of this page is the original `dude` write-up.

Starts Episode 2 in the gold town at Dude's stables, on the Minister's referral beat (`STABLES`), fully geared.
Code: `src/episode2/session/ep2_playtest.gd` (`Ep2Playtest`). Gate: `tests/ep2_playtest_dude_test.tscn` (in CI).

## How to enter
| Where | How |
|---|---|
| itch page `https://youngstunners88.itch.io/smokerealm` | press **F3** (debug overlay on), then **F8**. Press F3 again to hide the overlay. |
| the game's own URL (the itch iframe `https://html-classic.itch.zone/html/<build>/index.html`) | add `?playtest=dude` |

`https://youngstunners88.itch.io/smokerealm?playtest=dude` does **not** reach the game: itch embeds the build in an iframe
(`referrerpolicy="origin"`) and never forwards the page's query. The F3 then F8 chord is the stable route on the itch page.
The Episode 2 access code still applies (a device that has entered it once goes straight in).

## What you get (production systems only)
- Every Episode 2 gun owned and unlocked through `Ep2ArmoryState.restore`: GM Lever Rifle (Winchester 1886), Golden BTC Revolver,
  GM Bow, Lever Shotgun, Drum SMG, Golden Thompson, Borchardt Pistol, Buffalo Gun (Sharps). The pickaxe tab is always owned.
  The Colt Gatling is not stock (never sold) and is not included.
- Ammo: each gun loaded full + **2000 in reserve** (the save's `RESERVE_CAP`, so it survives Save/Continue). The bow has 999 arrows.
  There is no refill: 2000 rounds per gun is effectively unlimited for a test.
- The Shipment (`river_gear`) and the Sharps are bought, so after Dude's horse the town goes straight to GEARED and the horse can be mounted.
- On the web the warp first waits for `ep2_extras.pck` (Dude and his stable hand are streamed; about 30 s in a test browser), logging `[PLAYTEST] waiting for the streamed extras (Dude)`.
- Purse topped up to **64 BTC** (`GameManager.purse_add`), the region map owned. Prices are unchanged.

## Save / Continue
- A save in the warped town carries `"playtest": "dude"`; Continue opens at Dude's again with the saved gear.
- Saves anywhere else (trail, lake, ridge, auction) are normal checkpoints.
- The preset applies once per page load: Quit + Continue in the same page is a normal Continue; refreshing a `?playtest=dude` page warps again.
- The gear and BTC go into that device's save. A new Episode 2 run from the cliff clears the armory as always; the BTC stays in the purse.

## Without the preset
Nothing changes: no menu, pause or HUD element; a normal town save still opens on the STREET beat (gated).

## Follow-ups (not built)
Preset `lake_trail` (the ride itself; today it is `dude` + buy the horse + mount).
