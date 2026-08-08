<!-- dispatched: anthropic/claude-fable-5
     prompt: prompts/fable-chase-tune-implement.md
     files inlined: 0
     tokens: 2438 in / 2490 out
     cost: $0.1489
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
## New member variable declarations

Add near the other member vars (e.g. next to `_jump_cooldown`):

```gdscript
# Founder feel-review fairness tune: PURSUE speed ramps 55%→100% over 0.7s
# and the contact hitbox stays inert for the first 0.35s — not a redesign.
var _pursue_elapsed: float = 0.0
var _pursue_hitbox_live: bool = false
```

## Replacement `State.ALERT` block

```gdscript
	State.ALERT:
		velocity.x = 0.0
		velocity.y += 980.0 * delta
		move_and_slide()
		if state_timer <= 0.0:
			state_timer = pursue_duration
			current_state = State.PURSUE
			sprite.color = Color(0.55, 0.3, 0.12, 1.0)
			# Founder feel-review fairness tune: the hitbox no longer goes
			# live on the same frame the chase starts. Reset the PURSUE
			# clock; the actual set_deferred enables happen in PURSUE after
			# 0.35s of elapsed PURSUE time. take_damage() gating unchanged.
			_pursue_elapsed = 0.0
			_pursue_hitbox_live = false
```

## Replacement `State.PURSUE` block

```gdscript
	State.PURSUE:
		_jump_cooldown -= delta
		# Elapsed-PURSUE-time accumulator: frame-rate independent driver
		# for both the speed ramp and the hitbox grace window.
		_pursue_elapsed += delta
		# Hitbox grace: contact damage arms 0.35s into the chase, exactly
		# as it used to arm at chase start (same deferred calls, delayed).
		if not _pursue_hitbox_live and _pursue_elapsed >= 0.35:
			_pursue_hitbox_live = true
			hitbox.set_deferred("monitorable", true)
			hitbox.set_deferred("monitoring", true)
		# Cast immediately: get_first_node_in_group() is typed `Node`, so
		# `p.global_position` is a Variant and `var x := <Variant>` is a
		# HARD PARSE ERROR in Godot 4.3 (it does not warn — it refuses to
		# load the whole script). See distributor.gd's _apply_pull() for
		# the same documented trap; missed once already in this session's
		# first draft.
		var p := get_tree().get_first_node_in_group("player") as CharacterBody2D
		if p == null:
			current_state = State.PATROL
			state_timer = 1.4
			sprite.color = Color(0.4, 0.25, 0.15, 1.0)
			hitbox.set_deferred("monitorable", false)
			hitbox.set_deferred("monitoring", false)
			return
		# LIVE tracking — re-read the player every frame, never a snapshot.
		# Phase speed scaling comes for free: _update_phase already scales
		# patrol_speed off _base_patrol_speed, so reuse that ratio.
		var speed_scale := patrol_speed / _base_patrol_speed
		# Speed ramp: 55% → 100% of target speed over the first 0.7s of
		# PURSUE. Top speed and phase scaling are untouched — only the
		# approach to that speed changes.
		var ramp := lerpf(0.55, 1.0, clampf(_pursue_elapsed / 0.7, 0.0, 1.0))
		var dx := p.global_position.x - global_position.x
		var toward := signf(dx)
		velocity.x = toward * pursue_speed * speed_scale * ramp
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
```

## What changed and why

1. **Speed ramp:** `_pursue_elapsed` accumulates real `delta` each physics frame of PURSUE (reset in the ALERT→PURSUE transition), and `ramp` linearly interpolates 0.55→1.0 over 0.7s via `lerpf`/`clampf`. It multiplies only the final `velocity.x` — `pursue_speed`, `speed_scale`, and all phase math are byte-identical.
2. **Hitbox grace:** the two `set_deferred` enable calls were moved out of the ALERT transition into a one-shot check (`_pursue_hitbox_live` guard) that fires once `_pursue_elapsed >= 0.35`. The player-null bail-out path still disables the hitbox and the VULNERABLE transition still enables it, both unchanged — and both remain correct even if PURSUE ends before 0.35s elapses.
3. **Not gated:** jump logic, `_throw_clipboard()` cadence, live player tracking, and the `state_timer <= 0.0` exit to VULNERABLE are all outside the ramp/grace conditionals and run every frame as before.

**Jump-gap gating is unaffected — confirmed, not assumed:** the gate is `absf(dx) <= max_jump_gap`, where `dx = p.global_position.x - global_position.x`, computed fresh from positions that frame. `velocity.x` (the only thing the ramp touches) never feeds into `dx`, `dy`, `wants_up`, or `blocked`. The ramp only means the boss *reaches* a given gap slightly later in wall-clock time; the decision at any given gap is identical.