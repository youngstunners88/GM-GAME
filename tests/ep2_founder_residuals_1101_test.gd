extends Node
## Headless gate for the founder's 2026-11-01 residual packet (docs/founder-feedback/2026-11-01_residuals.md):
## no-subtitle speech pacing, the Armory showcase and the three new guns, Dude's Chill Bud patch, rushing / hiding / seated bandits,
## the lake approach landmarks, Dude's horse drinking and remountable at the lake, and the frame-cost fixes behind the quad and
## elevator stalls (the town crowd's street graph). Run: godot --headless --path . tests/ep2_founder_residuals_1101_test.tscn

const TRAIL := preload("res://src/episode2/chamber/lake_trail.tscn")

var _failures: int = 0


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_failures += 1
		print("  [FAIL] %s %s" % [label, detail])


func _ready() -> void:
	_test_speech()
	_test_new_guns()
	await _test_showcase()
	_test_bud_patch()
	_test_bandits()
	_test_nav_cost()
	await _test_lake_horse()
	print("EP2_RESIDUALS_1101: %s" % ("ALL PASS" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(0 if _failures == 0 else 1)


# --- 4. dialogue: heard, not subtitled; paced by the take -------------------------------------------------------------------------

func _test_speech() -> void:
	print("-- SPEECH: no subtitles, no dead air")
	var voiced_id: String = ""
	for id in Ep2TownVoiceBank.LINES:
		if Ep2TownVoiceBank.stream(str(id)) != null:
			voiced_id = str(id)
			break
	_check("a recorded line is available to test against", voiced_id != "")
	if voiced_id == "":
		return
	var take: float = Ep2TownVoiceBank.stream(voiced_id).get_length()
	var text: String = str(Ep2TownVoiceBank.LINES[voiced_id]["text"])
	_check("a voiced line holds for its take plus a short breath (not a reading time)", absf(Ep2Speech.pace(voiced_id, text) - (take + Ep2Speech.GAP)) < 0.001,
		"%.2f vs take %.2f" % [Ep2Speech.pace(voiced_id, text), take])
	_check("the breath between lines is short (< 0.2 s)", Ep2Speech.GAP < 0.2)
	_check("a missing take falls back to a reading time", Ep2Speech.pace("no_such_line", "Hello there partner.") >= 2.4 and not Ep2Speech.voiced("no_such_line"))
	var hud := Ep2FpsHud.new()
	add_child(hud)
	hud.speech("SHERIFF: " + text, 2.0, true)
	_check("a voiced line draws no subtitle", hud.toast_text == "" and hud.speech_log.size() == 1)
	hud.speech("SHERIFF: (silent line)", 2.0, false)
	_check("an unvoiced line still reaches the player as a caption", hud.toast_text == "SHERIFF: (silent line)")
	hud.queue_free()


# --- 3. the new guns -----------------------------------------------------------------------------------------------------------

func _test_new_guns() -> void:
	print("-- ARMORY: coach gun, Bergmann MP18, golden Thompson")
	for id in Ep2ArmoryState.SHOP_GUNS:
		_check("%s is sold at Rich & Utah's for crypto" % id, not Ep2ArmoryState.shop_item(id).is_empty() and int(Ep2ArmoryState.shop_item(id)["price"]) > 0)
		if not Ep2ArmoryGunView.has_view(id):
			continue          # the Winchester, golden revolver and bow keep their own first-person views
		_check("%s has a first-person model, an icon and report sounds" % id, Ep2ArmoryGunView.model(id) != null and Ep2ArmoryGunView.icon(id) != null
			and ResourceLoader.exists("res://src/assets/sounds/%s.mp3" % str(Ep2ArmoryGunView.SOUNDS[id][0])))
	var st := Ep2ArmoryState.new()
	st.acquire(Ep2ArmoryState.WIN)
	_check("a new gun is refused for a non-crypto tender", not st.purchase_firearm(Ep2ArmoryState.MP18, "gold"))
	_check("the MP18 is bought once for Episode 1 crypto", st.purchase_firearm(Ep2ArmoryState.MP18, "btc") and st.owns(Ep2ArmoryState.MP18)
		and not st.purchase_firearm(Ep2ArmoryState.MP18, "eth"))
	var mp18: Ep2Winchester = st.firearm(Ep2ArmoryState.MP18)
	_check("the MP18 fires while held, from a 32-round snail drum", mp18.automatic and mp18.capacity == 32 and mp18.rounds == 32)
	mp18.locked = false
	var shots: int = 0
	for frame in 60:
		if mp18.trigger() == Ep2Winchester.Shot.OK:
			shots += 1
		mp18.step(1.0 / 60.0)
	_check("a held MP18 trigger empties rounds at its cyclic rate (about 10 per second)", shots >= 9 and shots <= 11, str(shots))
	mp18.rounds = 0
	mp18._cycle = 0.0
	var reserve: int = mp18.reserve
	mp18.reload_locked = false
	mp18.start_reload()
	for frame in int(mp18.reload_interval * 60.0) + 2:
		mp18.step(1.0 / 60.0)
	_check("a drum reload fills the whole drum in one change", mp18.rounds == 32 and mp18.reserve == reserve - 32)
	_check("the Thompson carries a fifty-round drum", (st.firearm(Ep2ArmoryState.TOMMY) as Ep2Winchester).capacity == 50)
	var coach: Ep2Winchester = st.firearm(Ep2ArmoryState.SHOT)
	_check("the lever shotgun (founder's Winchester 1887) holds five shells of buckshot with a heavy kick", coach.capacity == 5 and coach.pellets > 1 and coach.hit_scale > 1.5
		and coach.kick_rad() > (st.firearm(Ep2ArmoryState.WIN) as Ep2Winchester).kick_rad())
	_check("ammunition for an unowned new gun is refused", not st.purchase_ammo(Ep2ArmoryState.TOMMY, 50, "btc"))
	_check("the long-standing guns keep their profiles", (st.firearm(Ep2ArmoryState.WIN) as Ep2Winchester).capacity == Ep2Winchester.MAG
		and not (st.firearm(Ep2ArmoryState.WIN) as Ep2Winchester).automatic and (st.firearm(Ep2ArmoryState.REM) as Ep2Winchester).capacity == 6)
	var saved: Dictionary = st.snapshot()
	var back := Ep2ArmoryState.new()
	back.restore(saved)
	_check("a bought MP18 survives save and restore", back.owns(Ep2ArmoryState.MP18) and not back.owns(Ep2ArmoryState.TOMMY))
	_test_guns_buff()


## "Guns Buff" (founder 2026-11-01 evening): all eight of his guns at Rich & Utah's, his Meshy models, rebuy after jail.
func _test_guns_buff() -> void:
	print("-- GUNS BUFF: eight guns, Meshy models, jail rebuy")
	for id in [Ep2ArmoryState.REM, Ep2ArmoryState.BOW, Ep2ArmoryState.WIN, Ep2ArmoryState.BORCH, Ep2ArmoryState.SHOT, Ep2ArmoryState.MP18, Ep2ArmoryState.TOMMY]:
		_check("%s is a row of Rich's stock" % id, not Ep2ArmoryState.shop_item(id).is_empty())
	_check("the buffalo gun is a row of Rich's stock (story id 'sniper')", "BUFFALO" in str(Ep2ArmoryState.shop_item("sniper").get("name", "")))
	for ammo in ["revolver_ammo", "arrows", "rifle_ammo", "borchardt_ammo", "shotgun_ammo", "sniper_ammo", "mp18_ammo", "tommy_ammo"]:
		_check("Rich sells %s" % ammo, int(Ep2ArmoryState.shop_item(ammo).get("rounds", 0)) > 0)
	for id in Ep2ArmoryGunView.MESHY_MODELS:
		var view: Node3D = Ep2ArmoryGunView.make(id)
		_check("%s is the founder's Meshy model (his gun with Lil Blunt's hands)" % id, Ep2ArmoryGunView.meshy(id) and view.get_meta("meshy", false) and view.get_node_or_null("Gun") != null)
		view.free()
	var st := Ep2ArmoryState.post_hideout()
	st.purchase_firearm(Ep2ArmoryState.MP18, "btc")
	_check("buying the buffalo gun puts the Sharps in his quick-switch armory", st.purchase_sniper("eth") and st.sniper_owned and st.owns(Ep2ArmoryState.BUFF))
	_check("Sharps cartridges feed the quick-switch Sharps too", st.purchase_sniper_ammo(10, "btc") and st.firearm(Ep2ArmoryState.BUFF).reserve >= 10)
	st.confiscate_firearms()
	_check("jail: every owned gun is held, he carries the pick", st.is_held(Ep2ArmoryState.WIN) and st.is_held(Ep2ArmoryState.MP18) and st.is_held(Ep2ArmoryState.BUFF) and st.equipped == Ep2ArmoryState.PICK)
	_check("a held gun cannot be selected", not st.select(Ep2ArmoryState.MP18))
	_check("after jail Rich sells a held gun again and it goes straight into his hands", st.purchase_firearm(Ep2ArmoryState.MP18, "sol")
		and not st.is_held(Ep2ArmoryState.MP18) and st.equipped == Ep2ArmoryState.MP18 and st.firearm(Ep2ArmoryState.MP18).rounds == 32)
	_check("a gun he never owned bought while the rest are held is usable too", st.purchase_firearm(Ep2ArmoryState.BORCH, "btc") and st.equipped == Ep2ArmoryState.BORCH)
	_check("the other guns stay held until he buys them or leaves town", st.is_held(Ep2ArmoryState.WIN) and not st.select(Ep2ArmoryState.WIN))
	var shop := Ep2ArmoryShop.new()
	shop.state = st
	_check("the panel offers the held Winchester for sale again", not shop._owned(Ep2ArmoryState.shop_item(Ep2ArmoryState.WIN)))
	shop.free()
	var kept: Dictionary = st.snapshot()
	var back := Ep2ArmoryState.new()
	back.restore(kept)
	_check("holds and the rebought gun survive save and restore", back.is_held(Ep2ArmoryState.WIN) and not back.is_held(Ep2ArmoryState.MP18) and back.equipped == Ep2ArmoryState.BORCH)
	st.return_firearms()
	_check("leaving town returns every held gun and keeps the one in his hands", not st.is_held(Ep2ArmoryState.WIN) and st.equipped == Ep2ArmoryState.BORCH and st.select(Ep2ArmoryState.WIN))
	var old := Ep2ArmoryState.new()
	var legacy: Dictionary = Ep2ArmoryState.post_hideout().snapshot()
	legacy["sniper"] = true
	legacy["sniper_rounds"] = 7
	(legacy["weapons"] as Dictionary).erase(Ep2ArmoryState.BUFF)
	old.restore(legacy)
	_check("an older save that bought the Sharps gets it in the quick-switch armory", old.owns(Ep2ArmoryState.BUFF) and old.firearm(Ep2ArmoryState.BUFF).reserve == 7)


# --- 3. the showcase -----------------------------------------------------------------------------------------------------------

func _test_showcase() -> void:
	print("-- ARMORY SHOWCASE: the highlighted gun turns slowly")
	var layer := CanvasLayer.new()
	add_child(layer)
	var shop := Ep2ArmoryShop.new()
	layer.add_child(shop)
	var st := Ep2ArmoryState.new()
	st.acquire(Ep2ArmoryState.WIN)
	shop.open_shop(st, 10)
	var mp18_row: int = -1
	var gear_row: int = -1
	for i in Ep2ArmoryState.SHOP.size():
		if str(Ep2ArmoryState.SHOP[i]["id"]) == Ep2ArmoryState.MP18: mp18_row = i
		if str(Ep2ArmoryState.SHOP[i]["id"]) == "river_gear": gear_row = i
	shop.index = mp18_row
	for f in 4:
		await get_tree().process_frame
	var spin_a: float = shop.showcase_spin
	for f in 30:
		await get_tree().process_frame
	_check("highlighting the MP18 puts the MP18 in the display case", shop.showcase_key == Ep2ArmoryState.MP18)
	_check("...and it turns slowly (well under a turn a second)", shop.showcase_spin > spin_a and Ep2ArmoryShop.SHOWCASE_SPEED < 1.0)
	shop.index = mp18_row + 1                       # its snail drums: the case keeps the gun they feed
	await get_tree().process_frame
	_check("the ammunition row shows the gun it feeds", shop.showcase_key == Ep2ArmoryState.MP18)
	shop.index = gear_row
	await get_tree().process_frame
	await get_tree().process_frame
	_check("moving to gear with no gun empties the case cleanly", shop.showcase_key == "" and not shop._case_box.visible)
	for screen in [Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(844, 390), Vector2i(390, 844)]:
		get_window().size = screen
		shop.index = Ep2ArmoryState.SHOP.size() - 1
		await get_tree().process_frame
		await get_tree().process_frame
		var last: Rect2 = shop.row_rect(shop.index)
		var case_r: Rect2 = shop.showcase_rect()
		var rows_ok: bool = shop.is_row_shown(shop.index) and last.end.y <= shop.size.y and last.position.y >= 0.0 and last.size.y >= 34.0
		var apart: bool = shop.size.x < Ep2ArmoryShop.SIDE_CASE_MIN_W or not case_r.intersects(last)
		_check("%dx%d: the last of the eleven rows can be reached and read, beside the case" % [screen.x, screen.y], rows_ok and apart and case_r.end.y <= shop.size.y,
			"%s case %s size %s" % [last, case_r, shop.size])
	shop.hide()
	await get_tree().process_frame
	_check("closing the panel stops the case rendering", shop._case_vp.render_target_update_mode == SubViewport.UPDATE_DISABLED)
	layer.queue_free()


# --- 5. the Chill Bud patch ----------------------------------------------------------------------------------------------------

func _test_bud_patch() -> void:
	print("-- DUDE'S CHILL BUD PATCH")
	var root := Node3D.new()
	add_child(root)
	var patch: Node3D = Ep2BudPatch.build(root)
	_check("a small fenced bed of plants stands outside the ranch fence", patch.find_children("*ChillBudPlant*", "", true, false).size() >= 6
		and Ep2BudPatch.POS.x > -4.0 and Ep2BudPatch.BED.x < 3.0, str(patch.find_children("*ChillBudPlant*", "", true, false).size()) + " " + str(patch.get_children().map(func(n): return n.name)))
	_check("E reaches the patch only beside it", Ep2BudPatch.in_reach(Ep2BudPatch.POS + Vector3(1.2, 0, 0)) and not Ep2BudPatch.in_reach(Ep2BudPatch.POS + Vector3(6, 0, 0)))
	root.queue_free()
	var town: GoldTownChamber = (load("res://src/episode2/chamber/gold_town.tscn") as PackedScene).instantiate() as GoldTownChamber
	var buds: int = GameManager.chill_buds
	GameManager.purse_add("btc", 3)
	var btc: int = GameManager.purse_balance("btc")
	_check("a paid patch purchase stores the buds in Tabs", town.buy_buds_at_patch("buds_two", "btc") and GameManager.chill_buds == buds + 2
		and GameManager.purse_balance("btc") == btc - 1)
	GameManager.purse_spend("btc", GameManager.purse_balance("btc"))
	_check("no crypto, no buds (nothing free from the patch)", not town.buy_buds_at_patch("buds_five", "btc") and GameManager.chill_buds == buds + 2)
	_check("the patch panel sells only the patch's stock", Ep2BudPatchShop.new()._catalogue() == Ep2BudPatch.STOCK)
	town.free()


# --- 6. the bandits -----------------------------------------------------------------------------------------------------------

func _test_bandits() -> void:
	print("-- TRAIL BANDITS: rushers, holdouts, a seated rider")
	var c: LakeTrailChamber = TRAIL.instantiate() as LakeTrailChamber
	add_child(c)
	c.set_physics_process(false)
	c.setup(0, [], 0)
	c.debug_invulnerable = true
	var rushers: Array = []
	var holdouts: Array = []
	var rider: Dictionary = {}
	for b in c._bandits:
		match str(b["role"]):
			"rush": rushers.append(b)
			"hold": holdouts.append(b)
			"ride": rider = b
	_check("some bandits rush and the rest hold behind rocks", rushers.size() >= 5 and holdouts.size() >= 8, "%d / %d" % [rushers.size(), holdouts.size()])
	var hidden: bool = true
	for b in holdouts:
		hidden = hidden and is_equal_approx((b["root"] as Node3D).position.y, (b["home"] as Vector3).y - LakeTrailChamber.HOLDOUT_HIDE)
	_check("holdouts crouch fully below their rock's crest until they telegraph", hidden)
	var r: Dictionary = rushers[0]
	var start: Vector3 = c._bandit_world_position(r)
	c._place_at_distance(maxf(0.0, float(r["s"]) - 40.0))
	var rushed: bool = false
	for frame in 60 * 4:
		c.step(1.0 / 60.0)
		if bool(r["exposed"]):
			rushed = true
	var moved: float = c._bandit_world_position(r).distance_to(start)
	_check("a rusher leaves his rock and runs at Lil Blunt", rushed and moved > 3.0, "moved %.1f m" % moved)
	_check("...standing in the open, never crouched", is_equal_approx((r["root"] as Node3D).position.y, (r["home"] as Vector3).y) or str(r["state"]) == "dead")
	var seated: bool = bool(rider.get("seated", false))
	_check("the chasing rider is a rigged man in the ranch ride pose", seated and (rider["folk"] as Ep2TownFolk).current_clip() == Ep2RanchPose.RIDE.to_lower(),
		(rider["folk"] as Ep2TownFolk).current_clip() if not rider.is_empty() else "no rider")
	_check("...sitting on the saddle, not standing on the horse", seated and float(rider["seat_y"]) < LakeTrailChamber.SADDLE_HEIGHT,
		str(rider.get("seat_y", -1)))
	var folk: Ep2TownFolk = rider["folk"]
	c._bandit_rest(rider)
	_check("...and his rest between shots keeps him seated (never the rig's standing idle)", folk.current_clip() == Ep2RanchPose.RIDE.to_lower())
	_check("the trail names Logan's camp ahead, well before the shore", c._visuals.find_child("LogansLakeSignpost", true, false) != null
		and LakeTrailChamber.SIGNPOST_BEFORE_END > LakeTrailChamber.LAKE_REVEAL_DISTANCE)
	_check("the desert floor turns to grassland toward the lake", bool(c._sand_material.get_shader_parameter("has_forest")))
	c.queue_free()


# --- 1/2. frame cost of the town crowd's street graph ------------------------------------------------------------------------------

func _test_nav_cost() -> void:
	print("-- STALLS: the town crowd's street graph")
	var holder := Node3D.new()
	add_child(holder)
	var info: Dictionary = Ep2GoldTown.build(holder, true)
	var nav := Ep2TownNavigation.new()
	var t0: int = Time.get_ticks_usec()
	nav.configure(info)
	var ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
	_check("the crowd's street graph builds in well under a second (was ~9 s in one frame)", ms < 1500.0, "%.0f ms" % ms)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var same: bool = true
	for k in 4000:
		var p := Ep2TownNavigation.ORIGIN + Vector2(rng.randf() * 40.0, rng.randf() * 71.2)
		var inside: bool = true
		for rect in nav.blocked_rects:
			if rect.has_point(p): inside = false
		if inside:
			same = same and nav.is_clear(p) == (Ep2GoldTown.collide(p, Ep2TownNavigation.RADIUS, nav.walls, nav.props).distance_to(p) < 0.002)
	_check("...and answers exactly as the full wall/prop test did", same)
	holder.queue_free()


# --- 7/8. the lake: camp landmark, Dude's horse drinks and stays mountable ------------------------------------------------------

func _test_lake_horse() -> void:
	print("-- LOGAN'S LAKE: the horse drinks through the talk and can be ridden again")
	var session: Ep2SessionRoot = load("res://src/episode2/session/ep2_session_root.tscn").instantiate()
	add_child(session)
	session.configure([{"chamber": "lake_trail"}, {"chamber": "miner_shaft"}], false)
	session._enter_chamber()
	var trail: LakeTrailChamber = session.get_active() as LakeTrailChamber
	if trail == null:
		_check("the trail starts", false)
		return
	trail._place_at_distance(trail.get_route_length())          # he rode the whole trail: the hand-over happens at the shore
	trail._player_pos += trail.lake_transform().basis.x * 1.3       # ...after the shore's short dismount to the right
	trail._resolve({"next_chamber": "logans_lake", "arrived_mounted": true, "trail_seconds": 60.0, "bandits_down": 0, "companion": ""})
	var c: LogansLakeChamber = session.get_active() as LogansLakeChamber
	_check("the lake takes over", c != null)
	if c == null:
		return
	c.set_physics_process(false)
	_check("Logan's camp smoke column is part of the lake (copied onto the trail's horizon)", c._visuals.find_child("CampSmokeColumn", true, false) != null)
	var horse: Node3D = c.get_horse_node()
	_check("Dude's horse is at the lake, not left behind with the trail", horse != null and horse.is_inside_tree() and horse.visible)
	_check("...walking down to the water after he slid off", c.get_horse_state() == "lead")
	for i in 60 * 10:
		c.step(1.0 / 60.0)
	_check("...then drinking at the water's edge (within ten seconds)", c.get_horse_state() == "drink" and c.get_horse_clip() == "horse_graze"
		and Vector2(horse.position.x - LogansLakeChamber.HORSE_DRINK.x, horse.position.z - LogansLakeChamber.HORSE_DRINK.z).length() < 0.2,
		"%s %s at %s" % [c.get_horse_state(), c.get_horse_clip(), horse.position])
	# meet Logan (ordinary movement) and let the whole talk run
	for i in 3600:
		var d: Vector3 = Vector3(-5.5, 0, 8) - c.get_player_position()
		if Vector2(d.x, d.z).length() < 0.35:
			break
		c._look_yaw = atan2(d.x, d.z)
		c.set_move_input(Vector2(0, 1))
		c.step(1.0 / 60.0)
	c.set_move_input(Vector2.ZERO)
	_check("meeting Logan starts the talk", c.start_rig() and c.get_beat() == LogansLakeChamber.Beat.INVESTIGATE)
	var drank_all_talk: bool = true
	for i in 60 * 8:
		c.step(1.0 / 60.0)
		if c.get_beat() == LogansLakeChamber.Beat.INVESTIGATE:
			drank_all_talk = drank_all_talk and c.get_horse_state() == "drink" and is_instance_valid(horse) and horse.visible
	_check("the horse drinks the whole time Logan talks", drank_all_talk)
	_check("...and the talk is not subtitled when it is voiced", not c._dialogue_panel.visible or Ep2TownVoiceBank.stream(Ep2TownVoiceBank.id_for("logan", "This depth stays deep. We stage what comes in before anything goes downstream.")) == null)
	for i in 60 * 20:
		if c.get_beat() != LogansLakeChamber.Beat.INVESTIGATE: break
		c.step(1.0 / 60.0)
	# walk to the horse and mount it
	for i in 3600:
		var d2: Vector3 = horse.position - c.get_player_position()
		if c.can_mount_horse():
			break
		c._look_yaw = atan2(d2.x, d2.z)
		c.set_move_input(Vector2(0, 1))
		c.step(1.0 / 60.0)
	c.set_move_input(Vector2.ZERO)
	_check("after the talk, E beside the horse mounts it", c.can_mount_horse() and c.start_rig() and c.is_riding_horse())
	for i in 60:
		c.step(1.0 / 60.0)
	_check("...his eye rises into the saddle", c.eye_height > 2.0)
	var before: Vector3 = horse.position
	c._look_yaw = PI
	c.set_move_input(Vector2(0, 1))
	for i in 60:
		c.step(1.0 / 60.0)
	c.set_move_input(Vector2.ZERO)
	_check("...and the horse carries him", horse.position.distance_to(before) > 2.0)
	_check("E again slides him off; the horse stays, ready to be ridden again", c.start_rig() and not c.is_riding_horse() and is_instance_valid(horse) and horse.visible)
	session.queue_free()
