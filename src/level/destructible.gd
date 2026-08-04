class_name Destructible
extends Node2D
## Progressive structural damage for level furniture (ladders, platforms, crates).
##
## Founder, verbatim: "it should also do heavier damage even to the extent where
## the ladder breaks and the platforms etc. They mustn't break completely as in
## disappear, but there needs to be structural damage and if the player persists
## then we see that the damage increases until the object is completely wrecked
## so that the novelty of the tool is worthwhile."
##
## So: a hit must be VISIBLE and CUMULATIVE, and the prop only disappears at the
## end of a chain of hits — never on the first one. Before this, a big axe
## fade-and-freed a ladder instantly, which is exactly the "disappear" he ruled
## out.
##
## Rendered PROCEDURALLY. Every damageable prop in this project is built from
## ColorRects in GDScript at runtime (ladder.gd draws its own rungs; platforms
## come from level_base._create_platform) — there is no authored art per prop,
## so a 4-sprites-per-stage art pipeline would be unbuildable. Cracks are drawn
## from a per-instance deterministic seed so they are stable frame to frame and
## different prop to prop.
##
## Usage:
##   var d := Destructible.new()
##   d.configure(Vector2(w, h), 3)          # size + hits to wreck
##   d.wrecked.connect(_my_cleanup)
##   add_child(d)
## then route damage in with d.take_structural_damage(1).

signal damaged(stage: int)
signal wrecked

## Hits absorbed before the prop is wrecked. Stage advances once per hit.
@export var max_integrity: int = 3
## Size of the prop this is overlaying, so cracks span the real object.
@export var prop_size: Vector2 = Vector2(24, 128)

var integrity: int = 3
## 0 = pristine, 1 = cracked, 2 = badly damaged, 3 = wrecked.
var damage_stage: int = 0
var _is_wrecked: bool = false
var _rng_seed: int = 0

func configure(size: Vector2, hits: int = 3) -> void:
	prop_size = size
	max_integrity = maxi(1, hits)
	integrity = max_integrity

func _ready() -> void:
	integrity = max_integrity
	# Deterministic per-instance crack pattern: seeded from the world position
	# so two ladders don't wear identically, but a given ladder's cracks never
	# shimmer between frames the way a fresh randf() per _draw() would.
	_rng_seed = int(abs(global_position.x) * 7.0 + abs(global_position.y) * 13.0) | 1
	# Draw on top of the prop's own ColorRects.
	z_index = 5

## Apply damage. Returns true if this hit wrecked the prop.
## Safe to call after wrecking — extra hits are ignored rather than
## re-emitting `wrecked` and double-freeing the owner.
func take_structural_damage(amount: int = 1) -> bool:
	if _is_wrecked or amount <= 0:
		return false
	integrity = maxi(0, integrity - amount)
	damage_stage = max_integrity - integrity
	queue_redraw()
	_shudder()
	_spit_debris()
	damaged.emit(damage_stage)
	if integrity <= 0:
		_is_wrecked = true
		wrecked.emit()
		return true
	return false

func is_wrecked() -> bool:
	return _is_wrecked

## A short shake on the PARENT so the hit has weight. Tween is created on the
## parent and targets its own position, restoring the exact original value —
## no drift accumulates across many hits.
func _shudder() -> void:
	var host := get_parent()
	if not (host is Node2D):
		return
	var n := host as Node2D
	var home := n.position
	var t := n.create_tween()
	t.tween_property(n, "position", home + Vector2(3, 0), 0.04)
	t.tween_property(n, "position", home + Vector2(-3, 0), 0.04)
	t.tween_property(n, "position", home, 0.04)
	# Permanent lean once badly damaged — reads as structurally failing.
	if damage_stage >= 2:
		n.rotation = deg_to_rad(3.0 * (1 if (_rng_seed % 2) == 0 else -1))

func _spit_debris() -> void:
	var burst := CPUParticles2D.new()
	burst.texture = load("res://src/assets/sprites/fx_dot.png")
	burst.emitting = true
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.amount = 10
	burst.lifetime = 0.5
	burst.position = prop_size / 2.0
	burst.direction = Vector2(0, -1)
	burst.spread = 80.0
	burst.gravity = Vector2(0, 900)
	burst.initial_velocity_min = 60.0
	burst.initial_velocity_max = 160.0
	burst.scale_amount_min = 0.1
	burst.scale_amount_max = 0.2
	burst.color = Color(0.75, 0.62, 0.42, 0.95)
	add_child(burst)
	get_tree().create_timer(1.2).timeout.connect(func() -> void:
		if is_instance_valid(burst):
			burst.queue_free())

## Progressive cracks over an arbitrary-sized rect, no per-prop art.
##
## Stage 1: a couple of hairline fractures.
## Stage 2: more + wider fractures, plus punched-out chunks (holes drawn in
##          near-black) so material is visibly MISSING, not just scratched.
## Stage 3: only briefly visible before the owner removes the prop.
func _draw() -> void:
	if damage_stage <= 0:
		return
	var w: float = maxf(prop_size.x, 4.0)
	var h: float = maxf(prop_size.y, 4.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = _rng_seed

	var fractures: int = 2 + damage_stage * 2
	var crack := Color(0.06, 0.04, 0.03, 0.92)
	for i in range(fractures):
		# Each fracture is a short polyline walking across the prop, so it
		# reads as a split rather than a straight scratch.
		var start := Vector2(rng.randf() * w, rng.randf() * h)
		var pts := PackedVector2Array([start])
		var p := start
		var dir := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)).normalized()
		for _s in range(3):
			p += dir * rng.randf_range(w * 0.18, w * 0.55) + Vector2(rng.randf_range(-4, 4), rng.randf_range(-4, 4))
			p.x = clampf(p.x, 0.0, w)
			p.y = clampf(p.y, 0.0, h)
			pts.append(p)
		draw_polyline(pts, crack, 1.0 + float(damage_stage), true)

	# Punched-out chunks from stage 2 — actual missing material.
	if damage_stage >= 2:
		var holes: int = damage_stage * 2
		for i in range(holes):
			var c := Vector2(rng.randf() * w, rng.randf() * h)
			var r: float = rng.randf_range(2.5, 5.5)
			draw_circle(c, r, Color(0.03, 0.02, 0.02, 0.95))

	# Char/soot wash as it approaches collapse.
	if damage_stage >= 2:
		draw_rect(Rect2(Vector2.ZERO, Vector2(w, h)), Color(0.1, 0.07, 0.05, 0.18), true)
