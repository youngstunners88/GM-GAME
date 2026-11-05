extends Node
## Founder 2026-11-05: the Borchardt "far too small" beside the Golden Remington; the Sharps "blocks the view" shouldered. Guards the fix: the pistol is real size in its file and held by the
## Remington's own hand at the Remington's first-person size, and the Sharps wears a period telescopic sight whose one aiming rule (Ep2ArmoryState.aimed_fov) every first-person room reads.
## Run: godot --headless --path . tests/ep2_weapon_consistency_test.tscn

const ROOMS := ["res://src/episode2/chamber/interlude_base.gd", "res://src/episode2/chamber/lake_trail.gd", "res://src/episode2/chamber/smelting_facility.gd"]
var failures: int = 0


func check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] ", label)
	else:
		failures += 1
		print("  [FAIL] ", label, " ", detail)


func _bounds(node: Node3D) -> AABB:
	var box := AABB()
	var first: bool = true
	var inv: Transform3D = node.global_transform.affine_inverse()
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var b: AABB = (inv * m.global_transform) * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _ready() -> void:
	_test_borchardt()
	_test_sharps_model()
	await _test_scope_rule()
	_test_shop()
	print("EP2_WEAPON_CONSISTENCY: %s" % ("ALL PASS" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(0 if failures == 0 else 1)


func _test_borchardt() -> void:
	print("-- THE BORCHARDT")
	var gun: Node3D = (load(Ep2Extras.BORCHARDT_GUN) as PackedScene).instantiate() as Node3D
	add_child(gun)
	var bb: AABB = _bounds(gun)
	check("the file is the real pistol, gun only: 0.355 m long, muzzle +Z, the bore on y = 0 (the stranger draws this same file)", absf(bb.size.z - 0.355) < 0.005 and bb.end.z > 0.2 and bb.position.y < -0.1, str(bb))
	gun.free()
	check("the stranger's fist still closes on the grip", GoldTownChamber.OPP_GUN_GRIP.y < -0.05 and GoldTownChamber.OPP_GUN_GRIP.y > -0.15)
	var view: Node3D = Ep2ArmoryGunView.make(Ep2ArmoryState.BORCH)
	add_child(view)
	var rem: Node3D = Ep2RemingtonView.make_held()
	add_child(rem)
	var view_gun: Node3D = view.get_node("Gun")
	var seen: AABB = _bounds(view_gun)
	var rem_len: float = _bounds(rem).size.z
	var scaled: float = seen.size.z * view_gun.scale.z
	check("first person it is the Remington's length within 5 percent (%.3f vs %.3f m), on the view only" % [scaled, rem_len], absf(scaled - rem_len) / rem_len < 0.05)
	var hand: Node3D = view.get_node_or_null("Hands/GunHand")
	check("it is held by the Remington's own glove and arm, in the Remington's own place", hand != null and hand.position.is_equal_approx(Ep2RemingtonView.FOUNDER_OFFSET))
	check("gun and arm are the Remington's full size, not a keychain", hand != null and _bounds(hand).size.x > 0.7 or hand != null and _bounds(hand).size.z > 0.7)
	var eye: Vector3 = view.get_meta("ads_cam")
	check("aimed from the Remington's own eye point, so the arm lands where his does and stays out of the centre", eye.is_equal_approx(Vector3(0, 0.095, -0.60)), str(eye))
	check("the carry is the Remington's", is_equal_approx(Vector3(view.get_meta("hip_rotation")).y, PI + 0.28))
	view.free()
	rem.free()


func _test_sharps_model() -> void:
	print("-- THE SHARPS")
	var view: Node3D = Ep2ArmoryGunView.make(Ep2ArmoryState.BUFF)
	add_child(view)
	var gun: Node3D = view.get_node("Gun")
	var bb: AABB = _bounds(gun)
	check("the rifle is 1.21 m long, gun only, muzzle +Z", absf(bb.size.z - 1.21) < 0.01 and bb.end.z > 0.7, str(bb))
	check("it carries the telescopic sight", gun.find_child("ScopeTube*", true, false) != null and gun.find_child("ScopeLensEye*", true, false) != null)
	var tube: MeshInstance3D = gun.find_child("ScopeTube*", true, false) as MeshInstance3D
	if tube != null:
		var tb: AABB = _bounds(gun).intersection(_bounds(gun))
		var length: float = tube.get_aabb().size.z
		check("the tube is a long period sight, 0.45 - 0.60 m", length > 0.45 and length < 0.60, str(length))
		var eye: Vector3 = view.get_meta("ads_cam")
		var axis_y: float = tube.global_position.y + tube.get_aabb().get_center().y
		check("the aimed eye is on the tube's axis and behind the eyepiece", absf(eye.y - axis_y) < 0.003 and eye.z < tube.get_aabb().position.z + tube.position.z, "%s axis %.4f" % [str(eye), axis_y])
		check("the tube clears the rifle (its underside over the hammer)", axis_y - 0.0185 > 0.061, str(tb))
	check("no pitched-up aim: the view looks level down the tube", not view.has_meta("ads_rotation") or is_equal_approx(Vector3(view.get_meta("ads_rotation")).x, 0.0))
	check("the view says it is scoped", view.get_meta("scoped", false))
	view.free()
	var rich: Node3D = (load(Ep2Extras.SHARPS) as PackedScene).instantiate() as Node3D
	add_child(rich)
	var rb: AABB = _bounds(rich)
	check("Rich's own rifle (the case and his hand) wears the sight too, and is still a real rifle", rb.end.y > 0.11 and rb.size.x > 1.1 and rb.size.x < 1.3, str(rb))
	rich.free()


func _test_scope_rule() -> void:
	print("-- ONE AIMING RULE")
	var st := Ep2ArmoryState.post_hideout()
	st.acquire(Ep2ArmoryState.BUFF)
	st.acquire(Ep2ArmoryState.REM)
	st.select(Ep2ArmoryState.REM)
	check("every other gun still aims at the room's 58", is_equal_approx(Ep2ArmoryState.aimed_fov(st, 1.0, 78.0, 58.0), 58.0))
	check("every other gun keeps its look speed", is_equal_approx(Ep2ArmoryState.aimed_look_scale(st, 1.0, 58.0), 1.0))
	st.select(Ep2ArmoryState.BUFF)
	var scoped: float = Ep2ArmoryState.aimed_fov(st, 1.0, 78.0, 58.0)
	var zoom: float = tan(deg_to_rad(29.0)) / tan(deg_to_rad(scoped * 0.5))
	check("the Sharps zooms at least 2x past the normal aimed view (%.2fx, fov %.0f)" % [zoom, scoped], zoom >= 2.0 and scoped >= 26.0 and scoped <= 30.0)
	check("at the hip it is the normal view", is_equal_approx(Ep2ArmoryState.aimed_fov(st, 0.0, 78.0, 58.0), 78.0))
	check("mouse look slows with the zoom", absf(Ep2ArmoryState.aimed_look_scale(st, 1.0, 58.0) - scoped / 58.0) < 0.001)
	check("no armory state (the hideout before the lesson) is the normal view", is_equal_approx(Ep2ArmoryState.aimed_fov(null, 1.0, 78.0, 58.0), 58.0))
	var sharps: Ep2Winchester = st.firearm(Ep2ArmoryState.BUFF)
	sharps.ads = 1.0
	var rem_gun: Ep2Winchester = st.firearm(Ep2ArmoryState.REM)
	rem_gun.ads = 1.0
	check("through the scope the round goes where the reticle is (under 0.1 degree, a pixel or two)", sharps.spread_deg(false, false) < 0.1 and rem_gun.spread_deg(false, false) > 0.5)
	check("the kick is held down at full aim", sharps.kick_rad() < deg_to_rad(sharps.kick_deg) * 0.3)
	sharps.ads = 0.0
	rem_gun.ads = 0.0
	for path in ROOMS:
		var src: String = (load(path) as GDScript).source_code
		check("%s reads the one rule, not its own fov lerp" % path.get_file(), "aimed_fov(armory" in src and not "lerpf(FPS_FOV, FPS_ADS_FOV" in src and not "lerpf(FPS_FOV + _fov_extra, FPS_ADS_FOV" in src)
	print("-- THE VIEW AND THE LENS")
	var cam := Camera3D.new()
	add_child(cam)
	var vm := Ep2Viewmodel.new()
	add_child(vm)
	vm.bind_armory(st)
	vm.attach(cam)
	st.select(Ep2ArmoryState.BUFF)
	for i in 60:
		vm.step(1.0 / 60.0, false, false, 0.0)
	check("at the hip the rifle is in his hands and no lens is drawn", vm.rifle.visible and vm.scope_k() == 0.0)
	vm.set_aim(true)
	for i in 60:
		vm.step(1.0 / 60.0, false, false, 0.0)
	check("shouldered, the rifle is away and the lens is full: nothing covers the target", not vm.rifle.visible and vm.scope_k() == 1.0)
	vm.set_aim(false)
	for i in 60:
		vm.step(1.0 / 60.0, false, false, 0.0)
	check("released, the rifle is back", vm.rifle.visible and vm.scope_k() == 0.0)
	vm.set_aim(true)
	for i in 60:
		vm.step(1.0 / 60.0, false, false, 0.0)
	vm.set_aim(false)
	st.select(Ep2ArmoryState.REM)
	for i in 3:
		vm.step(1.0 / 60.0, false, false, 0.0)
	check("switching away mid-scope leaves no lens, and the Remington shows", vm.scope_k() == 0.0 and vm.rifle.visible)
	st.select(Ep2ArmoryState.BUFF)
	vm.set_shown(false)
	check("a director shot still hides it", not vm.rifle.visible)
	vm.set_shown(true)
	vm.free()
	cam.free()
	var hud := Ep2FpsHud.new()
	add_child(hud)
	await get_tree().process_frame
	hud.objective = "OBJECTIVE ON THE LENS"
	hud.toast("TOAST ON THE LENS", 2.0)
	hud.bind_armory(st)
	hud.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	check("without the lens the objective is written (the guard below means something)", hud.drawn_texts.has("OBJECTIVE ON THE LENS"), str(hud.drawn_texts))
	hud.scope = 1.0
	hud.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	check("on the lens: no objective, toast, gun name or weapon card", not hud.drawn_texts.has("OBJECTIVE ON THE LENS") and not hud.drawn_texts.has("TOAST ON THE LENS") and not hud.drawn_texts.has(Ep2ArmoryState.NAMES[st.equipped]) and not hud._quick.visible, str(hud.drawn_texts))
	hud.free()


func _test_shop() -> void:
	print("-- RICH & UTAH")
	var sold: Dictionary = Ep2ArmoryState.shop_item("sniper")
	check("the row keeps its story id, name and price, and now says telescopic sight", str(sold.get("id", "")) == "sniper" and "BUFFALO" in str(sold.get("name", "")) and int(sold.get("price", 0)) == 3 and "TELESCOPIC" in str(sold.get("note", "")) and not "LADDER" in str(sold.get("note", "")), str(sold))
	check("still nine weapon tabs", Ep2ArmoryShop.WEAPON_TABS.size() == 9)
	var tab: Dictionary = Ep2ArmoryShop.WEAPON_TABS[0]
	check("the Sharps tab shows the scoped model", str(tab["label"]) == "SHARPS" and Ep2Extras.has(str(tab["model"])))
	var piece: Node3D = (load(str(tab["model"])) as PackedScene).instantiate() as Node3D
	add_child(piece)
	var bb: AABB = _bounds(piece)
	check("the case model is the existing case height", absf(bb.size.y - 0.30) < 0.01, str(bb))
	piece.free()
	check("the Gatling is still never stock", Ep2ArmoryState.shop_item("gatling").is_empty())
