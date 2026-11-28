extends Node
## Proof captures for the Logan fishing process + huge-fish gag (skill `ep2-logan-fishing-process`).
##   xvfb-run -a .godot-cache/Godot_v4.3-stable_linux.x86_64 --rendering-driver opengl3 --path . res://tools/ep2_shots/logan_fishing_shot.tscn -- out=<dir> [settle]
## Default: the return from the ridge (after day-88) - Logan fishing, then the fish over his head (frames through the arc).
## `settle`: the first visit's rowing -> oars shipped -> rod up -> cast chain, one frame per step.
var c: LogansLakeChamber
var out := "user://logan_fishing"
var settle := false

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="): out = arg.substr(4)
		if arg == "settle": settle = true
	DirAccess.make_dir_recursive_absolute(out)
	c = load("res://src/episode2/chamber/logans_lake.tscn").instantiate()
	c.handoff = {"after_day88": not settle}
	add_child(c)
	c.set_physics_process(false)
	c.bind_armory(Ep2ArmoryState.new())
	c.setup(0, [], 0)
	for i in 10: await get_tree().process_frame
	var b: Ep2LoganSkiff = c._skiff
	if b == null or not b.ready_art:
		push_error("skiff not built"); get_tree().quit(1); return
	if settle: await _settle_shots(b)
	else: await _gag_shots(b)
	get_tree().quit()

func _aim(feet: Vector3, target: Vector3) -> void:
	c._player_pos = feet
	var d: Vector3 = target - feet - Vector3(0, c.eye_height, 0)
	c._look_yaw = atan2(d.x, d.z)
	c._look_pitch = atan2(d.y, Vector2(d.x, d.z).length())

func _gag_shots(b: Ep2LoganSkiff) -> void:
	var feet := Vector3(-4.2, 0, 23.0)
	_aim(feet, Vector3(0, 0, 0))
	for i in 30: c.step(1.0 / 30.0); await get_tree().process_frame
	_aim(feet, b.boat.global_position + Vector3(0, 1.2, 0))
	await _capture("01-return-fishing")
	var shots := {20: "02-fish-out", 28: "03-fish-rising", 36: "04-fish-over-head", 44: "05-fish-down", 52: "06-bellyflop", 70: "07-back-fishing"}
	for f in 75:
		_aim(feet, b.boat.global_position + Vector3(0, 1.2, 0))
		c.step(1.0 / 30.0)
		if shots.has(f): await _capture(shots[f])
		else: await get_tree().process_frame

func _settle_shots(b: Ep2LoganSkiff) -> void:
	c.armory.purchase_river_gear("btc")
	c._player_pos = c.STAGING_MARK + Vector3(-1, 0, 0)
	c._advance_to(c.Beat.STAGE)
	c.start_rig()
	while b.state != b.State.SETTLE:
		c.step(1.0 / 30.0)
	var marks := {0: "s0-last-stroke", 21: "s1-blades-up", 50: "s2-oars-shipped", 80: "s3-hands-on-rod", 115: "s4-rod-up", 140: "s5-casting", 180: "s6-fishing"}
	for f in 181:
		var at: Vector3 = b.boat.global_position
		_aim(Vector3(-5.0, 0, at.z - 1.0), at + Vector3(0, .9, 0))
		c._player_pos = Vector3(-5.0, 0, clampf(at.z - 1.0, -10, 40))
		c.step(1.0 / 30.0)
		if marks.has(f): await _capture(marks[f])

func _capture(label: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(label + ".png"))
	print("FISH_CAPTURE ", label)
