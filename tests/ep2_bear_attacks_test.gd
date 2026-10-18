extends Node
## Founder 2026-10-18: bears must move properly and, when they attack, be seen striking and biting the way a bear would.
## Guards the authored clips (tools/ep2_blender/build_bear_combat_clips.py) and the brain's attack choice + contact timing.
var failures: int = 0


func check(label: String, ok: bool, detail: String = "") -> void:
	print("  [PASS] " if ok else "  [FAIL] ", label, "" if ok or detail.is_empty() else "  (" + detail + ")")
	if not ok:
		failures += 1


func _brawler(world: Node3D, pos: Vector3, seed_value: int) -> Ep2BearBrain:
	var bear := Ep2BearKit.make_bear(world, pos)
	var brain := Ep2BearBrain.new(bear, {"hp": 2, "routine": "watch", "role": "brawler"}, seed_value)
	brain.aware = Ep2BearBrain.Aware.ALERT
	brain.target = Vector3.ZERO
	return brain


func _ready() -> void:
	var world := Node3D.new()
	add_child(world)
	var b := Ep2BearKit.make_bear(world, Vector3.ZERO)
	var have: bool = b.anim != null
	check("the bear has a player and the combat clips merged onto its skeleton",
		have and b.anim.has_animation(Ep2BearKit.SWIPE) and b.anim.has_animation(Ep2BearKit.BITE)
		and b.anim.has_animation(Ep2BearKit.BEAR_WALK) and b.anim.has_animation(Ep2BearKit.BEAR_RUN))
	if not have or not b.anim.has_animation(Ep2BearKit.SWIPE):
		print("EP2_BEAR_ATTACKS: FAILED %d" % failures)
		get_tree().quit(1)
		return
	var sw: Animation = b.anim.get_animation(Ep2BearKit.SWIPE)
	var bi: Animation = b.anim.get_animation(Ep2BearKit.BITE)
	check("swipe and bite are 1.2 s one-shots (30 fps authoring)", is_equal_approx(sw.length, 1.2) and is_equal_approx(bi.length, 1.2)
		and sw.loop_mode == Animation.LOOP_NONE and bi.loop_mode == Animation.LOOP_NONE)
	check("the gait clips loop and the bear uses them for walk and run",
		b.walk_clip == Ep2BearKit.BEAR_WALK and b.run_clip == Ep2BearKit.BEAR_RUN
		and b.anim.get_animation(Ep2BearKit.BEAR_WALK).loop_mode == Animation.LOOP_LINEAR
		and b.anim.get_animation(Ep2BearKit.BEAR_RUN).loop_mode == Animation.LOOP_LINEAR)
	check("the claw blow lands inside its clip, after the wind-up (not the first 0.3 s, before the end)",
		Ep2BearKit.SWIPE_IMPACT > 0.3 and Ep2BearKit.SWIPE_IMPACT < 0.8 and Ep2BearKit.BITE_IMPACT > 0.3 and Ep2BearKit.BITE_IMPACT < 0.8)

	# The clips must actually move the bones (a mis-bound clip leaves the rest T-pose, which is what the first export did).
	Ep2BearKit.pose(b, "swipe")
	b.step(1.0 / 60.0)
	var arm_bone: int = b.skeleton.find_bone("RightArm")
	var q0: Quaternion = b.skeleton.get_bone_pose_rotation(arm_bone)
	for i in 36:
		b.step(1.0 / 60.0)
		Ep2BearKit.tick_pose(b, 1.0 / 60.0)
	var q1: Quaternion = b.skeleton.get_bone_pose_rotation(arm_bone)
	var rest: Quaternion = b.skeleton.get_bone_rest(arm_bone).basis.get_rotation_quaternion()
	check("the swipe drives the striking arm away from the rest pose", q1.angle_to(rest) > 0.8 and q1.angle_to(q0) > 0.3)
	Ep2BearKit.pose(b, "bite")
	b.step(1.0 / 60.0)
	var head_bone: int = b.skeleton.find_bone("Head")
	var yaws: Array = []
	for i in 60:
		b.step(1.0 / 60.0)
		Ep2BearKit.tick_pose(b, 1.0 / 60.0)
		if i >= 28:
			yaws.append(b.skeleton.get_bone_pose_rotation(head_bone).get_euler().y)
	var swing: float = 0.0
	for y in yaws:
		swing = maxf(swing, absf(float(y) - float(yaws[0])))
	check("the bite worries its prey: the head shakes side to side after the lunge", swing > 0.12)

	# The brain picks the attack from the distance and the blow connects at the clip's contact time.
	var close := _brawler(world, Vector3(0, 0, 0), 11)
	close._pick_attack(1.4)
	var far := _brawler(world, Vector3(10, 0, 0), 12)
	far._pick_attack(2.2)
	check("right on top of the player a bear bites (at arm's length it rears and swipes)",
		(close._attack_kind in ["bite", "swipe"]) and far._attack_kind == "swipe" and far._strike_at == Ep2BearKit.SWIPE_IMPACT)
	var landed: Array = []
	var brain := _brawler(world, Vector3(0, 0, 20), 13)
	brain.swiped.connect(func(_bb: Ep2BearBrain) -> void: landed.append(brain._attack_t))
	var player := Vector3(0, 0, 21.8)                      # 1.8 m away: inside the bite range
	for i in 240:
		brain.step(1.0 / 60.0, player)
		brain.actor.step(1.0 / 60.0)
		Ep2BearKit.tick_pose(brain.actor, 1.0 / 60.0)
		if not landed.is_empty():
			break
	check("a brawler beside the player attacks and lands one blow", landed.size() == 1,
		"kind %s pose %s" % [brain._attack_kind, Ep2BearKit.pose_name(brain.actor)])
	check("...with a real attack pose, struck at the clip's contact time (not the old fixed 0.55 s punch)",
		Ep2BearKit.pose_name(brain.actor) in ["bite", "swipe"] and not landed.is_empty() and absf(float(landed[0]) - brain._strike_at) < 0.1)
	var out_of_reach := _brawler(world, Vector3(30, 0, 0), 14)
	var struck: Array = []
	out_of_reach.swiped.connect(func(_bb: Ep2BearBrain) -> void: struck.append(1))
	out_of_reach._attack_t = 0.0
	out_of_reach._pick_attack(2.0)
	for i in 120:
		out_of_reach.step(1.0 / 60.0, Vector3(30, 0, 8.0))   # he stepped away to 8 m before the blow: it misses
	check("a blow only lands if the player is still in reach when it connects", struck.is_empty())
	world.queue_free()
	print("EP2_BEAR_ATTACKS: ALL PASS" if failures == 0 else "EP2_BEAR_ATTACKS: FAILED %d" % failures)
	get_tree().quit(0 if failures == 0 else 1)
