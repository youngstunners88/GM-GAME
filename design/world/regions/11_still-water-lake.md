# Still Water - the quiet lake (still_water)            status: outline (proposal for founder review, 2026-10-16)
Protocol pillar taught here: Pillar 1 GOLD Mining (100-day linear vesting, early-claim forfeiture, 20% Diamond burn)
and Pillar 2 Fort Knox (short/long pool). Canon: design/goldmine_protocol_design.md Pillars 1-2 (Phase 1 only).
FREEZE: no Pillar 5 certificates / SWF tiers (Phase 2, Rich is revising - client_protocol_updates.md). No
CONFIDENTIAL items in any player text. No real addresses. No invented tokenomics, numbers come from the constants.

Who made it: an old oxbow the river cut off from the rail line long before the mine opened. The smelter crews
dammed the outlet once to cool the furnaces and gave up; the water has been rising by itself ever since.
Who lives here now: nobody. A boat that nobody finished, a dock with a few planks, a heron, frogs, and a horse that
wandered off a ranch. It is the only place on the frontier where nothing is trying to collect from you.
How the player changes it: by being patient. The lake is the whitepaper made into a place - it pays out what you
let it vest, and punishes grabbing early (see Metaphor table). Lil Blunt leaves with a different understanding of
why the Bull never hurries, not with a new weapon.

Geography / ecology: a bowl valley two ridges behind the frontier town, reached by a goat track from the town's
back lane. Reeds, willows, mist at dawn, still black water that mirrors the sky. Far, low, on the one open side:
the rail line, and on it the GoldMine train (black + brass 4-4-0, GM medallion) - tiny, silent, on schedule.
Signature landmark: the dock at the centre, the water line marked on a wooden pole with 100 notches (the vesting
pole), and the train's plume crawling along the far horizon.
Time of day / weather: dawn to golden hour compressed (a slow sun-arc as the player lingers); light mist; no wind.
Factions present: none. Hostiles: none (calm beat - never two set pieces in a row). The Wild is absent on purpose.
Mystery left open: who is leaving the lit lantern on the dock each night.

THE TRAIN MUST EXIST (founder lock). It is visible as a distant silhouette + plume on the horizon rail line, heard as
a whistle every N minutes (data-driven), and its smoke reflects in the water. Asset: `src/assets/models/goldmine_train/`
(sprite_prop_train-goldmine_512.png for the far layer, glb for any nearer pass). It never comes close and cannot be
boarded here. It is the clock of the hurried world; the lake is the opposite clock.

## Metaphor table (whitepaper element -> thing the player sees/does)
| Whitepaper element (Phase 1 constant) | In the lake | Player verb |
|---|---|---|
| Mint GOLD, 100-day linear vesting at 1%/day (MINER_VESTING_DAYS = 100) | The vesting pole: the water climbs one notch per "day" (compressed to minutes of play). A gold lantern-light follows the waterline. | Wait, fish, listen. Time itself is the reward. |
| Early claim forfeits unvested tokens | Dipping the bucket before the notch: water spills back, some leaves the lake (visible ripple loss). Player sees exactly what impatience costs. | Choose: scoop now (less) or wait (all) |
| Permanent 20% Diamond burn on mint (DIAMOND_BURN_PCT) | One in five diamond shards dropped in is not recovered - it sinks and becomes a glow on the lakebed that stays. | Drop shards; accept the permanent sink |
| Fort Knox short pool 60% / long pool 40% (day 88 / day 288) | Two basins joined by a sluice: the near pool (60) fills sooner, the far pool (40) fills later. | Open the sluice early or late |
| Max-term bonus 100% (MAX_TERM_BONUS_PCT) | If the player stays through the whole sun-arc, the lantern lights the dock and the far pool glows (one cosmetic reward, no stat). | Stay |
Rule: the lake NEVER shows token balances, prices or yield numbers in prose. It teaches the SHAPE of the incentives
(time rewards, impatience costs, a permanent sink), exactly as the Translation Philosophy says.

## Narrative role
- Where in the route: a CALM hub between the bar draw (surface-to-town lock) and the Fort Knox approach. It does not
  alter any existing lock; Bull is absent here (the established pattern: he is not present for every situation).
- Beat: after the draw, Lil Blunt is told by someone (the sheriff's witness line, or the horse) that the "map to the
  auction" can wait until the water is right. He goes to the lake, not to the auction. The train passing on the far
  rail line is what he would be riding if he hurried.
- The Bull's promise beat stays in the Smoke Lounge (region 9). This is the beat that sets up WHY the promise matters.

## Missions (verb - set piece - calm beat)
1. WALK + OBSERVE (new verb: patience) - the vesting pole fills; no timer is shown, only the water line.
2. A single choice set piece - scoop early vs. wait, with a visible consequence (no fail state).
3. Calm beat - the horse comes to the dock; Lil Blunt can sit. Leave when ready (no gate).

## Assets (founder models first, per ep2-meshy-studio rule zero)
Goldmine train (exists). Horse: `src/assets/sprites/horse_*.png` (walk 8f, graze 6f, stand) are now the photoreal AssetFurnace horse; the rigged GLB
(`src/assets/models/horse/assetfurnace/horse_rigged.glb`, clips walk/graze/stand) is for a 3D pass (2026-10-16). Needed: water shader (planar
reflection of sky), reeds/willow kit, dock + unfinished boat, vesting pole, heron, frog + night-insect loops,
whistle SFX (train far), wind-less ambience bed. Budget: web export, pck gate < 190 MiB (ep2-local-export.sh).

## Hand-offs
Arrive: walk - the town's back lane -> goat track (a short runner-free walk, no loading black: ep2-no-blackouts).
Leave: the same track back to town, or a ridge path toward Fort Knox once the sun-arc completes.

## Gates (ep2-layered-production)
Wire spec -> `design/ep2/lake/WIRE_SPEC.md` (to write) with solvability = "every path completes; no fail state".
Illustration -> founder target image needed (none yet). Imagery/3D/motion layers follow. Proof = real capture vs
reference (ep2-reference-match-loop), not a screenshot of a mockup.
