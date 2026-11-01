extends Node
## Guns Buff (founder 2026-11-01 evening): real-renderer captures of his Meshy guns in Lil Blunt's hands, at the hip and aimed, and
## of every one of the eight in the Armory's spinning showcase.
## OUT=<dir> godot --path . --rendering-driver opengl3 tools/ep2_shots/guns_buff_shot.tscn [-- only=<gun id>]

var out: String = ""


func _shot(name: String) -> void:
	for i in 5:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/" + name + ".png")
	print("GUNS_SHOT ", name)


func _ready() -> void:
	out = OS.get_environment("OUT")
	if out == "":
		out = "user://guns_buff"
	DirAccess.make_dir_recursive_absolute(out)
	var only: String = ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only="):
			only = a.substr(5)
	get_window().size = Vector2i(1280, 720)
	var session: Ep2SessionRoot = load("res://src/episode2/session/ep2_session_root.tscn").instantiate()
	add_child(session)
	session.set_process(false)
	session.armory = Ep2ArmoryState.post_hideout()
	var trail: LakeTrailChamber = load("res://src/episode2/chamber/lake_trail.tscn").instantiate()
	session.add_child(trail)
	session._active = trail
	session._wire_chamber(trail)
	trail.setup()
	trail.set_physics_process(false)
	trail.debug_invulnerable = true
	trail._place_at_distance(40.0)
	var ids: Array = [Ep2ArmoryState.SHOT, Ep2ArmoryState.MP18, Ep2ArmoryState.TOMMY, Ep2ArmoryState.BORCH, Ep2ArmoryState.BUFF]
	for id in ids:
		if only != "" and id != only:
			continue
		if id == Ep2ArmoryState.BUFF:
			trail.armory.purchase_sniper("btc")
		else:
			trail.armory.purchase_firearm(id, "btc")
		trail.armory.select(id)
		for aimed in [false, true]:
			trail._look_yaw = trail._travel_yaw
			trail._look_pitch = 0.0
			for i in 50:
				trail.set_aim(aimed)
				trail.step(1.0 / 60.0)
			trail._update_camera(0)
			await _shot(("ads-" if aimed else "hip-") + id)
		trail.set_aim(false)
	if only != "":
		get_tree().quit()
		return
	for key in [Ep2ArmoryState.REM, Ep2ArmoryState.BOW, Ep2ArmoryState.WIN, Ep2ArmoryState.BORCH, Ep2ArmoryState.SHOT, "sniper", Ep2ArmoryState.MP18, Ep2ArmoryState.TOMMY]:
		var vp := SubViewport.new()
		vp.size = Vector2i(1280, 720)
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(vp)
		var shop := Ep2ArmoryShop.new()
		vp.add_child(shop)
		shop.open_shop(trail.armory, 9)
		for i in Ep2ArmoryState.SHOP.size():
			if str(Ep2ArmoryState.SHOP[i]["id"]) == key:
				shop.index = i
		for i in 60:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png(out + "/case-%s.png" % key)
		print("GUNS_SHOT case ", key)
		vp.queue_free()
	print("GUNS_SHOTS_DONE")
	get_tree().quit()
