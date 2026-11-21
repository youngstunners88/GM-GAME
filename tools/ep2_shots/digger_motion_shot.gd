extends Node
## Motion fix T3 proof: the back-lot digger's pick swing in the real town, 1280x720 SubViewport, side view, frames across a whole
## loop of each. Prints per frame the tool's working end above the ground and both hands off the handle (metres).
##   godot --rendering-method gl_compatibility --path . res://tools/ep2_shots/digger_motion_shot.tscn -- out=<dir>

const TOWN := preload("res://src/episode2/chamber/gold_town.tscn")
var _out := ".farm/digger_motion"


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
	cam.fov = 38.0
	vp.add_child(cam)
	var miners: Ep2BackLotMiners = null
	for n in c.find_children("*", "Node", true, false):
		if n is Ep2BackLotMiners: miners = n
	var dig = miners.miner("digger")
	var mound: Vector3 = Ep2BackLotMiners.MINERS[0]["mound"]
	var side: Vector3 = (dig.folk.global_position - mound).cross(Vector3.UP).normalized()
	var mid: Vector3 = (dig.folk.global_position + mound) * 0.5 + Vector3.UP * 0.9
	cam.global_position = mid - side * 4.2 + Vector3.UP * 0.4
	cam.look_at(mid, Vector3.UP)
	for spell in ["pick"]:
		await get_tree().process_frame
		var ap: AnimationPlayer = dig.folk.anim_player()
		var len: float = ap.current_animation_length if ap != null else 1.4
		for k in 8:
			for i in int(len / 8.0 * 60.0):
				await get_tree().physics_frame
			for i in 2:
				await RenderingServer.frame_post_draw
			vp.get_texture().get_image().save_png("%s/%s_%d.png" % [_out, spell, k])
			var axis: Vector3 = dig.tool.global_transform.basis.y.normalized()
			var base: Vector3 = dig.tool.global_transform.origin
			var tip: Vector3 = base if spell == "shovel" else dig.tool.global_transform * Vector3(0, 0.95, 0)
			print("@@", JSON.stringify({"spell": spell, "k": k, "clip": dig.folk.current_clip(),
				"work_end_above_ground_m": snappedf(tip.y - Ep2GoldTown.ground_y(tip), 0.01)}))
	get_tree().quit()
