<!-- dispatched: deepseek/deepseek-v4.1-flash
     prompt: prompts/portals/step3_rooms_deepseek.md
     files inlined: 6
     images attached: 0
     tokens: 13463 in / 68483 out
     cost: $0.0431
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
=== FILE: src/protocol_portals/PortalTravel.gd ===
extends RefCounted
class_name PortalTravel
## Static travel bookkeeping for the Protocol Portals loop.
##
## The ladder asks this class to descend; the study room asks it to ascend.
## Nothing here draws, mints or networks: it only remembers where the player
## came from, hands the study room its PortalSession and calls SceneRouter.
##
## SceneRouter is an autoload, so it is reached through Engine.get_main_loop()
## instead of a direct node path (static functions have no scene tree).

const SignalsScript := preload("res://src/protocol_portals/PortalSignals.gd")
const PortalSessionScript := preload("res://src/protocol_portals/PortalSession.gd")

const ROOM_SMOKE: String = "res://src/protocol_portals/rooms/smoke/ReadingRing.tscn"
const ROOM_DIAMONDS: String = "res://src/protocol_portals/rooms/diamonds/PressureStudy.tscn"
const ROOM_GOLD: String = "res://src/protocol_portals/rooms/gold/ClaimOffice.tscn"

## Autoload node name that owns load_scene(path, transition).
const ROUTER_NODE: String = "SceneRouter"

## True while the player is inside a study room and owes the level a return.
static var pending_return: bool = false
## Scene the player came from (the level that owns the ladder).
static var return_scene: String = ""
## World x of the ladder, kept for debugging / future spawn offsets.
static var return_x: float = 0.0
## Protocol of the run in flight ("smoke" | "diamonds" | "gold").
static var protocol: String = ""
## Stage id of the run in flight.
static var stage_id: int = 0
## The single live PortalSession, or null when no run is in flight.
## Typed RefCounted so this file never depends on a global class name being
## registered (it is also preloaded by headless tests).
static var session: RefCounted = null


## Room scene that belongs to a protocol. Unknown protocols fall back to smoke.
static func room_scene_for(protocol_id: String) -> String:
    match protocol_id.to_lower():
        "diamonds":
            return ROOM_DIAMONDS
        "gold":
            return ROOM_GOLD
        _:
            return ROOM_SMOKE


## Called by the ladder when the player presses "interact" inside the shaft.
## Stores the return point, opens the session, walks WORLD -> DESCENT and loads
## the matching study room with a fade.
static func descend(protocol_id: String, new_stage_id: int, from_scene_path: String, world_x: float) -> void:
    protocol = protocol_id.to_lower()
    stage_id = new_stage_id
    return_scene = from_scene_path
    return_x = world_x
    pending_return = false

    var fresh: RefCounted = PortalSessionScript.begin(stage_id, protocol)
    if fresh != null:
        fresh.call("transition", SignalsScript.State.DESCENT)
    session = fresh

    _load(room_scene_for(protocol))


## Called by the study room (ascent shaft / "CLIMB BACK").
## Walks the session up to WORLD when that edge is legal — a player leaving
## early from STUDY_CHOICE simply does not get the state change, they still
## get to go home.
static func ascend() -> void:
    if session != null:
        # ASCENT is only reachable from RESULT; anything else just leaves.
        if bool(session.call("transition", SignalsScript.State.ASCENT)):
            session.call("transition", SignalsScript.State.WORLD)

    pending_return = true
    if return_scene.is_empty():
        return
    _load(return_scene)


## True exactly once, when the pending return belongs to this scene/protocol.
## The ladder calls this right after its floor snap to place the player.
static func consume_return(scene_path: String, protocol_id: String) -> bool:
    if not pending_return:
        return false
    if not return_scene.is_empty() and return_scene != scene_path:
        return false
    if not protocol.is_empty() and protocol_id.to_lower() != protocol:
        return false
    pending_return = false
    return true


# ---- SceneRouter plumbing ---------------------------------------------------

## Loads a scene through the SceneRouter autoload. FADE is the default
## transition, which is exactly what a portal wants.
static func _load(path: String) -> void:
    if path.is_empty():
        return
    var router: Node = _router()
    if router == null:
        push_warning("PortalTravel: SceneRouter autoload not found, cannot load %s" % path)
        return
    router.call("load_scene", path)


## Resolves the SceneRouter autoload from the running SceneTree, or null when
## there is no tree (headless unit scripts) or no such autoload.
static func _router() -> Node:
    var loop: MainLoop = Engine.get_main_loop()
    if loop == null or not (loop is SceneTree):
        return null
    var tree: SceneTree = loop as SceneTree
    if tree.root == null:
        return null
    return tree.root.get_node_or_null(ROUTER_NODE)
=== END ===
=== FILE: src/protocol_portals/PortalLadder.gd ===
extends Node2D
class_name PortalLadder
## Protocol Portal — a DOWNWARD glowing ladder that reads as a hatch into a
## study room.
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

const Travel := preload("res://src/protocol_portals/PortalTravel.gd")

## Which protocol this portal belongs to. Drives the glow colour.
@export var protocol: String = "smoke"  # "smoke" | "diamonds" | "gold"
## Stage identity, forwarded to the study room.
@export var stage_id: int = 1

## Emitted when a player stands in the shaft mouth and presses "interact".
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

## How far right / up of the ladder the returning player is placed.
const RETURN_OFFSET: Vector2 = Vector2(70.0, -48.0)

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
## position is kept as-is. Runs once, then places a returning player.
func _snap_to_floor() -> void:
	var node: Node = get_parent()
	while node != null:
		if node.has_method("_floor_y_at"):
			var floor_y: float = node.call("_floor_y_at", global_position.x)
			global_position.y = floor_y
			break
		node = node.get_parent()
	_place_returning_player()

## If this ladder is the one the player just came back through (the study room
## called PortalTravel.ascend()), drop them next to the shaft mouth instead of
## inside it, so the EnterZone cannot instantly re-trigger.
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
		print("[PortalLadder] study requested: protocol=%s stage=%d" % [protocol, stage_id])
		# Hand the run to the travel bookkeeper: it stores the return point,
		# opens the PortalSession and fades into the matching study room.
		Travel.descend(protocol, stage_id, get_tree().current_scene.scene_file_path, global_position.x)
=== END ===
=== FILE: src/protocol_portals/PortalTravel.gd ===
=== END ===
=== FILE: src/protocol_portals/ScorecardGrant.gd ===
extends RefCounted
class_name ScorecardGrant
## Local scorecard bookkeeping for the protocol portals.
##
## This class NEVER mints, never networks and never calls Meshy or any wallet:
## it only records that a completed run earned a scorecard slot, in
## user://portal_scorecards.json, keyed by the protocol token id.
## A later, human-run step may read load_all() and mint out of band.

const SignalsScript := preload("res://src/protocol_portals/PortalSignals.gd")

const SAVE_PATH: String = "user://portal_scorecards.json"


## Marks a finished session eligible. Returns the record that was written, or an
## empty dictionary when the session is not (or no longer) eligible.
## The parameter is typed RefCounted so this file does not depend on the global
## PortalSession class name being registered in headless runs.
static func mark_eligible(session: RefCounted) -> Dictionary:
    if session == null:
        return {}
    if not bool(session.call("eligible_for_scorecard")):
        return {}

    # The scorecard is only "pending" until the mint actually happens offline.
    session.set("pending_icp", true)

    var token: String = String(session.get("nft_token_id"))
    if token.is_empty():
        var protocol: String = String(session.get("protocol"))
        token = String(SignalsScript.TOKEN_IDS.get(protocol, ""))
    if token.is_empty():
        return {}

    var all: Dictionary = load_all()
    var record: Dictionary = session.call("to_dict")
    record["eligible"] = true
    record["minted"] = false
    record["minted_at"] = ""
    all[token] = record
    _write_all(all)
    return record


## Every recorded scorecard entry, keyed by token id. Empty when nothing has
## been recorded yet (or the file is unreadable/malformed).
static func load_all() -> Dictionary:
    if not FileAccess.file_exists(SAVE_PATH):
        return {}
    var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file == null:
        push_warning("ScorecardGrant: could not open %s (err %d)"
            % [SAVE_PATH, FileAccess.get_open_error()])
        return {}
    var text: String = file.get_as_text()
    file.close()
    var parsed: Variant = JSON.parse_string(text)
    if typeof(parsed) != TYPE_DICTIONARY:
        push_warning("ScorecardGrant: %s does not contain a JSON object" % SAVE_PATH)
        return {}
    return parsed


## Merges the whole table back to disk. Local file only — nothing leaves the
## machine here.
static func _write_all(all: Dictionary) -> void:
    var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file == null:
        push_warning("ScorecardGrant: could not write %s (err %d)"
            % [SAVE_PATH, FileAccess.get_open_error()])
        return
    file.store_string(JSON.stringify(all, "  "))
    file.close()
=== END ===
=== FILE: src/protocol_portals/SmokePlate.gd ===
extends Node2D
## The SMOKE whitepaper plate, drawn in code.
##
## The diamonds/gold rooms hang a founder JPEG on the wall; smoke has no art, so
## this node renders the plate's `draw_spec` as a flat 512x512 disc design:
## dark ground, neon rim circles, a burnt ash ring, the central sink hole, eight
## inward burn arrows and the two word marks.
##
## Only three colours are used (background / rim / accent), read straight out of
## the draw_spec dictionary so a copy tweak re-tints the plate.
## SmokePlate draws with the fallback font (draw_string) — the design's text is
## pure ASCII on purpose.

const DESIGN_SIZE: float = 512.0
const CENTRE: Vector2 = Vector2(256.0, 256.0)

## The plate.draw_spec dictionary from portal_copy.json. Assigned by StudyRoom
## before the node enters the tree; the defaults below match the shipped copy.
var draw_spec: Dictionary = {}


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	var background: Color = _spec_color("background", Color(0.043, 0.078, 0.063))
	var rim: Color = _spec_color("rim", Color(0.224, 1.0, 0.533))
	var accent: Color = _spec_color("accent", Color(0.714, 1.0, 0.816))

	# 1. Ground: full square, then a faint radial lift at the centre.
	draw_rect(Rect2(0.0, 0.0, DESIGN_SIZE, DESIGN_SIZE), background)
	draw_circle(CENTRE, 250.0, background.lightened(0.06))

	# 2. Outer rim (r=236) and a thinner, softer inner ring (r=214).
	draw_arc(CENTRE, 236.0, 0.0, TAU, 160, rim, 6.0, true)
	draw_arc(CENTRE, 214.0, 0.0, TAU, 160, Color(rim.r, rim.g, rim.b, 0.4), 2.0, true)

	# 3. Ash ring: 40 short arcs along r=225, alternating alpha, reading as a
	#    burnt paper edge.
	for i in range(40):
		var start: float = TAU * float(i) / 40.0
		var alpha: float = 0.85 if (i % 2) == 0 else 0.35
		draw_arc(CENTRE, 225.0, start, start + (TAU / 40.0) * 0.5, 4,
			Color(rim.r, rim.g, rim.b, alpha), 3.0, true)

	# 4. Sink hole (r=96) and the lounge-basket mark inside it.
	draw_circle(CENTRE, 96.0, Color(0.02, 0.04, 0.03))
	draw_arc(CENTRE, 96.0, 0.0, TAU, 96, rim, 4.0, true)
	for i in range(3):
		var bar := Rect2(CENTRE.x - 34.0, CENTRE.y - 18.0 + float(i) * 16.0, 68.0, 9.0)
		draw_rect(bar, Color(accent.r, accent.g, accent.b, 0.9 - 0.2 * float(i)))

	# 5. Burn arrows: eight chevrons on r=160, all pointing inward.
	for i in range(8):
		var angle: float = TAU * float(i) / 8.0
		var outward := Vector2(cos(angle), sin(angle))
		var perp := Vector2(-outward.y, outward.x)
		var base: Vector2 = CENTRE + outward * 160.0
		var tri := PackedVector2Array([
			base - outward * 12.0,
			base + outward * 6.0 + perp * 9.0,
			base + outward * 6.0 - perp * 9.0,
		])
		draw_colored_polygon(tri, accent)

	# 6. Word marks. draw_string with a width centres the text for us.
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	draw_string(font, Vector2(0.0, CENTRE.y - 26.0), "SMOKE",
		HORIZONTAL_ALIGNMENT_CENTER, DESIGN_SIZE, 44, accent)
	draw_string(font, Vector2(0.0, CENTRE.y + 12.0), "culture + sink",
		HORIZONTAL_ALIGNMENT_CENTER, DESIGN_SIZE, 28, rim)

	# 7. Four corner ticks on the outer ring at the 45-degree marks.
	for i in range(4):
		var angle: float = TAU * float(i) / 4.0 + TAU / 8.0
		var outward := Vector2(cos(angle), sin(angle))
		var outer: Vector2 = CENTRE + outward * 248.0
		var inner: Vector2 = CENTRE + outward * 222.0
		draw_line(inner, outer, rim, 5.0, true)


## Reads one "#rrggbb" colour out of the draw_spec, falling back when absent.
func _spec_color(key: String, fallback: Color) -> Color:
	var raw: Variant = draw_spec.get(key, null)
	if typeof(raw) != TYPE_STRING:
		return fallback
	var text: String = String(raw)
	if text.is_empty():
		return fallback
	return Color.from_string(text, fallback)
=== END ===
=== FILE: src/protocol_portals/WhitepaperJump.gd ===
extends Area2D
## Interaction zone that fronts the whitepaper plate in a study room.
##
## Two ways in, both of which simply ask the room to open its whitepaper
## overlay:
##   * the player presses "interact" while standing inside the zone;
##   * the player lands on the zone from above (above the zone centre and moving
##     down), which is what happens if they ever come down onto the lectern.
## The script owns no session state: the room owns the session, the pause and
## the UI. `room` may be null (the zone is inspectable in isolation by tests).

## The StudyRoom that owns this zone. Set by StudyRoom right after the node is
## built.
var room: Node = null

var _player_inside: bool = false
var _has_interact: bool = false


func _ready() -> void:
	_has_interact = InputMap.has_action("interact")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_inside = true
	var falling: bool = true
	if body is CharacterBody2D:
		falling = (body as CharacterBody2D).velocity.y >= 0.0
	if body.global_position.y <= global_position.y and falling:
		_open()


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = false


func _unhandled_input(event: InputEvent) -> void:
	if not _player_inside or not _has_interact:
		return
	if _room_busy():
		return
	if event.is_action_pressed("interact"):
		_open()


## True while the room has an overlay open (paused) — never stack a second one.
func _room_busy() -> bool:
	if room == null:
		return false
	if room.has_method("is_overlay_open"):
		return bool(room.call("is_overlay_open"))
	return false


func _open() -> void:
	if _room_busy():
		return
	if room != null and room.has_method("open_whitepaper"):
		room.call("open_whitepaper")
=== END ===
=== FILE: src/protocol_portals/VideoShrine.gd ===
extends Area2D
## Interaction zone that fronts the video shrine in a study room.
##
## Press "interact" inside the zone and the room opens its video overlay (which
## shell-opens the official X post and gates the DONE button on a minimum watch
## time). Nothing is downloaded, embedded or proxied here.
## `room` may be null — the zone is inspectable in isolation by tests.

## The StudyRoom that owns this zone.
var room: Node = null

var _player_inside: bool = false
var _has_interact: bool = false


func _ready() -> void:
	_has_interact = InputMap.has_action("interact")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = false


func _unhandled_input(event: InputEvent) -> void:
	if not _player_inside or not _has_interact:
		return
	if _room_busy():
		return
	if event.is_action_pressed("interact"):
		_open()


func _room_busy() -> bool:
	if room == null:
		return false
	if room.has_method("is_overlay_open"):
		return bool(room.call("is_overlay_open"))
	return false


func _open() -> void:
	if _room_busy():
		return
	if room != null and room.has_method("open_video"):
		room.call("open_video")
=== END ===
=== FILE: src/protocol_portals/Examiner.gd ===
extends Area2D
## Interaction zone that fronts the examiner prop in a study room.
##
## Press "interact" inside the zone and the room starts the examination: the
## examiner's three intro lines, then the eleven-question quiz.
##
## The Examiner is a prop and a prompt only. It NEVER mints, never touches
## ScorecardGrant and never sees a wallet: completion is the room's business.
## `room` may be null — the zone is inspectable in isolation by tests.

## The StudyRoom that owns this zone.
var room: Node = null
## Protocol id, kept so a future examiner variant can branch on it.
var protocol: String = ""

var _player_inside: bool = false
var _has_interact: bool = false


func _ready() -> void:
	_has_interact = InputMap.has_action("interact")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = false


func _unhandled_input(event: InputEvent) -> void:
	if not _player_inside or not _has_interact:
		return
	if _room_busy():
		return
	if event.is_action_pressed("interact"):
		_open()


func _room_busy() -> bool:
	if room == null:
		return false
	if room.has_method("is_overlay_open"):
		return bool(room.call("is_overlay_open"))
	return false


func _open() -> void:
	if _room_busy():
		return
	if room != null and room.has_method("start_exam"):
		room.call("start_exam")
=== END ===
=== FILE: src/protocol_portals/StudyRoom.gd ===
extends Node2D
## Protocol Portals step 3 — the study room underneath a glowing ladder.
##
## One screen, no platforming: LEFT is the whitepaper plate, RIGHT is the video
## shrine, and the examiner stands between them at floor level. Everything is
## built in code so the three protocol skins are one-line .tscn instances that
## only override `protocol` and `stage_id`.
##
## The room owns the PortalSession loop for the STUDY_CHOICE half of the run:
##   STUDY_CHOICE -> WHITEPAPER | VIDEO        (overlay, back to STUDY_CHOICE)
##   STUDY_CHOICE -> EXAMINER_INTRO -> QUIZ -> RESULT
##   RESULT -> QUIZ (retry) | ASCENT (leave at any time)
##
## It never mints, never networks and never talks to ICP. Completion only writes
## a local record through ScorecardGrant and hands the player back to the level
## through PortalTravel.ascend().

const SignalsScript := preload("res://src/protocol_portals/PortalSignals.gd")
const PortalSessionScript := preload("res://src/protocol_portals/PortalSession.gd")
const QuizBankScript := preload("res://src/protocol_portals/QuizBank.gd")
const Travel := preload("res://src/protocol_portals/PortalTravel.gd")
const Grant := preload("res://src/protocol_portals/ScorecardGrant.gd")
const SmokePlateScript := preload("res://src/protocol_portals/SmokePlate.gd")
const WhitepaperJumpScript := preload("res://src/protocol_portals/WhitepaperJump.gd")
const VideoShrineScript := preload("res://src/protocol_portals/VideoShrine.gd")
const ExaminerScript := preload("res://src/protocol_portals/Examiner.gd")

# ---- Configuration ----------------------------------------------------------

## Which protocol this room belongs to. Overridden by each skin scene.
@export var protocol: String = "smoke"
## Stage identity. Overridden by each skin scene.
@export var stage_id: int = 1

const ROOM_W: float = 1280.0
const ROOM_H: float = 720.0
const FLOOR_Y: float = 620.0
const PLAYER_SCENE: String = "res://src/player/player.tscn"
const COPY_PATH: String = "res://src/protocol_portals/data/portal_copy.json"

## Official study links. EXACTLY these, nothing else, ever.
const PAPER_URLS: Dictionary = {
	"smoke": "https://richs-crypto-projects.gitbook.io/smokering",
	"diamonds": "https://richs-crypto-projects.gitbook.io/diamonds",
	"gold": "https://richs-crypto-projects.gitbook.io/goldmine",
}
const VIDEO_URLS: Dictionary = {
	"smoke": "https://x.com/DefiSparco/status/2082090949086519703",
	"diamonds": "https://x.com/richland100/status/2003193678790283561",
	"gold": "https://x.com/richland100/status/2070925446124839334",
}

# ---- State ------------------------------------------------------------------

var session: PortalSessionScript = null
var bank: QuizBankScript = null

var _copy: Dictionary = {}
var _data: Dictionary = {}
var _glow: Color = Color(0.35, 1.0, 0.45)

var _ui_layer: CanvasLayer = null
var _overlay_root: Control = null
var _overlay_panel: Panel = null
var _overlay_box: VBoxContainer = null
var _overlay_open: bool = false
var _watch_timer: Timer = null
var _done_button: Button = null
var _primary_action: Callable = Callable()
var _quiz_active: bool = false
var _player_in_ascent: bool = false
var _intro_index: int = 0
var _q_index: int = 0
var _grant_recorded: bool = false


func _ready() -> void:
	# StudyRoom keeps receiving input while the tree is paused for an overlay,
	# so it processes always; the player is explicitly re-marked PAUSABLE right
	# after it is instanced, so a paused overlay really does freeze the room.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_glow = _glow_color()
	_copy = _load_copy()
	var raw: Variant = _copy.get(protocol, {})
	if typeof(raw) == TYPE_DICTIONARY:
		_data = raw

	_build_backdrop()
	_build_floor_and_walls()
	_build_divider()
	_build_ascent_shaft()
	_build_whitepaper_plate()
	_build_video_shrine()
	_build_examiner()
	_build_player()
	_build_ui()
	_start_session()


# ---- Copy -------------------------------------------------------------------

func _load_copy() -> Dictionary:
	if not FileAccess.file_exists(COPY_PATH):
		push_error("StudyRoom: copy file missing: %s" % COPY_PATH)
		return {}
	var file: FileAccess = FileAccess.open(COPY_PATH, FileAccess.READ)
	if file == null:
		push_error("StudyRoom: could not open %s (err %d)"
			% [COPY_PATH, FileAccess.get_open_error()])
		return {}
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("StudyRoom: %s is not a JSON object" % COPY_PATH)
		return {}
	return parsed


func _s(key: String, fallback: String = "") -> String:
	var value: Variant = _data.get(key, fallback)
	if value == null:
		return fallback
	return String(value)


func _s2(source: Dictionary, key: String, fallback: String = "") -> String:
	var value: Variant = source.get(key, fallback)
	if value == null:
		return fallback
	return String(value)


func _plate() -> Dictionary:
	var value: Variant = _data.get("plate", {})
	if typeof(value) == TYPE_DICTIONARY:
		return value
	return {}


# ---- Session ----------------------------------------------------------------

## Reuses the session PortalTravel opened for this protocol (the normal path
## when the player came down the ladder), otherwise opens one here so the room
## also works when loaded directly. Either way the session sits in STUDY_CHOICE
## once _ready is done.
func _start_session() -> void:
	var reuse: bool = false
	if Travel.session != null:
		reuse = String(Travel.session.get("protocol")) == protocol
	if reuse:
		session = Travel.session
	else:
		session = PortalSessionScript.begin(stage_id, protocol)
		Travel.session = session
	if session == null:
		push_error("StudyRoom: could not start a PortalSession for %s" % protocol)
		return
	if session.state == SignalsScript.State.WORLD:
		session.transition(SignalsScript.State.DESCENT)
	if session.state == SignalsScript.State.DESCENT:
		session.transition(SignalsScript.State.STUDY_CHOICE)


## Headless test hook: drives the session through the exam without any UI.
## Returns session.to_dict() so a test can assert on score / pass / completion.
func test_run(choices: Array[int]) -> Dictionary:
	if session == null:
		return {"error": "no session"}
	if bank == null:
		bank = QuizBankScript.load_bank(protocol)
	if bank == null:
		return {"error": "no quiz bank for %s" % protocol}
	if session.state == SignalsScript.State.STUDY_CHOICE:
		session.transition(SignalsScript.State.EXAMINER_INTRO)
	if session.state == SignalsScript.State.EXAMINER_INTRO:
		session.transition(SignalsScript.State.QUIZ)
	if session.state != SignalsScript.State.QUIZ:
		return {"error": "session not in QUIZ (state %d)" % session.state}
	for i in range(SignalsScript.QUESTION_COUNT):
		var choice: int = choices[i] if i < choices.size() else -1
		if choice < 0:
			continue
		session.answer(i, choice)
	session.grade(bank.answer_key())
	if session.state == SignalsScript.State.QUIZ:
		session.transition(SignalsScript.State.RESULT)
	return session.to_dict()


## True while any overlay is open (the tree is paused). Used by the interaction
## zones so a second overlay can never stack.
func is_overlay_open() -> bool:
	return _overlay_open


# ---- Backdrop ---------------------------------------------------------------

func _glow_color() -> Color:
	match protocol:
		"diamonds":
			return Color(0.35, 0.95, 1.0)
		"gold":
			return Color(1.0, 0.9, 0.45)
		_:
			return Color(0.35, 1.0, 0.45)


func _top_color() -> Color:
	match protocol:
		"diamonds":
			return Color(0.03, 0.07, 0.17)
		"gold":
			return Color(0.14, 0.09, 0.05)
		_:
			return Color(0.05, 0.13, 0.09)


func _bottom_color() -> Color:
	match protocol:
		"diamonds":
			return Color(0.01, 0.02, 0.06)
		"gold":
			return Color(0.05, 0.03, 0.02)
		_:
			return Color(0.02, 0.05, 0.04)


func _slab_color() -> Color:
	match protocol:
		"diamonds":
			return Color(0.02, 0.04, 0.09)
		"gold":
			return Color(0.09, 0.06, 0.035)
		_:
			return Color(0.03, 0.06, 0.045)


## Vertical gradient + vignette + slow drifting motes. All CPUParticles2D (never
## GPU): the HTML5 non-threaded target has no reliable GPU particles.
func _build_backdrop() -> void:
	var layer := Node2D.new()
	layer.name = "Backdrop"
	layer.z_index = -100
	add_child(layer)

	var grad := Gradient.new()
	grad.set_color(0, _top_color())
	grad.set_color(1, _bottom_color())
	var grad_tex := GradientTexture2D.new()
	grad_tex.gradient = grad
	grad_tex.fill = GradientTexture2D.FILL_LINEAR
	grad_tex.fill_from = Vector2(0.0, 0.0)
	grad_tex.fill_to = Vector2(0.0, 1.0)
	grad_tex.width = 8
	grad_tex.height = 256
	var bg := TextureRect.new()
	bg.name = "Gradient"
	bg.texture = grad_tex
	bg.position = Vector2.ZERO
	bg.size = Vector2(ROOM_W, ROOM_H)
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	layer.add_child(bg)

	var vig_grad := Gradient.new()
	vig_grad.set_color(0, Color(0.0, 0.0, 0.0, 0.0))
	vig_grad.set_color(1, Color(0.0, 0.0, 0.0, 0.6))
	var vig_tex := GradientTexture2D.new()
	vig_tex.gradient = vig_grad
	vig_tex.fill = GradientTexture2D.FILL_RADIAL
	vig_tex.fill_from = Vector2(0.5, 0.5)
	vig_tex.fill_to = Vector2(0.5, 0.0)
	vig_tex.width = int(ROOM_W)
	vig_tex.height = int(ROOM_H)
	var vignette := TextureRect.new()
	vignette.name = "Vignette"
	vignette.texture = vig_tex
	vignette.position = Vector2.ZERO
	vignette.size = Vector2(ROOM_W, ROOM_H)
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	layer.add_child(vignette)

	var motes := CPUParticles2D.new()
	motes.name = "Motes"
	motes.texture = _make_square_texture(2)
	motes.amount = 26
	motes.lifetime = 9.0
	motes.local_coords = false
	motes.position = Vector2(ROOM_W * 0.5, ROOM_H * 0.5)
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2(ROOM_W * 0.5, ROOM_H * 0.4)
	motes.direction = Vector2(0.0, -1.0)
	motes.spread = 40.0
	motes.gravity = Vector2.ZERO
	motes.initial_velocity_min = 5.0
	motes.initial_velocity_max = 18.0
	motes.scale_amount_min = 2.0
	motes.scale_amount_max = 4.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(_glow.r, _glow.g, _glow.b, 0.0))
	ramp.set_color(1, Color(_glow.r, _glow.g, _glow.b, 0.35))
	motes.color_ramp = ramp
	layer.add_child(motes)


func _make_square_texture(side: int) -> ImageTexture:
	var img: Image = Image.create(side, side, false, Image.FORMAT_RGBA8)
	img.fill(Color(1.0, 1.0, 1.0, 1.0))
	return ImageTexture.create_from_image(img)


# ---- Floor ------------------------------------------------------------------

## Solid floor across the room (top surface exactly at FLOOR_Y) plus two off
## screen side walls, so the player can never run out of the pocket.
func _build_floor_and_walls() -> void:
	var slab := ColorRect.new()
	slab.name = "FloorSlab"
	slab.position = Vector2(0.0, FLOOR_Y)
	slab.size = Vector2(ROOM_W, ROOM_H - FLOOR_Y)
	slab.color = _slab_color()
	slab.z_index = -50
	add_child(slab)

	var trim := ColorRect.new()
	trim.name = "FloorTrim"
	trim.position = Vector2(0.0, FLOOR_Y - 3.0)
	trim.size = Vector2(ROOM_W, 3.0)
	trim.color = Color(_glow.r, _glow.g, _glow.b, 0.55)
	trim.z_index = -49
	add_child(trim)

	var floor_body := StaticBody2D.new()
	floor_body.name = "Floor"
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	floor_body.position = Vector2(ROOM_W * 0.5, FLOOR_Y + 20.0)
	var floor_shape := CollisionShape2D.new()
	floor_shape.name = "CollisionShape2D"
	var floor_rect := RectangleShape2D.new()
	floor_rect.size = Vector2(ROOM_W, 40.0)
	floor_shape.shape = floor_rect
	floor_body.add_child(floor_shape)
	add_child(floor_body)

	var walls := StaticBody2D.new()
	walls.name = "Walls"
	walls.collision_layer = 1
	walls.collision_mask = 0
	var wall_xs: Array[float] = [-20.0, ROOM_W + 20.0]
	for i in range(wall_xs.size()):
		var wall_shape := CollisionShape2D.new()
		wall_shape.name = "WallShape%d" % i
		var wall_rect := RectangleShape2D.new()
		wall_rect.size = Vector2(40.0, ROOM_H + 200.0)
		wall_shape.shape = wall_rect
		wall_shape.position = Vector2(wall_xs[i], ROOM_H * 0.5)
		walls.add_child(wall_shape)
	add_child(walls)


# ---- Divider ----------------------------------------------------------------

## One crisp 3px line splitting LEFT (paper) from RIGHT (video). Deliberately a
## single Line2D with two points: no second edge, no seam, no taper.
func _build_divider() -> void:
	var line := Line2D.new()
	line.name = "Divider"
	line.width = 3.0
	line.default_color = Color(_glow.r, _glow.g, _glow.b, 0.6)
	line.joint_mode = Line2D.LINE_JOINT_SHARP
	line.points = PackedVector2Array([Vector2(640.0, 140.0), Vector2(640.0, FLOOR_Y)])
	line.z_index = -40
	add_child(line)


# ---- Ascent shaft -----------------------------------------------------------

## The way home: the same glow colour as the ladder down in the level, rails
## climbing up and out of the top of the frame, an always-visible "CLIMB BACK"
## prompt and the AscentShaft area at the base. Leaving is allowed at ANY time.
func _build_ascent_shaft() -> void:
	var rails := Node2D.new()
	rails.name = "AscentRails"
	rails.z_index = -30
	add_child(rails)

	var shaft_color: Color = _glow
	var offsets: Array[float] = [-14.0, 14.0]
	for i in range(offsets.size()):
		var rail := Line2D.new()
		rail.name = "Rail%d" % i
		rail.width = 4.0
		rail.default_color = shaft_color
		rail.points = PackedVector2Array([
			Vector2(640.0 + offsets[i], -40.0),
			Vector2(640.0 + offsets[i], 560.0),
		])
		rails.add_child(rail)

	var y: float = -30.0
	var rung_index: int = 0
	while y < 552.0:
		var rung := Line2D.new()
		rung.name = "Rung%d" % rung_index
		rung.width = 4.0
		rung.default_color = shaft_color.darkened(0.15)
		rung.points = PackedVector2Array([Vector2(626.0, y), Vector2(654.0, y)])
		rails.add_child(rung)
		rung_index += 1
		y += 26.0

	var label := Label.new()
	label.name = "AscentLabel"
	label.text = "CLIMB BACK  [E]"
	label.size = Vector2(240.0, 38.0)
	label.position = Vector2(376.0, 540.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", shaft_color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	label.add_theme_constant_override("outline_size", 8)
	label.add_theme_stylebox_override("normal", _backing_style())
	label.z_index = 5
	add_child(label)

	var area := Area2D.new()
	area.name = "AscentShaft"
	area.collision_layer = 0
	area.collision_mask = 2
	area.position = Vector2(640.0, 570.0)
	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var rect := RectangleShape2D.new()
	rect.size = Vector2(100.0, 130.0)
	shape.shape = rect
	area.add_child(shape)
	area.body_entered.connect(_on_ascent_body_entered)
	area.body_exited.connect(_on_ascent_body_exited)
	add_child(area)

	var motes := CPUParticles2D.new()
	motes.name = "ShaftMotes"
	motes.texture = _make_square_texture(2)
	motes.amount = 16
	motes.lifetime = 2.0
	motes.local_coords = false
	motes.position = Vector2(640.0, 560.0)
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2(28.0, 16.0)
	motes.direction = Vector2(0.0, -1.0)
	motes.spread = 10.0
	motes.gravity = Vector2.ZERO
	motes.initial_velocity_min = 30.0
	motes.initial_velocity_max = 70.0
	motes.scale_amount_min = 2.0
	motes.scale_amount_max = 4.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(_glow.r, _glow.g, _glow.b, 0.9))
	ramp.set_color(1, Color(_glow.r, _glow.g, _glow.b, 0.0))
	motes.color_ramp = ramp
	motes.z_index = -29
	add_child(motes)


func _on_ascent_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_ascent = true


func _on_ascent_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_ascent = false


# ---- Whitepaper plate (LEFT, x ~ 300) ---------------------------------------

## A lectern holding the plate. Smoke renders the plate in code (SmokePlate);
## diamonds and gold hang the founder JPEG, framed and shadowed.
func _build_whitepaper_plate() -> void:
	var holder := Node2D.new()
	holder.name = "WhitepaperPlate"
	holder.position = Vector2(300.0, FLOOR_Y)
	add_child(holder)

	var lectern := Polygon2D.new()
	lectern.name = "Lectern"
	lectern.polygon = PackedVector2Array([
		Vector2(-90.0, 0.0),
		Vector2(90.0, 0.0),
		Vector2(58.0, -150.0),
		Vector2(-58.0, -150.0),
	])
	lectern.color = _slab_color().lightened(0.08)
	holder.add_child(lectern)

	var lectern_top := Polygon2D.new()
	lectern_top.name = "LecternTop"
	lectern_top.polygon = PackedVector2Array([
		Vector2(-74.0, -150.0),
		Vector2(74.0, -150.0),
		Vector2(66.0, -162.0),
		Vector2(-66.0, -162.0),
	])
	lectern_top.color = _slab_color().lightened(0.18)
	holder.add_child(lectern_top)

	if protocol == "smoke":
		var plate := Node2D.new()
		plate.name = "PlateArt"
		plate.set_script(SmokePlateScript)
		plate.position = Vector2(0.0, -250.0)
		plate.scale = Vector2(0.55, 0.55)
		var spec: Variant = _plate().get("draw_spec", {})
		if typeof(spec) == TYPE_DICTIONARY:
			plate.set("draw_spec", spec)
		holder.add_child(plate)
	else:
		holder.add_child(_build_plate_art(
			"res://src/assets/portals/plate_%s_whitepaper.jpg" % protocol,
			Vector2(0.0, -250.0), 300.0))

	var label := Label.new()
	label.name = "PaperLabel"
	label.text = _s("paper_label", "Read the Whitepaper")
	label.size = Vector2(300.0, 40.0)
	label.position = Vector2(-150.0, -470.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", _glow)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	label.add_theme_constant_override("outline_size", 8)
	label.add_theme_stylebox_override("normal", _backing_style())
	holder.add_child(label)

	var zone := Area2D.new()
	zone.set_script(WhitepaperJumpScript)
	zone.name = "WhitepaperJumpZone"
	zone.collision_layer = 0
	zone.collision_mask = 2
	zone.position = Vector2(0.0, -160.0)
	zone.set("room", self)
	var zone_shape := CollisionShape2D.new()
	zone_shape.name = "CollisionShape2D"
	var zone_rect := RectangleShape2D.new()
	zone_rect.size = Vector2(280.0, 320.0)
	zone_shape.shape = zone_rect
	zone.add_child(zone_shape)
	holder.add_child(zone)


## Founder art, centred, with a drop shadow behind it and a glow-colour frame
## around it. Falls back to a plain dark card if the texture is missing.
func _build_plate_art(texture_path: String, centre: Vector2, target_width: float) -> Node2D:
	var holder := Node2D.new()
	holder.name = "PlateArt"
	holder.position = centre

	var art_size := Vector2(target_width, 200.0)
	var sprite: Sprite2D = null
	if ResourceLoader.exists(texture_path):
		var tex: Texture2D = load(texture_path)
		if tex != null and tex.get_width() > 0:
			sprite = Sprite2D.new()
			sprite.name = "PlateTexture"
			sprite.texture = tex
			var factor: float = target_width / float(tex.get_width())
			sprite.scale = Vector2(factor, factor)
			art_size = Vector2(float(tex.get_width()) * factor, float(tex.get_height()) * factor)
	else:
		push_warning("StudyRoom: plate texture missing: %s" % texture_path)

	var half := art_size * 0.5

	var shadow := ColorRect.new()
	shadow.name = "PlateShadow"
	shadow.position = Vector2(-half.x + 10.0, -half.y + 12.0)
	shadow.size = art_size
	shadow.color = Color(0.0, 0.0, 0.0, 0.45)
	holder.add_child(shadow)

	if sprite != null:
		holder.add_child(sprite)
	else:
		var card := ColorRect.new()
		card.name = "PlateFallback"
		card.position = -half
		card.size = art_size
		card.color = _slab_color().lightened(0.05)
		holder.add_child(card)

	var frame := Line2D.new()
	frame.name = "PlateFrame"
	frame.width = 3.0
	frame.default_color = Color(_glow.r, _glow.g, _glow.b, 0.85)
	frame.closed = true
	frame.points = PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y),
	])
	holder.add_child(frame)
	return holder


# ---- Video shrine (RIGHT, x ~ 980) ------------------------------------------

## A small shrine: stone arch, a screen with a drawn play triangle and the
## video label above it. The triangle is a Polygon2D — the game font has no
## play glyph.
func _build_video_shrine() -> void:
	var holder := Node2D.new()
	holder.name = "VideoShrine"
	holder.position = Vector2(980.0, FLOOR_Y)
	add_child(holder)

	var arch := Polygon2D.new()
	arch.name = "Arch"
	arch.polygon = PackedVector2Array([
		Vector2(-80.0, 0.0),
		Vector2(80.0, 0.0),
		Vector2(80.0, -140.0),
		Vector2(0.0, -200.0),
		Vector2(-80.0, -140.0),
	])
	arch.color = _slab_color().lightened(0.06)
	holder.add_child(arch)

	var screen := Polygon2D.new()
	screen.name = "Screen"
	screen.polygon = PackedVector2Array([
		Vector2(-90.0, -150.0),
		Vector2(90.0, -150.0),
		Vector2(90.0, -30.0),
		Vector2(-90.0, -30.0),
	])
	screen.color = Color(0.02, 0.03, 0.05, 0.95)
	screen.z_index = 1
	holder.add_child(screen)

	var screen_frame := Line2D.new()
	screen_frame.name = "ScreenFrame"
	screen_frame.width = 3.0
	screen_frame.default_color = Color(_glow.r, _glow.g, _glow.b, 0.85)
	screen_frame.closed = true
	screen_frame.points = PackedVector2Array([
		Vector2(-90.0, -150.0),
		Vector2(90.0, -150.0),
		Vector2(90.0, -30.0),
		Vector2(-90.0, -30.0),
	])
	screen_frame.z_index = 2
	holder.add_child(screen_frame)

	var play := Polygon2D.new()
	play.name = "PlayTriangle"
	play.polygon = PackedVector2Array([
		Vector2(-16.0, -26.0),
		Vector2(-16.0, 26.0),
		Vector2(26.0, 0.0),
	])
	play.color = Color(_glow.r, _glow.g, _glow.b, 0.95)
	play.position = Vector2(0.0, -90.0)
	play.z_index = 3
	holder.add_child(play)

	var label := Label.new()
	label.name = "VideoLabel"
	label.text = _s("video_label", "Watch the Video")
	label.size = Vector2(300.0, 40.0)
	label.position = Vector2(-150.0, -300.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", _glow)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	label.add_theme_constant_override("outline_size", 8)
	label.add_theme_stylebox_override("normal", _backing_style())
	holder.add_child(label)

	var zone := Area2D.new()
	zone.set_script(VideoShrineScript)
	zone.name = "VideoShrineZone"
	zone.collision_layer = 0
	zone.collision_mask = 2
	zone.position = Vector2(0.0, -110.0)
	zone.set("room", self)
	var zone_shape := CollisionShape2D.new()
	zone_shape.name = "CollisionShape2D"
	var zone_rect := RectangleShape2D.new()
	zone_rect.size = Vector2(240.0, 300.0)
	zone_shape.shape = zone_rect
	zone.add_child(zone_shape)
	holder.add_child(zone)


# ---- Examiner (CENTRE-RIGHT, x ~ 780) ---------------------------------------

## A protocol-specific Polygon2D prop plus the examiner's name. Smoke: Ember,
## a robed archivist with a green lamp. Diamonds: the Assay Trio, three crystal
## figures. Gold: the Claim Recorder at a small desk with a stamp and ledger.
## Purely decorative plus an interaction zone — no minting anywhere near it.
func _build_examiner() -> void:
	var holder := Node2D.new()
	holder.name = "Examiner"
	holder.position = Vector2(780.0, FLOOR_Y)
	add_child(holder)

	var prop := Node2D.new()
	prop.name = "ExaminerProp"
	holder.add_child(prop)
	match protocol:
		"diamonds":
			_build_assay_trio(prop)
		"gold":
			_build_claim_recorder(prop)
		_:
			_build_ember(prop)

	var label := Label.new()
	label.name = "ExaminerLabel"
	label.text = _s("examiner_name", "Examiner")
	label.size = Vector2(260.0, 34.0)
	label.position = Vector2(-130.0, -262.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", _glow)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	label.add_theme_constant_override("outline_size", 8)
	label.add_theme_stylebox_override("normal", _backing_style())
	holder.add_child(label)

	var zone := Area2D.new()
	zone.set_script(ExaminerScript)
	zone.name = "ExaminerZone"
	zone.collision_layer = 0
	zone.collision_mask = 2
	zone.position = Vector2(0.0, -110.0)
	zone.set("room", self)
	zone.set("protocol", protocol)
	var zone_shape := CollisionShape2D.new()
	zone_shape.name = "CollisionShape2D"
	var zone_rect := RectangleShape2D.new()
	zone_rect.size = Vector2(160.0, 300.0)
	zone_shape.shape = zone_rect
	zone.add_child(zone_shape)
	holder.add_child(zone)


## Ember: a hooded, robed figure with a small green lamp on a stand.
func _build_ember(parent: Node2D) -> void:
	var robe := Color(0.10, 0.16, 0.12)
	var robe_light := Color(0.16, 0.26, 0.19)
	_add_poly(parent, "Robe", PackedVector2Array([
		Vector2(-52.0, 0.0), Vector2(52.0, 0.0),
		Vector2(34.0, -104.0), Vector2(-34.0, -104.0),
	]), robe)
	_add_poly(parent, "Hood", PackedVector2Array([
		Vector2(-30.0, -100.0), Vector2(30.0, -100.0),
		Vector2(22.0, -168.0), Vector2(-22.0, -168.0),
	]), robe_light)
	_add_poly(parent, "Face", _circle_polygon(15.0, 18), Color(0.24, 0.34, 0.26), Vector2(0.0, -140.0))
	_add_poly(parent, "LampStand", PackedVector2Array([
		Vector2(62.0, 0.0), Vector2(70.0, 0.0),
		Vector2(70.0, -62.0), Vector2(62.0, -62.0),
	]), robe)
	_add_poly(parent, "Lamp", _circle_polygon(15.0, 20), Color(_glow.r, _glow.g, _glow.b, 0.95), Vector2(66.0, -74.0))
	_add_poly(parent, "LampHalo", _circle_polygon(28.0, 24), Color(_glow.r, _glow.g, _glow.b, 0.18), Vector2(66.0, -74.0))


## The Assay Trio: three crystal figures side by side, CUT / WEIGH / STAMP.
func _build_assay_trio(parent: Node2D) -> void:
	var body_color := Color(0.10, 0.22, 0.32)
	var xs: Array[float] = [-76.0, 0.0, 76.0]
	for i in range(xs.size()):
		var x: float = xs[i]
		var tint: float = 0.10 + 0.06 * float(i)
		_add_poly(parent, "Crystal%d" % i, PackedVector2Array([
			Vector2(x, 0.0),
			Vector2(x + 20.0, -48.0),
			Vector2(x, -118.0),
			Vector2(x - 20.0, -48.0),
		]), body_color.lightened(tint))
		_add_poly(parent, "Head%d" % i, _circle_polygon(12.0, 16),
			Color(_glow.r, _glow.g, _glow.b, 0.9), Vector2(x, -132.0))
		_add_poly(parent, "Rune%d" % i, PackedVector2Array([
			Vector2(x - 6.0, -70.0), Vector2(x + 6.0, -70.0),
			Vector2(x + 6.0, -62.0), Vector2(x - 6.0, -62.0),
		]), Color(0.75, 0.9, 1.0, 0.8))


## The Claim Recorder: clerk behind a small desk with a ledger and a stamp.
func _build_claim_recorder(parent: Node2D) -> void:
	var clerk := Color(0.22, 0.15, 0.09)
	var desk := Color(0.30, 0.20, 0.11)
	_add_poly(parent, "ClerkBody", PackedVector2Array([
		Vector2(-22.0, -70.0), Vector2(26.0, -70.0),
		Vector2(20.0, -142.0), Vector2(-14.0, -142.0),
	]), clerk)
	_add_poly(parent, "ClerkHead", _circle_polygon(16.0, 18), clerk.lightened(0.18), Vector2(4.0, -160.0))
	_add_poly(parent, "Desk", PackedVector2Array([
		Vector2(-84.0, 0.0), Vector2(84.0, 0.0),
		Vector2(84.0, -72.0), Vector2(-84.0, -72.0),
	]), desk)
	_add_poly(parent, "Ledger", PackedVector2Array([
		Vector2(-46.0, -76.0), Vector2(14.0, -76.0),
		Vector2(14.0, -66.0), Vector2(-46.0, -66.0),
	]), Color(0.85, 0.80, 0.62))
	_add_poly(parent, "Stamp", PackedVector2Array([
		Vector2(48.0, -96.0), Vector2(64.0, -96.0),
		Vector2(64.0, -84.0), Vector2(48.0, -84.0),
	]), Color(_glow.r, _glow.g, _glow.b, 0.95))


func _add_poly(parent: Node2D, node_name: String, points: PackedVector2Array, color: Color, offset: Vector2 = Vector2.ZERO) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.name = node_name
	poly.polygon = points
	poly.color = color
	poly.position = offset
	parent.add_child(poly)
	return poly


func _circle_polygon(radius: float, segments: int = 20) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(segments):
		var angle: float = TAU * float(i) / float(segments)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points


# ---- Player -----------------------------------------------------------------

## The room is one screen wide, so the player's own camera is clamped to the
## room rectangle and left at 1:1 zoom. No extra Camera2D is created here.
func _build_player() -> void:
	if not ResourceLoader.exists(PLAYER_SCENE):
		push_error("StudyRoom: player scene missing: %s" % PLAYER_SCENE)
		return
	var packed: PackedScene = load(PLAYER_SCENE)
	if packed == null:
		push_error("StudyRoom: could not load %s" % PLAYER_SCENE)
		return
	var player: Node2D = packed.instantiate()
	player.name = "Player"
	player.position = Vector2(640.0, 560.0)
	player.add_to_group("player")
	# Explicitly pausable: StudyRoom itself processes always so it can keep
	# handling overlay input, and PROCESS_MODE_INHERIT would drag the player
	# along with it.
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)

	var camera: Camera2D = _find_camera(player)
	if camera != null:
		camera.limit_left = 0
		camera.limit_top = 0
		camera.limit_right = int(ROOM_W)
		camera.limit_bottom = int(ROOM_H)
		camera.zoom = Vector2.ONE


func _find_camera(root: Node) -> Camera2D:
	if root is Camera2D:
		return root as Camera2D
	for child in root.get_children():
		var found: Camera2D = _find_camera(child)
		if found != null:
			return found
	return null


# ---- UI ---------------------------------------------------------------------

func _build_ui() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "UI"
	_ui_layer.layer = 20
	# ALWAYS so an overlay keeps working while get_tree().paused is true.
	_ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_ui_layer)

	_overlay_root = Control.new()
	_overlay_root.name = "OverlayRoot"
	_overlay_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay_root.visible = false
	_ui_layer.add_child(_overlay_root)

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	_overlay_root.add_child(dim)

	_overlay_panel = Panel.new()
	_overlay_panel.name = "Panel"
	_overlay_panel.position = Vector2(260.0, 100.0)
	_overlay_panel.size = Vector2(760.0, 520.0)
	_overlay_panel.add_theme_stylebox_override("panel", _panel_style())
	_overlay_root.add_child(_overlay_panel)

	_overlay_box = VBoxContainer.new()
	_overlay_box.name = "Box"
	_overlay_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay_box.offset_left = 28.0
	_overlay_box.offset_top = 28.0
	_overlay_box.offset_right = -28.0
	_overlay_box.offset_bottom = -28.0
	_overlay_box.add_theme_constant_override("separation", 14)
	_overlay_panel.add_child(_overlay_box)

	# Counts the minimum watch time with an always-processing timer.
	_watch_timer = Timer.new()
	_watch_timer.name = "VideoWatchTimer"
	_watch_timer.one_shot = true
	_watch_timer.wait_time = SignalsScript.VIDEO_MIN_WATCH_SEC
	_watch_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_watch_timer.timeout.connect(_on_watch_timeout)
	_ui_layer.add_child(_watch_timer)


func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.06, 0.96)
	sb.border_color = Color(_glow.r, _glow.g, _glow.b, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(0.0)
	sb.shadow_color = Color(_glow.r, _glow.g, _glow.b, 0.18)
	sb.shadow_size = 10
	return sb


func _button_style(hovered: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(_glow.r, _glow.g, _glow.b, 0.18 if hovered else 0.08)
	sb.border_color = Color(_glow.r, _glow.g, _glow.b, 1.0 if hovered else 0.6)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(10.0)
	return sb


func _backing_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.0, 0.0, 0.6)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(6.0)
	return sb


## Opens the shared overlay shell: wipes previous content, shows the panel and
## pauses the tree (the player must stop while reading).
func _open_overlay() -> void:
	_clear_overlay()
	_overlay_open = true
	_overlay_root.visible = true
	get_tree().paused = true


func _clear_overlay() -> void:
	for child in _overlay_box.get_children():
		_overlay_box.remove_child(child)
		child.queue_free()
	_primary_action = Callable()
	_quiz_active = false
	_done_button = null
	if _watch_timer != null:
		_watch_timer.stop()


## Closes the overlay shell and unpauses. The session move back to STUDY_CHOICE
## is done by the callers that changed it.
func _close_overlay_ui() -> void:
	_clear_overlay()
	_overlay_open = false
	_overlay_root.visible = false
	get_tree().paused = false


func _add_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(704.0, 0.0)
	_overlay_box.add_child(label)
	return label


func _add_button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0.0, 46.0)
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color", Color(0.92, 0.96, 0.96))
	button.add_theme_stylebox_override("normal", _button_style(false))
	button.add_theme_stylebox_override("hover", _button_style(true))
	button.add_theme_stylebox_override("pressed", _button_style(true))
	if action.is_valid():
		button.pressed.connect(action)
	_overlay_box.add_child(button)
	return button


# ---- Overlay: whitepaper ----------------------------------------------------

## LEFT plate overlay. STUDY_CHOICE -> WHITEPAPER, then back on EXIT.
func open_whitepaper() -> void:
	if _overlay_open or session == null:
		return
	if session.state == SignalsScript.State.STUDY_CHOICE:
		session.choose_study("whitepaper")
	_open_overlay()
	var plate: Dictionary = _plate()
	_add_label(_s("paper_label", "Read the Whitepaper"), 26, _glow)
	_add_label(_s2(plate, "title"), 22, Color(0.95, 0.98, 0.98))
	_add_label(_s2(plate, "subtitle"), 20, Color(0.78, 0.84, 0.84))
	_add_label(_s2(plate, "design_notes"), 18, Color(0.66, 0.72, 0.72))
	_add_button("OPEN WHITEPAPER", _on_open_paper)
	_add_button("EXIT", close_overlay)


func _on_open_paper() -> void:
	# Opens a browser tab on web; the URL list is fixed and official.
	OS.shell_open(String(PAPER_URLS.get(protocol, "")))


## Closes any study overlay and walks the session back to STUDY_CHOICE.
func close_overlay() -> void:
	if session != null:
		if session.state == SignalsScript.State.WHITEPAPER or session.state == SignalsScript.State.VIDEO:
			session.transition(SignalsScript.State.STUDY_CHOICE)
	_close_overlay_ui()


# ---- Overlay: video ---------------------------------------------------------

## RIGHT shrine overlay. STUDY_CHOICE -> VIDEO, DONE gated on the minimum watch
## time so a video-only player can never be blocked out of the loop.
func open_video() -> void:
	if _overlay_open or session == null:
		return
	if session.state == SignalsScript.State.STUDY_CHOICE:
		session.choose_study("video")
	_open_overlay()
	_add_label(_s("video_label", "Watch the Video"), 26, _glow)
	_add_label(_s("video_wait_line"), 20, Color(0.85, 0.90, 0.90))
	_add_button("WATCH ON X", _on_open_video)
	_done_button = _add_button("DONE", close_overlay)
	_done_button.disabled = true
	if _watch_timer != null:
		_watch_timer.start(SignalsScript.VIDEO_MIN_WATCH_SEC)


func _on_open_video() -> void:
	OS.shell_open(String(VIDEO_URLS.get(protocol, "")))


func _on_watch_timeout() -> void:
	if _done_button != null and is_instance_valid(_done_button):
		_done_button.disabled = false


# ---- Overlay: examiner, quiz, result ----------------------------------------

## EXAMINER_INTRO: the three intro lines, one at a time, then the quiz intro.
func start_exam() -> void:
	if _overlay_open or session == null:
		return
	if bank == null:
		bank = QuizBankScript.load_bank(protocol)
	if session.state == SignalsScript.State.STUDY_CHOICE:
		session.transition(SignalsScript.State.EXAMINER_INTRO)
	_intro_index = 0
	_show_intro()


func _show_intro() -> void:
	_open_overlay()
	if bank == null:
		bank = QuizBankScript.load_bank(protocol)
	var intro: Array = []
	var raw: Variant = _data.get("examiner_intro", [])
	if typeof(raw) == TYPE_ARRAY:
		intro = raw
	if _intro_index < intro.size():
		_add_label(_s("examiner_name", "Examiner"), 26, _glow)
		_add_label(String(intro[_intro_index]), 22, Color(0.92, 0.95, 0.95))
		_add_label("%d / %d" % [_intro_index + 1, intro.size()], 16, Color(0.62, 0.68, 0.68))
		_primary_action = _on_intro_next
		_add_button("NEXT  [E]", _on_intro_next)
	else:
		_add_label(_s("examiner_name", "Examiner"), 26, _glow)
		_add_label(_s("quiz_intro"), 22, Color(0.92, 0.95, 0.95))
		_primary_action = _begin_quiz
		_add_button("BEGIN QUIZ  [E]", _begin_quiz)


func _on_intro_next() -> void:
	_intro_index += 1
	_show_intro()


func _begin_quiz() -> void:
	if session != null and session.state == SignalsScript.State.EXAMINER_INTRO:
		session.transition(SignalsScript.State.QUIZ)
	_q_index = 0
	_show_question()


func _show_question() -> void:
	_open_overlay()
	if bank == null:
		return
	var question: Dictionary = bank.question(_q_index)
	_add_label("Question %d / %d" % [_q_index + 1, SignalsScript.QUESTION_COUNT],
		18, Color(0.66, 0.74, 0.74))
	_add_label(String(question.get("prompt", "")), 24, Color(0.95, 0.98, 0.98))
	var options: Array = []
	var raw: Variant = question.get("options", [])
	if typeof(raw) == TYPE_ARRAY:
		options = raw
	for i in range(options.size()):
		_add_button("%d) %s" % [i + 1, String(options[i])], _on_option.bind(i))
	# Keys 1/2/3 are handled in _unhandled_input; E is not a valid answer.
	_primary_action = Callable()
	_quiz_active = true


func _on_option(index: int) -> void:
	if session == null:
		return
	_quiz_active = false
	session.answer(_q_index, index)
	_q_index += 1
	if _q_index >= SignalsScript.QUESTION_COUNT:
		_finish_quiz()
	else:
		_show_question()


func _finish_quiz() -> void:
	_quiz_active = false
	if session == null or bank == null:
		return
	session.grade(bank.answer_key())
	if session.state == SignalsScript.State.QUIZ:
		session.transition(SignalsScript.State.RESULT)
	_grant_once()
	_show_result()


## Completion — pass or proceed — earns scorecard eligibility exactly once.
func _grant_once() -> void:
	if _grant_recorded or session == null:
		return
	if not session.eligible_for_scorecard():
		return
	Grant.mark_eligible(session)
	_grant_recorded = true


func _show_result() -> void:
	_open_overlay()
	if session == null:
		return
	_add_label("Score: %d / %d" % [session.score_correct, SignalsScript.QUESTION_COUNT],
		30, _glow)
	_add_label(_s("pass_line" if session.passed else "fail_line"), 22, Color(0.94, 0.96, 0.96))
	if not session.passed and not session.proceeded_without_pass:
		_add_button(_s("retry_label", "Retry the Quiz"), _on_retry)
		_add_button(_s("proceed_label", "Keep Score and Go"), _on_proceed)
	else:
		_add_label(_s("ascent_line"), 20, Color(0.80, 0.88, 0.88))
		_add_button("CLIMB BACK", _on_climb_back)


func _on_retry() -> void:
	if session == null:
		return
	if session.state == SignalsScript.State.RESULT:
		session.transition(SignalsScript.State.QUIZ)
	_q_index = 0
	_show_question()


func _on_proceed() -> void:
	if session == null:
		return
	session.proceed_without_pass()
	_grant_once()
	_show_result()


func _on_climb_back() -> void:
	_close_overlay_ui()
	Travel.ascend()


# ---- Input ------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if _overlay_open:
		_handle_overlay_input(event)
		return
	if not _player_in_ascent:
		return
	if not InputMap.has_action("interact"):
		return
	if event.is_action_pressed("interact"):
		# Leaving is allowed at any point in the loop.
		Travel.ascend()


func _handle_overlay_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and _primary_action.is_valid():
		_primary_action.call()
		return
	if _quiz_active and event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed or key.echo:
			return
		match key.keycode:
			KEY_1:
				_on_option(0)
			KEY_2:
				_on_option(1)
			KEY_3:
				_on_option(2)
=== END ===
=== FILE: src/protocol_portals/StudyRoom.tscn ===
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/protocol_portals/StudyRoom.gd" id="1_studyroom"]

[node name="StudyRoom" type="Node2D"]
script = ExtResource("1_studyroom")
protocol = "smoke"
stage_id = 1
=== END ===
=== FILE: src/protocol_portals/rooms/smoke/ReadingRing.tscn ===
[gd_scene load_steps=2 format=3]

[ext_resource type="PackedScene" path="res://src/protocol_portals/StudyRoom.tscn" id="1_studyroom"]

[node name="ReadingRing" instance=ExtResource("1_studyroom")]
protocol = "smoke"
stage_id = 1
=== END ===
=== FILE: src/protocol_portals/rooms/diamonds/PressureStudy.tscn ===
[gd_scene load_steps=2 format=3]

[ext_resource type="PackedScene" path="res://src/protocol_portals/StudyRoom.tscn" id="1_studyroom"]

[node name="PressureStudy" instance=ExtResource("1_studyroom")]
protocol = "diamonds"
stage_id = 2
=== END ===
=== FILE: src/protocol_portals/rooms/gold/ClaimOffice.tscn ===
[gd_scene load_steps=2 format=3]

[ext_resource type="PackedScene" path="res://src/protocol_portals/StudyRoom.tscn" id="1_studyroom"]

[node name="ClaimOffice" instance=ExtResource("1_studyroom")]
protocol = "gold"
stage_id = 3
=== END ===
=== FILE: tests/portal_room_test.gd ===
extends SceneTree
## Headless test for the Protocol Portals study rooms (step 3).
##
## Run with:
##   godot --headless --script res://tests/portal_room_test.gd
##
## Everything is preloaded by path: class_name globals are not guaranteed to be
## registered when a script is run with --script.

const Travel := preload("res://src/protocol_portals/PortalTravel.gd")
const Grant := preload("res://src/protocol_portals/ScorecardGrant.gd")
const QuizBankScript := preload("res://src/protocol_portals/QuizBank.gd")
const SignalsScript := preload("res://src/protocol_portals/PortalSignals.gd")

const PORTAL_DIR: String = "res://src/protocol_portals"
const SAVE_PATH: String = "user://portal_scorecards.json"

const REQUIRED_NODES: Array[String] = [
	"WhitepaperPlate",
	"VideoShrine",
	"Examiner",
	"AscentShaft",
	"Divider",
]

const SKINS: Array = [
	{
		"stage": 1,
		"protocol": "smoke",
		"token": "portal_smoke",
		"path": "res://src/protocol_portals/rooms/smoke/ReadingRing.tscn",
	},
	{
		"stage": 2,
		"protocol": "diamonds",
		"token": "portal_diamonds",
		"path": "res://src/protocol_portals/rooms/diamonds/PressureStudy.tscn",
	},
	{
		"stage": 3,
		"protocol": "gold",
		"token": "portal_gold",
		"path": "res://src/protocol_portals/rooms/gold/ClaimOffice.tscn",
	},
]

var _failures: int = 0


func _initialize() -> void:
	print("PORTAL ROOMS: starting")
	paused = false
	_clean_save()

	_test_room_scene_map()
	_test_consume_return()
	_test_forbidden_tokens()

	for skin in SKINS:
		await _test_skin(skin)

	paused = false
	if _failures == 0:
		print("PORTAL ROOMS: ALL PASS")
		quit(0)
	else:
		print("PORTAL ROOMS: FAILURES %d" % _failures)
		quit(1)


# ---- Pure / static checks ---------------------------------------------------

func _test_room_scene_map() -> void:
	_check(Travel.room_scene_for("smoke") == "res://src/protocol_portals/rooms/smoke/ReadingRing.tscn",
		"room_scene_for(smoke)")
	_check(Travel.room_scene_for("diamonds") == "res://src/protocol_portals/rooms/diamonds/PressureStudy.tscn",
		"room_scene_for(diamonds)")
	_check(Travel.room_scene_for("gold") == "res://src/protocol_portals/rooms/gold/ClaimOffice.tscn",
		"room_scene_for(gold)")


func _test_consume_return() -> void:
	Travel.return_scene = "res://src/protocol_portals/rooms/smoke/ReadingRing.tscn"
	Travel.protocol = "smoke"
	Travel.pending_return = true
	_check(not Travel.consume_return(Travel.return_scene, "diamonds"),
		"consume_return refuses a mismatched protocol")
	_check(Travel.consume_return(Travel.return_scene, "smoke"),
		"consume_return accepts the matching return once")
	_check(not Travel.consume_return(Travel.return_scene, "smoke"),
		"consume_return is one-shot")
	Travel.pending_return = false
	Travel.protocol = ""
	Travel.return_scene = ""


func _test_forbidden_tokens() -> void:
	var files: Array[String] = []
	_collect_files(PORTAL_DIR, files)
	_check(files.size() > 0, "portal scripts found to scan (%d)" % files.size())
	var forbidden: Array[String] = ["OS.execute", "JavaScriptBridge", "HTTPRequest"]
	var hits: int = 0
	for i in range(files.size()):
		var source: String = _read_text(files[i])
		if source.is_empty():
			continue
		for j in range(forbidden.size()):
			if source.contains(forbidden[j]):
				hits += 1
				_fail("%s contains forbidden token '%s'" % [files[i], forbidden[j]])
	_check(hits == 0, "no forbidden tokens in %d portal files" % files.size())


# ---- Per-skin checks --------------------------------------------------------

func _test_skin(skin: Dictionary) -> void:
	var path: String = String(skin["path"])
	var protocol: String = String(skin["protocol"])
	var token: String = String(skin["token"])

	_check(ResourceLoader.exists(path), "skin scene exists: %s" % path)
	if not ResourceLoader.exists(path):
		return

	var bank: RefCounted = QuizBankScript.load_bank(protocol)
	if bank == null:
		_fail("%s: quiz bank did not load" % protocol)
		return
	var key: Array[int] = bank.call("answer_key")

	# --- run 1: every answer correct ---------------------------------------
	Travel.session = null
	Travel.pending_return = false
	var room: Node = await _open_room(path)
	if room == null:
		return
	for i in range(REQUIRED_NODES.size()):
		var node_name: String = REQUIRED_NODES[i]
		_check(room.has_node(node_name), "%s: has node %s" % [protocol, node_name])
	_check(_room_has_player(room), "%s: player is in the group and in the room" % protocol)
	_check(room.has_method("test_run"), "%s: room exposes test_run()" % protocol)

	var passed_result: Dictionary = room.call("test_run", key)
	_check(bool(passed_result.get("passed", false)), "%s: perfect run passes" % protocol)
	_check(int(passed_result.get("score_correct", -1)) == 11, "%s: perfect run scores 11" % protocol)
	_check(bool(passed_result.get("completed", false)), "%s: perfect run completes" % protocol)
	_check(String(passed_result.get("nft_token_id", "")) == token,
		"%s: completion pins token id %s" % [protocol, token])
	_close_room(room)

	# --- run 2: every answer wrong, on a fresh room -------------------------
	Travel.session = null
	Travel.pending_return = false
	var room2: Node = await _open_room(path)
	if room2 == null:
		return
	var wrong: Array[int] = []
	for i in range(key.size()):
		wrong.append((int(key[i]) + 1) % 3)
	var failed_result: Dictionary = room2.call("test_run", wrong)
	_check(not bool(failed_result.get("passed", true)), "%s: all-wrong run fails" % protocol)
	_check(int(failed_result.get("score_correct", -1)) == 0, "%s: all-wrong run scores 0" % protocol)
	_check(not bool(failed_result.get("completed", true)),
		"%s: a failed run is not complete until the player proceeds" % protocol)

	var session: RefCounted = room2.get("session")
	if session == null:
		_fail("%s: room has no session" % protocol)
		_close_room(room2)
		return

	session.call("proceed_without_pass")
	_check(bool(session.call("eligible_for_scorecard")),
		"%s: proceed_without_pass makes the run scorecard-eligible" % protocol)

	var record: Dictionary = Grant.mark_eligible(session)
	_check(not record.is_empty(), "%s: mark_eligible writes a record" % protocol)
	_check(String(record.get("nft_token_id", "")) == token,
		"%s: record carries token id %s" % [protocol, token])
	_check(bool(record.get("eligible", false)), "%s: record is marked eligible" % protocol)
	_check(not bool(record.get("minted", true)), "%s: record is marked not minted" % protocol)
	_check(String(record.get("minted_at", "x")).is_empty(),
		"%s: record has an empty minted_at" % protocol)

	var all: Dictionary = Grant.load_all()
	_check(all.has(token), "%s: scorecard table contains %s" % [protocol, token])
	if all.has(token):
		var stored: Dictionary = all[token]
		_check(String(stored.get("nft_token_id", "")) == token,
			"%s: stored record keeps the token id" % protocol)
		_check(not bool(stored.get("minted", true)), "%s: stored record is not minted" % protocol)

	_close_room(room2)


# ---- Helpers ----------------------------------------------------------------

func _open_room(path: String) -> Node:
	var packed: PackedScene = load(path)
	if packed == null:
		_fail("could not load %s" % path)
		return null
	var room: Node = packed.instantiate()
	root.add_child(room)
	# Two frames: one for _ready + the first physics tick, one for anything the
	# room defers.
	await process_frame
	await process_frame
	return room


func _close_room(room: Node) -> void:
	if room != null and is_instance_valid(room):
		root.remove_child(room)
		room.queue_free()


func _room_has_player(room: Node) -> bool:
	for node in get_nodes_in_group("player"):
		if room.is_ancestor_of(node):
			return true
	return false


func _collect_files(dir_path: String, out: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = dir.get_next()
			continue
		var full: String = dir_path.path_join(entry)
		if dir.current_is_dir():
			_collect_files(full, out)
		else:
			out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()


func _read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text


func _clean_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("[PASS] %s" % label)
	else:
		_fail(label)


func _fail(label: String) -> void:
	_failures += 1
	print("[FAIL] %s" % label)
=== END ===
=== FILE: scripts/capture-portals.mjs ===
#!/usr/bin/env node
// capture-portals.mjs — capture each protocol portal ladder, then the study
// room it opens, without any walking.
// Usage: node scripts/capture-portals.mjs <base-url> <out-dir>
import fs from 'fs';
import { chromium } from 'playwright';

const URL_BASE = process.argv[2];
const OUT_DIR = process.argv[3];
if (!URL_BASE || !OUT_DIR) {
  console.error('usage: node scripts/capture-portals.mjs <base-url> <out-dir>');
  process.exit(2);
}
fs.mkdirSync(OUT_DIR, { recursive: true });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const PINNED = ['/opt/pw-browsers/chromium-1194/chrome-linux/chrome','/opt/pw-browsers/chromium/chrome-linux/chrome'];
const launchOpts = { args: ['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--disable-dev-shm-usage','--no-sandbox'] };
for (const p of PINNED) { if (fs.existsSync(p)) { launchOpts.executablePath = p; break; } }

// stage id, ladder x in the level, protocol id
const STAGES = [ [1, 2100, 'smoke'], [2, 3300, 'diamonds'], [3, 3100, 'gold'] ];
const ERR_RE = /USER SCRIPT ERROR|Parse Error|SCRIPT ERROR/i;

async function waitForBoot(page) {
  await page.waitForSelector('canvas', { timeout: 120000 });
  await page.waitForFunction(() => { const c = document.querySelector('canvas'); return c && c.width > 100 && c.height > 100; }, { timeout: 180000 });
  await sleep(9500); // let warp + camera settle
}

async function openPage(browser) {
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  const errors = [];
  page.on('console', (m) => { const t = m.text(); if (ERR_RE.test(t)) errors.push(t); });
  return { page, errors };
}

let failures = 0;
try {
  const browser = await chromium.launch(launchOpts);

  for (const [stage, x, proto] of STAGES) {
    // (a) the ladder in situ, approached from the left
    {
      const { page, errors } = await openPage(browser);
      const url = `${URL_BASE}?stage=${stage}&spawn_x=${x - 250}`;
      console.log('opening', url);
      await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 120000 });
      await waitForBoot(page);
      const f = `${OUT_DIR}/${proto}_ladder.png`;
      await page.screenshot({ path: f });
      console.log('  ->', f, 'errs', errors.length);
      await page.close();
    }

    // (b) stand in the shaft, press E, land in the study room
    {
      const { page, errors } = await openPage(browser);
      const url = `${URL_BASE}?stage=${stage}&spawn_x=${x}`;
      console.log('opening', url);
      await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 120000 });
      await waitForBoot(page);
      for (let i = 0; i < 3; i += 1) {
        await page.keyboard.down('KeyE');
        await sleep(150);
        await page.keyboard.up('KeyE');
        await sleep(400);
      }
      await sleep(5000);
      const f = `${OUT_DIR}/${proto}_room.png`;
      await page.screenshot({ path: f });
      console.log('  ->', f, 'errs', errors.length);
      await page.close();
    }
  }

  await browser.close();
} catch (err) {
  console.error('capture-portals crashed:', err && err.stack ? err.stack : err);
  failures += 1;
}

if (failures > 0) {
  process.exit(1);
}
console.log('DONE');
=== END ===