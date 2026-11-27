extends Node
var c: LogansLakeChamber
var out := "/workspace/scratch/logan-task/captures"
var motion := false
var cargo := false
var view_frames: int = 30
func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="): out = arg.substr(4)
		if arg == "motion": motion = true
		if arg == "cargo": cargo = true
		if arg.begins_with("frames="): view_frames = int(arg.substr(7))
	DirAccess.make_dir_recursive_absolute(out)
	c = load("res://src/episode2/chamber/logans_lake.tscn").instantiate()
	add_child(c)
	c.setup()
	c.set_physics_process(false)
	if cargo:
		await cargo_shots()
		return
	if motion:
		await motion_shots()
		get_tree().quit()
		return
	await shot("01-arrival", c.SPAWN, Vector3(5, 1.5, 15))
	await shot("02-logan", Vector3(-5.3, 0, 5.5), c.LOGAN_MARK + Vector3(0, 1.3, 0))
	c.start_rig()
	await shot("03-investigate", Vector3(-5.3, 0, 5.5), c.LOGAN_MARK + Vector3(0, 1.3, 0))
	for i in 1250: c.step(1.0/60.0)
	await shot("04-staging", Vector3(-6.5, 0, 15.5), c.STAGING_MARK + Vector3(0, 0.8, 0))
	c.start_rig()
	await shot("05-handoff", Vector3(-5.8, 0, 15.5), Vector3(24, 0, 51))
	await shot("06-overlook", c.OVERLOOK, Vector3(24, 0, 70))
	get_tree().quit()

## Sample the runtime camera across the whole shot. Run with a tall window to inspect upright framing.
func cargo_shots() -> void:
	c.armory.purchase_river_gear("btc")
	c._player_pos = c.STAGING_MARK + Vector3(-1.0, 0.0, 0.0)
	c._advance_to(c.Beat.STAGE)
	if not c.start_rig():
		push_error("Cargo capture could not start the staging interaction.")
		get_tree().quit(1)
		return
	var frames := {15: "01-moored", 65: "02-released", 182: "03-crossing", 208: "04-current", 317: "05-follow", 437: "06-outflow"}
	for frame in 450:
		c.step(1.0 / 60.0)
		if frames.has(frame):
			await capture(frames[frame])
	get_tree().quit()


## Diagnostic engine views: same skin/materials, unobstructed whole-body gestures.
func motion_shots() -> void:
	c.get_viewmodel().set_shown(false)
	c._hud_layer.hide()
	var ap: AnimationPlayer = c._logan.anim_player()
	ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for clip in ["Idle", "Greet", "Point", "Approve"]:
		ap.stop()
		c._logan.hold_clip(clip)
		ap.advance(0)
		var duration: float = ap.current_animation_length
		for fraction in [0.0, 0.25 if clip in ["Idle", "Approve"] else 0.5, 0.98]:
			ap.seek(duration * fraction, true)
			await shot("motion-%s-%02d" % [clip, int(fraction * 100)],
				c.LOGAN_MARK + Vector3(0, 0, -3.0), c.LOGAN_MARK + Vector3(0, 0.95, 0), 4)
	# Exercise the runtime blend with real advancing poses between unlike clips.
	c._logan.hold_clip("Point")
	ap.advance(0.15)
	await shot("motion-crossfade", c.LOGAN_MARK + Vector3(0, 0, -3.0), c.LOGAN_MARK + Vector3(0, 0.95, 0), 4)

func shot(label: String, feet: Vector3, target: Vector3, frames: int = -1) -> void:
	if frames < 0: frames = view_frames
	c._player_pos = feet
	var d: Vector3 = target - feet - Vector3(0, c.eye_height, 0)
	c._look_yaw = atan2(d.x, d.z)
	c._look_pitch = atan2(d.y, Vector2(d.x, d.z).length())
	for i in frames:
		c.step(1.0/60.0)
		if motion:
			c.get_viewmodel().set_shown(false)
			c._hud_layer.hide()
		await get_tree().process_frame
	await capture(label)


func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(label + ".png"))
	print("LAKE_CAPTURE ", label)
