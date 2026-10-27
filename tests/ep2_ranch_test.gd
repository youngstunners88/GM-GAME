extends Node
## End-to-end ranch gate: real chamber input, both caption paths, purse/credit,
## rig attachments, three minutes of routines, layout and handoff continuity.
var failures := 0
var checks := 0


func check(label: String, ok: bool) -> void:
	checks += 1
	print("  [%s] %s" % ["PASS" if ok else "FAIL", label])
	if not ok: failures += 1


func _walk_to_dude(chamber: Ep2Interlude, yard: Ep2StableYard) -> bool:
	chamber._look_yaw = -PI * 0.5
	chamber._player_yaw = chamber._look_yaw
	chamber.set_move_input(Vector2(0, 1), true)
	var arrived: bool = false
	for i in 1800:
		chamber.step(1.0 / 60.0)
		if chamber._player_pos.distance_to(yard.actors[0].position) <= 2.55:
			arrived = true
			break
	chamber.set_move_input(Vector2.ZERO)
	chamber.step(1.0 / 60.0)
	return arrived and yard.can_talk(chamber._player_pos)


func _finish_conversation(chamber: Ep2Interlude, yard: Ep2StableYard) -> bool:
	for i in 1200:
		if not yard.conversation_active(): return true
		chamber.step(0.1)
	return not yard.conversation_active()


func _finish_yard_conversation(yard: Ep2StableYard, player: Vector3) -> bool:
	for i in 1200:
		if not yard.conversation_active(): return true
		yard.step(0.1, player)
	return not yard.conversation_active()


func _ready() -> void:
	await get_tree().process_frame
	GameManager.reset_session()
	var woods: WoodsQuadChamber = load("res://src/episode2/chamber/woods_quad.tscn").instantiate()
	woods.handoff = {"surface_player": Vector3(9, 0, 1221)}
	add_child(woods)
	woods.setup(0, [], 0)
	woods.set_physics_process(false)
	woods.debug_invulnerable = true
	var wy: Ep2StableYard = woods._stable_yard
	check("woods builds Dude's yard", wy != null and wy.actors.size() == 2)
	var wood_captions: Array = []
	var wood_voices: Array = []
	woods.stable_captioned.connect(func(who, text): wood_captions.append([who, text]))
	woods.stable_voice_requested.connect(func(id, voice): wood_voices.append([id, voice]))
	check("woods: movement input crosses road and east gate to Dude", _walk_to_dude(woods, wy))
	check("woods: Talk to Dude prompt appears", woods._stable_prompt_shown)
	check("woods: E starts the real conversation", woods.start_rig())
	check("woods: first caption is DUDE and requests his voice", wood_captions.size() > 0 and wood_captions[0][0] == "DUDE" and wood_voices.size() > 0 and wood_voices[0][1] == Ep2StableYard.DUDE_VOICE)
	check("woods: greeting completes", _finish_conversation(woods, wy))
	check("woods: free Chill Bud is granted once", GameManager.chill_buds == 1 and GameManager.dude_free_bud_claimed)
	var travelling: Dictionary = wy.snapshot()

	var town: GoldTownChamber = load("res://src/episode2/chamber/gold_town.tscn").instantiate()
	town.handoff = {"pos": Vector3(9, 0, 1221), "stable_yard": travelling}
	add_child(town)
	town.setup(0, [], 0)
	town.set_physics_process(false)
	var yard: Ep2StableYard = town._stable_yard
	check("woods-to-town snapshot keeps conversation state", yard.snapshot().get("greeted", false) and not yard.conversation_active())
	var town_captions: Array = []
	var town_voices: Array = []
	town.captioned.connect(func(who, text): town_captions.append([who, text]))
	town.stable_voice_requested.connect(func(id, voice): town_voices.append([id, voice]))
	check("town: movement input crosses road and east gate to Dude", _walk_to_dude(town, yard))
	check("town: Talk to Dude prompt appears", town._stable_prompt_shown)
	check("town: E starts a short follow-up, not the greeting", town.start_rig() and town_captions.size() > 0 and town_captions[0][0] == "DUDE" and town_captions[0][1] != Ep2StableYard.CONV_LINES["dude_ranch_01"][1])
	check("town: follow-up requests Dude's voice", town_voices.size() > 0 and town_voices[0][1] == Ep2StableYard.DUDE_VOICE)
	check("town: follow-up completes", _finish_conversation(town, yard))
	check("handoff never grants the welcome bud twice", GameManager.chill_buds == 1)
	GameManager.purse_add("btc", 5)
	check("town: repeatable bud offer starts", town.start_rig())
	check("town: bud sale completes", _finish_conversation(town, yard))
	check("two buds for exactly one BTC", GameManager.chill_buds == 3 and GameManager.purse_balance("btc") == 4)

	yard.set_referred(true)
	var sales: Array = []
	yard.horse_bought.connect(func(paid, credit): sales.append([paid, credit]))
	check("referred negotiation starts", town.start_rig())
	check("referred negotiation and Logan's Lake direction complete", _finish_conversation(town, yard))
	check("horse deal debits two BTC exactly once", sales == [[2, 0]] and GameManager.purse_balance("btc") == 2)
	var lake_said: bool = false
	for row in town_captions:
		if str(row[1]).contains("Logan's Lake"): lake_said = true
	check("Dude sends Lil Blunt to Logan's Lake first", lake_said and yard.snapshot().get("horse_deal_done", false))

	var mounted: bool = false
	var ridden: bool = false
	var dismounted: bool = false
	var moved_with_horse: bool = false
	var previous_horse: Vector3 = yard.horses[0].position
	var spectator := Vector3(4, 0, 1222)
	for i in 1800:
		yard.step(0.1, spectator)
		if yard._ride_state == "mount": mounted = true
		if yard._ride_state == "ride":
			ridden = true
			if yard.horses[0].position.distance_to(previous_horse) > 0.0001 and yard.actors[0].position.distance_to(yard._seat_position()) < 0.001:
				moved_with_horse = true
		if ridden and yard._ride_state == "": dismounted = true
		previous_horse = yard.horses[0].position
	check("three minutes: Dude mounts", mounted)
	check("three minutes: Dude rides the loop with the horse", ridden and moved_with_horse and yard._ride_distance > 5.0)
	check("three minutes: Dude dismounts where he mounted", dismounted)
	check("assistant brushes and carries hay", yard.brush_strokes > 0 and yard.hay_bales_moved > 0)
	check("eight horses and a wooden water trough", yard.horses.size() == 8 and yard.get_node_or_null("WaterTrough/TroughWater") != null)
	var tree_ok: bool = yard.ranch_trees.size() >= 20
	for tree in yard.ranch_trees:
		var p: Vector2 = tree["pos"]
		tree_ok = tree_ok and Vector2(Ep2StableYard.STABLE_POS.x, Ep2StableYard.STABLE_POS.z).distance_to(p) <= 45.0 and not Ep2StableYard.ACCESS_CLEAR.has_point(p)
	check("at least twenty woods-style ranch trees, none in gate approach", tree_ok)
	# Dude's own model wears rectangular black glasses (part of his mesh): the yard must not stack a procedural pair on them.
	check("Dude wears his own glasses - no second, procedural pair added", yard.actors[0].find_child("DudeGlasses", true, false) == null)

	GameManager.reset_session()
	var holder := Node3D.new()
	add_child(holder)
	var props: Array = []
	var walls: Array = []
	var credit_yard: Ep2StableYard = Ep2StableYard.build(holder, props, walls)
	credit_yard.set_referred(true)
	var credit_sales: Array = []
	var credit_lines: Array = []
	credit_yard.horse_bought.connect(func(paid, credit): credit_sales.append([paid, credit]))
	credit_yard.conversation_line.connect(func(who, text, _id, _voice): credit_lines.append(text))
	var visitor: Vector3 = credit_yard.actors[0].position + Vector3(2.0, 0, 0)
	check("short-purse negotiation starts", credit_yard.try_talk(visitor))
	check("short-purse negotiation completes", _finish_yard_conversation(credit_yard, visitor))
	check("short purse takes the horse on credit without a soft-lock", credit_sales == [[0, 2]] and GameManager.dude_credit_btc == 2 and credit_yard.snapshot().get("horse_deal_done", false))
	var credit_lake: bool = false
	for text in credit_lines:
		if str(text).contains("Logan's Lake"): credit_lake = true
	check("credit path also gives the Logan's Lake direction", credit_lake)
	print("EP2_RANCH: %s" % ("ALL PASS" if failures == 0 else "%d FAILURE(S)" % failures))
	get_tree().quit(failures)
