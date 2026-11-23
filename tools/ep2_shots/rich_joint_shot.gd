extends Node
## Rich's lit joint (founder 2026-11-22: "why isn't his joint lit with smoke twirling"), close on his face at the Armory counter in the REAL
## town, three frames a second apart (the ember breathes, the curl rises and fades) (a fourth frame from the counter is written too).
##   godot --rendering-method gl_compatibility --path . res://tools/ep2_shots/rich_joint_shot.tscn -- out=<dir>

const TOWN := preload("res://src/episode2/chamber/gold_town.tscn")
var _out := ".farm/rich_joint"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): _out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(_out)
	var c: GoldTownChamber = TOWN.instantiate()
	add_child(c)
	c.setup(0, [], 0)
	await get_tree().process_frame
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var cam := Camera3D.new()
	cam.fov = 30.0
	vp.add_child(cam)
	c._player_pos = Ep2GoldTown.local_to_world("Bldg_Armory", GoldTownChamber.ARMORY_SPOT)
	for i in 120:
		c.step(1.0 / 60.0)
		await get_tree().process_frame
	var rich: Ep2TownFolk = c.get_rich()
	var joint: Ep2RichJoint = c._rich_joint
	if rich == null or joint == null:
		print("RICHJOINT none (rich %s joint %s)" % [rich, joint])
		get_tree().quit(1)
		return
	var sk: Skeleton3D = rich.model.find_children("*", "Skeleton3D", true, false)[0]
	var hb: int = -1
	for b in sk.get_bone_count():
		if sk.get_bone_name(b).ends_with("Head"):
			hb = b
	for k in 4:
		for i in 60:
			c.step(1.0 / 60.0)
			await get_tree().process_frame
		var head: Vector3 = sk.global_transform * sk.get_bone_global_pose(hb).origin
		var tip: Vector3 = joint.global_position
		var out_dir: Vector3 = (tip - head)
		out_dir.y = 0.0
		out_dir = out_dir.normalized()
		var side: Vector3 = out_dir.cross(Vector3.UP).normalized()
		var eye: Vector3 = tip + out_dir * 0.35 + side * 0.55 + Vector3.UP * 0.12 if k < 3 else c._player_pos + Vector3.UP * 1.1
		cam.global_position = eye
		cam.look_at((head + tip) * 0.5 + Vector3.UP * 0.05, Vector3.UP)
		if k == 3:
			cam.fov = 45.0
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var name: String = "joint_%d" % k if k < 3 else "joint_from_counter"
		vp.get_texture().get_image().save_png(_out + "/" + name + ".png")
		print("RICHJOINT %s tip %s head %s smoke %s clip %s" % [name, tip, head, joint.smoke.emitting, rich.current_clip()])
	get_tree().quit()
