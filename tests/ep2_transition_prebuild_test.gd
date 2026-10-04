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
	_check("while the film plays, the room is NOT built yet (first second)", not c._room_built)
	# drive the film a few seconds (its own clock) - the room must build behind it
	for i in int(c.PREBUILD_AT * 60.0) + 40:
		c.step(1.0 / 60.0)
	_check("the hideout is built DURING the film, before it ends (no blank-screen build at the cut)", c._room_built)
	_check("...and the film is still playing over it (still CINEMATIC)", c.get_beat_name() == "CINEMATIC")
	_check("the five-target range exists behind the film", c._mold_nodes.size() == 5)
	# finish the film: the cut must be immediate (room already there), landing in the lesson
	var vf = c.get_video_film()
	vf.skip()
	for i in 8:
		c.step(1.0 / 60.0)
		await get_tree().process_frame
	_check("the film ends straight into the range lesson (VERB_TEACH / LEAD)",
		c.get_beat_name() == "VERB_TEACH", c.get_beat_name())
	c.queue_free()
	print("EP2_TRANSITION_PREBUILD: %s" % ("ALL PASS" if _fail == 0 else "FAIL (%d)" % _fail))
	get_tree().quit(_fail)
