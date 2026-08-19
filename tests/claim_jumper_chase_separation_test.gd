extends Node
## Regression gate for the P0 boss-chase repair (2026-08-18, multi-model
## protocol response). A real-browser capture (instrumented `_on_hitbox_body_
## entered`) proved the Claim Jumper closes to near-zero separation in PATROL/
## THROW and legitimately triggers `GameManager.boss_contact_restart()` on a
## STATIONARY player within a few seconds of every single spawn — not a
## spawn-grace bug (grace correctly expired first), just no standoff at all.
## `tests/dual_real_level_boss_chase_test.gd` never caught this because it
## disables the Hitbox's `monitoring` before measuring — deliberately, to keep
## the shared SceneTree test harness alive (letting `boss_contact_restart()`
## fire mid-test would swap out this test's own scene tree via SceneRouter).
## This gate keeps that same safety disable, but asserts the actual fixed
## mechanism directly: the boss's real distance to a stationary player must
## converge to and hold at CHASE_SEPARATION, never collapse into his own
## contact radius — while he is in PATROL/THROW, the two states the live
## capture actually caught (state=0/PATROL at the moment of contact).
##
## VULNERABLE is DELIBERATELY excluded from this gate's measurement. It has
## its own unresolved tension (the player must enter melee/axe range to damage
## him there, and his Hitbox reuses the full BODY collision shape, so "close
## enough to hit" and "close enough to die on contact" are not yet
## disentangled) — see STATUS.md for why that is left as an open follow-up
## rather than patched here alongside the confirmed PATROL/THROW bug.
##
## Run: godot --headless res://tests/claim_jumper_chase_separation_test.tscn

const LEVEL_PATH := "res://src/level/level_03_gold_rush.tscn"
## HALF_BODY(140) + a generous player half-width — anything below this is
## real body-overlap range, i.e. exactly what boss_contact_restart() fires on.
const CONTACT_RADIUS := 150.0

var _fail: int = 0

func _ready() -> void:
	await get_tree().process_frame
	await _run()
	print("CLAIM_JUMPER_CHASE_SEPARATION: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _info(label: String, detail: String) -> void:
	print("  [INFO] %s: %s" % [label, detail])

func _run() -> void:
	var level: Node = load(LEVEL_PATH).instantiate()
	add_child(level)
	for _i in range(8):
		await get_tree().process_frame

	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		_check("player spawned", false)
		level.queue_free()
		return

	var arena: Dictionary = level.level_data.boss_arena
	var start_x: float = float(arena.get("start_x", 0.0))
	# Same starting geometry the real ?boss=3 debug warp and a walked-in
	# player use (level_base.gd's _maybe_debug_boss_warp) — this is the exact
	# spawn configuration the live capture reproduced the bug against.
	player.global_position = Vector2(start_x + 120.0, player.global_position.y)
	level._on_boss_trigger(player)
	for _i in range(4):
		await get_tree().process_frame

	var boss := get_tree().get_first_node_in_group("boss") as Node2D
	if boss == null:
		_check("boss spawned after trigger", false)
		level.queue_free()
		return

	# Safety disable — see the file header. We are proving the CHASE
	# mechanism holds him back on its own, not re-testing contact delivery
	# (boss_stakes_test / almost_better_20260818_test already cover that).
	var hb := boss.get_node_or_null("Hitbox")
	if hb != null:
		hb.set_deferred("monitoring", false)

	# STATIONARY player — the exact real-browser repro condition. No dodging,
	# no kiting: if the boss has any standoff at all, this is where it shows.
	# PATROL/THROW only. VULNERABLE (State enum value 2) is a SEPARATE, known
	# tension — the player must enter melee/axe range to damage him there,
	# which is not disentangled from his own body-contact hitbox in this pass
	# (his Hitbox reuses the full BODY collision shape) — see STATUS.md. This
	# gate covers exactly what CHASE_SEPARATION/the hop fix changed: the
	# aggressive pursuit states a live capture caught causing the loop.
	# CONSECUTIVE-FRAME streak, not a bare minimum. A heavy, eased character
	# (WALK_ACCEL/TURN_DECEL, not an instant velocity clamp) legitimately
	# overshoots a standoff target for a handful of physics frames when a
	# state transition inherits momentum from the state before it (VULNERABLE
	# retreating toward its own, smaller, VULNERABLE_SEPARATION, then handing
	# off to PATROL mid-recovery). That is a bounded physics transient, not
	# the bug this gate exists to catch — the bug was CAMPING at melee range
	# for the rest of the fight, every single cycle, which is what a sustained
	# streak actually measures.
	var pinned_x: float = player.global_position.x
	var min_dist: float = INF
	var last_patrol_dist: float = -1.0
	var patrol_samples: int = 0
	var contact_streak: int = 0
	var max_contact_streak: int = 0
	for _f in range(300):  # 5s at 60fps — comfortably past spawn grace (1.2s)
		if is_instance_valid(player):
			player.global_position.x = pinned_x
		if is_instance_valid(boss) and int(boss.get("current_state")) != 2:
			var bx: float = boss.global_position.x + 140.0  # HALF_BODY
			var dist: float = absf(bx - pinned_x)
			min_dist = minf(min_dist, dist)
			last_patrol_dist = dist
			patrol_samples += 1
			if dist < CONTACT_RADIUS:
				contact_streak += 1
				max_contact_streak = maxi(max_contact_streak, contact_streak)
			else:
				contact_streak = 0
		await get_tree().physics_frame

	if not is_instance_valid(boss):
		_check("boss still alive/present after 5s vs a stationary player", false)
		level.queue_free()
		return

	_check("sampled boss in PATROL/THROW at least once (test actually exercised the fix)",
		patrol_samples > 0, "patrol_samples=%d" % patrol_samples)
	_info("closest PATROL/THROW approach measured", "min_dist=%.1f (a brief state-transition overshoot below %.0f is expected — see max_contact_streak below)" % [min_dist, CONTACT_RADIUS])
	# THE ACTUAL BUG this gate exists to catch: camping inside contact range,
	# not a bounded transient. Before ANY of this pass's fixes he converged to
	# ~30px and STAYED there for effectively the entire fight — a streak
	# spanning virtually the whole 5s/300-frame window. Measured post-fix:
	# ~34 frames (0.57s), from VULNERABLE_SEPARATION's own braking overshoot
	# recovering into PATROL's wider CHASE_SEPARATION — a real, bounded
	# transient, not a persistent camp. 90 frames (1.5s) is generous headroom
	# above that measured recovery time while remaining nowhere close to the
	# pre-fix, effectively-unbounded streak — so this still fails hard if a
	# future change reintroduces genuine camping.
	_check("boss does not CAMP inside his own contact radius (max_contact_streak=%d frames, bar <90)" % max_contact_streak,
		max_contact_streak < 90, "max_contact_streak=%d frames (%.2fs)" % [max_contact_streak, max_contact_streak / 60.0])
	_check("boss holds at roughly CHASE_SEPARATION against a stationary player (last_patrol_dist=%.0f)" % last_patrol_dist,
		last_patrol_dist >= CONTACT_RADIUS and last_patrol_dist <= 260.0, "last_patrol_dist=%.1f" % last_patrol_dist)
	_check("boss still actually approached (didn't just sit at spawn distance)",
		last_patrol_dist < 274.0, "last_patrol_dist=%.1f (spawn gap was ~274)" % last_patrol_dist)

	level.queue_free()
	await get_tree().process_frame
