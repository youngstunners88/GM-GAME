extends Node
## FIX document: exercise the session boundary that standalone town tests bypassed.
var checks := 0
var failed := 0

func check(label: String, ok: bool) -> void:
	checks += 1
	if not ok: failed += 1
	print("[PASS] " + label if ok else "[FAIL] " + label)

func _ready() -> void:
	var session := Ep2SessionRoot.new()
	add_child(session)
	session.set_process(false)
	var woods: WoodsQuadChamber = preload("res://src/episode2/chamber/woods_quad.tscn").instantiate()
	session.add_child(woods)
	woods.setup()
	woods.set_physics_process(false)
	session.world_routes.park(session, woods)
	var town: GoldTownChamber = preload("res://src/episode2/chamber/gold_town.tscn").instantiate()
	session.add_child(town)
	town.setup()
	town.set_physics_process(false)
	town._show_active = false
	town._show_blocks_control = false
	town._hold = 0.0
	town._stamped = true
	town._advance_to(town.Beat.STABLES)
	session._active = town
	session._mode = session.Mode.CHAMBER
	var yard: Ep2StableYard = town._stable_yard
	town._player_pos = Vector3(0, 0, 1352)
	town._look_yaw = PI
	town.set_move_input(Vector2(0, 1), true)
	for i in 1500:
		town.step(1.0 / 30.0)
		session.world_routes.tick(session, 1.0 / 30.0)
		if session._active != town or town._player_pos.z < 1231.0: break
	check("held movement physically reaches the ranch road", town._player_pos.z < 1231.0)
	check("walking from Mike Dean to stables retains the active town", session._active == town)
	check("the story-owned Dude retains the referral", session._active == town and yard._referred)
	check("referral objective never reverts to Mike Dean", session._active == town and town.get_beat_name() == "STABLES" and "dude" in town._hud.objective.to_lower())
	# The yard conversation must actually buy the horse and finish; no direct flag grant.
	if session._active == town:
		town.set_move_input(Vector2.ZERO)
		yard._ride_state = ""
		yard._quiet = false
		yard._talk_cd = 0.0
		town._player_pos = yard.actors[0].position + Vector3(0, 0, 1)
		check("Dude accepts the real referred conversation", town.start_rig(""))
		for i in 7200:
			town.step(1.0 / 60.0)
			if town.horse_bought() and not yard.conversation_active(): break
		check("Dude's actual conversation grants one horse", town.horse_bought() and yard._horse_deal_done)
		town.armory.sniper_owned = true
		town.armory.river_gear = true
		town._after_story()
		town._player_pos = town.DEPART_HORSE + Vector3(1.5, 0, 0)
		check("horse is mountable at the same stables", town.can_mount_departure())
		check("interact starts the explicit mount", town.start_rig(""))
		check("mount stays in town until saddle transition", town._depart_mounted and session._active == town)
	# Revisit an unfinished beat without granting GEARED or losing the objective.
	if session._active != town:
		session.world_routes.travel(session, "gold_town", Vector3(0, 0, 1400))
	town._depart_mounted = false
	town._advance_to(town.Beat.STABLES)
	var objective: String = town._hud.objective
	session.world_routes.park(session, town)
	var active_woods: Node = session.world_routes.rooms.woods_quad.node
	active_woods.reparent(session)
	session.world_routes.rooms.erase("woods_quad")
	session._active = active_woods
	check("unfinished town can be returned to", session.world_routes.travel(session, "gold_town", Vector3(0, 0, 1400)))
	check("return preserves STABLES instead of forcing GEARED", town.get_beat_name() == "STABLES")
	check("return preserves the current objective", town._hud.objective == objective)
	session.queue_free()
	await get_tree().process_frame
	print("EP2_FIX_DOCUMENT: %d checks, %d failed" % [checks, failed])
	get_tree().quit(failed)
