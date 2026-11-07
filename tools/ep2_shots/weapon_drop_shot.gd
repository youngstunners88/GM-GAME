extends Node
## A dead trail bandit's Borchardt and its box of rounds in the dirt by his body (founder 2026-11-07, Ep2WeaponDrop), seen from the saddle:
## from the trail, then ridden up to it (prompt in reach), then after riding over it.
##   godot --rendering-method gl_compatibility --rendering-driver opengl3 --path . res://tools/ep2_shots/weapon_drop_shot.tscn -- out=<dir>
var out := ".farm/weapon-drop"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var session = load("res://src/episode2/session/ep2_session_root.tscn").instantiate()
	vp.add_child(session)
	session.set_process(false)
	session.armory = Ep2ArmoryState.post_hideout()
	var trail: LakeTrailChamber = load("res://src/episode2/chamber/lake_trail.tscn").instantiate()
	session.add_child(trail)
	session._active = trail
	session._wire_chamber(trail)
	trail.setup()
	trail.set_physics_process(false)
	trail.debug_invulnerable = true
	var b: Dictionary = trail._bandits[0]
	(b["root"] as Node3D).visible = true
	(b["root"] as Node3D).position = b["home"]
	trail._drop_bandit(0)
	for i in 90:
		trail.step(1.0 / 60.0)                     # he falls; the gun stays where it landed
	var drop: Ep2WeaponDrop = trail._drops_root.get_node("Drop_trail_0")
	var folk: Ep2TownFolk = b["folk"]
	print("DBG body ", folk.global_position, " vis ", folk.is_visible_in_tree(), " drop ", drop.global_position, " gun kids ", (b["gun"] as Node3D).get_children().map(func(n): return n.name), " gun vis ", (b["gun"] as Node3D).is_visible_in_tree(), " gun at ", (b["gun"] as Node3D).global_position, " extras ", Ep2Extras.has(Ep2Extras.BORCHARDT_GUN), " rot ", folk.rotation.y, " facing ", folk.facing)
	var s: float = float(drop.get_meta("s"))
	var lat: float = float(drop.get_meta("lat"))
	for shot in [["from_trail", s - 6.0, 0.0], ["in_reach", s + 1.7, lat], ["after", s + 1.7, lat]]:
		trail._in_departure_area = false
		trail._route_s = float(shot[1])
		trail._lane = float(shot[2])
		trail._speed = 0.0
		trail._sync_route_pose(0.0)
		if str(shot[0]) == "after":
			trail._route_s = s
			trail._lane = lat
			trail._sync_route_pose(0.0)
			trail.step(1.0 / 60.0)                 # rides over it
			trail._route_s = float(shot[1])
			trail._sync_route_pose(0.0)
		var d: Vector3 = drop.global_position - trail._player_pos
		trail._look_yaw = atan2(d.x, d.z)
		trail._update_camera(0)
		var eye: Vector3 = trail.get_camera().global_position
		var to: Vector3 = drop.global_position - eye
		trail._look_pitch = atan2(to.y, Vector2(to.x, to.z).length())
		trail._update_camera(0)
		trail._tick_drops()
		trail._sync_visuals()
		for f in 4:
			await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_jpg("%s/drop_%s.jpg" % [out, str(shot[0])], 0.85)
		print("SHOT ", shot[0], " prompt='", trail._hud._search.text if trail._hud != null else "", "' reserve=", session.armory.firearm(Ep2ArmoryState.BORCH).reserve)
	print("WEAPON_DROP_SHOT_DONE")
	get_tree().quit()
