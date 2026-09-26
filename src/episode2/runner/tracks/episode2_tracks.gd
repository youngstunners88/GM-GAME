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
## Units: z is metres along the track; RUN_SPEED is 12 m/s, so 12 m ≈ 1 second.
## Lanes: 0 = left rail, 1 = centre, 2 = right; -1 = "whichever cart the rider
## is in" (boarders only). Archer side: -1 left, +1 right.
## Hazard verbs: box = JUMP, arrow = DUCK (or SHOOT its archer once armed),
## boulder = HOP to another cart, boarder = SWIPE (pickaxe: F / right-click).
## Zipline = JUMP to hook it; chained cables need a second JUMP near the end of
## each to swing to the next.

## Leg 1 — THE DESCENT. Armed from the start: the golden revolver is Lil
## Blunt's own gun (founder, 2026-09-26), so every volley here can be answered
## by ducking OR by shooting its archer. The leg ends at Chamber 0, the Smelting
## Facility. It teaches the movement verbs one at a time, each introduced alone
## with ~3 s of warning before any combination.
const LEG_DESCENT := {
	"name": "The Descent",
	"armed": true,
	"chamber_z": 330.0,
	"archers": [
		{"id": "d_a1", "z": 138.0, "side": 1},
		{"id": "d_a2", "z": 236.0, "side": -1},
		{"id": "d_a3", "z": 300.0, "side": 1},
	],
	"obstacles": [
		# JUMP — first one off-centre, so holding the middle rail survives it.
		{"z": 34.0, "lane": 0, "type": "box"},
		{"z": 66.0, "lane": 1, "type": "box"},
		# HOP — a boulder down your rail; nothing but another cart saves you.
		{"z": 100.0, "lane": 1, "type": "boulder"},
		# DUCK — a full volley across all three rails, so the only answer is duck
		# (or shoot the bear).
		{"z": 138.0, "lane": 0, "type": "arrow", "archer": "d_a1"},
		{"z": 138.0, "lane": 1, "type": "arrow", "archer": "d_a1"},
		{"z": 138.0, "lane": 2, "type": "arrow", "archer": "d_a1"},
		# Combo: the zipline drops you on the centre rail — straight into two
		# boulders. Hop left, the only clear cart.
		{"z": 212.0, "lane": 1, "type": "boulder"},
		{"z": 212.0, "lane": 2, "type": "boulder"},
		# Volley again, other side of the track.
		{"z": 236.0, "lane": 0, "type": "arrow", "archer": "d_a2"},
		{"z": 236.0, "lane": 1, "type": "arrow", "archer": "d_a2"},
		{"z": 236.0, "lane": 2, "type": "arrow", "archer": "d_a2"},
		# Final approach: jump, then a two-rail volley (safe lane = hop to it OR duck).
		{"z": 285.0, "lane": 1, "type": "box"},
		{"z": 300.0, "lane": 0, "type": "arrow", "archer": "d_a3"},
		{"z": 300.0, "lane": 1, "type": "arrow", "archer": "d_a3"},
		# BOARDER — a bear leaps onto YOUR cart (lane -1 = whichever cart you're in).
		# Only the pickaxe swipe (F / right-click) knocks it off.
		{"z": 320.0, "lane": -1, "type": "boarder"},
	],
	"zip_segments": [
		# ZIPLINE — one cable to learn the catch.
		{"start_z": 165.0, "end_z": 190.0},
		# ZIPLINE CHAIN — jump to hook, jump again to swing to the next cable.
		{"start_z": 250.0, "end_z": 262.0},
		{"start_z": 268.0, "end_z": 278.0},
	],
	# CHAMBER 0 — the Smelting Facility: a story set-piece, so it mints nothing
	# (no gold_principal, no bears).
	"chamber": "smelting_facility",
}

## Leg 2 — DEEPER RAILS. Armed. Every volley has a second answer: shoot its
## archer before it looses. Hazards arrive tighter and in combinations.
const LEG_DEEPER := {
	"name": "Deeper Rails",
	"armed": true,
	"chamber_z": 360.0,
	"archers": [
		{"id": "r_a1", "z": 60.0, "side": 1},
		{"id": "r_a2", "z": 118.0, "side": -1},
		{"id": "r_a3", "z": 170.0, "side": 1},
		{"id": "r_a4", "z": 250.0, "side": -1},
		{"id": "r_a5", "z": 318.0, "side": 1},
	],
	"obstacles": [
		# First armed volley — shoot the bear or duck, your call.
		{"z": 60.0, "lane": 0, "type": "arrow", "archer": "r_a1"},
		{"z": 60.0, "lane": 1, "type": "arrow", "archer": "r_a1"},
		{"z": 60.0, "lane": 2, "type": "arrow", "archer": "r_a1"},
		{"z": 88.0, "lane": 1, "type": "boulder"},
		{"z": 88.0, "lane": 2, "type": "boulder"},
		{"z": 118.0, "lane": 0, "type": "arrow", "archer": "r_a2"},
		{"z": 118.0, "lane": 1, "type": "arrow", "archer": "r_a2"},
		{"z": 118.0, "lane": 2, "type": "arrow", "archer": "r_a2"},
		{"z": 140.0, "lane": 0, "type": "box"},
		{"z": 140.0, "lane": 2, "type": "box"},
		# Boulder into a volley: hop first, then shoot/duck.
		{"z": 158.0, "lane": 1, "type": "boulder"},
		{"z": 170.0, "lane": 0, "type": "arrow", "archer": "r_a3"},
		{"z": 170.0, "lane": 1, "type": "arrow", "archer": "r_a3"},
		{"z": 170.0, "lane": 2, "type": "arrow", "archer": "r_a3"},
		{"z": 250.0, "lane": 0, "type": "arrow", "archer": "r_a4"},
		{"z": 250.0, "lane": 1, "type": "arrow", "archer": "r_a4"},
		{"z": 250.0, "lane": 2, "type": "arrow", "archer": "r_a4"},
		{"z": 272.0, "lane": -1, "type": "boarder"},
		{"z": 290.0, "lane": 0, "type": "boulder"},
		{"z": 290.0, "lane": 1, "type": "boulder"},
		{"z": 318.0, "lane": 0, "type": "arrow", "archer": "r_a5"},
		{"z": 318.0, "lane": 1, "type": "arrow", "archer": "r_a5"},
		{"z": 318.0, "lane": 2, "type": "arrow", "archer": "r_a5"},
		{"z": 340.0, "lane": 1, "type": "box"},
	],
	"zip_segments": [
		# Three-cable chain over the pit — the set piece of the leg.
		{"start_z": 195.0, "end_z": 207.0},
		{"start_z": 213.0, "end_z": 225.0},
		{"start_z": 231.0, "end_z": 242.0},
	],
	# First PROTOCOL chamber — the Miner Shaft vesting mechanic.
	"chamber": "miner_shaft",
	"gold_principal": 1000,
	"bears": [{"z": 4.0}, {"z": -6.0}],
}

## Play order. Each leg ends at a chamber; after the last chamber the session ends.
const LEGS: Array = [LEG_DESCENT, LEG_DEEPER]
