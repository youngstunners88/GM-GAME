class_name LevelBase
extends Node2D

@export var level_data: LevelData

@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var boss_trigger: Area2D = $BossTrigger
@onready var boss_spawn: Marker2D = $BossSpawn

## Wall-clock level start (msec) — auditor.die() reads it to report the
## level_complete pacing metric for adaptive difficulty (task #23).
var level_start_ms: int = 0

func _ready() -> void:
	level_start_ms = Time.get_ticks_msec()
	# Adaptive difficulty (task #23): pull this player's heatmap BEFORE
	# entities spawn where possible; late-arriving tuning is applied in
	# _on_difficulty_ready (checkpoint/hint tweaks are placement-safe anytime).
	DifficultyManager.tuning_ready.connect(_on_difficulty_ready, CONNECT_ONE_SHOT)
	DifficultyManager.refresh()
	if boss_trigger:
		boss_trigger.body_entered.connect(_on_boss_trigger)
	_setup_background()
	_setup_geometry()
	_setup_parallax()
	_setup_kill_zone()
	_setup_entities()
	_setup_boss_arena()
	_spawn_player()
	_setup_camera_limits()
	_setup_hud()
	_apply_token_perks()
	# R9 (2026-08-08): record the level actually being played so Continue can
	# resume it. Previously current_level was only set when a level was CLEARED
	# (next_level_scene), and Continue read highest_unlocked_level — so a player
	# who reached L2 and refreshed could land back on L1. Recording on ENTRY
	# makes "last level played" authoritative regardless of how it was reached.
	# Guarded to the 3 campaign levels (level_index 1..3); the Smoke Lounge and
	# Blaze Rush do not extend LevelBase, so they never touch this.
	if level_data and level_data.level_index >= 1:
		GameManager.current_level = level_data.level_index
		GameManager.save_session()
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

## Show the boss key art (called from boss triggers).
##
## Founder defect D2 ("player floats in the air on flat ground art"). Real
## mechanism (corrected after a Kimi K3 audit caught the first version of
## this fix misdescribing it as "arbitrary drift" — it is not; parallax
## offset is a deterministic function of camera position, not history): the
## boss art was swapped onto the SAME layer _setup_background() built for
## the level's regular repeating backdrop — motion_scale=(0.35,0.5), mirrored
## every image-width. With the camera clamped near the arena floor, real
## ground geometry (world y=650) moves 1:1 with the camera while that layer
## only moves at 0.5x — a fixed, reproducible ~70px gap between the art's
## illustrated walkway and the actual ground every single time, not
## something that drifts run to run.
##
## Fix: an ADDITIVE dedicated layer for the boss art (never mutate the
## shared level-wide backdrop sprite) — world-fixed (motion_scale=1,1, zero
## mirroring, so it moves in perfect lockstep with the camera and can never
## develop a parallax gap against real geometry again), sized and positioned
## to cover the camera's ENTIRE reachable range while the arena is sealed.
## That range is WIDER than the arena itself: the viewport (1280px) reaches
## past the arena's own start_x when the player first crosses in, which the
## first version of this fix missed and left a blank strip on screen for
## the whole fight (caught by the same Kimi audit, with the exact math).
## Being additive also means a player knocked back to a west-of-arena
## checkpoint still sees the ORIGINAL, correctly-scrolling level backdrop —
## nothing here ever needs to revert.
const BOSS_ART_FLOOR_ROW: float = 605.0
var _boss_backdrop_sprite: Sprite2D

func set_boss_background() -> void:
	if level_data == null or level_data.boss_background_path == "":
		return
	var tex: Texture2D = load(level_data.boss_background_path)
	if tex == null:
		return

	if not is_instance_valid(_boss_backdrop_sprite):
		var pbg := ParallaxBackground.new()
		pbg.layer = -19  # in front of the regular -20 level backdrop, still behind gameplay (0)
		add_child(pbg)
		var layer := ParallaxLayer.new()
		layer.motion_scale = Vector2(1.0, 1.0)
		layer.motion_mirroring = Vector2.ZERO
		pbg.add_child(layer)
		_boss_backdrop_sprite = Sprite2D.new()
		_boss_backdrop_sprite.centered = false
		layer.add_child(_boss_backdrop_sprite)
	_boss_backdrop_sprite.texture = tex

	var start_x: float = level_data.boss_arena.get("start_x", 0.0)
	var end_x: float = level_data.boss_arena.get("end_x", start_x + tex.get_width())
	# Cover the camera's full reachable range, not just the arena's own
	# width — the camera can show up to viewport_width/2 px WEST of start_x
	# the moment the player first crosses in (Kimi audit).
	var viewport_w := float(get_viewport().get_visible_rect().size.x)
	var view_left := start_x - viewport_w / 2.0
	var required_width := end_x - view_left
	var scale_factor := required_width / float(tex.get_width())
	_boss_backdrop_sprite.scale = Vector2(scale_factor, scale_factor)
	var floor_y := _floor_y_at(start_x)
	_boss_backdrop_sprite.position = Vector2(view_left, floor_y - BOSS_ART_FLOOR_ROW * scale_factor)

## The ground segment's own Y at a given world X — used to align the boss
## backdrop's illustrated floor with the REAL collision surface instead of a
## guessed constant.
func _floor_y_at(x: float) -> float:
	for seg in level_data.ground_segments:
		if x >= seg.x and x < seg.x + seg.z:
			return seg.y
	push_warning("LevelBase._floor_y_at: no ground segment covers x=%.0f — falling back to kill_zone_y" % x)
	return level_data.kill_zone_y

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
		_create_platform(segment.x, segment.y, segment.z, segment.w, level_data.platform_body_color, level_data.platform_lip_color)
	for platform in level_data.platforms:
		_create_platform(platform.x, platform.y, platform.z, platform.w, level_data.floating_platform_body_color, level_data.floating_platform_lip_color)

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

## Only the FAR wall exists from level start.
##
## The entry wall used to be built here too, and it made **every boss in the
## game unreachable**: a 600px-tall wall at `boss_arena.start_x` is directly
## across the approach, so the player walked into it and stopped. The boss
## still spawned and its health bar still appeared (the trigger Area2D is
## 200px wide and reaches 100px west of the wall), which is why this read as
## "the boss ignores me" rather than "I am blocked" — and why an automated
## driver sat at the Auditor for 380 seconds without landing a hit.
##
## The wall's real job is to stop the player FLEEING mid-fight, so it is now
## raised behind them once they are actually inside (see _process below).
## Proven by tests/boss_arena_reachable_test.gd.
func _setup_boss_arena() -> void:
	if level_data.boss_arena.is_empty():
		return
	var end_x: float = level_data.boss_arena.get("end_x", 0.0)
	if end_x > 0:
		_create_wall(end_x, 400, 20, 600)

## Arm the entry wall. Called from each level's _on_boss_trigger; the wall is
## not built until the player has genuinely crossed into the arena, because
## the trigger fires while they are still WEST of start_x.
func arm_boss_arena_seal() -> void:
	if level_data.boss_arena.is_empty():
		return
	var start_x: float = level_data.boss_arena.get("start_x", 0.0)
	if start_x > 0.0:
		_seal_x = start_x
		set_process(true)

## -1 = seal not armed. Set by arm_boss_arena_seal().
var _seal_x: float = -1.0
## The entry wall, once raised. Kept so it can be taken back DOWN — see below.
var _seal_wall: StaticBody2D = null

## Raises the entry wall behind the player, and lowers it again if they end up
## back outside.
##
## The lowering half is not optional. Checkpoints sit west of every arena, so a
## player who dies mid-fight respawns OUTSIDE a wall that is already up — and
## with the boss still alive, they would be permanently locked out of a fight
## they cannot finish and cannot leave. That is a soft-lock, and it is one this
## seal would have introduced.
func _process(_delta: float) -> void:
	if _seal_x < 0.0:
		set_process(false)
		return
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p == null:
		return
	if _seal_wall == null:
		# 60px of clearance so the wall never spawns on top of the player.
		if p.global_position.x > _seal_x + 60.0:
			_seal_wall = _create_wall(_seal_x, 400, 20, 600)
	elif p.global_position.x < _seal_x - 40.0:
		# Player is back outside (death + respawn at a western checkpoint):
		# drop the wall so they can walk in and re-engage.
		_seal_wall.queue_free()
		_seal_wall = null

## Returns the wall so the boss-arena seal can take it back down again
## (existing callers ignore the return value).
func _create_wall(x: float, y: float, w: float, h: float) -> StaticBody2D:
	var wall := StaticBody2D.new()
	wall.position = Vector2(x, y)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(w, h)
	col.shape = shape
	wall.add_child(col)
	add_child(wall)
	return wall

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

## FIX (Stage 2/3 boss-visibility bug): the Camera2D baked into player.tscn
## ships with a hardcoded limit_right=3400 — correct for Level 1
## (bounds.x=3400, pure coincidence) but 1000px SHORT of Level 2 and Level 3
## (both bounds.x=4400, whose boss arenas sit at x=3700-4400 — ENTIRELY past
## the clamp). LevelBase never overrode it, so on Stage 2/3 the camera hit a
## hard wall at x=3400 while the boss spawned beyond it (boss "unseen" on
## arrival) and the player kept walking right past the now-frozen camera
## (Lil Blunt "disappearing" off the right edge). secret_realm.gd and
## prototype_room.gd already set their own camera limits correctly — the
## shared campaign LevelBase was the one path that never did.
func _setup_camera_limits() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		# Kimi audit 2026-08-02: silently returning here would resurrect the
		# EXACT bug this function exists to fix, with no signal that it
		# happened — warn loudly instead of failing quiet.
		push_warning("LevelBase: no player in group 'player' — camera limits not set")
		return
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		push_warning("LevelBase: player has no Camera2D child named 'Camera2D' — camera limits not set")
		return
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = int(level_data.bounds.x)
	cam.limit_bottom = int(level_data.kill_zone_y) + 100

## Adaptive-difficulty application (task #23, Video-Game Layer). Runs when the
## player's analytics arrive (or immediately with neutral defaults offline).
## Everything here is INVISIBLE: no banner, no toast — the level just adjusts.
func _on_difficulty_ready() -> void:
	# 1. Retro-apply Tax Collector slow-down to enemies that spawned before
	#    the analytics arrived (per-enemy meta guard prevents double-apply).
	if DifficultyManager.tax_speed_scale != 1.0:
		for e in get_tree().get_nodes_in_group("enemy"):
			if "patrol_speed" in e and e.get("analytics_id") == "tax" \
					and not e.has_meta("dd_scaled"):
				e.set_meta("dd_scaled", true)
				e.patrol_speed = e.patrol_speed * DifficultyManager.tax_speed_scale
	# 2. Slow runners get one extra mid-level checkpoint.
	if DifficultyManager.extra_checkpoint and level_data and level_data.checkpoints.size() >= 2:
		var a: Vector2 = level_data.checkpoints[0]
		var b: Vector2 = level_data.checkpoints[level_data.checkpoints.size() - 1]
		EntitySpawner.spawn("checkpoint", (a + b) / 2.0 + Vector2(0, -4), self,
			{"checkpoint_id": 90, "level_index": level_data.level_index})
	# 3. Heavy retriers get a Hint Leaf: touch it and the route to the next
	#    checkpoints glows for 5 seconds.
	if DifficultyManager.hint_leaf:
		_spawn_hint_leaf()

## Glowing leaf near spawn; on pickup, draws a dotted guide line through the
## level's checkpoints for 5s. A nudge, not a walkthrough.
func _spawn_hint_leaf() -> void:
	if level_data == null or level_data.checkpoints.is_empty():
		return
	var leaf := Area2D.new()
	leaf.collision_layer = 0
	leaf.collision_mask = 2
	var spr := Sprite2D.new()
	spr.texture = load("res://src/assets/sprites/sprite_item_weed-leaf.png") \
			if ResourceLoader.exists("res://src/assets/sprites/sprite_item_weed-leaf.png") \
			else load("res://src/assets/sprites/sprite_item_eth-ring.png")
	spr.modulate = Color(0.7, 1.4, 0.7, 1.0)
	leaf.add_child(spr)
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(30, 30)
	cs.shape = rect
	leaf.add_child(cs)
	var anchor := player_spawn.global_position if player_spawn else Vector2(120, 500)
	leaf.global_position = anchor + Vector2(90, -20)
	leaf.body_entered.connect(func(b: Node2D) -> void:
		if b.is_in_group("player"):
			AudioManager.play_sfx("powerup")
			Web3Bridge.report_metric("powerup_used", {"type": "hint_leaf"})
			_show_hint_path()
			leaf.queue_free())
	add_child(leaf)

func _show_hint_path() -> void:
	var line := Line2D.new()
	line.width = 4.0
	line.default_color = Color(0.65, 1.0, 0.7, 0.65)
	line.z_index = 40
	for cp: Vector2 in level_data.checkpoints:
		line.add_point(cp)
	add_child(line)
	var tw := line.create_tween()
	tw.tween_interval(5.0)
	tw.tween_property(line, "modulate:a", 0.0, 0.8)
	tw.finished.connect(line.queue_free)

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
	pm.get_node("VBox/TalkBtn").pressed.connect(pm._on_talk_pressed)
	pm.get_node("VBox/QuitBtn").pressed.connect(pm._on_quit_pressed)

func _on_boss_trigger(body: Node2D) -> void:
	pass  # Override in subclasses for boss arena logic
