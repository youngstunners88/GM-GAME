class_name LevelBase
extends Node2D

@export var level_data: LevelData

@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var boss_trigger: Area2D = $BossTrigger
@onready var boss_spawn: Marker2D = $BossSpawn

## Wall-clock level start (msec) — auditor.die() reads it to report the
## level_complete pacing metric for adaptive difficulty (task #23).
var level_start_ms: int = 0

## Full-level-width x-ranges the kill zone must NOT cover (world space),
## registered before `_setup_kill_zone()` runs — see `_register_kill_zone_gaps()`.
var kill_zone_gaps: Array[Vector2] = []

func _ready() -> void:
	level_start_ms = Time.get_ticks_msec()
	# MUST run before _setup_kill_zone(): a level that carves a deep vault
	# under one of its own floor pits (Part B/C, protocol_vault.gd) needs its
	# x-range excluded from the level-wide kill band BEFORE that band is
	# built, not patched afterward. Virtual hook, default no-op — every level
	# without a vault is unaffected.
	_register_kill_zone_gaps()
	# Adaptive difficulty (task #23): pull this player's heatmap BEFORE
	# entities spawn where possible; late-arriving tuning is applied in
	# _on_difficulty_ready (checkpoint/hint tweaks are placement-safe anytime).
	DifficultyManager.tuning_ready.connect(_on_difficulty_ready, CONNECT_ONE_SHOT)
	DifficultyManager.refresh()
	if boss_trigger:
		boss_trigger.body_entered.connect(_on_boss_trigger)
	# GameManager.current_level MUST be set before _setup_entities() spawns
	# anything. entity_spawner.gd's EntitySpawner.spawn() calls add_child() on
	# a parent (this node) that is already inside the tree, which fires the
	# new child's _ready() SYNCHRONOUSLY, in the same call — so any spawned
	# entity that reads GameManager.current_level from its own _ready() (e.g.
	# coin.gd choosing which stage's protocol logo to wear, and since this
	# pass, which system to credit for it) was reading the PREVIOUS level's
	# index on every level transition, not this one's. Harmless while
	# current_level only picked cosmetic art; no longer harmless now that it
	# also decides which currency a pickup credits (T4, "$TITANX/$DIAMONDS/
	# $GOLD are tokens and not coins" — a stale read would misattribute the
	# credit, not just the logo).
	if level_data and level_data.level_index >= 1:
		GameManager.current_level = level_data.level_index
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
	#
	# The ASSIGNMENT itself moved above (before _setup_entities()); this save
	# stays here so it still persists everything ELSE _ready() has set up by
	# this point (checkpoint state, HUD-visible stats), not just current_level.
	if level_data and level_data.level_index >= 1:
		GameManager.save_session()
	StateMachine.change_state(StateMachine.State.PLAYING)
	# S10 T6/T7 — test-only boss warp, fired after the whole _ready chain (incl.
	# subclass geometry) has run. No-op unless the page is loaded with ?boss=N.
	call_deferred("_maybe_debug_boss_warp")

## TEST-ONLY debug warp (S10 T6/T7). If the web page is loaded with `?boss=N`
## and N == this level's index, drop the player straight into the boss arena and
## fire the level's REAL `_on_boss_trigger` path, so a Playwright capture can
## record the Distributor / Claim Jumper fight without first beating Level 1's
## boss (a blind key-driver cannot, which blocked every prior S2 capture).
##
## It reuses the exact live approach (audit parity checklist): the player is
## placed just EAST of the entry trigger, then `_on_boss_trigger` runs — same
## seal wall (`arm_boss_arena_seal`), same `set_boss_background`, same arena
## bounds set on the boss BEFORE add_child. So it captures the real fight, not a
## lookalike. A normal production load has no `?boss` param, so this never fires.
func _maybe_debug_boss_warp() -> void:
	if level_data == null or level_data.boss_arena.is_empty():
		return
	var want := _requested_boss_warp()
	if want <= 0 or want != level_data.level_index:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or boss_trigger == null:
		return
	var start_x: float = level_data.boss_arena.get("start_x", 0.0)
	# Just inside the arena, east of the entry trigger, so the normal seal +
	# spawn logic runs identically to a walked-in approach.
	player.global_position = Vector2(start_x + 120.0, player.global_position.y)
	_on_boss_trigger(player)

## Reads the `?boss=N` query param on web (0 if absent / not a web build).
## Tiny + side-effect-free so it cannot affect a normal production load.
func _requested_boss_warp() -> int:
	if not OS.has_feature("web"):
		return 0
	var q: Variant = JavaScriptBridge.eval(
		"new URLSearchParams(window.location.search).get('boss') || ''", true)
	var s := str(q)
	return int(s) if s.is_valid_int() else 0

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
	# THE GREY BAR AT THE BOTTOM OF THE SCREEN.
	#
	# Founder: "I also don't want this grey block at the bottom of the screen.
	# It's eating up the real estate unnecessarily!!!"
	#
	# Sampled from his screenshots it is RGB(77,77,77) — precisely Godot's
	# DEFAULT clear colour (0.3,0.3,0.3). It was never a node: it is raw
	# viewport showing through where nothing is painted. project.godot sets
	# stretch/aspect="expand", so a browser window taller than 16:9 gives a
	# viewport TALLER than the 720px backdrop, and the uncovered strip is the
	# clear colour. (project.godot now also sets that colour to near-black as
	# a belt-and-braces second line of defence.)
	#
	# motion_scale.y = 0 pins the painting to the viewport vertically so it can
	# never slide up and expose a gap, and the fill scale is computed from the
	# LIVE viewport height rather than the baked 720 so a tall window is
	# covered too. Horizontal parallax (0.35) is unchanged, so depth still reads.
	var view_h: float = get_viewport_rect().size.y
	var fill: float = maxf(1.0, view_h / float(tex.get_height()))
	layer.motion_scale = Vector2(0.35, 0.0)
	layer.motion_mirroring = Vector2(float(tex.get_width()) * fill, 0.0)
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.centered = false
	spr.scale = Vector2(fill, fill)
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
## Slight upscale so the art reaches the top of the camera's range without
## visibly softening. Everything BELOW the floor is covered by an opaque
## skirt instead of by upscaling further — covering the full vertical range
## with the image alone would need ~2.6x and look badly blurred.
const BOSS_ART_SCALE: float = 1.15
var _boss_backdrop_sprite: Sprite2D
var _boss_backdrop_skirt: ColorRect

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
		# motion_scale 1 = moves in lockstep with the camera, exactly like real
		# geometry, so the art can never develop a parallax gap against the
		# ground it is supposed to be sitting on.
		layer.motion_scale = Vector2(1.0, 1.0)
		# Mirroring is what makes ONE 1280px image cover a 3400px+ level. It is
		# safe here precisely BECAUSE motion_scale is 1: the layer never drifts,
		# it just repeats. (At the old 0.35 motion_scale, mirroring is what
		# produced the misaligned wrapping this whole function exists to fix.)
		layer.motion_mirroring = Vector2(float(tex.get_width()) * BOSS_ART_SCALE, 0.0)
		pbg.add_child(layer)
		_boss_backdrop_sprite = Sprite2D.new()
		_boss_backdrop_sprite.centered = false
		layer.add_child(_boss_backdrop_sprite)
	_boss_backdrop_sprite.texture = tex
	_boss_backdrop_sprite.scale = Vector2(BOSS_ART_SCALE, BOSS_ART_SCALE)

	# Align the art's illustrated floor to the arena's REAL ground surface.
	var start_x: float = level_data.boss_arena.get("start_x", 0.0)
	var floor_y := _floor_y_at(start_x)
	var top_y := floor_y - BOSS_ART_FLOOR_ROW * BOSS_ART_SCALE
	# x=0: the art now starts at the LEVEL origin and tiles right across the
	# whole stage. Founder requirement, verbatim: the arena art must hold
	# "even if Lil Blunt runs back to the beginning section of the game".
	# The previous version started at (start_x - viewport/2) and so left the
	# original stage art showing everywhere west of the arena — the
	# split-screen half-FOMO/half-forest look in his screenshot.
	_boss_backdrop_sprite.position = Vector2(0.0, top_y)

	# Opaque under-floor skirt: the image bottom lands at ~782 while the
	# camera can see to ~950, and below the floor is underground anyway.
	if not is_instance_valid(_boss_backdrop_skirt):
		_boss_backdrop_skirt = ColorRect.new()
		_boss_backdrop_skirt.z_index = -6
		_boss_backdrop_skirt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_boss_backdrop_skirt)
	_boss_backdrop_skirt.color = Color(0.05, 0.03, 0.09, 1.0)
	_boss_backdrop_skirt.position = Vector2(-400.0, floor_y - 4.0)
	_boss_backdrop_skirt.size = Vector2(level_data.bounds.x + 800.0, 1200.0)

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
	# TINTED TO THE REALM. Founder: "I don't like the design of these
	# platforms. They are terrible!!!" — on the Gold Rush canyon shot.
	#
	# tile_block-chain.png is a single shared CYAN blockchain cube used by all
	# three realms. The per-level palettes in level_0N_data.tres were already
	# correct (Level 3 is gold), but they only coloured the thin body rect and
	# lip — the texture drawn on top kept rendering its own cyan, so a gold
	# canyon got teal mossy-looking ledges that clashed with everything around
	# them. Modulating toward the realm's lip colour makes one tile asset serve
	# three realms instead of fighting two of them.
	blocks.modulate = Color(
		0.55 + lip_color.r * 0.55,
		0.55 + lip_color.g * 0.45,
		0.55 + lip_color.b * 0.45,
		1.0)
	plat.add_child(blocks)

	# Drop shadow under the lip — gives the ledge thickness so it reads as a
	# solid object rather than a flat sticker on the backdrop.
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.30)
	shade.size = Vector2(w, min(6.0, h))
	shade.position = Vector2(0, min(4.0, h))
	plat.add_child(shade)

	# Bright top lip — a glowing edge so the standable surface is unmistakable.
	var lip := ColorRect.new()
	lip.color = lip_color
	lip.size = Vector2(w, min(4.0, h))
	plat.add_child(lip)

	# Warm highlight inset just under the lip, and darker edge caps at both
	# ends: cheap bevel that reads as carved rock/metal instead of a bar.
	var inner := ColorRect.new()
	inner.color = Color(lip_color.r, lip_color.g, lip_color.b, 0.28)
	inner.size = Vector2(w, 2.0)
	inner.position = Vector2(0, min(4.0, h))
	plat.add_child(inner)
	for cap_x: float in [0.0, w - 3.0]:
		var cap := ColorRect.new()
		cap.color = Color(0.0, 0.0, 0.0, 0.35)
		cap.size = Vector2(3.0, h)
		cap.position = Vector2(cap_x, 0.0)
		plat.add_child(cap)

	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(w, h)
	col.shape = shape
	col.position = Vector2(w / 2, h / 2)
	plat.add_child(col)

	add_child(plat)

## Override point (default no-op): a level that carves a deep vault under one
## of its own pits appends its vault's world x-range here, e.g.
## `kill_zone_gaps.append(Vector2(2340, 2560))`. Called from `_ready()` BEFORE
## `_setup_kill_zone()` — the vault's x-position is a design-time constant in
## the level script (the same literal already used for the vault's own
## `global_position`), so this does not need the vault node to exist yet.
func _register_kill_zone_gaps() -> void:
	pass

## ONE full-width strip when `kill_zone_gaps` is empty — byte-identical to
## this project's original behavior, so every level that doesn't register a
## gap is completely unaffected. A level that DOES register one (Part B/C's
## downward vaults) gets N strips instead, skipping the registered x-ranges,
## so a vault chamber can safely extend past the old kill_zone_y+175±200 band
## — the vault's own solid floor is the real guard against falling through
## (same "the floor is the guard" proof the vaults were already built on),
## this just stops the LEVEL-WIDE band from also claiming that same airspace.
func _setup_kill_zone() -> void:
	var full_width: float = level_data.bounds.x
	var y_centre: float = level_data.kill_zone_y + 175.0
	for interval: Vector2 in _kill_zone_strip_intervals(full_width):
		_build_kill_zone_strip(interval.x, interval.y, y_centre)

## Splits [0, full_width] into strips excluding `kill_zone_gaps`. Gaps are
## sorted and clamped to the level bounds first so registration order and
## slightly-oversized ranges can't produce overlapping or out-of-bounds
## strips.
func _kill_zone_strip_intervals(full_width: float) -> Array[Vector2]:
	if kill_zone_gaps.is_empty():
		return [Vector2(0.0, full_width)]
	var gaps := kill_zone_gaps.duplicate()
	gaps.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var intervals: Array[Vector2] = []
	var cursor := 0.0
	for gap: Vector2 in gaps:
		var gap_lo: float = clampf(gap.x, 0.0, full_width)
		var gap_hi: float = clampf(gap.y, 0.0, full_width)
		if gap_lo > cursor:
			intervals.append(Vector2(cursor, gap_lo))
		cursor = maxf(cursor, gap_hi)
	if cursor < full_width:
		intervals.append(Vector2(cursor, full_width))
	return intervals

func _build_kill_zone_strip(x_lo: float, x_hi: float, y_centre: float) -> void:
	var w: float = x_hi - x_lo
	if w <= 0.0:
		return
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
	shape.size = Vector2(w, 400)
	col.shape = shape
	kill_zone.add_child(col)
	kill_zone.position = Vector2(x_lo + w / 2.0, y_centre)
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
			_seal_wall = _create_wall(_seal_x, 400, 20, 600, true)
	elif p.global_position.x < _seal_x - 40.0:
		# Player is back outside (death + respawn at a western checkpoint):
		# drop the wall so they can walk in and re-engage.
		_seal_wall.queue_free()
		_seal_wall = null
	# END THE FIGHT WHENEVER THE PLAYER IS OUTSIDE — NOT ONLY ON THE FRAME THE
	# WALL COMES DOWN.
	#
	# This used to live inside the `elif` above, which made it conditional on
	# `_seal_wall` currently existing. Two real ways that misses:
	#   * the player triggers the boss but turns back west before ever crossing
	#     `_seal_x + 60`, so the wall is never raised and the `elif` is never
	#     reached at all;
	#   * the wall came down on an earlier trip, leaving `_seal_wall` null, so a
	#     second retreat re-enters the `if` branch instead.
	# Either way the boss stayed alive with an unreachable target — the exact
	# frozen-boss state this teardown exists to prevent. Checking the player's
	# position directly is unconditional, and _end_boss_fight() is a no-op once
	# the latch is already clear, so running it every frame while outside is
	# cheap and idempotent.
	if p.global_position.x < _seal_x - 40.0:
		_end_boss_fight()

## THE "BOSS DOESN'T MOVE" SHARED ROOT CAUSE (2026-08-19 forensic pass).
##
## Every boss is clamped STRICTLY INSIDE its own arena box (distributor and
## claim_jumper via _clamp_to_arena; see each boss's own arena_min/arena_max).
## The player, however, could be OUTSIDE that box while the fight was still
## live — the seal above drops the moment they walk back west, but nothing
## ended the fight, so the boss stayed alive, kept pursuing a target it was
## structurally forbidden from reaching, and sat welded to its clamp.
##
## Measured, not assumed: photogrammetry on the founder's own Stage 2
## screenshot puts Lil Blunt at world x~3109 — 591 px WEST of that arena's
## start_x (3700) — while the Distributor sits at ~3813, i.e. pinned on his
## west clamp (his reachable centre range is only [3820, 4280]). The Stage 1
## shot shows the same shape: player retreated ~900 px west, boss never left
## the arena mouth. That is exactly "THE BOSS IS NOT FUCKING MOVING": he
## genuinely cannot, and no amount of speed/acceleration/standoff tuning
## (this repo has ~10 such attempts recorded in comments) can fix a boss whose
## target is outside his own permitted world.
##
## It also explains the companion complaint that the Stage 3 boss is "way too
## easy to defeat": a wall-pinned boss is a stationary target that can be shot
## from safety, outside his reach, indefinitely.
##
## The fix is to make the two rules stop contradicting each other. The fight is
## only coherent while the player is inside the arena, so leaving it ENDS the
## fight rather than freezing it: the boss is freed and the level's own
## `_boss_arena_active` latch is cleared, so walking back in re-runs
## `_on_boss_trigger` and starts a clean fight.
##
## This deliberately does NOT just re-seal the player in. The seal's drop
## behaviour exists to prevent a real soft-lock — checkpoints sit WEST of every
## arena, so a player who dies mid-fight respawns outside a wall that is
## already up, permanently locked out of a fight they can neither finish nor
## leave. Ending the fight preserves that escape hatch instead of trading one
## trap for another.
func _end_boss_fight() -> void:
	# `_boss_arena_active` is declared on each concrete level script, not here,
	# so it is cleared dynamically. get()/set() resolve it on the instance; the
	# guard keeps this a no-op for any level that has no boss.
	if get("_boss_arena_active") == null:
		return
	set("_boss_arena_active", false)
	for boss in get_tree().get_nodes_in_group("boss"):
		if is_instance_valid(boss):
			boss.queue_free()

## Returns the wall so the boss-arena seal can take it back down again
## (existing callers ignore the return value).
## `player_only` walls collide with the player and nothing else.
##
## The boss-arena SEAL used a plain StaticBody2D on the default World layer, so
## it blocked the BOSS as well as the player. That is the Stage 1 half of "the
## boss cant get passed this point": the Auditor has no arena clamp at all, yet
## a probe with the player parked at the arena's west edge (x=2830) measured him
## hard-stopped at x=2905 — his body flush against the seal wall at 2800, 75px
## short of the player, forever. The wall was caging the boss out of the very
## pocket the player was standing in.
##
## Layer 8 (Player) is the only bit the player's own mask reads, so a
## player-only wall still seals the player in while the boss can cross it.
## Containing the BOSS is the arena clamp's job, not this wall's.
func _create_wall(x: float, y: float, w: float, h: float, player_only: bool = false) -> StaticBody2D:
	var wall := StaticBody2D.new()
	wall.position = Vector2(x, y)
	if player_only:
		wall.collision_layer = 8
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
	# 3. Hint Leaf — DISABLED (founder, 2026-08-19).
	#
	# "I noticed these leaves in the very 1st point of each stage all of a
	# sudden. Remove them. They have no function."
	#
	# They were adaptive difficulty: DifficultyManager.hint_leaf turns on for
	# players who die repeatedly, and _spawn_hint_leaf() drops a green weed leaf
	# at player_spawn + (90,-20) which lights the checkpoint route for 5s. That
	# explains both halves of his report — "all of a sudden" (it switched on
	# after a run of deaths) and "in the very 1st point of EACH stage" (it is
	# anchored to every level's spawn). To him it reads as an inert prop,
	# because its one interaction is invisible until touched.
	#
	# The spawner is kept, not deleted, so the mechanic can be reinstated
	# deliberately (with a readable tell) rather than rebuilt from scratch.
	# Nothing else calls it, so it is simply never invoked today.

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
