extends Node2D
class_name PortalLadder
## Protocol Portal — a DOWNWARD glowing ladder that reads as a hatch into a
## study room (the room itself does not exist yet; build step 3 wires it).
##
## This is NOT the climbable ladder from src/level/ladder.gd. It shares no code,
## no scene, no behaviour: it is a decorative + request-only marker. It has NO
## StaticBody2D and NO solid collision of any kind, so it can never block the
## player or the boss chase.
##
## CHOSEN X POSITIONS (founder placement spec: on the boss-approach path,
## readable BEFORE the fight, never inside the boss trigger/hitbox, >=200px
## horizontal clearance from the Blaze Portal, Smoke Lounge door, Hall of
## Blaze, Diamond Vault door, Gold Rush Reserve and Fort Knox entries, aimed
## ~250-450px left of the boss trigger where the door layout permits):
##   Level 1 — x = 2100. BossTrigger CollisionShape2D sits at x = 2700, but the
##     Smoke Lounge secret door (2350) and the Blaze Portal (1450) make the
##     whole 2250-2450 window illegal: >=200px clearance around 2350 excludes
##     2150..2550. 2100 clears the lounge door by 250px, the Blaze Portal by
##     650px and the boss trigger by 600px. (Hall of Blaze at 3250 is beyond
##     the trigger and untouched.)
##   Level 2 — x = 3300. BossTrigger CollisionShape2D is at x = 3700, so 3300
##     is 400px left of it — inside the 250-450 aim. It also clears the
##     Diamond Vault door at 2450 by 850px and never touches the x=3468 secret
##     wall (portal right edge 3332 vs wall left edge 3452).
##   Level 3 — x = 3100. BossTrigger node is at x = 3700 (its CollisionShape2D
##     sits at local 0,0) but the Gold Rush Reserve at 3420 blocks the
##     3250-3450 window (>=200px clearance excludes 3220..3620), so 3100 is
##     the legal spot on the approach: 320px clear of the Reserve, 410px clear
##     of the Fort Knox vault door at 2690, 500px clear of the Blaze Portal at
##     2600, and 600px left of the boss trigger.

## Which protocol this portal belongs to. Drives the glow colour only for now.
@export var protocol: String = "smoke"  # "smoke" | "diamonds" | "gold"
## Stage identity, forwarded with the request so step 3 can open the right room.
@export var stage_id: int = 1

## Emitted when a player stands in the shaft mouth and presses "interact".
## Deliberately does NOT change scene / warp / create a PortalSession.
signal portal_requested(protocol: String, stage_id: int)

const COLOR_SMOKE: Color = Color(0.35, 1.0, 0.45)      # neon green
const COLOR_DIAMONDS: Color = Color(0.35, 0.95, 1.0)   # cyan
const COLOR_GOLD: Color = Color(1.0, 0.78, 0.25)       # gold lantern
## Brighter, whiter gold used for the ring + rails so they separate from the
## orange mine rock on Stage 3.
const COLOR_GOLD_BRIGHT: Color = Color(1.0, 0.9, 0.45)

const SHAFT_WIDTH: float = 64.0
const SHAFT_DEPTH: float = 120.0
const HALO_SIZE: Vector2 = Vector2(260.0, 260.0)
const RING_RADIUS: Vector2 = Vector2(42.0, 24.0)
const PULSE_HZ: float = 1.4
const Z_LEVEL: int = 5  # over background art and ground tiles.

var _color: Color = COLOR_SMOKE
var _glow: Sprite2D = null
var _ring: Line2D = null
var _label: Label = null
var _zone: Area2D = null
var _player_inside: bool = false
var _has_interact_action: bool = false
var _pulse_time: float = 0.0

func _ready() -> void:
	add_to_group("protocol_portal")
	# 5 so the whole rig (hole, rails, rungs, halo, label) draws over the
	# backdrop and the runtime-built ground tiles.
	z_index = Z_LEVEL
	_color = _glow_color()
	_has_interact_action = InputMap.has_action("interact")
	_build_shaft()
	_build_mouth_backing()
	_build_glow_halo()
	_build_ring()
	_build_chevron()
	_build_label()
	_build_particles()
	_build_zone()
	# The parent level (extends LevelBase) builds its ground at runtime and its
	# _ready runs AFTER this child's _ready, so global_position.y is snapped
	# one frame later, once _floor_y_at() can actually answer.
	call_deferred("_snap_to_floor")

func _process(delta: float) -> void:
	# 0.45..1.0 alpha and 0.92..1.08 scale at ~1.4 Hz. Plain sin on a counter
	# instead of a Tween loop, so nothing keeps running once this node is freed.
	_pulse_time += delta
	var t: float = 0.5 + 0.5 * sin(_pulse_time * TAU * PULSE_HZ)
	var a: float = 0.45 + 0.55 * t
	var s: float = 0.92 + 0.16 * t
	if _glow != null:
		_glow.modulate = Color(_color.r, _color.g, _color.b, a)
		_glow.scale = Vector2(s, s)
	if _ring != null:
		_ring.modulate = Color(1.0, 1.0, 1.0, a)
		_ring.scale = Vector2(s, s)

# ---- Floor snap -------------------------------------------------------------

## Walk up the parent chain to whatever node owns the runtime ground (LevelBase
## exposes `_floor_y_at(x: float) -> float`). If nothing owns one, the authored
## position is kept as-is.
func _snap_to_floor() -> void:
	var node: Node = get_parent()
	while node != null:
		if node.has_method("_floor_y_at"):
			var floor_y: float = node.call("_floor_y_at", global_position.x)
			global_position.y = floor_y
			return
		node = node.get_parent()

# ---- Visuals (all built in code; the .tscn stays minimal) -------------------

func _glow_color() -> Color:
	match protocol:
		"diamonds":
			return COLOR_DIAMONDS
		"gold":
			return COLOR_GOLD
		_:
			return COLOR_SMOKE

## Rails + rungs tint. Gold gets the brighter, whiter gold so the ladder does
## not disappear into the orange mine rock.
func _rail_color() -> Color:
	if protocol == "gold":
		return COLOR_GOLD_BRIGHT
	return Color(_color.r, _color.g, _color.b, 0.9).darkened(0.25)

## Ring tint. Same brighter gold rule as the rails.
func _ring_color() -> Color:
	if protocol == "gold":
		return COLOR_GOLD_BRIGHT
	return _color

## Shaft opening at floor level (y = 0) and the rails + rungs dropping away
## below it. Drawn as plain ColorRects on this Node2D — no collision. Every
## bright line gets a 2px near-black outline drawn under it so the ladder reads
## against warm/gold backgrounds too.
func _build_shaft() -> void:
	# Dark hole, drawn a few px BELOW the floor line so the lip stays visible.
	var hole := ColorRect.new()
	hole.name = "ShaftHole"
	hole.position = Vector2(-SHAFT_WIDTH * 0.5, -4.0)
	hole.size = Vector2(SHAFT_WIDTH, SHAFT_DEPTH + 14.0)
	hole.color = Color(0.02, 0.03, 0.04, 0.95)
	add_child(hole)

	var outline_color: Color = Color(0.02, 0.02, 0.03, 0.95)
	var rail_color: Color = _rail_color()

	# Left rail: 2px dark outline first, bright line on top.
	var rail_l_out := ColorRect.new()
	rail_l_out.name = "RailLOutline"
	rail_l_out.position = Vector2(-26.0, -1.0)
	rail_l_out.size = Vector2(9.0, SHAFT_DEPTH + 2.0)
	rail_l_out.color = outline_color
	add_child(rail_l_out)

	var rail_l := ColorRect.new()
	rail_l.name = "RailL"
	rail_l.position = Vector2(-24.0, 0.0)
	rail_l.size = Vector2(5.0, SHAFT_DEPTH)
	rail_l.color = rail_color
	add_child(rail_l)

	# Right rail: same outline treatment.
	var rail_r_out := ColorRect.new()
	rail_r_out.name = "RailROutline"
	rail_r_out.position = Vector2(17.0, -1.0)
	rail_r_out.size = Vector2(9.0, SHAFT_DEPTH + 2.0)
	rail_r_out.color = outline_color
	add_child(rail_r_out)

	var rail_r := ColorRect.new()
	rail_r.name = "RailR"
	rail_r.position = Vector2(19.0, 0.0)
	rail_r.size = Vector2(5.0, SHAFT_DEPTH)
	rail_r.color = rail_color
	add_child(rail_r)

	var rung_count: int = int(SHAFT_DEPTH / 20.0)
	for i in range(rung_count):
		var y: float = 10.0 + float(i) * 20.0
		var rung_out := ColorRect.new()
		rung_out.name = "RungOutline%d" % i
		rung_out.position = Vector2(-26.0, y - 2.0)
		rung_out.size = Vector2(52.0, 8.0)
		rung_out.color = outline_color
		add_child(rung_out)

		var rung := ColorRect.new()
		rung.name = "Rung%d" % i
		rung.position = Vector2(-24.0, y)
		rung.size = Vector2(48.0, 4.0)
		rung.color = rail_color
		add_child(rung)

## Near-black rounded panel sitting at the shaft mouth, drawn UNDER the glow so
## the additive halo always has something dark to read against (Stage 3's gold
## glow used to blend straight into the orange mine).
func _build_mouth_backing() -> void:
	var backing := Panel.new()
	backing.name = "MouthBacking"
	backing.position = Vector2(-60.0, -30.0)
	backing.size = Vector2(120.0, 60.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.02, 0.05, 0.85)
	sb.corner_radius_top_left = 30
	sb.corner_radius_top_right = 30
	sb.corner_radius_bottom_left = 30
	sb.corner_radius_bottom_right = 30
	backing.add_theme_stylebox_override("panel", sb)
	add_child(backing)

## Additive halo ~260x260px, centred on the shaft mouth. No PointLight2D: the
## Compatibility renderer's light cost is not worth it here, an additive sprite
## reads the same in a side-scroller. The radial falloff is baked into a
## GradientTexture2D (RADIAL, opaque centre -> transparent edge) so the Sprite2D
## only needs a modulate tint, which _process pulses.
func _build_glow_halo() -> void:
	_glow = Sprite2D.new()
	_glow.name = "GlowHalo"
	_glow.texture = _make_radial_glow_texture()
	_glow.position = Vector2.ZERO  # centred on the shaft mouth
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = mat
	_glow.modulate = _color
	add_child(_glow)

func _make_radial_glow_texture() -> GradientTexture2D:
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	grad.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = int(HALO_SIZE.x)
	tex.height = int(HALO_SIZE.y)
	return tex

## Thin bright ring around the mouth, pulsing in sync with the halo.
func _build_ring() -> void:
	_ring = Line2D.new()
	_ring.name = "MouthRing"
	_ring.width = 4.0
	_ring.default_color = _ring_color()
	_ring.closed = true
	_ring.joint_mode = Line2D.LINE_JOINT_ROUND
	_ring.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_ring.end_cap_mode = Line2D.LINE_CAP_ROUND
	var pts := PackedVector2Array()
	var segments: int = 40
	for i in range(segments):
		var ang: float = TAU * float(i) / float(segments)
		pts.append(Vector2(cos(ang) * RING_RADIUS.x, sin(ang) * RING_RADIUS.y))
	_ring.points = pts
	_ring.position = Vector2.ZERO
	add_child(_ring)

## Down arrow drawn as a Polygon2D chevron (the "▼" glyph is missing from the
## game font and rendered as a tofu box). ~26x18px, glow colour, with a 2px
## near-black outline so it holds up over bright sky.
func _build_chevron() -> void:
	var outline := Polygon2D.new()
	outline.name = "DownChevronOutline"
	outline.polygon = PackedVector2Array([
		Vector2(-15.0, -11.0),
		Vector2(15.0, -11.0),
		Vector2(0.0, 11.0),
	])
	outline.color = Color(0.0, 0.0, 0.0, 0.95)
	outline.position = Vector2(-68.0, -52.0)
	add_child(outline)

	var chevron := Polygon2D.new()
	chevron.name = "DownChevron"
	chevron.polygon = PackedVector2Array([
		Vector2(-13.0, -9.0),
		Vector2(13.0, -9.0),
		Vector2(0.0, 9.0),
	])
	chevron.color = _color
	chevron.position = Vector2(-68.0, -52.0)
	add_child(chevron)

## "STUDY" always visible (readable at gameplay zoom), 22px with an 8px
## near-black outline on a dark rounded backing panel so it survives the busy
## sky. Swaps to the prompt form while the player is in the zone. ASCII only —
## the arrow is the Polygon2D chevron built above.
func _build_label() -> void:
	_label = Label.new()
	_label.name = "StudyLabel"
	_label.text = "STUDY"
	_label.size = Vector2(160.0, 36.0)
	_label.position = Vector2(-80.0, -70.0)  # ~70px above the shaft mouth
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_color", _color)
	_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	_label.add_theme_constant_override("outline_size", 8)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.0, 0.0, 0.6)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0
	_label.add_theme_stylebox_override("normal", sb)
	add_child(_label)

## Rising glow motes. CPUParticles2D (not GPU) — the HTML5 non-threaded export
## target has no reliable GPU particle support. Denser, bigger and faster than
## the first pass, with the alpha fade baked into color_ramp.
func _build_particles() -> void:
	var p := CPUParticles2D.new()
	p.name = "RisingGlow"
	p.texture = _make_square_texture(1)
	p.amount = 28
	p.lifetime = 1.4
	p.local_coords = false
	p.position = Vector2(0.0, -10.0)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(SHAFT_WIDTH * 0.5, 20.0)
	p.direction = Vector2(0.0, -1.0)
	p.spread = 12.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 80.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 5.0
	p.color = Color(1.0, 1.0, 1.0, 1.0)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(_color.r, _color.g, _color.b, 1.0))
	ramp.set_color(1, Color(_color.r, _color.g, _color.b, 0.0))
	p.color_ramp = ramp
	add_child(p)

func _make_square_texture(side: int) -> ImageTexture:
	var img: Image = Image.create(side, side, false, Image.FORMAT_RGBA8)
	img.fill(Color(1.0, 1.0, 1.0, 1.0))
	return ImageTexture.create_from_image(img)

# ---- Interaction zone -------------------------------------------------------

## Detection only: layer 0 (nothing detects this), mask 2 (the player).
## The body is additionally required to be in the "player" group, so stray
## layer-2 bodies cannot trigger a study request.
func _build_zone() -> void:
	_zone = Area2D.new()
	_zone.name = "EnterZone"
	_zone.collision_layer = 0
	_zone.collision_mask = 2
	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var rect := RectangleShape2D.new()
	rect.size = Vector2(64.0, 80.0)
	shape.shape = rect
	shape.position = Vector2(0.0, 0.0)  # centred on the shaft mouth
	_zone.add_child(shape)
	_zone.body_entered.connect(_on_body_entered)
	_zone.body_exited.connect(_on_body_exited)
	add_child(_zone)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_inside = true
	_update_prompt()

func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_inside = false
	_update_prompt()

func _update_prompt() -> void:
	if _label == null:
		return
	_label.text = "STUDY  [E]" if _player_inside else "STUDY"

func _unhandled_input(event: InputEvent) -> void:
	if not _player_inside or not _has_interact_action:
		return
	if event.is_action_pressed("interact"):
		portal_requested.emit(protocol, stage_id)
		# One line only — no scene change, no warp, no PortalSession. Study
		# rooms are step 3's job.
		print("[PortalLadder] study requested: protocol=%s stage=%d" % [protocol, stage_id])
