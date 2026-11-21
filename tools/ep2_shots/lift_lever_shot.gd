extends Node
## Motion fix T6 proof: Inferno pulls the cage lever with his LEFT fist (the right is sculpted into his pouch). Real MineLift chamber, stepped by
## this script, 1280x720 SubViewport side view; prints per frame the fist-to-grip error and the lever's travel (it may only move on contact).
##   godot --rendering-method gl_compatibility --path . res://tools/ep2_shots/lift_lever_shot.tscn -- out=<dir>
var _out := ".farm/lift_lever"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): _out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(_out)
	var lift: MineLiftChamber = load("res://src/episode2/chamber/mine_lift.tscn").instantiate()
	add_child(lift)
	lift.setup()
	await get_tree().process_frame
	lift.set_process(false)
	lift.set_physics_process(false)
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var cam := Camera3D.new()
	cam.fov = 45.0
	vp.add_child(cam)
	lift._player_pos = Vector3(0.0, 0.0, -1.0)
	var k: int = 0
	for i in 60 * 40:
		lift.step(1.0 / 60.0)
		if lift.get_beat_name() == "LEVER" or (lift._lever_t >= 0.0 and lift._lever_t < 1.0):
			if i % 6 == 0 and k < 40:
				var lp: Vector3 = lift.get_lever_position()
				cam.global_position = lp + Vector3(-1.3, 0.35, -1.6)
				cam.look_at(lp + Vector3(0.45, 0.25, 0.1), Vector3.UP)
				for j in 2:
					await RenderingServer.frame_post_draw
				vp.get_texture().get_image().save_png("%s/lever_%02d.png" % [_out, k])
				print("@@", JSON.stringify({"k": k, "beat": lift.get_beat_name(), "lever_t": snappedf(lift._lever_t, 0.01),
					"left_reach_w": snappedf(lift._bull.reach_weight("Left"), 0.01), "fist_to_grip_m": snappedf(lift.lever_contact_error(), 0.003),
					"ik_shortfall_m": snappedf((lift._bull._reach["Left"]["ik"] as Ep2ArmIK).shortfall, 0.003),
					"bull": [snappedf(lift._bull.global_position.x, 0.01), snappedf(lift._bull.global_position.z, 0.01)], "facing": snappedf(lift._bull.facing, 0.01),
					"grip": [snappedf(lift.lever_grip_position().x, 0.01), snappedf(lift.lever_grip_position().y, 0.01), snappedf(lift.lever_grip_position().z, 0.01)],
					"fist": [snappedf(Ep2BullHero.final_grip_world(lift._bull).x, 0.01), snappedf(Ep2BullHero.final_grip_world(lift._bull).y, 0.01), snappedf(Ep2BullHero.final_grip_world(lift._bull).z, 0.01)]}))
				k += 1
		if lift.get_beat_name() == "RISE" and lift._lever_t >= 1.0 and k > 0:
			break
	get_tree().quit()
