extends Node2D
## PROTOCOL VAULT — a downward, in-level set-piece the player DROPS into
## through a floor mouth, loots, and climbs back out of. Parametric by
## protocol so Stage 2's **Diamond Vault** (DIAMONDS) and Stage 3's **Fort
## Knox** (GOLD MINE) share one implementation, differing only in palette,
## mouth dressing, and which protocol coin they reward — the same reuse
## pattern `hall_of_blaze` (room_title) and `ladder` (exports) already use.
##
## DELIBERATELY NOT the Blaze Portal / Smoke Lounge / Secret Realm pattern:
## those are HORIZONTAL Area2Ds that SceneRouter.load_scene() into a separate
## scene (a stage wipe). A vault is a "strong hub" carved into the SAME level —
## the player physically drops down and climbs back up, no scene load. The
## downward axis alone already separates it from every existing entrance.
##
## Design + verification came from a mandated multi-model pass (logged in
## docs/model-responses/2026-08-12-partb-*.md):
##   Grok  — protocol identity / "this is a vault, not a death pit" readability
##   Kimi  — entrance/exit collision + soft-lock proof (the numbers below)
##   Fable — parametric structure + level wiring
##
## GEOMETRY (all derived from mouth_width so a resize can't desync — the exact
## class of drift that broke a Stage 2 ladder before). Origin = the mouth
## centre on the walk surface (y = SURFACE_Y). The player is 32x32; a single
## jump clears only ~92px, so the 150px climb out MUST be the ladder.
##
## The chamber floor sits ABOVE the full-width kill band (top ~825), so it is
## the guard: the player rests at feet 800 / centre 784, 25px clear, and the
## kill zone (mask = player-only) never detects the StaticBody floor. No
## kill-zone edits are needed or made.

## "diamonds" -> Diamond Vault (Stage 2). "gold" -> Fort Knox (Stage 3).
@export var protocol: String = "diamonds"
## Width of the floor opening the player drops through. L2 pit = 100, L3 = 140.
@export var mouth_width: float = 100.0

const SURFACE_Y: float = 650.0        # walk surface; vault origin sits here
const CHAMBER_FLOOR_TOP: float = 800.0 # solid floor surface, 25px above kill band
const FLOOR_THICK: float = 40.0
const WALL_THICK: float = 16.0
const WALL_TOP_Y: float = 700.0       # overlaps segment underside (650..720) -> no seam
const LADDER_HEIGHT: float = 170.0
## Ladder is inset this far from the mouth's inner edge (hugs the right wall).
const LADDER_INSET: float = 22.0
## Player centre lands this far PAST the mouth edge, onto the exit segment.
## +-16 body -> 24px clear of the drop. See the top-out block for the offset
## derivation (it's a constant, LADDER_LAND_PAST + LADDER_INSET, so it can
## never desync from mouth_width).
const LADDER_LAND_PAST: float = 40.0

func _ready() -> void:
	var half := mouth_width / 2.0
	var diamonds := protocol == "diamonds"

	# --- SOLID CHAMBER (StaticBody2D, layer 1 — same as level_base platforms) ---
	# Floor spans the full OUTER width so both walls stand ON it: no wall/floor
	# seam a corner-clip could exploit toward the kill band.
	var outer := half + WALL_THICK
	_add_solid(Vector2(0.0, CHAMBER_FLOOR_TOP + FLOOR_THICK / 2.0 - SURFACE_Y),
		Vector2(outer * 2.0, FLOOR_THICK),
		Color(0.18, 0.28, 0.38, 1.0) if diamonds else Color(0.25, 0.22, 0.15, 1.0))
	# Side walls flank the mouth, inner face exactly at the mouth edge, running
	# from WALL_TOP_Y down flush with the floor bottom. Wall top overlaps the
	# segment body (650..720), so there is no gap to slip through and no exposed
	# top to jump onto.
	var wall_cy := (WALL_TOP_Y + CHAMBER_FLOOR_TOP + FLOOR_THICK) / 2.0 - SURFACE_Y
	var wall_h := (CHAMBER_FLOOR_TOP + FLOOR_THICK) - WALL_TOP_Y
	var wall_body_col := Color(0.2, 0.32, 0.42, 1.0) if diamonds else Color(0.3, 0.27, 0.2, 1.0)
	_add_solid(Vector2(-(half + WALL_THICK / 2.0), wall_cy), Vector2(WALL_THICK, wall_h), wall_body_col)
	_add_solid(Vector2(half + WALL_THICK / 2.0, wall_cy), Vector2(WALL_THICK, wall_h), wall_body_col)

	# --- INTERIOR IDENTITY (decor only, never collides) ---
	_build_interior(diamonds, half)
	_build_mouth_frame(diamonds, half)

	# --- REWARD: 5 protocol coins (2 grabbed on the way down + 3 on the floor) ---
	# Spawned under the LEVEL (get_parent), not this node: EntitySpawner sets
	# global_position before add_child, so a transformed parent would double the
	# offset. The level sits at the origin, so absolute coords are correct there.
	var lvl := get_parent()
	var coin_id := "coin_diamonds" if diamonds else "coin_goldmine"
	if lvl != null:
		EntitySpawner.spawn(coin_id, global_position + Vector2(0.0, 55.0), lvl)   # shaft
		EntitySpawner.spawn(coin_id, global_position + Vector2(0.0, 95.0), lvl)   # shaft
		for dx: float in [-half * 0.5, 0.0, half * 0.5]:
			EntitySpawner.spawn(coin_id, global_position + Vector2(dx, 116.0), lvl)  # floor (y 766)

	# --- UPWARD EXIT LADDER (the no-soft-lock guarantee) ---
	# Hug the right (exit-side) wall so the climb clears the wall and the
	# top-out lands on the segment EAST of the pit — never over the pit itself
	# (the default (0,-20) offset would land over air: the exact bug that once
	# blocked Stage 2). Geometry, in this node's local space (origin = mouth
	# centre on the surface line):
	#   ladder x   = half - LADDER_INSET       (inset from the mouth edge)
	#   landing x  = half + LADDER_LAND_PAST    (past the mouth edge, onto seg)
	#   offset.x   = landing - ladder = LADDER_LAND_PAST + LADDER_INSET  (const,
	#               independent of mouth_width, so a resize can never desync it)
	# For LAND_PAST 40 + INSET 22 -> offset.x = 62; player centre lands 40px onto
	# the segment, box +-16 -> 24px clear of the pit edge (Kimi's top-out proof).
	var ladder := preload("res://src/level/ladder.tscn").instantiate()
	ladder.height = LADDER_HEIGHT
	ladder.top_exit_offset = Vector2(LADDER_LAND_PAST + LADDER_INSET, -16.0)
	# A vault's only way out — never let the big axe shear it (Kimi soft-lock).
	ladder.destructible = false
	ladder.rung_color = Color(0.4, 0.85, 0.95, 1.0) if diamonds else Color(0.75, 0.6, 0.28, 1.0)
	ladder.position = Vector2(half - LADDER_INSET, 0.0)  # local; origin is the surface line
	add_child(ladder)

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
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	body.add_child(cs)
	add_child(body)

## Non-colliding interior dressing: wall tints, a back-wall protocol emblem,
## and the signature particle VFX. z_index negative so it sits behind coins,
## the ladder, and the player.
func _build_interior(diamonds: bool, half: float) -> void:
	# Light well: a soft vertical glow down the shaft so the opening reads as a
	# lit chamber with a floor, not a black death pit (Grok's key cue).
	var well := ColorRect.new()
	well.size = Vector2(mouth_width, CHAMBER_FLOOR_TOP - SURFACE_Y)
	well.position = Vector2(-half, 0.0)
	well.color = Color(0.3, 0.8, 0.9, 0.12) if diamonds else Color(0.9, 0.7, 0.25, 0.10)
	well.z_index = -3
	add_child(well)

	# Back-wall emblem, upper interior (visible from the mouth before dropping):
	# a cyan rhombus (DIAMONDS) or a brass vault wheel (GOLD).
	var emblem := Polygon2D.new()
	emblem.z_index = -2
	emblem.position = Vector2(0.0, 108.0)  # abs y ~758, upper-mid interior
	if diamonds:
		emblem.polygon = PackedVector2Array([Vector2(0, -22), Vector2(16, 0), Vector2(0, 22), Vector2(-16, 0)])
		emblem.color = Color(0.55, 0.95, 1.0, 0.7)
	else:
		# Blocky vault-wheel: octagon ring feel via a filled octagon.
		emblem.polygon = PackedVector2Array([
			Vector2(-10, -20), Vector2(10, -20), Vector2(20, -10), Vector2(20, 10),
			Vector2(10, 20), Vector2(-10, 20), Vector2(-20, 10), Vector2(-20, -10)])
		emblem.color = Color(0.85, 0.65, 0.25, 0.7)
	add_child(emblem)

	var motes := CPUParticles2D.new()
	motes.texture = load("res://src/assets/sprites/fx_dot.png")
	motes.position = Vector2(0.0, 40.0)
	motes.amount = 12
	motes.lifetime = 1.8
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2(half, 6.0)
	motes.gravity = Vector2.ZERO
	motes.scale_amount_min = 0.15
	motes.scale_amount_max = 0.4
	motes.z_index = -1
	if diamonds:
		# Prismatic motes drifting DOWN into the shaft.
		motes.direction = Vector2(0.0, 1.0)
		motes.spread = 20.0
		motes.initial_velocity_min = 12.0
		motes.initial_velocity_max = 30.0
		motes.color = Color(0.7, 0.95, 1.0, 0.6)
	else:
		# Heavy amber glints drifting sideways — metal, not crystal.
		motes.direction = Vector2(1.0, 0.0)
		motes.spread = 12.0
		motes.initial_velocity_min = 6.0
		motes.initial_velocity_max = 16.0
		motes.color = Color(1.0, 0.8, 0.35, 0.55)
	add_child(motes)

## The drop-in mouth dressing on the surface line: a crystal collar (DIAMONDS)
## or a riveted steel hatch (GOLD), plus a bobbing downward chevron that says
## "drop here" without any text. All decor, no collision.
func _build_mouth_frame(diamonds: bool, half: float) -> void:
	# Prismatic/brass threshold lip across the full mouth width.
	var lip := ColorRect.new()
	lip.size = Vector2(mouth_width, 8.0)
	lip.position = Vector2(-half, -8.0)
	lip.color = Color(0.6, 1.0, 0.95, 0.55) if diamonds else Color(0.9, 0.7, 0.3, 0.9)
	add_child(lip)

	if diamonds:
		# Inward-pointing crystal facets around the rim — a cut-gem mouth.
		for sign_x: float in [-1.0, 1.0]:
			var facet := Polygon2D.new()
			facet.polygon = PackedVector2Array([
				Vector2(sign_x * half, -8), Vector2(sign_x * (half - 22), -8), Vector2(sign_x * half, 14)])
			facet.color = Color(0.45, 0.95, 1.0, 0.85)
			add_child(facet)
			var chip := Polygon2D.new()
			chip.polygon = PackedVector2Array([
				Vector2(sign_x * (half - 6), -8), Vector2(sign_x * (half - 18), -8), Vector2(sign_x * (half - 6), 6)])
			chip.color = Color(0.75, 0.55, 1.0, 0.7)
			add_child(chip)
	else:
		# Two parted steel hatch leaves with rivets — a bank vault door thrown open.
		for sign_x: float in [-1.0, 1.0]:
			var leaf := ColorRect.new()
			leaf.size = Vector2(18.0, 14.0)
			leaf.position = Vector2(sign_x * half - (9.0 if sign_x > 0 else -9.0) - 9.0, -14.0)
			leaf.color = Color(0.45, 0.42, 0.38, 1.0)
			add_child(leaf)
			for r in range(2):
				var rivet := ColorRect.new()
				rivet.size = Vector2(4.0, 4.0)
				rivet.position = leaf.position + Vector2(3.0 + r * 8.0, 4.0)
				rivet.color = Color(0.85, 0.65, 0.25, 1.0)
				add_child(rivet)

	# Beckon chevron above the lip — protocol-tinted, slow bob. Points DOWN.
	var chevron := Polygon2D.new()
	chevron.polygon = PackedVector2Array([Vector2(-10, -30), Vector2(10, -30), Vector2(0, -18)])
	chevron.color = Color(0.6, 1.0, 0.95, 0.85) if diamonds else Color(1.0, 0.8, 0.35, 0.9)
	add_child(chevron)
	var bob := chevron.create_tween().set_loops()
	bob.tween_property(chevron, "position:y", 4.0, 0.8).set_trans(Tween.TRANS_SINE)
	bob.tween_property(chevron, "position:y", 0.0, 0.8).set_trans(Tween.TRANS_SINE)
