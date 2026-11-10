extends Node
## Headless gate for PROMPT_LAKE_HORSE_REPAIR_AUCTION_ROAD_2026-11-08: after Utah's dock the session returns to Logan's Lake with the horse
## already drinking, Logan's far-shore stock, the 0.5 BTC salve (short of coin = a line, not a lock), Dude's 1 BTC swap intact, and the short
## diagonal road to the auction (one claim beat, one vulture/dust spook, zero Hammersmen) that ends at the auction gate.
const LAKE := preload("res://src/episode2/chamber/logans_lake.tscn")
const ROAD := preload("res://src/episode2/chamber/auction_road.tscn")
var failures: int = 0
var checks: int = 0


func check(label: String, ok: bool, detail: String = "") -> void:
	checks += 1
	print("  [%s] %s %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		failures += 1


func _text(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func _lake(st: Ep2ArmoryState, after: bool) -> LogansLakeChamber:
	var c: LogansLakeChamber = LAKE.instantiate() as LogansLakeChamber
	c.handoff = {"after_day88": after}
	add_child(c)
	c.set_physics_process(false)
	c.bind_armory(st)
	c.setup(0, [], 0)
	return c


func _advance(c: Node, seconds: float) -> void:
	for i in int(seconds * 30.0):
		c.step(1.0 / 30.0)


func _ready() -> void:
	print("EP2_LAKE_AUCTION_ROAD")
	# 1. the river hands on to the lake, flagged, instead of ending the slice
	var river: String = _text("res://src/episode2/chamber/river_cover.gd")
	check("day-88 success hands on to Logan's Lake (after_day88), not end_session", "\"next_chamber\": \"logans_lake\", \"after_day88\": true" in river)
	check("the session knows the auction road", "\"auction_road\"" in _text("res://src/episode2/session/ep2_session_root.gd"))
	check("Save/Continue accepts the auction road", "\"auction_road\"]" in _text("res://src/autoload/game_manager.gd"))
	check("a post-day-88 lake save resumes post-day-88", "\"after_day88\": is_instance_valid(_active)" in _text("res://src/episode2/session/ep2_session_root.gd")
		and "_resume_handoff = {\"after_day88\": true}" in _text("res://src/episode2/session/ep2_session_root.gd"))
	# 2. horse at the water + stock
	GameManager.token_purse["btc"] = 0
	var st := Ep2ArmoryState.post_hideout()
	var lake := _lake(st, true)
	check("after day-88 the sound horse is at the lake drinking", lake.get_horse_state() == "drink" and lake.get_horse_node().visible, lake.get_horse_state())
	check("the lake opens on the ROAD beat", lake.get_beat_name() == "ROAD", lake.get_beat_name())
	check("3-4 extra horses stand on the far shore", lake.get_stock_count() >= 3 and lake.get_stock_count() <= 4, str(lake.get_stock_count()))
	var far: bool = true
	for h in lake._stock:
		far = far and h.position.x > 60.0
	check("the stock is across the water from Logan's landing (x > 60)", far)
	lake.queue_free()
	# 3. shot horse: short of coin = clear line; with a coin = salve -> rideable
	var hurt := Ep2ArmoryState.post_hideout()
	hurt.wound_horse()
	lake = _lake(hurt, true)
	check("a shot horse comes back to the lake and stands hurt", lake.get_horse_state() == "hurt", lake.get_horse_state())
	lake._player_pos = lake.get_horse_node().position + Vector3(-1.5, 0, 0)
	check("Logan's salve is offered beside the shot horse", lake._can_offer_salve())
	check("short of BTC: no salve, nothing debited, horse still hurt", not lake._buy_salve() and lake.get_horse_state() == "hurt" and GameManager.purse_balance("btc") == 0)
	check("short of BTC is never a lock: the road still says what to do", not lake._can_leave_for_auction())
	GameManager.token_purse["btc"] = 1
	check("with a coin the salve is bought", lake._buy_salve() and lake.salve_running())
	check("half a Bitcoin taken: one face spent, half banked as change", GameManager.purse_balance("btc") == 0 and hurt.btc_half_change)
	_advance(lake, 3.5)
	check("the salve restores the horse: sound and drinking", hurt.horse_is_sound() and lake.get_horse_state() == "drink", lake.get_horse_state())
	hurt.wound_horse()
	check("a second salve spends the banked half, no new face", hurt.pay_half_btc() and not hurt.btc_half_change and GameManager.purse_balance("btc") == 0)
	check("a lake save carries the banked half", Ep2ArmoryState.post_hideout() != null and "btc_half_change" in _text("res://src/episode2/chamber/ep2_armory_state.gd"))
	lake.queue_free()
	# 4./5. Dude path + message
	var town: String = _text("res://src/episode2/chamber/gold_town.gd")
	check("Dude's swap stays and costs 1 BTC (credit when short)", "const DUDE_SWAP_BTC := 1" in town and "record_dude_credit(DUDE_SWAP_BTC)" in town)
	var lake_src: String = _text("res://src/episode2/chamber/logans_lake.gd")
	check("'needs Dude, not water' is no longer the only recovery line", not "it needs Dude, not water" in lake_src and "half a Bitcoin" in lake_src)
	# 6./7. the road
	var road: AuctionRoadChamber = ROAD.instantiate() as AuctionRoadChamber
	road.handoff = {"road_mounted": true}
	add_child(road)
	road.set_physics_process(false)
	road.bind_armory(Ep2ArmoryState.post_hideout())
	road.setup(0, [], 0)
	var res: Array = []
	road.chamber_cleared.connect(func(r: Dictionary) -> void: res.append(r))
	check("the road starts mounted", road.is_mounted() and road.eye_height > 2.0)
	var road_src: String = _text("res://src/episode2/chamber/auction_road.gd")
	check("zero Hammersmen on the road", not "Hammersm" in road_src.replace("NO Hammersmen", "").replace("no Hammersmen", "") and not "bandit" in road_src.to_lower())
	road._player_pos = road.at(road.CLAIM_S - 10.0)
	_advance(road, 0.2)
	check("the claim wagon is reached (CLAIM beat)", road.get_beat_name() == "CLAIM", road.get_beat_name())
	road._player_pos = road.at(road.CLAIM_S - 5.0)
	check("the wagon holds the road until he talks", road.road_s(road._collide(road.at(road.CLAIM_S + 10.0))) <= road.CLAIM_S - 3.9)
	check("show papers starts the claim talk", road.start_rig())
	_advance(road, 4.3 * road.CLAIM_LINES.size() + 0.5)
	check("the claim talk ends and the road opens", road.claim_done() and road.get_beat_name() == "SPOOK", road.get_beat_name())
	road._player_pos = road.at(road.SPOOK_S - 20.0)
	_advance(road, 0.2)
	check("the vultures lift off the carcass and the horse bolts", road.spooked() and road.is_bolting())
	var s0: float = road.road_s(road._player_pos)
	_advance(road, 1.0)
	check("the bolt carries him on down the road", road.road_s(road._player_pos) > s0 + 8.0)
	_advance(road, 4.0)
	road._player_pos = road.at(road.ARRIVE_S + 0.5)
	_advance(road, 0.1)
	check("the gate is only a sign now: no hand-off, no load, the grounds go on in this room", res.is_empty() and road.get_beat_name() == "ARRIVE", str(res))
	# 8. the auction house (brief PROMPT_AUCTION_HOUSE_RENEGADE_JACK_HAMMER_2026-11-08), in the same room
	var house: Ep2AuctionHouse = road.house()
	check("the auction house is built inside the road room (CAD kit streamed)", house != null and house.built)
	check("the lake builds the road behind itself and holds the sign until it is ready", "prebuild_requested.emit(\"auction_road\")" in lake_src and "_can_leave_for_auction() and _handoff_ok()" in lake_src)
	check("the hand-over keeps the lake's gaze (no camera reset)", "_apply_handoff_gaze(ROAD_YAW" in road_src and not "_look_yaw = ROAD_YAW" in road_src)
	road._player_pos = road.at(road.DISMOUNT_S + 1.0)
	_advance(road, 1.2)
	check("at the hitching rail he gets down and walks on (eye at foot height)", road.is_hitched() and road.eye_height < 1.7, str(road.eye_height))
	_advance(road, 6.0)
	var spot: Vector3 = road.from_house(Ep2AuctionHouse.HITCH + Vector3(1.3, 0, 0))
	check("the horse walks to the rail and stands there", Vector2(road._horse.position.x - spot.x, road._horse.position.z - spot.z).length() < 0.3)
	var wall: Vector3 = road.to_house(road._collide(road.from_house(Vector3(-6.0, 0, 2.0))))
	check("the front wall beside the door is solid", absf(wall.z - 2.0) > 0.4, str(wall))
	var door: Vector3 = road.to_house(road._collide(road.from_house(Vector3(0.0, 0, 2.0))))
	check("the open double door lets him through", absf(door.x) < 0.01 and absf(door.z - 2.0) < 0.01, str(door))
	var stage: Vector3 = road.to_house(road._collide(road.from_house(Vector3(0.0, 0, 27.0))))
	check("the stage is solid (no walking through the block)", stage.z < house.STAGE_Z0 - 0.3, str(stage))
	var rail: Vector3 = road.to_house(road._collide(road.from_house(Vector3(-5.0, 0, house.RAIL_Z))))
	check("the brass rail is solid off the aisle", absf(rail.z - house.RAIL_Z) > 0.4, str(rail))
	var side: Vector3 = road.to_house(road._collide(road.from_house(Vector3(-10.6, 0, 21.0))))
	check("the side wall is solid from inside", side.x >= -10.46, str(side))
	check("Renegade (the Drive GLB) is the host on the block, with lent clips", house.renegade != null and house.renegade.has_clips()
		and house.renegade.position.y > 1.0 and absf(house.renegade.position.x) < 0.5)
	check("Jack Hammer can run (Dude's run lent to his rig)", house.jack.anim_player() != null and house.jack.anim_player().has_animation("lent/Run"))
	road._player_pos = road.from_house(Vector3(0.0, 0, 8.0))
	_advance(road, 0.2)
	check("inside the hall Renegade starts calling (HALL)", road.get_beat_name() == "HALL" and house.phase == "calls", road.get_beat_name())
	_advance(road, house.CALL_GAP * house.CALLS.size() + 2.0)
	check("Jack Hammer is recognised (JACK)", road.get_beat_name() == "JACK", road.get_beat_name())
	_advance(road, 3.9 * house.JACK_LINES.size() + 0.3)
	check("he flees (FLEE): running, the side door swings", road.get_beat_name() == "FLEE" and house.jack.is_walking(), road.get_beat_name())
	_advance(road, 14.0)
	check("he is gone and the auction carries on (AFTER), alive", road.get_beat_name() == "AFTER" and not house.jack.visible and not house.jack.dead, road.get_beat_name())
	check("no teleport, no hand-off while he was in the hall", res.is_empty())
	road._player_pos = road.from_house(Vector3(0.0, 0, -1.5))
	_advance(road, 0.2)
	check("out the front doors the slice ends cleanly", res.size() == 1 and bool(res[0].get("jack_fled", false)) and bool(res[0].get("end_session", false)), str(res))
	# a shot inside is pressure: Jack runs at once and is never killed here
	road.setup(0, [], 0)
	check("a retry puts Jack back at the claim board", house.phase == "" and house.jack.visible and house.jack.position.distance_to(house.JACK_MARK) < 0.2)
	var eye: Vector3 = house.jack.position + Vector3(0, 1.0, -4.0)
	check("a round at Jack sends him running, not down", house.shot(eye, Vector3(0, 0, 1)) and house.phase == "flee" and not house.jack.dead)
	road.queue_free()
	print("EP2_LAKE_AUCTION_ROAD: %d checks, %d FAIL" % [checks, failures])
	if failures == 0:
		print("ALL PASS")
	get_tree().quit(1 if failures > 0 else 0)
