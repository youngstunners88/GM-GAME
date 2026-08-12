extends Area2D
## Climbable ladder (task #23, Movie Layer). Area2D detection per Godot 4.3
## best practice: overlapping the zone lets the player enter the CLIMB state
## (up/down movement, no gravity), jump off mid-climb, or slide off the ends.
## Placement intent (LEVEL_DEPTH.md): escape routes out of high-death pockets,
## sourced from the player_analytics heatmap.

@export var height: float = 128.0
## Where the player stands after topping out, RELATIVE to the ladder origin
## (which is the ladder's top). Data-driven per instance so offset platforms
## work without hardcoding player coordinates (brief correction E). Default:
## just above the ladder top, centered. Set y more negative if the platform
## surface sits higher than the ladder top.
@export var top_exit_offset: Vector2 = Vector2(0, -20)

## Whether the big axe can shear this ladder off. TRUE for the world ladders
## the mechanic was built for. Set FALSE for a ladder that is the ONLY way out
## of a sealed pocket — e.g. the protocol vaults (Diamond Vault / Fort Knox):
## Kimi K3 audit found that a destroyed vault ladder is an unrecoverable
## soft-lock, because the vault floor guards the kill band, so the trapped
## player cannot even die to reset. A destructible ladder is only safe where a
## fall-out or an alternate route exists; a vault has neither.
@export var destructible: bool = true

## Optional identity tint applied to the whole rung group (white = the default
## Smoke-Realm green). The protocol vaults set this so the exit ladder reads as
## crystal (Diamond Vault) or brass (Fort Knox) rather than jungle vine.
@export var rung_color: Color = Color(1, 1, 1, 1)

@onready var shape: CollisionShape2D = $CollisionShape2D
@onready var rungs: Node2D = $Rungs

func _ready() -> void:
	add_to_group("ladder")
	# Layer 8 (Destructible), NOT 0. A layer of 0 makes a node undetectable by
	# anything, so the big axe's ladder-smash could never fire no matter what
	# the axe code said — the founder's "the ladder breaks" was unreachable.
	# The player's own ladder detection is driven by this Area2D's MASK
	# (player layer 2) and is unaffected by the layer change.
	collision_layer = 128
	collision_mask = 2  # player layer
	# 44px, not the visual rungs' 24px: a forgiving grab zone. At normal fall/
	# jump horizontal speed a 28px zone crosses in well under 150ms — reliably
	# missable on approach even when the player is holding UP the whole time,
	# which reads as "the ladder is a ghost object" even though detection
	# itself was never broken. Wider hitbox than sprite is a standard
	# platformer forgiveness trick, not a visible mismatch at this margin.
	var rect := RectangleShape2D.new()
	rect.size = Vector2(44, height)
	shape.shape = rect
	shape.position = Vector2(0, height / 2.0)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_draw_rungs()
	rungs.modulate = rung_color
	# Only wire the big-axe shear on ladders that can safely lose it. A vault's
	# sole exit ladder stays indestructible (see `destructible`'s note).
	if destructible:
		_setup_destructible()

# ---- Structural damage (big axe) -------------------------------------------

## Typed as Node2D and loaded BY PATH, not via the `Destructible` class_name.
## A brand-new class_name is not in Godot's global class cache until the editor
## re-imports, so a headless compile gate fails with "Could not find type" even
## though the script is perfectly valid. The rest of this project already uses
## load-by-path for exactly this reason (see main_menu.gd's how_to_play_panel).
var _destructible: Node2D

## Takes 3 big-axe hits to shear off, showing cracks and missing chunks in
## between. Previously the first hit faded the whole ladder out instantly,
## which is precisely the "mustn't break completely as in disappear" the
## founder ruled out.
func _setup_destructible() -> void:
	_destructible = load("res://src/level/destructible.gd").new()
	_destructible.configure(Vector2(28.0, height), 3)
	_destructible.position = Vector2(-14.0, 0.0)
	_destructible.wrecked.connect(_on_wrecked)
	add_child(_destructible)

func take_structural_damage(amount: int = 1) -> bool:
	if _destructible == null:
		return false
	return _destructible.take_structural_damage(amount)

## SOFT-LOCK GUARD — the part most likely to ship a game-breaking bug.
##
## The player enters CLIMB while inside this Area2D and leaves it via
## exit_ladder_zone(), which ladder.gd normally fires from `body_exited`.
## queue_free() does NOT reliably emit body_exited, so a player who is
## mid-climb when the ladder collapses would keep `_climbing = true` with
## gravity disabled and no ladder to climb — frozen in mid-air, unrecoverable
## without a death. So every overlapping player is explicitly released FIRST,
## and only then is the node freed.
func _on_wrecked() -> void:
	for body in get_overlapping_bodies():
		if body.is_in_group("player") and body.has_method("exit_ladder_zone"):
			body.exit_ladder_zone(self)
	# Stop detecting immediately so nothing can re-enter during the fade.
	set_deferred("monitoring", false)
	AudioManager.play_sfx_at("hit", global_position)
	var t := create_tween()
	t.tween_property(self, "rotation", deg_to_rad(18.0), 0.35)
	t.parallel().tween_property(self, "modulate:a", 0.0, 0.35)
	t.finished.connect(queue_free)

## World Y of the ladder top (origin) and bottom, for the climb/top-out logic.
func top_y() -> float:
	return global_position.y

func bottom_y() -> float:
	return global_position.y + height

## Collision-valid standing position when topping out. Never a raw teleport
## into geometry: the player does a short move_and_collide nudge from here.
func top_exit_position() -> Vector2:
	return global_position + top_exit_offset

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("enter_ladder_zone"):
		body.enter_ladder_zone(self)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("exit_ladder_zone"):
		body.exit_ladder_zone(self)

## Procedural rungs (vine-wrapped pole look, Smoke Realm palette) — keeps the
## ladder readable without a dedicated sprite sheet yet.
func _draw_rungs() -> void:
	var rail_l := ColorRect.new()
	rail_l.size = Vector2(4, height)
	rail_l.position = Vector2(-12, 0)
	rail_l.color = Color(0.35, 0.5, 0.32, 0.95)
	rungs.add_child(rail_l)
	var rail_r := rail_l.duplicate()
	rail_r.position = Vector2(8, 0)
	rungs.add_child(rail_r)
	var count: int = int(height / 20.0)
	for i in range(count):
		var rung := ColorRect.new()
		rung.size = Vector2(24, 3)
		rung.position = Vector2(-12, 8 + i * 20.0)
		rung.color = Color(0.55, 0.68, 0.45, 0.95)
		rungs.add_child(rung)
