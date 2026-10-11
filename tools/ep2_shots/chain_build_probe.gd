extends Node
## How long does each chained chamber take to build, and does the background build keep every frame short?
##   xvfb-run -a godot --rendering-driver opengl3 --rendering-method gl_compatibility --path . res://tools/ep2_shots/chain_build_probe.tscn
## Prints the synchronous build (what the player used to sit through as a freeze/blackout), then the background build: the longest
## single frame it adds, how many frames it takes, and the first frames after the hand-over.
func _ready() -> void:
	for p in ["res://src/episode2/chamber/mine_lift.tscn", "res://src/episode2/chamber/woods_quad.tscn"]:
		var c: Ep2Interlude = (load(p) as PackedScene).instantiate()
		add_child(c)
		var t0 := Time.get_ticks_msec()
		c.setup(0, [], 0)
		print("CHAINPROBE ", p.get_file(), " SYNC setup ms=", Time.get_ticks_msec() - t0)
		c.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	for p in ["res://src/episode2/chamber/mine_lift.tscn", "res://src/episode2/chamber/woods_quad.tscn"]:
		var vp := SubViewport.new()
		vp.size = Vector2i(320, 180)
		vp.own_world_3d = true
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(vp)
		var c: Ep2Interlude = (load(p) as PackedScene).instantiate()
		vp.add_child(c)
		c.prebuild_begin()
		var frames := 0
		var worst := 0
		while not c.prebuild_step(7.0):
			var t1 := Time.get_ticks_msec()
			await get_tree().process_frame
			var dt := Time.get_ticks_msec() - t1
			worst = maxi(worst, dt)
			print("CHAINPROBE   bg frame ", frames, " ", dt, " ms (step idx ", c._pb_i, " warm ", c._pb_warm_i, ")")
			frames += 1
		print("CHAINPROBE ", p.get_file(), " BACKGROUND frames=", frames, " worst_frame_ms=", worst)
		await get_tree().process_frame
		var t2 := Time.get_ticks_msec()
		c.activate(self, {"yaw": 0.3, "pitch": 0.0})
		vp.queue_free()
		print("CHAINPROBE ", p.get_file(), " activate ms=", Time.get_ticks_msec() - t2)
		for i in 6:
			var t3 := Time.get_ticks_msec()
			await get_tree().process_frame
			print("CHAINPROBE   frame after hand-over ", i, " ms=", Time.get_ticks_msec() - t3)
		c.queue_free()
		await get_tree().process_frame
	get_tree().quit()
