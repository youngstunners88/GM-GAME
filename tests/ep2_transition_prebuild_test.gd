extends Node
## Gate for the film -> target-practice transition (founder 2026-10-04: "a long period of blank screen that
## delays for no reason. Fix it, I want smooth transitions"). The hideout must be BUILT WHILE THE FILM PLAYS
## (hidden behind the full-screen film), so the cut is instant - never built on black after the film ends.
## Run: godot --headless res://tests/ep2_transition_prebuild_test.tscn

const SMELT := preload("res://src/episode2/chamber/smelting_facility.tscn")
var _fail: int = 0

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok: print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])


func _ready() -> void:
	print("EP2 TRANSITION PREBUILD:")
	var c: SmeltingFacilityChamber = SMELT.instantiate()
	c.intro_film = true
	add_child(c)
	c.setup(0, [], 0)
	c.set_physics_process(false)
	await get_tree().process_frame
	if c.get_video_film() == null:
		# No video in this build -> the in-engine film path; nothing to gate here.
		_check("the founder's film is in the build (else skip)", false, "video missing")
		print("EP2_TRANSITION_PREBUILD: %s" % ("ALL PASS" if _fail == 0 else "FAIL (%d)" % _fail))
		c.queue_free()
		get_tree().quit(_fail)
		return
	# a JUMP key still held from the runner must NOT skip the film (founder: "the video isn't playing")
	Input.action_press("jump")
	for i in 150:                                  # 2.5 s of held jump
		c.step(1.0 / 60.0)
	_check("a JUMP held from the runner does not skip the film", c.get_beat_name() == "CINEMATIC" and c.get_video_film() != null and not c.get_video_film().is_done())
	Input.action_release("jump")
	var vf0 = c.get_video_film()
	for i in 90:
		c.step(1.0 / 60.0)
	Input.action_press("jump")
	for i in 70:                                   # a deliberate NEW hold (> 0.9 s) after releasing does skip
		c.step(1.0 / 60.0)
	Input.action_release("jump")
	_check("...but releasing and holding JUMP again (the hint) still skips it", vf0.is_done() or vf0.is_finishing() or c.get_beat_name() != "CINEMATIC")
	c.queue_free()
	c = SMELT.instantiate()
	c.intro_film = true
	add_child(c)
	c.setup(0, [], 0)
	c.set_physics_process(false)
	await get_tree().process_frame
	_check("while the film plays, the room is NOT built yet (first second)", not c._room_built)
	# drive the film a few seconds (its own clock) - the room must build behind it
	var worst_ms: float = 0.0
	var t_prev: int = Time.get_ticks_msec()
	for i in int(c.PREBUILD_AT * 60.0) + 40:
		c.step(1.0 / 60.0)
		if i % 4 == 0:                  # let real frames pass so the SLICED build can run, and time each one
			await get_tree().process_frame
			var now: int = Time.get_ticks_msec()
			worst_ms = maxf(worst_ms, float(now - t_prev))
			t_prev = now
	var guard: int = 0
	while not c._room_ready and guard < 600:
		guard += 1
		var t0: int = Time.get_ticks_msec()
		await get_tree().process_frame
		worst_ms = maxf(worst_ms, float(Time.get_ticks_msec() - t0))
	_check("the hideout is built DURING the film, before it ends (no blank-screen build at the cut)", c._room_built and c._room_ready)
	print("PREBUILD worst frame while building behind the film: %.0f ms" % worst_ms)
	_check("...and no single frame while building stalled the film for more than 450 ms (was ~900 ms in one block)", worst_ms < 450.0, "%.0f ms" % worst_ms)
	_check("...and the film is still playing over it (still CINEMATIC)", c.get_beat_name() == "CINEMATIC")
	_check("while the film covers the screen the 3D pass is OFF (it starved the decoder on weak GPUs)", c.get_viewport().disable_3d)
	_check("the five-target range exists behind the film", c._mold_nodes.size() == 5)
	# finish the film: the cut must be immediate (room already there), landing in the lesson
	var vf = c.get_video_film()
	vf.skip()
	for i in 8:
		c.step(1.0 / 60.0)
		await get_tree().process_frame
	_check("...and the 3D pass is back on once the film is over", not c.get_viewport().disable_3d)
	_check("the film ends straight into the range lesson (VERB_TEACH / LEAD)",
		c.get_beat_name() == "VERB_TEACH", c.get_beat_name())
	c.queue_free()
	print("EP2_TRANSITION_PREBUILD: %s" % ("ALL PASS" if _fail == 0 else "FAIL (%d)" % _fail))
	get_tree().quit(_fail)
