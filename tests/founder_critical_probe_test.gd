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
	# By design the disc's local vertices run y=[96,128] (mean 112) while the
	# body's collision centre is at local y=48 — an intentional 64-local-px
	# "feet" offset (96 local px is a generous ceiling: 1.5x that intentional
	# gap, scaled by the boss's real transform so BOSS_SCALE changes don't
	# require updating this test).
	_check("disc sits below the body (a real footprint, not floating away from it)",
		offset.y > 0.0 and offset.y < 96.0 * boss.scale.y,
		"vertical offset %.1fpx" % offset.y)

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
	for cycle in 10:  # 10 x 0.5s = 5s total, matching the old budget
		player.global_position = boss.to_global(Vector2(48, 48)) + Vector2(-160, 0)
		for i in 10:
			await get_tree().physics_frame
		player.global_position = boss.to_global(Vector2(48, 48))
		for i in 20:
			await get_tree().physics_frame
			if GameManager.player_health < health_before:
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
	_check("%s: standing in the boss body damages the player under real physics" % label,
		hit, "player health stayed at %d after 5s of repeated contact" % GameManager.player_health)

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
	_check("L%d: backdrop layer world-fixed (motion_scale 1.0, no mirroring)" % level_index,
		layer != null and layer.motion_scale == Vector2(1.0, 1.0) and layer.motion_mirroring == Vector2.ZERO,
		"motion_scale=%s mirroring=%s" % [str(layer.motion_scale if layer else "?"),
			str(layer.motion_mirroring if layer else "?")])

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

	# Kimi K3 audit caught the first version of this fix leaving a blank
	# strip on screen: centering the art on the 700px arena left ~300px
	# uncovered on the left, because the camera's 1280px-wide viewport can
	# show area WEST of start_x the moment the player first crosses in.
	# Assert actual pixel coverage, not just that a scale factor exists.
	var viewport_w: float = get_viewport().get_visible_rect().size.x
	var camera_min_left: float = start_x - viewport_w / 2.0
	var art_left: float = spr.position.x
	var art_right: float = spr.position.x + spr.texture.get_width() * scale_factor
	_info("L%d camera's leftmost reachable view / art's actual left..right edge" % level_index,
		"%.1f / %.1f..%.1f" % [camera_min_left, art_left, art_right])
	_check("L%d: backdrop art covers the camera's full reachable range (no blank strip)" % level_index,
		art_left <= camera_min_left + 1.0 and art_right >= end_x - 1.0,
		"camera can show as far left as x=%.1f and as far right as x=%.1f, but art only covers %.1f..%.1f"
			% [camera_min_left, end_x, art_left, art_right])

	level.queue_free()
	await get_tree().process_frame
