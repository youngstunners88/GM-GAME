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
	var view := Ep2BowView.make(true)
	add_child(view)
	Ep2BowView.update(view, 1.0, true)
	check("draw hand and arrow share the independently authored nock", view.get_node("RightHand").position.is_equal_approx(view.get_node("Nock").position) and view.get_node("NockedArrow").position.is_equal_approx(view.get_node("Nock").position))
	var limbs: MeshInstance3D = view.find_child("FlexibleLimbs", true, false)
	check("bow has deforming limbs and separate string", limbs != null and limbs.get_blend_shape_count() == 1 and is_equal_approx(limbs.get_blend_shape_value(0), 1.0) and view.has_node("String0") and view.has_node("String1"))
	Ep2BowView.update(view, 0.0, false)
	check("released arrow disappears from the bow", not view.get_node("NockedArrow").visible)
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
