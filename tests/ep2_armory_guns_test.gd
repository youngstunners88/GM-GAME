extends Node
## Founder 2026-10-20: "upgrade Rich and Utah ... they introduce Lil Blunt to the Sharps 1874 Buffalo Gun and the Colt Gatling Gun" - the Sharps is the
## long rifle Rich sells; the Colt Gatling is a mounted gun in the yard OUTSIDE the shop (never for sale) that Utah demonstrates and Lil Blunt may fire from the
## mount (skill ep2-armory-guns). Guards: both models and their parts; the shop sells the Sharps and never the Gatling; the post's arc, rounds (finite, one per
## round, never refilled), hits and plates; and the whole introduction played headless through the real chamber: Rich lifts the Sharps out of the case into his
## hand and names it, Utah takes him out to the post, demonstrates on the plates, offers the crank, he mounts, aims, fires and steps away, both men go back to
## work. Run: godot --headless res://tests/ep2_armory_guns_test.tscn
const TOWN := preload("res://src/episode2/chamber/gold_town.tscn")
var failures: int = 0


func check(label: String, ok: bool, detail: String = "") -> void:
	print("  [PASS] " if ok else "  [FAIL] ", label, "" if ok or detail.is_empty() else "  (" + detail + ")")
	if not ok:
		failures += 1


func _run(c: GoldTownChamber, seconds: float) -> void:
	for i in int(seconds * 60.0):
		c.step(1.0 / 60.0)


func _until(c: GoldTownChamber, seconds: float, cond: Callable) -> bool:
	for i in int(seconds * 60.0):
		if cond.call():
			return true
		c.step(1.0 / 60.0)
	return bool(cond.call())


func _ready() -> void:
	print("-- THE TWO HERO GUNS: assets")
	check("both guns are streamed extras (Sharps, Gatling post)", Ep2Extras.has(Ep2Extras.SHARPS) and Ep2Extras.has(Ep2Extras.GATLING))
	var sharps: Node3D = (load(Ep2Extras.SHARPS) as PackedScene).instantiate() as Node3D
	var bb: AABB = Ep2TownFolk._aabb(sharps)
	check("the Sharps is a real rifle: 1.1 - 1.3 m long, under 0.3 m tall (a 1874 sporting rifle is ~1.2 m)", bb.size.x > 1.1 and bb.size.x < 1.3 and bb.size.y < 0.3,
		str(bb.size))
	check("the Sharps muzzle points +x with the butt behind the origin (it sits in a hand and a case the same way)", bb.position.x < -0.25 and bb.position.x + bb.size.x > 0.7)
	sharps.free()
	var scene: Node3D = (load(Ep2Extras.GATLING) as PackedScene).instantiate() as Node3D
	var parts_ok: bool = true
	var missing: Array = []
	for n in ["Gatling_Post", "Gat_Yaw", "Gat_Pitch", "Gat_Barrels", "Gat_Crank", "Gat_Muzzle", "Gat_Eye", "Gat_Eject", "Gat_Sign", "Range_Plate", "Range_Swing", "Range_Bale"]:
		if scene.find_child(n, true, false) == null:
			parts_ok = false
			missing.append(n)
	check("the Gatling post has every moving part, its muzzle/eye/eject points and the yard's plate and bale", parts_ok, str(missing))
	var gb: Node3D = scene.find_child("Gat_Barrels", true, false) as Node3D
	var barrel_meshes: int = gb.find_children("*", "MeshInstance3D", true, false).size() if gb != null else 0
	check("the barrel cluster spins as its own piece (a mesh under Gat_Barrels)", barrel_meshes >= 1)
	scene.free()
	check("a missing Gatling file is no crash: the post reports it could not be built", not Ep2GatlingPost.new().build("res://src/episode2/extras/armory/none.glb", 0.0))

	print("-- THE SHOP: the Sharps is sold, the Gatling never")
	var sold: Dictionary = Ep2ArmoryState.shop_item("sniper")
	check("the long rifle in the Armory's stock IS the Sharps 1874 Buffalo Gun", "SHARPS 1874" in str(sold.get("name", "")) and "BUFFALO" in str(sold.get("name", "")), str(sold))
	var stock_text: String = ""
	for it in Ep2ArmoryState.SHOP:
		stock_text += (str(it["id"]) + " " + str(it["name"]) + " " + str(it["note"])).to_lower() + " "
	check("the Gatling is not in the Armory's stock under any name (it is a showpiece outside the shop)", not ("gatling" in stock_text or "colt" in stock_text))
	var st := Ep2ArmoryState.new()
	check("the personal armory still has its three slots only (no Gatling slot, no fourth gun)", Ep2ArmoryState.IDS.size() == 3 and not st.owns("gatling") and not st.purchase_firearm("gatling", "btc"))

	print("-- THE POST: arc, rounds, plates")
	var root := Node3D.new()
	add_child(root)
	var post := Ep2GatlingPost.new()
	root.add_child(post)
	post.position = Vector3(100.0, 0.0, 200.0)
	check("the post builds from the GLB with the bore at rest along a heading of -90 degrees", post.build(Ep2Extras.GATLING, -PI * 0.5))
	check("at rest the bore points west (-x)", post.bore_dir().distance_to(Vector3(-1, 0, 0)) < 0.01, str(post.bore_dir()))
	var far_left: Vector2 = Vector2(-2000.0, 0.0)
	post.aim_delta(far_left)
	check("the mouse cannot swing the bore outside its +-50 degree arc", absf(post.aim_yaw - post.heading) <= Ep2GatlingPost.ARC_YAW + 1e-4)
	post.aim_delta(Vector2(0.0, -4000.0))
	check("nor tip it past its elevation stop", post.aim_pitch <= Ep2GatlingPost.PITCH_MAX + 1e-4)
	post.set_aim(post.heading, 0.0)
	# plates in front of the muzzle: one dead ahead 14 m, one far off to the side
	var ahead: int = post.add_plate(post.position + Vector3(-14.0, 0.0, 0.0), post.position + Vector3(0.0, 1.2, 0.0))
	var aside: int = post.add_plate(post.position + Vector3(-12.0, 0.0, 9.0), post.position + Vector3(0.0, 1.2, 0.0))
	check("plates stand in the yard", ahead == 0 and aside == 1 and post.plate_count() == 2)
	var muzzle: Vector3 = post.muzzle_position()
	post.aim_toward(post.position + Vector3(-14.0, 1.22, 0.0), 1.0, 20.0)
	check("laid on a plate, the bore is within 3 degrees of it", post.aim_error(post.position + Vector3(-14.0, 1.22, 0.0)) < deg_to_rad(3.0), "%.3f rad" % post.aim_error(post.position + Vector3(-14.0, 1.22, 0.0)))
	var r0: int = post.rounds
	check("a burst needs rounds and a cranked barrel: nothing leaves on the first frame", post.fire_burst(1.0) and post.shots_fired == 0)
	for i in 60:
		post.step(1.0 / 60.0)
	check("then it fires about nine rounds a second, one round each, from the finite drum", post.shots_fired >= 6 and post.shots_fired <= 10 and post.rounds == r0 - post.shots_fired,
		"%d shots, %d rounds" % [post.shots_fired, post.rounds])
	check("the plate dead ahead rang (a pendulum kicked away) and the one off to the side did not", post.plates_rung == 1 and int(post.targets[ahead]["hits"]) >= 3 and int(post.targets[aside]["hits"]) == 0,
		"hits %d / %d" % [int(post.targets[ahead]["hits"]), int(post.targets[aside]["hits"])])
	var swing: float = float(post.targets[ahead]["ang"])
	check("the hit plate is swinging", absf(swing) > 0.02 or absf(float(post.targets[ahead]["vel"])) > 0.1)
	for i in 240:
		post.step(1.0 / 60.0)
	check("the barrels spin down and the rounds never come back (no refill, no free ammunition)", post.spin < 1.0 and post.rounds <= r0 - 6 and post.rounds <= Ep2GatlingPost.DRUM)
	var before_empty: int = post.rounds
	post.rounds = 3
	var emptied: Array = [false]
	post.emptied.connect(func(): emptied[0] = true)
	post.fire_burst(2.0)
	for i in 120:
		post.step(1.0 / 60.0)
	check("an empty drum stops the burst and the next one is refused", post.rounds == 0 and emptied[0] and not post.fire_burst(1.0), "%d" % post.rounds)
	check("the tracers, flash and casings are only effects (nothing is left lit)", post.spin < 1.0)
	root.queue_free()

	print("-- THE INTRODUCTION (headless, the real chamber)")
	var c: GoldTownChamber = TOWN.instantiate()
	add_child(c)
	c.setup(0, [], 0)
	await get_tree().process_frame
	check("the Armory drew the Gatling post and its yard (post, plates, bale) and the Sharps case", c.get_gatling() != null and c.get_gatling().plate_count() == Ep2GoldTown.GATLING_PLATES.size()
		and c._sharps_case != null)
	var intro: Ep2ArmoryIntro = c.get_intro()
	check("the introduction is built (Rich and Utah's brains, the post and the first plate as Utah's mark)", intro != null and intro.demo_target.y > 1.0)
	var counter: Vector3 = Ep2GoldTown.local_to_world("Bldg_Armory", GoldTownChamber.ARMORY_SPOT)
	c._player_pos = counter
	c._advance_to(GoldTownChamber.Beat.ARMORY)
	c._look_yaw = atan2(Ep2GoldTown.local_to_world("Bldg_Armory", Vector3(2.6, 1.0, -5.2)).x - counter.x, Ep2GoldTown.local_to_world("Bldg_Armory", Vector3(2.6, 1.0, -5.2)).z - counter.z)
	var greeting_seconds: float = 1.0
	for id in ["town_trade_00", "town_trade_01", "town_trade_02", "town_trade_03"]:
		greeting_seconds += Ep2TownVoiceBank.seconds(id) + 0.3
	_until(c, greeting_seconds + 2.0, func(): return intro.is_busy())
	check("walking up to the counter starts the introduction: Rich is called to the lit case, directed off his tasks", intro.is_busy() and c._rich_brain.directed)
	check("Rich cannot mount the Gatling before Utah offers it", not intro.mount_allowed() and not c._can_mount())
	_until(c, 40.0, func(): return intro.stage == Ep2ArmoryIntro.Stage.SHARPS_TALK)
	var rifle: Node3D = c.get_rich().held_prop("Sharps")
	check("Rich walked to the case and lifted the Sharps into his hand (a prop on his hand bone), and the case is empty", rifle != null and not c._sharps_case.visible, str(rifle))
	_until(c, 40.0, func(): return intro.stage == Ep2ArmoryIntro.Stage.SHARPS_BACK)
	var said: String = ""
	for ln in intro.shown_lines:
		said += str(ln[0]) + ": " + str(ln[1]) + "\n"
	check("they introduce it by name: Sharps, Model 1874, the Buffalo Gun, falling block, octagon barrel, set triggers, tang sight",
		"Sharps" in said and "1874" in said and "Buffalo Gun" in said and "Falling block" in said and "octagon" in said and "set trigger" in said.to_lower() and "tang sight" in said, said)
	check("Rich prices the iron in the shop's own coins and never offers it free", "Three coin" in said and not ("free" in said.to_lower().replace("not for", "")), said)
	check("Lil Blunt cannot leave with the rifle: he does not own it until he pays", not c.has_sniper())
	_until(c, 20.0, func(): return intro.stage == Ep2ArmoryIntro.Stage.GATLING_WALK)
	check("the rifle is locked back in the case and Rich returns to his work", c.get_rich().held_prop("Sharps") == null and c._sharps_case.visible)
	check("Utah says the Gatling is outside and takes the lead", intro.stage == Ep2ArmoryIntro.Stage.GATLING_WALK and c._utah_brain.directed)
	var door_out: bool = _until(c, 120.0, func(): return intro.stage == Ep2ArmoryIntro.Stage.GATLING_WAIT)
	var stand: Vector3 = c.get_gatling().stand_position()
	check("Utah walked out the door and across the yard to the Gatling post", door_out and c.get_utah().position.distance_to(stand) < 1.2, "%.2f m" % c.get_utah().position.distance_to(stand))
	check("the post is OUTSIDE the shop: well clear of the building's front plane", Ep2GoldTown.armory_spots.has("porch") and (Ep2GoldTown.GATLING_POST.z > 2.5 or absf(Ep2GoldTown.GATLING_POST.x) > 5.5))
	check("the Gatling is not in the Armory's stock (no [E] trade for it at the counter)", not c.buy("gatling", 1, "btc"))
	# Lil Blunt follows him out and watches the demonstration
	c._player_pos = stand + Vector3(2.0, 0.0, 0.0)
	_until(c, 40.0, func(): return intro.stage == Ep2ArmoryIntro.Stage.GATLING_DEMO)
	check("he comes up and Utah starts the demonstration", intro.stage == Ep2ArmoryIntro.Stage.GATLING_DEMO)
	_until(c, 40.0, func(): return intro.stage == Ep2ArmoryIntro.Stage.GATLING_OFFER)
	check("Utah laid the gun on the plates and cranked a burst (rounds left the drum, a plate rang)", c.get_gatling().shots_fired >= 8 and c.get_gatling().plates_rung >= 1,
		"%d shots, %d plates" % [c.get_gatling().shots_fired, c.get_gatling().plates_rung])
	said = ""
	for ln in intro.shown_lines:
		said += str(ln[0]) + ": " + str(ln[1]) + "\n"
	check("they name it: Colt Gatling Gun, six barrels, drum, crank, Doctor Gatling's patent; and it is not for sale", "colt gatling gun" in said.to_lower() and "six barrels" in said.to_lower() and "crank" in said
		and "doctor gatling" in said.to_lower() and "not for coin" in said.to_lower(), said)
	check("Utah offers him the crank and the mount is open", intro.mount_allowed())
	# --- mounted: his view and his mouse are the gun's; he cannot walk; the Winchester is out of the picture
	c._player_pos = stand + Vector3(0.6, 0.0, 0.0)
	var mounted_ok: bool = c.start_rig("eth")
	check("[E] near the post takes the crank", mounted_ok and c.is_mounted())
	var rounds0: int = c.get_gatling().rounds
	var shots0: int = c.get_gatling().shots_fired
	var pos0: Vector3 = c.get_player_position()
	c.set_move_input(Vector2(0.0, 1.0), true)
	_run(c, 1.0)
	c.set_move_input(Vector2.ZERO)
	check("at the crank he cannot walk off (his feet stay at the stand)", c.get_player_position().distance_to(pos0) < 0.05)
	var eye: Vector3 = c.get_gatling().eye_position()
	check("his eye is the gun's: the camera sits above the breech and looks down the bore", c.get_camera().position.distance_to(eye) < 0.05
		and (-c.get_camera().global_transform.basis.z).distance_to(c.get_gatling().bore_dir()) < 0.02)
	c.look(Vector2(-4000.0, 0.0))
	check("his mouse swings the gun inside its arc and the view follows", absf(c.get_gatling().aim_yaw - c.get_gatling().heading) <= Ep2GatlingPost.ARC_YAW + 1e-4)
	c.look(Vector2(4000.0, 0.0))
	c.get_gatling().set_aim(c.get_gatling().heading, 0.0)
	check("a click is a burst: the crank turns and rounds leave the drum, nothing else is spent", c.shoot() and c.mount_bursts() == 1)
	_run(c, 1.6)
	check("rounds were fired from the finite drum, one each", c.get_gatling().shots_fired > shots0 and rounds0 - c.get_gatling().rounds == c.get_gatling().shots_fired - shots0,
		"%d -> %d" % [rounds0, c.get_gatling().rounds])
	check("the Winchester is not fired while he is on the crank", c.get_ammo() == c.get_viewmodel().gun.rounds)
	check("the [E] prompt does not offer the trade while he is at the post", not c.is_shop_open())
	check("[E] steps him away from the post and his view is his own again", c.start_rig("eth") and not c.is_mounted())
	_until(c, 10.0, func(): return intro.is_done())
	check("Utah's closing line ends the introduction and he and Rich go back to their work", intro.is_done() and not c._utah_brain.directed and not c._rich_brain.directed, str(intro.stage))
	check("the objective goes back to the trade", "Trade with Rich" in str(c.get_hud().objective), str(c.get_hud().objective))
	c.queue_free()
	await get_tree().process_frame
	print("EP2_ARMORY_GUNS: ", "ALL PASS" if failures == 0 else "%d FAILED" % failures)
	get_tree().quit(1 if failures > 0 else 0)
