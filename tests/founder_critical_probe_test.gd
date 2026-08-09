extends Node
## Founder-critical regression probe — closes the exact gaps the founder
## rejected prior "FIXED" claims over: Blaze Rush exit/finish proven ONLY for
## a Level-2 entry context (see docs/session-logs/2026-08-08b), and full-wipe
## restart proven ONLY on Level 2. This drives the REAL handlers
## (blaze_rush.gd::_exit_to_level, Player._respawn_or_game_over via
## pit_death) through the REAL SceneRouter for L1 and L3 too, plus a
## genuinely NEW geometric check the prior clamp-only probe never covered:
## does the Distributor's levitating disc actually render under the boss's
## real global transform, not just "exist as a child."
##
## Run: godot --headless res://tests/founder_critical_probe_test.tscn

const LEVEL_SCENES := {
	1: "res://src/level/level_01_smoke_realm.tscn",
	2: "res://src/level/level_02_crystal_caverns.tscn",
	3: "res://src/level/level_03_gold_rush.tscn",
}
const BLAZE_RUSH := preload("res://src/dashmode/blaze_rush.tscn")
const DISTRIBUTOR := preload("res://src/boss/distributor.tscn")
const AUDITOR := preload("res://src/boss/auditor.tscn")

var _failures: int = 0

func _ready() -> void:
	# The engine's root is still finishing initial tree construction on the
	# very first _ready() callback of a run — calling add_child() on
	# get_tree().root synchronously here fails with "Parent node is busy
	# setting up children" (confirmed by a real run). One frame of headroom
	# before anything touches the root node sidesteps it for every test.
	await get_tree().process_frame
	await _run()

func _check(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("  [PASS] %s" % label)
	else:
		_failures += 1
		print("  [FAIL] %s %s" % [label, detail])

func _info(label: String, value: Variant) -> void:
	print("  [INFO] %s = %s" % [label, str(value)])

func _run() -> void:
	for lvl in [1, 2, 3]:
		await _test_blaze_exit_returns_to_entry_level(lvl)
	for lvl in [1, 3]:
		await _test_full_wipe_restarts_current_level(lvl)
	_test_distributor_disc_renders_under_boss_body()
	await _test_distributor_hits_player_on_contact()
	await _test_auditor_hits_player_on_contact()
	await _test_skateboard_zone_hover_and_steer()
	await _test_boss_backdrop_floor_alignment(2)
	await _test_lounge_pickups_never_overlap()
	await _test_blaze_backdrops_differ_per_realm()
	await _test_founder_art_drop_ins_actually_render()
	await _test_campaign_stage_tokens_use_the_right_protocol_mark()
	await _test_blaze_band_includes_robinhood_after_goldmine_move()
	await _test_blaze_music_is_the_founders_track()

	if _failures == 0:
		print("FOUNDER_CRITICAL_PROBE: ALL PASS")
		get_tree().quit(0)
	else:
		print("FOUNDER_CRITICAL_PROBE: %d FAILURE(S)" % _failures)
		get_tree().quit(1)

## SceneRouter._finalise_load() does `get_tree().current_scene.queue_free()`
## on whatever is current before swapping in the new scene. When this test
## runs directly (`godot --headless res://tests/X.tscn`), THIS TEST NODE
## starts out as current_scene — triggering a real SceneRouter.load_scene()
## without redirecting current_scene first would free the test itself
## mid-run. Hand current_scene to a disposable decoy so the free lands
## there instead. Re-armed before every SceneRouter-triggering action.
func _arm_decoy_current_scene() -> void:
	var decoy := Node.new()
	# MUST be a direct child of the tree ROOT, not of this test node — Godot
	# asserts `current_scene`'s parent == root (scene_tree.cpp) and silently
	# refuses the assignment otherwise, which then makes SceneRouter's later
	# `get_tree().current_scene.queue_free()` free THIS TEST NODE itself
	# (still current_scene) instead of the decoy — killing every pending
	# coroutine in this script with no error, which looks exactly like a
	# hang. Confirmed by a real run: "ERROR: Condition p_scene->get_parent()
	# != root" followed by silence forever.
	#
	# call_deferred + a frame of wait, not a direct add_child(): the root can
	# still be "busy setting up children" depending on exactly when this is
	# called (also confirmed by a real run: "Parent node is busy setting up
	# children, add_child() failed") — a direct call silently no-ops and
	# reproduces the exact same hang one line later.
	get_tree().root.add_child.call_deferred(decoy)
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().current_scene = decoy

# ---------------------------------------------------------------------------
# Blaze Rush exit — the SAME function finish and ESC both call, for all three
# entry contexts (only L2 was previously proven end-to-end).
# ---------------------------------------------------------------------------

func _test_blaze_exit_returns_to_entry_level(level_index: int) -> void:
	print("Blaze Rush exit — L%d entry context:" % level_index)
	var scene_path: String = LEVEL_SCENES[level_index]
	# Distinguishable from every level's real start marker / checkpoints so a
	# false pass (falling back to level start) cannot be mistaken for success.
	var entry_pos := Vector2(1234.5, 321.5)
	GameManager.dash_return = {
		"scene_path": scene_path,
		"position": entry_pos,
		"level_index": level_index,
	}
	GameManager.level_checkpoints.erase(level_index)

	await _arm_decoy_current_scene()
	var run: Node = BLAZE_RUSH.instantiate()
	add_child(run)
	await get_tree().process_frame
	await get_tree().process_frame

	# The exact function both _finish_run() (win) and the ui_cancel branch of
	# _unhandled_input() (ESC) call — proving this once proves both, since
	# they cannot drift apart (single shared code path).
	run.call("_exit_to_level")

	_check("L%d: dash_return cleared synchronously by _exit_to_level" % level_index,
		GameManager.dash_return.is_empty())
	_check("L%d: checkpoint written under the CORRECT level key (not hardcoded)" % level_index,
		level_index in GameManager.level_checkpoints,
		"checkpoint keys present: %s" % str(GameManager.level_checkpoints.keys()))
	if level_index in GameManager.level_checkpoints:
		var cp: Vector2 = GameManager.level_checkpoints[level_index].pos
		_check("L%d: checkpoint position matches the portal entry position" % level_index,
			cp.distance_to(entry_pos) < 1.0,
			"checkpoint at %s, expected %s" % [str(cp), str(entry_pos)])

	# Deeper check: let the REAL async scene load finish and confirm the
	# resulting scene is genuinely the entry level, with the player placed at
	# the entry checkpoint — not silently still on Blaze Rush, not the menu.
	var loaded := false
	for i in range(360):  # ~6s at 60Hz — SMOKE transition + real resource load
		await get_tree().physics_frame
		if SceneRouter.get("_loading_path") == "" and is_instance_valid(get_tree().current_scene) \
				and get_tree().current_scene.scene_file_path == scene_path:
			loaded = true
			break
	_check("L%d: SceneRouter actually loaded the entry scene" % level_index, loaded,
		"current_scene ended at %s, expected %s" % [
			get_tree().current_scene.scene_file_path if is_instance_valid(get_tree().current_scene) else "<freed>",
			scene_path])
	if loaded:
		var player := get_tree().get_first_node_in_group("player")
		_check("L%d: player spawned in the reloaded level" % level_index, player != null)
		if player:
			var dist: float = player.global_position.distance_to(entry_pos + Vector2(0, -50))
			_check("L%d: player positioned at the entry marker (not level start)" % level_index,
				dist < 40.0,
				"player at %s, expected near %s" % [str(player.global_position), str(entry_pos + Vector2(0, -50))])
		# Clean up the loaded level before the next iteration reuses the tree.
		get_tree().current_scene.queue_free()
		await get_tree().process_frame

	if is_instance_valid(run):
		run.queue_free()
	GameManager.dash_return = {}
	GameManager.level_checkpoints.erase(level_index)
	await get_tree().process_frame

# ---------------------------------------------------------------------------
# Full life wipe — must restart the CURRENT level from its start marker.
# Previously proven only on L2; founder reports L1 specifically diverges.
# ---------------------------------------------------------------------------

func _test_full_wipe_restarts_current_level(level_index: int) -> void:
	print("Full-wipe restart — Level %d:" % level_index)
	var scene_path: String = LEVEL_SCENES[level_index]

	GameManager.level_checkpoints.erase(level_index)
	GameManager.lives = 3
	GameManager.max_lives = 3
	GameManager.player_health = GameManager.max_health

	await _arm_decoy_current_scene()
	var packed: PackedScene = load(scene_path)
	var level: Node = packed.instantiate()
	add_child(level)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	_check("L%d: level records itself as GameManager.current_level on entry" % level_index,
		GameManager.current_level == level_index,
		"current_level=%d" % GameManager.current_level)

	var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
	_check("L%d: player spawned" % level_index, player != null)
	if player == null:
		level.queue_free()
		await get_tree().process_frame
		return

	var start_pos: Vector2 = player.global_position
	_info("L%d player start position" % level_index, start_pos)
	# Diagnostics up front: if pit_death's own guard (is_dead() or _dying)
	# bails silently, lives never move and NO SceneRouter log line ever
	# appears — indistinguishable from several other causes unless these are
	# printed at the exact moment pit_death is invoked.
	_info("L%d StateMachine state before pit_death" % level_index, StateMachine.get_current_state())
	_info("L%d player._dying before pit_death" % level_index, player.get("_dying"))
	_info("L%d players currently in group 'player'" % level_index,
		get_tree().get_nodes_in_group("player").size())

	# Put a MID-LEVEL checkpoint down, far from the start marker, so a wipe
	# that wrongly resumed there (instead of the true level start) would be
	# unmistakable — this is exactly the founder's reported symptom shape.
	var mid_checkpoint: Vector2 = start_pos + Vector2(600.0, 0.0)
	GameManager.save_checkpoint(level_index, 500 + level_index, mid_checkpoint)

	# Drain to the LAST life, then trigger the real hard-fail path (pit_death,
	# the same call every level's kill zone makes) for the killing loss.
	GameManager.lives = 1
	GameManager.player_health = GameManager.max_health
	player.call("pit_death")
	_info("L%d GameManager.lives immediately after pit_death() call returns" % level_index, GameManager.lives)

	# pit_death -> _respawn_or_game_over() waits ~1.2s (tween + timer) before
	# the FADE transition even starts loading — budget generously.
	var loaded := false
	for i in range(420):  # ~7s at 60Hz
		await get_tree().physics_frame
		if SceneRouter.get("_loading_path") == "" and is_instance_valid(get_tree().current_scene) \
				and get_tree().current_scene != level \
				and get_tree().current_scene.scene_file_path == scene_path:
			loaded = true
			break
	_check("L%d: full wipe reloads the SAME level (not menu, not a different level)" % level_index,
		loaded,
		"current_scene ended at %s" % (
			get_tree().current_scene.scene_file_path if is_instance_valid(get_tree().current_scene) else "<freed>"))

	_check("L%d: lives refilled to max after the wipe" % level_index,
		GameManager.lives == GameManager.max_lives,
		"lives=%d, max_lives=%d" % [GameManager.lives, GameManager.max_lives])
	_check("L%d: the mid-level checkpoint was CLEARED by the wipe" % level_index,
		not (level_index in GameManager.level_checkpoints),
		"checkpoint still present: %s" % str(GameManager.level_checkpoints.get(level_index, {})))

	if loaded:
		var new_player := get_tree().get_first_node_in_group("player")
		if new_player:
			var dist_from_mid: float = new_player.global_position.distance_to(mid_checkpoint)
			var dist_from_start: float = new_player.global_position.distance_to(start_pos)
			_info("L%d respawn position" % level_index, new_player.global_position)
			_check("L%d: respawned at LEVEL START, not the mid-level checkpoint" % level_index,
				dist_from_start < 60.0 and dist_from_mid > 200.0,
				"landed %.0fpx from start, %.0fpx from the mid-level checkpoint it should have ignored"
					% [dist_from_start, dist_from_mid])
		if is_instance_valid(get_tree().current_scene):
			get_tree().current_scene.queue_free()
		await get_tree().process_frame

	# Free the PRE-wipe instance too — when `loaded` is true this is a
	# DIFFERENT object from current_scene (the post-wipe reload), and a
	# prior version of this probe only ever freed current_scene, leaking
	# `level` (and its player) as an orphan for the rest of the whole run.
	if is_instance_valid(level):
		level.queue_free()

	GameManager.level_checkpoints.erase(level_index)
	await get_tree().process_frame

# ---------------------------------------------------------------------------
# Distributor disc alignment (D1) — genuinely NEW: the prior R7/R8 probe only
# confirmed the boss stays within a Y-band, never that the disc's rendered
# footprint actually coincides with the boss's own collision/body centre.
# ---------------------------------------------------------------------------

func _test_distributor_disc_renders_under_boss_body() -> void:
	print("Distributor disc/body alignment:")
	var boss: Node2D = DISTRIBUTOR.instantiate()
	add_child(boss)
	boss.global_position = Vector2(500, 500)

	var collision: CollisionShape2D = boss.get_node("CollisionShape2D")
	var disc: Polygon2D = boss.get("_disc")
	_check("disc node exists", disc != null and is_instance_valid(disc))
	if disc == null or not is_instance_valid(disc):
		boss.queue_free()
		return

	# Body centre in WORLD space: the collision shape's local centre (48,48)
	# transformed through the boss's actual global transform (picks up
	# BOSS_SCALE=1.7 automatically — this is the point of using the real
	# transform instead of hand-multiplying the scale constant).
	var body_centre_world: Vector2 = boss.to_global(collision.position)
	# Disc centre in local (Polygon2D) space is the mean of its 4 vertices;
	# transform through the DISC's own global transform (it's a direct child,
	# so this also picks up the boss's scale via the transform chain).
	var poly: PackedVector2Array = disc.polygon
	var local_centre := Vector2.ZERO
	for v in poly:
		local_centre += v
	local_centre /= float(poly.size())
	var disc_centre_world: Vector2 = disc.to_global(local_centre)

	var offset: Vector2 = disc_centre_world - body_centre_world
	_info("body centre (world)", body_centre_world)
	_info("disc centre (world)", disc_centre_world)
	_info("horizontal offset (px)", offset.x)
	# The disc is DESIGNED to sit below the body (positive Y offset is
	# correct — that's "under his feet"), but it must NOT be offset
	# sideways, or the boss reads as standing BESIDE it, not on it.
	_check("disc is horizontally centred under the boss body (not beside it)",
		absf(offset.x) < 3.0,
		"disc is %.1fpx off-centre horizontally — this IS 'stands beside, not on' if nonzero" % offset.x)
	# The board is a FOOTPRINT: below the body centre, and no further down than
	# the body's own half-height (plus a little slack for the hover bob).
	#
	# Derived from the boss's real CollisionShape2D, not from a fixed 96px
	# scaled by boss.scale.y. That old form silently rotted: the comment
	# claimed it tracked the boss's size, but sizing is done by the BODY
	# constant, not by node scale — scale.y stays 1.0 — so growing the boss
	# from 96 to 176 to 240 moved the real offset while the ceiling never
	# budged, and the gate failed on a board that was correctly placed.
	var body_cs := boss.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var half_h: float = 48.0
	if body_cs and body_cs.shape is RectangleShape2D:
		half_h = (body_cs.shape as RectangleShape2D).size.y / 2.0
	_check("disc sits below the body (a real footprint, not floating away from it)",
		offset.y > 0.0 and offset.y < half_h * 1.15 * boss.scale.y,
		"vertical offset %.1fpx vs ceiling %.1fpx" % [offset.y, half_h * 1.15 * boss.scale.y])

	boss.queue_free()
	await get_tree().process_frame

# ---------------------------------------------------------------------------
# Bidirectional damage (D3-equivalent) — boss CONTACT hurting the player,
# under real physics. Orb-redirect (player hurting boss) is already covered
# by distributor_behaviour_test.gd; this covers the other direction, which
# was asserted from .tscn masks by hand but never driven under real physics.
# ---------------------------------------------------------------------------

func _test_distributor_hits_player_on_contact() -> void:
	print("Distributor -> player contact damage:")
	await _test_boss_hits_player_on_contact(DISTRIBUTOR, "distributor")

func _test_auditor_hits_player_on_contact() -> void:
	print("Auditor -> player contact damage:")
	await _test_boss_hits_player_on_contact(AUDITOR, "auditor")

func _test_boss_hits_player_on_contact(boss_scene: PackedScene, label: String) -> void:
	# Defensive reset: Player._hitstop() is fire-and-forget and awaits a real
	# 0.07s timer before restoring Engine.time_scale to 1.0. The PREVIOUS
	# call of this function frees its player right after detecting damage —
	# if that happens before the pending hitstop timer fires, the coroutine
	# resumes on a freed object and the restore never runs, leaving
	# time_scale stuck at 0.05 for every test that follows (confirmed by a
	# real run: the Auditor's own state_timer appeared frozen in PATROL for
	# 5 real seconds because it was only accumulating simulated time at 1/20
	# speed). Never trust ambient global state between tests — reset it.
	Engine.time_scale = 1.0
	# Player.take_damage() early-returns unless StateMachine.is_playing().
	# A bare probe scene never enters PLAYING, so EVERY contact-damage check
	# here was measuring the harness, not the game: the boss really did touch
	# the player, the player really did call take_damage(), and take_damage()
	# really did return on line 1 because the state machine said the game was
	# not running. Enter PLAYING (via TRANSITIONING — the state machine
	# rejects an arbitrary jump) so contact damage is actually reachable.
	StateMachine.change_state(StateMachine.State.TRANSITIONING)
	StateMachine.change_state(StateMachine.State.PLAYING)
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 1
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(2000, 80)
	cs.shape = rect
	floor_body.add_child(cs)
	floor_body.global_position = Vector2(0, 400)
	add_child(floor_body)

	var player: CharacterBody2D = preload("res://src/player/player.tscn").instantiate()
	add_child(player)
	player.global_position = Vector2(-200, 300)

	var boss: Node2D = boss_scene.instantiate()
	add_child(boss)
	boss.global_position = Vector2(0, 280)

	for i in 20:
		await get_tree().physics_frame

	var health_before: int = GameManager.player_health
	var hit := false
	# Distributor's hitbox monitors for the WHOLE fight (contact damage is
	# live from frame one) — a single walk-in registers immediately. The
	# Auditor's does NOT: it only arms ~2.95s in (PATROL's 2.0s state timer +
	# 0.6s ALERT telegraph + 0.35s PURSUE grace). Area2D's body_entered only
	# fires on a NEW overlap transition — pinning the player motionless
	# inside the hitbox before it arms means monitoring flips on with the
	# body ALREADY overlapping, and Godot never raises a fresh "entered"
	# event for that (confirmed by a real run: 5s of static contact, zero
	# damage). Cycle the player out and back in instead, so a genuine
	# enter-transition happens repeatedly across the whole window regardless
	# of exactly when monitoring goes live.
	# Seed a checkpoint so its ERASURE by boss_contact_restart() is observable.
	GameManager.save_checkpoint(GameManager.current_level, 777, Vector2(500, 500))
	for cycle in 10:  # 10 x 0.5s = 5s total, matching the old budget
		player.global_position = boss.to_global(_body_centre(boss)) + Vector2(-_exit_dist(boss), 0)
		for i in 10:
			await get_tree().physics_frame
		player.global_position = boss.to_global(_body_centre(boss))
		for i in 20:
			await get_tree().physics_frame
			# NEW CONTRACT (founder F2): contact triggers a level restart, not
			# damage. boss_contact_restart() erases this level's checkpoint and
			# asks SceneRouter to reload — either is proof contact registered.
			if GameManager.player_health < health_before \
					or GameManager.get("_boss_restart_pending") \
					or not (GameManager.current_level in GameManager.level_checkpoints):
				hit = true
				break
		if boss.has_method("get") and "current_state" in boss:
			var hb: Area2D = boss.get_node_or_null("Hitbox")
			_info("%s cycle %d" % [label, cycle],
				"state=%s monitoring=%s monitorable=%s boss_pos=%s player_pos=%s"
					% [str(boss.get("current_state")),
					   str(hb.monitoring if hb else "?"),
					   str(hb.monitorable if hb else "?"),
					   str(boss.global_position), str(player.global_position)])
		if hit:
			break
	_check("%s: touching the boss body sends the player back to level start" % label,
		hit, "no restart requested after 5s of repeated contact (health %d)" % GameManager.player_health)

	player.queue_free()
	boss.queue_free()
	floor_body.queue_free()
	await get_tree().process_frame

# ---------------------------------------------------------------------------
# Magic skateboard (F) — the new feature. Drives the player through L1's
# board zone under real physics and confirms: it actually engages/disengages
# at the zone bounds, it holds a hover height instead of falling, and
# steering input actually changes horizontal velocity.
# ---------------------------------------------------------------------------

func _test_skateboard_zone_hover_and_steer() -> void:
	print("Magic skateboard — L1 board zone:")
	# Same Engine.time_scale-stuck-at-0.05 hazard as the boss contact tests
	# (see the comment in _test_boss_hits_player_on_contact) — this test runs
	# immediately after the Auditor contact test, which deals damage and
	# frees its player shortly after, and can leave time_scale orphaned low.
	# Confirmed by a real run: velocity.y sat around 1500 while position.y
	# advanced ~1px/frame instead of the ~25px/frame that velocity implies at
	# a normal 60Hz delta — a ~20x slowdown, matching 1/0.05.
	Engine.time_scale = 1.0
	GameManager.dash_return = {"level_index": 1}
	await _arm_decoy_current_scene()
	var run: Node = BLAZE_RUSH.instantiate()
	add_child(run)
	await get_tree().process_frame
	await get_tree().process_frame

	var zone: Dictionary = run.get("_board_zone")
	_check("L1 layout defines a board zone", not zone.is_empty())
	if zone.is_empty():
		run.queue_free()
		return
	var zone_start: float = float(zone.get("start"))
	var zone_end: float = float(zone.get("end"))
	var path_height: float = float(zone.get("path_height"))
	var target_y: float = BlazeRushLayouts.GROUND_Y - path_height

	var player: Node = run.get("_player")
	# Drop the player well before the zone, falling normally (off-board). Not
	# just a small margin: the auto-run's own velocity.x (~370-390px/s) covers
	# real distance during the wait below — a 40px buffer got consumed by the
	# 10-frame settle wait itself, so the player was already inside the zone
	# by the time this checked "not yet on board" (confirmed by a real run).
	player.position = Vector2(zone_start - 300.0, target_y - 200.0)
	player.velocity = Vector2.ZERO
	for i in 10:
		await get_tree().physics_frame
	_check("before the zone: not on the board", not bool(run.get("_on_board")),
		"_on_board was already true before reaching the zone")

	# Cross into the zone and let the spring settle onto the hover band.
	player.position.x = zone_start + 10.0
	var entered := false
	for i in 30:
		await get_tree().physics_frame
		if bool(run.get("_on_board")):
			entered = true
			break
	_check("crossing zone_start engages the board", entered)

	# Zone is 600px wide; at this course's local speed (~370-390px/s) that's
	# crossed in ~1.5-1.6s (~95 physics frames). The spring (rate 8.0, time
	# constant 0.125s) converges within ~30 frames, so 40 is a safe margin
	# that settles well before exiting the far side — a prior version waited
	# 90 frames against an original 280px-wide zone crossed in under a
	# second, so it was reading the player's position AFTER it had already
	# exited back into free-fall, not while genuinely on the board.
	for i in 40:
		await get_tree().physics_frame
		if i % 5 == 0:
			_info("  settle frame %d" % i,
				"pos=%s vel=%s on_board=%s zone_x=[%.0f,%.0f]"
					% [str(player.position), str(player.velocity), str(run.get("_on_board")),
					   zone_start, zone_end])
	var settled_y: float = player.position.y
	_check("still on the board after settling (didn't already exit the zone)",
		bool(run.get("_on_board")), "_on_board went false before settling finished")
	_info("player y after settling (target %.0f)" % target_y, settled_y)
	_check("board holds a hover height instead of falling",
		absf(settled_y - target_y) < 20.0,
		"settled at y=%.1f, expected within 20px of target %.1f" % [settled_y, target_y])

	# Steering: hold right, confirm velocity.x rises above the base run speed.
	var steer_axis_before := Input.get_axis("move_left", "move_right")
	Input.action_press("move_right")
	var steer_axis_after := Input.get_axis("move_left", "move_right")
	for i in 20:
		await get_tree().physics_frame
	var vx_steered: float = player.velocity.x
	var base_speed: float = run.get("_current_speed")
	Input.action_release("move_right")
	_info("Input.get_axis(move_left,move_right) before/after action_press",
		"%.2f -> %.2f" % [steer_axis_before, steer_axis_after])
	_check("steering right increases velocity.x above the base run speed",
		vx_steered > base_speed + 20.0,
		"velocity.x=%.1f, base speed=%.1f (Input.action_press may not simulate reliably in --headless — see the axis INFO line above)"
			% [vx_steered, base_speed])

	# Cross out the far end and confirm the board disengages.
	player.position.x = zone_end + 10.0
	var exited := false
	for i in 30:
		await get_tree().physics_frame
		if not bool(run.get("_on_board")):
			exited = true
			break
	_check("crossing zone_end disengages the board", exited)

	run.queue_free()
	GameManager.dash_return = {}
	await get_tree().process_frame

# ---------------------------------------------------------------------------
# D2 — boss backdrop floor alignment. Founder: "Lil Blunt stands in the air
# on flat ground art" near the Distributor arena. Real cause: the boss
# backdrop inherited the main level's SCROLLING/TILING parallax, so its
# illustrated floor line drifts to an arbitrary position by the time the
# camera reaches the arena. Fix makes the backdrop world-fixed and aligned
# to the real ground segment. This proves the ALIGNMENT MATH, not the pixels
# on screen — a live screenshot is still the final word on how it looks.
# ---------------------------------------------------------------------------

func _test_boss_backdrop_floor_alignment(level_index: int) -> void:
	print("Boss backdrop floor alignment — L%d:" % level_index)
	var scene_path: String = LEVEL_SCENES[level_index]
	var packed: PackedScene = load(scene_path)
	var level: Node = packed.instantiate()
	add_child(level)
	for i in 5:
		await get_tree().process_frame

	var level_data: Resource = level.get("level_data")
	if level_data == null:
		_check("L%d level_data resolved" % level_index, false)
		level.queue_free()
		return

	level.call("set_boss_background")
	await get_tree().process_frame

	var spr: Sprite2D = level.get("_boss_backdrop_sprite")
	_check("L%d: dedicated boss backdrop sprite exists" % level_index, is_instance_valid(spr))
	if not is_instance_valid(spr):
		level.queue_free()
		return

	var layer := spr.get_parent() as ParallaxLayer
	# UPDATED 2026-08-04. This used to also demand motion_mirroring == ZERO.
	# That was correct for the older design, where the boss art only had to
	# span the arena. The founder then required the arena art to hold across
	# the WHOLE stage ("even if Lil Blunt runs back to the beginning"), and a
	# single 1280px image cannot cover a 3400px level without repeating.
	# Mirroring is safe here specifically BECAUSE motion_scale is 1: the layer
	# is world-locked, so it tiles without ever drifting against real geometry
	# (drift was the original D2 bug, and it came from motion_scale 0.35).
	_check("L%d: backdrop layer world-locked (motion_scale 1.0)" % level_index,
		layer != null and layer.motion_scale == Vector2(1.0, 1.0),
		"motion_scale=%s" % str(layer.motion_scale if layer else "?"))
	_check("L%d: backdrop tiles horizontally to span the whole level" % level_index,
		layer != null and layer.motion_mirroring.x > 0.0,
		"mirroring=%s" % str(layer.motion_mirroring if layer else "?"))

	var start_x: float = level_data.boss_arena.get("start_x", 0.0)
	var end_x: float = level_data.boss_arena.get("end_x", start_x)
	var expected_floor_y: float = level.call("_floor_y_at", start_x)
	var art_floor_row: float = level.get("BOSS_ART_FLOOR_ROW")
	var scale_factor: float = spr.scale.x
	var actual_art_floor_world_y: float = spr.position.y + art_floor_row * scale_factor
	_info("L%d expected ground Y / art's illustrated floor world Y" % level_index,
		"%.1f / %.1f" % [expected_floor_y, actual_art_floor_world_y])
	_check("L%d: backdrop's illustrated floor lines up with the real ground surface" % level_index,
		absf(actual_art_floor_world_y - expected_floor_y) < 1.0,
		"art floor at world y=%.1f, real ground at y=%.1f" % [actual_art_floor_world_y, expected_floor_y])

	# Coverage. A Kimi K3 audit previously caught a version of this fix that
	# centred the art on the 700px arena and left ~300px of blank screen,
	# because the camera can see WEST of start_x the moment the player
	# crosses in. The art now starts at the level origin and TILES, so
	# coverage is continuous from x=0 rightwards for the full level — assert
	# that rather than a single sprite's finite width.
	var tile_w: float = spr.texture.get_width() * scale_factor
	_info("L%d art origin / tile width / level bounds" % level_index,
		"%.1f / %.1f / %.1f" % [spr.position.x, tile_w, level_data.bounds.x])
	_check("L%d: backdrop starts at the level origin so nothing west of the arena is stale" % level_index,
		absf(spr.position.x) < 1.0, "starts at x=%.1f" % spr.position.x)
	_check("L%d: tiling actually repeats (one tile alone cannot span the level)" % level_index,
		tile_w > 0.0 and (layer != null and absf(layer.motion_mirroring.x - tile_w) < 1.0),
		"tile %.1f vs mirroring %s" % [tile_w, str(layer.motion_mirroring if layer else "?")])
	var skirt: ColorRect = level.get("_boss_backdrop_skirt")
	_check("L%d: opaque under-floor skirt spans the level" % level_index,
		is_instance_valid(skirt) and skirt.size.x >= level_data.bounds.x,
		"skirt=%s" % (str(skirt.size) if is_instance_valid(skirt) else "missing"))

	level.queue_free()
	await get_tree().process_frame

## Boss body centre in LOCAL space, read from the boss's actual CollisionShape2D
## instead of the hardcoded Vector2(48, 48) this test used to carry.
##
## That literal was the centre of a 96x96 boss. The Auditor is now 168 and the
## Distributor 176 (the founder asked for them to be much bigger), so the old
## constant no longer pointed at the middle of anything — the test was placing
## the player near a corner and then reporting the GAME as broken. A test that
## hardcodes a size silently rots the moment that size is tuned.
func _body_centre(boss: Node2D) -> Vector2:
	var cs := boss.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs and cs.shape is RectangleShape2D:
		return cs.position
	return Vector2(48, 48)

## Far enough out to guarantee a real exit transition for ANY boss size —
## body half-width plus the player's own width plus margin.
func _exit_dist(boss: Node2D) -> float:
	var cs := boss.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs and cs.shape is RectangleShape2D:
		return (cs.shape as RectangleShape2D).size.x / 2.0 + 90.0
	return 160.0

## "Its like you just threw them around with no care to placement" + the items
## masking each other, in the Smoke Lounge.
##
## Measured, not eyeballed: build the real lounge and read back the world X of
## every collectible it spawned. Five pickup types used to each generate their
## own independent arithmetic progression at the same Y, so 22 of 43 items sat
## inside a neighbour's 44px trigger — including an exact 0px overlap. They are
## now placed from one evenly-pitched lattice, and this asserts BOTH properties
## the founder actually named: nothing overlaps, and the spacing is uniform.
func _test_lounge_pickups_never_overlap() -> void:
	var lounge: Node2D = load("res://src/level/secret_realm.tscn").instantiate()
	get_tree().root.add_child(lounge)
	await get_tree().process_frame
	await get_tree().process_frame

	var xs: Array[float] = []
	for node in lounge.get_children():
		var a := node as Area2D
		if a == null:
			continue
		# Every lounge pickup is on the collectible layer (8) and sits in the
		# skate band; the level's own props are not Area2Ds on that layer.
		if a.collision_layer != 8:
			continue
		xs.append(a.global_position.x)
	xs.sort()
	_info("lounge pickups placed", xs.size())
	_check("the lounge actually spawned its pickup lane", xs.size() >= 30,
		"only %d collectibles found" % xs.size())

	var min_gap := INF
	var max_gap := 0.0
	for i in range(1, xs.size()):
		var g: float = xs[i] - xs[i - 1]
		min_gap = minf(min_gap, g)
		max_gap = maxf(max_gap, g)
	if xs.size() > 1:
		_info("closest two pickups (px apart)", min_gap)
		# 44px triggers on ~40px sprites: below ~88px they visibly touch.
		_check("no two lounge pickups mask each other", min_gap >= 88.0,
			"closest pair is %.0fpx apart — they overlap on screen" % min_gap)
		# Uniform pitch is the other half of the complaint. A lattice gives one
		# pitch end to end; independent progressions give a ragged spread.
		_check("lounge pickup spacing is uniform, not scattered",
			max_gap - min_gap < 2.0,
			"pitch varies from %.0f to %.0f px" % [min_gap, max_gap])

	lounge.queue_free()
	await get_tree().process_frame

## "Return the trees in the background of the Blaze Rush... the theme of the
##  2nd should align with the 2nd stage and same with the 3rd" — and NOT a
##  single tint of the main stage art.
##
## The previous implementation loaded each LEVEL's own painted plate and
## modulated it toward magenta, so all three runs were one picture at three
## tints. A check that merely asserted "a backdrop layer exists" would have
## passed that happily, which is why this compares the three realms against
## each other instead: it reads the texture actually assigned for L1/L2/L3 and
## requires three DIFFERENT plates, each the realm's dedicated forest art, all
## shipping unmodulated.
func _test_blaze_backdrops_differ_per_realm() -> void:
	var seen: Dictionary = {}
	for level_index in [1, 2, 3]:
		GameManager.dash_return = {
			"scene_path": LEVEL_SCENES[level_index],
			"position": Vector2(1234.5, 321.5),
			"level_index": level_index,
		}
		await _arm_decoy_current_scene()
		var run: Node = BLAZE_RUSH.instantiate()
		add_child(run)
		await get_tree().process_frame
		await get_tree().process_frame

		var path: String = ""
		var tint := Color(1, 1, 1, 1)
		# The backdrop is the slowest ParallaxLayer in the run's background.
		for pbg in _find_all(run, "ParallaxBackground"):
			for child in pbg.get_children():
				var pl := child as ParallaxLayer
				if pl == null or not is_equal_approx(pl.motion_scale.x, 0.08):
					continue
				for gc in pl.get_children():
					var spr := gc as Sprite2D
					if spr != null and spr.texture != null:
						path = spr.texture.resource_path
						tint = spr.modulate
		_check("L%d Blaze: a backdrop plate is assigned" % level_index, path != "",
			"no 0.08-motion_scale ParallaxLayer with a texture was built")
		if path != "":
			_check("L%d Blaze: uses its own realm forest plate, not the level's art" % level_index,
				path.contains("bg_blaze_l"), path)
			# A modulated plate is the "single tint of the main stage art" the
			# founder rejected — the realm plates are painted, not tinted.
			_check("L%d Blaze: backdrop ships unmodulated (painted, not tinted)" % level_index,
				tint.is_equal_approx(Color(1, 1, 1, 1)), str(tint))
			seen[level_index] = path
		run.queue_free()
		await get_tree().process_frame

	var distinct: Dictionary = {}
	for k in seen:
		distinct[seen[k]] = true
	_info("blaze backdrops", seen)
	_check("all three Blaze realms use DIFFERENT backdrops",
		distinct.size() == seen.size() and seen.size() == 3,
		"%d plate(s) across %d realms — a shared plate is the 'same art, different tint' defect"
			% [distinct.size(), seen.size()])

## Depth-first search for nodes of a given class name.
func _find_all(root: Node, cls: String) -> Array[Node]:
	var out: Array[Node] = []
	if root.is_class(cls):
		out.append(root)
	for c in root.get_children():
		out.append_array(_find_all(c, cls))
	return out

## B3 — GoldMine moved right; the Robin Hood x Smoke Lounge artwork was already
## in the repo (byte-identical to an unreferenced file, br_robinhood.png) and
## now fills the slot GoldMine vacated. This proves both halves against the
## real band build rather than reading the ordered list back.
func _test_blaze_band_includes_robinhood_after_goldmine_move() -> void:
	GameManager.dash_return = {
		"scene_path": LEVEL_SCENES[1],
		"position": Vector2(1234.5, 321.5),
		"level_index": 1,
	}
	await _arm_decoy_current_scene()
	var run: Node = BLAZE_RUSH.instantiate()
	add_child(run)
	await get_tree().process_frame
	await get_tree().process_frame

	var paths: Array[String] = []
	for child in run.get_children():
		var spr := child as Sprite2D
		if spr != null and spr.texture != null:
			paths.append(spr.texture.resource_path)

	_check("Blaze band includes the Robin Hood x Smoke Lounge artwork",
		paths.any(func(p: String) -> bool: return p.contains("br_robinhood")),
		"br_robinhood.png was not placed on the course")
	_check("Blaze band still includes the GoldMine badge",
		paths.any(func(p: String) -> bool: return p.contains("badge_goldmine")),
		"moving GoldMine right must not drop it from the band")
	run.queue_free()
	await get_tree().process_frame

## The founder replaced the Blaze theme (New_LB3.mp3, "Enter the Blaze Rush!
## Crush DIAMONDS!"). Confirms the run actually acquires a music override on
## the shipped file, not merely that the file exists on disk.
func _test_blaze_music_is_the_founders_track() -> void:
	var path := "res://src/assets/music/blaze_rush_theme.mp3"
	_check("Blaze theme file present", ResourceLoader.exists(path))
	if not ResourceLoader.exists(path):
		return
	var stream: AudioStream = load(path) as AudioStream
	_check("Blaze theme loads as an AudioStream", stream != null)
	if stream:
		# The founder's track runs ~3:24; the old placeholder theme was much
		# shorter. A length floor catches an accidental revert to the old file
		# without hardcoding an exact duration future re-encodes might shift.
		_check("Blaze theme is the founder's ~3:24 track, not the old placeholder",
			stream.get_length() > 120.0, "length=%.1fs" % stream.get_length())

	GameManager.dash_return = {
		"scene_path": LEVEL_SCENES[1],
		"position": Vector2(1234.5, 321.5),
		"level_index": 1,
	}
	await _arm_decoy_current_scene()
	var run: Node = BLAZE_RUSH.instantiate()
	add_child(run)
	for i in 6:
		await get_tree().process_frame
	_check("Blaze run acquires the music override on the shipped theme",
		int(run.get("_music_token")) != -1)
	run.queue_free()
	await get_tree().process_frame

## B1 / B2 / B6 — "wired but not visible" must never ship as a claim again.
##
## Founder, after a prior pass, correctly pushed back: code that checks
## ResourceLoader.exists() is not the same as the art showing up in the game.
## This instantiates the REAL Blaze Rush scene and reads back the actual
## Texture2D assigned to each live node, and asserts it resolves to the
## founder's file by RESOURCE PATH — not merely "a texture is set" (which the
## old fallback assets would also satisfy) and not merely "the file is on
## disk" (which proves nothing about whether the game picked it up).
func _test_founder_art_drop_ins_actually_render() -> void:
	if not ResourceLoader.exists("res://src/assets/logos/founder/enter_the_blaze_rush.png") \
			and not ResourceLoader.exists("res://src/assets/logos/founder/now_look_smoke_lounge.png"):
		_check("founder art drop-in check skipped (no founder art on disk yet)", true)
		return

	GameManager.dash_return = {
		"scene_path": "res://src/level/level_01_smoke_realm.tscn",
		"position": Vector2(500, 400),
		"level_index": 1,
	}
	var run: Node2D = BLAZE_RUSH.instantiate()
	add_child(run)
	await get_tree().process_frame
	await get_tree().process_frame

	# B1 — REVERTED. Founder: "why did you change the diamonds!!! Want the blue
	# flaming diamonds!!!" A prior pass substituted blaze_diamond_correct.png
	# (the clear diamond baked into the "Enter the Blaze Rush" wordmark) for the
	# in-course pickup, which was never its intended use. The token must always
	# be the original blue gem, unconditionally — asserted here so a future
	# founder-art drop at that path can never silently re-trigger the same
	# mistake through the old ResourceLoader.exists() branch.
	var tokens: Array = run.get("_smoke_tokens")
	_check("Blaze Rush spawned diamond tokens to check", tokens.size() > 0)
	if tokens.size() > 0:
		var tok_spr: Sprite2D = (tokens[0] as Node).get_child(0) as Sprite2D
		_check("B1: token Sprite2D exists", tok_spr != null)
		if tok_spr != null:
			var tok_tex: Texture2D = tok_spr.texture
			_check("B1: token texture is the ORIGINAL blue flaming diamond, not the founder's wordmark diamond",
				tok_tex != null and tok_tex.resource_path.contains("fx_flame_diamond_blue"),
				"resource_path = %s" % (tok_tex.resource_path if tok_tex else "null"))

	# B2 — REDESIGNED. Founder circled the purple GROUND BAND on a screenshot,
	# not the sky, and a second screenshot much later in the same attempt
	# ("Attempt 45") showed that spot still empty — proof the old screen-space
	# fade-and-despawn card had already vanished for good. It is now a plain
	# world-space band object with no tween and no despawn, so this checks BOTH
	# that it exists immediately AND that it is still there after real time
	# passes (the exact window the founder's second screenshot caught empty).
	if ResourceLoader.exists("res://src/assets/logos/founder/enter_the_blaze_rush.png"):
		var card := run.get_node_or_null("WorldCard") as Sprite2D
		_check("B2: WorldCard is a Sprite2D (world-space, not a CanvasLayer overlay)", card != null)
		if card != null:
			var card_tex: Texture2D = card.texture
			_check("B2: live world card texture IS the founder's 'Enter the Blaze Rush' art",
				card_tex != null and card_tex.resource_path.contains("enter_the_blaze_rush"),
				"resource_path = %s" % (card_tex.resource_path if card_tex else "null"))
			_check("B2: world card sits on the purple ground band, not floating in the sky",
				card.position.y > 500.0, "y = %.0f" % card.position.y)
			for i in 120:
				await get_tree().process_frame
			_check("B2: world card is STILL present after 2s (Attempt-45 style — no fade, no despawn)",
				is_instance_valid(card) and card.is_inside_tree())

	# B6 — the lounge banner replaces the legacy plate OUTRIGHT (not alongside),
	# AND now sits near the very end of the course. Founder, drawing an arrow to
	# the far edge of a screenshot labelled "End!!": "This banner... is for the
	# very fucking end!!!" — it was at 74% of the course before, which his own
	# annotation rejects as not the end.
	if ResourceLoader.exists("res://src/assets/logos/founder/now_look_smoke_lounge.png"):
		var banner := run.get_node_or_null("SmokeLoungeBanner")
		_check("B6: SmokeLoungeBanner node was built", banner != null)
		if banner != null:
			var art_spr: Sprite2D = null
			for c in banner.get_children():
				if c is Sprite2D:
					art_spr = c
			_check("B6: banner carries a Sprite2D", art_spr != null)
			if art_spr != null:
				var banner_tex: Texture2D = art_spr.texture
				_check("B6: live banner texture IS the founder's replacement art",
					banner_tex != null and banner_tex.resource_path.contains("now_look_smoke_lounge"),
					"resource_path = %s" % (banner_tex.resource_path if banner_tex else "null"))
			var course_length: float = float(run.get("_course_length"))
			_check("B6: banner sits near the END of the course, not at 74%",
				(banner as Node2D).position.x > course_length * 0.85,
				"x = %.0f of course_length %.0f" % [(banner as Node2D).position.x, course_length])
		# The legacy lowrider plate must not ALSO appear in the landmark band —
		# "replace entirely" means gone, not doubled up.
		var legacy_still_present := false
		for child in run.get_children():
			var spr := child as Sprite2D
			if spr != null and spr.texture != null and spr.texture.resource_path.contains("br_smoke_lounge_car"):
				legacy_still_present = true
		_check("B6: the legacy lowrider plate is dropped from the band, not doubled up",
			not legacy_still_present)

	run.queue_free()
	await get_tree().process_frame

## Founder circled the L1 coin token in a screenshot (the exact sprite
## coin.gd's STAGE_TOKENS maps for GameManager.current_level == 1): "I want
## you to make these the TitanX logos that I originally requested!!!" — the
## token was baked from the Lil Blunt / FOMO mark, a reasonable but wrong
## guess. Reads back the LIVE Sprite2D.texture.resource_path on a real
## instantiated coin, exactly like the Blaze Rush founder-art checks, so this
## proves the runtime swap picked up the new bake rather than merely that the
## file exists on disk.
func _test_campaign_stage_tokens_use_the_right_protocol_mark() -> void:
	var prev_level: int = GameManager.current_level
	GameManager.current_level = 1
	var coin: Area2D = load("res://src/collectibles/coin.tscn").instantiate()
	add_child(coin)
	await get_tree().process_frame

	var spr := coin.get_node_or_null("Sprite") as Sprite2D
	_check("L1 coin token: Sprite2D exists", spr != null)
	if spr != null:
		var tex: Texture2D = spr.texture
		_check("L1 coin token: live texture IS the TitanX mark, not the old Lil Blunt token",
			tex != null and tex.resource_path.contains("sprite_token_l1"),
			"resource_path = %s" % (tex.resource_path if tex else "null"))

	coin.queue_free()
	await get_tree().process_frame
	GameManager.current_level = prev_level
