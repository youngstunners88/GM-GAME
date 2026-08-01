<!-- dispatched: anthropic/claude-fable-5
     prompt: prompts/fable-lead-stomp-taxcollector.md
     files inlined: 4
     tokens: 23374 in / 11229 out
     cost: $0.7952
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
# Task A — Stomp attack

**Approach.** The stomp check belongs in `_on_hurtbox_body_entered` in `player.gd` — it's the one callback that already receives every enemy-body contact and already has the pattern of special-casing before falling through to the normal damage path (pickaxe/boulder). No `EnemyBase` change is needed: `take_damage(1)` already exists on every enemy and its default `health = 1` means weak enemies die instantly, while tougher enemies take one honest hit — I chose `take_damage(1)` over an instant-kill so the existing flash/score/die pipeline and multi-HP enemies keep working. Detection: it's a stomp only if the player is **moving downward** (`velocity.y` — with `_last_fall_speed` as a fallback, since `move_and_slide` can zero `velocity.y` on the same frame the area signal fires) **and** the player's center is clearly above the enemy's center (`global_position.y < body.global_position.y - 8.0`). Side/below contact fails one of those and falls through to the existing `deal_damage` path unchanged. Bosses are excluded (group `"boss"`) so the Auditor's VULNERABLE-window design isn't bypassed. The bounce also refreshes double-jump/air-dash so chains feel good, and it cleanly ends an in-progress Big Mode ground pound (otherwise `velocity.y = ground_pound_speed` would stomp the bounce on the same frame).

New exports (place near the other `@export`s at the top of `player.gd`):

```gdscript
# src/player/player.gd — new exports
## Mario-style stomp: upward kick applied after bouncing off an enemy's head.
@export var stomp_bounce_force: float = -300.0
## Minimum downward speed for contact to count as a stomp — filters out
## brushing an enemy at the apex of a jump.
@export var stomp_min_fall_speed: float = 40.0
```

Changed callback + new helper:

```gdscript
# src/player/player.gd — replaces _on_hurtbox_body_entered, adds _try_stomp

func _on_hurtbox_body_entered(body: Node2D) -> void:
	# Pickaxe shatters boulders instead of them hurting us.
	if GameManager.has_power_up("pickaxe") and body.has_method("smash"):
		body.smash()
		return
	if body.is_in_group("enemy"):
		# Defect #10: landing on a head is a stomp — damage THEM, bounce US.
		if _try_stomp(body):
			return
		if body.has_method("deal_damage"):
			body.deal_damage(self)
	elif body.is_in_group("hazard"):
		take_damage(1)

## True (and fully handled) if this enemy contact is a head-stomp: player
## falling, player center clearly above enemy center. Side/below contact
## returns false and stays a normal player-takes-damage hit.
## velocity.y OR _last_fall_speed: move_and_slide can zero velocity.y on the
## exact frame the Area2D signal arrives, but _last_fall_speed still holds
## the pre-landing value (it only resets once is_on_floor() is true).
func _try_stomp(body: Node2D) -> bool:
	if body.is_in_group("boss"):
		return false  # bosses keep their VULNERABLE-window contract
	if not body.has_method("take_damage"):
		return false
	if body.get("is_dead") == true:
		return false  # don't re-stomp a corpse mid-death-tween
	var falling: bool = velocity.y > stomp_min_fall_speed \
			or _last_fall_speed > stomp_min_fall_speed
	if not falling:
		return false
	if global_position.y >= body.global_position.y - 8.0:
		return false
	body.take_damage(1)
	_ground_pounding = false  # pound resolves as a stomp, don't fight the bounce
	velocity.y = stomp_bounce_force
	input_handler.can_double_jump = true
	input_handler.can_air_dash = true
	_play_jump_stretch()
	AudioManager.play_sfx("jump")
	return true
```

One file touched. The player takes no damage on a successful stomp because we `return` before the `deal_damage` branch — and note `body_entered` fires once per overlap, so there's no second callback to worry about; the bounce separates the shapes anyway.

---

# Task B — Auditor: chase + attack simultaneously

**Approach.** Replace the snapshot-based `CHARGE` with a live-tracking `PURSUE` state, and insert an `ALERT` telegraph between `PATROL` and `PURSUE` (same fairness contract as `tax_collector.gd`: frozen beat, facing the player, audible tell). During PURSUE the boss re-reads the live player every frame, steers toward them, jumps when the player is above or a wall blocks (gated on `max_jump_gap`, derived from its own kinematics per the house style), **and keeps throwing clipboards on the existing per-phase cadence while moving** — `_throw_clipboard()` already aims at the live player, so it works mid-chase unmodified. PURSUE runs on a timer, then the boss "overextends" into the existing `VULNERABLE` window — so the damage loop, `take_damage`'s return-to-PATROL, `_update_phase`, and all token-spectacle hooks are untouched. Phase speed scaling is inherited for free by deriving `speed_scale = patrol_speed / _base_patrol_speed` (which `_update_phase` already maintains), so `_update_phase` needs zero edits. I also enable the hitbox during PURSUE so the chase actually threatens on contact — safe, because `take_damage` is already guarded to only apply damage in `VULNERABLE`, so player projectiles hitting the hitbox mid-chase are no-ops.

**Declarations** (top of file — remove `charge_speed`, `charge_target`, and the `CHARGE` enum entry; add these):

```gdscript
# src/boss/auditor.gd — enum + new exports/vars

enum State { PATROL, ALERT, PURSUE, VULNERABLE, DEFEATED }

@export var pursue_speed: float = 170.0
@export var pursue_duration: float = 4.0
## Fairness contract telegraph (see tax_collector.gd ALERT): frozen beat
## before the chase begins. Deliberately generous.
@export var alert_time: float = 0.6
@export var jump_force: float = -430.0
## Derived from kinematics, not eyeballed (house style, see tax_collector.gd):
## jump_force=-430 / 980 gravity -> ~0.88s airtime; at base pursue_speed 170
## that's ~149px horizontal. 110 leaves margin for raised ledges (shorter
## horizontal reach for the same launch) at phase-1 speed.
@export var max_jump_gap: float = 110.0
var _jump_cooldown: float = 0.0
```

(Delete `@export var charge_speed: float = 320.0` and `var charge_target: Vector2 = Vector2.ZERO` — nothing else in the file references them once the match block below is in.)

**Changed match block** in `_physics_process` (the `State.PATROL` and `State.CHARGE` arms are replaced; `State.VULNERABLE` is unchanged and shown only as an anchor):

```gdscript
# src/boss/auditor.gd — inside _physics_process(delta), the match statement

	match current_state:
		State.PATROL:
			velocity.x = patrol_speed * patrol_direction
			velocity.y += 980.0 * delta
			move_and_slide()
			if is_on_wall():
				patrol_direction *= -1.0
				sprite.scale.x = 1.0 if patrol_direction > 0 else -1.0
			# Ranged pressure — cadence tightens per phase.
			if throw_timer <= 0.0:
				throw_timer = [0.0, 2.6, 2.0, 1.4][phase]
				_throw_clipboard()
			# Occasional reposition hop.
			if hop_timer <= 0.0:
				hop_timer = 6.0 if phase < 3 else 3.5
				velocity.y = -320.0
				velocity.x = -patrol_direction * 160.0
			if state_timer <= 0.0:
				# Telegraph BEFORE the chase — freeze, face the player, tell.
				state_timer = alert_time
				current_state = State.ALERT
				velocity.x = 0.0
				var p := get_tree().get_first_node_in_group("player")
				if p:
					sprite.scale.x = 1.0 if p.global_position.x > global_position.x else -1.0
				sprite.color = Color(0.85, 0.5, 0.15, 1.0)  # amber wind-up
				AudioManager.play_sfx_at("tax_alert", global_position)

		State.ALERT:
			velocity.x = 0.0
			velocity.y += 980.0 * delta
			move_and_slide()
			if state_timer <= 0.0:
				state_timer = pursue_duration
				current_state = State.PURSUE
				sprite.color = Color(0.55, 0.3, 0.12, 1.0)
				# Contact hurts during the chase; take_damage() is guarded to
				# VULNERABLE, so stray projectiles hitting this are no-ops.
				hitbox.set_deferred("monitorable", true)
				hitbox.set_deferred("monitoring", true)

		State.PURSUE:
			_jump_cooldown -= delta
			var p := get_tree().get_first_node_in_group("player")
			if p == null:
				current_state = State.PATROL
				state_timer = 1.4
				sprite.color = Color(0.4, 0.25, 0.15, 1.0)
				hitbox.set_deferred("monitorable", false)
				hitbox.set_deferred("monitoring", false)
				return
			# LIVE tracking — re-read the player every frame, no snapshot.
			# Phase speed scaling comes for free: _update_phase already scales
			# patrol_speed off _base_patrol_speed, so reuse that ratio.
			var speed_scale := patrol_speed / _base_patrol_speed
			var dx := p.global_position.x - global_position.x
			var toward := signf(dx)
			velocity.x = toward * pursue_speed * speed_scale
			sprite.scale.x = 1.0 if toward > 0.0 else -1.0
			# Jump when the player is above or a wall blocks the chase — gated
			# on max_jump_gap so he never commits to a leap he can't land.
			var dy := p.global_position.y - global_position.y
			if is_on_floor() and _jump_cooldown <= 0.0:
				var wants_up := dy < -48.0
				var blocked := is_on_wall()
				if (wants_up or blocked) and absf(dx) <= max_jump_gap:
					velocity.y = jump_force
					_jump_cooldown = 0.9
			# Attack WHILE chasing — same per-phase cadence, slightly tighter.
			if throw_timer <= 0.0:
				throw_timer = [0.0, 2.2, 1.7, 1.2][phase]
				_throw_clipboard()
			velocity.y += 980.0 * delta
			move_and_slide()
			# Overextended — the readable damage window, unchanged from before.
			if state_timer <= 0.0:
				state_timer = vulnerable_time
				current_state = State.VULNERABLE
				sprite.color = Color(1.0, 0.2, 0.2, 1.0)
				hitbox.set_deferred("monitorable", true)
				hitbox.set_deferred("monitoring", true)

		State.VULNERABLE:
			# ... unchanged ...
```

`take_damage()`, `_update_phase()`, `die()`, and all shard/gold/smoke hooks stay byte-identical — `take_damage`'s exit already sets `State.PATROL` + a breather `state_timer`, which now leads into the next ALERT→PURSUE cycle naturally.

**Re: the "useless obstacle that blocks chase":** not found in the provided file. `auditor.gd` contains no arena geometry — the only spawned bodies are the token-gated gold platforms (`_spawn_gold_platforms`, holders-only, phase 3) which are safe zones, not blockers. The obstacle is almost certainly a `StaticBody2D`/TileMap wall in the boss arena scene. I need the arena `.tscn` (whichever level scene instantiates this boss) to name it. Note that with the jump logic above, a mid-arena wall no longer hard-stops the chase anyway — but if it exists it should still be removed per the founder, once I can see the scene.