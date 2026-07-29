extends Area2D
## Thrown flame — the torch power-up's tap attack. Replaces the base axe
## throw for the attack's duration (CombatHandler branches on
## GameManager.has_power_up("torch") before AXE_SCENE). Lobs in a shallow
## arc rather than axe's flat throw, so the two moves read differently even
## though both are simple thrown projectiles.
##
## Collision: same layer/mask as axe.gd — Projectiles layer (64), masking
## Enemies (bit 3) + Hazards (bit 6) = 36. Deliberately not World, so a low
## throw skims the ground instead of despawning on the first floor tile.
##
## Palette from the Grok 4.5 VFX dispatch (docs/model-responses/
## 2026-07-29-grok-torch-vfx.md) — main-campaign neon-orange, deliberately
## NOT the Smoke Lounge's purple-grey palette.

const MID_COLOR := Color(1.0, 0.624, 0.11, 1.0)     # #FF9F1C main flame body
const OUTER_COLOR := Color(1.0, 0.302, 0.0, 1.0)     # #FF4D00 edge/rim
const SMOKE_COLOR := Color(0.353, 0.4, 0.439, 0.5)   # #5A6670 cool smoke

var direction: float = 1.0        ## -1 = left, +1 = right
var speed: float = 300.0
var vertical_speed: float = -50.0 ## slight upward lob at launch
const GRAVITY: float = 200.0
var damage: int = 2
var lifetime: float = 1.4
var _age: float = 0.0

@onready var core: Sprite2D = $Core
@onready var envelope: CPUParticles2D = $Envelope
@onready var trail: CPUParticles2D = $Trail

## Cached per-instance (each projectile is a fresh node anyway; no cross-
## instance sharing needed) — same "no art dependency for a one-off cosmetic
## effect" technique already used in lil_blunt_visual.gd and boss_health_bar.gd.
var _glow_tex: ImageTexture

func _ready() -> void:
	add_to_group("projectile")
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	if core:
		core.texture = _make_glow_texture()
		core.modulate = MID_COLOR
	var t := get_tree().create_timer(lifetime)
	t.timeout.connect(_despawn)

func _physics_process(delta: float) -> void:
	_age += delta
	vertical_speed += GRAVITY * delta
	position.x += direction * speed * delta
	position.y += vertical_speed * delta
	if trail:
		trail.direction = Vector2(-direction, 0.3)
	_update_flicker()

## Size ramps 16px -> 24px -> ~18px over the projectile's life (Grok spec),
## plus a light scale pulse so it doesn't read as a static decal in flight.
func _update_flicker() -> void:
	if core == null:
		return
	var t := clampf(_age / lifetime, 0.0, 1.0)
	var base_scale := 0.67
	if t < 0.5:
		base_scale = lerpf(0.67, 1.0, t / 0.5)
	else:
		base_scale = lerpf(1.0, 0.75, (t - 0.5) / 0.5)
	var pulse := 1.0 + sin(_age * 22.0) * 0.08
	core.scale = Vector2.ONE * base_scale * pulse
	core.modulate = MID_COLOR.lerp(OUTER_COLOR, t)

func _on_body_entered(body: Node2D) -> void:
	if _hit(body):
		_impact()
	elif body.has_method("smash"):        # rolling boulder
		body.smash()
		_impact()

func _on_area_entered(area: Area2D) -> void:
	# The hitbox Area2D itself usually isn't the enemy — the enemy is its owner.
	if _hit(area) or _hit(area.get_parent()):
		_impact()

## Damages `node` if it's a takeable enemy; returns whether a hit landed.
func _hit(node: Node) -> bool:
	if node and node.is_in_group("enemy") and node.has_method("take_damage"):
		node.take_damage(damage)
		return true
	return false

var _impacted: bool = false

func _impact() -> void:
	_impacted = true
	AudioManager.play_sfx_at("torch_impact", global_position)
	_spawn_burst(16)
	_despawn()

func _despawn() -> void:
	if not is_instance_valid(self):
		return
	# Kimi audit: this used to key off `_age < lifetime`, which is true for
	# almost every impact too (impacts happen mid-flight, well before the
	# timer fires) — every hit was double-bursting AND double-playing
	# impact + fizzle SFX. Fizzle is only for the no-hit timeout case.
	if not _impacted:
		AudioManager.play_sfx_at("torch_fizzle", global_position)
		_spawn_burst(10)
	queue_free()

## One-shot impact/fizzle burst. Reparented to the scene root, not this node,
## because this node is about to be freed (rolling_boulder.gd's precedent for
## a burst that must outlive the object it came from).
func _spawn_burst(count: int) -> void:
	# Kimi audit: check current_scene BEFORE constructing the node, not after —
	# building it first and returning on a null scene left an un-parented,
	# never-freed CPUParticles2D orphaned (only reachable mid scene-transition,
	# but a real one-off leak).
	var root := get_tree().current_scene
	if root == null:
		return
	var burst := CPUParticles2D.new()
	burst.texture = _make_glow_texture()
	burst.amount = count
	burst.lifetime = 0.3
	burst.one_shot = true
	burst.emitting = true
	burst.spread = 180.0
	burst.initial_velocity_min = 60.0
	burst.initial_velocity_max = 160.0
	burst.scale_amount_min = 0.4
	burst.scale_amount_max = 0.8
	burst.color = OUTER_COLOR
	burst.global_position = global_position
	root.add_child(burst)
	get_tree().create_timer(0.5).timeout.connect(func() -> void:
		if is_instance_valid(burst):
			burst.queue_free())

func _make_glow_texture() -> ImageTexture:
	if _glow_tex:
		return _glow_tex
	var size := 24
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size / 2.0, size / 2.0)
	for x in range(size):
		for y in range(size):
			var d := Vector2(x, y).distance_to(center) / (size / 2.0)
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	_glow_tex = ImageTexture.create_from_image(img)
	return _glow_tex
