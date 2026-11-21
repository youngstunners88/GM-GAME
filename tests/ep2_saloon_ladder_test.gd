extends Node
## EP2 SALOON SIDE LADDER (founder 2026-11-21: the two old regulars drink OUTSIDE on the saloon's balcony and there was no way up; "a
## LADDER on the outside side wall, not an interior staircase"; skill ep2-saloon-roof-access).
##  * The ladder stands at the saloon's free (south) end, flush with the side wall's line, outside the porch roof, its rails 1 m above the
##    balcony boards; the balcony gets end rails with a gap where it tops out. Doors, batwings, hitching rails, troughs, the Treasury
##    and every story mark stay clear of it. The streamed ladder replaces its stand-in in place when the pack mounts.
##  * "Climb [E]" at the foot takes Lil Blunt up rung by rung (no shot, no sights, the rifle lowered while his hands are on the rungs,
##    never inside the wall or the porch roof), onto the balcony, where he walks its boards round the chairs and the two old men and
##    cannot step off; "Climb down [E]" at the gap brings him back to the street, and the batwings still open for him after.
##  * The old men stay where they are, standing on boards that are really there.
## Run: godot --headless res://tests/ep2_saloon_ladder_test.tscn

const TOWN := preload("res://src/episode2/chamber/gold_town.tscn")
const LADDER := preload("res://src/episode2/chamber/ep2_saloon_ladder.gd")
var failures := 0
var checks := 0


func check(label: String, ok: bool, detail: String = "") -> void:
	checks += 1
	print("  [%s] %s %s" % ["PASS" if ok else "FAIL", label, detail if not ok else ""])
	if not ok:
		failures += 1


func _run(c: GoldTownChamber, seconds: float) -> void:
	for i in int(seconds * 60.0):
		c.step(1.0 / 60.0)


## Walk straight at `goal` like a player at the keys (re-aimed every frame). True when he gets within 0.4 m.
func _walk_to(c: GoldTownChamber, goal: Vector3, seconds: float = 12.0) -> bool:
	for i in int(seconds * 60.0):
		var me: Vector3 = c.get_player_position()
		var d := Vector2(goal.x - me.x, goal.z - me.z)
		if d.length() < 0.4:
			c.set_move_input(Vector2.ZERO)
			return true
		c._look_yaw = atan2(d.x, d.y)
		c.set_move_input(Vector2(0.0, 1.0))
		c.step(1.0 / 60.0)
	c.set_move_input(Vector2.ZERO)
	return false


## The y of the first saloon surface straight below `from` (the kit's own triangles), or -INF.
static func _floor_below(saloon: Node3D, from: Vector3) -> float:
	var best: float = -INF
	for mi in saloon.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		if m.mesh == null:
			continue
		var xf: Transform3D = m.global_transform
		var inv: Transform3D = xf.affine_inverse()
		var o: Vector3 = inv * from
		var dir: Vector3 = (inv.basis * Vector3.DOWN).normalized()
		for si in m.mesh.get_surface_count():
			var arr: Array = m.mesh.surface_get_arrays(si)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			var n: int = idx.size() if idx.size() > 0 else v.size()
			for t in range(0, n, 3):
				var a: Vector3 = v[idx[t]] if idx.size() > 0 else v[t]
				var b: Vector3 = v[idx[t + 1]] if idx.size() > 0 else v[t + 1]
				var cc: Vector3 = v[idx[t + 2]] if idx.size() > 0 else v[t + 2]
				var hit = Geometry3D.ray_intersects_triangle(o, dir, a, b, cc)
				if hit != null:
					var w: Vector3 = xf * (hit as Vector3)
					if w.y < from.y and w.y > best:
						best = w.y
	return best


func _ready() -> void:
	print("-- EP2 SALOON SIDE LADDER")
	var c: GoldTownChamber = TOWN.instantiate()
	add_child(c)
	c.setup(0, [], 0)
	await get_tree().process_frame
	c.step(1.0 / 60.0)
	var lad = c.get_ladder()
	check("the saloon has its side ladder", lad != null and c._visuals.find_child("SaloonLadder", true, false) != null)
	if lad == null:
		_done()
		return
	var S := func(p: Vector3) -> Vector3: return Ep2GoldTown.local_to_world("Bldg_Saloon", p)
	var L := func(w: Vector3) -> Vector3: return Ep2GoldTown.building_xform(Ep2GoldTown.entry("Bldg_Saloon")).affine_inverse() * w
	# ---- (a) the ladder itself
	var holder: Node3D = lad.get_node("Ladder")
	check("the streamed ladder is drawn (the pack is in the project)", lad.streamed and holder.get_node_or_null("Streamed") != null)
	var top: float = -INF
	var low: float = INF
	for mi in holder.find_children("*", "MeshInstance3D", true, false):
		var ab: AABB = (mi as MeshInstance3D).get_aabb()
		for k in 8:
			var w: Vector3 = (mi as MeshInstance3D).global_transform * ab.get_endpoint(k)
			top = maxf(top, w.y)
			low = minf(low, w.y)
	check("it stands on the ground and its rails run ~1 m above the balcony boards", absf(low) < 0.02 and top > Ep2GoldTown.BALCONY_Y + 0.9 and top < Ep2GoldTown.BALCONY_Y + 1.1,
		"low %.2f top %.2f" % [low, top])
	var at_l: Vector3 = L.call(holder.global_position)
	check("it is on the saloon's free (south, desert-side) end, outside the porch roof, in line with the side wall", at_l.x < -6.33 and at_l.x > -6.6 and at_l.z > -0.2 and at_l.z < 0.8,
		str(at_l))
	var tre: Array = Ep2GoldTown.entry("Bldg_Treasury")
	check("...not in the 1.5 m gap toward the Treasury", holder.global_position.z < float(tre[2]) - 5.0 - 3.0)
	check("rungs ~0.3 m apart", absf(LADDER.RUNG_STEP - 0.3) < 0.01 and LADDER.RUNGS >= 12)
	var door: Vector3 = Ep2GoldTown.door_world("Bldg_Saloon", 0.0)
	check("the batwing doorway is well clear of it (> 5 m)", Vector2(door.x - holder.global_position.x, door.z - holder.global_position.z).length() > 5.0)
	var clear: bool = true
	var near: String = ""
	for n in c._visuals.find_children("*", "", true, false):
		var nm: String = str(n.name)
		if (nm.begins_with("HitchRail") or nm.begins_with("Trough") or nm.begins_with("LampPost") or nm.begins_with("Bench")) and n is Node3D:
			var d: float = Vector2((n as Node3D).global_position.x - holder.global_position.x, (n as Node3D).global_position.z - holder.global_position.z).length()
			if d < 3.0:
				clear = false
				near = "%s %.2f m" % [nm, d]
	check("no hitching rail, trough, lamp or bench within 3 m of it", clear, near)
	var horses_ok: bool = true
	for h in c._visuals.find_children("*Horse*", "Node3D", true, false):
		if Vector2((h as Node3D).global_position.x - holder.global_position.x, (h as Node3D).global_position.z - holder.global_position.z).length() < 2.5:
			horses_ok = false
	check("no horse stands at it", horses_ok)
	check("the town's walking graph keeps townspeople round its foot (it is a walk-around prop)",
		(c._town_col.get("props", []) as Array).any(func(pr): return (pr[0] as Vector2).distance_to(lad.to_world2(LADDER.LADDER_AT)) < 0.05))
	var rails: Node3D = lad.get_node_or_null("BalconyEndRails")
	check("the balcony gets end rails, with a gap where the ladder tops out", rails != null and rails.get_child_count() >= 8)
	# ---- (b) stand-in -> streamed, in place
	LADDER.force_stand_in = true
	var scratch := Node3D.new()
	add_child(scratch)
	var props: Array = []
	var l2 = LADDER.build(scratch, null, props)
	var si: Node = l2.get_node("Ladder").get_node_or_null("StandIn")
	var rungs: int = 0
	if si != null:
		for m in si.get_children():
			if m is MeshInstance3D and (m as MeshInstance3D).mesh is CylinderMesh:
				rungs += 1
	check("before the pack mounts the same ladder stands as rails, rungs and boards (procedural)", si != null and not l2.streamed and rungs == LADDER.RUNGS, "rungs %d" % rungs)
	LADDER.force_stand_in = false
	check("...and turns into the streamed ladder in place when it does", l2.upgrade_now() and l2.get_node("Ladder").get_node_or_null("Streamed") != null)
	scratch.queue_free()
	# ---- (c) the old men are up there, on real boards, at the rail
	var crowd: Ep2TownPeople = c.get_people()
	var saloon: Node3D = c._visuals.find_child("Bldg_Saloon", true, false) as Node3D
	var regulars: Dictionary = {}
	for id in Ep2TownPeople.BALCONY_REGULARS:
		var p: Ep2TownPeople.Person = crowd.person(id)
		regulars[id] = p.folk.position
		var fl: float = _floor_below(saloon, p.folk.position + Vector3(0.0, 0.5, 0.0))
		check("%s stands on the balcony at the rail (y %.2f), on boards that are there (the kit's top %.2f below him)" % [id, p.folk.position.y, fl],
			absf(p.folk.position.y - Ep2GoldTown.BALCONY_Y) < 0.02 and absf(fl - Ep2GoldTown.BALCONY_Y) < 0.06)
	# ---- (d) up the ladder
	c._player_pos = lad.to_world(Vector3(-9.2, 0.0, 0.6))
	check("away from it there is no climb", not lad.can_climb_up(c._player_pos) and c._ladder_prompt_text() == "")
	check("[E] there does not climb", not c.start_rig(""))
	_walk_to(c, lad.foot_world() + (lad.foot_world() - lad.to_world(LADDER.LADDER_AT)).normalized() * 0.5)
	c.step(1.0 / 60.0)
	check("at its foot: \"Climb\" (the INTERACT button lights on a phone)", c._ladder_prompt_text().begins_with("Climb") and c.get_hud()._search.text.begins_with("Climb"),
		"%s | %s" % [c._ladder_prompt_text(), c.get_hud()._search.text])
	c._player_pos = lad.to_world(Vector3(-5.8, 0.0, 0.3))
	check("not from the porch side (that would walk him through it)", not lad.can_climb_up(c._player_pos))
	c._player_pos = lad.to_world(Vector3(-9.2, 0.0, 0.6))
	_walk_to(c, lad.foot_world() + Vector3(0.0, 0.0, 0.0) + (lad.foot_world() - lad.to_world(LADDER.LADDER_AT)).normalized() * 0.4)
	check("[E] starts the climb", c.start_rig("") and lad.busy())
	var ys: Array = []
	var inside: bool = false
	var gun_down: bool = true
	var no_fire: bool = true
	var max_drop: float = 0.0
	var prev_y: float = 0.0
	var rung_on: Dictionary = {}
	for i in 60 * 12:
		c.step(1.0 / 60.0)
		var me: Vector3 = c.get_player_position()
		var l: Vector3 = L.call(me)
		ys.append(me.y)
		max_drop = maxf(max_drop, prev_y - me.y)
		prev_y = me.y
		if l.y > 0.2 and l.y < Ep2GoldTown.BALCONY_Y - 0.01 and l.x > -6.50:
			inside = true                           # under the boards: never inside the porch roof's edge or the wall
		if lad.busy():
			gun_down = gun_down and not c.get_viewmodel()._shown
			no_fire = no_fire and not c.shoot()
			if l.y > 0.25 and l.y < 3.95:
				rung_on[int(round(l.y / LADDER.RUNG_STEP))] = true
		if not lad.busy():
			break
	var me2: Vector3 = c.get_player_position()
	check("he climbs to the balcony boards (%.2f m) and stands on them" % me2.y, lad.on_top() and absf(me2.y - Ep2GoldTown.BALCONY_Y) < 0.01
		and absf(c._ground_y - Ep2GoldTown.BALCONY_Y) < 0.01 and lad.over_deck(me2))
	check("rung by rung, only ever up (%d rungs under his hands)" % rung_on.size(), rung_on.size() >= 10 and max_drop < 0.005)
	check("the climb takes a few seconds, not a teleport (%.1f s)" % (ys.size() / 60.0), ys.size() > 60 * 3 and ys.size() < 60 * 9)
	check("never inside the wall or through the porch roof", not inside)
	check("the rifle is lowered while his hands are on the rungs (and no shot leaves it)", gun_down and no_fire)
	c.step(1.0 / 60.0)
	check("...and back in his hands up there", c.get_viewmodel()._shown)
	# ---- (e) the balcony
	for id in regulars:
		check("%s has not moved (he drinks where he stood)" % id, crowd.person(id).folk.position.distance_to(regulars[id]) < 0.05)
	c._look_yaw = atan2((S.call(Vector3(5.0, 0, 0.6)) - me2).x, (S.call(Vector3(5.0, 0, 0.6)) - me2).z)
	c.set_move_input(Vector2(0.0, 1.0))
	_run(c, 4.0)
	c.set_move_input(Vector2.ZERO)
	var gl: Vector3 = L.call(c.get_player_position())
	var gap_to_men: float = INF
	for id in regulars:
		gap_to_men = minf(gap_to_men, Vector2(c.get_player_position().x - (regulars[id] as Vector3).x, c.get_player_position().z - (regulars[id] as Vector3).z).length())
	check("walking along it he stops at the old men and their chairs (never through them: %.2f m)" % gap_to_men, gap_to_men > 0.6 and gl.y > Ep2GoldTown.BALCONY_Y - 0.01)
	c._look_yaw = atan2((S.call(Vector3(gl.x, 0, 4.0)) - c.get_player_position()).x, (S.call(Vector3(gl.x, 0, 4.0)) - c.get_player_position()).z)
	c.set_move_input(Vector2(0.0, 1.0))
	_run(c, 2.0)
	c.set_move_input(Vector2.ZERO)
	check("he cannot walk off over the front rail", L.call(c.get_player_position()).z < 1.2 and c.get_player_position().y > Ep2GoldTown.BALCONY_Y - 0.01, str(L.call(c.get_player_position())))
	c._look_yaw = atan2((S.call(Vector3(-9.0, 0, 0.3)) - c.get_player_position()).x, (S.call(Vector3(-9.0, 0, 0.3)) - c.get_player_position()).z)
	c.set_move_input(Vector2(0.0, 1.0))
	_run(c, 3.0)
	c.set_move_input(Vector2.ZERO)
	var el: Vector3 = L.call(c.get_player_position())
	check("...nor off the end through the gap (that is what the ladder is for)", el.x > -5.7 and c.get_player_position().y > Ep2GoldTown.BALCONY_Y - 0.01 and lad.on_top(), str(el))
	c.jump()
	_run(c, 1.5)
	check("a jump up there lands back on the boards", absf(c.get_player_position().y - Ep2GoldTown.BALCONY_Y) < 0.01 and lad.on_top())
	# ---- (f) down again
	c.step(1.0 / 60.0)
	check("at the gap: \"Climb down\"", c._ladder_prompt_text().begins_with("Climb down"), c._ladder_prompt_text())
	check("[E] starts down", c.start_rig("") and lad.busy())
	var rose: float = 0.0
	var py: float = c.get_player_position().y
	for i in 60 * 12:
		c.step(1.0 / 60.0)
		rose = maxf(rose, c.get_player_position().y - py)
		py = c.get_player_position().y
		if not lad.busy():
			break
	var fm: Vector3 = c.get_player_position()
	check("he climbs down to the street at its foot, only ever down", lad.state == "ground" and absf(fm.y) < 0.01 and absf(c._ground_y) < 0.01
		and fm.distance_to(lad.foot_world()) < 0.2 and rose < 0.005, "%s rose %.3f" % [str(fm), rose])
	check("one climb up and one down counted", lad.climbs_up == 1 and lad.climbs_down == 1)
	c.step(1.0 / 60.0)
	check("the rifle is back in his hands in the street", c.get_viewmodel()._shown)
	# ---- (g) the batwings still open for him
	var widest: float = 0.0
	_walk_to(c, Ep2GoldTown.door_world("Bldg_Saloon", 2.5))
	var goal: Vector3 = S.call(Vector3(0.0, 0.0, -2.5))
	for i in 60 * 6:
		var me: Vector3 = c.get_player_position()
		var d := Vector2(goal.x - me.x, goal.z - me.z)
		if d.length() < 0.4:
			break
		c._look_yaw = atan2(d.x, d.y)
		c.set_move_input(Vector2(0.0, 1.0))
		c.step(1.0 / 60.0)
		for dr in c._town_col.get("doors", []):
			for k in 2:
				widest = maxf(widest, absf((dr as Ep2SwingDoor).leaf_angle(k)))
	c.set_move_input(Vector2.ZERO)
	check("after the climb he still walks in through the batwings and they swing (%.0f deg)" % rad_to_deg(widest),
		L.call(c.get_player_position()).z < -1.5 and widest > deg_to_rad(25.0), str(L.call(c.get_player_position())))
	# ---- (h) a scripted beat that moves him while he is up there puts him on the ground; story beats keep [E]
	lad.state = "top"
	c._ground_y = Ep2GoldTown.BALCONY_Y
	c._player_pos = Ep2GoldTown.DROP_POINT + Vector3(0.0, Ep2GoldTown.BALCONY_Y, 0.0)
	c.step(1.0 / 60.0)
	check("moved off the balcony by a beat: on the ground, no climb state left", lad.state == "ground" and c.get_player_position().y < 0.01 and absf(c._ground_y) < 0.01)
	c._player_pos = lad.foot_world()
	c._show_active = true
	check("during a scripted show [E] at the foot does not climb", not c._ladder_allowed() and c._ladder_prompt_text() == "")
	c._show_active = false
	_done()


func _done() -> void:
	print("SALOON_LADDER: %d checks, %d failed" % [checks, failures])
	print("EP2_SALOON_LADDER: %s" % ("ALL PASS" if failures == 0 else "FAILED"))
	get_tree().quit(1 if failures > 0 else 0)
