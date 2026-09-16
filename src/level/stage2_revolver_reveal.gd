class_name Stage2RevolverReveal
extends CanvasLayer
## THE GOLDEN REVOLVER REVEAL — plays between the Stage 2 boss-defeat video
## and the level transition into Stage 3 (Gold Rush).
##
## Founder brief (2026-09-16, golden Remington reference art): "the golden
## Remington handgun comes out of the bus that Lil Blunt smashes into pieces
## and he picks it up and then continues into the next level just as you had
## set it previously." No video-generation tool is wired into this
## environment (see hero-character-pipeline's honesty note for the same
## constraint on a different asset), so this is built the same way the
## ORIGINAL Stage 2 shot list was drafted before the Seedance video replaced
## it (docs/model-responses/2026-09-05-*-stage2-defeat-cutscene.md):
## CanvasLayer-only primitives, tweened, no new art pipeline required except
## the one real asset that already exists — sprite_item_golden_revolver.png,
## cropped directly from the founder's own reference image, not a
## regeneration of it.
##
## "just as you had set it previously": this is inserted as a NEW beat
## between distributor.gd's `await cutscene.finished` (the existing video,
## untouched) and its `queue_free(); SceneRouter.load_scene(...)` call — the
## video, its VO, its timing, and the Stage 3 transition are all unchanged.
##
## Weapon-system side of this: Stage 3's base attack becomes the revolver
## (see combat_handler.gd::_uses_revolver, gated on current_level == 3) as
## soon as Stage 3 loads. This scene is the narrative justification for why
## he already has it — it does not itself set any gameplay flag, the same
## way Stage 1's smoke-bomb doc comment about "finding the pickaxe" was
## narrative framing rather than a runtime gate.

signal finished

const REVOLVER_ART := "res://src/assets/sprites/sprite_item_golden_revolver.png"

var _done := false

func play() -> void:
	layer = 5  # same layer as the video cutscenes: above HUD, below the wipe
	process_mode = Node.PROCESS_MODE_ALWAYS

	var vp: Vector2 = get_viewport().get_visible_rect().size
	var center := vp * 0.5

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.05, 0.05, 0.08, 0.0)
	backdrop.size = vp
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	var bus := _build_bus(center)
	add_child(bus)

	var fade_in := create_tween()
	fade_in.tween_property(backdrop, "color:a", 0.85, 0.3)
	await fade_in.finished

	# Impact — Lil Blunt's swing lands off-screen; the bus takes the hit.
	await get_tree().create_timer(0.35, true, false, true).timeout
	ScreenShake.heavy()
	AudioManager.play_sfx_at("bigaxe_impact", center)
	var flash := create_tween()
	flash.tween_property(bus, "modulate", Color(1.6, 1.6, 1.6, 1.0), 0.05)
	flash.tween_property(bus, "modulate", Color(1, 1, 1, 1), 0.1)

	# Shatter — the bus breaks into pieces and a debris burst covers the cut.
	await get_tree().create_timer(0.25, true, false, true).timeout
	AudioManager.play_sfx_at("explosion", center)
	EffectSpawner.burst("explosion", center)
	_shatter_bus(bus)

	# The golden revolver flies clear of the wreck.
	await get_tree().create_timer(0.35, true, false, true).timeout
	var revolver := _spawn_revolver(center)
	add_child(revolver)
	EffectSpawner.burst("coin_sparkle", center)

	var arc_target := Vector2(vp.x * 0.5, vp.y * 0.32)
	var arc := create_tween()
	arc.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	arc.tween_property(revolver, "position", arc_target, 0.55)
	arc.parallel().tween_property(revolver, "rotation", TAU * 1.5, 0.55)
	arc.parallel().tween_property(revolver, "scale", Vector2(2.0, 2.0), 0.55)
	await arc.finished
	AudioManager.play_sfx_at("powerup", center)
	ScreenShake.light()

	var label := _spawn_label(arc_target + Vector2(0.0, 46.0))
	add_child(label)
	var label_tween := create_tween()
	label_tween.tween_property(label, "modulate:a", 1.0, 0.2)

	await get_tree().create_timer(1.1, true, false, true).timeout

	var fade_out := create_tween()
	fade_out.tween_property(backdrop, "color:a", 0.0, 0.4)
	fade_out.parallel().tween_property(revolver, "modulate:a", 0.0, 0.4)
	fade_out.parallel().tween_property(label, "modulate:a", 0.0, 0.4)
	await fade_out.finished
	_finish()

## A boxy Gold Rush transport bus, drawn from primitives — rust-brown body,
## a pale windshield band, dark wheels. Reads as "vehicle" at a glance
## without needing a sprite sheet, same procedural-drawing rule every other
## unreleased-art object in this project follows.
func _build_bus(center: Vector2) -> Node2D:
	var root := Node2D.new()
	root.position = center

	var body := ColorRect.new()
	body.size = Vector2(220.0, 90.0)
	body.position = Vector2(-110.0, -45.0)
	body.color = Color(0.42, 0.28, 0.14, 1.0)
	root.add_child(body)

	var windshield := ColorRect.new()
	windshield.size = Vector2(190.0, 26.0)
	windshield.position = Vector2(-95.0, -34.0)
	windshield.color = Color(0.55, 0.68, 0.72, 0.9)
	root.add_child(windshield)

	var stripe := ColorRect.new()
	stripe.size = Vector2(220.0, 10.0)
	stripe.position = Vector2(-110.0, 4.0)
	stripe.color = Color(0.85, 0.68, 0.2, 1.0)
	root.add_child(stripe)

	for wx in [-70.0, 70.0]:
		var wheel := ColorRect.new()
		wheel.size = Vector2(30.0, 30.0)
		wheel.position = Vector2(wx - 15.0, 30.0)
		wheel.color = Color(0.08, 0.08, 0.08, 1.0)
		root.add_child(wheel)

	return root

## Splits the bus into its own child rects and flings them outward — a cheap
## procedural "shatter" (position/rotation tween per fragment + fade), same
## technique the Stage 2 shot list specified for the crystal-boss collapse
## ("new rotated ColorRects... breaking into sharp fragments").
func _shatter_bus(bus: Node2D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for child in bus.get_children():
		if not (child is ColorRect):
			continue
		var dir := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.6, -0.4)).normalized()
		var dist := rng.randf_range(90.0, 180.0)
		var t := child.create_tween()
		t.set_parallel(true)
		t.tween_property(child, "position", child.position + dir * dist, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_property(child, "rotation", rng.randf_range(-6.0, 6.0), 0.7)
		t.tween_property(child, "modulate:a", 0.0, 0.7)
	get_tree().create_timer(0.8, true, false, true).timeout.connect(func() -> void:
		if is_instance_valid(bus):
			bus.queue_free())

func _spawn_revolver(pos: Vector2) -> Sprite2D:
	var sprite := Sprite2D.new()
	if ResourceLoader.exists(REVOLVER_ART):
		sprite.texture = load(REVOLVER_ART)
	sprite.position = pos
	sprite.scale = Vector2(1.4, 1.4)
	return sprite

func _spawn_label(pos: Vector2) -> Label:
	var label := Label.new()
	label.text = "GOLDEN REVOLVER ACQUIRED"
	label.position = pos - Vector2(150.0, 0.0)
	label.size = Vector2(300.0, 30.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.25, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 5)
	label.modulate.a = 0.0
	return label

func _finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()
	queue_free()
