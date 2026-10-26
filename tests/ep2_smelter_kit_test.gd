extends Node
## EP2 SMELTER KIT (founder 2026-10-25: "Inferno hideout smelting facility - hyperreal props, furnace, kegs, tools, surfaces - not grey
## primitives"; "weapons in facility ... match founder Winchester / revolver quality bar").
##  * The streamed CAD kit (tools/ep2_cad/smelter_kit_cad.py -> tools/ep2_blender/build_smelter_kit.py) carries every prop the hideout asks for,
##    real geometry, dressed by Ep2Pbr.
##  * Ep2KitProps places the CAD prop when the kit is mounted; when it is not (the web build is still downloading), the room's OLD primitive
##    stands in and is swapped to the CAD prop the moment the kit mounts - never a missing prop, never a wait.
##  * The hideout itself is built with the CAD Colts on the gun wall, real chains, the kit's crates, ammo boxes and tools, and the new kegs,
##    anvil, ingot moulds and pick - with blockers for the new pieces.
## Run: godot --headless res://tests/ep2_smelter_kit_test.tscn

const PROPS := ["Kit_Revolver", "Kit_Keg", "Kit_KegSmall", "Kit_Chock", "Kit_Anvil", "Kit_Tongs", "Kit_Ladle", "Kit_Mould", "Kit_Shovel",
	"Kit_Sledge", "Kit_Pick", "Kit_ChainLink", "Kit_Hook", "Kit_Cartridge", "Kit_Crate", "Kit_AmmoBox",
	"Kit_FurnaceDoors", "Kit_FurnaceHood", "Kit_Bellows", "Kit_FireTools"]
var failures := 0


func check(label: String, ok: bool, detail: String = "") -> void:
	print("  [%s] %s %s" % ["PASS" if ok else "FAIL", label, detail if not ok else ""])
	if not ok:
		failures += 1


## Kit holders under `root` whose name is `base` or `base` + a number (Prop_Keg, Prop_Keg2 ... but not Prop_KegSmall).
static func _props(root: Node, base: String) -> Array:
	return root.find_children(base + "*", "Node3D", true, false).filter(func(n: Node) -> bool:
		var rest: String = str(n.name).substr(base.length())
		return rest == "" or rest.is_valid_int())


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


func _ready() -> void:
	print("EP2 SMELTER KIT:")
	check("the streamed CAD kit is on disk", Ep2KitProps.available())
	var missing: Array = []
	var flat: Array = []
	var thin: Array = []
	for p in PROPS:
		var n: Node3D = Ep2KitProps.instance(p)
		if n == null:
			missing.append(p)
			continue
		add_child(n)
		if _tris(n) < 100:
			thin.append("%s %d" % [p, _tris(n)])
		var dressed: bool = false
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			for si in (mi as MeshInstance3D).mesh.get_surface_count():
				var om: Material = (mi as MeshInstance3D).get_surface_override_material(si)
				if om != null and String(om.resource_name).begins_with("Pbr_"):
					dressed = true
		if not dressed:
			flat.append(p)
		n.queue_free()
	check("every prop the hideout asks for is in the kit (Colt, kegs, chock, anvil, tongs, ladle, mould, shovel, sledge, pick, chain, hook, round, crate, ammo box)",
		missing.is_empty(), str(missing))
	check("...each is real CAD geometry, not a box (>= 100 triangles)", thin.is_empty(), str(thin))
	check("...and comes in photo-scanned (Ep2Pbr) on its metal / wood surfaces", flat.is_empty(), str(flat))

	print("-- a stand-in when the kit is not mounted yet, upgraded in place when it is")
	var room := Node3D.new()
	add_child(room)
	var at := Transform3D(Basis.IDENTITY, Vector3(1.0, 0.0, 2.0))
	var direct: Node3D = Ep2KitProps.place(room, "Kit_Keg", at, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 1.5), Vector3.ZERO))
	check("with the kit mounted, place() puts the CAD prop in the holder at once", direct.get_child_count() == 1
		and str(direct.get_child(0).name) == "Kit_Keg" and direct.position.is_equal_approx(Vector3(1.0, 0.0, 2.0)), str(direct.get_children()))
	Ep2KitProps.force_fallback = true
	var stood: Array = []
	var slot: Node3D = Ep2KitProps.place(room, "Kit_Crate", at, Transform3D.IDENTITY, func(h: Node3D) -> void:
		var b := MeshInstance3D.new()
		b.name = "OldBox"
		b.mesh = BoxMesh.new()
		h.add_child(b)
		stood.append(b))
	check("without the kit, the room's own old primitive stands in (built in the holder's frame)", stood.size() == 1 and slot.get_child_count() == 1
		and str(slot.get_child(0).name) == "OldBox")
	check("...and the slot waits for the kit", Ep2KitProps.pending_count() >= 1)
	check("...nothing is upgraded while the kit is still missing", Ep2KitProps.upgrade_pending() == 0 and str(slot.get_child(0).name) == "OldBox")
	Ep2KitProps.force_fallback = false
	var up: int = Ep2KitProps.upgrade_pending()
	await get_tree().process_frame
	check("the moment the kit mounts, the stand-in becomes the CAD crate in the same holder", up >= 1 and slot.get_child_count() == 1
		and str(slot.get_child(0).name) == "Kit_Crate" and Ep2KitProps.pending_count() == 0, "%d upgraded, children %s" % [up, str(slot.get_children())])
	var chain: Node3D = Ep2KitProps.chain(room, Vector3(0.0, 6.0, 0.0), 3.0, 3.4)
	var mmi: MultiMeshInstance3D = chain.find_child("Links", true, false) as MultiMeshInstance3D
	check("a hanging chain is real oval links (one MultiMesh) down its length, ending in the hook",
		mmi != null and mmi.multimesh.instance_count == int(3.0 / (Ep2KitProps.LINK_PITCH * 3.4)) and chain.find_child("Kit_Hook", true, false) != null,
		str(mmi.multimesh.instance_count if mmi != null else -1))
	room.queue_free()

	print("-- the hideout, dressed with the kit")
	var visuals := Node3D.new()
	add_child(visuals)
	var d: Dictionary = await HideoutDressing.build(visuals, false)
	var revolvers: Array = _props(visuals, "Prop_Revolver")
	var cad_revs: int = 0
	var rev_len: float = 0.0
	for r in revolvers:
		var k: Node3D = (r as Node3D).find_child("Kit_Revolver", false, false) as Node3D
		if k != null:
			cad_revs += 1
			rev_len = Ep2KitProps._aabb_in(r, k).size.z
	check("the gun wall's six revolvers are the CAD Colt", revolvers.size() == 6 and cad_revs == 6, "%d holders, %d CAD" % [revolvers.size(), cad_revs])
	check("...at the old prop's size on the wall (about 0.6-0.7 m at Inferno's scale)", rev_len > 0.55 and rev_len < 0.75, "%.3f m" % rev_len)
	var chains: Array = _props(visuals, "Prop_Chain")
	check("the eight hanging chains are real links", chains.size() == 8 and chains.all(func(c: Node) -> bool: return c.find_child("Links", true, false) != null),
		str(chains.size()))
	check("the crates and the open ammo boxes are the kit's", _props(visuals, "Prop_Crate").size() >= 10
		and _props(visuals, "Prop_AmmoBox").size() == 3)
	check("the shovel, the sledge and a pick lean on the walls", _props(visuals, "Prop_Shovel").size() == 1
		and _props(visuals, "Prop_Sledge").size() == 1 and _props(visuals, "Prop_Pick").size() == 1)
	var smithy: Node3D = visuals.find_child("HideoutSmithy", true, false) as Node3D
	check("the new working floor: three kegs and a lying one on two chocks, the anvil with its tongs, two ingot moulds",
		smithy != null and _props(smithy, "Prop_Keg").size() == 3 and _props(smithy, "Prop_KegSmall").size() == 1
		and _props(smithy, "Prop_Chock").size() == 2 and _props(smithy, "Prop_Anvil").size() == 1
		and _props(smithy, "Prop_Tongs").size() == 1 and _props(smithy, "Prop_Mould").size() == 2)
	var bl: Array = d.get("blockers", [])
	var has := func(p: Vector2) -> bool: return bl.any(func(b: Array) -> bool: return (b[0] as Vector2).distance_to(p) < 0.3)
	check("...each new standing group blocks the walk (kegs, the lying keg, the anvil, the moulds)",
		has.call(Vector2(6.25, 6.0)) and has.call(Vector2(-6.2, -0.5)) and has.call(Vector2(-5.9, 14.2)) and has.call(Vector2(-7.1, 14.0)))
	check("the furnace has its CAD front: the iron doors swung open, the riveted hood and flue, the bellows, the fire tools",
		_props(visuals, "Prop_FurnaceDoors").size() == 1 and _props(visuals, "Prop_FurnaceHood").size() == 1
		and _props(visuals, "Prop_Bellows").size() == 1 and _props(visuals, "Prop_FireTools").size() == 1
		and visuals.find_children("Kit_FurnaceDoors", "Node3D", true, false).size() == 1)
	check("...the open right-hand door and the tools block the walk; the bellows and the left door are beyond the walk clamp (x -6.3)",
		has.call(Vector2(-4.95, 15.05)) and has.call(Vector2(HideoutDressing.FIRE_TOOLS_AT.x, HideoutDressing.FIRE_TOOLS_AT.z))
		and HideoutDressing.BELLOWS_AT.x < -6.8)
	check("nothing waits for the kit on desktop (no stand-ins left)", Ep2KitProps.pending_count() == 0, str(Ep2KitProps.pending_count()))
	var lying: Node3D = null
	for k in _props(smithy, "Prop_Keg"):
		var kk: Node3D = (k as Node3D).get_child(0) as Node3D
		if absf(kk.transform.basis.y.normalized().y) < 0.1:
			lying = k
	check("...the lying keg rests on its chocks (its bilge at the cradle height, axis level)", lying != null
		and absf(Ep2KitProps._aabb_in(lying, lying.get_child(0)).position.y - (0.30 - 0.245) * 1.5) < 0.03,
		str(Ep2KitProps._aabb_in(lying, lying.get_child(0)) if lying != null else "none"))
	print("EP2_SMELTER_KIT: %s" % ["ALL PASS" if failures == 0 else "%d FAILURE(S)" % failures])
	get_tree().quit(failures)
