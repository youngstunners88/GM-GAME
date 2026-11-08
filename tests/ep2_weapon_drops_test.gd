extends Node
## Headless gate for what a dead gunman leaves (founder 2026-11-07, Ep2WeaponDrop): Lil Blunt shoots a trail bandit, the gun that bandit
## held and a box of ITS rounds lie where he fell, stay put, can be taken once (riding over it or the interact control, with a prompt in
## reach), go into the one armory (acquire) and that gun's own reserve (capped like the store), and a gun he already owns still gives its rounds.
## Run: godot --headless res://tests/ep2_weapon_drops_test.tscn

const TRAIL := preload("res://src/episode2/chamber/lake_trail.tscn")

var _failures: int = 0


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_failures += 1
		print("  [FAIL] %s %s" % [label, detail])


func _ready() -> void:
	print("== Ep2 weapon drops ==")
	_test_state()
	_test_trail()
	print("EP2_WEAPON_DROPS: ALL PASS" if _failures == 0 else "EP2_WEAPON_DROPS: %d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _test_state() -> void:
	print("-- ARMORY RECORD")
	var a := Ep2ArmoryState.new()
	var bor: String = Ep2ArmoryState.BORCH
	_check("a gun he has not got is not owned before the drop", not a.owns(bor))
	_check("a drop is recorded once and stays takeable", a.record_drop("t:1", bor, 8) and a.record_drop("t:1", bor, 99) and int(a.corpses["t:1"]["rounds"]) == 8)
	_check("a bow is never a gunman's drop", not a.record_drop("t:bow", Ep2ArmoryState.BOW, 4))
	var copy := Ep2ArmoryState.new()
	copy.restore(JSON.parse_string(JSON.stringify(a.snapshot())))
	_check("an untaken drop survives a save", copy.record_drop("t:1", bor, 0) and str(copy.corpses["t:1"].get("gun", "")) == bor and int(copy.corpses["t:1"]["rounds"]) == 8)
	var got: Dictionary = a.claim_drop("t:1")
	_check("taking it acquires the gun with the dead man's rounds as its reserve", a.owns(bor) and bool(got.get("new", false)) and a.firearm(bor).reserve == 8, str(got))
	_check("it is taken once", a.claim_drop("t:1").is_empty() and not a.record_drop("t:1", bor, 8) and a.firearm(bor).reserve == 8)
	a.record_drop("t:2", bor, 8)
	got = a.claim_drop("t:2")
	_check("a gun he owns still gives its rounds", not bool(got.get("new", true)) and int(got.get("rounds", 0)) == 8 and a.firearm(bor).reserve == 16, str(got))
	a.firearm(bor).reserve = Ep2ArmoryState.RESERVE_CAP - 3
	a.record_drop("t:3", bor, 8)
	got = a.claim_drop("t:3")
	_check("rounds stop at the store's cap and the rest stays on the ground", a.firearm(bor).reserve == Ep2ArmoryState.RESERVE_CAP
		and int(got.get("rounds", 0)) == 3 and int(a.corpses["t:3"]["rounds"]) == 5 and not bool(a.corpses["t:3"]["searched"]), str(got))
	_check("a full reserve takes nothing", a.claim_drop("t:3").is_empty())


func _step(c: LakeTrailChamber, seconds: float) -> void:
	for i in int(seconds * 60.0):
		c.step(1.0 / 60.0)


## Stands him on the trail at arc `s`, `lane` metres off its centre, stopped.
func _stand(c: LakeTrailChamber, s: float, lane: float) -> void:
	c._in_departure_area = false
	c._route_s = s
	c._lane = lane
	c._speed = 0.0
	c._move_input = Vector2.ZERO
	c._sync_route_pose(0.0)


## Raises bandit `i` from his cover, aims the camera at his chest and fires: the room's own shot path kills him.
func _shoot(c: LakeTrailChamber, i: int) -> bool:
	var b: Dictionary = c._bandits[i]
	var root: Node3D = b["root"]
	root.visible = true
	root.position = b["home"]
	b["exposed"] = true
	_stand(c, float(b["s"]) - 8.0, 0.0)
	c._update_camera(0.0)
	var target: Vector3 = c._bandit_world_position(b) + Vector3(0.0, 1.2, 0.0)
	var eye: Vector3 = c.get_camera().global_position
	var d: Vector3 = target - eye
	c._look_yaw = atan2(d.x, d.z)
	c._look_pitch = atan2(d.y, Vector2(d.x, d.z).length())
	c._update_camera(0.0)
	c._on_player_shot()
	return str(b["state"]) == "dead"


func _test_trail() -> void:
	print("-- LAKE TRAIL")
	var c: LakeTrailChamber = TRAIL.instantiate() as LakeTrailChamber
	add_child(c)
	c.set_physics_process(false)
	c.setup(0, [], 0)
	c.debug_invulnerable = true
	var bor: String = Ep2ArmoryState.BORCH
	if c.armory.owns(bor):
		c.armory.owned.erase(bor)
	var before: int = c.armory.firearm(bor).reserve
	var b: Dictionary = c._bandits[0]
	var held: Node3D = b["gun"]
	_check("the bandit is killed by a shot", _shoot(c, 0))
	var drop: Ep2WeaponDrop = c._drops_root.get_node_or_null("Drop_trail_0") as Ep2WeaponDrop if c._drops_root != null else null
	_check("his gun lies where he fell", drop != null)
	if drop == null:
		return
	var body: Vector3 = c._drops_root.to_local(c._bandit_world_position(b))
	_check("it is the gun he held (the same node), not a stand-in", held.get_parent() == drop and held.visible and drop.gun_id == bor)
	_check("a box of rounds lies with it", drop.get_node_or_null("AmmoBox") != null)
	_check("the rounds are that gun's calibre", Ep2ArmoryState.AMMO_TYPES[drop.gun_id] == "seven_six_five" and str(c.armory.corpses["trail:0"]["gun"]) == bor)
	_check("on the ground by the body", Vector2(drop.position.x - body.x, drop.position.z - body.z).length() < 1.6
		and is_equal_approx(drop.position.y, (b["home"] as Vector3).y), "%s vs %s" % [drop.position, body])
	var lying: Vector3 = drop.position
	_step(c, 90.0)
	_check("it stays put and nothing times out (90 s later)", is_instance_valid(drop) and drop.visible and drop.position == lying)
	var where := Vector2(float(drop.get_meta("s")), float(drop.get_meta("lat")))
	_stand(c, where.x, 0.0)
	var bounds: Array = c._lane_bounds()
	_check("the lane opens toward the gun so he can ride over to it", float(bounds[0]) <= where.y and where.y <= float(bounds[1]) and absf(where.y) > Ep2WeaponDrop.REACH, "%s lat %.2f" % [bounds, where.y])
	_stand(c, where.x, where.y - signf(where.y) * 1.6)
	c._tick_drops()
	_check("in reach a prompt names what he can take", c._hud == null or c._hud._search.text.begins_with("Take Borchardt"), c._hud._search.text if c._hud != null else "")
	_check("the drop is still there at the edge of reach", is_instance_valid(drop) and drop.visible)
	_stand(c, where.x, where.y)
	_step(c, 0.1)
	_check("riding over it takes it", not is_instance_valid(drop) or not drop.visible)
	_check("the gun goes into the armory", c.armory.owns(bor))
	_check("its reserve goes up by the dead man's rounds", c.armory.firearm(bor).reserve == LakeTrailChamber.BANDIT_ROUNDS, "%d (before %d)" % [c.armory.firearm(bor).reserve, before])
	_check("it cannot be taken twice", c.armory.claim_drop("trail:0").is_empty() and Ep2WeaponDrop.nearest(c._drops_root, c._player_pos) == null)
	_check("the prompt clears once it is taken", c._hud == null or c._hud._search.text == "")
	# a second bandit: the gun he already owns still gives its rounds, through the interact control
	_check("a second bandit is killed", _shoot(c, 1))
	var second: Ep2WeaponDrop = c._drops_root.get_node_or_null("Drop_trail_1") as Ep2WeaponDrop
	_check("he drops his gun too", second != null)
	if second != null:
		var at := Vector2(float(second.get_meta("s")), float(second.get_meta("lat")))
		_stand(c, at.x, at.y - signf(at.y) * 1.5)
		var reserve: int = c.armory.firearm(bor).reserve
		_check("the interact control takes it in reach", c.start_rig())
		_check("an owned gun still gives its rounds", c.armory.firearm(bor).reserve == reserve + LakeTrailChamber.BANDIT_ROUNDS)
		_check("interact with nothing in reach does nothing", not c.start_rig())
	c.queue_free()
