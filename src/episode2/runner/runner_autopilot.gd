class_name RunnerAutopilot
extends RefCounted
## Episode 2 runner AUTOPILOT — plays a leg with human-like lookahead.
##
## One implementation, two users:
##   - tests/ep2_runner_carts_test.gd proves every leg is SOLVABLE at speed with
##     cart attrition (reach the chamber with zero hits) and has teeth.
##   - ?ep2bot=1 on the web build (ep2_entry.gd, TEST-ONLY) lets a browser capture
##     show clean play, since harness key timing drifts with render latency.
## It only calls the sim's public input API — the same verbs a player has.

## Lane `l` is doomed within [d, d + h] (boulder or rail end on it).
static func _doomed(r: Node, l: int, d: float, h: float) -> bool:
	for o in r.get_obstacles():
		if str(o.get("type", "")) == "boulder" and int(o["lane"]) == l:
			var z: float = float(o["z"])
			if z >= d - 1.5 and z <= d + h:
				return true
	for e in r.get_rail_events():
		if str(e["type"]) == "end" and int(e["lane"]) == l and not e["done"]:
			var z2: float = float(e["z"])
			if z2 >= d and z2 <= d + h:
				return true
	return false

## One frame of autopilot input for sim `r`. Call before r.step().
static func tick(r: Node) -> void:
	var d: float = r.get_distance()
	var v: float = r.get_speed()
	var lane: int = r.get_lane()
	# 1. Lanes: leave a doomed rail for the nearest safe live one (one hop at a time).
	if not r.is_ziplining():
		var h: float = v * 1.1
		if _doomed(r, lane, d, h):
			var best: int = -1
			for step in [1, -1, 2, -2]:
				var t: int = lane + int(step)
				if t < 0 or t > 2 or not r.is_cart_alive(t) or _doomed(r, t, d, h):
					continue
				# Only reachable through live carts.
				var mid_ok: bool = absi(int(step)) == 1 or r.is_cart_alive((lane + t) / 2)
				if mid_ok:
					best = t
					break
			if best >= 0:
				if best > lane:
					r.switch_lane_right()
				else:
					r.switch_lane_left()
	lane = r.get_lane()
	var x: float = r.get_cart_x()
	var duck := false
	for o in r.get_obstacles():
		var t2: String = str(o.get("type", ""))
		var z: float = float(o["z"])
		var ahead: float = z - d
		var ol: int = int(o["lane"])
		var in_lane: bool = ol < 0 or absf(x - float(RunnerGraybox.LANE_X[clampi(ol, 0, 2)])) < 1.0 \
			or ol == lane
		if not in_lane or o.get("cancelled", false):
			continue
		match t2:
			"box":
				if ahead > 0.0 and ahead - RunnerGraybox.OBSTACLE_HIT_Z <= v * 0.2:
					r.jump()
			"arrow":
				if ahead > -1.5 and ahead < v * 0.25:
					duck = true
			"boarder":
				if ahead > 0.0 and ahead < v * 0.3 and not r.is_swiping():
					r.swipe()
	if duck and not r.is_duck_held():
		r.duck_start()
	elif not duck and r.is_duck_held():
		r.duck_end()
	# Ziplines: jump to hook; jump near the end of a chained cable to swing on.
	for seg in r.get_zip_segments():
		var sz: float = float(seg["start_z"]) - d
		if not r.is_ziplining() and sz > 0.0 and sz <= v * 0.25:
			r.jump()
	if r.is_ziplining():
		var zi: int = r.get_zip_index()
		var segs: Array = r.get_zip_segments()
		if zi >= 0 and float(segs[zi]["end_z"]) - d <= RunnerGraybox.ZIP_TRANSFER_WINDOW:
			r.jump()
