class_name Ep2TownPosters
extends RefCounted
## THE WANTED POSTERS (founder 2026-10-24: "the posters of the wanted bandits are not visible anywhere"; skill ep2-wanted-posters).
##
## Jack Hammer uses only the official founder image (2026-11-05); the old engraving is retired. The supporting painted bills
## remain alongside the founder's own (Drive 2026-10-24, "Crypto Queen Wanted.jpg" and "RH Wanted.jpg") hang in the most-seen places: the top row
## of the drop-off notice board, the saloon, the certificate office and the general store. Torn edges keyed to alpha, kept square.
## Nailed up where a man would look for them: the notice board at the drop-off, beside the shop doors under the porches, over the jail's
## blank papers outside and on its wanted board inside.
##
## Streamed (ADR-0005): the images live in the extras pack. A poster whose image is not loadable yet is simply not hung - nothing else
## depends on them. Positions are in each building's LOCAL frame (x along the front, +z out of the front wall, y up), see Ep2GoldTown.

const DIR := "res://src/episode2/extras/town/posters/"
## The painted hand-bills are 640 x 880 (height / width), for callers that size a frame before the image is loaded.
const ASPECT_PAINTED := 880.0 / 640.0
const IDS := ["crypto_queen", "rh", "jack_hammer", "accomplice", "masked_riders", "horse_thieves"]
## Each bill takes its own height / width from its image (the painted hand-bills are 640 x 880, the founder's are square).
## The notice board at the drop-off: Lil Blunt hops off the quad at Ep2GoldTown.DROP_POINT and this is the first thing on the left.
const BOARD_POS := Vector3(-7.0, 0.0, 1405.6)
const BOARD_YAW := PI * 0.5             # its face looks across the street (+x)

## [building, local position of the poster centre, width (m), poster id, roll (rad)]. Kit fronts: wall face z = 0, porch floor y = 0.44,
## ground windows centred at x = +-(w/2 - 1.3), y = 1.6 (0.95 wide) - every poster sits on bare boards between door and window.
const WALL: Array = [
	["Bldg_Certificates", Vector3(1.48, 1.90, 0.03), 0.56, "crypto_queen", -0.03],
	["Bldg_Certificates", Vector3(-1.48, 1.92, 0.03), 0.46, "masked_riders", 0.04],
	["Bldg_Saloon", Vector3(2.35, 1.95, 0.03), 0.62, "jack_hammer", 0.02],
	["Bldg_Saloon", Vector3(-1.65, 1.95, 0.03), 0.56, "crypto_queen", -0.02],
	["Bldg_Saloon", Vector3(3.05, 1.80, 0.03), 0.40, "horse_thieves", -0.06],
	["Bldg_Saloon", Vector3(-2.75, 2.0, 0.03), 0.44, "jack_hammer", -0.03],
	["Bldg_A", Vector3(1.25, 1.92, 0.03), 0.44, "horse_thieves", 0.05],
	["Bldg_A", Vector3(-1.25, 1.92, 0.03), 0.52, "rh", -0.02],
	["Bldg_B", Vector3(-1.48, 1.94, 0.03), 0.44, "jack_hammer", 0.03],
	["Bldg_C", Vector3(-1.55, 1.92, 0.03), 0.46, "masked_riders", -0.04],
	["Bldg_C", Vector3(1.50, 1.96, 0.03), 0.44, "jack_hammer", 0.02],
	["Bldg_D", Vector3(1.70, 1.92, 0.03), 0.54, "crypto_queen", -0.03],
	["Bldg_E", Vector3(-1.25, 1.92, 0.03), 0.44, "horse_thieves", 0.04],
	["Bldg_F", Vector3(1.48, 1.94, 0.03), 0.44, "masked_riders", 0.02],
	# Square official bills on timber backing over the three baked rectangular placeholders.
	["Bldg_Armory", Vector3(-1.75, 1.60, 0.04), 0.42, "jack_hammer", -0.07],
	["Bldg_Armory", Vector3(1.80, 1.45, 0.04), 0.42, "jack_hammer", 0.072],
	["Bldg_Armory", Vector3(-4.60, 1.50, 0.04), 0.42, "jack_hammer", -0.184],
	# the jailhouse front: exactly over the three blank papers build_jailhouse.py nails up (0.40 x 0.55 at z = 0.006)
	["Bldg_Jail", Vector3(-1.45, 1.55, 0.02), 0.40, "jack_hammer", 0.05],
	["Bldg_Jail", Vector3(1.55, 1.45, 0.02), 0.40, "accomplice", -0.04],
	["Bldg_Jail", Vector3(-3.3, 1.40, 0.02), 0.40, "masked_riders", 0.03],
]
## The jail's wanted board inside (right wall, x = HX - T - 0.075 = 3.445, papers 0.26 wide): each faces into the office (-x).
const JAIL_BOARD: Array = [
	[Vector3(3.425, 2.10, -1.80), "jack_hammer", 0.0], [Vector3(3.425, 1.65, -1.80), "accomplice", 0.05],
	[Vector3(3.425, 2.15, -2.35), "masked_riders", 0.10], [Vector3(3.425, 1.70, -2.35), "horse_thieves", 0.15],
]
## The street notice board's four bills (board-local: x across its face, y up, +z out of the face).
const BOARD_BILLS: Array = [
	[Vector3(-0.56, 1.95, 0.07), 0.56, "crypto_queen", -0.02], [Vector3(0.02, 1.86, 0.075), 0.40, "rh", 0.03],
	[Vector3(0.58, 1.95, 0.07), 0.56, "jack_hammer", -0.03],
	[Vector3(-0.30, 1.38, 0.08), 0.26, "masked_riders", 0.06], [Vector3(0.32, 1.37, 0.08), 0.26, "horse_thieves", -0.05],
]


## Optional poster art and its construction stream together. Missing extras leave the town playable.
static func build(root: Node3D, props: Array) -> int:
	var path: String = DIR + "town_posters_builder.gd"
	if not Ep2Extras.has(path):
		return 0
	var builder: RefCounted = load(path).new()
	return builder.build(root, props)
