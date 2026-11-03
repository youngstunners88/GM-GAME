# Phase 2 license dialogue reframe (founder, 2026-11-03)

Source: Drive `PROMPT_EPISODE2_PHASE2_LICENSE_DIALOGUE_REFRAME_2026-11-03.md`
(https://drive.google.com/file/d/1q2HD_kYdlvas6i9ea4MfuvZAU4h6ixuq). It supersedes every "Gold Panner stamp gifted by Inferno ->
Mike Dean 2nd visit" line in the 2026-10-27 fix pack, the 2026-10-28 map/stables docs and the surface-to-town spec.

## Why
Phase 2 is four **Miner's License NFTs** (Prospector's -> Miner's -> Foreman's -> Mine Owner's, wBTC-backed floor, upgrade path,
perks: pre-order queue, trade-tax reduction, Builder pool weight, flip discount), **Flip bonds** (discount NOTE) and **Builder
bonds** (ETH into the Builder pool, 2,888-day positions, XAUT share). There is no "Gold Panner stamp"; Inferno gifts no paper.

## Visual lock - Certificates office
- Mike Dean at his desk **facing the entrance**.
- **Left wall** (player's left looking at Mike Dean): the **four certificates**, vertical or slight diagonal, readable during
  the talk - Prospector's, Miner's, Foreman's, Mine Owner's. No fifth "Gold Panner" item.

## Locked story order (replaces section 2 of the 2026-10-27 fix pack)
1. Bar draw (Lil Blunt wins). 2. Loot at the body (E): the gun + auction map; blood. 3. Mike Dean alarmed, prays.
4. Sheriff James -> jail -> Rich & Utah. 5. Gear + Colt Gatling test at Rich & Utah. 6. Bar with Inferno Bull. 7. They drink.
8. Inferno leaves to help Flux (kettle). **He gifts nothing**; he points Lil Blunt back to Mike Dean for a Miner's License / bond.
9. Mike Dean, 2nd visit: the license / bond conversation. 10. Mike Dean: get a horse from Dude. 11-12. Dude (BTC price, Chill
Buds, Logan's Lake first). 13. Ride, bandits. 14. Logan. 15. Downstream unchanged.

First visit: soft gate, the four licenses + bonds, no free grant. Second visit: deeper explanation + next action. The auction map
stays the bar prize. The horse is transport only.

## Dialogue (Mike Dean voice `CfxYdK3WmF3bmrvyLAiU`)
Implemented verbatim in `src/episode2/chamber/gold_town.gd`: `MINISTER1_LINES` (3.1, first visit), `INFERNO_LICENSE_LINES`
(3.2, post-drink, before Flux), `MINISTER2_LINES` (3.3, second visit). Voiced takes: `town_cert1_0..4`, `town_inferno_license_0..1`,
`town_minister2_10..14` (`assets/town-audio.json`).

## Out of scope
Interactive mint / upgrade UI for the licenses or the bond flows (the narrative pointer is enough); horse, Dude, lake, auction,
Fort Knox locks; Episode 1.

## Definition of done (hard refresh)
- [x] No Gold Panner stamp / gift prop anywhere in Episode 2 (code, voice bank, takes)
- [x] First visit: four-license + bond soft-gate lines; four certificates on the left wall
- [x] Post-draw: Mike Dean still alarms and prays (unchanged)
- [x] Inferno's post-drink line gifts no paper; points back to Mike Dean
- [x] Second visit: license / bond close + Dude referral; four certificates still visible
- [x] Story order matches section 2
- [x] Mike Dean VO id `CfxYdK3WmF3bmrvyLAiU` on the new lines (ElevenLabs, key `ELEVENLABS_OPEN_API`)
- [x] Related docs updated (2026-10-27 fix pack, surface-to-town spec)
- [ ] Founder hard-refresh playthrough
