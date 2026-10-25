extends Node
## The smelter's CAD prop kit in the real hideout (founder 2026-10-25: "hyperreal props, furnace, kegs, tools, surfaces - not grey
## primitives"): the facility is built exactly as the game builds it, inside a 1600x900 SubViewport (a tiled window would squash a direct
## viewport grab), and a camera visits each new or replaced piece - the kegs, the lying keg on its chocks, the anvil and ingot moulds, the
## Colts on the gun wall, the hanging chains, the leaning tools, the crates with their ammo box.
##   godot --rendering-driver opengl3 --path . res://tools/ep2_shots/smelter_kit_shot.tscn -- out=<dir> [fallback=1]
## fallback=1 forces the stand-ins (the look before the streamed kit is mounted on the web) for a before/after pair from one build.

const SMELT := preload("res://src/episode2/chamber/smelting_facility.tscn")
const VIEWS := [
	["kegs", Vector3(4.2, 1.8, 7.0), Vector3(6.3, 0.6, 5.9)],
	["lying_keg", Vector3(-3.9, 1.5, -2.2), Vector3(-6.2, 0.45, -0.5)],
	["anvil_moulds", Vector3(-3.2, 2.2, 15.4), Vector3(-6.3, 0.8, 14.1)],
	["gun_wall_colts", Vector3(-5.2, 1.5, 4.0), Vector3(-6.9, 1.3, 5.7)],
	["chains", Vector3(0.6, 3.2, -1.2), Vector3(-2.6, 4.3, 2.0)],
	["tools", Vector3(4.3, 1.6, 10.2), Vector3(6.5, 0.9, 12.2)],
	["crates_ammo", Vector3(2.6, 2.0, -1.0), Vector3(5.6, 1.0, -2.0)],
]


func _ready() -> void:
	var out := ".farm/smelter_kit"
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.split("=", true, 1)
		if kv.size() == 2 and kv[0] == "out":
			out = kv[1]
		if kv.size() == 2 and kv[0] == "fallback" and kv[1] == "1":
			Ep2KitProps.force_fallback = true
	DirAccess.make_dir_recursive_absolute(out)
	var vp := SubViewport.new()
	vp.size = Vector2i(1600, 900)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_4X
	add_child(vp)
	var f = SMELT.instantiate()
	f.intro_film = false
	vp.add_child(f)
	f.setup(0, [], 0)
	f.set_physics_process(false)                   # only this loop steps the scene (see facility_shot.gd)
	await get_tree().process_frame
	f._beat = f.Beat.DRINK
	f._has_winchester = true
	f._has_helmet = true
	f._player_pos = f.HAND_MARK
	for _i in 120:
		f.step(1.0 / 60.0)
		f._hold = 99.0
		await get_tree().process_frame
	# diagnosis switches (not used by the proof run): nonormal=1 turns the dressed materials' normal maps off, flat=1 puts back every
	# kit surface's own GLB material - so a look can be traced to the normal map, the scanned set or the geometry
	for a in OS.get_cmdline_user_args():
		if a == "nonormal=1" or a == "flat=1":
			for mi in f.find_children("*", "MeshInstance3D", true, false):
				var m: MeshInstance3D = mi
				if m.mesh == null:
					continue
				for si in m.mesh.get_surface_count():
					var om: StandardMaterial3D = m.get_surface_override_material(si) as StandardMaterial3D
					if om == null or not String(om.resource_name).begins_with("Pbr_"):
						continue
					if a == "flat=1":
						m.set_surface_override_material(si, null)
					else:
						var nm: StandardMaterial3D = om.duplicate() as StandardMaterial3D
						nm.normal_enabled = false
						m.set_surface_override_material(si, nm)
	var cam := Camera3D.new()
	cam.fov = 55.0
	vp.add_child(cam)
	cam.make_current()
	for v in VIEWS:
		cam.global_position = v[1]
		cam.look_at(v[2], Vector3.UP)
		for _j in 5:
			await get_tree().process_frame
		var path := "%s/%s.png" % [out, v[0]]
		vp.get_texture().get_image().save_png(path)
		print("SHOT ", path)
	get_tree().quit()
