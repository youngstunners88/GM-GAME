<!-- dispatched: anthropic/claude-fable-5
     prompt: prompts/fable-vo-bark-wiring.md
     files inlined: 0
     tokens: 2836 in / 5383 out
     cost: $0.2975
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
## 1. `play_bark()` — paste into `src/autoload/audio_manager.gd`

```gdscript
## Dedicated player for Lil Blunt's character barks. Deliberately a
## SEPARATE node from _voice_player: barks must never cut off announcer
## lines, and announcer lines must never be blocked by barks. One single
## slot (newest bark replaces the old one) because barks are reactions —
## the newest is the relevant one — and replacing also prevents player
## nodes accumulating over a long session.
var _bark_player: AudioStreamPlayer = null

## Last-fired timestamp (msec) per bark id. Cooldowns are tracked per-id
## so a rapid hurt bark can't starve an attack bark, and vice versa.
var _bark_last_played: Dictionary = {}


## Plays a short character bark. Unlike play_voice(), this never touches
## current_music_player (no duck tween — a hurt-spam duck/restore storm
## would be worse than the bark itself) and never touches _voice_player.
## Calls inside the per-id cooldown are silently dropped: the cooldown IS
## the spam absorber for fan-axe / continuous-flame hit cadence.
## Missing or unloadable files are a silent no-op because VO assets may
## not exist in every build and gameplay must never depend on them.
func play_bark(name: String, cooldown: float) -> void:
	var now := Time.get_ticks_msec()
	if _bark_last_played.has(name):
		var last: int = _bark_last_played[name]
		if now - last < int(cooldown * 1000.0):
			return
	var path := _resolve_audio("res://src/assets/sounds/voice/" + name)
	if path == "":
		return
	var stream := load(path)
	if not stream:
		return
	# Stamp only after a successful load, so a build missing this file
	# doesn't burn the cooldown for nothing.
	_bark_last_played[name] = now
	if _bark_player and is_instance_valid(_bark_player):
		_bark_player.queue_free()
	_bark_player = AudioStreamPlayer.new()
	_bark_player.bus = "SFX"
	_bark_player.stream = stream
	add_child(_bark_player)
	_bark_player.play()
	# Self-cleanup so finished barks don't leak nodes across a session.
	_bark_player.finished.connect(_bark_player.queue_free)
```

## 2. Call sites

### A — `src/player/player.gd`

```gdscript
	else:
		_hitstop()
		sprite.play_animation("hurt")
		velocity.y = -260.0
		velocity.x = -240.0 if input_handler.facing_right else 240.0
		power_up_handler.activate_invincibility(1.0)
		AudioManager.play_sfx("damage")
		AudioManager.play_bark("vo_hurt", 4.0)
```

In `die()`, immediately after both guards (so a refused state change never barks):

```gdscript
func die() -> void:
	if StateMachine.is_dead():
		return
	if not StateMachine.change_state(StateMachine.State.DEAD):  # (guard as it exists in file)
		return
	AudioManager.play_bark("vo_death", 5.0)
	# ...rest of die() unchanged
```

I don't have the full body of `die()` — I've placed the line relative to the two guards described in the ticket. If the `change_state` argument differs, keep the existing guard line untouched.

### B — the three attack hit paths (identical edit shape in each)

`src/combat/axe.gd` and `src/combat/flame_projectile.gd` (`_hit`), `src/combat/fire_breath.gd` (`_burn_node`):

```gdscript
func _hit(node: Node) -> bool:
	if node and node.is_in_group("enemy") and node.has_method("take_damage"):
		node.take_damage(damage)
		AudioManager.play_bark("vo_attack", 8.0)
	return true
```

(For `fire_breath.gd` the function is `_burn_node`, same body shape.) All three deliberately share the id `vo_attack` so the single per-id cooldown absorbs fan-axe multi-hits and continuous flame ticks collectively.

### C — `src/autoload/game_manager.gd`

```gdscript
func activate_power_up(type: String, duration: float) -> void:
	# ...existing body...
	# Bark only on a real acquisition. The empty-type / zero-duration
	# path is the power-up CLEAR (power_up_changed.emit("", 0.0)) and
	# must stay silent.
	if type != "" and duration > 0.0:
		AudioManager.play_bark("vo_collect_major", 10.0)
	power_up_changed.emit(type, duration)
```

**Caveat:** I don't have the full `activate_power_up()` body or the list of valid `type` strings. If coins/rings ever route through this function (they shouldn't — the ticket implies they don't), gate with an explicit whitelist of major power-up ids instead of `type != ""`. Tell me the type strings and I'll write the whitelist.

### D — `src/boss/auditor.gd`, in `die()`

```gdscript
	GameManager.add_score(500)
	ScreenShake.shake(0.4, 8.0)  # (existing call, args as in file)
	AudioManager.play_voice("victory")
	# Delay the hype bark so it lands AFTER the announcer's victory line
	# instead of talking over it. SceneTreeTimer is owned by the tree and
	# the lambda only touches the AudioManager autoload, so this still
	# fires even if the boss node frees itself before the timer elapses.
	get_tree().create_timer(1.6).timeout.connect(
		func() -> void: AudioManager.play_bark("vo_boss_hype", 60.0)
	)
```

If the recorded `victory` announcer line is longer than ~1.6 s, bump the delay to its actual length — tell me the clip duration and I'll set it exactly.

## 3. Cooldown values

| Bark | Cooldown | Justification |
|---|---|---|
| `vo_hurt` | 4.0 s | Invincibility gates hits to ≥1 s apart; 4 s means roughly every 3rd–4th hit barks instead of every one. |
| `vo_death` | 5.0 s | Deaths are already gated by respawn flow; this is a safety net against die()/pit_death firing in the same sequence. |
| `vo_attack` | 8.0 s | The main spam risk: fan axes land several hits per input and fire_breath ticks multiple times/sec — 8 s turns "per hit" into occasional flavor. |
| `vo_collect_major` | 10.0 s | Power-ups can be placed in clusters; prevents back-to-back pickup barks while still firing on distinct pickups. |
| `vo_boss_hype` | 60.0 s | Bosses are rare; a full minute guarantees no repeat even in a fast multi-boss chain. |

## 4. Explicit answers

**Pit death:** Yes, bark `vo_death`, placed immediately after `AudioManager.play_sfx("fall")` in `pit_death()` — a life is lost either way, and the "fall" SFX is environmental, not the character's voice, so they complement rather than duplicate. The 5 s per-id cooldown covers the respawn-then-real-`die()` edge case. **One condition:** if the recorded `vo_death` line's content is final-death specific ("I'm done for good"-type read), skip pit death instead — check the actual recording before shipping.

**Power-up clear/expiry:** Covered. The clear path emits `power_up_changed.emit("", 0.0)` from *outside* `activate_power_up()`, and our bark is gated inside `activate_power_up()` on `type != "" and duration > 0.0`, so a clear can never bark. The `auditor.gd` SMOKE path is also safe: it *listens* to `power_up_changed` and writes `GameManager.power_up_timer` directly — it never calls `activate_power_up()`, and writing the timer field cannot trigger the bark.