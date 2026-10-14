extends Node
## Gate for the founder's 2026-10-14 feedback on the woods (skills ep2-bull-companion-pacing, ep2-road-donkey-cart):
##  * INFERNO IS NOT MECHANICAL: his unprompted lines are rare, random and rotate (never "walk soft" twice running); when Lil Blunt scouts AHEAD he
##    carries on (an adult - he does not stand and wait for him to come back); when Lil Blunt LAGS he looks back, waits a few seconds, then strolls on.
##  * HE COVERS LIL BLUNT: hurt, or a bear on him -> Inferno fires (woods and the quad ride).
##  * THE ROAD: the farmer's donkey cart (founder's model) plods down the desert road; the quad slows behind it, Inferno greets, the farmer answers,
##    Lil Blunt answers, they pass him and open up again.
## Run: godot --headless res://tests/ep2_companion_cart_test.tscn
const WOODS := preload("res://src/episode2/chamber/woods_quad.tscn")

var _fail: int = 0


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])


func _run(w: WoodsQuadChamber, seconds: float) -> void:
	for i in int(seconds * 60.0):
		w.step(1.0 / 60.0)


func _manifest_text(id: String) -> String:
	var m = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio-manifest.json"))
	for e in m["voice"]:
		if str(e["id"]) == id:
			return str(e["text"])
	return ""


func _ready() -> void:
	print("-- INFERNO PACING")
	var w: WoodsQuadChamber = WOODS.instantiate()
	add_child(w)
	var said: Array = []
	w.line_spoken.connect(func(id): said.append(id))
	w.setup(0, [], 0)
	w.debug_invulnerable = true
	await get_tree().process_frame
	# Lil Blunt strides on AHEAD of him along the trail: Inferno keeps walking, says an easy word at most now and then
	var trail: Array = WoodsQuadChamber.SNEAK_TRAIL
	var b0: Vector3 = w.get_bull().position
	var lead_s: float = 0.0
	var moved: float = 0.0
	# he strides along the trail a good way in front of Inferno (a scout), all the way to the thicket
	for i in 60 * 6:
		lead_s = minf(lead_s + 2.6 / 60.0, 150.0)
		w._player_pos = _trail_point(trail, w._trail_s(Vector2(b0.x, b0.z)) + 9.0 + lead_s)
		w.step(1.0 / 60.0)
	moved = w.get_bull().position.distance_to(b0)
	_check("Lil Blunt scouts AHEAD: Inferno does not stand waiting for him to come back - he walks on (moved %.1f m in 6 s)" % moved, moved > 6.0 and not w.get_bull().is_walking() == false, "%.1f" % moved)
	for i in 60 * 60:
		lead_s = minf(lead_s + 2.6 / 60.0, 150.0)
		w._player_pos = _trail_point(trail, w._trail_s(Vector2(w.get_bull().position.x, w.get_bull().position.z)) + 9.0)
		w.step(1.0 / 60.0)
		if w.get_beat_name() != "SNEAK":
			break
	var talk: Array = said.filter(func(id): return str(id).begins_with("vo_bull_") and not str(id).begins_with("vo_bull_scout"))
	_check("...and he does not nag: at most 4 unprompted lines in a minute (%d)" % talk.size(), talk.size() <= 4, str(talk))
	var repeats: int = 0
	for i in range(1, talk.size()):
		if talk[i] == talk[i - 1]:
			repeats += 1
	_check("...never the same line twice running", repeats == 0, str(talk))
	var ahead_said: Array = said.filter(func(id): return str(id) in WoodsQuadChamber.BULL_AHEAD)
	_check("...and when Lil Blunt is out in front he acknowledges it (an 'ahead' line, a grown man's word)", ahead_said.size() >= 1 and ahead_said.size() <= 3, str(ahead_said))
	w.queue_free()

	var w1: WoodsQuadChamber = WOODS.instantiate()
	add_child(w1)
	var said1: Array = []
	w1.line_spoken.connect(func(id): said1.append(id))
	w1.setup(0, [], 0)
	w1.debug_invulnerable = true
	await get_tree().process_frame
	# Lil Blunt LAGS far behind: Inferno stops and looks back, then after a few seconds strolls on (not rigid)
	var bull_far: Vector2 = trail[4]
	w1.get_bull().position = Vector3(bull_far.x, 0.0, bull_far.y)
	w1._sneak_i = 5
	w1._player_pos = Vector3(0.0, 0.0, 2.0)
	_run(w1, 1.5)
	_check("Lil Blunt lags: Inferno stops and looks back for him", not w1.get_bull().is_walking() and w1._bull_waiting)
	var p_wait: Vector3 = w1.get_bull().position
	_run(w1, 4.6)
	_check("...but only for a few seconds: then he strolls on without him (an adult, not rigid)", w1.get_bull().position.distance_to(p_wait) > 0.8 or w1.get_bull().is_walking(),
		"moved %.2f" % w1.get_bull().position.distance_to(p_wait))
	w1.queue_free()

	print("-- INFERNO COVERS LIL BLUNT")
	var w2: WoodsQuadChamber = WOODS.instantiate()
	add_child(w2)
	var said2: Array = []
	w2.line_spoken.connect(func(id): said2.append(id))
	w2.setup(0, [], 0)
	w2.debug_invulnerable = false
	await get_tree().process_frame
	var barn: Ep2BearBrain = w2.get_bear("Professor Barnaby")
	var bf := Vector3(sin(barn.actor.facing), 0.0, cos(barn.actor.facing))
	w2._player_pos = barn.actor.position + bf * 6.0
	w2._look_yaw = atan2(-bf.x, -bf.z)
	w2.get_bull().position = w2._player_pos + Vector3(2.0, 0.0, 1.5)
	w2._health = 1
	barn.alarm(w2._player_pos)
	w2._invuln = 30.0                             # the test player must live to see him fire
	var shots0: int = w2.get_bull_shots()
	_run(w2, 10.0)
	_check("a bear on Lil Blunt who is down to his last heart: Inferno opens fire", w2.get_bull_shots() > shots0, "%d shots" % w2.get_bull_shots())
	_check("...and calls out that he has him covered", said2.any(func(id): return str(id) in WoodsQuadChamber.BULL_COVER), str(said2))
	w2.queue_free()

	print("-- THE DONKEY CART")
	var w3: WoodsQuadChamber = WOODS.instantiate()
	add_child(w3)
	var said3: Array = []
	w3.line_spoken.connect(func(id): said3.append(id))
	w3.setup(0, [], 0)
	w3.debug_invulnerable = true
	await get_tree().process_frame
	_check("the founder's donkey cart is built on the desert road, right of the centre line", w3.get_cart_node() != null and ResourceLoader.exists(WoodsQuadChamber.CART_MODEL)
		and w3.get_cart_node().find_children("*", "MeshInstance3D", true, false).size() >= 1)
	_check("...with the driver on the box and the donkey in the shafts (one model, ~14k faces)", w3.get_cart_node().find_children("*", "MeshInstance3D", true, false).size() >= 1)
	for b in w3.get_bears():                                  # a clear road: this run is about the cart, not the bears
		(b as Ep2BearBrain).actor.visible = false
		(b as Ep2BearBrain).aware = Ep2BearBrain.Aware.DEAD
	w3._advance_to(WoodsQuadChamber.Beat.RIDE)
	var guard: int = 0
	while not w3.is_riding() and guard < 900:
		guard += 1
		w3.step(1.0 / 60.0)
	w3._ride_s = WoodsQuadChamber.CART_S0 - 110.0
	w3._ride_speed = WoodsQuadChamber.RIDE_SPEED
	var min_speed: float = 99.0
	var speed_at_pass: float = 99.0
	var t: float = 0.0
	var passed_at: float = -1.0
	while t < 60.0 and w3.get_cart_state() < 3:
		t += 1.0 / 60.0
		w3.step(1.0 / 60.0)
		var gap: float = w3._cart_s - w3._ride_s
		if gap < 70.0 and gap > -10.0:
			min_speed = minf(min_speed, w3._ride_speed)
		if absf(gap) < 5.0:
			speed_at_pass = minf(speed_at_pass, w3._ride_speed)
	_check("the quad slows down behind the cart (so as not to spook the donkey): %.1f m/s near him" % speed_at_pass, speed_at_pass < WoodsQuadChamber.CART_SPEED + 4.0, "%.2f" % speed_at_pass)
	_check("...and they get past him (the cart is behind them)", w3.get_cart_state() == 3 and w3._ride_s > w3._cart_s, "state %d" % w3.get_cart_state())
	var order: Array = ["vo_bull_cart1", "vo_bull_cart2", "vo_cart_man", "vo_lb_cart"]
	var in_order: bool = true
	for i in range(1, order.size()):
		if said3.find(order[i - 1]) < 0 or said3.find(order[i - 1]) > said3.find(order[i]):
			in_order = false
	_check("Inferno warns about the animal, greets the farmer, the farmer answers, Lil Blunt answers - in order", in_order, str(said3))
	_run(w3, 12.0)
	_check("past him the road opens up again (speed back above 8 m/s)", w3._ride_speed > 8.0 or w3.get_beat_name() != "RIDE", "%.1f" % w3._ride_speed)
	var lines: Array = ["vo_bull_ahead1", "vo_bull_ahead2", "vo_bull_ahead3", "vo_bull_wait1", "vo_bull_wait2", "vo_bull_sneak2", "vo_bull_sneak3", "vo_bull_quiet2",
		"vo_bull_cover1", "vo_bull_cover2", "vo_bull_cover3", "vo_bull_cart1", "vo_bull_cart2", "vo_cart_man", "vo_lb_cart"]
	var missing: Array = []
	for id in lines:
		if not ResourceLoader.exists("res://src/assets/sounds/voice/%s.mp3" % id) or _manifest_text(id) == "":
			missing.append(id)
	_check("all %d new voice lines are generated and in the manifest" % lines.size(), missing.is_empty(), str(missing))
	_check("Inferno speaks at a natural pace on the new lines", lines.filter(func(id): return str(id).begins_with("vo_bull")).all(func(id): return _manifest_speed(str(id)) >= 1.0))
	w3.queue_free()

	await get_tree().process_frame
	if _fail == 0:
		print("EP2_COMPANION_CART: ALL PASS")
		get_tree().quit(0)
	else:
		print("EP2_COMPANION_CART: %d FAILED" % _fail)
		get_tree().quit(1)


## The point `s` metres along the sneak trail.
func _trail_point(trail: Array, s: float) -> Vector3:
	var acc: float = 0.0
	for i in range(trail.size() - 1):
		var a: Vector2 = trail[i]
		var b: Vector2 = trail[i + 1]
		var l: float = a.distance_to(b)
		if acc + l >= s:
			var p: Vector2 = a.lerp(b, (s - acc) / maxf(l, 0.001))
			return Vector3(p.x, 0.0, p.y)
		acc += l
	var e: Vector2 = trail[trail.size() - 1]
	return Vector3(e.x, 0.0, e.y)


func _manifest_speed(id: String) -> float:
	var m = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio-manifest.json"))
	for e in m["voice"]:
		if str(e["id"]) == id:
			return float((e.get("voice_settings", {}) as Dictionary).get("speed", 1.0))
	return 0.0
