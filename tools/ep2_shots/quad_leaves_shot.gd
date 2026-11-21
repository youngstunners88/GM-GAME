extends Node
## Motion fix T6 proof: Inferno drags the camouflage net off the quad with his LEFT fist; each clump only moves once the pull reaches it.
## Real WoodsQuad chamber at the REVEAL beat, 1280x720 SubViewport; prints the fist-to-net contact and how many clumps have come away.
##   godot --rendering-method gl_compatibility --path . res://tools/ep2_shots/quad_leaves_shot.tscn -- out=<dir>
var _out := ".farm/quad_leaves"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): _out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(_out)
	var wood: WoodsQuadChamber = load("res://src/episode2/chamber/woods_quad.tscn").instantiate()
	add_child(wood)
	wood.setup()
	wood.debug_invulnerable = true
	await get_tree().process_frame
	wood.set_process(false)
	wood.set_physics_process(false)
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var cam := Camera3D.new()
	cam.fov = 50.0
	vp.add_child(cam)
	var q: Vector3 = WoodsQuadChamber.QUAD_POS
	wood._player_pos = q + Vector3(3.0, 0.0, -5.0)
	wood._bull.position = q + Vector3(3.0, 0.0, -1.2)
	wood._hold = 0.0
	wood._advance_to(WoodsQuadChamber.Beat.REVEAL)
	cam.global_position = q + Vector3(4.6, 2.2, -5.0)
	cam.look_at(q + Vector3(1.4, 0.9, -0.6), Vector3.UP)
	var k: int = 0
	for i in 60 * 14:
		wood.step(1.0 / 60.0)
		if wood.get_beat_name() != "REVEAL":
			break
		if i % 12 == 0 and wood._bull.reach_weight("Left") > 0.02 and k < 22:
			for j in 2:
				await RenderingServer.frame_post_draw
			vp.get_texture().get_image().save_png("%s/leaves_%02d.png" % [_out, k])
			var moved: int = 0
			for d in wood._net_delay:
				if wood._reveal_t - float(d) > 0.0: moved += 1
			print("@@", JSON.stringify({"k": k, "reach_w": snappedf(wood._bull.reach_weight("Left"), 0.01), "reveal_t": snappedf(wood._reveal_t, 0.01),
				"fist_to_net_m": snappedf(wood.net_contact_error(), 0.003), "clumps_away": moved, "clumps": wood._cover_bits.size(),
				"ik_shortfall_m": snappedf((wood._bull._reach["Left"]["ik"] as Ep2ArmIK).shortfall, 0.003),
				"bull_rel": [snappedf(wood._bull.position.x - q.x, 0.01), snappedf(wood._bull.position.z - q.z, 0.01)], "facing": snappedf(wood._bull.facing, 0.01),
				"fist_rel": [snappedf(Ep2BullHero.final_grip_world(wood._bull).x - q.x, 0.01), snappedf(Ep2BullHero.final_grip_world(wood._bull).y, 0.01), snappedf(Ep2BullHero.final_grip_world(wood._bull).z - q.z, 0.01)], "h": wood._bull.height_m}))
			k += 1
	get_tree().quit()
