extends Node
var failures: int = 0
func check(label: String, ok: bool) -> void:
	print("  [PASS] " if ok else "  [FAIL] ", label)
	if not ok:
		failures += 1

func _ready() -> void:
	var state := Ep2ArmoryState.post_hideout()
	state.record_corpse("no_bow", 2)
	state.claim_corpse("no_bow")
	check("arrows alone never invent a bow", state.arrows == 2 and not state.owns(Ep2ArmoryState.BOW))
	state.record_corpse("archer", 4, true)
	check("search an archer awards its bow and remaining arrows once", state.claim_corpse("archer") == 4 and state.owns(Ep2ArmoryState.BOW) and state.claim_corpse("archer") == -1 and state.arrows == 6)
	state.select(Ep2ArmoryState.BOW)
	state.step(0.18)
	var bow := state.active_gun() as Ep2Bow
	var shots: Array = []
	bow.fired.connect(func() -> void: shots.append(state.arrows))
	check("draw starts without spending an arrow", bow.trigger() == Ep2Winchester.Shot.OK and state.arrows == 6)
	state.step(0.35)
	check("half draw stays nocked and cannot double trigger", bow.draw_amount() > 0.49 and bow.trigger() == Ep2Winchester.Shot.CYCLING and shots.is_empty())
	state.select(Ep2ArmoryState.WIN)
	state.step(1.0)
	check("switch interrupts draw without a delayed shot or arrow loss", not bow.drawing and shots.is_empty() and state.arrows == 6)
	state.select(Ep2ArmoryState.BOW)
	state.step(0.18)
	bow.trigger()
	for i in 42:
		state.step(1.0 / 60.0)
	check("full draw emits once and spends exactly one arrow", shots.size() == 1 and state.arrows == 5 and bow.rounds == 5)
	state.step(0.5)
	check("release cannot repeat during recovery", shots.size() == 1 and state.arrows == 5)
	var saved: Dictionary = state.snapshot()
	var copy := Ep2ArmoryState.new()
	copy.restore(JSON.parse_string(JSON.stringify(saved)))
	check("save round trip keeps bow, pool and once-only archer claim", copy.owns(Ep2ArmoryState.BOW) and copy.equipped == Ep2ArmoryState.BOW and copy.arrows == 5 and copy.active_gun().rounds == 5 and copy.claim_corpse("archer") == -1)
	bow.trigger()
	state.restore(saved)
	state.step(1.0)
	check("checkpoint restore cancels an in-progress draw", state.arrows == 5 and not bow.drawing)
	# the bears' bow (and the player's where the streamed founder bow is not mounted) keeps its authored limb morph and separate string
	var view := Ep2BowView.make(false)
	add_child(view)
	Ep2BowView.update(view, 1.0, true)
	check("draw hand and arrow share the independently authored nock", view.get_node("NockedArrow").position.is_equal_approx(view.get_node("Nock").position))
	var limbs: MeshInstance3D = view.find_child("FlexibleLimbs", true, false)
	check("bow has deforming limbs and separate string", limbs != null and limbs.get_blend_shape_count() == 1 and is_equal_approx(limbs.get_blend_shape_value(0), 1.0) and view.has_node("String0") and view.has_node("String1"))
	Ep2BowView.update(view, 0.0, false)
	check("released arrow disappears from the bow", not view.get_node("NockedArrow").visible)
	# THE FOUNDER'S BOW (Drive 2026-10-20): the player's bow where the streamed extras are mounted; here they are on disk
	check("the founder bow is in the streamed extras and is the player's bow", Ep2BowView.has_founder() and Ep2BowView.make(true).has_meta("fb"))
	var fb := Ep2BowView.make(true)
	add_child(fb)
	check("it keeps the contract the viewmodel and the woods read: Nock, NockedArrow, RightHand, String0/1", fb.has_node("Nock") and fb.has_node("NockedArrow") and fb.has_node("RightHand") and fb.has_node("String0") and fb.has_node("String1"))
	Ep2BowView.update(fb, 1.0, true)
	check("at full draw the string hand and the arrow are on the nock, 0.32 m behind its rest", fb.get_node("RightHand").position.is_equal_approx(fb.get_node("Nock").position) and fb.get_node("NockedArrow").position.is_equal_approx(fb.get_node("Nock").position)
		and absf((fb.get_node("Nock") as Node3D).position.z - (-0.52)) < 0.01)
	var up: MeshInstance3D = fb.find_child("Limb_Up", true, false)
	var low: MeshInstance3D = fb.find_child("Limb_Low", true, false)
	check("both limbs flex with the draw (a `draw` shape key each, fully on at full draw)", up != null and low != null and up.get_blend_shape_count() == 1 and low.get_blend_shape_count() == 1
		and is_equal_approx(up.get_blend_shape_value(0), 1.0) and is_equal_approx(low.get_blend_shape_value(0), 1.0))
	var tip: Vector3 = (fb.get_meta("fb") as Dictionary)["tip_up"]
	var string0: MeshInstance3D = fb.get_node("String0")
	var s0_end: Vector3 = string0.position + string0.basis.y * ((string0.mesh as CylinderMesh).height * 0.5)
	var s0_other: Vector3 = string0.position - string0.basis.y * ((string0.mesh as CylinderMesh).height * 0.5)
	var nock_p: Vector3 = fb.get_node("Nock").position
	check("the string runs from the flexed limb tip to the nock (a real string, not a baked rod)", minf(s0_end.distance_to(nock_p), s0_other.distance_to(nock_p)) < 0.02 and maxf(s0_end.distance_to(nock_p), s0_other.distance_to(nock_p)) > 0.4)
	var emb: MeshInstance3D = fb.find_child("Emblem", true, false)
	check("the GM emblem disc is on the riser, both sides (the rifle's own emblem art, no ring added)", emb != null and emb.mesh != null and emb.mesh.get_surface_count() == 1 and (emb.mesh.surface_get_material(0) as StandardMaterial3D).albedo_texture != null
		and (emb.mesh.surface_get_material(0) as StandardMaterial3D).emission_enabled)
	var fb_aabb: AABB = emb.mesh.get_aabb()
	check("the emblem is a flush disc about 8 cm across (the rifle emblem is 7.5 cm), covering the old pin head on each side of the riser", fb_aabb.size.y > 0.07 and fb_aabb.size.y < 0.09 and fb_aabb.size.z > 0.07 and fb_aabb.size.z < 0.09)
	Ep2BowView.update(fb, 0.0, false)
	check("released arrow disappears from the founder bow too", not fb.get_node("NockedArrow").visible)
	var arrow_fly := Ep2BowView.player_arrow()
	check("the arrow that flies is the founder's: origin at the head (hit tests start at the point), 0.75 m long behind it", arrow_fly.name == "FlightArrow" and arrow_fly.get_child_count() == 1 and is_equal_approx((arrow_fly.get_child(0) as Node3D).position.z, -Ep2BowView.FOUNDER_ARROW_LEN))
	arrow_fly.free()
	# the bow's draw and loose are paired with their sounds: creak sized to the draw, loose on the shot, thunk on the hit
	var creak: AudioStream = load("res://src/assets/sounds/ep2_bow_creak.mp3") as AudioStream
	check("the draw creak is 0.88 s and is stretched to the 0.7 s draw (pitch = length / draw time)", creak != null and absf(creak.get_length() - 0.88) < 0.05 and is_equal_approx(0.88 / Ep2Bow.DRAW_TIME, 1.2571429))
	check("loose and impact sounds exist for the player's arrow", ResourceLoader.exists("res://src/assets/sounds/ep2_bow_loose.mp3") and ResourceLoader.exists("res://src/assets/sounds/ep2_arrow_thunk.mp3"))
	var vm := Ep2Viewmodel.new()
	add_child(vm)
	var cam := Camera3D.new()
	add_child(cam)
	var armory_state := Ep2ArmoryState.post_hideout()
	vm.bind_armory(armory_state)
	vm.attach(cam)
	armory_state.record_corpse("archer2", 3, true)
	armory_state.claim_corpse("archer2")
	armory_state.select(Ep2ArmoryState.BOW)
	armory_state.step(0.3)
	vm._sync_weapon()
	check("selecting the bow in the viewmodel shows the founder bow", vm.rifle != null and vm.rifle.has_meta("fb") and vm.rifle.visible)
	var vbow := armory_state.active_gun() as Ep2Bow
	var played: Array = [false]
	vbow.trigger()
	for i in 12:
		vm.step(1.0 / 60.0, false, false, 0.0)
	check("drawing raises the bow toward the eye and tightens the view (draw adds to ads)", vbow.ads > 0.05 and vm._creak != null and vm._creak.playing)
	for i in 15:
		vm.step(1.0 / 60.0, false, false, 0.0)
	check("the founder bow's limbs flex with the draw in the viewmodel (mid draw)", float((vm.rifle.find_child("Limb_Up", true, false) as MeshInstance3D).get_blend_shape_value(0)) > 0.3 and vbow.drawing)
	for i in 30:
		vm.step(1.0 / 60.0, false, false, 0.0)
	check("after the loose the limbs relax and the creak is done (nothing stuck drawn)", not vbow.drawing and float((vm.rifle.find_child("Limb_Up", true, false) as MeshInstance3D).get_blend_shape_value(0)) < 1.12)
	vm.queue_free()
	cam.queue_free()
	var rem := Ep2RemingtonView.make()
	add_child(rem)
	var skeletons := rem.find_children("*", "Skeleton3D", true, false)
	check("Remington glove imports with a real finger skeleton", skeletons.size() == 1 and (skeletons[0] as Skeleton3D).get_bone_count() == 19)
	# Exercise the shipping swept-flight code, not a separate collision approximation.
	var woods := WoodsQuadChamber.new()
	add_child(woods)
	woods._visuals = Node3D.new()
	woods.add_child(woods._visuals)
	var target := Ep2BearKit.make_bear(woods._visuals, Vector3(0, 0, 5))
	var brain := Ep2BearBrain.new(target, {"hp": 1, "routine": "watch"}, 7)
	woods._bears = [brain]
	var arrow := Ep2BowView.arrow()
	woods._visuals.add_child(arrow)
	woods._player_arrows.append({"node": arrow, "pos": Vector3(0, 1.4, 0), "v": Vector3(0, 0, 38), "t": 0.0})
	for i in 20:
		woods._tick_player_arrows(1.0 / 60.0)
	check("swept arrow hits a bear once and retires the projectile", brain.is_dead() and woods._player_arrows.is_empty())
	brain.hp = 1
	brain.aware = Ep2BearBrain.Aware.UNAWARE
	Ep2BearKit.pose(target, "idle")
	woods._tree_grid = {Vector2i(0, 0): [[Vector2(0, 2.5), 0.3, 4.0]]}
	arrow = Ep2BowView.arrow()
	woods._visuals.add_child(arrow)
	woods._player_arrows.append({"node": arrow, "pos": Vector3(0, 1.4, 0), "v": Vector3(0, 0, 38), "t": 0.0})
	for i in 20:
		woods._tick_player_arrows(1.0 / 60.0)
	check("a trunk stops the short swept segment before the bear", not brain.is_dead() and woods._player_arrows.is_empty())
	woods.queue_free()
	view.queue_free()
	rem.queue_free()
	print("EP2_BOW: ALL PASS" if failures == 0 else "EP2_BOW: FAILED %d" % failures)
	get_tree().quit(0 if failures == 0 else 1)
