# Episode 2 Runner — Wire Spec (Layer 2 of `ep2-layered-production`)

The numbers and beats every other layer builds on. The data lives in
`src/episode2/runner/tracks/episode2_tracks.gd`; the rules live in `runner_graybox.gd`; this
page is the human-readable contract. Change them together.

## Core loop
Lil Blunt rides a three-cart convoy through the mine at 20 → 30 m/s. He survives by hopping
between carts, jumping, ducking, shooting bear archers with the golden revolver (mouse aim,
6-round cylinder, R / auto reload) and swiping boarders with the pickaxe. **Carts are a
resource:** boulders smash them, rails end, replacements roll in on sidings. Losing every cart
derails the run.

## Numbers
| Thing | Value | Why |
|---|---|---|
| Speed | base 20–22 → max 28–30 m/s over 900 m | founder: "way too slow" at a flat 12 |
| Hop | 22 m/s lateral (~0.11 s per rail), adjacent live cart only | strategy: a dead centre splits the convoy |
| Jump | v0 12, g 36 → ~0.67 s airtime, clears at y ≥ 1.2 | clears a box at speed with ~0.2 s lead |
| Duck | held ≥ 0.10 s | arrows fly at head height |
| Revolver | 6 rounds, 0.35 s cadence, 1.3 s reload, range 60 m | shoot the archer to cancel its volley |
| Health | 3 | a hit per mistake; cart loss under you = 1 hit |
| Telegraph → punishment | ≥ 40 m | ~1.5 s to read and act at speed |

## Cart life cycle
roll → **wreck** (boulder on its rail, or rail `end`) → dead (hidden; unreachable) →
**spawn** (siding for outer rails, ore chute for the centre; previewed 26 m ahead) → roll.

## Beats (with Layer-1 references)
| Beat | Leg | z | What the player learns / decides | Reference |
|---|---|---|---|---|
| Gold line | 1 | 40–56 | pickups exist; stay centre | IMG_2478_rear_cart |
| Witness | 1 | 160 | an EMPTY cart is smashed — carts die | IMG_2497_broken-cart_bears-arrows-boulder |
| Bait | 1 | 200 | gold on the dead rail is unreachable | IMG_2497 |
| Lose yours → Split | 1 | 290 | choose left or right; the centre is gone | IMG_2492_cart-jump_bears-arrows-boulders |
| Volley | 1 | 320 | duck or shoot the bear | REF_balaclava-bear-archer_turnaround |
| Zipline | 1 | 430–470 | hook and ride; landing = decision | IMG_2479_zipline_rear |
| Post-zip boulders | 1 | 500 | hop left immediately | IMG_2480_action_jump |
| Rail ends | 1 | 680 | leave the left rail before the buffer stop | IMG_2497 |
| Chain zip | 1 | 790–836 | two cables, second jump to swing | IMG_2479 |
| Short convoy | 2 | 0 | start with only two carts | IMG_2492 |
| Only cart | 2 | 630 | one live cart, spawn arrives just in time | IMG_2497 |
| Boarder in volley | 2 | 660–670 | swipe, then duck/shoot | REF_balaclava-bear-archer_turnaround |

## Proof
`tests/ep2_runner_carts_test.gd` — the autopilot clears both legs with zero hits, a
do-nothing run fails, and each leg wrecks at least four carts. In the web build, `?ep2bot=1`
plays the same autopilot so every capture shows the intended flow.
