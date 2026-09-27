extends Node
## Gate for the Episode 2 MOTION + EMOTION layer (runner_motion.gd) and its asset
## contract with the Meshy rigs. Pure picks are unit-tested; the rig check proves
## every clip the tables name exists in the shipped GLB (a re-rig that drops a
## clip would otherwise just freeze that emotion silently). The last block runs a
## real leg with the view live so any runtime SCRIPT ERROR shows in the log.
##
## Run: .godot-cache/Godot_v4.3-stable_linux.x86_64 --headless res://tests/ep2_runner_motion_test.tscn

const SCENE := preload("res://src/episode2/runner/runner_graybox.tscn")
var _fail: int = 0

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _ready() -> void:
	print("EP2_RUNNER_MOTION:")
	var M := RunnerMotion
	# Rider priorities.
	_check("zipline beats everything", M.pick_rider(true, true, true, true, 0, 0, 0, 0, 0) == "zip")
	_check("a hit reaction beats duck/jump", M.pick_rider(false, true, true, false, 0.1, 99, 99, 99, 99) == "hit")
	_check("swipe beats duck", M.pick_rider(false, true, false, false, 99, 99, 0.1, 99, 99) == "swipe")
	_check("duck while held", M.pick_rider(false, true, false, false, 99, 99, 99, 99, 99) == "duck")
	_check("airborne = jump", M.pick_rider(false, false, true, false, 99, 99, 99, 99, 99) == "jump")
	_check("fresh hop = hop", M.pick_rider(false, false, false, false, 99, 99, 99, 0.1, 99) == "hop")
	_check("shot then reload then cheer", M.pick_rider(false, false, false, true, 99, 0.1, 99, 99, 0.1) == "shoot"
		and M.pick_rider(false, false, false, true, 99, 99, 99, 99, 0.1) == "reload"
		and M.pick_rider(false, false, false, false, 99, 99, 99, 99, 0.1) == "cheer")
	_check("calm = idle", M.pick_rider(false, false, false, false, 99, 99, 99, 99, 99) == "idle")
	# Archer.
	_check("dead archer dies", M.pick_archer(false, 0.1, 10.0) == "die")
	_check("archer looses just before its arrow flies", M.pick_archer(true, 0.2, 30.0) == "loose")
	_check("archer aims in range", M.pick_archer(true, 3.0, 50.0) == "aim")
	_check("archer idles far away", M.pick_archer(true, 9.0, 200.0) == "idle")

	# Rig contract: every named clip exists in the shipped GLB.
	for pair in [[M.RIDER_RIG, M.RIDER_CLIPS], [M.BEAR_RIG, M.BEAR_CLIPS]]:
		var path: String = pair[0]
		var table: Dictionary = pair[1]
		_check("%s exists" % path.get_file(), ResourceLoader.exists(path))
		if not ResourceLoader.exists(path):
			continue
		var n: Node = (load(path) as PackedScene).instantiate()
		var an: RefCounted = M.Anim.new(n, table)
		_check("%s has an AnimationPlayer" % path.get_file(), an.ok())
		if an.ok():
			for mood in table:
				var clip: String = str(table[mood][0])
				_check("%s: mood '%s' -> clip %s present" % [path.get_file(), mood, clip], an.player.has_animation(clip))
			for lc in M.LOOPING:
				if an.player.has_animation(lc):
					_check("%s: %s loops" % [path.get_file(), lc], an.player.get_animation(lc).loop_mode == Animation.LOOP_LINEAR)
		n.free()

	# danger_eta on a real sim.
	var r: Node3D = SCENE.instantiate()
	add_child(r)
	r.set_physics_process(false)
	r.setup(300.0, [{"z": 40.0, "lane": 1, "type": "boulder"}])
	_check("danger ETA to own boulder = 2 s at 20 m/s (%.2f)" % M.danger_eta(r, 1, 0.0, 20.0),
		absf(M.danger_eta(r, 1, 0.0, 20.0) - 2.0) < 0.01)
	_check("no danger on a clear rail", M.danger_eta(r, 0, 0.0, 20.0) == INF)
	r.queue_free()

	# Live leg with the view: 4 s of real frames, rider rig driven.
	var live: Node3D = SCENE.instantiate()
	add_child(live)
	var leg: Dictionary = Episode2Tracks.LEG_DESCENT
	live.setup(float(leg["chamber_z"]), leg["obstacles"], leg["zip_segments"], leg["archers"], true,
		{"rail_events": leg["rail_events"], "carts_start": leg["carts_start"], "speed": leg["speed"]})
	for _i in 240:
		await get_tree().process_frame
	var view: Node = live.get_node("View")
	_check("rider rig is driven by RunnerMotion", view._rider_anim != null and view._rider_anim.ok())
	_check("the leg advanced with the view live (d=%.0f)" % live.get_distance(), live.get_distance() > 20.0)
	# Regression: the bear rig's Armature carries a 0.01 scale, and measuring it
	# through the node chain drew it 130x too big (off-screen) on the web build.
	var rs: float = view._rider_model.scale.y
	_check("rider rig scale sane (%.2f)" % rs, rs > 0.5 and rs < 5.0)
	for id in view._archer_nodes:
		var bear: Node3D = view._archer_nodes[id]
		for c in bear.get_children():
			if c is Node3D and String(c.name).contains("rigged"):
				var bs: float = (c as Node3D).scale.y
				_check("archer %s rig scale sane (%.2f)" % [id, bs], bs > 0.5 and bs < 5.0)
	live.queue_free()
	print("EP2_RUNNER_MOTION: " + ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(1 if _fail else 0)
