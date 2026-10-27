extends Node
## Founder 2026-10-27: "When I use the gatlin gun it doesnt hit any of the targets". This is the PLAYER'S shot, not Utah's
## bore-laid demonstration: build the real town, take the crank, centre each plate with the mounted mouse-look path, read the
## actual camera ray, then fire through shoot(). Run: godot --headless res://tests/ep2_gatling_hits_test.tscn
const TOWN := preload("res://src/episode2/chamber/gold_town.tscn")
var failures: int = 0


func check(label: String, ok: bool, detail: String = "") -> void:
	print("  [PASS] " if ok else "  [FAIL] ", label, "" if ok or detail.is_empty() else "  (" + detail + ")")
	if not ok:
		failures += 1


func _run(c: GoldTownChamber, seconds: float) -> void:
	for i in int(seconds * 60.0):
		c.step(1.0 / 60.0)


func _plate_centre(g: Ep2GatlingPost, index: int) -> Vector3:
	var t: Dictionary = g.targets[index]
	var swing: Node3D = t["swing"]
	if swing != null:
		return swing.global_transform * Ep2GatlingPost.PLATE_CENTRE
	return (t["node"] as Node3D).global_position + Vector3(0.0, 1.2, 0.0)


func _inside_arc(g: Ep2GatlingPost, centre: Vector3) -> bool:
	var d: Vector3 = centre - g.eye_position()
	var wanted_yaw: float = atan2(d.x, d.z)
	return absf(wrapf(wanted_yaw - g.heading, -PI, PI)) <= Ep2GatlingPost.ARC_YAW + 0.001


## Move the mouse exactly as the mounted chamber receives it. The error is measured from the camera's current ray, so this
## also compensates any residual view kick just as a player would; aim_toward() and set_aim() are deliberately not used.
func _mouse_centre(c: GoldTownChamber, centre: Vector3) -> void:
	for i in 10:
		var camera: Camera3D = c.get_camera()
		var eye: Vector3 = camera.global_position
		var ray: Vector3 = -camera.global_transform.basis.z
		var wanted: Vector3 = centre - eye
		var wanted_yaw: float = atan2(wanted.x, wanted.z)
		var wanted_pitch: float = atan2(wanted.y, Vector2(wanted.x, wanted.z).length())
		var ray_yaw: float = atan2(ray.x, ray.z)
		var ray_pitch: float = asin(clampf(ray.y, -1.0, 1.0))
		var dy: float = wrapf(wanted_yaw - ray_yaw, -PI, PI)
		var dp: float = wanted_pitch - ray_pitch
		if absf(dy) < 0.00002 and absf(dp) < 0.00002:
			break
		c.look(Vector2(-dy / Ep2GatlingPost.AIM_SENS, -dp / Ep2GatlingPost.AIM_SENS))
		c.step(1.0 / 60.0)


func _finish() -> void:
	if failures == 0:
		print("EP2_GATLING_HITS: ALL PASS")
	else:
		print("EP2_GATLING_HITS: %d FAILURE(S)" % failures)
	get_tree().quit(failures)


func _ready() -> void:
	print("-- THE COLT GATLING: the player's crosshair must hit")
	var c: GoldTownChamber = TOWN.instantiate()
	add_child(c)
	c.setup(0, [], 0)
	await get_tree().process_frame
	var g: Ep2GatlingPost = c.get_gatling()
	check("the real Armory yard has the streamed Gatling and all of its plates", g != null and g.plate_count() == Ep2GoldTown.GATLING_PLATES.size())
	if g == null:
		c.queue_free()
		await get_tree().process_frame
		_finish()
		return
	c._advance_to(GoldTownChamber.Beat.ARMORY)
	c._player_pos = g.stand_position()
	c._mount()
	c.step(1.0 / 60.0)
	check("Lil Blunt is at the crank in the real mounted mode", c.is_mounted())
	if not c.is_mounted():
		c.queue_free()
		await get_tree().process_frame
		_finish()
		return
	var in_arc: int = 0
	var rung: int = 0
	for i in g.targets.size():
		var t: Dictionary = g.targets[i]
		if str(t["kind"]) != "plate":
			continue
		var centre: Vector3 = _plate_centre(g, i)
		if not _inside_arc(g, centre):
			print("  [SKIP] plate ", i, " is outside the gun's clamped arc")
			continue
		in_arc += 1
		_mouse_centre(c, centre)
		var camera: Camera3D = c.get_camera()
		var sight_hit: Dictionary = g._trace(camera.global_position, -camera.global_transform.basis.z)
		check("plate %d is under the PLAYER'S camera crosshair before the burst" % i, int(sight_hit.get("index", -1)) == i,
			str(sight_hit))
		var shots0: int = g.shots_fired
		var accepted: bool = false
		# Hold the trigger through several ordinary clicks: about fifteen rounds, then let the burst and the crank finish.
		for frame in 150:
			if frame < 90 and frame % 18 == 0:
				accepted = c.shoot() or accepted
			c.step(1.0 / 60.0)
		_run(c, 1.0)
		check("plate %d received a real burst through shoot()" % i, accepted and g.shots_fired > shots0,
			"%d rounds" % (g.shots_fired - shots0))
		var hits: int = int((g.targets[i] as Dictionary)["hits"])
		check("plate %d inside the arc rings from the mounted player's rounds" % i, hits > 0, "%d hits" % hits)
		if hits > 0:
			rung += 1
	check("every plate inside the gun's arc was hit", in_arc > 0 and rung == in_arc, "%d / %d plates" % [rung, in_arc])
	c.look(Vector2(-10000.0, 0.0))
	check("mounted mouse look still cannot traverse outside the gun's arc", absf(g.aim_yaw - g.heading) <= Ep2GatlingPost.ARC_YAW + 1e-4)
	c.queue_free()
	await get_tree().process_frame
	_finish()
