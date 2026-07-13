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

# The three parallax sprites (far/mid/near) all sample the level's key art;
# kept as an array so the boss-arena swap can retexture every depth at once.
var _backdrop_sprites: Array[Sprite2D] = []

func _setup_background() -> void:
	# Painted key-art backdrop split into three parallax depths. The art is
	# viewport-sized (1280×720), so scale 1 and mirror at texture width.
	if not level_data or level_data.background_path == "":
		return
	var tex: Texture2D = load(level_data.background_path)
	if tex == null:
		return
	var pbg := ParallaxBackground.new()
	pbg.name = "BackdropParallax"
	pbg.layer = -20
	add_child(pbg)
	# far: whole painting, slow + cooled down — reads as distance
	_add_parallax_layer(pbg, tex, 0.2, Color(0.55, 0.55, 0.68, 1.0), Rect2())
	# mid: the main read of the art, standard darken from the old backdrop
	_add_parallax_layer(pbg, tex, 0.5, Color(0.82, 0.82, 0.86, 0.8), Rect2())
	# near: bottom strip of the same painting drifting faster — foreground
	# silhouettes (grass edges / rocks) without needing extracted art
	var h := float(tex.get_height())
	_add_parallax_layer(pbg, tex, 0.8, Color(0.65, 0.7, 0.72, 0.55),
			Rect2(0.0, h * 0.72, float(tex.get_width()), h * 0.28))

func _add_parallax_layer(pbg: ParallaxBackground, tex: Texture2D, speed: float,
		mod: Color, region: Rect2) -> void:
	var layer := ParallaxLayer.new()
	layer.motion_scale = Vector2(speed, 1.0)
	layer.motion_mirroring = Vector2(float(tex.get_width()), 0.0)
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.centered = false
	spr.modulate = mod
	if region.size != Vector2.ZERO:
		spr.region_enabled = true
		spr.region_rect = region
		spr.position = Vector2(0.0, 720.0 - region.size.y)
	layer.add_child(spr)
	pbg.add_child(layer)
	_backdrop_sprites.append(spr)

## Swap the backdrop to the boss key art (called from boss triggers).
## All three parallax depths swap together so the arena reads as one place.
func set_boss_background() -> void:
	if level_data == null or level_data.boss_background_path == "":
		return
	var tex: Texture2D = load(level_data.boss_background_path)
	if tex == null:
		return
	for spr in _backdrop_sprites:
		if is_instance_valid(spr):
			spr.texture = tex

func _setup_parallax() -> void:
	# Skip the flat color bands when a painted backdrop is present.
	if level_data and level_data.background_path != "":
		return
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
	# Ground + floating platforms get a dark body with a bright lip so they
	# read as solid ledges over the painted backdrop.
	for segment in level_data.ground_segments:
		_create_platform(segment.x, segment.y, segment.z, segment.w, Color(0.10, 0.07, 0.14, 0.94), Color(0.45, 0.9, 0.5, 1.0))
	for platform in level_data.platforms:
		_create_platform(platform.x, platform.y, platform.z, platform.w, Color(0.12, 0.09, 0.18, 0.92), Color(0.55, 0.95, 0.7, 1.0))

func _create_platform(x: float, y: float, w: float, h: float, body_color: Color, lip_color: Color = Color(0.5, 0.9, 0.6, 1.0)) -> void:
	var plat := StaticBody2D.new()
	plat.position = Vector2(x, y)
	plat.collision_layer = 1

	var visual := ColorRect.new()
	visual.color = body_color
	visual.size = Vector2(w, h)
	plat.add_child(visual)

	# Bright top lip — the "grass/crystal edge" read.
	var lip := ColorRect.new()
	lip.color = lip_color
	lip.size = Vector2(w, min(6.0, h))
	plat.add_child(lip)

	# Thin dark outline sides for definition.
	var outline := ColorRect.new()
	outline.color = Color(0, 0, 0, 0.35)
	outline.size = Vector2(w, h)
	outline.position = Vector2(0, 0)
	plat.add_child(outline)
	plat.move_child(outline, 0)

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
	# Checkpoints — level_index must be a pre-add_child prop like MineCart's
	# cart_type: Checkpoint._ready() reads it immediately on body_entered wiring.
	for i in range(level_data.checkpoints.size()):
		EntitySpawner.spawn("checkpoint", level_data.checkpoints[i], self,
			{"checkpoint_id": i, "level_index": level_data.level_index})
	# Spawn melt forges (Level 3 whitepaper mechanic)
	for forge_data in level_data.melt_forges:
		var entity := EntitySpawner.spawn("melt_forge", forge_data.get("pos", Vector2.ZERO), self)
	# Spawn mine carts. cart_type must be passed as a pre-add_child prop —
	# MineCart._ready() consumes it to set speed/reward/visual, so assigning
	# it after spawn silently leaves every cart FAST (the old bug).
	for cart_data in level_data.mine_carts_fast:
		EntitySpawner.spawn("mine_cart", cart_data.get("pos", Vector2.ZERO), self,
			{"cart_type": MineCart.CartType.FAST})
	for cart_data in level_data.mine_carts_slow:
		EntitySpawner.spawn("mine_cart", cart_data.get("pos", Vector2.ZERO), self,
			{"cart_type": MineCart.CartType.SLOW})

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
	var checkpoint := GameManager.get_checkpoint(level_data.level_index)
	if checkpoint != Vector2.ZERO:
		player.global_position = checkpoint + Vector2(0, -50)
	elif player_spawn:
		player.global_position = player_spawn.global_position
	else:
		player.global_position = Vector2(100, 500)
	add_child(player)

## Place this level's hidden Blaze Portal (Geometry-Dash secret run entrance).
## Locked until the player's accumulated score reaches `threshold`.
func _setup_blaze_portal(pos: Vector2, threshold: int, level_index: int) -> void:
	var portal := preload("res://src/dashmode/blaze_portal.tscn").instantiate()
	portal.global_position = pos
	portal.unlock_threshold = threshold
	portal.level_index = level_index
	add_child(portal)

func _setup_hud() -> void:
	var pm := preload("res://src/ui/pause_menu.tscn").instantiate()
	add_child(pm)
	pm.get_node("VBox/ResumeBtn").pressed.connect(pm._on_resume_pressed)
	pm.get_node("VBox/RestartBtn").pressed.connect(pm._on_restart_pressed)
	pm.get_node("VBox/QuitBtn").pressed.connect(pm._on_quit_pressed)

func _on_boss_trigger(body: Node2D) -> void:
	pass  # Override in subclasses for boss arena logic
