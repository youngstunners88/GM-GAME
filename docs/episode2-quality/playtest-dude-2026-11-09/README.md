# Founder playtest preset `dude` (2026-11-09)

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

## Forward route repair (2026-11-11)

Keep the same `dude` entry. Only the pre-Dude mine/hideout/draw are skipped. **Day-88 is played**, never flagged complete at spawn.

| Link | Production requirement / finding |
|---|---|
| `start_playtest()` → town `STABLES` | Existing `playtest: dude` handoff refers the player to Dude. No missing prerequisite flag reproduced. `grant()` unchanged. |
| Dude → `GEARED` → `lake_trail` | Talk to Dude; the real horse transaction costs 2 BTC. After his conversation, walk to the saddled horse and interact to mount. Existing Shipment purchase satisfies `_after_story()`; no return to Rich required. |
| Trail → Logan's Lake | Ride out through the ranch gate along the surveyed road. Cold room creation previously dropped the shore arrival and reset held movement. It now consumes the same handoff as a prebuilt room. |
| Lake → `river_cover` | Meet Logan, hear his investigation, check the cargo once, then follow the bank uphill. No license/item gate here beyond the existing staging beat. Shipment + Sharps already satisfy the ridge's gear checks. |
| Ridge → post-day-88 lake | Cross the DAY-88 marker; look down at the launch pool from the first overlook. Fight through all three gates and relocate to the next overlooks. Utah's successful dock handoff alone sets `after_day88`. Cold handoffs now also retain held movement; the input router only resends movement when the input changes. |
| Post-day-88 lake → `auction_road` → house | The return lake opens on `ROAD` with its auction sign and drinking horse. Mount at the bank (salve first if hurt), interact at the sign, ride the road, talk at the claim wagon, hitch and enter the hall. License conversation is a soft check, never an extra unlock. |

At ridge sandbags, **C/Ctrl** toggles the existing cover; **R** reloads; fire peeks out. Touch gets one ridge-only **head-behind-bags icon** using that same toggle, shown only at an overlook, hidden on pause/transition and away from the bags. Existing touch reload and fire stay in use.

### Verification

- Extended the existing `ep2_playtest_dude_test` gate: **41 checks**, real horse purchase/mount, movement out of the ranch, lake investigation/cargo, cold shore handoff with held forward, all three day-88 gates, post-success lake/sign/horse and auction-road reachability. Existing warp, loadout, Save/Continue and normal town save checks retained.
- Travel/time and combat are accelerated in this deterministic gate; it defeats spawned threats through their production damage methods. This is reachability evidence, not a claim of a manual combat playthrough. The existing river and auction-road gates cover their detailed gameplay.
- Added touch enter/peek assertions to the existing ridge cover gate, alongside its protection, reload and walk-away checks.
- No new preset, grant path, progression flag, room, asset, menu or save format. Physical-phone confirmation remains separate from automated touch evidence.

### Local release evidence (2026-11-11)

- Pinned Godot `4.3.stable.official.77dcf97d8`, Compatibility; non-threaded release export, **zero script/parse errors**. Core pack **199,220,896 bytes**, extras **197,863,296 bytes**, both below **199,229,440 bytes**. Excluded only unused backend source, reference sprite copies and verification reports; no runtime asset additions or replacements.
- 13 selected suites passed: compile, founder preset (41), ridge, trail, lake, auction road/house, seamless chain, session root, manual checkpoint (69), save compatibility, Episode 2 touch, mobile controls and touch profiles. Security, founder title lock, harness-inert and background checks passed.
- Actual Compatibility render and GUI-delivered second-finger input: enters the existing cover once; pause hides the icon immediately; resume restores it; leaving the sandbags hides it and stands up. Gameplay camera at 1280×720 and 844×390 reviewed. [Phone-sized cover capture](evidence/ridge-touch-phone.png). This is an automated desktop touch simulation, not physical-phone verification.
- The Game Development Studio CLI and project `scripts/preflight.py` were unavailable; verification used the repository's existing Godot, export and browser tooling.
- Master export, butler upload and public BUILD verification: pending.
