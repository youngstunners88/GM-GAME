extends Node
## FULL-AUDIT REGRESSIONS (PROMPT_EPISODE2_FULL_AUDIT_FIX_AND_SKILL_PACK_2026-11-17; skill ep2-revisit-route-integrity).
## Each section reproduces one audited defect through the production session / world-routes / room code - never a re-implementation.
##   A  back in town ON FOOT after the first ride out: [E] at Dude's rail froze the game (a resolved room nobody listened to)
##   B  back in town IN THE SADDLE: there was no route back to the lake trail at all
##   C  the horse left drinking at the lake still "carried" him through town (saddle height, riding pace, no horse)
##   E  a retry of the ride restored the armory of its first minute: gear bought on a later visit was wiped, the BTC stayed spent
##   D  the day-88 ridge without the Sharps could only end the run: the lake now turns him round while the way back is open
## Run: godot --headless res://tests/ep2_audit_1117_test.tscn
const DT := 1.0 / 30.0
var failed := 0
var checks := 0


func check(label: String, ok: bool, detail: String = "") -> void:
	checks += 1
	if not ok: failed += 1
	print(("[PASS] " if ok else "[FAIL] ") + label + ("" if ok or detail == "" else "  -> " + detail))


## A session with the town LEFT (its first ride out is done and it is parked) and the trail live at Dude's end, as the game has them
## the moment after "Mount horse".
func _session() -> Array:
	var session := Ep2SessionRoot.new()
	add_child(session)
	session.set_process(false)
	var town: GoldTownChamber = preload("res://src/episode2/chamber/gold_town.tscn").instantiate()
	session.add_child(town); town.setup(); town.set_physics_process(false)
	town._beat = town.Beat.DONE
	town._horse_bought = true
	town.eye_height = 2.18                 # what the mount at Dude's leaves behind
	session.world_routes.park(session, town)
	var trail: LakeTrailChamber = preload("res://src/episode2/chamber/lake_trail.tscn").instantiate()
	session.add_child(trail); trail.setup(); trail.set_physics_process(false)
	trail.adopt_departure(town, null)
	session._active = trail; session._mode = session.Mode.CHAMBER; session._chain_id = "lake_trail"
	session._plan = [{}]; session._segment = 0; session._chamber_segment = 0; session._chain_n = 5
	return [session, town, trail]


## Up the street past the trail's line: the production tick hands him to the town room.
func _into_town(session: Ep2SessionRoot, trail: LakeTrailChamber) -> bool:
	trail._in_departure_area = true
	trail._player_pos = Vector3(13, 0, Ep2WorldRoutes.TOWN_LINE_Z + 0.5)
	trail.set_move_input(Vector2(0, 1))
	session.world_routes.cooldown = 0.0
	session.world_routes.tick(session, DT)
	return session._active is GoldTownChamber


## Back down the street (facing -z), frame by frame, until the room changes or `seconds` pass.
func _ride_south(session: Ep2SessionRoot, town: GoldTownChamber, seconds: float) -> void:
	town._look_yaw = PI
	town.set_move_input(Vector2(0, 1), true)
	for i in int(seconds / DT):
		session._active.step(DT)
		session.world_routes.tick(session, DT)
		if session._active != town:
			return


func _ready() -> void:
	# --- A -----------------------------------------------------------------------------------------------------------------------
	var s: Array = _session()
	var session: Ep2SessionRoot = s[0]
	var town: GoldTownChamber = s[1]
	var trail: LakeTrailChamber = s[2]
	trail.set_return_mounted(false)                       # the horse stayed at the lake
	check("A the revisited town is entered on foot through the street", _into_town(session, trail) and not session.world_routes.mounted)
	check("A ...at his own eye height, not the saddle's", is_equal_approx(town.eye_height, Ep2Interlude.FPS_EYE_HEIGHT), str(town.eye_height))
	town._player_pos = GoldTownChamber.DEPART_HORSE + Vector3(1, 0, 1)
	check("A Dude's rail no longer offers the first-departure mount on a revisit", not town.can_mount_departure())
	town.start_rig()
	for i in 90: town.step(DT)
	check("A [E] at the rail never freezes the town", town._running and not town._resolved and town.has_player_control())
	town._player_pos = Vector3(0, 0, GoldTownChamber.DEPART_HORSE.z + Ep2WorldRoutes.TOWN_LINE_Z + 1.0)
	session.world_routes.cooldown = 0.0
	_ride_south(session, town, 6.0)
	check("A walking back down the street returns him to the lake trail", session._active == trail and trail.has_player_control(),
		"active=%s z=%.1f" % [session._active.name, session._active.get_player_position().z])
	check("A ...at Dude's end, on foot, where he actually stands", trail._in_departure_area and not trail.is_mounted()
		and absf(trail.get_player_position().z - (Ep2WorldRoutes.TOWN_LINE_Z - Ep2WorldRoutes.TOWN_LINE_BACK)) < 1.5, str(trail.get_player_position()))
	session.queue_free()
	await get_tree().process_frame

	# --- B -----------------------------------------------------------------------------------------------------------------------
	s = _session()
	session = s[0]; town = s[1]; trail = s[2]
	var horse: Node3D = trail.get_horse_node()
	var yaw_in: float = 0.4
	trail._look_yaw = yaw_in
	check("B the revisited town is entered in the saddle", trail.is_mounted() and _into_town(session, trail) and session.world_routes.mounted and town._mounted_transport)
	session.world_routes.tick(session, DT)
	check("B the horse is under him in the street", horse.get_parent() == town._visuals)
	check("B ...and Dude's rail does not offer a second horse", not town.can_mount_departure())
	session.world_routes.cooldown = 0.0
	_ride_south(session, town, 6.0)
	check("B riding back down the street returns him to the lake trail", session._active == trail and trail.has_player_control(),
		"active=%s z=%.1f" % [session._active.name, session._active.get_player_position().z])
	check("B the one horse is the trail's again, under him", horse.get_parent() == trail._visuals and trail.is_mounted() and not session.world_routes.mounted)
	check("B he keeps the way he was looking (the town and the trail share their axes)", absf(angle_difference(trail._look_yaw, PI)) < 0.01, str(trail._look_yaw))
	for i in 3: trail.step(DT)
	check("B the horse is drawn where he rides, not a town-width away", Vector2(horse.global_position.x - trail._camera.global_position.x,
		horse.global_position.z - trail._camera.global_position.z).length() < 2.0, str(horse.global_position))
	# --- E: what he bought on the visit survives a later retry of the ride --------------------------------------------------------
	check("E fixture: the ride's first snapshot holds no Sharps", not bool(trail._armory_snapshot.get("sniper", false)))
	trail.armory.sniper_owned = true                      # bought at Rich's counter while he was back in town
	trail.armory.sniper_rounds = 10
	session.world_routes.travel(session, "gold_town", GoldTownChamber.DEPART_HORSE + Vector3(13, 0, Ep2WorldRoutes.TOWN_LINE_Z + 1.0))
	session.world_routes.travel(session, "lake_trail", Vector3(13, 0, Ep2WorldRoutes.TOWN_LINE_Z - 3.0))
	trail._retry_trail()                                  # shot down by the bandits on the way back out
	check("E a retry of the ride keeps the gear bought since it began", trail.armory.sniper_owned and trail.armory.sniper_rounds == 10)
	# and round again: the hand-off works every time, not once
	check("B the same street can be ridden up again", _into_town(session, trail) and session.world_routes.mounted)
	session.queue_free()
	await get_tree().process_frame

	# --- C -----------------------------------------------------------------------------------------------------------------------
	s = _session()
	session = s[0]; town = s[1]; trail = s[2]
	var routes: Ep2WorldRoutes = session.world_routes
	routes.mounted = true                                 # what an earlier ridden leg (trail -> lake) left in the routes
	routes.horse = trail.get_horse_node()
	trail.set_return_mounted(false)                       # ...but he walked back: the horse is drinking at the lake
	check("C a walker enters town as a walker", _into_town(session, trail) and not routes.mounted and not town._mounted_transport)
	for i in 5:
		town.step(DT); routes.tick(session, DT)
	check("C ...no saddle height, no riding pace, no horse carried in", is_equal_approx(town.eye_height, Ep2Interlude.FPS_EYE_HEIGHT)
		and town.walk_speed < 4.0 and trail.get_horse_node().get_parent() == trail._visuals, "eye=%.2f pace=%.1f" % [town.eye_height, town.walk_speed])
	session.queue_free()
	await get_tree().process_frame

	# --- D -----------------------------------------------------------------------------------------------------------------------
	var lake: LogansLakeChamber = preload("res://src/episode2/chamber/logans_lake.tscn").instantiate()
	add_child(lake); lake.setup(); lake.set_physics_process(false)
	var cleared: Array = []
	lake.chamber_cleared.connect(func(r: Dictionary) -> void: cleared.append(r))
	lake.armory.river_gear = true
	lake.armory.mark_day88_outflow_started()
	lake.armory.sniper_owned = false
	lake._show_active = false; lake._show_blocks_control = false; lake._hold = 0.0; lake._talk_t = 0.0
	lake._beat = lake.Beat.OVERLOOK
	lake._staged = true
	lake._player_pos = Vector3(-8, 0, LogansLakeChamber.WALK_ON_Z + 0.2)
	for i in 30: lake.step(DT)
	check("D without the Sharps the lake does not send him up a ridge he cannot come back from", cleared.is_empty() and lake.has_player_control())
	check("D ...it says what is missing and where it is sold", "sharps" in lake._hud.objective.to_lower() and "rich" in lake._hud.objective.to_lower(), lake._hud.objective)
	check("D ...and never holds the next room's build against him", not lake.is_waiting_for_handoff())
	lake.armory.sniper_owned = true
	lake._player_pos = Vector3(-8, 0, LogansLakeChamber.WALK_ON_Z + 0.2)
	for i in 5: lake.step(DT)
	check("D with the Sharps the same step goes on to the day-88 ridge", cleared.size() == 1 and str(cleared[0].get("next_chamber", "")) == "river_cover", str(cleared))
	lake.queue_free()
	await get_tree().process_frame
	print("EP2_AUDIT_1117: ", checks, " checks, ", failed, " failed")
	print("EP2_AUDIT_1117: ALL PASS" if failed == 0 and checks == 22 else "EP2_AUDIT_1117: FAIL")
	get_tree().quit(failed)
