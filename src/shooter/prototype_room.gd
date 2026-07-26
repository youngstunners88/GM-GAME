extends Node2D
## v1.2 "Blunt Force" — PROTOTYPE ROOM (GDD §3.6 step 1).
##
## One room, built to answer exactly one question: *does this feel like a
## shooter, or like the platformer with a gun bolted on?* Everything here is
## procedural geometry so the feel test doesn't wait on art.
##
## The room is deliberately WIDE and FLAT. There is no platforming challenge in
## it, because platforming would let the player answer the encounter with a
## jump. The only answers available are: aim, shoot, take cover, reposition.
##
## Contents (per roadmap STEP 5):
##  - Lil Blunt with the Bong Blaster (mouse-aimed, single shot)
##  - one Tax Drone (patrol → alert → telegraph → fire → reposition)
##  - two destructible cover crates
##  - ammo leaves, so the cross-mode economy is visible from day one
##
## Nothing in this file touches the v1.0 platformer scenes or autoload state
## beyond the shared read-only systems (roadmap anti-pattern rule).

const PLAYER := preload("res://src/shooter/shooter_player.tscn")
const DRONE := preload("res://src/shooter/enemy_drone.tscn")
const CRATE := preload("res://src/shooter/cover_crate.tscn")

const ROOM_WIDTH: float = 1800.0
## Room height is deliberately ONE viewport (720). With camera limits set to
## match, the camera never scrolls vertically — the arena is always fully in
## frame. That's a shooter framing decision: you must be able to read every
## threat and every piece of cover at once. Scrolling up/down to find the
## drone would make the encounter unfair rather than hard.
const FLOOR_Y: float = 600.0
const ROOM_HEIGHT: float = 720.0

var _player: Node2D
var _ammo_label: Label
var _health_label: Label
var _drones_alive: int = 0
var _wave: int = 0

func _ready() -> void:
	_build_room()
	_build_hud()
	_spawn_player()
	_spawn_cover()
	_spawn_ammo()
	_start_wave()
	# Direct-boot safety: the shooter prototype can be launched as the main
	# scene, in which case nobody has moved us out of MENU yet.
	if not StateMachine.is_playing():
		StateMachine.change_state(StateMachine.State.TRANSITIONING)
		StateMachine.change_state(StateMachine.State.PLAYING)

## ESC leaves the prototype. Without this the preview is a one-way door on web,
## where there's no window to close.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# SceneRouter owns the TRANSITIONING transition — don't double-fire it.
		SceneRouter.load_scene("res://src/ui/main_menu.tscn", SceneRouter.Transition.FADE)

# ---------------------------------------------------------------- geometry --

func _build_room() -> void:
	# Backdrop: occupied-planet dusk. Dark enough that smoke bolts and the
	# drone's telegraph flare are the brightest things on screen — readability
	# is a combat mechanic, not a style choice.
	# Generously oversized so no camera position can ever show the void past
	# its edges (the first pass had grey bands at the room boundaries).
	var bg := ColorRect.new()
	bg.size = Vector2(ROOM_WIDTH + 1400.0, 2000.0)
	bg.position = Vector2(-700, -700)
	bg.color = Color(0.09, 0.11, 0.16, 1.0)
	bg.z_index = -20
	add_child(bg)
	for i in range(12):
		# Skyline slabs so horizontal movement actually reads as movement.
		var slab := ColorRect.new()
		slab.size = Vector2(120, 220 + (i % 3) * 90)
		slab.position = Vector2(-200 + i * 190, FLOOR_Y - slab.size.y)
		slab.color = Color(0.13, 0.15, 0.22, 1.0)
		slab.z_index = -10
		add_child(slab)

	_solid(Vector2(ROOM_WIDTH / 2.0, FLOOR_Y + 60.0), Vector2(ROOM_WIDTH + 200.0, 120),
		Color(0.2, 0.22, 0.26, 1.0))                       # floor
	_solid(Vector2(-30, FLOOR_Y - 300.0), Vector2(60, 760),
		Color(0.16, 0.18, 0.24, 1.0))                      # left wall
	_solid(Vector2(ROOM_WIDTH + 30.0, FLOOR_Y - 300.0), Vector2(60, 760),
		Color(0.16, 0.18, 0.24, 1.0))                      # right wall
	# A single low ledge — not a platforming route, a sight-line breaker that
	# gives the drone somewhere to be that isn't "directly above you".
	_solid(Vector2(ROOM_WIDTH * 0.5, FLOOR_Y - 230.0), Vector2(300, 26),
		Color(0.24, 0.26, 0.31, 1.0))

## Static world block. Layer 1 = world, which is what bolts and bodies test.
func _solid(centre: Vector2, size: Vector2, color: Color) -> void:
	var body := StaticBody2D.new()
	body.global_position = centre
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	body.add_child(cs)
	var vis := ColorRect.new()
	vis.size = size
	vis.position = -size / 2.0
	vis.color = color
	body.add_child(vis)
	add_child(body)

# ---------------------------------------------------------------- entities --

func _spawn_player() -> void:
	_player = PLAYER.instantiate()
	_player.global_position = Vector2(300, FLOOR_Y - 60.0)
	# Connect BEFORE add_child: the player emits its opening ammo/health values
	# from _ready, which fires the moment it enters the tree.
	_player.ammo_changed.connect(_on_ammo_changed)
	_player.health_changed.connect(_on_health_changed)
	add_child(_player)
	# Lock the camera to the arena: horizontal scroll only, no vertical drift.
	var cam: Camera2D = _player.get_node("Camera2D")
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = int(ROOM_WIDTH)
	cam.limit_bottom = int(ROOM_HEIGHT)
	cam.limit_smoothed = true

func _spawn_cover() -> void:
	# Two crates, spaced so you cannot cover both flanks from one of them.
	# That spacing IS the encounter: cover forces a commitment.
	for x in [640.0, 1240.0]:
		var crate := CRATE.instantiate()
		crate.global_position = Vector2(x, FLOOR_Y - 28.0)
		add_child(crate)

func _spawn_ammo() -> void:
	# Leaves = ammo (GDD pillar 3). Placed AWAY from cover on purpose: to
	# restock you have to leave safety, which keeps the room from stalemating.
	for x in [940.0, 1560.0, 120.0]:
		var leaf := Area2D.new()
		leaf.global_position = Vector2(x, FLOOR_Y - 46.0)
		leaf.collision_layer = 0
		leaf.collision_mask = 2
		var cs := CollisionShape2D.new()
		var circ := CircleShape2D.new()
		circ.radius = 18.0
		cs.shape = circ
		leaf.add_child(cs)
		var dot := ColorRect.new()
		dot.size = Vector2(18, 18)
		dot.position = Vector2(-9, -9)
		dot.color = Color(0.45, 0.95, 0.5, 1.0)
		leaf.add_child(dot)
		var tw := leaf.create_tween().set_loops()
		tw.tween_property(dot, "position:y", -16.0, 0.8).set_trans(Tween.TRANS_SINE)
		tw.tween_property(dot, "position:y", -9.0, 0.8).set_trans(Tween.TRANS_SINE)
		leaf.body_entered.connect(func(b: Node2D) -> void:
			if b.has_method("add_ammo"):
				b.add_ammo(15)
				leaf.queue_free())
		add_child(leaf)

## Waves keep the feel test running without a restart. Wave size grows so the
## cover system gets stressed once one crate is gone.
func _start_wave() -> void:
	_wave += 1
	var count: int = 1 if _wave == 1 else mini(1 + _wave / 2, 3)
	_drones_alive = count
	for i in range(count):
		var drone := DRONE.instantiate()
		drone.global_position = Vector2(1000.0 + i * 260.0, FLOOR_Y - 320.0)
		add_child(drone)
		drone.tree_exited.connect(_on_drone_gone)

func _on_drone_gone() -> void:
	_drones_alive -= 1
	if _drones_alive <= 0 and is_inside_tree():
		get_tree().create_timer(2.0).timeout.connect(func() -> void:
			if is_inside_tree():
				_start_wave())

# --------------------------------------------------------------------- HUD --

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	# y=48: the offline-mode banner owns the top strip; the first pass drew
	# the ammo counter straight through it.
	_ammo_label = _hud_label(layer, Vector2(24, 48), 26,
		Color(0.6, 1.0, 0.7, 1.0))
	_health_label = _hud_label(layer, Vector2(24, 84), 22,
		Color(1.0, 0.55, 0.55, 1.0))
	var hint := _hud_label(layer, Vector2(24, 676), 16,
		Color(0.8, 0.85, 0.95, 0.85))
	hint.text = "MOVE A/D  ·  AIM MOUSE  ·  FIRE CLICK  ·  DOWN = TAKE COVER  ·  FIRE FROM COVER = PEEK"
	_ammo_label.text = "BONG AMMO  -- / --"
	_health_label.text = "HP  -"

func _hud_label(parent: Node, pos: Vector2, size: int, color: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	# Outline: the HUD sits over a dark, busy combat scene.
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 5)
	parent.add_child(l)
	return l

func _on_ammo_changed(current: int, maximum: int) -> void:
	_ammo_label.text = "BONG AMMO  %d / %d" % [current, maximum]
	_ammo_label.add_theme_color_override("font_color",
		Color(1.0, 0.4, 0.4, 1.0) if current <= 8 else Color(0.6, 1.0, 0.7, 1.0))

func _on_health_changed(current: int) -> void:
	# Letters and digits ONLY. The project's pixel font has no glyph for ♦ or
	# even brackets — both earlier attempts rendered as a row of tofu boxes.
	_health_label.text = "HP  %d / 5" % maxi(current, 0)
