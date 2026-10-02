extends Node
## Frame grabs of Inferno Bull's real performance (skill see-it-yourself + ep2-bull-handoff-walk): plays the actual
## beat sheet by stepping it (no wall clock) and saves the viewport at the moments that matter - seated with the
## whiskey, standing, walking to the wall, reaching for the rifle, carrying it, the hand-over, the helmet, first person.
##   xvfb-run -a -s "-screen 0 960x540x24" godot --rendering-driver opengl3 --rendering-method gl_compatibility \
##       --resolution 960x540 res://tools/ep2_shots/show_shot.tscn -- out=<dir> [only=name1,name2]

const SMELT := preload("res://src/episode2/chamber/smelting_facility.tscn")
var _out := ".farm/show"
var _only: PackedStringArray = PackedStringArray()
var f: Node = null


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.split("=", true, 1)
		if kv.size() == 2 and kv[0] == "out":
			_out = kv[1]
		if kv.size() == 2 and kv[0] == "only":
			_only = kv[1].split(",")
	DirAccess.make_dir_recursive_absolute(_out)
	f = SMELT.instantiate()
	f.intro_film = false
	add_child(f)
	f.setup(0, [], 0)
	f.set_physics_process(false)
	await get_tree().process_frame
	for i in 70:
		f.step(1.0 / 60.0)
	# walk to the Bull
	f._look_yaw = atan2(f.BULL_POSITION.x, f.BULL_POSITION.z)
	f.set_move_input(Vector2(0.0, 1.0))
	_run_until(func(): return f.get_beat() != f.Beat.APPROACH, 12.0)
	f.set_move_input(Vector2.ZERO)
	f._look_yaw = atan2(f.BULL_POSITION.x - f._player_pos.x, f.BULL_POSITION.z - f._player_pos.z)
	await _run_until_cap(func(): return f.get_beat() == f.Beat.DRINK and f._anim_t > 0.0 and f.get_line_hold() > 0.0 and f._hold > 0.0, 3.0, "")
	_run(2.5)
	await _cap("1_seated")
	await _until_cap(func(): return f.get_beat() == f.Beat.SIZING and f._stand_t >= 0.0 and f._stand_t < 90.0 and f._stand_t > 1.2, 60.0, "2_standing_up")
	await _until_cap(func(): return f.get_beat() == f.Beat.SIZING and not f.is_bull_seated() and f._stand_t >= 99.0, 20.0, "3_standing")
	await _until_cap(func(): return f.get_beat() == f.Beat.HANDOFF and f.get_bull().is_walking() and f.get_bull().position.distance_to(f.WALL_STAND) > 2.0, 30.0, "4_walk_to_wall", 0.5)
	await _until_cap(func(): return f.get_bull().reach_weight("Right") > 0.97 and f.get_beat() == f.Beat.HANDOFF, 30.0, "5_reach_rifle", 0.6)
	await _until_cap(func(): return f._rifle_node.get_parent().name == "Holder" and f.get_bull().is_walking() and f.get_beat() == f.Beat.HANDOFF, 30.0, "6_carry_rifle", 0.9)
	await _until_cap(func(): return f.get_bull().reach_weight("Right") > 0.97 and f.get_beat() == f.Beat.HANDOFF and f._rifle_node.get_parent().name == "Holder" and not f.get_bull().is_walking(), 30.0, "7_offer_rifle", 0.5)
	await _until_cap(func(): return f.has_winchester(), 30.0, "8_rifle_delivered", 0.4)
	await _until_cap(func(): return f.get_beat() == f.Beat.HELMET and f.get_bull().reach_weight("Right") > 0.97 and f._helmet_node.get_parent() == f._visuals, 40.0, "9_reach_helmet", 0.6)
	await _until_cap(func(): return f.get_beat() == f.Beat.HELMET and f.get_bull().reach_weight("Right") > 0.97 and f._helmet_node.get_parent().name == "Holder" and not f.get_bull().is_walking(), 40.0, "10_offer_helmet", 0.6)
	await _until_cap(func(): return f.has_helmet(), 30.0, "11_helmet_on", 0.9)
	await _until_cap(func(): return f.get_beat() == f.Beat.VERB_TEACH, 30.0, "12_fps", 1.2)
	f._look_yaw = atan2(f.MOLD_RACK_POSITION.x - f._player_pos.x, f.MOLD_RACK_POSITION.z - f._player_pos.z)
	await _until_cap(func(): return f.get_beat() == f.Beat.TERMS, 4.0, "13_fps_terms", 0.2, func(): f.aim_at(f.get_mold_position(0)); f.shoot(); f.aim_at(f.get_mold_position(1)); f.shoot(); f.aim_at(f.get_mold_position(2)); f.shoot())
	_run(6.0)
	await _cap("14_terms_companion")
	get_tree().quit()


func _run(sec: float) -> void:
	for i in int(sec * 60.0):
		f.step(1.0 / 60.0)


func _run_until(pred: Callable, limit: float) -> bool:
	for i in int(limit * 60.0):
		if pred.call():
			return true
		f.step(1.0 / 60.0)
	return pred.call()


func _run_until_cap(pred: Callable, limit: float, _n: String) -> void:
	_run_until(pred, limit)


func _until_cap(pred: Callable, limit: float, name: String, extra: float = 0.0, pre: Callable = Callable()) -> void:
	if pre.is_valid():
		pre.call()
	var ok: bool = _run_until(pred, limit)
	_run(extra)
	if not ok:
		print("SHOT-TIMEOUT ", name)
	await _cap(name)


func _cap(name: String) -> void:
	if _only.size() > 0 and not (name in _only):
		return
	for i in 4:
		await get_tree().process_frame
	var path := "%s/%s.png" % [_out, name]
	get_viewport().get_texture().get_image().save_png(path)
	print("SHOT ", path, " beat=", f.get_beat_name(), " bull=", f.get_bull().position, " clip=", f.get_bull().current_clip())
