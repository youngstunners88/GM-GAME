class_name Ep2GoldTown
extends RefCounted
## THE GOLDMINE TOWN (founder lock 2026-10-14, PROMPT_EPISODE2_SURFACE_TO_TOWN_DRAW_SPEC.md; look: skill ep2-gold-rush-town, target
## artifacts/episode2-gold-mine/references/founder_2026-10-13_town/goldmine_town_target.jpg + the Muapi street still
## artifacts/episode2-gold-mine/references/fort_knox_prep/town_street/hero.jpg).
##
## ONE layout, built by BOTH the bear woods (you see the town and Fort Knox grow out of the desert as the quad comes down the road, and
## Bull drops you in its street) and the town chamber (where you walk in), at the SAME world coordinates - so the hand-over between the
## two rooms is a single invisible cut (skill ep2-no-blackouts).
##
## The street runs along +z from TOWN_Z, centred on x = 0, fronts at x = +-STREET_HALF. Buildings come from the Blender town kit
## (tools/ep2_blender/build_town_kit.py); their origin is the middle of the front edge, the front faces local +Z. Signs are painted
## textures (tools/ep2_forge/paint_town_signs.py) hung on each building's SignAnchor_<WORD>. No sign for the protocol Episode 2 bans (ep2-fort-knox-arc rule 4).

const KIT := "res://src/episode2/assets/town/town_kit.glb"
const TEX_DIR := "res://src/episode2/assets/town/"
const BARREL := "res://src/episode2/assets/mine_lift/mine_barrel.glb"
const CRATE := "res://src/episode2/assets/mine_lift/mine_crate.glb"
const ROCK := "res://src/episode2/assets/woods/woods_rock.glb"
const PLANK_TEX := "res://src/episode2/assets/mine_lift/tex_lift_planks.jpg"
const TIMBER_TEX := "res://src/episode2/assets/textures/tex_timber.jpg"
const TOWN_Z := 1400.0
const STREET_HALF := 9.0
const DROP_POINT := Vector3(0.0, 0.0, 1403.0)        # where the quad stops and Lil Blunt hops off
const FORT_POS := Vector3(34.0, 0.0, 1610.0)          # Fort Knox on its rock hill beyond the town (FORT_HILL_H up)
const FORT_HILL_H := 20.0
## The river and the railway behind the town (founder 2026-10-18; Ep2TownLife): both run along x between the church (z 1478) and
## the foot of Fort Knox's hill (z ~1558). The walkable town ends at z 1495, so they are scenery, never an obstacle.
const RIVER_Z := 1522.0
const RIVER_W := 22.0
const TRACK_Z := 1546.0

## [kit piece, x of the front plane, z of the front centre, faces the street from the left (+1) / right (-1) / along -z (0)]
const LAYOUT: Array = [
	["Bldg_Certificates", -STREET_HALF, 1412.0, 1], ["Bldg_A", -STREET_HALF, 1421.5, 1], ["Bldg_B", -STREET_HALF, 1430.0, 1],
	["Bldg_C", -STREET_HALF, 1438.5, 1], ["Bldg_E", -STREET_HALF, 1447.0, 1],
	["Bldg_Saloon", STREET_HALF, 1414.0, -1], ["Bldg_Treasury", STREET_HALF, 1426.5, -1], ["Bldg_D", STREET_HALF, 1437.5, -1],
	["Bldg_F", STREET_HALF, 1447.0, -1],
	["Church", 0.0, 1478.0, 0],
	["Bldg_Armory", -20.0, 1468.0, 0],   # Rich & Utah's shop: down a side lane off the left row, set back off the Main Street sightline
	# the jailhouse (founder lock 2026-10-20): Sheriff / Certificates side, out at the south edge of town west of the road - ~26 m from
	# Main Street, not on it. Streamed (Ep2Extras.JAIL); where the extras are not mounted nothing is drawn and the story skips it.
	["Bldg_Jail", -26.0, 1399.0, 1],
]
## Kit piece -> [width, depth, door half-width (0 = shut), door open]
const FOOTPRINT: Dictionary = {
	"Bldg_Certificates": [8.0, 9.0, 0.75], "Bldg_Saloon": [12.0, 12.0, 0.95], "Bldg_Treasury": [10.0, 12.0, 0.0], "Bldg_A": [7.0, 8.0, 0.75],
	"Bldg_B": [8.0, 9.0, 0.75], "Bldg_C": [6.0, 8.0, 0.75], "Bldg_D": [9.0, 9.0, 0.0], "Bldg_E": [7.0, 8.0, 0.0], "Bldg_F": [8.0, 9.0, 0.0],
	"Church": [8.0, 14.0, 0.0],
	"Bldg_Armory": [8.0, 9.0, 0.7],
	"Bldg_Armory2": [10.0, 12.0, 1.0],      # the two-storey Armory (streamed extras): double door 2 m wide
	"Bldg_Jail": [7.4, 8.6, 0.75],          # the jailhouse (streamed extras): 1.5 m plank door
}

## THE WALK-IN SHOPS (founder 2026-10-24: "the interiors of the buildings in the town ... aren't detailed enough ... people ... entering the
## stores and leaving. buying things"). The general store, the hotel and the assay office open their doors and are furnished
## (tools/ep2_blender/build_town_kit.py Gen_* / Hotel_* / Assay_*) - in the STREAMED kit only: the shipped fallback kit still has their
## doors shut, so their walls stay closed until town_kit2 is drawn (kit_v2).
## shop -> its kit piece; [trade name, counter offset in the building's local frame (the customer stands at the counter's CustomerSpot)]
const WALKIN_SHOPS: Dictionary = {"Bldg_A": ["general", Vector3(1.2, 0.0, -4.0)], "Bldg_B": ["hotel", Vector3(-1.4, 0.0, -5.4)],
	"Bldg_C": ["assay", Vector3(0.0, 0.0, -3.8)], "Bldg_Saloon": ["saloon", Vector3(-1.0, 0.0, -9.0)]}
## The shops that only open with the streamed kit (the saloon is always open: the story walks in through its batwings).
const KIT2_SHOPS := ["Bldg_A", "Bldg_B", "Bldg_C"]
## THE SALOON'S DRINKERS (founder 2026-10-24: "sitting and drinking in the saloon as well as the balcony above"). Table chairs (the same
## three tables _furnish sets, three chairs each) and two chairs on the balcony; skill ep2-saloon-drinkers. Saloon-local positions.
const SALOON_TABLES: Array = [Vector3(-3.2, 0.0, -3.6), Vector3(3.6, 0.0, -3.0), Vector3(3.8, 0.0, -6.8)]
const BALCONY_Y := 3.98                      # the balcony's plank top (build_town_kit.py building(balcony=True))
## The regulars STAND at the rail (a seated head is below the 1.3 m rail: from the street you would see nobody); chairs behind them.
const BALCONY_SEATS: Array = [Vector3(-2.3, 0.0, 1.2), Vector3(-1.0, 0.0, 1.2)]
const BALCONY_CHAIRS: Array = [Vector3(-2.6, 0.0, 0.45), Vector3(-0.7, 0.0, 0.45)]
const BALCONY_TABLE := Vector3(-1.65, 0.0, 0.45)


## Every place a drinker can take: [{"kind": "table" | "bar" | "balcony", "pos": world floor point (the chair / the spot at the bar),
## "face": world point to look at, "y": floor height, "approach": where the walk in ends (a step behind the chair), "route": world
## points from just inside the door to "approach" (down the aisle, never through a table or a neighbour)}]. Only the aisle-side chair
## of each table is used, so whoever walks in or out passes nobody seated; the bar places are 1.4 m apart, walked to along a row 0.75 m
## in front of them. Empty when the saloon is not in the layout.
const BAR_SPOTS := [-3.6, -2.2, -0.8, 0.6]         # saloon-local x of the places at the bar
const BAR_Z := -8.15                               # standing at the bar (its front is at z -8.6)
const BAR_ROW_Z := -7.4                            # the walking row in front of the drinkers there
## Porch floor height (kit porch(): planks 0.22 thick centred at 0.33) and its depth / steps, for anyone walking in or out.
const PORCH_Y := 0.44
const PORCH_DEPTH := 2.6


static func _saloon_w(p: Vector3) -> Vector3:
	return local_to_world("Bldg_Saloon", p)


static func saloon_seats() -> Array:
	var out: Array = []
	if entry("Bldg_Saloon").is_empty():
		return out
	for tp in SALOON_TABLES:
		var best: Vector3 = Vector3.ZERO
		var best_x: float = INF
		for k in 3:
			var a: float = float(k) * TAU / 3.0 + (tp as Vector3).x
			var p: Vector3 = tp + Vector3(sin(a), 0, cos(a)) * 0.95
			if absf(p.x) < best_x:
				best_x = absf(p.x)
				best = p
		var approach: Vector3 = best + (best - (tp as Vector3)).normalized() * 0.45
		# down the aisle, never further back than the bar's walking row (a back table's chair is reached along that row, 0.75 m
		# clear of anyone standing at the bar), then across to the chair
		var row_z: float = maxf(approach.z, BAR_ROW_Z)
		out.append({"kind": "table", "pos": _saloon_w(best), "face": _saloon_w(tp), "y": 0.06, "approach": _saloon_w(approach),
			"route": [_saloon_w(Vector3(0.0, 0.0, row_z)), _saloon_w(Vector3(approach.x, 0.0, row_z)), _saloon_w(approach)]})
	for bx in BAR_SPOTS:
		var spot := Vector3(float(bx), 0.0, BAR_Z)
		out.append({"kind": "bar", "pos": _saloon_w(spot), "face": _saloon_w(Vector3(float(bx), 1.0, -9.0)), "y": 0.06, "approach": _saloon_w(spot),
			"route": [_saloon_w(Vector3(0.0, 0.0, BAR_ROW_Z)), _saloon_w(Vector3(float(bx), 0.0, BAR_ROW_Z)), _saloon_w(spot)]})
	for bs in BALCONY_SEATS:
		out.append({"kind": "balcony", "pos": _saloon_w(bs), "face": _saloon_w((bs as Vector3) + Vector3(0, 0, 3.0)), "y": BALCONY_Y,
			"approach": _saloon_w(bs), "route": []})
	return out


static func _balcony_furniture(root: Node3D, kit: Node3D) -> void:
	if entry("Bldg_Saloon").is_empty():
		return
	var chair: Node3D = kit.find_child("Bar_Chair", true, false) as Node3D
	var table: Node3D = kit.find_child("Bar_Table", true, false) as Node3D
	var xf: Transform3D = building_xform(entry("Bldg_Saloon"))
	if chair != null:
		for bs in BALCONY_CHAIRS:
			var c: Node3D = chair.duplicate() as Node3D
			c.transform = xf * Transform3D(Basis(Vector3.UP, PI), (bs as Vector3) + Vector3(0, BALCONY_Y, 0))   # facing the street
			c.name = "BalconyChair"
			root.add_child(c)
	if table != null:
		var t: Node3D = table.duplicate() as Node3D
		t.transform = xf * Transform3D(Basis().scaled(Vector3(0.7, 1.0, 0.7)), BALCONY_TABLE + Vector3(0, BALCONY_Y, 0))
		t.name = "BalconyTable"
		root.add_child(t)


## Where a customer goes for each walk-in shop, in world space: "out" (the street, past the porch steps), "door" (just inside the doorway),
## "counter" (at the counter's front) and "face" (the shopkeeper's side, to look at). {} when the shop is not open (fallback kit).
static func shop_spots(piece: String) -> Dictionary:
	if not kit_v2 or not WALKIN_SHOPS.has(piece) or entry(piece).is_empty():
		return {}
	var c: Vector3 = WALKIN_SHOPS[piece][1]
	return {"out": local_to_world(piece, Vector3(0.0, 0.0, PORCH_DEPTH + 1.1)), "porch": local_to_world(piece, Vector3(0.0, 0.0, 1.0)),
		"door": local_to_world(piece, Vector3(0.0, 0.0, -0.9)), "counter": local_to_world(piece, c + Vector3(0.0, 0.0, 0.95)),
		"face": local_to_world(piece, c + Vector3(0.0, 0.0, -0.8))}


## Floor height under a world point near a walk-in shop: the porch boards are 0.44 m up (two steps in front), the shop floor is level
## with the street (its plank floor is 0.06). Everyone else stands on y = 0.
static func shop_floor_y(piece: String, world: Vector3) -> float:
	var e: Array = entry(piece)
	if e.is_empty():
		return 0.0
	var l: Vector3 = building_xform(e).affine_inverse() * world
	var half: float = float(FOOTPRINT.get(piece, [8.0, 9.0, 0.0])[0]) * 0.5 + 0.2
	if absf(l.x) > half:
		return 0.0
	if l.z >= 0.0 and l.z <= PORCH_DEPTH:
		return PORCH_Y
	if l.z > PORCH_DEPTH and l.z < PORCH_DEPTH + 0.75:                  # the two steps
		return PORCH_Y * clampf(1.0 - (l.z - PORCH_DEPTH) / 0.75, 0.0, 1.0)
	if l.z < 0.0 and l.z > -float(FOOTPRINT.get(piece, [8.0, 9.0, 0.0])[1]):
		return 0.06
	return 0.0


## The Colt Gatling's post in the Armory's front yard (founder 2026-10-20, skill ep2-armory-guns), in Bldg_Armory's LOCAL frame (x along the front, +z out
## into the yard). The Armory faces -z (yaw PI), so local +x is world -x: at rest the bore points west over open ground, away from the street. The gun
## is NOT FOR SALE; the plates and bales are the firing yard it is demonstrated on.
const GATLING_POST := Vector3(9.6, 0.0, 1.6)         # beyond the porch's right end and clear of the grazing horse (-27, 1462.5): founder, "dont replace the horses"
const GATLING_STAND_BACK := 1.0
const GATLING_PLATES: Array = [Vector3(17.0, 0.0, 0.4), Vector3(20.5, 0.0, 3.6), Vector3(24.0, 0.0, -0.9), Vector3(27.5, 0.0, 2.4), Vector3(31.0, 0.0, 0.2)]
const GATLING_BALES: Array = [Vector3(36.0, 0.0, 1.6), Vector3(19.0, 0.0, 5.6)]

## The two-storey Armory (founder 2026-10-19, skill ep2-armory-two-story). When the streamed extras are loadable (Ep2Extras), the
## "Bldg_Armory" LAYOUT row draws Bldg_Armory2 + its fit-out instead of the kit's one-storey shop, at the SAME transform - so wherever
## the row is moved, the new building follows. Its GLB also carries the NPC waypoints and walk blockers, read here once per build.
static var armory_v2: bool = false
static var kit_v2: bool = false                # the streamed town kit with real openings is the one drawn
static var armory_spots: Dictionary = {}       # Spot_<name> -> local Vector3 (x along the front, -z inside, y = floor)
static var armory_blocks: Array = []           # [local centre Vector2(x, z), half extents Vector2] of the shop-floor blockers
static var armory_lights: Array = []           # local Vector3 lamp positions
## The jailhouse (streamed extras): drawn when jailhouse.glb is loadable; its Jail_Nav empties give the stand points and the
## cell-block blockers, the same way the Armory's do.
static var jail_v1: bool = false
static var jail_spots: Dictionary = {}
static var jail_blocks: Array = []
static var jail_lights: Array = []
## Where the desert scatter (scrub, rock) keeps clear around the jailhouse, so it does not stand in brush (x, z rectangle).
const JAIL_CLEAR := Rect2(-46.0, 1390.0, 24.0, 20.0)


## The yaw that turns a kit piece's local +Z front toward the street.
static func yaw_for(side: int) -> float:
	match side:
		1:
			return PI * 0.5            # on the left (x < 0): faces +x
		-1:
			return -PI * 0.5           # on the right: faces -x
	return PI                          # at the end of the street: faces back down it (-z)


## A building's transform (origin = middle of the front edge at street level).
static func building_xform(entry: Array) -> Transform3D:
	var side: int = int(entry[3])
	return Transform3D(Basis(Vector3.UP, yaw_for(side)), Vector3(float(entry[1]), 0.0, float(entry[2])))


static func entry(piece: String) -> Array:
	for e in LAYOUT:
		if str(e[0]) == piece:
			return e
	return []


## A point given in a building's LOCAL frame (x along the front, z negative = inside) -> world.
static func local_to_world(piece: String, p: Vector3) -> Vector3:
	var e: Array = entry(piece)
	return building_xform(e) * p if not e.is_empty() else p


static func door_world(piece: String, out: float = 1.0) -> Vector3:
	return local_to_world(piece, Vector3(0.0, 0.0, out))


## Build the town into `parent`. `interiors` = furnish the certificate office and the saloon (the town chamber); the woods only needs the
## street seen from the road. Returns {"walls": [[Vector2 a, Vector2 b], ...], "props": [[Vector2 p, radius], ...]} for collision.
static func build(parent: Node3D, interiors: bool) -> Dictionary:
	var walls: Array = []
	var props: Array = []
	var root := Node3D.new()
	root.name = "GoldTown"
	parent.add_child(root)
	if not ResourceLoader.exists(KIT):
		return {"walls": walls, "props": props}
	# the kit with real openings is streamed (Ep2Extras); until it is mounted the shipped kit is drawn
	var kit_path: String = Ep2Extras.TOWN_KIT if Ep2Extras.has(Ep2Extras.TOWN_KIT) else KIT
	kit_v2 = kit_path == Ep2Extras.TOWN_KIT
	var kit: Node3D = (load(kit_path) as PackedScene).instantiate() as Node3D
	_apply_mats(kit)
	var a2: Node3D = _load_armory2()
	var jl: Node3D = _load_jail()
	for e in LAYOUT:
		var piece: String = str(e[0])
		var src: Node3D = kit.find_child(piece, true, false) as Node3D
		if piece == "Bldg_Armory" and a2 != null:
			src = a2.find_child("Bldg_Armory2", true, false) as Node3D
			piece = "Bldg_Armory2"
		if piece == "Bldg_Jail":
			src = jl.find_child("Bldg_Jail", true, false) as Node3D if jl != null else null
		if src == null:
			continue
		var b: Node3D = src.duplicate() as Node3D
		b.transform = building_xform(e)
		root.add_child(b)
		_hang_signs(b)
		walls.append_array(_walls_of(piece, building_xform(e)))
		if piece == "Bldg_Armory2":
			walls.append_array(_armory2_block_walls(building_xform(e)))
		if piece == "Bldg_Jail":
			walls.append_array(_blocks_to_walls(jail_blocks, building_xform(e)))
	# the street furniture: hitching rails, troughs, wagons, lamps, barrels and crates, benches on the porches
	var dress: Array = [
		["HitchRail", Vector3(-6.4, 0.0, 1418.0), PI * 0.5], ["HitchRail", Vector3(6.4, 0.0, 1431.0), PI * 0.5],
		["HitchRail", Vector3(-6.4, 0.0, 1441.0), PI * 0.5], ["Trough", Vector3(-6.0, 0.0, 1425.0), PI * 0.5],
		["Trough", Vector3(6.2, 0.0, 1420.5), PI * 0.5], ["Wagon", Vector3(4.2, 0.0, 1452.0), 0.2], ["Wagon", Vector3(-3.6, 0.0, 1463.0), -2.9],
		["LampPost", Vector3(-6.8, 0.0, 1409.0), 0.0], ["LampPost", Vector3(6.8, 0.0, 1424.0), PI], ["LampPost", Vector3(-6.8, 0.0, 1434.0), 0.0],
		["Bench", Vector3(-7.6, 0.44, 1423.0), PI * 0.5], ["Bench", Vector3(7.6, 0.44, 1446.0), -PI * 0.5],
		# the armory lane, off the left row past the STATS block: a lamp, and river gear staged at the lean-to
		["LampPost", Vector3(-10.0, 0.0, 1450.0), 0.0],
		# the jailhouse yard (south edge of town, west of the road): a lamp, a hitching rail and a bench by the door
		["LampPost", Vector3(-23.2, 0.0, 1396.4), 0.0], ["HitchRail", Vector3(-22.4, 0.0, 1403.6), PI * 0.5], ["Bench", Vector3(-24.0, 0.0, 1394.4), PI * 0.5],
		["Arm_PowderKeg", Vector3(-17.0, 0.0, 1465.2), 0.0], ["Arm_PowderKeg", Vector3(-16.1, 0.0, 1465.7), 0.0],
		["River_Crate", Vector3(-14.9, 0.0, 1465.0), 0.3], ["River_Skiff", Vector3(-22.4, 0.0, 1460.0), PI * 0.5],
	]
	for d in dress:
		var s: Node3D = kit.find_child(str(d[0]), true, false) as Node3D
		if s == null:
			continue
		var n: Node3D = s.duplicate() as Node3D
		n.transform = Transform3D(Basis(Vector3.UP, float(d[2])), d[1])
		root.add_child(n)
		props.append([Vector2((d[1] as Vector3).x, (d[1] as Vector3).z), 1.6 if str(d[0]) == "Wagon" else 0.7])
	for bp in [Vector3(-6.9, 0.0, 1427.5), Vector3(-7.3, 0.0, 1428.3), Vector3(7.0, 0.0, 1433.0), Vector3(6.6, 0.0, 1443.6), Vector3(-7.0, 0.0, 1450.0)]:
		_glb(root, BARREL, bp, bp.x * 0.7, 1.0)
		props.append([Vector2(bp.x, bp.z), 0.45])
	for cp in [Vector3(7.4, 0.0, 1434.2), Vector3(-7.1, 0.0, 1416.2), Vector3(6.9, 0.0, 1451.0)]:
		_glb(root, CRATE, cp, cp.z, 1.0)
		props.append([Vector2(cp.x, cp.z), 0.6])
	# Fort Knox on its rock hill, flags flying
	var hill := Node3D.new()
	hill.name = "FortHill"
	root.add_child(hill)
	for i in 9:
		var a: float = float(i) * 0.7
		var r: float = 10.0 + 9.0 * float(i % 3)
		_glb(hill, ROCK, FORT_POS + Vector3(cos(a) * r, -4.0, sin(a) * r * 0.8), a, 13.0 + 3.0 * float(i % 4), Color(0.86, 0.72, 0.52))
	var plateau := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 30.0
	cm.bottom_radius = 46.0
	cm.height = FORT_HILL_H
	cm.radial_segments = 14
	plateau.mesh = cm
	plateau.material_override = _tex_mat("tex_sandstone.jpg", Color(0.78, 0.64, 0.46), 0.05)
	plateau.position = FORT_POS + Vector3(0.0, FORT_HILL_H * 0.5 - 0.2, -6.0)
	hill.add_child(plateau)
	var fort_src: Node3D = kit.find_child("FortKnox", true, false) as Node3D
	if fort_src != null:
		var fort: Node3D = fort_src.duplicate() as Node3D
		fort.transform = Transform3D(Basis(Vector3.UP, PI), FORT_POS + Vector3(0.0, FORT_HILL_H - 0.2, 0.0))
		root.add_child(fort)
		_hang_signs(fort)
		for fa in fort.find_children("FlagAnchor*", "", true, false):
			_flag(fort, (fa as Node3D).position)
	Ep2TownLife.build(root, props)                      # horses at the rails, the river, the railway and the train
	Ep2StableYard.build(root, props, walls)              # original surface stable, shared by the quad approach and town
	Ep2TownPosters.build(root, props)                   # the wanted posters: notice board, shop fronts, the jail (streamed images)
	_balcony_furniture(root, kit)                       # two chairs and a little table on the saloon's balcony (its drinkers sit there)
	if interiors:
		_furnish(root, kit, a2)
	kit.free()
	if a2 != null:
		a2.free()
	if jl != null:
		jl.free()
	return {"walls": walls, "props": props}


## The two-storey Armory scene from the streamed extras (null when they are not loadable yet: the kit's shop is drawn instead).
## Also reads its Arm2_Nav empties into armory_spots / armory_blocks / armory_lights.
static func _load_armory2() -> Node3D:
	armory_v2 = false
	armory_spots = {}
	armory_blocks = []
	armory_lights = []
	if not Ep2Extras.has(Ep2Extras.ARMORY):
		return null
	var ps: PackedScene = load(Ep2Extras.ARMORY) as PackedScene
	if ps == null:
		return null
	var a2: Node3D = ps.instantiate() as Node3D
	if a2.find_child("Bldg_Armory2", true, false) == null:
		a2.free()
		return null
	_apply_mats(a2)
	var nav: Node = a2.find_child("Arm2_Nav", true, false)
	if nav != null:
		for c in nav.get_children():
			var n3 := c as Node3D
			if n3 == null:
				continue
			var nm: String = String(n3.name)
			if nm.begins_with("Spot_"):
				armory_spots[nm.trim_prefix("Spot_")] = n3.position
			elif nm.begins_with("Block_"):
				armory_blocks.append([Vector2(n3.position.x, n3.position.z), Vector2(absf(n3.scale.x), absf(n3.scale.z))])
	var bld: Node = a2.find_child("Bldg_Armory2", true, false)
	for c in bld.find_children("LightAnchor_*", "", true, false):
		armory_lights.append((c as Node3D).position)
	armory_v2 = true
	return a2


## The jailhouse scene from the streamed extras (null when it is not loadable: nothing is drawn). Reads Jail_Nav into
## jail_spots / jail_blocks and the lamp anchors into jail_lights.
static func _load_jail() -> Node3D:
	jail_v1 = false
	jail_spots = {}
	jail_blocks = []
	jail_lights = []
	if not Ep2Extras.has(Ep2Extras.JAIL):
		return null
	var ps: PackedScene = load(Ep2Extras.JAIL) as PackedScene
	if ps == null:
		return null
	var j: Node3D = ps.instantiate() as Node3D
	if j.find_child("Bldg_Jail", true, false) == null:
		j.free()
		return null
	_apply_mats(j)
	_texture_dark_wood(j)
	var nav: Node = j.find_child("Jail_Nav", true, false)
	if nav != null:
		for c in nav.get_children():
			var n3 := c as Node3D
			if n3 == null:
				continue
			var nm: String = String(n3.name)
			if nm.begins_with("Spot_"):
				jail_spots[nm.trim_prefix("Spot_")] = n3.position
			elif nm.begins_with("Block_"):
				jail_blocks.append([Vector2(n3.position.x, n3.position.z), Vector2(absf(n3.scale.x), absf(n3.scale.z))])
	for c in (j.find_child("Bldg_Jail", true, false) as Node).find_children("LightAnchor_*", "", true, false):
		jail_lights.append((c as Node3D).position)
	jail_v1 = true
	return j


## Rectangular walk blockers [centre Vector2(x, z), half extents Vector2] in a building's local frame -> world wall segments.
static func _blocks_to_walls(blocks: Array, xf: Transform3D) -> Array:
	var out: Array = []
	for bl in blocks:
		var c: Vector2 = bl[0]
		var h: Vector2 = bl[1]
		var pts: Array = [Vector3(c.x - h.x, 0, c.y - h.y), Vector3(c.x + h.x, 0, c.y - h.y), Vector3(c.x + h.x, 0, c.y + h.y), Vector3(c.x - h.x, 0, c.y + h.y)]
		for i in 4:
			var a: Vector3 = xf * (pts[i] as Vector3)
			var b: Vector3 = xf * (pts[(i + 1) % 4] as Vector3)
			out.append([Vector2(a.x, a.z), Vector2(b.x, b.z)])
	return out


## The Armory's shop-floor blockers (counter, cases, stair, shelves, kegs, gallery posts) as wall segments, so Lil Blunt walks round
## them like walls (collide()).
static func _armory2_block_walls(xf: Transform3D) -> Array:
	var out: Array = []
	for bl in armory_blocks:
		var c: Vector2 = bl[0]
		var h: Vector2 = bl[1]
		var pts: Array = [Vector3(c.x - h.x, 0, c.y - h.y), Vector3(c.x + h.x, 0, c.y - h.y), Vector3(c.x + h.x, 0, c.y + h.y), Vector3(c.x - h.x, 0, c.y + h.y)]
		for i in 4:
			var a: Vector3 = xf * (pts[i] as Vector3)
			var b: Vector3 = xf * (pts[(i + 1) % 4] as Vector3)
			out.append([Vector2(a.x, a.z), Vector2(b.x, b.z)])
	return out


## The kit's named materials -> textured, world-triplanar ones (one material per name, shared by every instance).
static func _apply_mats(kit: Node) -> void:
	var mats: Dictionary = {
		"Siding": _tex_mat("tex_siding.jpg", Color(0.92, 0.84, 0.74), 0.45, PLANK_TEX),
		"Trim": _tex_mat("tex_siding.jpg", Color(0.55, 0.42, 0.30), 0.8, TIMBER_TEX),
		"Roof": _tex_mat("tex_roof.jpg", Color(0.85, 0.82, 0.78), 0.35, ""),
		"Sandstone": _tex_mat("tex_sandstone.jpg", Color(1.0, 0.95, 0.86), 0.35, ""),
		"FortStone": _tex_mat("tex_fortstone.jpg", Color(0.95, 0.90, 0.82), 0.12, ""),
		"PaintWhite": _tex_mat("tex_siding.jpg", Color(1.35, 1.32, 1.25), 0.45, PLANK_TEX),
		"Planks": _tex_mat("", Color(0.80, 0.72, 0.62), 0.7, PLANK_TEX),
	}
	(mats["Roof"] as StandardMaterial3D).metallic = 0.35
	for mi in kit.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for si in m.mesh.get_surface_count():
			var src: Material = m.mesh.surface_get_material(si)
			var key: String = String(src.resource_name) if src != null else ""
			if mats.has(key):
				m.mesh.surface_set_material(si, mats[key])


## The jail's furniture (desk, chair, cots, the privy box, the rifle rack) came out of the glTF as flat brown "DarkWood"; give it real
## grain - the timber texture, darkened - so it stops reading as painted cardboard (founder 2026-10-24: interiors look low quality).
## The jail and the walk-in shops only: the kit's other rooms and the Armory's DarkWood stay exactly as approved.
static func _texture_dark_wood(n: Node) -> void:
	var dw: StandardMaterial3D = _tex_mat("", Color(0.50, 0.36, 0.26), 0.9, TIMBER_TEX)
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for si in m.mesh.get_surface_count():
			var src: Material = m.mesh.surface_get_material(si)
			if src != null and String(src.resource_name) == "DarkWood":
				m.mesh.surface_set_material(si, dw)


## A world-triplanar material from a town texture (falls back to `fallback`, then to a flat colour) - tinted.
static func _tex_mat(file: String, tint: Color, uv_scale: float, fallback: String = "") -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.roughness = 0.88
	var path: String = TEX_DIR + file if file != "" else ""
	if path == "" or not ResourceLoader.exists(path):
		path = fallback
	if path != "" and ResourceLoader.exists(path):
		m.albedo_texture = load(path)
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE * uv_scale
	return m


## Hang the painted board on every SignAnchor_<WORD> of a building.
static func _hang_signs(b: Node3D) -> void:
	for an in b.find_children("SignAnchor_*", "", true, false):
		var word: String = String(an.name).trim_prefix("SignAnchor_")
		var hang: bool = word.ends_with("_hang")             # a small board hung under a porch awning (the two-storey Armory)
		word = word.trim_suffix("_hang")
		var path: String = TEX_DIR + "sign_%s.png" % word
		if word == "JAIL":
			path = Ep2Extras.JAIL_SIGN                      # the jail's sign ships with its streamed extras
		if not ResourceLoader.exists(path):
			continue
		var q := MeshInstance3D.new()
		q.name = "Sign_" + word
		var qm := QuadMesh.new()
		var w: float = 6.0 if word != "FORTKNOX" else 5.6
		if word in ["ASSAY", "STATS"]:
			w = 4.6
		if hang:
			w = 2.4
		qm.size = Vector2(w, w * 180.0 / 1024.0)
		q.mesh = qm
		var sm := StandardMaterial3D.new()
		sm.albedo_texture = load(path)
		sm.roughness = 0.9
		q.material_override = sm
		(an as Node3D).add_child(q)


## The building's walls as ground-plane segments (the door gap left open on the enterable ones), for collision.
static func _walls_of(piece: String, xf: Transform3D) -> Array:
	var fp: Array = FOOTPRINT.get(piece, [8.0, 9.0, 0.0])
	var w: float = float(fp[0]) * 0.5
	var d: float = float(fp[1])
	var door: float = float(fp[2])
	if piece in KIT2_SHOPS and not kit_v2:
		door = 0.0                      # the fallback kit draws these doors shut
	var local: Array = []
	if door > 0.0:
		local.append([Vector3(-w, 0, 0), Vector3(-door, 0, 0)])
		local.append([Vector3(door, 0, 0), Vector3(w, 0, 0)])
	else:
		local.append([Vector3(-w, 0, 0), Vector3(w, 0, 0)])
	local.append([Vector3(-w, 0, 0), Vector3(-w, 0, -d)])
	local.append([Vector3(w, 0, 0), Vector3(w, 0, -d)])
	local.append([Vector3(-w, 0, -d), Vector3(w, 0, -d)])
	var out: Array = []
	for s in local:
		var a: Vector3 = xf * (s[0] as Vector3)
		var b: Vector3 = xf * (s[1] as Vector3)
		out.append([Vector2(a.x, a.z), Vector2(b.x, b.z)])
	return out


## Push a body of radius `r` at ground point `p` out of every wall segment and prop circle.
static func collide(p: Vector2, r: float, walls: Array, props: Array) -> Vector2:
	var q := p
	for s in walls:
		var a: Vector2 = s[0]
		var ab: Vector2 = (s[1] as Vector2) - a
		var t: float = clampf((q - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
		var c: Vector2 = a + ab * t
		var dv: Vector2 = q - c
		var dl: float = dv.length()
		if dl < r:
			q = c + (dv / dl if dl > 1e-5 else Vector2(-ab.y, ab.x).normalized()) * r
	for pr in props:
		var cp: Vector2 = pr[0]
		var rr: float = float(pr[1]) + r
		var dv2: Vector2 = q - cp
		if dv2.length() < rr:
			q = cp + (dv2.normalized() if dv2.length() > 1e-5 else Vector2(1, 0)) * rr
	return q


static func _glb(parent: Node3D, path: String, pos: Vector3, yaw: float, scale: float, tint: Color = Color(1, 1, 1)) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var n: Node3D = (load(path) as PackedScene).instantiate() as Node3D
	n.transform = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale), pos)
	parent.add_child(n)
	if tint != Color(1, 1, 1):
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			var sm := StandardMaterial3D.new()
			sm.albedo_color = tint
			var src: Material = m.mesh.surface_get_material(0) if m.mesh and m.mesh.get_surface_count() > 0 else null
			if src is BaseMaterial3D and (src as BaseMaterial3D).albedo_texture != null:
				sm.albedo_texture = (src as BaseMaterial3D).albedo_texture
			sm.roughness = 0.95
			m.material_override = sm
	return n


## A cloth flag on a pole top (a quad that ripples in the shader-free way: a slow rotation wobble driven by the owner, if any).
static func _flag(parent: Node3D, pos: Vector3) -> void:
	var q := MeshInstance3D.new()
	q.name = "Flag"
	var qm := QuadMesh.new()
	qm.size = Vector2(1.8, 1.1)
	q.mesh = qm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.82, 0.62, 0.18)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material_override = m
	q.position = pos
	parent.add_child(q)


## The two rooms Lil Blunt walks into: the certificate office (counter, pigeonholes, desk, stove, lamps) and the saloon (the long bar,
## the back shelf of bottles round a mirror, tables and chairs, a piano, oil lamps). Positions are in each building's local frame.
static func _furnish(root: Node3D, kit: Node3D, a2: Node3D = null) -> void:
	var rooms: Array = [
		["Bldg_Certificates", "Int_Counter", Vector3(0.6, 0.0, -4.6), 0.0], ["Bldg_Certificates", "Int_Shelves", Vector3(0.6, 0.0, -8.6), 0.0],
		["Bldg_Certificates", "Int_Desk", Vector3(-2.3, 0.0, -7.0), 0.0], ["Bldg_Certificates", "Int_Stove", Vector3(-3.0, 0.0, -2.4), 0.0],
		["Bldg_Saloon", "Bar_Counter", Vector3(-1.0, 0.0, -9.0), 0.0], ["Bldg_Saloon", "Bar_BackShelf", Vector3(-1.0, 0.0, -11.6), 0.0],
		["Bldg_Saloon", "Bar_Piano", Vector3(4.9, 0.0, -10.6), -PI * 0.5],
		["Bldg_Saloon", "Bar_Table", Vector3(-3.2, 0.0, -3.6), 0.0], ["Bldg_Saloon", "Bar_Table", Vector3(3.6, 0.0, -3.0), 0.0],
		["Bldg_Saloon", "Bar_Table", Vector3(3.8, 0.0, -6.8), 0.0],
		# the armory: counter, wall racks, a revolver case, the lit long-rifle case, a powder keg
		# the walk-in shops (streamed kit only: these pieces exist in town_kit2): general store, hotel, assay office
		["Bldg_A", "Gen_Counter", Vector3(1.2, 0.0, -4.0), 0.0], ["Bldg_A", "Gen_Shelves", Vector3(0.0, 0.0, -7.6), 0.0],
		["Bldg_A", "Gen_FloorGoods", Vector3(-2.2, 0.0, -2.0), 0.0],
		["Bldg_B", "Hotel_Desk", Vector3(-1.4, 0.0, -5.4), 0.0], ["Bldg_B", "Hotel_Stairs", Vector3(2.95, 0.0, -2.0), 0.0],
		["Bldg_B", "Hotel_Lounge", Vector3(-2.3, 0.0, -2.1), PI * 0.5],
		["Bldg_C", "Assay_Counter", Vector3(0.0, 0.0, -3.8), 0.0], ["Bldg_C", "Assay_Furnace", Vector3(-1.85, 0.0, -6.7), 0.0],
		["Bldg_C", "Assay_Shelves", Vector3(1.4, 0.0, -7.6), 0.0],
		["Bldg_Armory", "Arm_Counter", Vector3(0.6, 0.0, -4.4), 0.0], ["Bldg_Armory", "Arm_Rack", Vector3(-3.4, 0.0, -7.4), PI * 0.5],
		["Bldg_Armory", "Arm_Rack", Vector3(3.4, 0.0, -7.4), -PI * 0.5], ["Bldg_Armory", "Arm_Case", Vector3(-1.4, 0.0, -6.6), 0.0],
		["Bldg_Armory", "Arm_SniperCase", Vector3(1.8, 0.0, -7.8), 0.0], ["Bldg_Armory", "Arm_PowderKeg", Vector3(-3.2, 0.0, -2.2), 0.0],
	]
	for rm in rooms:
		if a2 != null and str(rm[0]) == "Bldg_Armory":
			continue                    # the two-storey Armory brings its own fit-out (below)
		var src: Node3D = kit.find_child(str(rm[1]), true, false) as Node3D
		if src == null:
			continue
		var n: Node3D = src.duplicate() as Node3D
		var xf: Transform3D = building_xform(entry(str(rm[0])))
		n.transform = xf * Transform3D(Basis(Vector3.UP, float(rm[3])), rm[2])
		n.name = str(rm[1]) + "_" + str(rm[0])
		root.add_child(n)
		if str(rm[0]) in WALKIN_SHOPS:
			_texture_dark_wood(n)          # the shops' counters, shelves and furniture in real grain, like the jail's
	var chair: Node3D = kit.find_child("Bar_Chair", true, false) as Node3D
	if chair != null:
		for tp in [Vector3(-3.2, 0.0, -3.6), Vector3(3.6, 0.0, -3.0), Vector3(3.8, 0.0, -6.8)]:
			for k in 3:
				var a: float = float(k) * TAU / 3.0 + tp.x
				var c: Node3D = chair.duplicate() as Node3D
				c.transform = building_xform(entry("Bldg_Saloon")) * Transform3D(Basis(Vector3.UP, a + PI), tp + Vector3(sin(a), 0, cos(a)) * 0.95)
				root.add_child(c)
	# warm oil lamps in both rooms
	var lamps: Array = [["Bldg_Certificates", Vector3(0.0, 3.0, -4.0), 4.5], ["Bldg_Saloon", Vector3(-2.0, 3.2, -4.0), 6.0], ["Bldg_Saloon", Vector3(3.0, 3.2, -8.0), 6.0]]
	if kit_v2:                         # one warm lamp in each walk-in shop
		lamps.append_array([["Bldg_A", Vector3(0.0, 3.0, -4.0), 4.5], ["Bldg_B", Vector3(-0.8, 3.0, -4.2), 4.5], ["Bldg_C", Vector3(0.0, 3.0, -4.2), 4.0]])
	if a2 == null:
		lamps.append(["Bldg_Armory", Vector3(0.0, 3.0, -5.0), 5.0])
	else:
		# the two-storey Armory: its fit-out at the building's transform, and a warm lamp at each hanging oil lamp (<= 4 lights)
		var fit: Node3D = a2.find_child("Arm2_Fit", true, false) as Node3D
		if fit != null:
			var f: Node3D = fit.duplicate() as Node3D
			f.transform = building_xform(entry("Bldg_Armory"))
			f.name = "Arm2_Fit_Bldg_Armory"
			root.add_child(f)
		var shp: Node3D = a2.find_child("Arm2_Sharps", true, false) as Node3D        # the Sharps in the lit case: its own node, Rich lifts it out
		if shp != null:
			var sn: Node3D = shp.duplicate() as Node3D
			sn.transform = building_xform(entry("Bldg_Armory"))
			sn.name = "Arm2_Sharps_Bldg_Armory"
			root.add_child(sn)
		for i in mini(armory_lights.size(), 4):
			lamps.append(["Bldg_Armory", armory_lights[i], 4.5])
	if jail_v1:
		for i in mini(jail_lights.size(), 2):
			lamps.append(["Bldg_Jail", jail_lights[i], 4.0])
		if jail_spots.has("privy"):                      # the flies over the cell's privy, and their buzz (founder 2026-10-24)
			var flies := Ep2JailFlies.new()
			flies.name = "JailFlies"
			flies.position = local_to_world("Bldg_Jail", jail_spots["privy"])
			flies.rotation.y = building_xform(entry("Bldg_Jail")).basis.get_euler().y
			root.add_child(flies)
	for lp in lamps:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.72, 0.42)
		l.light_energy = 1.8
		l.omni_range = float(lp[2]) * 2.0
		l.position = local_to_world(str(lp[0]), lp[1])
		root.add_child(l)


## Gold-rush country light (`k` 0 = the woods' golden hour, 1 = the open desert by the town): a warm low sun ahead, amber sky, thin
## warm haze so the mesas and Fort Knox read at distance. Interpolated by road distance as the quad leaves the trees - never a cut.
static func apply_desert_grade(env: Environment, sun: DirectionalLight3D, k: float) -> void:
	k = clampf(k, 0.0, 1.0)
	if env.sky == null:
		env.background_mode = Environment.BG_SKY
		env.sky = Sky.new()
		env.sky.sky_material = ProceduralSkyMaterial.new()
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		env.fog_enabled = true
		env.adjustment_enabled = true
		env.glow_enabled = true
		env.glow_intensity = 0.5
		env.glow_hdr_threshold = 1.0
	var psm := env.sky.sky_material as ProceduralSkyMaterial
	if psm != null:
		psm.sky_top_color = Color(0.46, 0.52, 0.62).lerp(Color(0.42, 0.52, 0.66), k)
		psm.sky_horizon_color = Color(0.92, 0.80, 0.62).lerp(Color(0.98, 0.80, 0.55), k)
		psm.ground_horizon_color = Color(0.40, 0.32, 0.22).lerp(Color(0.66, 0.52, 0.36), k)
		psm.ground_bottom_color = Color(0.30, 0.24, 0.17)
		psm.sky_energy_multiplier = lerpf(1.6, 1.45, k)
		psm.sun_angle_max = 18.0
	env.fog_light_color = Color(0.60, 0.58, 0.48).lerp(Color(0.86, 0.70, 0.50), k)
	env.fog_density = lerpf(0.0095, 0.0022, k)
	env.fog_sun_scatter = 0.35
	env.fog_sky_affect = 0.3
	env.ambient_light_color = Color(0.50, 0.52, 0.46).lerp(Color(0.62, 0.54, 0.44), k)
	env.ambient_light_energy = lerpf(0.55, 0.62, k)
	env.tonemap_exposure = 1.05
	env.tonemap_white = 6.0
	env.adjustment_saturation = lerpf(1.0, 1.05, k)
	env.adjustment_contrast = lerpf(1.22, 1.15, k)
	sun.rotation_degrees = Vector3(lerpf(-14.0, -16.0, k), 160.0, 0.0)
	sun.light_color = Color(1.0, 0.82, 0.62).lerp(Color(1.0, 0.80, 0.56), k)
	sun.light_energy = lerpf(2.0, 2.3, k)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0


## Dry tan wagon-road dirt, world-tiled.
static func desert_ground_mat() -> StandardMaterial3D:
	var m: StandardMaterial3D = _tex_mat("tex_desert.jpg", Color(0.92, 0.82, 0.66), 0.22, "res://src/episode2/assets/textures/tex_gravel.jpg")
	m.roughness = 0.97
	return m


# --- the desert around the town (built identically by the woods and the town chamber) -------------------------------------

static func _hash01(x: float, z: float, k: float) -> float:
	var h: float = sin(x * 12.9898 * k + z * 78.233) * 43758.5453
	return h - floor(h)


static func _road_dist(p: Vector2, road: Array) -> float:
	var best: float = 1e9
	for i in range(road.size() - 1):
		var a: Vector2 = road[i]
		var b: Vector2 = road[i + 1]
		if maxf(a.y, b.y) < p.y - 60.0 or minf(a.y, b.y) > p.y + 60.0:
			continue
		var ab: Vector2 = b - a
		var t: float = clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best


## Gold-rush country from the last pines (forest_end_z - 100) to world_end_z: dry sage scrub in 60 m slices with draw distances,
## boulders, and mesas / rock hills on the horizon. Deterministic (hashed), so two rooms building it get the very same desert.
static func build_desert(parent: Node3D, road: Array, forest_end_z: float, world_end_z: float, scrub_mesh: Mesh, rock_mesh: Mesh,
		scrub_mat: Material, rock_mat: Material, z_from: float = -1e9) -> void:
	var rocks: Array = []
	var z: float = forest_end_z - 100.0
	while z < world_end_z:
		if z + 60.0 < z_from:
			z += 60.0
			continue
		var xf_s: Array = []
		var x: float = -160.0
		while x <= 160.0:
			var h1: float = _hash01(x, z, 11.3)
			var h2: float = _hash01(z, x, 13.7)
			var p := Vector2(x + (h1 - 0.5) * 6.0, z + (h2 - 0.5) * 6.0)
			var near_road: float = _road_dist(p, road)
			var in_town: bool = (absf(p.x) < 26.0 and p.y > TOWN_Z - 6.0 and p.y < TOWN_Z + 90.0) \
				or (p.y > RIVER_Z - RIVER_W and p.y < TRACK_Z + 8.0) \
				or JAIL_CLEAR.has_point(p) \
				or Ep2StableYard.PADDOCK.grow(6.0).has_point(p) or Ep2StableYard.ACCESS_CLEAR.has_point(p)
			var open_k: float = clampf((p.y - (forest_end_z - 100.0)) / 120.0, 0.0, 1.0)      # scrub takes over as the pines thin
			if near_road > 3.5 and not in_town and h1 < 0.55 * open_k:
				var sc: float = 0.6 + 0.9 * h2
				xf_s.append(Transform3D(Basis(Vector3.UP, h1 * TAU) * Basis.from_scale(Vector3(sc, sc * (0.6 + 0.5 * h1), sc)), Vector3(p.x, -0.05, p.y)))
			if near_road > 6.0 and not in_town and h2 > 0.965:
				rocks.append(Transform3D(Basis(Vector3.UP, h2 * TAU) * Basis.from_scale(Vector3.ONE * (0.8 + 2.6 * h1)), Vector3(p.x, -0.3, p.y)))
			x += 4.0
		if scrub_mesh != null and not xf_s.is_empty():
			var mm := _multi(parent, scrub_mesh, xf_s, scrub_mat, 150.0)
			mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mm.name = "DesertScrub_%d" % int(z)
		z += 60.0
	if rock_mesh != null and not rocks.is_empty():
		_multi(parent, rock_mesh, rocks, rock_mat, 220.0).name = "DesertRocks"
	# mesas and rock hills on the horizon (no draw distance: they ARE the horizon)
	var mesas: Array = []
	for k in 16:
		var side: float = -1.0 if k % 2 == 0 else 1.0
		var mz: float = 1050.0 + float(k) * 70.0 + 30.0 * _hash01(float(k), 3.0, 2.0)
		var mx: float = side * (190.0 + 160.0 * _hash01(float(k), 7.0, 5.0))
		var sc2: float = 26.0 + 30.0 * _hash01(float(k), 1.0, 9.0)
		mesas.append(Transform3D(Basis(Vector3.UP, float(k)) * Basis.from_scale(Vector3(sc2 * 1.6, sc2 * 0.55, sc2 * 1.2)), Vector3(mx, -sc2 * 0.12, mz)))
	for k in 6:
		var sc3: float = 60.0 + 25.0 * float(k % 3)
		mesas.append(Transform3D(Basis(Vector3.UP, float(k) * 1.3) * Basis.from_scale(Vector3(sc3 * 1.8, sc3 * 0.5, sc3)), Vector3(-260.0 + 105.0 * float(k), -sc3 * 0.1, 2050.0)))
	if rock_mesh != null:
		_multi(parent, rock_mesh, mesas, rock_mat, 0.0).name = "Mesas"


static func _multi(parent: Node3D, mesh: Mesh, xforms: Array, mat: Material, draw_dist: float) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	if draw_dist > 0.0:
		mmi.visibility_range_end = draw_dist
		mmi.visibility_range_end_margin = 12.0
	parent.add_child(mmi)
	return mmi


## The desert scrub: the founder's sage card (Muapi, keyed) on the wind shader, else the woods' fern card tinted dry.
static func scrub_mat() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://src/episode2/art/ep2_foliage_wind.gdshader")
	var card: String = TEX_DIR + "card_sage.png"
	var fern: String = "res://src/episode2/assets/woods/tex_woods_fern.png"
	if ResourceLoader.exists(card):
		m.set_shader_parameter("albedo_tex", load(card))
		m.set_shader_parameter("tint", Color(1.0, 1.0, 1.0))
	else:
		if ResourceLoader.exists(fern):
			m.set_shader_parameter("albedo_tex", load(fern))
		m.set_shader_parameter("tint", Color(0.95, 0.82, 0.52))
	m.set_shader_parameter("sway", 0.05)
	m.set_shader_parameter("speed", 1.4)
	m.set_shader_parameter("bend_height", 1.0)
	m.set_shader_parameter("flutter", 0.012)
	return m


static func desert_rock_mat() -> StandardMaterial3D:
	return _tex_mat("tex_sandstone.jpg", Color(0.86, 0.70, 0.52), 0.06, "res://src/episode2/assets/woods/tex_woods_floor.jpg")


## The kit meshes the desert needs, from the woods' kit (the same meshes the woods use): [scrub card mesh, rock mesh].
static func desert_meshes() -> Array:
	var fern: Mesh = null
	var rock: Mesh = null
	var fk: String = "res://src/episode2/assets/woods/forest_kit.glb"
	if ResourceLoader.exists(fk):
		var r: Node = (load(fk) as PackedScene).instantiate()
		var mi: MeshInstance3D = r.find_child("Fern", true, false) as MeshInstance3D
		if mi != null:
			fern = mi.mesh
		r.free()
	if ResourceLoader.exists(ROCK):
		var rr: Node = (load(ROCK) as PackedScene).instantiate()
		for n in rr.find_children("*", "MeshInstance3D", true, false):
			if (n as MeshInstance3D).mesh != null:
				rock = (n as MeshInstance3D).mesh
				break
		rr.free()
	return [fern, rock]
