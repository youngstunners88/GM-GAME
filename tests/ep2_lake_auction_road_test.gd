extends Node
## Headless gate for PROMPT_LAKE_HORSE_REPAIR_AUCTION_ROAD_2026-11-08: after Utah's dock the session returns to Logan's Lake with the horse
## already drinking, Logan's far-shore stock, the 0.5 BTC salve (short of coin = a line, not a lock), Dude's 1 BTC swap intact, and the short
## diagonal road to the auction (one claim beat, one vulture/dust spook, zero Hammersmen) that ends at the auction gate.
const LAKE := preload("res://src/episode2/chamber/logans_lake.tscn")
const ROAD := preload("res://src/episode2/chamber/auction_road.tscn")
const ARM_CLEAR := 1.2        # hand clearance / shoulder width: 1.27-1.31 with the arm override, 1.01-1.14 pinned to his sides without it
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


## Renegade's Idle at 3 frames: [hand clearance / shoulder width, shoulder->hand span / rest arm length] per frame (worse side).
func _arm_report(folk: Ep2TownFolk) -> Array:
	var out: Array = []
	var ap: AnimationPlayer = folk.anim_player() if folk != null else null
	var rigs: Array = folk.model.find_children("*", "Skeleton3D", true, false) if folk != null and folk.model != null else []
	if ap == null or rigs.is_empty() or not ap.has_animation("Idle"):
		return out
	var sk: Skeleton3D = rigs[0]
	var pose := preload("res://src/episode2/actors/ep2_ranch_pose.gd")
	var hips: int = pose._find(sk, "Hips")
	var length: float = ap.get_animation("Idle").length
	ap.play("Idle")
	for frac in [0.1, 0.45, 0.8]:
		ap.seek(length * frac, true)
		sk.force_update_all_bone_transforms()
		var centre: Vector3 = sk.get_bone_global_pose(hips).origin
		var clear: float = 9.0
		var span: float = 9.0
		for side in ["Left", "Right"]:
			var a: int = pose._find(sk, side + "Arm")
			var f: int = pose._find(sk, side + "ForeArm")
			var h: int = pose._find(sk, side + "Hand")
			var shoulder: Vector3 = sk.get_bone_global_pose(a).origin
			var hand: Vector3 = sk.get_bone_global_pose(h).origin
			var arm_len: float = sk.get_bone_rest(f).origin.length() + sk.get_bone_rest(h).origin.length()
			span = minf(span, shoulder.distance_to(hand) / maxf(arm_len, 0.0001))
			# how far the hand is from the body's vertical axis, as a fraction of the shoulder's own distance (measured flat)
			var up: Vector3 = (sk.global_basis.inverse() * Vector3.UP).normalized()
			var hs: Vector3 = hand - centre
			var ss: Vector3 = shoulder - centre
			clear = minf(clear, (hs - up * hs.dot(up)).length() / maxf((ss - up * ss.dot(up)).length(), 0.0001))
		out.append([snappedf(clear, 0.01), snappedf(span, 0.01)])
	folk.hold_clip("Idle")
	return out


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
	# 2026-11-19: the fused cart model is authored ~1 m long and stood on the road as a toy under a floating sign
	var wagon_len: float = 0.0
	for mi in road._wagon.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = (road._wagon.global_transform.affine_inverse() * (mi as MeshInstance3D).global_transform) * (mi as MeshInstance3D).get_aabb()   # the wagon's own frame (the road is diagonal)
		wagon_len = maxf(wagon_len, maxf(box.size.x, box.size.z))
	check("the claim wagon is full size (a real cart across the road, not a toy)", wagon_len > 3.0 and wagon_len < 5.0, "%.2f m" % wagon_len)
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
	# 8b. visitor carriages parked outside (founder brief 2026-11-20): all four reference styles, grounded, horse-scaled, off the road
	var kinds := {}
	var grounded := true
	var off_road := true
	var heights := {}
	var floors: Array = []
	for rig in house.visitors:
		var k: String = str(rig.name).trim_prefix("Visitor_").rsplit("_", true, 1)[0]
		kinds[k] = true
		var lo := Vector3(INF, INF, INF)
		var hi := -lo
		for mi in (rig as Node3D).find_children("*", "MeshInstance3D", true, false):
			var xf: Transform3D = house.global_transform.affine_inverse() * (mi as MeshInstance3D).global_transform
			var bb: AABB = (mi as MeshInstance3D).get_aabb()
			for i in 8:
				var c: Vector3 = xf * bb.get_endpoint(i)
				lo = lo.min(c)
				hi = hi.max(c)
		grounded = grounded and lo.y < 0.02 and lo.y > -0.08      # never floating; a few cm into the dirt (decimation + vertex compression) is fine
		floors.append(snappedf(lo.y, 0.001))
		off_road = off_road and (lo.x > 4.8 or hi.x < -4.8)
		heights[k] = hi.y - lo.y
	check("five visitor rigs stand outside, all four reference styles", house.visitors.size() == 5 and kinds.size() == 4, str(kinds.keys()))
	check("every visitor rig's wheels and hooves are on the ground", grounded and not house.visitors.is_empty(), str(floors))
	check("the visitor rigs sit clear of the lamp-lit road into the hall", off_road and not house.visitors.is_empty())
	check("the working teams stand at horse height and the palace carriage towers over them",
		heights.size() == 4 and absf(float(heights["visitor_common_pair"]) - 2.25) < 0.2 and absf(float(heights["visitor_common_single"]) - 2.25) < 0.2
		and float(heights["visitor_royal_palace"]) > 7.0, str(heights))
	var road_clear := true
	for zi in range(-44, 0, 2):
		var on_road: Vector3 = house.collide(Vector3(0.0, 0, float(zi)))
		road_clear = road_clear and on_road.distance_to(Vector3(0.0, 0, float(zi))) < 0.01
	check("the road from the gate to the porch is never blocked", road_clear)
	var pushed: Vector3 = house.collide(Vector3(17.0, 0, -11.0))
	check("nobody walks through the palace carriage", Vector2(pushed.x - 17.0, pushed.z + 11.0).length() > 2.0, str(pushed))
	check("outside the hall the crowd bed is silent and the hall score is off", is_equal_approx(house.murmur_target(), house.MURMUR_OFF) and not road.hall_score_on())
	check("the lake builds the road behind itself and holds the sign until it is ready", "prebuild_requested.emit(\"auction_road\")" in lake_src and "_can_leave_for_auction() and not _resolved and has_player_control() and _handoff_ok()" in lake_src)
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
	# 8b. the auction cast brief (PROMPT_EPISODE2_AUCTION_CAST_TPOSE_CAD_ARMS_2026-11-16)
	var arms: Array = _arm_report(house.renegade)
	check("Renegade's Idle: both hands outside the torso at 3 sampled frames", arms.size() == 3 and arms.all(func(r): return r[0] >= ARM_CLEAR), str(arms))
	check("Renegade's Idle: shoulder-to-hand span not collapsed (>= 55% of the arm) at 3 frames", arms.size() == 3 and arms.all(func(r): return r[1] >= 0.55), str(arms))
	var coats: Dictionary = {}
	for h in house._tied:
		coats[Ep2HorseCoat.coat_of(h)] = true
	check("the horses tied at the rail wear at least two different coats", house._tied.size() >= 2 and coats.size() >= 2, str(coats.keys()))
	var house_src: String = _text("res://src/episode2/chamber/ep2_auction_house.gd")
	# founder 2026-11-17: one horse - the road horse wears the coat Lil Blunt picked at Dude's, and the hall never touches it
	check("the road horse wears the stable's coat; the auction never recolours it", not house._tied.has(road._horse) and house_src.count("Ep2HorseCoat.apply(") == 1
		and (road._horse.find_children("*", "MeshInstance3D", true, false).is_empty() or Ep2HorseCoat.coat_of(road._horse) == Ep2HorseCoat.ridden),
		Ep2HorseCoat.coat_of(road._horse))
	var clerk: Ep2TownFolk = road.find_child("ClaimClerk", true, false) as Ep2TownFolk
	check("checker A is the claim clerk when his model is in the pack (the old clerk until then)", clerk != null
		and ResourceLoader.exists(AuctionRoadChamber.clerk_model_path())
		and (AuctionRoadChamber.clerk_model_path() == Ep2Extras.CHECKER_A) == ResourceLoader.exists(Ep2Extras.CHECKER_A), AuctionRoadChamber.clerk_model_path())
	check("checker B is the hall doorman when his model is in the pack (the rancher until then)", house._doorman != null and house._doorman.has_clips()
		and (Ep2AuctionHouse.doorman_model() == Ep2Extras.CHECKER_B) == ResourceLoader.exists(Ep2Extras.CHECKER_B), Ep2AuctionHouse.doorman_model())
	check("the band is five, or not there at all (never a part-band or stand-in faces)",
		house._band.size() == (5 if Ep2AuctionHouse.band_ready() else 0), "%d players, ready=%s" % [house._band.size(), Ep2AuctionHouse.band_ready()])
	var band_ok: bool = str(Ep2AuctionHouse.BAND[0][0]) == Ep2Extras.BAND_LEAD and Ep2AuctionHouse.BAND.size() == 5
	for row in Ep2AuctionHouse.BAND:
		band_ok = band_ok and float(row[1]) < -3.0 and float(row[2]) < house.STAGE_Z0 and float(row[2]) > house.RAIL_Z
	check("the band's marks: the woman who sings leads, all five stage-left of the aisle, on the floor in front of the stage", band_ok)
	var aisle_ok: bool = true
	for zi in range(2, 24):
		var a: Vector3 = house.collide(Vector3(0, 0, float(zi)))
		aisle_ok = aisle_ok and absf(a.x) < 0.001 and absf(a.z - float(zi)) < 0.001
	check("the centre aisle is clear from the doors to the stage (z 2..23)", aisle_ok)
	var kit_ok: bool = true
	for piece in ["Auc_Sconce", "Auc_CheckDesk", "Auc_Fiddle", "Auc_FiddleBow", "Auc_Banjo", "Auc_Bass", "Auc_Harmonica"]:
		kit_ok = kit_ok and house._kit.find_child(piece, true, false) != null
	check("the CAD kit carries the interior pass and the band's period instruments", kit_ok)
	road._player_pos = road.from_house(Vector3(0.0, 0, 8.0))
	_advance(road, 0.2)
	check("inside the hall Renegade starts calling (HALL)", road.get_beat_name() == "HALL" and house.phase == "calls", road.get_beat_name())
	check("in the hall the crowd murmurs under the auctioneer, swelling on arrival (never above bed + swell)",
		house.murmur_target() > house.MURMUR_BED - 0.01 and house.murmur_target() <= house.MURMUR_BED + house.MURMUR_SWELL + 0.01, str(house.murmur_target()))
	# 2026-11-17 grand event: the GM logo over the block and on both walls, fire, and the flame jets erupt on the calls
	var grand_ok: bool = not ResourceLoader.exists(Ep2AuctionHouse.SPECTACLE) or (house.grand != null
		and house.grand.find_children("GMLogo*", "MeshInstance3D", true, false).size() == 3 and house.grand.jets_fired >= 1
		and house.grand.find_children("*", "CPUParticles3D", true, false).size() >= 2 + 4 + Ep2AuctionHouse.SCONCES.size())
	check("a grand event: three GM logo discs, two braziers, four flame jets that fired on the first call, a flame in every lantern", grand_ok,
		str(house.grand.jets_fired) if house.grand != null else "no grand layer")
	# the instrumentalists really play (founder 2026-11-17): both hands reach the instrument the body holds, every frame
	# the solved pose is only there right after the skeleton's modifiers ran: measure on its skeleton_updated signal
	# (the test fast-forwards the room between frames; give the players a few real frames to settle into the beat first)
	for i in 3:
		await get_tree().process_frame
	var probe: Dictionary = {"worst": 0.0, "seen": 0}
	var players: int = 0
	var hooks: Array = []
	for f in house._band:
		var play: Node = (f as Node).get_node_or_null("Plays")
		if play == null or str(play.kind) == "lead":
			continue
		players += 1
		var sk: Skeleton3D = play._sk
		var hook := func() -> void:
			probe["seen"] = int(probe["seen"]) + 1
			for arm in ["Left", "Right"]:
				var hand: Vector3 = sk.global_transform * sk.get_bone_global_pose(int(play._bones[arm + "Hand"])).origin
				probe["worst"] = maxf(float(probe["worst"]), hand.distance_to((play._ik[arm] as Ep2ArmIK).target_world))
		sk.skeleton_updated.connect(hook)
		hooks.append([sk, hook])
		check("...the %s's instrument is held by the body, not glued to a hand bone" % str(play.kind),
			play.instrument != null and play.instrument.get_parent() == f)
	for i in 6:
		await get_tree().process_frame
	for h in hooks:
		(h[0] as Skeleton3D).skeleton_updated.disconnect(h[1])
	if Ep2AuctionHouse.band_ready():
		check("four instrumentalists play with both hands on the instrument (every wrist within 6 cm of its grip; 4.5 measured in the hall)",
			players == 4 and int(probe["seen"]) >= 8 and float(probe["worst"]) < 0.06, "%d players, %d poses, worst %.3f m" % [players, int(probe["seen"]), float(probe["worst"])])
	# 2026-11-17: the seven Tripo auction people were exported facing +X, so the band played side-on to the room. Measured from the shoulders.
	var worst_turn: float = 0.0
	for f in house._band + ([house._doorman] if house._doorman != null else []):
		var sks: Array = (f as Ep2TownFolk).model.find_children("*", "Skeleton3D", true, false)
		if sks.is_empty():
			continue
		var sk: Skeleton3D = sks[0]
		var la: int = -1
		var ra: int = -1
		for b in sk.get_bone_count():
			if sk.get_bone_name(b).ends_with("LeftArm"): la = b
			if sk.get_bone_name(b).ends_with("RightArm"): ra = b
		if la < 0 or ra < 0:
			continue
		var across: Vector3 = sk.global_transform * sk.get_bone_global_pose(ra).origin - sk.global_transform * sk.get_bone_global_pose(la).origin
		across.y = 0.0
		var body_fwd: Vector3 = Vector3.UP.cross(across.normalized())
		worst_turn = maxf(worst_turn, rad_to_deg(body_fwd.angle_to((f as Node3D).global_basis.z.normalized())))
	check("every auction player and the doorman face the way they are turned (chest within 25 degrees)", worst_turn < 25.0, "%.0f deg" % worst_turn)
	check("the hall score plays inside the hall when it is in the pack (night bed only until then)",
		road.hall_score_on() == Ep2Extras.has(AuctionRoadChamber.HALL_SCORE), str(road.hall_score_on()))
	# the floor answers like people (founder 2026-11-14): no two on one frame as a chorus, a mix of answers, one cheer recording per cooldown
	var waits: Dictionary = {}
	var clips: Dictionary = {}
	for r in house.react_log:
		waits[snappedf(float(r[0]), 0.001)] = true
		clips[str(r[1])] = true
	check("the crowd's answers are spread in time, not frame-synced (%d people, %d different moments)" % [house.react_log.size(), waits.size()],
		house.react_log.size() >= 6 and waits.size() >= house.react_log.size() - 1, str(house.react_log))
	check("and mixed (cheer / clap / nod / look on), not strict alternating rows", clips.size() >= 2, str(clips.keys()))
	var first_cheers: int = house.cheers_played
	_advance(road, house.CALL_GAP * house.CALLS.size() + 2.0)
	check("three calls inside the cooldown strike the cheer recording once, not three times on top of itself", first_cheers == 1 and house.cheers_played <= 2
		and house.CALL_GAP < house.CHEER_COOLDOWN, "%d then %d" % [first_cheers, house.cheers_played])
	check("Jack Hammer is recognised (JACK)", road.get_beat_name() == "JACK", road.get_beat_name())
	_advance(road, 3.9 * house.JACK_LINES.size() + 0.3)
	check("he flees (FLEE): running, the side door swings", road.get_beat_name() == "FLEE" and house.jack.is_walking(), road.get_beat_name())
	check("the room hushes while Jack runs", is_equal_approx(house.murmur_target(), house.MURMUR_HUSH), str(house.murmur_target()))
	_advance(road, 14.0)
	check("he is gone and the auction carries on (AFTER), alive", road.get_beat_name() == "AFTER" and not house.jack.visible and not house.jack.dead, road.get_beat_name())
	check("no teleport, no hand-off while he was in the hall", res.is_empty())
	road._player_pos = road.from_house(Vector3(0.0, 0, -1.5))
	_advance(road, 0.2)
	check("out the front doors the slice ends cleanly", res.size() == 1 and bool(res[0].get("jack_fled", false)) and bool(res[0].get("end_session", false)), str(res))
	check("the hall score fades out when he leaves by the porch", not road.hall_score_on())
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
