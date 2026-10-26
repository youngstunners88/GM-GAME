class_name Ep2KitProps
extends RefCounted
## THE SMELTER'S CAD PROP KIT (founder 2026-10-25: "Inferno hideout smelting facility - hyperreal props, furnace, kegs, tools, surfaces -
## not grey primitives"; "weapons in facility ... match founder Winchester / revolver quality bar").
##
## One streamed GLB (Ep2Extras.SMELTER_KIT, built by tools/ep2_cad/smelter_kit_cad.py -> tools/ep2_blender/build_smelter_kit.py) holds one
## root per prop, all at REAL size on their own origin: Kit_Revolver (a Colt Single Action Army, barrel +z, origin on the bore at the
## cylinder's front face), Kit_Keg / Kit_KegSmall / Kit_Chock, Kit_Anvil (on its stump), Kit_Tongs, Kit_Ladle, Kit_Mould (a three-bar
## ingot mould), Kit_Shovel / Kit_Sledge / Kit_Pick (working end at the origin, handle along -z), Kit_ChainLink, Kit_Hook, Kit_Cartridge
## (a .45-70, base at the origin, +y), Kit_Crate (a 1 m planked crate, base centre) and Kit_AmmoBox. Instances are dressed by Ep2Pbr.
##
## THE TOWN'S CAD FURNITURE (founder 2026-10-25: "Town interiors - more furnished furniture and subtle details") is a second kit of the
## same kind: Ep2Extras.TOWN_FURNITURE (tools/ep2_cad/town_interior_cad.py -> tools/ep2_blender/build_town_interior_kit.py), roots named
## Twn_* (Twn_Bar, Twn_BackBar, Twn_Chair, Twn_Piano, Twn_Counter, Twn_Stove, Twn_Safe, Twn_Clock ...; Ep2GoldTown._furnish places them).
## Its colours are the town kit's own, written the way the town kit wrote them, so a Twn_ piece is dressed AS SHOWN (no kit tone) and
## reads exactly as bright as the box it replaces - only the hideout's Kit_ props take their intended (sRGB) colour.
##
## The hideout is built behind the opening film while the web build is still downloading the streamed pack, so a room never waits for
## it: `place()` builds the room's OLD primitive (the room's own builder, in the holder's frame) when the kit is not mounted yet, and
## `upgrade_pending()` - polled by the room - swaps every such holder to the CAD prop the moment the pack mounts. Desktop, tests and the
## editor have the kit at once.

const SCALE_HIDEOUT := 2.15          # the hideout is built to Inferno Bull's 2.9 m: its hand props read at about twice real size
const LINK_PITCH := 0.052            # the oval link's inner length (real metres): consecutive links thread through each other

## Tests force the fallback path to prove the upgrade (never set in the game).
static var force_fallback: bool = false

static var _kits: Dictionary = {}         # kit path -> the instantiated kit, kept OUT of the tree as the template
static var _pending: Array = []           # [holder, prop, local transform, stand, dress extra]
static var _link_mesh: Mesh = null
static var _intended: Dictionary = {}     # kit material instance id -> its copy in the intended colour (undressed surfaces)


## The kit GLB a prop comes from: Twn_* = the town's furniture, anything else (Kit_*) = the smelter's kit.
static func kit_path(prop: String) -> String:
	return Ep2Extras.TOWN_FURNITURE if prop.begins_with("Twn_") else Ep2Extras.SMELTER_KIT


## True when the kit holding `prop` can be loaded (no prop = the smelter's kit).
static func available(prop: String = "") -> bool:
	return not force_fallback and Ep2Extras.has(kit_path(prop))


## A fresh, dressed copy of the kit root `prop` ("Kit_Keg"), or null when the kit is not mounted / has no such prop. `extra` is passed to
## Ep2Pbr.dress (a room's own tone for a material, e.g. the hideout's warm crate timber).
static func instance(prop: String, extra: Dictionary = {}) -> Node3D:
	if not available(prop):
		return null
	var path: String = kit_path(prop)
	var kit: Node3D = _kit_at(path)
	if kit == null:
		return null
	var src: Node3D = kit.find_child(prop, true, false) as Node3D
	if src == null:
		return null
	var n: Node3D = src.duplicate() as Node3D
	n.transform = Transform3D.IDENTITY
	if path == Ep2Extras.TOWN_FURNITURE:
		Ep2Pbr.dress(n, extra)                      # the town's furniture: as shown, like the town kit it replaces
		return n
	# the kit's INTENDED colours (Ep2Pbr.dress kit_tone): the hideout's palette is set in sRGB, the GLB's colours show a stop brighter
	Ep2Pbr.dress(n, extra, [], true)
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		for si in m.mesh.get_surface_count():
			var base: BaseMaterial3D = m.mesh.surface_get_material(si) as BaseMaterial3D
			if m.get_surface_override_material(si) != null or base == null:
				continue
			# a surface Ep2Pbr does not dress (the lead bullets) takes its intended colour the same way
			var dm: BaseMaterial3D = _intended.get(base.get_instance_id())
			if dm == null:
				dm = base.duplicate() as BaseMaterial3D
				dm.albedo_color = base.albedo_color.srgb_to_linear()
				_intended[base.get_instance_id()] = dm
			m.set_surface_override_material(si, dm)
	return n


## The kit GLB at `path`, instantiated once and kept out of the tree as the template (null when it cannot be loaded).
static func _kit_at(path: String) -> Node3D:
	var kit: Node3D = _kits.get(path)
	if kit == null or not is_instance_valid(kit):
		var ps: PackedScene = load(path) as PackedScene
		if ps == null:
			return null
		kit = ps.instantiate() as Node3D
		_kits[path] = kit
	return kit


## The raw (undressed) mesh of kit root `prop` and its transform inside the root - for a MultiMesh of many copies (the street's
## trim): [Mesh, Transform3D], or [] when the kit is not mounted / has no such prop.
static func raw_mesh(prop: String) -> Array:
	if not available(prop):
		return []
	var kit: Node3D = _kit_at(kit_path(prop))
	var src: Node3D = kit.find_child(prop, true, false) as Node3D if kit != null else null
	if src == null:
		return []
	for mi in src.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		var xf := Transform3D.IDENTITY
		var c: Node = m
		while c != null and c != src:
			if c is Node3D:
				xf = (c as Node3D).transform * xf
			c = c.get_parent()
		return [m.mesh, xf]
	return []


## Put prop `prop` in a holder at `at` under `parent`; the CAD prop sits at `local` inside the holder (its turn, scale and offset), the
## room's old primitive - `fallback.call(holder)`, built in the holder's frame - stands in until the kit is mounted. `stand` lifts the CAD
## prop so its lowest point is on the holder's floor (y 0) after any turn. Returns the holder.
static func place(parent: Node3D, prop: String, at: Transform3D, local: Transform3D = Transform3D.IDENTITY, fallback: Callable = Callable(),
		stand: bool = false, extra: Dictionary = {}) -> Node3D:
	var holder := Node3D.new()
	holder.name = prop.replace("Kit_", "Prop_").replace("Twn_", "Prop_")
	holder.transform = at
	parent.add_child(holder, true)                # readable, numbered names (Prop_Keg, Prop_Keg2 ...): rooms and tests find them
	if not _fill(holder, prop, local, stand, extra):
		if fallback.is_valid():
			fallback.call(holder)
		_remember([holder, prop, local, stand, extra])
	return holder


## Swap every fallback holder to its CAD prop once the kit is mounted. Returns how many were upgraded (0 while still waiting).
static func upgrade_pending() -> int:
	if _pending.is_empty():
		return 0
	var done: int = 0
	var keep: Array = []
	for slot in _pending:
		var holder: Node3D = slot[0]
		if not is_instance_valid(holder):
			continue
		if not available(str(slot[1]) if str(slot[1]) != "@chain" else ""):
			keep.append(slot)
			continue
		var old: Array = holder.get_children()
		if _fill(holder, str(slot[1]), slot[2], bool(slot[3]), slot[4]):
			for c in old:
				holder.remove_child(c)
				(c as Node).queue_free()
			done += 1
		else:
			keep.append(slot)
	_pending = keep
	return done


static func pending_count() -> int:
	return _pending.size()


## Forget stand-ins whose room has been freed (a chamber left before the kit mounted), so the list never holds dead holders.
static func _remember(slot: Array) -> void:
	_pending = _pending.filter(func(s: Array) -> bool: return is_instance_valid(s[0]))
	_pending.append(slot)


## A hanging chain of real oval links from `top` down `length` m (one MultiMesh, links alternately turned 90 degrees) ending in a hook;
## `link_scale` sizes the link. The room's old chain (`fallback`, in the holder's frame) stands in until the kit is mounted.
static func chain(parent: Node3D, top: Vector3, length: float, link_scale: float, fallback: Callable = Callable()) -> Node3D:
	var at := Transform3D(Basis.IDENTITY, top)
	var holder := Node3D.new()
	holder.name = "Prop_Chain"
	holder.transform = at
	parent.add_child(holder, true)                # readable, numbered names (Prop_Keg, Prop_Keg2 ...): rooms and tests find them
	var spec := Transform3D(Basis.IDENTITY.scaled(Vector3(length, link_scale, 1.0)), Vector3.ZERO)
	if not _fill(holder, "@chain", spec, false, {}):
		if fallback.is_valid():
			fallback.call(holder)
		_remember([holder, "@chain", spec, false, {}])
	return holder


static func _fill(holder: Node3D, prop: String, local: Transform3D, stand: bool, extra: Dictionary) -> bool:
	if prop == "@chain":
		return _fill_chain(holder, local.basis.x.x, local.basis.y.y)
	var n: Node3D = instance(prop, extra)
	if n == null:
		return false
	n.transform = local
	holder.add_child(n)
	if stand:
		var box: AABB = _aabb_in(holder, n)
		n.position.y -= box.position.y
	return true


static func _fill_chain(holder: Node3D, length: float, link_scale: float) -> bool:
	if not available():
		return false
	if _link_mesh == null:
		var link: Node3D = instance("Kit_ChainLink")
		if link == null:
			return false
		for mi in link.find_children("*", "MeshInstance3D", true, false):
			var m: MeshInstance3D = mi
			_link_mesh = m.mesh.duplicate() as Mesh
			for si in _link_mesh.get_surface_count():
				var dressed: Material = m.get_surface_override_material(si)
				if dressed != null:
					_link_mesh.surface_set_material(si, dressed)
			break
		link.free()
		if _link_mesh == null:
			return false
	var pitch: float = LINK_PITCH * link_scale
	var count: int = maxi(2, int(length / pitch))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _link_mesh
	mm.instance_count = count
	for i in count:
		var b: Basis = Basis(Vector3.UP, PI * 0.5 * float(i % 2)).scaled(Vector3.ONE * link_scale)
		mm.set_instance_transform(i, Transform3D(b, Vector3(0.0, -pitch * (float(i) + 0.5), 0.0)))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Links"
	mmi.multimesh = mm
	holder.add_child(mmi)
	var hook: Node3D = instance("Kit_Hook")
	if hook != null:
		hook.scale = Vector3.ONE * link_scale
		hook.position = Vector3(0.0, -pitch * float(count) - 0.01 * link_scale, 0.0)
		holder.add_child(hook)
	return true


## `n`'s mesh bounds in `holder`'s frame (n is a child of holder, possibly turned / scaled).
static func _aabb_in(holder: Node3D, n: Node3D) -> AABB:
	var out := AABB()
	var first: bool = true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		if m.mesh == null:
			continue
		var xf := Transform3D.IDENTITY
		var c: Node = m
		while c != null and c != holder:
			if c is Node3D:
				xf = (c as Node3D).transform * xf
			c = c.get_parent()
		var bx: AABB = xf * m.mesh.get_aabb()
		out = bx if first else out.merge(bx)
		first = false
	return out
