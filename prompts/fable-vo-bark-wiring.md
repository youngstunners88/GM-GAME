# Fable-5 — implement Lil Blunt's action-VO bark system (LEAD)

You are the lead implementer (rate-limit mode: primary Claude Code is
conserving budget). Produce EXACT GDScript — full function bodies ready to
paste, not descriptions.

## Goal

Five short character barks in Lil Blunt's own voice fire on pronounced
actions. Files ALREADY EXIST at `res://src/assets/sounds/voice/<id>.mp3`
for: `vo_hurt`, `vo_death`, `vo_attack`, `vo_collect_major`, `vo_boss_hype`.

## Critical constraint — do NOT reuse `AudioManager.play_voice()`

`play_voice()` is SINGLE-SLOT and music-ducking:
```gdscript
func play_voice(name: String) -> void:
	var path := _resolve_audio("res://src/assets/sounds/voice/" + name)
	if path == "": return
	var stream := load(path)
	if not stream: return
	if _voice_player and is_instance_valid(_voice_player):
		_voice_player.queue_free()          # <-- kills any playing line
	_voice_player = AudioStreamPlayer.new()
	_voice_player.bus = "SFX"
	_voice_player.stream = stream
	add_child(_voice_player)
	if current_music_player and is_instance_valid(current_music_player):
		var duck := current_music_player.create_tween()
		duck.tween_property(current_music_player, "volume_db", -8.0, 0.25)
	_voice_player.play()
	_voice_player.finished.connect(_on_voice_finished)
```
It is used for ANNOUNCER lines (`stage1_intro`, `boss1_intro`, `victory`).
If barks reused it: a bark during a stage/boss intro would CUT OFF that
line, and every single hurt would fire a music duck/restore tween pair.
Both are unacceptable.

**Write a NEW separate `play_bark()` path** in `src/autoload/audio_manager.gd`
with its own player(s), NO music ducking, and its own cooldown map.

## Requirements for `play_bark(name: String, cooldown: float) -> void`

1. Per-bark-id cooldown, tracked with `Time.get_ticks_msec()`. A call
   inside the cooldown is silently dropped. Cooldowns must be per-id
   (a hurt bark must not block an attack bark).
2. Never interrupts `play_voice()`'s announcer player, and never touches
   `current_music_player` volume.
3. Silent, safe no-op if the file is missing or fails to load (the game
   must never break because a VO file is absent — files may not exist in
   some builds).
4. Reuse the project's existing `_resolve_audio(base)` helper for path
   resolution (it handles `.mp3`/`.ogg` fallback). It returns `""` when
   nothing is found.
5. Bus `"SFX"`, same as the existing voice player.
6. Clean up finished bark players so they don't accumulate as leaked
   nodes across a long session.
7. **Barks must not stack into mush**: if a bark is already playing, a NEW
   different bark should take over (barks are reactions — the newest is
   the relevant one), but this must NOT touch the announcer player. Decide
   and implement: one dedicated bark player that gets replaced, which
   satisfies both "newest wins" and "no accumulation".

## Call sites (verified against the real code — use exactly these)

**A. `vo_hurt` and `vo_death` — `src/player/player.gd`**, current code:
```gdscript
func take_damage(amount: int) -> void:
	if not StateMachine.is_playing() or power_up_handler.invincible_timer > 0:
		return
	GameManager.take_damage(amount)
	ComboSystem.break_combo()
	ScreenShake.shake(0.2, 5.0)
	if GameManager.player_health <= 0:
		die()
	else:
		_hitstop()
		sprite.play_animation("hurt")
		velocity.y = -260.0
		velocity.x = -240.0 if input_handler.facing_right else 240.0
		power_up_handler.activate_invincibility(1.0)
		AudioManager.play_sfx("damage")
```
The fatal and survivable branches are mutually exclusive, so `vo_hurt` in
the `else` branch can never double-fire with `vo_death`. Put `vo_death` in
`func die()` (which begins `if StateMachine.is_dead(): return` then
`if not StateMachine.change_state(...): return` — place the bark AFTER
those guards so a refused death doesn't bark).

Also `func pit_death()` exists (falling in a pit — costs a life, plays
`AudioManager.play_sfx("fall")`, may respawn OR game-over). Recommend
whether pit death should bark `vo_death` too, and if so exactly where —
note it already plays a distinct "fall" SFX and may not end the run.

**B. `vo_attack` — three separate hit paths.** All three are
"projectile/flame connected with an enemy":
- `src/combat/axe.gd` → `func _hit(node: Node) -> bool:` body is
  `if node and node.is_in_group("enemy") and node.has_method("take_damage"): node.take_damage(damage)` then returns true
- `src/combat/flame_projectile.gd` → `func _hit(node: Node) -> bool:` same shape
- `src/combat/fire_breath.gd` → `func _burn_node(node: Node) -> bool:` same shape

**SPAM WARNING — this is the main design risk.** The purple power-up
throws a FAN of several axes from one input (each can connect separately),
and `fire_breath` burns CONTINUOUSLY over its lifetime, potentially hitting
multiple enemies many times per second. A naive bark per hit would be
unlistenable. The per-id cooldown in `play_bark` is what must absorb this
— pick a concrete cooldown value and justify it.

**C. `vo_collect_major` — `src/autoload/game_manager.gd`:**
```gdscript
func activate_power_up(type: String, duration: float) -> void:
	...
	power_up_changed.emit(type, duration)
```
Must fire ONLY for major power-ups, never coins/rings. Note this same
function is also used to CLEAR power-ups (there is a
`power_up_changed.emit("", 0.0)` elsewhere) — make sure an expiry/clear
can't bark. Also note `auditor.gd` connects to `power_up_changed` and
directly writes `GameManager.power_up_timer` for SMOKE holders — confirm
your approach can't bark from that path.

**D. `vo_boss_hype` — rare.** Boss defeat is the cleanest single trigger.
In `src/boss/auditor.gd`, `func die()` runs `GameManager.add_score(500)`,
`ScreenShake.shake(...)`, `AudioManager.play_voice("victory")` etc. Give
the exact placement, and pick a long cooldown so a multi-boss session
can't spam it. Note `play_voice("victory")` (announcer) already fires
there — make sure the bark and that line don't talk over each other badly;
recommend a small delay or a different placement if needed.

## Deliverables

1. Full `play_bark()` implementation + any new member vars, ready to paste
   into `audio_manager.gd`, with doc comments in the project's existing
   style (the codebase comments explain WHY, not just what).
2. The exact edited snippet for each call site (A–D), showing enough
   surrounding context to place it unambiguously.
3. Your chosen cooldown value per bark id, each with a one-line
   justification tied to the actual firing cadence described above.
4. Explicitly answer the pit-death question and the
   power-up-clear/expiry question.

GDScript 4.3. Note: `get_first_node_in_group()` returns untyped `Node` —
`var x := <Variant>` is a HARD PARSE ERROR in Godot 4.3, so cast
explicitly if you use it.
