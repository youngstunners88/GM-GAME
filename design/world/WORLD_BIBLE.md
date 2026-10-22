# Episode 2 World Bible - v0 (2026-09-30)

INTERNAL (design/). Skill: `ep2-western-world-forge`. Status: v0 outline for founder review - built places are
marked BUILT, everything else is an OUTLINE to be confirmed before it is built (build only what the next level
needs). Protocol mechanics come from canon (`design/client_protocol_updates.md`, chamber docs), never from here.

## The pitch
A western Modern Warfare. Lil Blunt - small, chill, unflappable - falls into a war over the richest gold seam on the
frontier. The mentor is **Inferno Bull**, a hulking old-school gunslinger-miner (whiskey, cigar, Winchester) who
"doesn't do sidekicks" but walks with him a stretch. The contrast is the tone: a cute, calm hero in a gritty,
gun-smoke world that he leaves a little better (the chill wins).

## Factions
| Faction | Who | Wants | Where | Notes |
|---|---|---|---|---|
| The Smelters (allies) | Inferno Bull and the old miners' crews | keep the seam honest; melt, stake, share | Smelting Facility, Fort Knox | the Bull is the mentor NPC (Price role) |
| The Bear Gangs (hostile) | balaclava bear archers, shovel bears, boarders | take the mine | the rails, the Miner Shaft, camps | MYSTERY: someone is paying them in gold - who? |
| The Tax Collectors (hostile) | greedy collectors + Compliance machines (FUD) | skim everything that moves | frontier towns, checkpoints, rail depots | approved enemy type (CLAUDE.md) |
| The Wild (hazard) | boulders, fly swarms, hostile vines | - | everywhere outdoors | never weed-themed |

## The route (play order)
| # | Region | Status | Pillar / purpose | Arrive / leave |
|---|---|---|---|---|
| 1 | **The Descent** - mine rails, 1800 m | BUILT | teaches attrition; chase | cart run -> the tracks end at the gorge |
| 2 | **The Gorge** - cliff jump | BUILT (film) | escape set piece; the cart dies, he lands on the Bull's side | film -> wakes in the facility |
| 3 | **The Smelting Facility** - Inferno Bull's smelter | BUILT (rebuilt 2026-09-30) | story: the Winchester + miner's helmet; shooter mode begins | walk out through the Fort Knox door |
| 4 | **Fort Knox** - the vault | OUTLINE (shell exists) | staking pillar (canon: goldmine_protocol_design.md) | breach & clear on arrival? |
| 5 | **Deeper Rails** | BUILT | chase, armed | cart |
| 6 | **The Miner Shaft** | BUILT (chamber) | mining/vesting pillar | cart |
| 7 | **The Gold Vein** - underground river where sweeper bots feed two pools | OUTLINE | replaces the removed Gold Rush auction (STATUS 2026-09-30) | mentor stealth through a bear camp |
| 8 | **Mine Mouth -> Frontier canyon** | OUTLINE | first time above ground; overwatch from a water tower | horseback / handcar chase |
| 9 | **The Smoke Lounge** | OUTLINE (portal room exists) | the Bull's PROMISE beat; calm hub | - |
| 10 | **Diamond territory** | OUTLINE | Diamonds pillar | - |
| 11 | **Logan's Lake** — named still-water, staging shore and day-88 outflow | Runtime `src/episode2/chamber/logans_lake.tscn`; active founder lock `design/ep2/lake/LOGANS_LAKE_LOCK.md` (2026-10-18) | Investigate / stage / protect depth; no fishing or vesting timers; separate from Town Stockpile | after Rich & Utah's gear, before the river fight |

Open for the founder: region 4-10 order, which regions are hubs, whether the frontier has a free-roam layer.

## Region cards
Built so far: see `design/world/regions/` (one card per place, template in the skill).

## Town buildings (off the main street) — LOCK 2026-10-17

`PROMPT_EPISODE2_RICH_ARMORY_UTAH_RIVER.md` locks the first off-street character location. The frontier town's main
street (Certificates office, Saloon, Hotel, Auctions, Treasury) stays as built; the following sits deliberately **off**
it.

| Building | Where | Runs it | Purpose | Status |
|---|---|---|---|---|
| **Rich's Armory** ("RICH & UTAH — ARMS") | one block off Main Street, down a side lane / alley; weathered false-front, barred windows, muted sign | **Rich** (with **Utah**) | 1800s weapon + ammunition shop; the spatial source that feeds the personal armory system | **IN GAME** (built 2026-10-17: kit piece + lane + walk-in trade; spec `design/ep2/armory/RICH_DEPARTMENT_SPEC.md`) |

- **Rich** returns from Episode 1 education (the GOLD side; "Rich the Claim Recorder", voice `LNV6ahDtkAOqwn1X3R7a`).
  He handles the sales conversation and the serious weapons. **Utah** is his partner and the river-linked character.
- The Armory is **not** the Treasury, Reserve or Fort Knox. The Treasury stays a sovereign / protocol-owned chamber
  (no weapon racks there). The town has no bears; the town already shows crypto as money (the quarter-Bitcoin whiskey).
- It is deliberately hard to find on the first visit: the Sheriff (after the draw), a townsperson (after the auction
  map) or an environmental clue points there — no giant ARMORY sign on the main drag.
- **As built (2026-10-17):** the town chamber places `Bldg_Armory` down a side lane off the left row — off the Main
  Street sightline, its own door gap, no building moved and the duel lane untouched. Behind the counter stand **Rich
  and Utah together on the first proper visit**; the trade opens at the counter (E) and sells the long rifle, boxes of
  cartridges and the river gear for **Episode 1 crypto only** (the purse Lil Blunt already carries), never a soft
  currency and never a free loadout. The room then hands him on to the day-88 river shipment.

## Day-88 river handoff (seeded at the Armory) — direction

- The day-88 pool is the **shorter, more exposed shipment moving on the river** (or a lake that narrows into one);
  it is the Fort Knox short-pool beat in place-form (canon `design/goldmine_protocol_design.md`, Pillar 2). Success =
  the shipment reaches the dock that feeds the later 288-day and 2,888-day trains.
- Lil Blunt covers the shipment from a **mountain overlook** with the **period sniper rifle bought at the Armory**,
  shooting bears that try to stop or divert it.
- The shipment rides in **river transport / packaging obtained at the Armory** (boat, kayak or sealed buoyant crates —
  exact form is for the river prompt).
- **Utah** is the river-linked Armory partner who later appears at the riverside. Whether Utah or Inferno Bull is the
  one who rides/goes with the shipment is NOT locked here.
- No invented protocol numbers: only existing whitepaper language describes the shipment.
- **As built (2026-10-17):** the long rifle and the **river gear** are both real stock in the Armory's catalogue
  (`Ep2ArmoryState.SHOP`), and buying both is what turns the town room's last beat (`GEARED`) into its hand-off —
  the day-88 river set-piece itself is not built yet.
