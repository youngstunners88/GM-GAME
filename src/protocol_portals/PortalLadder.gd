extends Node2D
class_name PortalLadder
## Protocol Portal: a TALL glowing climb shaft that drops through the floor
## into the protocol's tour strip.
##
## CONTROL PATH (founder tour rebuild, 2026-09-25):
##   * The EnterZone Area2D covers the mouth and the whole shaft. On
##     body_entered it calls player.enter_ladder_zone(self); on body_exited it
##     calls player.exit_ladder_zone(self). This is the same handshake
##     src/level/ladder.gd uses, and the player reads move_down / move_up
##     itself in player.gd::_update_climb.
##   * This node exposes top_y(), bottom_y() and top_exit_position(), the
##     three things player.gd calls back into on its active ladder.
##   * Holding move_down at the mouth starts the player's own climb. This
##     script then lets him pass through the ground by clearing his
##     collision_mask for the length of the shaft, keeps him centred on the
##     rails, draws him above the ground tiles and lowers his Camera2D bottom
##     limit so the camera follows him DOWN the shaft. Everything is
##     restored the moment he is back on the floor.
##   * The BottomTrigger Area2D at the foot of the shaft is the only thing
##     that calls PortalTravel.descend(). The fade into the tour scene is the
##     last step, after the visible climb, never the descent itself.
##
## It still has NO StaticBody2D and NO solid collision, so it can never block
## the player or the boss chase.
##
## CHOSEN X POSITIONS (unchanged; the instances stay where they were in the
## three stage scenes):
##   Level 1 - x = 2100, clear of the Smoke Lounge door (2350), the Blaze
##     Portal (1450) and the boss trigger (2700).
##   Level 2 - x = 3300, 400px left of the boss trigger (3700), clear of the
##     Diamond Vault door (2450) and the x=3468 secret wall.
##   Level 3 - x = 3100, clear of the Gold Rush Reserve (3420), the Fort Knox
##     door (2690), the Blaze Portal (2600) and the boss trigger (3700).

const Travel := preload("res://src/protocol_portals/PortalTravel.gd")

## Which protocol this portal belongs to. Drives the glow colour.
@export var protocol: String = "smoke"  # "smoke" | "diamonds" | "gold"
## Stage identity, forwarded to the tour scene.
@export var stage_id: int = 1

## Emitted once, when the player reaches the bottom of the shaft.
signal portal_requested(protocol: String, stage_id: int)

const COLOR_SMOKE: Color = Color(0.35, 1.0, 0.45)      # neon green
const COLOR_DIAMONDS: Color = Color(0.35, 0.95, 1.0)   # cyan
const COLOR_GOLD: Color = Color(1.0, 0.78, 0.25)       # gold lantern
## Brighter, whiter gold used for the ring + rails so they separate from the
## orange mine rock on Stage 3.
const COLOR_GOLD_BRIGHT: Color = Color(1.0, 0.9, 0.45)

const SHAFT_WIDTH: float = 64.0
## Visible depth below the mouth. >= 4 player-heights (the brief asks for
## at least 320px) so the climb reads on screen before the fade.
const SHAFT_DEPTH: float = 360.0
const RUNG_SPACING: float = 20.0
const HALO_SIZE: Vector2 = Vector2(260.0, 260.0)
const RING_RADIUS: Vector2 = Vector2(42.0, 24.0)
const PULSE_HZ: float = 1.4
const Z_LEVEL: int = 5  # over background art and ground tiles.

## Climb zone: narrow (so walking past does not grab much) and reaching a
## little above the mouth so a standing player is inside it.
const ZONE_WIDTH: float = 40.0
const ZONE_ABOVE: float = 40.0
## Foot-of-shaft trigger height.
const BOTTOM_TRIGGER_H: float = 40.0
## Player collision box side (top-left anchored 32x32, see player.gd).
const PLAYER_BOX: float = 32.0
## Extra room under the shaft bottom for the camera limit while climbing.
const CAMERA_BOTTOM_PAD: float = 220.0

## How far right / up of the ladder the returning player is placed.
const RETURN_OFFSET: Vector2 = Vector2(70.0, -48.0)

var _color: Color = COLOR_SMOKE
var _glow: Sprite2D = null
var _ring: Line2D = null
var _ring_outline: Line2D = null
var _label: Label = null
var _hint: Label = null
var _zone: Area2D = null
var _bottom: Area2D = null
var _player_inside: bool = false
var _pulse_time: float = 0.0

## The player currently using this shaft (null when nobody is near it).
var _player: CharacterBody2D = null
## True while the player is travelling through the ground inside the shaft.
var _shaft_mode: bool = false
var _saved_mask: int = 0
var _saved_z: int = 0
var _saved_limit_bottom: int = 10000000
var _descending: bool = false


func _ready() -> void:
	add_to_group("protocol_portal")
	z_index = Z_LEVEL
	# Run the shaft guard BEFORE the player's own physics step each frame, so
	# the collision mask is already cleared when his climb moves him down.
	process_physics_priority = -10
	_color = _glow_color()
	_build_shaft()
	_build_mouth_backing()
	_build_glow_halo()
	_build_ring()
	_build_chevron()
	_build_label()
	_build_particles()
	_build_zone()
	_build_bottom_trigger()
	# The parent level (extends LevelBase) builds its ground at runtime and its
	# _ready runs AFTER this child's _ready, so global_position.y is snapped
	# one frame later, once _floor_y_at() can actually answer.
	call_deferred("_snap_to_floor")


func _process(delta: float) -> void:
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
	if _ring_outline != null:
		_ring_outline.modulate = Color(1.0, 1.0, 1.0, a)
		_ring_outline.scale = Vector2(s, s)


# ---- Player climb API (called back by player.gd) ----------------------------

## World Y of the shaft mouth (the floor line).
func top_y() -> float:
	return global_position.y


## World Y of the shaft bottom.
func bottom_y() -> float:
	return global_position.y + SHAFT_DEPTH


## Where the player stands after topping out: on the floor, just OUTSIDE the
## climb zone on the side he is already on, so the zone cannot re-grab him.
func top_exit_position() -> Vector2:
	var side: float = 1.0
	if _player != null and is_instance_valid(_player):
		if _player.global_position.x + PLAYER_BOX * 0.5 < global_position.x:
			side = -1.0
	var x: float = global_position.x + 30.0
	if side < 0.0:
		x = global_position.x - 30.0 - PLAYER_BOX
	return Vector2(x, global_position.y - PLAYER_BOX - 2.0)


# ---- Shaft guard ------------------------------------------------------------

func _physics_process(_delta: float) -> void:
	if _player == null:
		return
	if not is_instance_valid(_player):
		_player = null
		_shaft_mode = false
		return
	var climbing: bool = bool(_player.get("_climbing"))
	if not _shaft_mode:
		if _player_inside and climbing and Input.is_action_pressed("move_down"):
			_enter_shaft_mode()
		return

	var feet_y: float = _player.global_position.y + PLAYER_BOX
	if not climbing:
		if feet_y <= global_position.y + 2.0:
			# Back on the floor (topped out or climbed out): normal physics.
			_leave_shaft_mode()
			return
		# Below the floor line but not climbing (a hop off the rungs, or the
		# anti-freeze heartbeat cleared the flag): he is inside solid ground
		# with no collision, so put him straight back on the rungs.
		if int(_player.get("_ladder_zones")) <= 0 and _player.has_method("enter_ladder_zone"):
			_player.call("enter_ladder_zone", self)
		_player.set("_climbing", true)
		_player.velocity = Vector2.ZERO

	# Keep him on the rails and never below the shaft floor.
	var home_x: float = global_position.x - PLAYER_BOX * 0.5
	_player.global_position.x = clampf(_player.global_position.x, home_x - 6.0, home_x + 6.0)
	var max_y: float = global_position.y + SHAFT_DEPTH - PLAYER_BOX
	if _player.global_position.y > max_y:
		_player.global_position.y = max_y
		if _player.velocity.y > 0.0:
			_player.velocity.y = 0.0


func _enter_shaft_mode() -> void:
	if _player == null or _shaft_mode:
		return
	_shaft_mode = true
	_saved_mask = _player.collision_mask
	_saved_z = _player.z_index
	_player.collision_mask = 0
	# Drawn over the ground tiles and the dark shaft hole, so he is visible
	# the whole way down.
	_player.z_index = Z_LEVEL + 2
	_player.global_position.x = global_position.x - PLAYER_BOX * 0.5
	var cam: Camera2D = _player.get_node_or_null("Camera2D") as Camera2D
	if cam != null:
		_saved_limit_bottom = cam.limit_bottom
		var needed: int = int(global_position.y + SHAFT_DEPTH + CAMERA_BOTTOM_PAD)
		cam.limit_bottom = maxi(cam.limit_bottom, needed)
	if _hint != null:
		_hint.visible = false


func _leave_shaft_mode() -> void:
	if not _shaft_mode:
		return
	_shaft_mode = false
	if _player != null and is_instance_valid(_player):
		_player.collision_mask = _saved_mask
		_player.z_index = _saved_z
		var cam: Camera2D = _player.get_node_or_null("Camera2D") as Camera2D
		if cam != null:
			cam.limit_bottom = _saved_limit_bottom
	if not _player_inside:
		_player = null
	_update_prompt()


func _descend() -> void:
	if _descending:
		return
	_descending = true
	portal_requested.emit(protocol, stage_id)
	print("[PortalLadder] shaft bottom reached: protocol=%s stage=%d" % [protocol, stage_id])
	var scene_path: String = ""
	var tree: SceneTree = get_tree()
	if tree != null and tree.current_scene != null:
		scene_path = tree.current_scene.scene_file_path
	# The climb already happened on screen; the scene load is the last step.
	Travel.descend(protocol, stage_id, scene_path, global_position.x)


# ---- Floor snap -------------------------------------------------------------

func _snap_to_floor() -> void:
	var node: Node = get_parent()
	while node != null:
		if node.has_method("_floor_y_at"):
			var floor_y: float = node.call("_floor_y_at", global_position.x)
			# Never write a non-finite y into the transform (blanks the frame).
			if is_finite(floor_y):
				global_position.y = floor_y
			break
		node = node.get_parent()
	_place_returning_player()


## If this is the shaft the player just climbed back up (the tour called
## PortalTravel.ascend()), stand him next to the mouth at the same world x.
func _place_returning_player() -> void:
	var scene_path: String = ""
	var tree: SceneTree = get_tree()
	if tree != null and tree.current_scene != null:
		scene_path = tree.current_scene.scene_file_path
	if not Travel.consume_return(scene_path, protocol):
		return
	for node in get_tree().get_nodes_in_group("player"):
		var body := node as Node2D
		if body == null:
			continue
		body.global_position = Vector2(
			global_position.x + RETURN_OFFSET.x,
			global_position.y + RETURN_OFFSET.y)
		if body is CharacterBody2D:
			(body as CharacterBody2D).velocity = Vector2.ZERO


# ---- Visuals ----------------------------------------------------------------

func _glow_color() -> Color:
	match protocol:
		"diamonds":
			return COLOR_DIAMONDS
		"gold":
			return COLOR_GOLD
		_:
			return COLOR_SMOKE


func _rail_color() -> Color:
	if protocol == "gold":
		return COLOR_GOLD_BRIGHT
	return Color(_color.r, _color.g, _color.b, 0.9).darkened(0.25)


func _ring_color() -> Color:
	if protocol == "gold":
		return COLOR_GOLD_BRIGHT
	return _color


## The tall shaft: a dark hole cut into the ground from the mouth down to
## SHAFT_DEPTH, two outlined rails and a rung every RUNG_SPACING px, plus a
## faint glow pool at the bottom where the tour opens.
func _build_shaft() -> void:
	var hole := ColorRect.new()
	hole.name = "ShaftHole"
	hole.position = Vector2(-SHAFT_WIDTH * 0.5, -4.0)
	hole.size = Vector2(SHAFT_WIDTH, SHAFT_DEPTH + 14.0)
	hole.color = Color(0.02, 0.03, 0.04, 0.97)
	add_child(hole)

	var pool := ColorRect.new()
	pool.name = "ShaftBottomGlow"
	pool.position = Vector2(-SHAFT_WIDTH * 0.5, SHAFT_DEPTH - 30.0)
	pool.size = Vector2(SHAFT_WIDTH, 40.0)
	pool.color = Color(_color.r, _color.g, _color.b, 0.28)
	add_child(pool)

	var outline_color: Color = Color(0.02, 0.02, 0.03, 0.95)
	var rail_color: Color = _rail_color()

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

	var rung_count: int = int(SHAFT_DEPTH / RUNG_SPACING)
	for i in range(rung_count):
		var y: float = 10.0 + float(i) * RUNG_SPACING
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


func _build_mouth_backing() -> void:
	var backing := Panel.new()
	backing.name = "MouthBacking"
	backing.position = Vector2(-60.0, -30.0)
	backing.size = Vector2(120.0, 30.0)
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.02, 0.05, 0.85)
	sb.corner_radius_top_left = 30
	sb.corner_radius_top_right = 30
	backing.add_theme_stylebox_override("panel", sb)
	add_child(backing)


## Additive halo centred on the mouth. Radial falloff baked into a
## GradientTexture2D, pulsed by _process through modulate.
func _build_glow_halo() -> void:
	_glow = Sprite2D.new()
	_glow.name = "GlowHalo"
	_glow.texture = _make_radial_glow_texture()
	_glow.position = Vector2.ZERO
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


## Bright ring around the mouth with a near-black outline ring drawn as a
## plain sibling before it (no show_behind_parent: that was the Stage 2
## black-frame root cause on web GL Compatibility).
func _build_ring() -> void:
	var pts := PackedVector2Array()
	var segments: int = 40
	for i in range(segments):
		var ang: float = TAU * float(i) / float(segments)
		pts.append(Vector2(cos(ang) * RING_RADIUS.x, sin(ang) * RING_RADIUS.y))

	_ring_outline = Line2D.new()
	_ring_outline.name = "MouthRingOutline"
	_ring_outline.width = 10.0
	_ring_outline.default_color = Color(0.03, 0.02, 0.05, 0.85)
	_ring_outline.closed = true
	_ring_outline.joint_mode = Line2D.LINE_JOINT_ROUND
	_ring_outline.points = pts
	add_child(_ring_outline)

	_ring = Line2D.new()
	_ring.name = "MouthRing"
	_ring.width = 4.0
	_ring.default_color = _ring_color()
	_ring.closed = true
	_ring.joint_mode = Line2D.LINE_JOINT_ROUND
	_ring.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_ring.end_cap_mode = Line2D.LINE_CAP_ROUND
	_ring.points = pts
	add_child(_ring)


## Down chevron drawn as Polygon2D (the arrow glyph is missing from the font).
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


## "STUDY" always visible, plus a small "HOLD DOWN" hint while the player
## stands at the mouth. ASCII only.
func _build_label() -> void:
	_label = Label.new()
	_label.name = "StudyLabel"
	_label.text = "STUDY"
	_label.size = Vector2(160.0, 36.0)
	_label.position = Vector2(-80.0, -70.0)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_color", _color)
	_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	_label.add_theme_constant_override("outline_size", 8)
	_label.add_theme_stylebox_override("normal", _dark_style())
	add_child(_label)

	_hint = Label.new()
	_hint.name = "HintLabel"
	_hint.text = "HOLD DOWN"
	_hint.size = Vector2(160.0, 26.0)
	_hint.position = Vector2(-80.0, -102.0)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 15)
	_hint.add_theme_color_override("font_color", Color(0.92, 0.96, 0.96))
	_hint.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	_hint.add_theme_constant_override("outline_size", 6)
	_hint.add_theme_stylebox_override("normal", _dark_style())
	_hint.visible = false
	add_child(_hint)


func _dark_style() -> StyleBoxFlat:
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
	return sb


## Rising glow motes (CPU particles only, web-safe).
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


# ---- Climb zone + bottom trigger --------------------------------------------

## Climb zone over the mouth AND the whole shaft. Layer 0, mask 2 (player).
func _build_zone() -> void:
	_zone = Area2D.new()
	_zone.name = "EnterZone"
	_zone.collision_layer = 0
	_zone.collision_mask = 2
	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var rect := RectangleShape2D.new()
	rect.size = Vector2(ZONE_WIDTH, ZONE_ABOVE + SHAFT_DEPTH)
	shape.shape = rect
	shape.position = Vector2(0.0, (SHAFT_DEPTH - ZONE_ABOVE) * 0.5)
	_zone.add_child(shape)
	_zone.body_entered.connect(_on_body_entered)
	_zone.body_exited.connect(_on_body_exited)
	add_child(_zone)


func _build_bottom_trigger() -> void:
	_bottom = Area2D.new()
	_bottom.name = "BottomTrigger"
	_bottom.collision_layer = 0
	_bottom.collision_mask = 2
	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var rect := RectangleShape2D.new()
	rect.size = Vector2(SHAFT_WIDTH, BOTTOM_TRIGGER_H)
	shape.shape = rect
	shape.position = Vector2(0.0, SHAFT_DEPTH - BOTTOM_TRIGGER_H * 0.5)
	_bottom.add_child(shape)
	_bottom.body_entered.connect(_on_bottom_body_entered)
	add_child(_bottom)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_inside = true
	if body is CharacterBody2D:
		_player = body as CharacterBody2D
	if body.has_method("enter_ladder_zone"):
		body.call("enter_ladder_zone", self)
	_update_prompt()


func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_inside = false
	if body.has_method("exit_ladder_zone"):
		body.call("exit_ladder_zone", self)
	if not _shaft_mode:
		_player = null
	_update_prompt()


func _on_bottom_body_entered(body: Node2D) -> void:
	if body == null or body != _player:
		return
	if not _shaft_mode:
		return
	_descend()


func _update_prompt() -> void:
	if _label != null:
		_label.text = "STUDY"
	if _hint != null:
		_hint.visible = _player_inside and not _shaft_mode and not _descending
