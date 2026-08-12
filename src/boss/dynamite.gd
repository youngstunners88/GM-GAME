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
## 120, not 100: the blast is aimed at player_pos + (0,-80), so its centre
## floats 80px above the standing player. At radius 100 the circle's lower edge
## only reaches ~player_pos.y+20 — a hair over the 32px body, so a small
## mis-aim or a step read as "no damage". 120 makes standing on the telegraphed
## marker an unambiguous hit while staying dodgeable by actually moving away.
@export var explosion_radius: float = 120.0

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

	# SYNCHRONOUS shape query — the blast damages whoever is in radius RIGHT NOW,
	# with no frame delay. Founder (session 4, twice): "the boss tried to blow
	# me up but it didnt do any damage!" Root cause (Kimi K3, confirmed): the
	# old code spawned a temporary Area2D then `await get_tree().physics_frame`
	# before `get_overlapping_bodies()`. `physics_frame` fires at the START of
	# the next physics tick, BEFORE that tick computes the new Area2D's overlaps
	# — so the query read pre-registration state and returned empty EVERY time.
	# The blast looked and sounded real and dealt zero damage. A direct
	# `intersect_shape` against the space state needs no registration frame and
	# works identically whether _explode() was called by the fuse timer or by a
	# player walking into the dynamite.
	var space := get_world_2d().direct_space_state
	var circle := CircleShape2D.new()
	circle.radius = explosion_radius
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = circle
	params.transform = Transform2D(0.0, global_position)
	params.collision_mask = 2  # player layer
	params.collide_with_bodies = true
	params.collide_with_areas = false
	for hit in space.intersect_shape(params, 8):
		var body: Object = hit.get("collider")
		if body != null and body.is_in_group("player") and body.has_method("take_damage"):
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
