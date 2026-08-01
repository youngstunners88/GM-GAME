# Fable-5 — implement the Auditor chase punish-window tune

You are the lead implementer this session (rate-limit mode: primary Claude
Code is conserving budget). Produce the EXACT GDScript edit needed — full
replacement text for the affected function(s), not a description.

## Context

`src/boss/auditor.gd`'s ALERT state already telegraphs the chase (0.6s
freeze + face player + SFX) before PURSUE begins. But when PURSUE starts,
the boss moves at FULL `pursue_speed` (scaled by phase) AND the Hitbox
becomes damage-live on the exact same frame — so "he's now chasing" and
"he can now hit you" are simultaneous, with zero grace. A founder feel
review found this reads as an instant, unfair punish right after a fight
starts. Grok 4.5 gave concrete numbers after reading the real code:

1. **Speed ramp:** PURSUE starts at 55% of the target speed and linearly
   reaches 100% over 0.7 seconds of PURSUE time. Top speed and per-phase
   scaling are UNCHANGED — only how fast it reaches that speed changes.
2. **Hitbox grace:** keep the Hitbox non-monitoring for the first 0.35
   seconds of PURSUE, then enable it exactly as today.

## Constraints (do not violate)

- Do NOT change `pursue_speed`, `max_jump_gap`, `jump_force`,
  `pursue_duration`, `alert_time`, or any phase-scaling math.
- Do NOT change live-tracking (must keep re-reading the player's position
  every physics frame, never a snapshot).
- Jump logic and `_throw_clipboard()` cadence during PURSUE must still fire
  normally during the ramp/grace window — do not gate them on the new ramp
  or grace timers.
- The ramp must be driven by actual elapsed PURSUE time (e.g. track a
  `_pursue_elapsed` accumulator reset when PURSUE state is entered), not a
  frame count, so it's frame-rate independent.
- The 0.35s hitbox grace must not change WHEN `hitbox.monitorable/
  monitoring` get set to `true` in the ALERT→PURSUE transition block
  itself if that would break existing structure — instead, delay the
  actual enable by 0.35s using the same elapsed-PURSUE-time accumulator
  (i.e. it's fine to still flip a "we are now in PURSUE" flag immediately,
  but the physical `hitbox.set_deferred("monitorable"/"monitoring", true)`
  calls should not happen until 0.35s of PURSUE has elapsed).
- State transition OUT of PURSUE (into VULNERABLE) via `state_timer <= 0.0`
  is unchanged.

## Files

Below is the exact current content of the relevant states in
`src/boss/auditor.gd`. Give back the full corrected `State.ALERT` and
`State.PURSUE` blocks (and any new member variable declarations needed),
ready to paste in directly, with a one-line comment explaining the tune
(referencing this being a founder feel-review fairness tune, not a
redesign).

```gdscript
	State.ALERT:
		velocity.x = 0.0
		velocity.y += 980.0 * delta
		move_and_slide()
		if state_timer <= 0.0:
			state_timer = pursue_duration
			current_state = State.PURSUE
			sprite.color = Color(0.55, 0.3, 0.12, 1.0)
			# Contact hurts during the chase; take_damage() stays gated to
			# VULNERABLE, so a stray projectile hitting this is a no-op.
			hitbox.set_deferred("monitorable", true)
			hitbox.set_deferred("monitoring", true)

	State.PURSUE:
		_jump_cooldown -= delta
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
```

Note: `max_jump_gap` is compared against `absf(dx)` (a pure position gap,
not dependent on current velocity), so the speed ramp should NOT affect
jump-gap gating correctness — confirm this in your answer, don't just
assume it.

Give back only the corrected GDScript blocks plus new variable
declarations, with a short explanation of exactly what changed and why the
jump-gap gating is unaffected.
