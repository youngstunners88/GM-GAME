<!-- dispatched: anthropic/claude-fable-5
     prompt: prompts/fable-chase-and-arrows.md
     files inlined: 3
     tokens: 26110 in / 17148 out
     cost: $1.1185
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
## 1. Root cause: Stage 2 boss "not moving"

Three defects compound; the third makes the first two visible.

**(a) Origin-seeking, not centre-seeking.** `_hover_pursue` computes `to = target - global_position`, i.e. the **origin** seeks `player + (0, -300)`. Since centre = origin + (120,120), the boss's centre equilibrium is `player.x + 120` — he always parks 120px **east** of the player.

**(b) Clamp geometry.** Level clamps the **origin** to `[3790, 4310]`, so the reachable **centre** range is `[3910, 4430]`. Player standing anywhere west of x≈3790 puts the pursuit target below the clamp minimum: origin pins at 3790, centre at 3910 — up to ~210px away from a player hugging the west wall at 3700.

**(c) Velocity not zeroed at the clamp.** While pinned, `move_toward` keeps velocity saturated at up to `HOVER_MAX * scale` **into** the wall; the clamp snaps position back every frame but never kills the velocity. When the player moves east again, the boss must burn off up to ~330 px/s of westward velocity at HOVER_ACCEL 430 px/s² — ~0.8s of visibly frozen boss *after* the player has already left.

**Bonus (d):** the non-PATROL speed scales are all sub-player: 0.62·330 = 204.6, 0.55·330 = 181.5, 0.70·330 = 231 — all < 240, so a sprinting player outruns him for most of every cycle.

**Combination:** player stands in the western third → (b) pins the origin at 3790 → (c) keeps him glued there with saturated inward velocity → (a) makes even the pinned pose read as "hovering away from me." He bobs in place and only attacks: "still not moving / not chasing."

## 2. `distributor.gd` patch (tabs, typed)

Add next to `HOVER_MAX`:

```gdscript
## Floor under every pursuing state. Player top speed is 240 px/s
## (walk 200 * sprint 1.2); the per-state scales dropped pursuit to
## 181–231 px/s, so holding the run key escaped him forever.
const HOVER_MIN_PURSUIT: float = 260.0
```

Replace `_hover_pursue`:

```gdscript
func _hover_pursue(delta: float, speed_scale: float = 1.0) -> void:
	var p := get_tree().get_first_node_in_group("player") as CharacterBody2D
	if p != null:
		# Seek with the body CENTRE over the player, not the origin: origin-
		# seeking parked the centre 120px east of the player and, combined
		# with the level's origin clamp, pinned him off the west wall. The
		# origin target is therefore player - (BODY/2, HOVER_ABOVE), which
		# puts the centre directly above the player at the tuned clearance.
		var origin_target: Vector2 = p.global_position + Vector2(-BODY / 2.0, -HOVER_ABOVE)
		var to: Vector2 = origin_target - global_position
		var speed: float = maxf(HOVER_MAX * speed_scale, HOVER_MIN_PURSUIT)
		velocity = velocity.move_toward(to.normalized() * speed, HOVER_ACCEL * delta)
		boss_sprite.set_facing(to.x > 0.0)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, HOVER_ACCEL * delta)
	# NO gravity term anywhere in this script any more.
	move_and_slide()
	_clamp_to_arena()
```

Replace `_clamp_to_arena`:

```gdscript
## Last line of defence against "he fell in the trench and disappeared" — and
## it now ZEROES the velocity component pushing into the wall. Previously the
## clamp snapped position while move_toward kept velocity saturated inward, so
## a boss pinned at the boundary stayed pinned for ~0.8s after the player
## moved back into reach (velocity had to reverse through 0 at HOVER_ACCEL).
func _clamp_to_arena() -> void:
	if arena_max == Vector2.ZERO:
		return
	if global_position.x < arena_min.x:
		global_position.x = arena_min.x
		velocity.x = maxf(velocity.x, 0.0)
	elif global_position.x > arena_max.x:
		global_position.x = arena_max.x
		velocity.x = minf(velocity.x, 0.0)
	if global_position.y < arena_min.y:
		global_position.y = arena_min.y
		velocity.y = maxf(velocity.y, 0.0)
	elif global_position.y > arena_max.y:
		global_position.y = arena_max.y
		velocity.y = minf(velocity.y, 0.0)
```

**Not fixable in this file:** the level's clamp `[start_x+90, end_x-90]` was tuned for an 80px body. For BODY=240 it (a) still forbids the centre from reaching the west 210px of the arena and (b) lets the body overhang `end_x` by 150px on the east. The level file wasn't provided; it should clamp the origin to `[start_x, end_x - BODY]` = `[3700, 4160]`. Say the word and I'll patch it when the file is shared.

## 3. `claim_jumper.gd` patch

Export change:

```gdscript
## Above the player's 240 px/s sprint in EVERY phase — 165 was outrun by a
## walking player, never mind a sprinting one.
@export var patrol_speed: float = 265.0
```

Replace `_on_phase_changed`:

```gdscript
## Accelerate patrol + taunt on phase transition (BossBase calls this).
func _on_phase_changed() -> void:
	if current_phase >= 2:
		patrol_speed = 300.0
		BossVoiceSystem.say(self, BOSS_ID, "phase50", true)
	if current_phase >= 3:
		patrol_speed = 340.0
		BossVoiceSystem.say(self, BOSS_ID, "phase25", true)
		ScreenShake.medium()
```

Replace `_physics_process` (PATROL logic unchanged except the gap-hop launch cap; THROW now closes; VULNERABLE untouched):

```gdscript
func _physics_process(delta: float) -> void:
	if is_dead:
		return

	throw_timer -= delta
	_hop_cooldown -= delta

	match current_state:
		State.PATROL:
			var pl := get_tree().get_first_node_in_group("player")
			if pl:
				var dx: float = pl.global_position.x - global_position.x
				if absf(dx) > TURN_DEAD_ZONE:
					direction = signf(dx)
			var target_vx: float = patrol_speed * direction
			var rate: float = (TURN_DECEL
				if signf(target_vx) != signf(velocity.x) and not is_zero_approx(velocity.x)
				else WALK_ACCEL)
			velocity.x = move_toward(velocity.x, target_vx, rate * delta)
			var at_ledge := false
			if is_on_floor() and not is_zero_approx(target_vx):
				at_ledge = _ledge_ahead(signf(target_vx))
				if at_ledge:
					velocity.x = 0.0
			velocity.y += 980.0 * delta
			move_and_slide()
			_clamp_to_arena()
			if absf(velocity.x) > 12.0:
				boss_sprite.set_facing(velocity.x > 0.0)
			if is_on_floor() and _hop_cooldown <= 0.0:
				var want_hop := is_on_wall() or (at_ledge and _gap_crossable(direction))
				if pl and pl.global_position.y < global_position.y - 80.0:
					want_hop = true
				if want_hop:
					if at_ledge:
						# HOP_REACH / _gap_crossable were derived from ≤240
						# px/s of air travel. At the raised chase speeds a gap
						# hop would overshoot the probed landing, so cap the
						# LAUNCH speed for gap hops only — walls and vertical
						# hops keep full momentum.
						velocity.x = clampf(velocity.x, -240.0, 240.0)
					velocity.y = HOP_VELOCITY
					_hop_cooldown = 0.7
			if throw_timer <= 0:
				_throw_dynamite()

		State.THROW:
			# Keep CLOSING while throwing instead of braking to a dead stop —
			# a boss that parks to attack hands the player a free reposition
			# every cycle. Reduced but still near sprint speed, with the same
			# ledge sense so the chase never becomes a walk-off.
			var pl_t := get_tree().get_first_node_in_group("player")
			if pl_t:
				var dx_t: float = pl_t.global_position.x - global_position.x
				if absf(dx_t) > TURN_DEAD_ZONE:
					direction = signf(dx_t)
			var throw_vx: float = maxf(patrol_speed * 0.85, 250.0) * direction
			velocity.x = move_toward(velocity.x, throw_vx, WALK_ACCEL * delta)
			if is_on_floor() and not is_zero_approx(throw_vx) and _ledge_ahead(signf(throw_vx)):
				velocity.x = 0.0
			velocity.y += 980.0 * delta
			move_and_slide()
			_clamp_to_arena()
			if absf(velocity.x) > 12.0:
				boss_sprite.set_facing(velocity.x > 0.0)

		State.VULNERABLE:
			velocity.x = move_toward(velocity.x, 0.0, 150.0 * delta * 60.0)
			velocity.y += 980.0 * delta
			move_and_slide()
			_clamp_to_arena()
			boss_sprite.modulate = Color(1.0, 0.3, 0.3, 1.0) if fmod(throw_timer, 0.2) < 0.1 else Color(1.0, 0.1, 0.1, 1.0)
```

**Note:** nothing in the provided file ever sets `current_state = State.THROW` or `State.VULNERABLE` — if those transitions live in `BossBase` (not provided), the THROW patch is live; if not, THROW is dead code and the fight is PATROL-only. Please share `boss_base.gd` so I can confirm.

## 4. Arrow projectile + bow

**New file: `src/enemies/gnome_arrow.gd`** (complete):

```gdscript
extends Area2D
class_name GnomeArrow
## Tax Collector arrow — self-drawn shaft + steel head + fletching, ~26x8 px,
## rotated to its travel direction. Replaces the reuse of boss_projectile.tscn
## whose CIRCLE read as a boss orb, not archery (founder: "arrows must LOOK
## like arrows"). Deliberately NOT in the "projectile" group: that group is
## what boss hitboxes treat as PLAYER attacks (_on_hitbox_area_entered), so an
## arrow in it would damage bosses.

@export var speed: float = 330.0
@export var lifetime: float = 3.0
var direction: Vector2 = Vector2.RIGHT

var _age: float = 0.0

func _ready() -> void:
	rotation = direction.angle()
	collision_layer = 0
	# Bit 1 = world geometry (the mask every raycast in this codebase uses).
	# Bit 2 assumed for the player body — the player's collision LAYER is not
	# in the files provided; verify against the player scene and adjust.
	collision_mask = 0b11
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(26.0, 8.0)
	shape.shape = rect
	add_child(shape)
	body_entered.connect(_on_body_entered)
	queue_redraw()

func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	global_position += direction * speed * delta

func _draw() -> void:
	# Local space points +X; node rotation supplies the travel direction.
	var wood := Color(0.55, 0.38, 0.20, 1.0)
	var steel := Color(0.82, 0.84, 0.88, 1.0)
	var feather := Color(0.85, 0.72, 0.45, 1.0)
	# Shaft.
	draw_line(Vector2(-13.0, 0.0), Vector2(7.0, 0.0), wood, 2.5)
	# Triangular head.
	draw_colored_polygon(PackedVector2Array([
		Vector2(13.0, 0.0), Vector2(6.0, -4.0), Vector2(6.0, 4.0)]), steel)
	# Fletching, two feathers at the tail.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-13.0, -4.0), Vector2(-7.0, -1.0), Vector2(-13.0, -1.0)]), feather)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-13.0, 4.0), Vector2(-7.0, 1.0), Vector2(-13.0, 1.0)]), feather)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			GameManager.last_damage_source = "tax"
			body.take_damage(1)
		queue_free()
	elif not body.is_in_group("enemy"):
		# World geometry — the arrow breaks.
		queue_free()
```

**`tax_collector.gd` changes.** Replace the `ARROW` const and `_fire_arrow`:

```gdscript
const ARROW := preload("res://src/enemies/gnome_arrow.gd")

## Loose one arrow at the player's current position.
func _fire_arrow() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_arrow_cd = arrow_cooldown
	var to: Vector2 = (_player.global_position - global_position).normalized()
	var arrow: GnomeArrow = ARROW.new()
	arrow.direction = to
	arrow.speed = arrow_speed
	get_parent().add_child(arrow)
	# Offset out of his own body so the arrow never spawns inside him.
	arrow.global_position = global_position + Vector2(16.0, 12.0) + to * 22.0
	AudioManager.play_sfx_at("throw", global_position)
```

Add the drawn bow (new `_draw`), and one line at the very end of `_physics_process` — after `move_and_slide()` — so the aim tracks:

```gdscript
	queue_redraw()
```

```gdscript
## Drawn bow, held out toward the player, so the shot reads as archery.
## Local coords: body is 32x32 with the origin at the TOP-LEFT, centre +16,+16.
func _draw() -> void:
	if is_dead or state == State.PATROL:
		return
	if _player == null or not is_instance_valid(_player):
		return
	var aim: Vector2 = (_player.global_position - global_position).normalized()
	var hand: Vector2 = Vector2(16.0, 12.0) + aim * 14.0
	var ang: float = aim.angle()
	# Bow limb: an arc opening toward the player.
	draw_arc(hand, 10.0, ang - 1.15, ang + 1.15, 12, Color(0.45, 0.28, 0.12), 2.0)
	# String between the limb tips.
	var tip_a: Vector2 = hand + Vector2(10.0, 0.0).rotated(ang - 1.15)
	var tip_b: Vector2 = hand + Vector2(10.0, 0.0).rotated(ang + 1.15)
	draw_line(tip_a, tip_b, Color(0.9, 0.9, 0.85, 1.0), 1.0)
	# Nocked arrow appears as the cooldown runs out — a per-shot tell.
	if _arrow_cd < 0.35:
		draw_line(hand - aim * 6.0, hand + aim * 10.0, Color(0.55, 0.38, 0.2, 1.0), 2.0)
```

## 5. Explicit risk callouts

1. **Level arena bounds (missing file):** both levels clamp the origin with ±90 margins. For the Distributor (BODY 240) that both hides the arena's west 210px from his centre AND lets his body overhang `end_x` by 150px. Needs `[start_x, end_x - BODY]` in the level file — not provided, can't patch here.
2. **`BossBase` not provided:** Claim Jumper's THROW/VULNERABLE transitions don't exist in the shown file. My THROW patch is correct but possibly inert.
3. **`EnemyBase` not provided:** if it already implements `_draw()`, my override in `tax_collector.gd` replaces it. Also, `tax_collector.gd` as pasted is indented with **spaces** while the bosses use tabs — GDScript hard-errors on mixed indentation, so match whatever that file actually uses when merging my tab-indented snippets.
4. **Arrow collision mask bit 2 is an assumption** — the player's collision layer isn't in any provided file. Verify against the player scene or the arrow will only die on walls.
5. **HOARD_GRAVITY now pursues at ≥260 px/s while pulling** — the pull + faster closing may over-tighten the tug-of-war; if playtests show unavoidable contact, lower `HOVER_MIN_PURSUIT` to 245 rather than re-scaling states.
6. **Old orb-arrows had `tint`/`homing`/`redirectable`** — `GnomeArrow` intentionally has none of these; nothing else in the provided files reads them off gnome arrows, but any test asserting on `boss_projectile` counts from gnomes will change.
7. **Gap-hop launch cap (240)** preserves the `HOP_REACH`/`_gap_crossable` envelope at the new speeds; wall hops and player-above hops keep full momentum, so mid-air overshoot at 340 px/s is only prevented for the ledge case — matching the ledge-safety guarantee you asked me to keep.