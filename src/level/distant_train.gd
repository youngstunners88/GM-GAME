class_name DistantTrain
extends ParallaxLayer
## Far-distance GoldMine train ride — Inferno Bull + Lil Blunt riding the rails
## into town behind the Level 3 gameplay plane.
##
## Lives inside its own ParallaxBackground (see distant_train.tscn, layer -15:
## in front of the painted level backdrop at -20, behind gameplay at 0) and
## scrolls at 0.18x so it reads as horizon depth. The track is drawn in code
## (layer space, one _draw pass: bed + rails + ties) and the train loops
## across the mirrored span on its own clock, so it keeps rolling even when
## the camera is still. ParallaxLayer mirroring repeats the whole rig, which
## just reads as more distant rail traffic.
##
## Riders are silhouettes on the tender deck: Lil Blunt in his cowboy outfit
## (the Level 3 look) and Inferno Bull as a dark horned shape — at ~280px
## render width no finer detail would survive the distance haze anyway.

const TRAIN_TEXTURE := "res://src/assets/sprites/sprite_prop_train-goldmine_512.png"
const BLUNT_TEXTURE := "res://src/assets/sprites/sprite_lil-blunt_cowboy.png"
const SMOKE_TEXTURE := "res://src/assets/sprites/fx_dot.png"

## Layer-space span the track covers; also the parallax mirror period and the
## train's wrap range, so the loop is seamless.
@export var span: float = 3200.0
## Layer-space rail height. Screen-pinned vertically (motion_scale.y = 0),
## tuned to sit on the backdrop's horizon band.
@export var track_y: float = 430.0
## Train travel speed in layer-space px/s. Slow on purpose: far away.
@export var train_speed: float = 45.0
## Locomotive render width in px. Small + hazed = far.
@export var render_width: float = 280.0
## Distance haze over the whole rig.
@export var haze: Color = Color(0.62, 0.58, 0.66, 1.0)

var _train: Node2D
var _train_x: float = 200.0
var _bob_time: float = 0.0
var _base_train_y: float = 0.0


func _ready() -> void:
	motion_scale = Vector2(0.18, 0.0)
	motion_mirroring = Vector2(span, 0.0)
	_build_train()
	_base_train_y = track_y - 78.0
	_train.position = Vector2(_train_x, _base_train_y)
	queue_redraw()


func _process(delta: float) -> void:
	_train_x = wrapf(_train_x + train_speed * delta, 0.0, span)
	_bob_time += delta
	_train.position = Vector2(_train_x, _base_train_y + sin(_bob_time * 2.6) * 1.6)


## Track art, drawn once in layer space: gravel bed, two steel rails seen
## edge-on, and cross-ties every 36px. Dark silhouette palette — the haze
## comes from the low values, not from transparency (which would let the
## backdrop bleed through the rails).
func _draw() -> void:
	var bed := Color(0.15, 0.11, 0.13, 1.0)
	var tie := Color(0.24, 0.17, 0.12, 1.0)
	var rail := Color(0.52, 0.47, 0.52, 1.0)
	draw_rect(Rect2(0.0, track_y + 10.0, span, 12.0), bed)
	var x: float = 0.0
	while x < span:
		draw_rect(Rect2(x, track_y + 6.0, 10.0, 16.0), tie)
		x += 36.0
	draw_line(Vector2(0.0, track_y + 4.0), Vector2(span, track_y + 4.0), rail, 3.0)
	draw_line(Vector2(0.0, track_y + 10.0), Vector2(span, track_y + 10.0), rail, 3.0)


func _build_train() -> void:
	_train = Node2D.new()
	_train.name = "Train"
	add_child(_train)
	# Locomotive. Reference art faces left; the ride runs left-to-right
	# (into town), so flip to face travel direction.
	var loco := Sprite2D.new()
	loco.name = "Locomotive"
	loco.texture = load(TRAIN_TEXTURE)
	loco.flip_h = true
	loco.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var tex_size: Vector2 = loco.texture.get_size()
	var scale_factor: float = render_width / tex_size.x
	loco.scale = Vector2(scale_factor, scale_factor)
	loco.modulate = haze
	_train.add_child(loco)
	_build_riders(scale_factor)
	_build_smoke()


## Both riders stand on the tender deck (right-hand end past the cab).
## Bull is a procedural horned silhouette — no 2D Bull sprite exists (he is
## a 3D rigged GLB in Episode 2) and at this render size a silhouette with
## horns + amber eyes reads better than a downscaled sculpt ever would.
func _build_riders(_train_scale: float) -> void:
	var deck := Node2D.new()
	deck.name = "Riders"
	# Tender deck in train-local px (loco sprite is centered, flipped, ~280px
	# wide: tender bed sits right-of-center, feet line just above the frames).
	deck.position = Vector2(80.0, -30.0)
	_train.add_child(deck)

	var bull := Node2D.new()
	bull.name = "InfernoBull"
	bull.position = Vector2(-16.0, 0.0)
	deck.add_child(bull)
	var hide := Color(0.23, 0.07, 0.07, 1.0)
	var horn := Color(0.92, 0.86, 0.70, 1.0)
	_add_poly(bull, PackedVector2Array([Vector2(-15, 0), Vector2(15, 0), Vector2(15, -26), Vector2(-15, -26)]), hide)  # torso
	_add_poly(bull, PackedVector2Array([Vector2(-2, -26), Vector2(16, -26), Vector2(16, -38), Vector2(-2, -38)]), hide)  # hump
	_add_poly(bull, PackedVector2Array([Vector2(12, -30), Vector2(26, -30), Vector2(26, -18), Vector2(12, -18)]), hide)  # head
	_add_poly(bull, PackedVector2Array([Vector2(14, -30), Vector2(8, -42), Vector2(12, -29)]), horn)  # horn L
	_add_poly(bull, PackedVector2Array([Vector2(24, -30), Vector2(30, -42), Vector2(26, -29)]), horn)  # horn R
	_add_poly(bull, PackedVector2Array([Vector2(-12, 0), Vector2(-7, 0), Vector2(-7, 10), Vector2(-12, 10)]), hide)  # leg L
	_add_poly(bull, PackedVector2Array([Vector2(7, 0), Vector2(12, 0), Vector2(12, 10), Vector2(7, 10)]), hide)  # leg R
	var eye := Node2D.new()
	eye.add_child(_dot(Vector2(18, -25), 1.6, Color(1.0, 0.62, 0.15, 1.0)))
	eye.add_child(_dot(Vector2(23, -25), 1.6, Color(1.0, 0.62, 0.15, 1.0)))
	bull.add_child(eye)

	var blunt := Sprite2D.new()
	blunt.name = "LilBlunt"
	blunt.texture = load(BLUNT_TEXTURE)
	blunt.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var b_size: Vector2 = blunt.texture.get_size()
	blunt.scale = Vector2.ONE * (34.0 / b_size.y)
	blunt.position = Vector2(22.0, -17.0)
	blunt.modulate = Color(0.75, 0.70, 0.72, 1.0)
	deck.add_child(blunt)


func _add_poly(parent: Node2D, points: PackedVector2Array, color: Color) -> void:
	var poly := Polygon2D.new()
	poly.polygon = points
	poly.color = color
	parent.add_child(poly)


func _dot(pos: Vector2, radius: float, color: Color) -> Polygon2D:
	var pts := PackedVector2Array()
	for i in range(8):
		var a: float = TAU * float(i) / 8.0
		pts.append(pos + Vector2(cos(a), sin(a)) * radius)
	var poly := Polygon2D.new()
	poly.polygon = pts
	poly.color = color
	return poly


## Coal-smoke puffs from the stack (front-right now that the loco is
## flipped). Same CPUParticles2D + fx_dot pattern Level 3 already uses for
## gold-dust motes.
func _build_smoke() -> void:
	var smoke := CPUParticles2D.new()
	smoke.name = "StackSmoke"
	smoke.texture = load(SMOKE_TEXTURE)
	smoke.position = Vector2(96.0, -108.0)
	smoke.amount = 20
	smoke.lifetime = 2.6
	smoke.preprocess = 2.6
	smoke.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = 6.0
	smoke.direction = Vector2(0.6, -1.0)
	smoke.spread = 28.0
	smoke.initial_velocity_min = 14.0
	smoke.initial_velocity_max = 30.0
	smoke.gravity = Vector2(6.0, -8.0)
	smoke.scale_amount_min = 1.2
	smoke.scale_amount_max = 3.0
	smoke.color = Color(0.55, 0.53, 0.58, 0.30)
	_train.add_child(smoke)
