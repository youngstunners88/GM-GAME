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
	_apply_token_perks()
	StateMachine.change_state(StateMachine.State.PLAYING)

# The three parallax sprites (far/mid/near) all sample the level's key art;
# kept as an array so the boss-arena swap can retexture every depth at once.
var _backdrop_sprites: Array[Sprite2D] = []

func _setup_background() -> void:
	# One crisp full-screen painting on a slow-scroll parallax layer. The art
	# is cohesive and premium now (Muapi Flux, blockchain-themed per realm), so
	# it reads best clean — NOT chopped into darkened/cropped duplicate layers,
	# which is what made the old version look muddy and "incoherent". A gentle
	# 0.35 motion scale gives depth against the camera without smearing.
	if not level_data or level_data.background_path == "":
		return
	var tex: Texture2D = load(level_data.background_path)
	if tex == null:
		return
	var pbg := ParallaxBackground.new()
	pbg.name = "BackdropParallax"
	pbg.layer = -20
	add_child(pbg)
	var layer := ParallaxLayer.new()
	layer.motion_scale = Vector2(0.35, 0.5)
	layer.motion_mirroring = Vector2(float(tex.get_width()), 0.0)
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.centered = false
	# Very slight cool tint keeps foreground gameplay readable over the art
	# without draining the painting's colour.
	spr.modulate = Color(0.9, 0.9, 0.94, 1.0)
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

const BLOCK_TEX := preload("res://src/assets/sprites/tile_block-chain.png")

func _create_platform(x: float, y: float, w: float, h: float, body_color: Color, lip_color: Color = Color(0.5, 0.9, 0.6, 1.0)) -> void:
	var plat := StaticBody2D.new()
	plat.position = Vector2(x, y)
	plat.collision_layer = 1

	# Dark base under the blocks so gaps between tiles read as solid, not
	# see-through, and the platform still contrasts the painted backdrop.
	var base := ColorRect.new()
	base.color = body_color
	base.size = Vector2(w, h)
	plat.add_child(base)

	# Blockchain blocks: the tile texture repeated across the platform. This is
	# the subtle blockchain-tech theme in the level geometry itself — every
	# ledge is literally a chain of blocks. texture_repeat tiles the 96px cube.
	var blocks := Sprite2D.new()
	blocks.texture = BLOCK_TEX
	blocks.centered = false
	blocks.region_enabled = true
	blocks.region_rect = Rect2(0, 0, w, max(h, 24.0))
	blocks.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	blocks.position = Vector2(0, min(0.0, h - 24.0))
	plat.add_child(blocks)

	# Bright top lip — a glowing edge so the standable surface is unmistakable.
	var lip := ColorRect.new()
	lip.color = lip_color
	lip.size = Vector2(w, min(4.0, h))
	plat.add_child(lip)

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
	# CRITICAL: Area2D.new() defaults collision_mask to 1 (World). The player
	# is on layer 2 (Player), so without this the pit never detected the player
	# and falling into a ditch did NOTHING (reported 2026-07-14). Mask the
	# Player layer explicitly so body_entered actually fires.
	kill_zone.collision_layer = 0
	kill_zone.collision_mask = 2
	# Make the pit a tall band, not a 50px sliver — a fast fall (up to
	# max_fall_speed 720 px/s ≈ 12px/frame) can't tunnel past 400px, and it
	# also catches a player who clips slightly into level geometry.
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(level_data.bounds.x, 400)
	col.shape = shape
	kill_zone.add_child(col)
	kill_zone.position = Vector2(level_data.bounds.x / 2, level_data.kill_zone_y + 175)
	kill_zone.body_entered.connect(func(body: Node2D) -> void:
		# Pit falls are a HARD fail: pit_death() plays the devastating sound and
		# costs a LIFE (not just health). Falls back to die() only if a custom
		# player somehow lacks it.
		if body.is_in_group("player") and body.has_method("pit_death"):
			body.pit_death()
		elif body.is_in_group("player") and body.has_method("die"):
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
	# Returning from a secret realm? Drop the player right back at the door they
	# entered (its saved position), then consume the return record.
	var sr: Dictionary = GameManager.secret_return
	if not sr.is_empty() and sr.get("scene_path", "") == scene_file_path:
		player.global_position = sr.get("position", Vector2(100, 500)) + Vector2(40, -50)
		GameManager.secret_return = {}
		add_child(player)
		return
	var checkpoint := GameManager.get_checkpoint(level_data.level_index)
	if checkpoint != Vector2.ZERO:
		player.global_position = checkpoint + Vector2(0, -50)
	elif player_spawn:
		player.global_position = player_spawn.global_position
	else:
		player.global_position = Vector2(100, 500)
	add_child(player)

## MOVIE LAYER — token-gated perks. At level start we read the connected
## wallet's real on-chain holdings (Web3Bridge, populated via ERC-20 balanceOf)
## and grant additive bonuses. Holders get a richer run; everyone else plays the
## unchanged Book-Layer level. Zero holdings / no wallet / off-web → no perks,
## no penalty. Contract addresses live in config.json (never hardcoded).
##   SMOKE    > 0 -> 30s Blaze Mode head-start
##   GoldMine > 0 -> golden skin tint (cosmetic flex)
##   DIAMONDS > 0 -> Crystal Caverns bonus portal appears in Level 1
func _apply_token_perks() -> void:
	if not Engine.has_singleton("Web3Bridge") and not has_node("/root/Web3Bridge"):
		return
	if Web3Bridge.wallet_address == "":
		return
	if Web3Bridge.holds("smoke"):
		GameManager.activate_power_up("blaze", 30.0)
		Web3Bridge.track("perk_blaze")
	if Web3Bridge.holds("goldmine"):
		var p := get_tree().get_first_node_in_group("player")
		if p:
			p.modulate = Color(1.25, 1.12, 0.55, 1.0)  # golden GoldMine flex
		Web3Bridge.track("perk_golden")
	if Web3Bridge.holds("diamonds") and level_data and level_data.level_index == 1:
		_spawn_crystal_caverns_portal()
		Web3Bridge.track("perk_crystal_portal")

## Diamond-tinted bonus portal (DIAMONDS holders only). Reuses the secret-door
## warp so the on-chain perk unlocks a real, reachable bonus area rather than a
## cosmetic-only marker. Placed just past spawn so holders find it immediately.
func _spawn_crystal_caverns_portal() -> void:
	if not ResourceLoader.exists("res://src/level/secret_door.tscn"):
		return
	var portal := preload("res://src/level/secret_door.tscn").instantiate()
	var anchor := player_spawn.global_position if player_spawn else Vector2(100, 500)
	portal.global_position = anchor + Vector2(220, -8)
	add_child(portal)
	var spr := portal.get_node_or_null("Sprite")
	if spr:
		spr.modulate = Color(0.5, 0.9, 1.4, 1.0)  # crystal cyan

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
