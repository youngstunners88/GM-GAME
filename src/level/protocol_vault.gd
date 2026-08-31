extends Node2D
## PROTOCOL VAULT — a downward, in-level "complete section" the player drops
## into through a floor mouth: a multi-tier chamber with a protocol-themed
## hazard, two distinct interactables, a coin hoard, and a ladder back out.
##
## Founder, this session (after the first, single-tier version shipped):
## "needs to be complete sections of their own; not just a hole in the ground
## with a ladder and tokens." Required and delivered here: multiple platform
## tiers (not one pit floor), a protocol-appropriate hazard, 2+ interactable
## types beyond a coin pile, real founder-supplied art, and a real
## enter -> explore -> interact -> reward -> exit loop. Still a downward drop
## + upward ladder exit, still distinct from the scene-loading Blaze Rush /
## Smoke Lounge / Secret Realm entrances (this is in-level, no scene load).
##
## Parametric by protocol so Stage 2's Diamond Vault (DIAMONDS) and Stage 3's
## Fort Knox (GOLD MINE) share one implementation — same reuse pattern
## `hall_of_blaze` (room_title) and `ladder` (exports) already use.
##
## Design + verification came from a mandated multi-model pass (logged in
## docs/model-responses/2026-08-12-s3-*.md):
##   Fable — multi-tier layout, kill-zone-gap depth argument, real-art placement
##   Grok  — protocol identity / interactable readability / layering rules
##   Kimi  — S2/S3 boss numbers (separate systems) + vault soft-lock invariants
##
## DEPTH: this vault registers an x-range gap in its level's kill zone (see
## `level_base.gd::kill_zone_gaps` / `_register_kill_zone_gaps()`) so the
## chamber can extend well past the old ~175px band without the level-wide
## pit-death Area2D reaching into it. The vault's OWN solid floor is still the
## real safety guard — same "the floor is the guard" proof the original
## single-tier version was built on, just with more room underneath it.

## "diamonds" -> Diamond Vault (Stage 2). "gold" -> Fort Knox (Stage 3).
@export var protocol: String = "diamonds"
## Width of the floor opening the player drops through. L2 pit = 100, L3 = 140.
@export var mouth_width: float = 100.0

const SURFACE_Y: float = 650.0        # walk surface; vault origin sits here
const FLOOR_TOP: float = 305.0        # solid floor surface, local space
const FLOOR_THICK: float = 40.0
const WALL_THICK: float = 16.0
const WALL_TOP_Y: float = 60.0        # overlaps the segment underside (0..70) -> no seam
const LADDER_HEIGHT: float = FLOOR_TOP + 40.0
const LADDER_INSET: float = 22.0      # ladder sits this far in from the mouth's east edge
const LADDER_LAND_PAST: float = 40.0  # top-out lands this far past the mouth edge onto real ground
const TIER1_Y: float = 150.0
const TIER2_Y: float = 230.0
const TIER_THICK: float = 20.0
const OUTER_MARGIN: float = 100.0     # interior room beyond the mouth half-width, each side

## World x-range this vault's chamber occupies — used by the level script to
## register the matching kill-zone gap BEFORE `_setup_kill_zone()` runs (see
## `level_base.gd::_register_kill_zone_gaps()`), so it can't drift out of sync
## with the actual built geometry. Read this AFTER setting `global_position`
## and `mouth_width` but does not require the node to be added to the tree.
func kill_zone_gap_range() -> Vector2:
	var outer: float = mouth_width / 2.0 + OUTER_MARGIN
	return Vector2(global_position.x - outer, global_position.x + outer)

var _diamonds: bool = true
var _deposit_used: bool = false
var _switch_used: bool = false
var _hazard_timer: float = 0.0
## The two interact props, tracked directly (not via a dynamically-attached
## script/signal — Area2D.set_script() after add_child() does not reliably
## re-run _ready(), so press-detection lives here instead, matching
## melt_forge.gd's proven `player_in_forge` + Input.is_action_just_pressed
## pattern).
var _deposit_prop: Area2D
var _switch_prop: Area2D
var _player_at_deposit: bool = false
var _player_at_switch: bool = false

func _ready() -> void:
	_diamonds = protocol == "diamonds"
	var half: float = mouth_width / 2.0
	var outer: float = half + OUTER_MARGIN

	_build_shell(half, outer)
	_build_tiers(half, outer)
	_build_backdrop(outer)
	_build_mouth_frame(half)
	_build_interactables(half, outer)
	if not _diamonds:
		_build_gear_guard(half, outer)
	_build_exit_ladder(half)
	_spawn_shaft_coins(half)
	if MobileInputHandler:
		MobileInputHandler.touch_interact.connect(_on_mobile_interact)
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	if _player_at_deposit and Input.is_action_just_pressed("interact"):
		_on_deposit_pillar_used()
	if _player_at_switch and Input.is_action_just_pressed("interact"):
		_on_switch_used()
	_hazard_timer -= delta
	if _hazard_timer <= 0.0:
		_hazard_timer = 2.4
		if _diamonds:
			_drop_crystal_shard()
		# Fort Knox's gear guard is a continuous Tween patrol, built once in
		# _ready() — nothing to do here for it.

func _on_mobile_interact() -> void:
	if _player_at_deposit:
		_on_deposit_pillar_used()
	elif _player_at_switch:
		_on_switch_used()

# --- SOLID CHAMBER ----------------------------------------------------------

func _build_shell(half: float, outer: float) -> void:
	var body_col: Color = Color(0.18, 0.28, 0.38, 1.0) if _diamonds else Color(0.25, 0.22, 0.15, 1.0)
	var wall_col: Color = Color(0.2, 0.32, 0.42, 1.0) if _diamonds else Color(0.3, 0.27, 0.2, 1.0)
	# Floor spans the full OUTER width so both walls stand ON it — no
	# wall/floor seam a corner-clip could exploit.
	_add_solid(Vector2(0.0, FLOOR_TOP + FLOOR_THICK / 2.0), Vector2(outer * 2.0, FLOOR_THICK), body_col)
	# Side walls: top overlaps the level's own ground-segment underside
	# (0..70 local), bottom flush with the floor — no gap to slip through.
	var wall_h: float = (FLOOR_TOP + FLOOR_THICK) - WALL_TOP_Y
	var wall_cy: float = WALL_TOP_Y + wall_h / 2.0
	_add_solid(Vector2(-(outer - WALL_THICK / 2.0), wall_cy), Vector2(WALL_THICK, wall_h), wall_col)
	_add_solid(Vector2(outer - WALL_THICK / 2.0, wall_cy), Vector2(WALL_THICK, wall_h), wall_col)

func _build_tiers(half: float, outer: float) -> void:
	var tier_col: Color = Color(0.32, 0.55, 0.65, 1.0) if _diamonds else Color(0.5, 0.4, 0.22, 1.0)
	# West-side tiers, clear of the mouth and the ladder (which hugs the east
	# wall — see _build_exit_ladder). Span from just past the west wall to
	# just short of the mouth's west edge.
	var tier_w: float = (outer - WALL_THICK) - half
	var tier_cx: float = -(half + tier_w / 2.0)
	_add_solid(Vector2(tier_cx, TIER1_Y), Vector2(tier_w, TIER_THICK), tier_col)
	_add_solid(Vector2(tier_cx, TIER2_Y), Vector2(tier_w, TIER_THICK), tier_col)

## Adds a solid StaticBody2D box (world-collision layer 1) centred at
## `center_local`, with a visible coloured base so the geometry reads.
func _add_solid(center_local: Vector2, size: Vector2, color: Color) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = center_local
	var vis := ColorRect.new()
	vis.size = size
	vis.position = -size / 2.0
	vis.color = color
	body.add_child(vis)
	# A thin bright lip on top so platform edges read clearly against the
	# busier backdrop art (Grok: "1px dark outline... full saturation, protocol
	# edge tint" for walkables vs the desaturated backdrop).
	var lip := ColorRect.new()
	lip.size = Vector2(size.x, 3.0)
	lip.position = Vector2(-size.x / 2.0, -size.y / 2.0)
	lip.color = Color(0.6, 1.0, 0.95, 0.9) if _diamonds else Color(0.95, 0.75, 0.3, 0.9)
	body.add_child(lip)
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	body.add_child(cs)
	add_child(body)

# --- REAL FOUNDER ART --------------------------------------------------------

## Sprite2D, clipped to the interior window, well behind all gameplay
## geometry. NOT a ParallaxBackground (that's a viewport-global CanvasLayer
## technique the boss arenas use because the whole screen IS the arena; a
## vault chamber is a small local window, so a Sprite2D anchored to this node
## is correct instead — Fable's correction from the first draft).
func _build_backdrop(outer: float) -> void:
	var clip := ColorRect.new()
	clip.color = Color(0.02, 0.03, 0.05, 1.0)
	clip.size = Vector2(outer * 2.0, (FLOOR_TOP + FLOOR_THICK) - WALL_TOP_Y)
	clip.position = Vector2(-outer, WALL_TOP_Y)
	clip.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	clip.z_index = -10
	add_child(clip)

	var art := Sprite2D.new()
	art.texture = load(
		"res://src/assets/art/vaults/diamond_vault_backdrop.png" if _diamonds
		else "res://src/assets/art/vaults/fort_knox_backdrop.png")
	if art.texture:
		var scale_to_cover: float = clip.size.y / float(art.texture.get_height())
		art.scale = Vector2(scale_to_cover, scale_to_cover) * 1.2
	art.centered = true
	art.position = Vector2(0.0, WALL_TOP_Y + clip.size.y / 2.0) - clip.position
	art.modulate = Color(0.85, 0.85, 0.9, 1.0)  # slight darken vs. the playable layer
	clip.add_child(art)

## Drop-in mouth dressing on the surface line: a crystal collar (DIAMONDS) or
## a riveted steel hatch (GOLD), plus a bobbing downward chevron. Decor only,
## no collision — carried over from the shipped single-tier version.
func _build_mouth_frame(half: float) -> void:
	var lip := ColorRect.new()
	lip.size = Vector2(half * 2.0, 8.0)
	lip.position = Vector2(-half, -8.0)
	lip.color = Color(0.6, 1.0, 0.95, 0.55) if _diamonds else Color(0.9, 0.7, 0.3, 0.9)
	add_child(lip)
	if _diamonds:
		for sign_x: float in [-1.0, 1.0]:
			var facet := Polygon2D.new()
			facet.polygon = PackedVector2Array([
				Vector2(sign_x * half, -8), Vector2(sign_x * (half - 22), -8), Vector2(sign_x * half, 14)])
			facet.color = Color(0.45, 0.95, 1.0, 0.85)
			add_child(facet)
	else:
		for sign_x: float in [-1.0, 1.0]:
			var leaf := ColorRect.new()
			leaf.size = Vector2(18.0, 14.0)
			leaf.position = Vector2(sign_x * half - (18.0 if sign_x > 0 else 0.0), -14.0)
			leaf.color = Color(0.45, 0.42, 0.38, 1.0)
			add_child(leaf)
	var chevron := Polygon2D.new()
	chevron.polygon = PackedVector2Array([Vector2(-10, -30), Vector2(10, -30), Vector2(0, -18)])
	chevron.color = Color(0.6, 1.0, 0.95, 0.85) if _diamonds else Color(1.0, 0.8, 0.35, 0.9)
	add_child(chevron)
	var bob := chevron.create_tween().set_loops()
	bob.tween_property(chevron, "position:y", 4.0, 0.8).set_trans(Tween.TRANS_SINE)
	bob.tween_property(chevron, "position:y", 0.0, 0.8).set_trans(Tween.TRANS_SINE)

# --- INTERACTABLES (2 distinct types, per the founder's requirement) -------

## Both use the same "interact" action `melt_forge.gd` already established
## (keyboard + MobileInputHandler.touch_interact), so controls stay consistent
## project-wide rather than inventing a second input convention.
func _build_interactables(half: float, outer: float) -> void:
	var tier_w: float = (outer - WALL_THICK) - half
	var tier_cx: float = -(half + tier_w / 2.0)

	# INTERACTABLE 1 — deposit pillar (Diamond) / melt forge (Fort Knox), on
	# the deeper tier. Fort Knox reuses the real melt_forge entity (it already
	# has a proven burn-GOLD-for-a-boost mechanic, press-E, mobile-parity);
	# Diamond gets a bespoke deposit pillar since no equivalent DIAMONDS
	# entity exists yet.
	if _diamonds:
		_deposit_prop = _make_interact_prop(
			"res://src/assets/art/vaults/diamond_deposit_pillar.png",
			Vector2(tier_cx, TIER2_Y - TIER_THICK / 2.0 - 70.0), true)
	else:
		var forge := preload("res://src/level/melt_forge.tscn").instantiate()
		forge.global_position = global_position + Vector2(tier_cx, TIER2_Y - TIER_THICK / 2.0 - 40.0)
		get_parent().add_child.call_deferred(forge)

	# INTERACTABLE 2 — a switch/lever on the shallow tier that triggers the
	# vault-door reveal + the coin hoard. Distinct mechanic from #1 (a
	# one-shot "open" trigger vs. #1's resource-producing prop), satisfying
	# the founder's "2+ interactable types beyond a coin pile."
	_switch_prop = _make_interact_prop(
		"res://src/assets/art/vaults/fort_knox_vault_door.png" if not _diamonds else "",
		Vector2(tier_cx, TIER1_Y - TIER_THICK / 2.0 - 20.0), false)

## A minimal interactable prop: an Area2D with a sprite (or a plain glyph if
## no texture path is given) and idle-vs-triggered visual states (Grok:
## continuous idle motion marks it interactive; a "spent" state stops the
## pulse so it can't misread as reusable). Press-detection is driven by the
## VAULT's own _physics_process via `_player_at_deposit`/`_player_at_switch`
## — see that function's header comment for why this isn't a per-prop script.
func _make_interact_prop(texture_path: String, local_pos: Vector2, is_deposit: bool) -> Area2D:
	var prop := Area2D.new()
	prop.collision_layer = 0
	prop.collision_mask = 2
	prop.position = local_pos
	add_child(prop)

	var visual: Node2D
	if texture_path != "" and ResourceLoader.exists(texture_path):
		var spr := Sprite2D.new()
		spr.texture = load(texture_path)
		spr.centered = true
		visual = spr
	else:
		# Bespoke deposit pillar has no separate small icon — draw a simple
		# glyph pedestal instead of a second art asset.
		var poly := Polygon2D.new()
		poly.polygon = PackedVector2Array([Vector2(0, -20), Vector2(16, 0), Vector2(0, 20), Vector2(-16, 0)])
		poly.color = Color(0.6, 1.0, 0.95, 0.9) if _diamonds else Color(0.95, 0.75, 0.3, 0.9)
		visual = poly
	visual.z_index = -1
	prop.add_child(visual)

	var cs := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 34.0
	cs.shape = circ
	prop.add_child(cs)

	# Idle breathing glow — continuous motion marks "this is interactive"
	# (Grok's readability rule) vs. static decoration nearby.
	var glow := create_tween().set_loops()
	glow.tween_property(visual, "modulate", Color(1.3, 1.3, 1.3, 1.0), 0.75).set_trans(Tween.TRANS_SINE)
	glow.tween_property(visual, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.75).set_trans(Tween.TRANS_SINE)
	prop.set_meta("visual", visual)
	prop.set_meta("glow_tween", glow)

	prop.body_entered.connect(func(b: Node2D) -> void:
		if b.is_in_group("player"):
			if is_deposit:
				_player_at_deposit = true
			else:
				_player_at_switch = true)
	prop.body_exited.connect(func(b: Node2D) -> void:
		if b.is_in_group("player"):
			if is_deposit:
				_player_at_deposit = false
			else:
				_player_at_switch = false)
	return prop

func _on_deposit_pillar_used() -> void:
	if _deposit_used or _deposit_prop == null:
		return
	_deposit_used = true
	var coin_id := "coin_diamonds" if _diamonds else "coin_goldmine"
	var lvl := get_parent()
	if lvl != null:
		for i in range(3):
			var ang: float = TAU * float(i) / 3.0
			var offset := Vector2(cos(ang), sin(ang)) * 30.0
			EntitySpawner.spawn(coin_id, _deposit_prop.global_position + offset, lvl)
	AudioManager.play_sfx("powerup")
	ScreenShake.light()
	_freeze_prop(_deposit_prop)

func _on_switch_used() -> void:
	if _switch_used or _switch_prop == null:
		return
	_switch_used = true
	var coin_id := "coin_diamonds" if _diamonds else "coin_goldmine"
	var lvl := get_parent()
	if lvl != null:
		for i in range(6):
			var offset := Vector2(-40.0 + float(i) * 16.0, -30.0)
			EntitySpawner.spawn(coin_id, _switch_prop.global_position + offset, lvl)
	AudioManager.play_sfx("powerup")
	ScreenShake.medium()
	var visual: Node2D = _switch_prop.get_meta("visual")
	if visual:
		var t := _switch_prop.create_tween()
		t.tween_property(visual, "rotation", deg_to_rad(90.0), 0.6)
		t.parallel().tween_property(visual, "position:x", visual.position.x + 30.0, 0.6)
	_freeze_prop(_switch_prop)

func _freeze_prop(prop: Area2D) -> void:
	var glow: Tween = prop.get_meta("glow_tween")
	if glow:
		glow.kill()
	var visual: Node2D = prop.get_meta("visual")
	if visual:
		visual.modulate = Color(0.5, 0.5, 0.5, 1.0)  # spent = desaturated, no pulse (Grok's rule)
	prop.monitoring = false

# --- HAZARD ------------------------------------------------------------------

## Diamond Vault: a telegraphed ceiling shard drop. Fort Knox's own hazard is
## a continuous patrolling gear (built once, drives itself via Tween — see
## _build_gear_guard, called from _build_tiers' caller below).
func _drop_crystal_shard() -> void:
	var half: float = mouth_width / 2.0
	var x: float = -(half + OUTER_MARGIN * 0.5)
	var shard := Area2D.new()
	shard.collision_layer = 0
	shard.collision_mask = 2
	shard.position = Vector2(x, WALL_TOP_Y + 10.0)
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([Vector2(0, -14), Vector2(8, 10), Vector2(-8, 10)])
	poly.color = Color(0.55, 0.9, 1.0, 0.95)
	shard.add_child(poly)
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(14, 20)
	cs.shape = rect
	shard.add_child(cs)
	add_child(shard)
	# Telegraph: brief glow before it actually starts falling and can hurt.
	poly.modulate = Color(2.0, 2.0, 2.0, 0.6)
	var tw := shard.create_tween()
	tw.tween_property(poly, "modulate", Color(1, 1, 1, 1), 0.4)
	shard.set_meta("armed", false)
	get_tree().create_timer(0.4).timeout.connect(func() -> void:
		if is_instance_valid(shard):
			shard.set_meta("armed", true))
	shard.body_entered.connect(func(b: Node2D) -> void:
		if bool(shard.get_meta("armed")) and b.is_in_group("player") and b.has_method("take_damage"):
			b.take_damage(1)
			shard.queue_free())
	var fall := shard.create_tween()
	fall.tween_interval(0.4)
	fall.tween_property(shard, "position:y", FLOOR_TOP - 10.0, 0.5)
	fall.finished.connect(func() -> void:
		if is_instance_valid(shard):
			shard.queue_free())

## Fort Knox's continuous hazard: a spinning gear that patrols the tier lane.
## Called once from _ready() via _build_tiers' sibling below.
func _build_gear_guard(half: float, outer: float) -> void:
	var tier_w: float = (outer - WALL_THICK) - half
	var tier_cx: float = -(half + tier_w / 2.0)
	var gear := Area2D.new()
	gear.collision_layer = 0
	gear.collision_mask = 2
	gear.position = Vector2(tier_cx, TIER1_Y - 14.0)
	var poly := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(8):
		var a: float = TAU * float(i) / 8.0
		var r: float = 16.0 if i % 2 == 0 else 11.0
		pts.append(Vector2(cos(a), sin(a)) * r)
	poly.polygon = pts
	poly.color = Color(0.55, 0.45, 0.2, 1.0)
	gear.add_child(poly)
	var cs := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 14.0
	cs.shape = circ
	gear.add_child(cs)
	add_child(gear)
	var spin := gear.create_tween().set_loops()
	spin.tween_property(poly, "rotation", TAU, 1.2).set_trans(Tween.TRANS_LINEAR)
	var patrol := gear.create_tween().set_loops()
	patrol.tween_property(gear, "position:x", tier_cx - tier_w * 0.35, 1.3).set_trans(Tween.TRANS_SINE)
	patrol.tween_property(gear, "position:x", tier_cx + tier_w * 0.35, 1.3).set_trans(Tween.TRANS_SINE)
	gear.body_entered.connect(func(b: Node2D) -> void:
		if b.is_in_group("player") and b.has_method("take_damage"):
			b.take_damage(1))

# --- REWARD + EXIT -----------------------------------------------------------

func _spawn_shaft_coins(half: float) -> void:
	var coin_id := "coin_diamonds" if _diamonds else "coin_goldmine"
	var lvl := get_parent()
	if lvl == null:
		return
	EntitySpawner.spawn(coin_id, global_position + Vector2(0.0, 55.0), lvl)
	EntitySpawner.spawn(coin_id, global_position + Vector2(0.0, 95.0), lvl)

## Geometry, in local space (origin = mouth centre on the surface line):
##   ladder x  = half - LADDER_INSET       (hugs the east wall)
##   landing x = half + LADDER_LAND_PAST   (past the mouth edge, onto ground)
##   offset.x  = landing - ladder = LADDER_LAND_PAST + LADDER_INSET  (constant,
##              independent of mouth_width, so a resize can never desync it —
##              Kimi's proof from the single-tier version still holds).
func _build_exit_ladder(half: float) -> void:
	var ladder := preload("res://src/level/ladder.tscn").instantiate()
	ladder.height = LADDER_HEIGHT
	ladder.top_exit_offset = Vector2(LADDER_LAND_PAST + LADDER_INSET, -16.0)
	# A vault's only way out — never let the big axe shear it (soft-lock proof
	# from the single-tier version: a destroyed sole exit over a floor that
	# guards the kill band is unrecoverable).
	ladder.destructible = false
	ladder.rung_color = Color(0.4, 0.85, 0.95, 1.0) if _diamonds else Color(0.75, 0.6, 0.28, 1.0)
	ladder.position = Vector2(half - LADDER_INSET, 0.0)
	add_child(ladder)
