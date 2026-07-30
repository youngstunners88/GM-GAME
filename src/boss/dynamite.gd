extends Area2D
## Telegraphed blast zone. Previously this had NO visual at all — an invisible
## Area2D that silently sat for `explosion_delay` seconds before detonating.
## That made the Claim Jumper's signature attack unreadable: there was
## nothing on screen to plan a dodge around, which is the opposite of what a
## "final boss" telegraph should do. Now it draws a lit fuse dot plus an
## expanding warning ring that brightens and pulses faster as detonation
## nears, sized to the actual blast radius so "stand here = you get hit" is
## legible at a glance.

@export var explosion_delay: float = 2.0
@export var explosion_radius: float = 100.0

var _elapsed: float = 0.0
var _exploded: bool = false
@onready var _fuse: Sprite2D = $Fuse

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(explosion_delay).timeout.connect(_explode)

func _process(delta: float) -> void:
	if _exploded:
		return
	_elapsed = minf(_elapsed + delta, explosion_delay)
	var t := _elapsed / explosion_delay if explosion_delay > 0.0 else 1.0
	# Pulse speeds up as detonation nears — a slow blink at the start, a fast
	# strobe in the last half-second, so "get out now" reads without a timer.
	var pulse_hz := lerpf(1.5, 9.0, t)
	var pulse := 0.5 + 0.5 * sin(_elapsed * pulse_hz * TAU)
	if _fuse:
		_fuse.modulate = Color(1.0, lerpf(0.5, 0.15, t), 0.05, 1.0).lerp(Color(1, 1, 0.3, 1), pulse * 0.4)
		_fuse.scale = Vector2.ONE * (0.7 + 0.15 * pulse)
	queue_redraw()

func _draw() -> void:
	if _exploded:
		return
	var t: float = _elapsed / explosion_delay if explosion_delay > 0.0 else 1.0
	var pulse_hz := lerpf(1.5, 9.0, t)
	var alpha := 0.15 + 0.35 * (0.5 + 0.5 * sin(_elapsed * pulse_hz * TAU))
	draw_circle(Vector2.ZERO, explosion_radius, Color(1.0, 0.3, 0.05, alpha))
	draw_arc(Vector2.ZERO, explosion_radius, 0, TAU, 48, Color(1.0, 0.6, 0.1, alpha + 0.25), 3.0)

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player"):
		_explode()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_explode()

func _explode() -> void:
	if _exploded or not is_inside_tree():
		return
	_exploded = true
	queue_redraw()
	var explosion := Area2D.new()
	explosion.position = global_position
	# Area2D.new() defaults to collision_layer=1/mask=1 (World). The player is
	# on layer 2, so without this override get_overlapping_bodies() below
	# would return empty every time — the blast would look and sound real but
	# deal zero damage. Same class of bug as the kill-zone fix (2026-07-14):
	# an Area2D silently matching nothing because nobody set its mask.
	explosion.collision_layer = 0
	explosion.collision_mask = 2
	get_parent().add_child(explosion)

	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = explosion_radius
	col.shape = shape
	explosion.add_child(col)

	# A freshly added Area2D needs one physics step before the physics server
	# has actually registered its shape against existing bodies — calling
	# get_overlapping_bodies() in the same frame it's created can return empty
	# even with a correct mask.
	await get_tree().physics_frame
	var overlapping := explosion.get_overlapping_bodies()
	for body in overlapping:
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(1)

	EffectSpawner.burst("explosion", global_position)
	AudioManager.play_sfx("explosion")
	ScreenShake.shake(0.3, 6.0)

	if _fuse:
		_fuse.visible = false
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.1)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.1)
	await tween.finished
	queue_free()
	explosion.queue_free()
