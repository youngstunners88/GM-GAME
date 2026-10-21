# Jack Hammer thread - beat sheet and build plan

Locked facts: `PROMPT_EPISODE2_JACK_HAMMER_BOUNTY_HORSE_AUCTION.md`. Lines: `JACK_HAMMER_LINES.md` (code: `Ep2JackHammer`). State: `Ep2JackHammerArc`.

## Where each beat plugs into what already exists
| Beat | Existing code it hangs on | New work |
|---|---|---|
| JOB_ASK | `gold_town.gd` `Beat.WON` (the Sheriff hands him the map to the auction; `_got_map`) | a new beat `JOB` between WON and JAIL_TIP: `[E]` on the Sheriff -> the three JOB_ASK lines (timed toasts via `_start_show`) |
| BOUNTY | the Sheriff's office / a wanted-notice board (`Bldg_Certificates`, kit sign pipeline `tools/ep2_forge/paint_town_signs.py`) | one painted notice (`Ep2JackHammer.NOTICE`), a look-at prompt, the BOUNTY lines |
| JAIL_WORD | `Beat.JAIL` + `_accomplice`, `JAIL_LINES` (already a partial truth about bears) | append the two JAIL_WORD lines; the Sheriff's line already points at the cell |
| STABLE | `Ep2TownLife` horses (`src/episode2/chamber/ep2_town_life.gd`, hitch rails + grazing horse); the Episode 2 surface stable is NOT built (`gm-game-ep2-surface-set`) | a stable building/yard + one stable hand folk + a buy panel like the Armory's (`ep2_armory_shop.gd`, tender-only, no soft currency) |
| TRAIL | none - a new ride-and-shoot chamber (`Ep2Interlude`, same size class as the day-88 river mountain cover) | `ep2-horse-trail-set-piece` plans it; needs the viewmodel on a horse + bandits (`Ep2BearBrain` patterns) |
| AUCTION | the map prop; `Ep2SessionRoot` chamber chain (`"logans_lake"` is wired after the town) | an arrival chamber stub that reads `jack_hammer` from the hand-off |

## Sequencing (the lock says production decides)
Recommended: `WON -> JOB -> BOUNTY -> JAIL_TIP/JAIL (+JAIL_WORD) -> TIP/ARMORY (optional guns) -> STABLE -> TRAIL -> AUCTION`, with Logan's Lake / river / trains / Fort Knox downstream as already planned. The Armory stays optional before the horse. **Do not delete** the Armory or Logan locks; `ep2_fort_knox_arc_test` lists the town beats exactly and must be updated in the same commit as any new beat.

## State carried between rooms
`Ep2JackHammerArc.result()` -> `{"jack_hammer": {...}}` merged into the chamber result (like `jail_visited` / `investigation`). Never persisted as a balance: the horse purchase debits the Episode 1 purse through the same path as the Armory (`GameManager.spend_coins` or its BTC equivalent once the purse-unit ruling lands).

## Build order (each step shippable alone)
1. **Narrative data + arc + gate (done this pass):** `Ep2JackHammer`, `Ep2JackHammerArc`, `tests/ep2_jack_hammer_test.tscn`.
2. Job + bounty + jail word as text beats in the town (no new art except the notice) - updates `ep2_gold_town_test` and `ep2_fort_knox_arc_test`.
3. Stable yard + hand + buy panel (half a Bitcoin; refuses short tender; never free).
4. Trail set-piece (ride + shoot, unhorse pressure, fail branches).
5. Auction arrival stub, then the auction itself (a separate pass).
6. Voice + Jack Hammer's model once the founder supplies the look.
Every step: STATUS.md, the vault, the gates, `ship-to-master.sh`, and the live probe.
