class_name Episode2Tracks
extends RefCounted
## Episode 2 runner LAYOUT — pure data, no logic.
##
## Each leg is one runner stretch that ends at a chamber's entrance. The session
## root plays leg N, then the chamber, then leg N+1: "once he completes a chamber
## stage he gets back into the miner cart to survive enough to go to the next
## chamber" (founder, 2026-09-23).
##
## Why a .gd and not a .json: the web export's include_filter ships only two
## named JSON files (.github/workflows/export-game.yml). A track .json would be
## silently MISSING from the live build while every headless test stayed green —
## exactly the "works in tests, broken live" class this repo keeps documenting.
## A const in a script always ships. Edit the numbers here; no logic lives in it.
##
## Units: z is metres along the track. Speed ramps 20 → 30 m/s over 900 m, so
## early on 20 m ≈ 1 s and late in a leg 30 m ≈ 1 s. Leave >= 40 m (~1.5 s) between
## a telegraphed hazard and the one that punishes the answer to it.
## Lanes: 0 = left rail, 1 = centre, 2 = right; -1 = "whichever cart the rider
## is in" (boarders only). Archer side: -1 left, +1 right.
## Hazard verbs: box = JUMP, arrow = DUCK (or SHOOT its archer once armed),
## boulder = HOP to another cart, boarder = SWIPE (pickaxe: F / right-click).
## Zipline = JUMP to hook it; chained cables need a second JUMP near the end of
## each to swing to the next.
##
## CART ATTRITION (founder, 2026-09-27): a boulder SMASHES the cart on its rail
## whether you are in it or not; a smashed rail stays dead until a "spawn" rail
## event rolls a fresh cart in from a siding. An "end" rail event is a buffer
## stop: that rail's cart is destroyed there. Hops only reach an ADJACENT live
## cart, so losing the centre cart splits the convoy. No live cart = derailed.
## Design rule: every boulder/end must leave at least one live cart the rider
## can REACH in time; ep2_track_solvability_test plays every leg to prove it.
## "gold" = pickup (collected by passing through), used as bait toward risk.

## Leg 1 — THE DESCENT (~1800 m, ~70 s). Teaches attrition: first you WATCH a
## cart die, then you lose your own, then the convoy splits and a rail ends.
## Founder 2026-09-30: "it needs to be longer ... the end of it must lead to a cliff that has a gap to the
## other side where Inferno Bull is situated". 960-1800 m adds the Gallery, a second shovel line, a chain
## and THE RUNAWAY, and the tracks run out at the cliff edge (chamber_z): the cliff-jump film takes over
## (src/episode2/cinematic/cliff_jump_cinematic.gd, played by the Smelting Facility).
const LEG_DESCENT := {
	"name": "The Descent",
	"armed": true,
	"chamber_z": 1800.0,
	"ends_at_cliff": true,
	"speed": {"base": 20.0, "max": 28.0},
	"carts_start": [true, true, true],
	"start_lane": 1,
	"archers": [
		{"id": "d_a1", "z": 320.0, "side": 1},
		{"id": "d_a2", "z": 560.0, "side": -1},
		{"id": "d_a3", "z": 930.0, "side": 1},
		{"id": "d_a4", "z": 1060.0, "side": -1},
		{"id": "d_a5", "z": 1380.0, "side": 1},
		{"id": "d_a6", "z": 1640.0, "side": -1},
	],
	"rail_events": [
		{"z": 240.0, "lane": 2, "type": "spawn"},   # right rail rebuilt from a siding
		{"z": 400.0, "lane": 1, "type": "spawn"},   # centre rail back: the convoy rejoins
		{"z": 600.0, "lane": 1, "type": "spawn"},
		{"z": 610.0, "lane": 2, "type": "spawn"},
		{"z": 680.0, "lane": 0, "type": "end"},     # left rail hits a buffer stop
		{"z": 760.0, "lane": 0, "type": "spawn"},
		{"z": 770.0, "lane": 2, "type": "spawn"},
		{"z": 1170.0, "lane": 1, "type": "spawn"},  # centre back after the Gallery boulder
		{"z": 1340.0, "lane": 0, "type": "spawn"},  # both outer carts back after the landing boulders
		{"z": 1345.0, "lane": 2, "type": "spawn"},
		{"z": 1590.0, "lane": 0, "type": "spawn"},
	],
	"obstacles": [
		# Warm-up: a gold line down the centre, then two jumps.
		{"z": 40.0, "lane": 1, "type": "gold"},
		{"z": 48.0, "lane": 1, "type": "gold"},
		{"z": 56.0, "lane": 1, "type": "gold"},
		{"z": 90.0, "lane": 0, "type": "box"},
		{"z": 120.0, "lane": 1, "type": "box"},
		# WATCH a cart die: a boulder down the EMPTY right rail smashes that cart.
		{"z": 160.0, "lane": 2, "type": "boulder"},
		# ...and the gold on the right rail is now out of reach.
		{"z": 200.0, "lane": 2, "type": "gold"},
		{"z": 208.0, "lane": 2, "type": "gold"},
		# LOSE yours: a boulder down the centre. Left or right (respawned at 240)?
		{"z": 290.0, "lane": 1, "type": "boulder"},
		# The convoy is now SPLIT (no centre cart): whichever side you chose, you
		# stay there. A full volley: duck or shoot.
		{"z": 320.0, "lane": 0, "type": "arrow", "archer": "d_a1"},
		{"z": 320.0, "lane": 1, "type": "arrow", "archer": "d_a1"},
		{"z": 320.0, "lane": 2, "type": "arrow", "archer": "d_a1"},
		{"z": 360.0, "lane": 0, "type": "box"},
		{"z": 360.0, "lane": 2, "type": "box"},
		# THE SHOVEL LINE: three bears across every rail, shovels raised. No rail, hop, jump or duck
		# gets past them - the zipline (430-470) goes over their heads. That is the zipline's job.
		{"z": 452.0, "lane": 0, "type": "shovels"},
		{"z": 452.0, "lane": 1, "type": "shovels"},
		{"z": 452.0, "lane": 2, "type": "shovels"},
		# Zipline over the pit; it drops you on the centre cart (back since 400).
		# Right after landing, boulders on centre AND right: hop LEFT, now.
		{"z": 500.0, "lane": 1, "type": "boulder"},
		{"z": 500.0, "lane": 2, "type": "boulder"},
		{"z": 535.0, "lane": 0, "type": "gold"},
		{"z": 543.0, "lane": 0, "type": "gold"},
		{"z": 560.0, "lane": 0, "type": "arrow", "archer": "d_a2"},
		{"z": 560.0, "lane": 1, "type": "arrow", "archer": "d_a2"},
		{"z": 560.0, "lane": 2, "type": "arrow", "archer": "d_a2"},
		{"z": 640.0, "lane": -1, "type": "boarder"},
		# The left rail ENDS at 680: get off it (centre is back since 600).
		# Then a boulder down the right: stay centre — it's the only cart left.
		{"z": 720.0, "lane": 2, "type": "boulder"},
		{"z": 745.0, "lane": 1, "type": "gold"},
		# The chain (790-836) lands you in the centre: nothing for 50 m (founder 2026-10-01: the 2nd
		# zipline "kills Lil Blunt" - the landing used to be a box 24 m on and a volley 20 m after it).
		{"z": 885.0, "lane": 1, "type": "box"},
		# Last volley covers left + centre only: hop right, or duck, or shoot.
		{"z": 930.0, "lane": 0, "type": "arrow", "archer": "d_a3"},
		{"z": 930.0, "lane": 1, "type": "arrow", "archer": "d_a3"},
		{"z": 955.0, "lane": 0, "type": "gold"},
		{"z": 955.0, "lane": 1, "type": "gold"},
		{"z": 955.0, "lane": 2, "type": "gold"},
		# --- THE GALLERY (960-1200): the cavern widens, archers on both walls.
		{"z": 980.0, "lane": 1, "type": "gold"},
		{"z": 988.0, "lane": 1, "type": "gold"},
		{"z": 996.0, "lane": 1, "type": "gold"},
		{"z": 1030.0, "lane": 0, "type": "box"},
		{"z": 1030.0, "lane": 2, "type": "box"},
		{"z": 1060.0, "lane": 0, "type": "arrow", "archer": "d_a4"},
		{"z": 1060.0, "lane": 1, "type": "arrow", "archer": "d_a4"},
		{"z": 1060.0, "lane": 2, "type": "arrow", "archer": "d_a4"},
		# Centre smashed: hop to a side (both outer carts live since 760/770).
		{"z": 1110.0, "lane": 1, "type": "boulder"},
		{"z": 1150.0, "lane": -1, "type": "boarder"},
		# --- SECOND SHOVEL LINE (1200-1340): only the zipline (1230-1275) clears it.
		{"z": 1255.0, "lane": 0, "type": "shovels"},
		{"z": 1255.0, "lane": 1, "type": "shovels"},
		{"z": 1255.0, "lane": 2, "type": "shovels"},
		# The zipline drops you on the centre cart (back since 1170); both outer rails die under you.
		{"z": 1315.0, "lane": 0, "type": "boulder"},
		{"z": 1315.0, "lane": 2, "type": "boulder"},
		# --- VOLLEY + CHAIN (1340-1520)
		{"z": 1380.0, "lane": 1, "type": "arrow", "archer": "d_a5"},
		{"z": 1380.0, "lane": 2, "type": "arrow", "archer": "d_a5"},
		{"z": 1500.0, "lane": 0, "type": "gold"},
		{"z": 1500.0, "lane": 1, "type": "gold"},
		{"z": 1500.0, "lane": 2, "type": "gold"},
		# --- THE RUNAWAY (1520-1800): full speed, the last gauntlet, then the rails run out.
		{"z": 1545.0, "lane": 0, "type": "boulder"},
		{"z": 1580.0, "lane": 1, "type": "box"},
		{"z": 1610.0, "lane": -1, "type": "boarder"},
		{"z": 1640.0, "lane": 0, "type": "arrow", "archer": "d_a6"},
		{"z": 1640.0, "lane": 1, "type": "arrow", "archer": "d_a6"},
		{"z": 1690.0, "lane": 1, "type": "gold"},
		{"z": 1700.0, "lane": 1, "type": "gold"},
		{"z": 1710.0, "lane": 1, "type": "gold"},
		{"z": 1720.0, "lane": 1, "type": "gold"},
	],
	"zip_segments": [
		{"start_z": 430.0, "end_z": 470.0},
		# Chain: jump to hook, jump again near the end to swing on.
		{"start_z": 790.0, "end_z": 812.0},
		{"start_z": 818.0, "end_z": 836.0},
		{"start_z": 1230.0, "end_z": 1275.0},   # over the second shovel line
		# Chain over the pit after the volley.
		{"start_z": 1420.0, "end_z": 1440.0},
		{"start_z": 1446.0, "end_z": 1464.0},
	],
	# CHAMBER 0 — the Smelting Facility: a story set-piece, so it mints nothing
	# (no gold_principal, no bears).
	"chamber": "smelting_facility",
}

## Leg 2 — DEEPER RAILS (~1180 m). Starts a cart short (right rail empty) and
## never gives the convoy back for long: bait gold toward rails about to die,
## boarders inside volleys, and one stretch where a single cart carries you.
const LEG_DEEPER := {
	"name": "Deeper Rails",
	"armed": true,
	"chamber_z": 1180.0,
	"speed": {"base": 22.0, "max": 30.0},
	"carts_start": [true, true, false],
	"start_lane": 1,
	"archers": [
		{"id": "r_a1", "z": 60.0, "side": 1},
		{"id": "r_a2", "z": 300.0, "side": -1},
		{"id": "r_a3", "z": 580.0, "side": 1},
		{"id": "r_a4", "z": 670.0, "side": -1},
		{"id": "r_a5", "z": 820.0, "side": 1},
		{"id": "r_a6", "z": 1040.0, "side": -1},
	],
	"rail_events": [
		{"z": 150.0, "lane": 2, "type": "spawn"},
		{"z": 200.0, "lane": 1, "type": "spawn"},
		{"z": 360.0, "lane": 0, "type": "spawn"},
		{"z": 530.0, "lane": 1, "type": "spawn"},
		{"z": 560.0, "lane": 2, "type": "end"},
		{"z": 600.0, "lane": 0, "type": "spawn"},
		{"z": 700.0, "lane": 1, "type": "spawn"},
		{"z": 705.0, "lane": 2, "type": "spawn"},
		{"z": 890.0, "lane": 0, "type": "spawn"},
		{"z": 1000.0, "lane": 1, "type": "spawn"},
		{"z": 1005.0, "lane": 2, "type": "spawn"},
	],
	"obstacles": [
		{"z": 60.0, "lane": 0, "type": "arrow", "archer": "r_a1"},
		{"z": 60.0, "lane": 1, "type": "arrow", "archer": "r_a1"},
		{"z": 60.0, "lane": 2, "type": "arrow", "archer": "r_a1"},
		# Centre smashed with the right rail still empty: left is the only way.
		{"z": 110.0, "lane": 1, "type": "boulder"},
		# Bait: gold on the right rail you can no longer cross to.
		{"z": 170.0, "lane": 2, "type": "gold"},
		{"z": 178.0, "lane": 2, "type": "gold"},
		# Left dies at 240; the centre is back since 200.
		{"z": 240.0, "lane": 0, "type": "boulder"},
		{"z": 270.0, "lane": 1, "type": "box"},
		{"z": 270.0, "lane": 2, "type": "box"},
		{"z": 300.0, "lane": 1, "type": "arrow", "archer": "r_a2"},
		{"z": 300.0, "lane": 2, "type": "arrow", "archer": "r_a2"},
		{"z": 330.0, "lane": -1, "type": "boarder"},
		# After the chain, boulders on left + centre: hop RIGHT.
		{"z": 470.0, "lane": 0, "type": "boulder"},
		{"z": 470.0, "lane": 1, "type": "boulder"},
		{"z": 500.0, "lane": 2, "type": "gold"},
		{"z": 508.0, "lane": 2, "type": "gold"},
		# The right rail ENDS at 560: centre is back at 530 — take it.
		{"z": 580.0, "lane": 0, "type": "arrow", "archer": "r_a3"},
		{"z": 580.0, "lane": 1, "type": "arrow", "archer": "r_a3"},
		{"z": 580.0, "lane": 2, "type": "arrow", "archer": "r_a3"},
		# The centre is the ONLY cart; left rolls in at 600, just in time.
		{"z": 630.0, "lane": 1, "type": "boulder"},
		# Boarder inside a volley: swipe it, then duck/shoot.
		{"z": 660.0, "lane": -1, "type": "boarder"},
		{"z": 670.0, "lane": 0, "type": "arrow", "archer": "r_a4"},
		{"z": 670.0, "lane": 1, "type": "arrow", "archer": "r_a4"},
		# Full convoy again at 705 — then both outer carts die: centre.
		{"z": 750.0, "lane": 0, "type": "boulder"},
		{"z": 750.0, "lane": 2, "type": "boulder"},
		{"z": 780.0, "lane": 1, "type": "box"},
		{"z": 820.0, "lane": 0, "type": "arrow", "archer": "r_a5"},
		{"z": 820.0, "lane": 1, "type": "arrow", "archer": "r_a5"},
		{"z": 820.0, "lane": 2, "type": "arrow", "archer": "r_a5"},
		# SECOND SHOVEL LINE, under the long cable: the zipline again is the only way through.
		{"z": 880.0, "lane": 0, "type": "shovels"},
		{"z": 880.0, "lane": 1, "type": "shovels"},
		{"z": 880.0, "lane": 2, "type": "shovels"},
		# Off the zipline onto the centre, boulder: the left cart arrived at 890.
		{"z": 930.0, "lane": 1, "type": "boulder"},
		{"z": 955.0, "lane": 0, "type": "gold"},
		{"z": 963.0, "lane": 0, "type": "gold"},
		{"z": 975.0, "lane": -1, "type": "boarder"},
		{"z": 1040.0, "lane": 1, "type": "arrow", "archer": "r_a6"},
		{"z": 1040.0, "lane": 2, "type": "arrow", "archer": "r_a6"},
		{"z": 1080.0, "lane": 0, "type": "boulder"},
		{"z": 1120.0, "lane": 1, "type": "box"},
		{"z": 1150.0, "lane": 1, "type": "gold"},
		{"z": 1150.0, "lane": 2, "type": "gold"},
	],
	"zip_segments": [
		# Three-cable chain over the pit — the set piece of the leg.
		{"start_z": 395.0, "end_z": 412.0},
		{"start_z": 418.0, "end_z": 432.0},
		{"start_z": 438.0, "end_z": 452.0},
		{"start_z": 860.0, "end_z": 900.0},
	],
	# First PROTOCOL chamber — the Miner Shaft vesting mechanic.
	"chamber": "miner_shaft",
	"gold_principal": 1000,
	"bears": [{"z": 4.0}, {"z": -6.0}],
}

## Play order. Each leg ends at a chamber; after the last chamber the session ends.
const LEGS: Array = [LEG_DESCENT, LEG_DEEPER]
