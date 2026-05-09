class_name LevelBase
extends Node2D

@export var level_data: LevelData

@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var boss_trigger: Area2D = $BossTrigger
@onready var boss_spawn: Marker2D = $BossSpawn

func _ready() -> void:
	if boss_trigger:
		boss_trigger.body_entered.connect(_on_boss_trigger)
	_setup_background()
	_setup_geometry()
	_setup_parallax()
	_setup_kill_zone()
	_setup_entities()
	_setup_boss_arena()
	_spawn_player()
	_setup_hud()
	StateMachine.change_state(StateMachine.State.PLAYING)

func _setup_background() -> void:
	pass  # Override in subclasses for custom background

func _setup_parallax() -> void:
	if not level_data or level_data.parallax_layers.is_empty():
		return
	var bg := ParallaxBackground.new()
	add_child(bg)
	move_child(bg, 0)
	for layer_data in level_data.parallax_layers:
		var layer := ParallaxLayer.new()
		layer.motion_scale = Vector2(layer_data.get("speed", 0.5), 0.0)
		layer.motion_mirroring = Vector2(level_data.bounds.x, 0.0)
		var rect := ColorRect.new()
		rect.color = layer_data.get("color", Color.WHITE)
		rect.size = Vector2(level_data.bounds.x, layer_data.get("height", 100))
		rect.position = Vector2(0.0, layer_data.get("y", 0.0))
		layer.add_child(rect)
		bg.add_child(layer)

func _setup_geometry() -> void:
	# Create ground segments
	for segment in level_data.ground_segments:
		_create_platform(segment.x, segment.y, segment.z, segment.w, Color(0.2, 0.5, 0.2, 1.0))
	# Create floating platforms
	for platform in level_data.platforms:
		_create_platform(platform.x, platform.y, platform.z, platform.w, Color(0.3, 0.6, 0.3, 1.0))

func _create_platform(x: float, y: float, w: float, h: float, color: Color) -> void:
	var plat := StaticBody2D.new()
	plat.position = Vector2(x, y)
	plat.collision_layer = 1

	var visual := ColorRect.new()
	visual.color = color
	visual.size = Vector2(w, h)
	plat.add_child(visual)

	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(w, h)
	col.shape = shape
	col.position = Vector2(w / 2, h / 2)
	plat.add_child(col)

	add_child(plat)

func _setup_kill_zone() -> void:
	var kill_zone := Area2D.new()
	kill_zone.add_to_group("hazard")
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(level_data.bounds.x, 50)
	col.shape = shape
	kill_zone.add_child(col)
	kill_zone.position = Vector2(level_data.bounds.x / 2, level_data.kill_zone_y)
	kill_zone.body_entered.connect(func(body: Node2D) -> void:
		if body.is_in_group("player") and body.has_method("die"):
			body.die()
	)
	add_child(kill_zone)

func _setup_entities() -> void:
	# Spawn enemies
	for enemy_data in level_data.enemy_spawns:
		var entity := EntitySpawner.spawn(enemy_data.get("type", ""), enemy_data.get("pos", Vector2.ZERO), self)
	# Spawn collectibles
	for collectible_data in level_data.collectible_spawns:
		var entity := EntitySpawner.spawn(collectible_data.get("type", ""), collectible_data.get("pos", Vector2.ZERO), self)
	# Spawn powerups
	for powerup_data in level_data.powerup_spawns:
		var entity := EntitySpawner.spawn(powerup_data.get("type", ""), powerup_data.get("pos", Vector2.ZERO), self)
	# Spawn breakable blocks
	for block_pos in level_data.breakable_blocks:
		var entity := EntitySpawner.spawn("breakable_block", block_pos, self)

func _setup_boss_arena() -> void:
	if level_data.boss_arena.is_empty():
		return
	# Create boss arena walls
	var start_x: float = level_data.boss_arena.get("start_x", 0.0)
	var end_x: float = level_data.boss_arena.get("end_x", 0.0)
	if start_x > 0:
		_create_wall(start_x, 400, 20, 600)
	if end_x > 0:
		_create_wall(end_x, 400, 20, 600)

func _create_wall(x: float, y: float, w: float, h: float) -> void:
	var wall := StaticBody2D.new()
	wall.position = Vector2(x, y)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(w, h)
	col.shape = shape
	wall.add_child(col)
	add_child(wall)

func _spawn_player() -> void:
	var player := preload("res://src/player/player.tscn").instantiate()
	var checkpoint := GameManager.get_checkpoint(1)
	if checkpoint != Vector2.ZERO:
		player.global_position = checkpoint + Vector2(0, -50)
	elif player_spawn:
		player.global_position = player_spawn.global_position
	else:
		player.global_position = Vector2(100, 500)
	add_child(player)

func _setup_hud() -> void:
	var pm := preload("res://src/ui/pause_menu.tscn").instantiate()
	add_child(pm)
	pm.get_node("VBox/ResumeBtn").pressed.connect(pm._on_resume_pressed)
	pm.get_node("VBox/RestartBtn").pressed.connect(pm._on_restart_pressed)
	pm.get_node("VBox/QuitBtn").pressed.connect(pm._on_quit_pressed)

func _on_boss_trigger(body: Node2D) -> void:
	pass  # Override in subclasses for boss arena logic
