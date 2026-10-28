extends Node
## Blood gate: restrained one-shot spurts, rig-following stains, flat growing pools, and the
## real draw / woods hit hooks. Run: godot --headless res://tests/ep2_blood_test.tscn

const BLOOD_FX = preload("res://src/episode2/fx/ep2_blood_fx.gd")
const TOWN := preload("res://src/episode2/chamber/gold_town.tscn")
const WOODS := preload("res://src/episode2/chamber/woods_quad.tscn")

var _fail: int = 0


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])


func _run(c: Ep2Interlude, seconds: float) -> void:
	for i in int(seconds * 60.0):
		c.step(1.0 / 60.0)


func _until(c: GoldTownChamber, seconds: float, cond: Callable) -> bool:
	for i in int(seconds * 60.0):
		if cond.call():
			return true
		c.step(1.0 / 60.0)
	return bool(cond.call())


func _compatible_fx(n: Node) -> bool:
	if n is Decal:
		return false
	if n is GeometryInstance3D:
		var g: GeometryInstance3D = n as GeometryInstance3D
		if g.material_override != null and not (g.material_override is StandardMaterial3D):
			return false
	for child in n.get_children():
		if not _compatible_fx(child):
			return false
	return true


func _aim_at_opp(c: GoldTownChamber) -> void:
	var eye: Vector3 = c.get_player_position() + Vector3(0.0, c.eye_height, 0.0)
	var t: Vector3 = c.get_opponent().position + Vector3(0.0, 1.3, 0.0) - eye
	c._look_yaw = atan2(t.x, t.z)
	c._look_pitch = atan2(t.y, Vector2(t.x, t.z).length())


func _test_spurt(host: Node3D) -> void:
	var fx: Node3D = BLOOD_FX.spurt(host, Vector3.ZERO, Vector3(0.3, 0.1, 1.0))
	var drops: CPUParticles3D = fx.get_node_or_null("Droplets") as CPUParticles3D
	_check("spurt has a one-shot 10-24 droplet emitter with a short life",
		drops != null and drops.one_shot and drops.amount >= 10 and drops.amount <= 24 and drops.lifetime >= 0.35 and drops.lifetime <= 0.7)
	_check("spurt has a faint short mist and only Compatibility materials",
		fx.get_node_or_null("Mist") is CPUParticles3D and _compatible_fx(fx))
	var freed: bool = false
	for i in 40:
		await get_tree().create_timer(0.05).timeout
		if not is_instance_valid(fx):
			freed = true
			break
	_check("spurt frees itself within two seconds", freed)


func _test_pool(host: Node3D) -> void:
	var ground := Vector3(2.0, 0.0, 3.0)
	var pool_node: Node3D = BLOOD_FX.pool(host, ground, 0.6, 0.3)
	var mark: MeshInstance3D = pool_node as MeshInstance3D
	_check("pool is a quad starting at roughly eight centimetres radius", mark != null and absf(mark.scale.x - 0.08) < 0.001)
	if mark == null:
		return
	var normal: Vector3 = (mark.global_transform.basis * Vector3(0.0, 0.0, 1.0)).normalized()
	_check("pool lies flat, normal up, just above the ground",
		normal.dot(Vector3.UP) > 0.999 and mark.global_position.y - ground.y >= 0.01 and mark.global_position.y - ground.y <= 0.02)
	_check("pool uses a Compatibility material", _compatible_fx(mark))
	await get_tree().create_timer(0.45).timeout
	_check("pool eases out to the requested radius in grow_s", absf(mark.scale.x - 0.6) < 0.01 and absf(mark.scale.y - 0.6) < 0.01,
		str(mark.scale))
	mark.queue_free()


func _test_rigged_stain(c: GoldTownChamber) -> void:
	var folk: Ep2TownFolk = c.get_rich()
	var rigs: Array = []
	if folk != null and folk.model != null:
		rigs = folk.model.find_children("*", "Skeleton3D", true, false)
	_check("a real rigged Ep2TownFolk is available for the stain test", folk != null and not rigs.is_empty())
	if folk == null or rigs.is_empty():
		return
	var outward: Vector3 = folk.global_transform.basis.z.normalized()
	var at: Vector3 = folk.global_position + Vector3(0.0, folk.height_m * 0.65, 0.0) + outward * 0.18
	var stain_node: Node3D = BLOOD_FX.stain(folk, at, outward)
	var attachment: BoneAttachment3D = stain_node.get_parent() as BoneAttachment3D
	_check("stain is parented under a BoneAttachment3D of that townsperson's skeleton",
		attachment != null and rigs.has(attachment.get_parent()))
	await get_tree().process_frame
	var before: Vector3 = stain_node.global_position
	folk.fall_dead()
	for i in 36:
		folk.step(1.0 / 60.0)
		await get_tree().process_frame
	_check("stain world position follows the falling torso through fall_dead()",
		stain_node.global_position.distance_to(before) > 0.12,
		"moved %.3f m" % stain_node.global_position.distance_to(before))
	_check("rigged stain uses a Compatibility material", _compatible_fx(stain_node))


func _test_town() -> void:
	var c: GoldTownChamber = TOWN.instantiate() as GoldTownChamber
	add_child(c)
	c.setup(0, [], 0)
	await get_tree().process_frame
	c._player_pos = GoldTownChamber.DUEL_MARK
	c._advance_to(GoldTownChamber.Beat.DRAW)
	_until(c, 10.0, func(): return c.get_draw_state() == "go")
	_until(c, 6.0, func(): return c.get_draw_state() == "lost")
	_check("a lost draw leaves neither a stain nor a pool",
		c.get_losses() == 1 and c.get_opponent().find_children("BloodStain", "MeshInstance3D", true, false).is_empty()
		and c._visuals.find_children("BloodPool*", "", true, false).is_empty())
	_until(c, 30.0, func(): return c.get_draw_state() == "wait")
	_until(c, 10.0, func(): return c.get_draw_state() == "go")
	var fired: bool = false
	for i in 120:
		_aim_at_opp(c)
		c.set_aim(true)
		c.draw_weapon()
		if c.shoot():
			fired = true
		c.step(1.0 / 60.0)
		if c.get_draw_state() != "go":
			break
	c.set_aim(false)
	_check("the real draw can still be won at the bell", fired and c.get_draw_state() == "won" and c.get_opponent().dead,
		"state %s fired %s" % [c.get_draw_state(), fired])
	_check("the winning shot leaves a stain on the opponent",
		c.get_opponent().find_children("BloodStain", "MeshInstance3D", true, false).size() == 1)
	_run(c, 1.1)
	var pools: Array = c._visuals.find_children("BloodPool*", "", true, false)
	_check("after the opponent falls a pool lies under his torso", pools.size() == 1 and c.get_opponent().dead)
	if pools.size() == 1:
		var pool_node: Node3D = pools[0] as Node3D
		var flat_distance: float = Vector2(pool_node.global_position.x - c.get_opponent().position.x,
			pool_node.global_position.z - c.get_opponent().position.z).length()
		_check("the draw pool is beneath the fallen man and is Compatibility-safe",
			flat_distance < 1.3 and _compatible_fx(pool_node), "%.2f m" % flat_distance)
	await _test_rigged_stain(c)          # it awaits frames: the town must outlive it
	c.queue_free()
	await get_tree().process_frame


func _aim_at_bear(w: WoodsQuadChamber, br: Ep2BearBrain) -> void:
	var eye: Vector3 = w._player_pos + Vector3(0.0, w.eye_height, 0.0)
	var t: Vector3 = br.actor.position + Vector3(0.0, br.actor.height_m * 0.55, 0.0) - eye
	w._look_yaw = atan2(t.x, t.z)
	w._look_pitch = atan2(t.y, Vector2(t.x, t.z).length())


func _test_woods() -> void:
	var w: WoodsQuadChamber = WOODS.instantiate() as WoodsQuadChamber
	add_child(w)
	w.setup(0, [], 0)
	await get_tree().process_frame
	var br: Ep2BearBrain = w.get_bear("Twitch")
	_check("the real woods has its scout bear", br != null)
	if br != null:
		br.actor.stop()
		Ep2BearKit.pose(br.actor, "idle")
		br.actor.position = Vector3(0.0, 0.0, 7.0)
		br.actor.visible = true
		br.hp = 1
		w._player_pos = Vector3.ZERO
		w.set_aim(true)
		var fired: bool = false
		for i in 12:
			_aim_at_bear(w, br)
			if w.shoot():
				fired = true
			if br.is_dead():
				break
			w.step(1.0 / 60.0)
		w.set_aim(false)
		_check("the player's rifle shot hits and kills the bear", fired and br.is_dead() and str(br.get_meta("killed_by", "")) == "player")
		var stains: Array = br.actor.find_children("BloodStain", "MeshInstance3D", true, false)
		var spurts: Array = w._visuals.find_children("BloodSpurt*", "", true, false)
		var pools: Array = w._visuals.find_children("BloodPool*", "", true, false)
		_check("the bear hit makes a spurt and one body stain", spurts.size() >= 1 and stains.size() == 1,
			"spurts %d stains %d" % [spurts.size(), stains.size()])
		_check("the dead bear gets a pool under the corpse", pools.size() == 1)
		var compatible: bool = true
		for fx in spurts + stains + pools:
			compatible = compatible and _compatible_fx(fx)
		_check("all bear blood materials work in the Compatibility renderer", compatible)
	w.queue_free()
	await get_tree().process_frame


func _ready() -> void:
	print("-- EP2 BLOOD")
	var host := Node3D.new()
	add_child(host)
	await _test_spurt(host)
	await _test_pool(host)
	await _test_town()
	await _test_woods()
	host.queue_free()
	await get_tree().process_frame
	_check("no Decal nodes anywhere in the tree", get_tree().root.find_children("*", "Decal", true, false).is_empty())
	if _fail == 0:
		print("EP2_BLOOD: ALL PASS")
	else:
		print("EP2_BLOOD: %d FAILURE(S)" % _fail)
	get_tree().quit(_fail)
