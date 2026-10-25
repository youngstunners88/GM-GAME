extends Node
## EP2 TOWN FURNITURE (founder 2026-10-25: "Town interiors - more furnished furniture and subtle details (Certificate, Saloon, Armory, Jail
## as touched)"; "do not ship grey boxes or low-poly placeholders where CAD can replace them").
##  * The streamed CAD kit (tools/ep2_cad/town_interior_cad.py -> tools/ep2_blender/build_town_interior_kit.py) carries every piece the
##    rooms ask for, as real geometry, dressed by Ep2Pbr, at the town kit's own colours (a CAD piece reads as bright as the box it
##    replaces; the saloon's keep their darker mahogany).
##  * The kit's box furniture (bar, back bar, tables, chairs, piano; the office's counter, pigeonholes, desk, stove) is replaced at the
##    SAME transform; the old piece stands in until the pack mounts and is upgraded in place.
##  * The new detail (cuspidors, hall trees, clocks with swinging pendulums, the safe, bench, captain's chair, lamps, the chandelier on
##    its chain, the jail's lantern, keys, coffee, bucket, supper, broom) is there, its floor pieces block the walk, and none of it
##    stands on a story mark or a townsperson's route.
## Run: godot --headless res://tests/ep2_town_furniture_test.tscn

const PIECES := ["Twn_Bar", "Twn_BackBar", "Twn_Table", "Twn_Chair", "Twn_PokerSet", "Twn_TableDrinks", "Twn_Piano", "Twn_PianoStool",
	"Twn_Spittoon", "Twn_HangLamp", "Twn_Chandelier", "Twn_Clock", "Twn_ClockPendulum", "Twn_HatRack", "Twn_Counter", "Twn_Pigeonholes",
	"Twn_Desk", "Twn_DeskLamp", "Twn_DeskChair", "Twn_Stove", "Twn_CoffeePot", "Twn_WoodBox", "Twn_Safe", "Twn_Bench", "Twn_Lantern",
	"Twn_KeyRing", "Twn_Bucket", "Twn_TinPlate", "Twn_Broom", "Twn_Workbench", "Twn_GunBoard"]
## Pieces with no PBR-dressed material (glass, paper, chips, tin): exempt from the "photo-scanned" check.
const UNDRESSED := ["Twn_PokerSet", "Twn_TableDrinks", "Twn_TinPlate"]
var failures := 0


func check(label: String, ok: bool, detail: String = "") -> void:
	print("  [%s] %s %s" % ["PASS" if ok else "FAIL", label, detail if not ok else ""])
	if not ok:
		failures += 1


static func _tris(n: Node) -> int:
	var t: int = 0
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = (mi as MeshInstance3D).mesh
		if m == null:
			continue
		for si in m.get_surface_count():
			var idx: PackedInt32Array = m.surface_get_arrays(si)[Mesh.ARRAY_INDEX]
			t += idx.size() / 3 if idx.size() > 0 else (m.surface_get_arrays(si)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return t


## The material named `mat_name` on n's first mesh: [the GLB's own (source) material, the override Ep2Pbr dressed it with].
static func _surface(n: Node, mat_name: String) -> Array:
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		for si in m.mesh.get_surface_count():
			var src: Material = m.mesh.surface_get_material(si)
			if src != null and String(src.resource_name).get_slice(".", 0) == mat_name:
				return [src, m.get_surface_override_material(si)]
	return [null, null]


static func _lum(c: Color) -> float:
	return c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722


## Distance from point p to segment ab (ground plane).
static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var t: float = clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _ready() -> void:
	print("EP2 TOWN FURNITURE:")
	check("the streamed CAD furniture is on disk", Ep2KitProps.available("Twn_Bar"))
	var missing: Array = []
	var thin: Array = []
	var flat: Array = []
	var total: int = 0
	var chair_tris: int = 0
	for p in PIECES:
		var n: Node3D = Ep2KitProps.instance(p)
		if n == null:
			missing.append(p)
			continue
		add_child(n)
		var t: int = _tris(n)
		total += t
		if p == "Twn_Chair":
			chair_tris = t
		if t < 100:
			thin.append("%s %d" % [p, t])
		var dressed: bool = false
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			for si in (mi as MeshInstance3D).mesh.get_surface_count():
				var om: Material = (mi as MeshInstance3D).get_surface_override_material(si)
				if om != null and String(om.resource_name).begins_with("Pbr_"):
					dressed = true
		if not dressed and not (p in UNDRESSED):
			flat.append(p)
		n.queue_free()
	check("every piece the rooms ask for is in the kit (31: bar, back bar, tables, bentwood chairs, piano, lamps, clocks, counter, safe ...)",
		missing.is_empty(), str(missing))
	check("...each is real CAD geometry, not a box (>= 100 triangles)", thin.is_empty(), str(thin))
	check("...and its wood / brass / iron / leather is photo-scanned (Ep2Pbr)", flat.is_empty(), str(flat))
	check("...within the web budget: the whole kit under 110k triangles, a saloon chair (eleven are on screen) under 4k",
		total > 0 and total < 110000 and chair_tris > 0 and chair_tris < 4000, "%d total, chair %d" % [total, chair_tris])

	print("-- the CAD piece reads as bright as the box it replaces")
	var kit: Node3D = (load(Ep2Extras.TOWN_KIT if Ep2Extras.has(Ep2Extras.TOWN_KIT) else Ep2GoldTown.KIT) as PackedScene).instantiate() as Node3D
	var old_counter: Node3D = kit.find_child("Int_Counter", true, false) as Node3D
	var cad_counter: Node3D = Ep2KitProps.instance("Twn_Counter")
	add_child(cad_counter)
	var old_dw: Material = _surface(old_counter, "DarkWood")[0]
	var cad_dw: Array = _surface(cad_counter, "DarkWood")
	check("the CAD counter's dark wood is the town kit's own colour (the same glTF value), dressed as shown",
		old_dw is BaseMaterial3D and cad_dw[0] is BaseMaterial3D
		and (old_dw as BaseMaterial3D).albedo_color.is_equal_approx((cad_dw[0] as BaseMaterial3D).albedo_color)
		and cad_dw[1] is StandardMaterial3D and String((cad_dw[1] as StandardMaterial3D).resource_name) == "Pbr_wood_dark",
		"%s vs %s" % [str((old_dw as BaseMaterial3D).albedo_color) if old_dw is BaseMaterial3D else "?", str((cad_dw[0] as BaseMaterial3D).albedo_color) if cad_dw[0] is BaseMaterial3D else "?"])
	var plain_bar: Node3D = Ep2KitProps.instance("Twn_Bar")
	var saloon_bar: Node3D = Ep2KitProps.instance("Twn_Bar", Ep2GoldTown.TOWN_TONE)
	add_child(plain_bar)
	add_child(saloon_bar)
	var plain_gw: Material = _surface(plain_bar, "GunWood")[1]
	var sal_gw: Material = _surface(saloon_bar, "GunWood")[1]
	var sal_dw: Material = _surface(saloon_bar, "DarkWood")[1]
	check("...the walnut panels are toned down to the old fronts' brightness, the dark wood is the kit's own, untoned",
		plain_gw is StandardMaterial3D and sal_gw is StandardMaterial3D and sal_dw is StandardMaterial3D
		and _lum((sal_gw as StandardMaterial3D).albedo_color) < _lum((plain_gw as StandardMaterial3D).albedo_color) * 0.8
		and (sal_dw as StandardMaterial3D).albedo_color.is_equal_approx((cad_dw[1] as StandardMaterial3D).albedo_color))
	plain_bar.queue_free()
	cad_counter.queue_free()
	saloon_bar.queue_free()

	print("-- the old piece stands in until the pack mounts, then turns into the CAD one in place")
	var room := Node3D.new()
	add_child(room)
	Ep2KitProps.force_fallback = true
	var old_chair: Node3D = kit.find_child("Bar_Chair", true, false) as Node3D
	var at := Transform3D(Basis(Vector3.UP, 0.7), Vector3(2.0, 0.0, 3.0))
	var slot: Node3D = Ep2GoldTown._cad_piece(room, "Twn_Chair", at, old_chair)
	check("without the pack, the kit's box chair stands in, at the chair's place", slot.get_child_count() == 1
		and str(slot.get_child(0).name) == "Bar_Chair" and slot.transform.is_equal_approx(at), str(slot.get_children()))
	Ep2KitProps.force_fallback = false
	var up: int = Ep2KitProps.upgrade_pending()
	await get_tree().process_frame
	check("...the moment the pack mounts it is the bentwood chair, same holder, same place", up >= 1 and slot.get_child_count() == 1
		and str(slot.get_child(0).name) == "Twn_Chair" and slot.transform.is_equal_approx(at), "%d upgraded %s" % [up, str(slot.get_children())])
	room.queue_free()
	kit.free()

	print("-- the town's rooms, furnished")
	var visuals := Node3D.new()
	add_child(visuals)
	var col: Dictionary = Ep2GoldTown.build(visuals, true)
	var town: Node3D = visuals.get_child(0) as Node3D
	var replaced := {"Int_Counter_Bldg_Certificates": ["Twn_Counter", "Bldg_Certificates", Vector3(0.6, 0.0, -4.6), 0.0],
		"Int_Shelves_Bldg_Certificates": ["Twn_Pigeonholes", "Bldg_Certificates", Vector3(0.6, 0.0, -8.6), 0.0],
		"Int_Desk_Bldg_Certificates": ["Twn_Desk", "Bldg_Certificates", Vector3(-2.3, 0.0, -7.0), 0.0],
		"Int_Stove_Bldg_Certificates": ["Twn_Stove", "Bldg_Certificates", Vector3(-3.0, 0.0, -2.4), 0.0],
		"Bar_Counter_Bldg_Saloon": ["Twn_Bar", "Bldg_Saloon", Vector3(-1.0, 0.0, -9.0), 0.0],
		"Bar_BackShelf_Bldg_Saloon": ["Twn_BackBar", "Bldg_Saloon", Vector3(-1.0, 0.0, -11.6), 0.0],
		"Bar_Piano_Bldg_Saloon": ["Twn_Piano", "Bldg_Saloon", Vector3(4.9, 0.0, -10.6), -PI * 0.5]}
	var wrong: Array = []
	for nm in replaced:
		var r: Array = replaced[nm]
		var h: Node3D = town.find_child(nm, false, false) as Node3D
		var want: Transform3D = Ep2GoldTown.building_xform(Ep2GoldTown.entry(str(r[1]))) * Transform3D(Basis(Vector3.UP, float(r[3])), r[2])
		if h == null or h.get_child_count() != 1 or str(h.get_child(0).name) != str(r[0]) or not h.transform.is_equal_approx(want):
			wrong.append(nm)
	check("the office's counter, pigeonholes, desk and stove and the saloon's bar, back bar and piano are the CAD pieces, where the old ones stood",
		wrong.is_empty(), str(wrong))
	var tables: int = 0
	var chairs: int = 0
	for h in town.get_children():
		if h.get_child_count() == 1 and str(h.get_child(0).name) == "Twn_Table":
			tables += 1
		if h.get_child_count() == 1 and str(h.get_child(0).name) == "Twn_Chair":
			chairs += 1
	check("...three saloon tables and the balcony's little one; nine chairs round the tables and two on the balcony, all bentwood",
		tables == 4 and chairs == 11, "%d tables, %d chairs" % [tables, chairs])
	var count := func(prefix: String, piece: String) -> int:
		return town.get_children().filter(func(n: Node) -> bool: return str(n.name).begins_with(prefix) and str(n.name).contains(piece)).size()
	check("the saloon's new detail: four cuspidors, the hall tree, the regulator, the piano stool, a poker spread and two rounds of drinks",
		count.call("Prop_Spittoon", "Saloon") == 4 and count.call("Prop_HatRack", "Saloon") == 1 and count.call("Prop_Clock", "Saloon") == 1
		and count.call("Prop_PianoStool", "Saloon") == 1 and count.call("Prop_PokerSet", "Saloon") == 1 and count.call("Prop_TableDrinks", "Saloon") == 2)
	check("the office's: captain's chair, desk lamp, safe, waiting bench, regulator, hall tree, stove wood, a cuspidor",
		count.call("Prop_DeskChair", "Certificates") == 1 and count.call("Prop_DeskLamp", "Certificates") == 1 and count.call("Prop_Safe", "Certificates") == 1
		and count.call("Prop_Bench", "Certificates") == 1 and count.call("Prop_Clock", "Certificates") == 1 and count.call("Prop_HatRack", "Certificates") == 1
		and count.call("Prop_WoodBox", "Certificates") == 1 and count.call("Prop_Spittoon", "Certificates") == 1)
	if Ep2GoldTown.jail_v1:
		check("the jail's: lantern, keys, regulator, coffee pot on the stove, water bucket, the prisoner's supper, a broom, a cuspidor",
			count.call("Prop_Lantern", "Jail") == 1 and count.call("Prop_KeyRing", "Jail") == 1 and count.call("Prop_Clock", "Jail") == 1
			and count.call("Prop_CoffeePot", "Jail") == 1 and count.call("Prop_Bucket", "Jail") == 1 and count.call("Prop_TinPlate", "Jail") == 1
			and count.call("Prop_Broom", "Jail") == 1 and count.call("Prop_Spittoon", "Jail") == 1)
	var pendulums: Array = town.find_children("Pendulum_*", "Node3D", false, false)
	check("every regulator has its pendulum on its pivot", pendulums.size() == (3 if Ep2GoldTown.jail_v1 else 2)
		and pendulums.all(func(p: Node) -> bool: return p is Ep2Pendulum and p.get_child_count() == 1 and p.get_child(0).find_child("Twn_ClockPendulum", false, false) != null),
		str(pendulums.size()))
	var chand: Node3D = town.find_child("Prop_Chandelier_Bldg_Saloon", false, false) as Node3D
	var want_c: Vector3 = Ep2GoldTown.local_to_world("Bldg_Saloon", Vector3(-2.0, 3.2 + 0.76, -4.0))
	var chains: Array = town.find_children("Prop_Chain*", "Node3D", false, false)
	check("the wagon-wheel chandelier hangs on a real chain from the ceiling, its flames where the saloon's warm light is",
		chand != null and chand.get_child_count() == 1 and chand.position.is_equal_approx(want_c) and chains.size() == 1
		and (chains[0] as Node).find_child("Links", true, false) != null
		and absf((chains[0] as Node3D).position.y - Ep2GoldTown.CEILING_Y) < 0.01)
	check("...and the harp lamps hang on rods over the bar end and the office counter", count.call("Prop_HangLamp", "Saloon") == 1
		and count.call("Prop_HangLamp", "Certificates") == 1 and town.find_children("LampRod*", "MeshInstance3D", false, false).size() == 2)
	check("nothing waits for the pack on desktop (no stand-ins left)", Ep2KitProps.pending_count() == 0, str(Ep2KitProps.pending_count()))

	print("-- the new floor pieces block the walk, and stand on no story mark or route")
	var props: Array = col.get("props", [])
	var blocked := func(local: Vector3, piece: String) -> bool:
		var w: Vector3 = Ep2GoldTown.local_to_world(piece, local)
		return props.any(func(pr: Array) -> bool: return (pr[0] as Vector2).distance_to(Vector2(w.x, w.z)) < float(pr[1]))
	check("the safe, the bench, both hall trees, the captain's chair, the wood box and the piano stool are solid",
		blocked.call(Vector3(3.05, 0, -8.45), "Bldg_Certificates") and blocked.call(Vector3(-3.55, 0, -4.0), "Bldg_Certificates")
		and blocked.call(Vector3(-3.55, 0, -4.8), "Bldg_Certificates") and blocked.call(Vector3(1.6, 0, -0.5), "Bldg_Certificates")
		and blocked.call(Vector3(-2.6, 0, -0.55), "Bldg_Saloon") and blocked.call(Vector3(-2.3, 0, -7.75), "Bldg_Certificates")
		and blocked.call(Vector3(-3.45, 0, -1.55), "Bldg_Certificates") and blocked.call(Vector3(4.15, 0, -10.6), "Bldg_Saloon"))
	# the story's marks (gold_town.gd) and the minister's panic run, the saloon drinkers' routes, the jail's stand points
	var marks: Array = []
	for m in [GoldTownChamber.OFFICE_SPOT, GoldTownChamber.MINISTER_DESK, GoldTownChamber.SHERIFF_OFFICE_AT, Vector3(3.2, 0, -5.4), Vector3(3.2, 0, -3.4),
			Vector3(0.6, 0, -2.0), Vector3(0.0, 0, -0.9)]:
		marks.append(["Bldg_Certificates", m])
	for m in [GoldTownChamber.BAR_SPOT, GoldTownChamber.BARTENDER_AT, GoldTownChamber.OPP_AT_BAR, GoldTownChamber.SHERIFF_SALOON, Vector3(0.0, 0, -0.9)]:
		marks.append(["Bldg_Saloon", m])
	for bx in Ep2GoldTown.BAR_SPOTS:
		marks.append(["Bldg_Saloon", Vector3(float(bx), 0.0, Ep2GoldTown.BAR_Z)])
	if Ep2GoldTown.jail_v1:
		for k in Ep2GoldTown.jail_spots:
			if str(k) != "privy" and str(k) != "lane":
				marks.append(["Bldg_Jail", Ep2GoldTown.jail_spots[k]])
	var crowded: Array = []
	for d in Ep2GoldTown.ROOM_DETAIL:
		var fp: Vector2 = d[4]
		var is_floor: bool = fp != Vector2.ZERO or str(d[1]) in ["Twn_Spittoon", "Twn_Bucket", "Twn_Broom", "Twn_TinPlate"]
		if not is_floor or Ep2GoldTown.entry(str(d[0])).is_empty() or (str(d[0]) == "Bldg_Jail" and not Ep2GoldTown.jail_v1):
			continue
		var w: Vector3 = Ep2GoldTown.local_to_world(str(d[0]), d[2])
		var r: float = maxf(fp.x, fp.y) * 0.5 if fp != Vector2.ZERO else 0.17
		for mk in marks:
			if str(mk[0]) != str(d[0]):
				continue
			var mw: Vector3 = Ep2GoldTown.local_to_world(str(mk[0]), mk[1])
			if Vector2(w.x, w.z).distance_to(Vector2(mw.x, mw.z)) < r + 0.35:
				crowded.append("%s@%s near %s" % [d[1], str(d[2]), str(mk[1])])
		if str(d[0]) == "Bldg_Saloon":
			for seat in Ep2GoldTown.saloon_seats():
				var pts: Array = [Ep2GoldTown.door_world("Bldg_Saloon", -0.9)] + (seat["route"] as Array)
				for i in pts.size() - 1:
					var a: Vector3 = pts[i]
					var b: Vector3 = pts[i + 1]
					if _seg_dist(Vector2(w.x, w.z), Vector2(a.x, a.z), Vector2(b.x, b.z)) < r + 0.3:
						crowded.append("%s@%s on a drinker's route" % [d[1], str(d[2])])
				var sp: Vector3 = seat["pos"]
				if absf(sp.y - w.y) < 1.0 and Vector2(w.x, w.z).distance_to(Vector2(sp.x, sp.z)) < r + 0.3:
					crowded.append("%s@%s on a seat" % [d[1], str(d[2])])
	check("...and none of them stands on a story mark, the minister's run, a drinker's place or route, or a jail stand point",
		crowded.is_empty(), str(crowded))

	print("-- a regulator keeps time")
	var pend: Ep2Pendulum = pendulums[0] if pendulums.size() > 0 else null
	var z0: float = pend.rotation.z if pend != null else 0.0
	for i in 20:
		await get_tree().process_frame
	check("its pendulum swings (a few degrees about its pivot)", pend != null and absf(pend.rotation.z - z0) > 0.001
		and absf(pend.rotation.z) <= pend.amplitude + 1e-4, "%.4f -> %.4f" % [z0, pend.rotation.z if pend != null else 0.0])
	print("EP2_TOWN_FURNITURE: %s" % ["ALL PASS" if failures == 0 else "%d FAILURE(S)" % failures])
	get_tree().quit(failures)
