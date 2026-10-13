extends Node
## Regression: walking off the LEFT (or right) END of a level must kill the
## player like any other pit, not drop him into an endless fall.
##
## Observed 2026-10-13 in a real Chromium run with the F3 overlay (`?debug=1`)
## on Stage 1: walk LEFT off the start platform and the overlay read
## `PLAYER pos(-1736,10190) |v|=747 floor=false dying=false` and kept climbing
## past y=22000 with the state still PLAYING. Walking off the right side into the
## real pits killed correctly (GAME_OVER -> respawn at the checkpoint).
##
## ROOT CAUSE: `LevelBase._setup_kill_zone()` built its strips over
## `[0, level_data.bounds.x]` only (and `secret_realm.gd`'s lounge kill zone was
## `BOUNDS` wide, centred on the room). The band is a thin Area2D, so a player
## whose x was outside the level's own width fell *beside* it — the world has no
## floor out there and nothing else ever ends the fall. Camera limit_left=0 only
## stops the camera; it does not stop the body.
##
## This gate has three layers so a regression names its cause:
##   1. Interval/coverage on a bare LevelBase: the band is continuous from
##      -margin to bounds+margin, and a registered `kill_zone_gaps` vault
##      carve-out is STILL excluded (the vault mechanism must not be undone).
##   2. The same coverage on the three REAL stage scenes.
##   3. Real physics on the real scenes: hold LEFT from the real spawn and walk
##      off the start platform (the founder's exact repro), then drop the body
##      far outside either end, and assert a pit death (a life is spent and the
##      player is respawned on solid ground) within a few seconds. The Smoke
##      Lounge gets the same treatment. A control case proves an interior pit
##      still kills exactly as before.
##
## Run: godot --headless res://tests/world_edge_kill_zone_test.tscn

const STAGES := {
	1: "res://src/level/level_01_smoke_realm.tscn",
	2: "res://src/level/level_02_crystal_caverns.tscn",
	3: "res://src/level/level_03_gold_rush.tscn",
}
const LOUNGE := preload("res://src/level/secret_realm.tscn")

## "Within a few seconds": 6 s of physics. A real walk-off + fall takes ~1-2 s;
## the unfixed game never finishes (the founder watched y pass 22000).
const DEATH_DEADLINE_FRAMES := 360
## CONTROL pits: the centre x of one real interior pit per stage that nothing
## bridges (L1 800..900, L2 800..900, L3 1520..1660). The first gap of L2 is NOT
## usable: a secret wall hugs its right edge ((468,586), level_02 _setup_depth_
## routes) and L3's first two gaps are bridged by the blue blocks. The player's
## collision box is 32 wide with its origin at the top-left, so the drop is
## placed at x - 16 to centre the box in the gap.
const CONTROL_PIT_X := {1: 850.0, 2: 850.0, 3: 1590.0}
const PLAYER_BOX_W := 32.0
## How far outside the level the "knocked far away" cases drop the body. Well
## inside LevelBase.KILL_ZONE_EDGE_MARGIN, well outside any plausible walk.
const FAR_OUTSIDE := 1500.0

var _fail: int = 0
## Lives spent since the current scenario started (see _on_lives_changed).
var _deaths: int = 0
var _last_lives: int = 0
## Where the player was the instant the life was spent. lose_life() runs BEFORE
## the respawn repositions him, so this is the true place of death. Without it a
## walk-off could "pass" by dying in some INTERIOR pit on the way — the wrong
## thing — so every scenario also asserts WHERE it died.
var _death_pos: Vector2 = Vector2.ZERO
var _player_ref: CharacterBody2D = null

func _ready() -> void:
	await get_tree().process_frame
	print("WORLD EDGE KILL ZONE:")
	_test_bare_level_band_is_continuous_and_keeps_vault_gaps()
	for idx: int in STAGES.keys():
		await _test_stage(idx)
	await _test_lounge()
	print("WORLD_EDGE_KILL_ZONE: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

# ---------------------------------------------------------------------------
# Layer 1 + 2: coverage (no physics)
# ---------------------------------------------------------------------------

## True if any "hazard" kill strip that is a direct child of `host` contains the
## world point. Reads the same Area2D/RectangleShape2D the engine would use.
func _band_covers(host: Node, point: Vector2) -> bool:
	for child: Node in host.get_children():
		var area := child as Area2D
		if area == null or not area.is_in_group("hazard"):
			continue
		for sub: Node in area.get_children():
			var cs := sub as CollisionShape2D
			var rect: RectangleShape2D = (cs.shape as RectangleShape2D) if cs != null else null
			if rect == null:
				continue
			var centre: Vector2 = area.position + cs.position
			if absf(point.x - centre.x) <= rect.size.x / 2.0 \
					and absf(point.y - centre.y) <= rect.size.y / 2.0:
				return true
	return false

func _test_bare_level_band_is_continuous_and_keeps_vault_gaps() -> void:
	print(" Coverage on a bare LevelBase (no scene tree):")
	# Arrange: a level 4800 wide with a vault carve-out, built WITHOUT _ready()
	# (same trick as kill_zone_gap_test.gd — _ready needs real child nodes).
	var lvl := LevelBase.new()
	lvl.level_data = LevelData.new()
	lvl.level_data.bounds = Vector2(4800.0, 720.0)
	lvl.level_data.kill_zone_y = 800.0
	var gap := Vector2(2340.0, 2560.0)
	lvl.kill_zone_gaps.append(gap)

	# Act
	lvl._setup_kill_zone()

	# Assert: every sampled x in the whole span is lethal EXCEPT the vault gap.
	var margin: float = LevelBase.KILL_ZONE_EDGE_MARGIN
	var y: float = 800.0
	var uncovered: Array[float] = []
	var leaked_into_gap: Array[float] = []
	var x: float = -margin + 1.0
	while x < 4800.0 + margin:
		var inside_gap: bool = x > gap.x and x < gap.y
		var covered: bool = _band_covers(lvl, Vector2(x, y))
		if inside_gap and covered:
			leaked_into_gap.append(x)
		elif not inside_gap and not covered:
			uncovered.append(x)
		x += 25.0
	_check("band is continuous from -margin to bounds+margin (outside the vault gap)",
		uncovered.is_empty(), "uncovered x samples: %s" % str(uncovered.slice(0, 6)))
	_check("registered kill_zone_gaps vault carve-out is still NOT lethal",
		leaked_into_gap.is_empty(), "lethal inside gap at x: %s" % str(leaked_into_gap.slice(0, 6)))
	_check("band covers x just left of the level start (the founder's repro)",
		_band_covers(lvl, Vector2(-40.0, y)))
	_check("band covers x just past the level end",
		_band_covers(lvl, Vector2(4800.0 + 40.0, y)))
	lvl.free()

func _test_stage_coverage(idx: int, level: LevelBase) -> void:
	var data: LevelData = level.level_data
	var y: float = data.kill_zone_y + 175.0
	var w: float = data.bounds.x
	_check("stage %d: band covers x<0 (left of the start platform)" % idx,
		_band_covers(level, Vector2(-60.0, y)) and _band_covers(level, Vector2(-FAR_OUTSIDE, y)))
	_check("stage %d: band covers x>bounds (past the right end)" % idx,
		_band_covers(level, Vector2(w + 60.0, y)) and _band_covers(level, Vector2(w + FAR_OUTSIDE, y)))
	_check("stage %d: band still covers the level interior" % idx,
		_band_covers(level, Vector2(w / 2.0, y)))

# ---------------------------------------------------------------------------
# Layer 3: real physics
# ---------------------------------------------------------------------------

func _on_lives_changed(new_lives: int) -> void:
	if new_lives < _last_lives:
		_deaths += 1
		if is_instance_valid(_player_ref):
			_death_pos = _player_ref.global_position
	_last_lives = new_lives

## Runs one scenario and returns the physics frames until a life was spent, or
## -1 if the deadline passed with the player still alive and falling.
## `teleport_to` == null keeps the player wherever the scene put him (the real
## spawn); `hold` is an InputMap action held for the whole run ("" = none).
func _frames_until_death(player: CharacterBody2D, teleport_to: Variant, hold: String) -> int:
	GameManager.refill_run()
	_deaths = 0
	_death_pos = Vector2.INF
	_player_ref = player
	_last_lives = GameManager.lives
	GameManager.lives_changed.connect(_on_lives_changed)
	if teleport_to != null:
		player.global_position = teleport_to as Vector2
		player.velocity = Vector2.ZERO
	if hold != "":
		Input.action_press(hold)
	var frames: int = -1
	for i in DEATH_DEADLINE_FRAMES:
		await get_tree().physics_frame
		if _deaths > 0:
			frames = i + 1
			break
	if hold != "":
		Input.action_release(hold)
	GameManager.lives_changed.disconnect(_on_lives_changed)
	return frames

## Failure detail: where the body is and what (if anything) it is resting on.
func _where(player: CharacterBody2D) -> String:
	var rest: String = "nothing"
	var col := player.get_last_slide_collision()
	if col != null and col.get_collider() != null:
		var c := col.get_collider() as Node
		rest = "%s@%s" % [c.name, str((c as Node2D).global_position) if c is Node2D else "?"]
	return "pos=%s on_floor=%s resting_on=%s" % [str(player.global_position), str(player.is_on_floor()), rest]

## After the death the player must be back on solid, in-level ground and
## PLAYING again — "respawn happens", not merely "a life was spent".
func _respawned_in_level(player: CharacterBody2D, kill_y: float) -> bool:
	return player.global_position.y < kill_y - 100.0 and StateMachine.is_playing()

func _reset_world_state() -> void:
	GameManager.secret_return = {}
	for i in [1, 2, 3]:
		GameManager.clear_checkpoint(i)
	GameManager.refill_run()
	# Enter a scene the way production does (SceneRouter: ... -> TRANSITIONING ->
	# the scene's own _ready() flips it to PLAYING). The machine boots in MENU,
	# and MENU -> PLAYING is not an allowed edge, so without this the level's
	# change_state(PLAYING) is refused, player.gd::_physics_process early-returns
	# on `not StateMachine.is_playing()`, the body never falls and every
	# assertion below is VACUOUS (this is the trap blue_block_floor_freeze_test
	# documents). The first run of this test hit it: pos never changed.
	if StateMachine.can_transition(StateMachine.get_state_enum(), StateMachine.State.TRANSITIONING):
		StateMachine.change_state(StateMachine.State.TRANSITIONING)

func _test_stage(idx: int) -> void:
	print(" Stage %d (real scene):" % idx)
	_reset_world_state()
	var level := (load(STAGES[idx]) as PackedScene).instantiate() as LevelBase
	add_child(level)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
	if player == null:
		_check("stage %d: scene spawned a player" % idx, false)
		level.queue_free()
		return

	_test_stage_coverage(idx, level)

	var kill_y: float = level.level_data.kill_zone_y
	var width: float = level.level_data.bounds.x
	var spawn: Vector2 = player.global_position

	# CONTROL, run FIRST on the fresh level (no earlier deaths/respawns can
	# colour it): a real interior pit must still kill exactly as before, and the
	# death must happen IN that pit.
	var pit_x: float = CONTROL_PIT_X[idx]
	var f: int = await _frames_until_death(player, Vector2(pit_x - PLAYER_BOX_W / 2.0, 560.0), "")
	_check("stage %d: CONTROL — interior pit at x=%d still kills as before" % [idx, int(pit_x)],
		f > 0 and absf(_death_pos.x - pit_x) < 80.0,
		"died=%s at %s — %s" % [str(f > 0), str(_death_pos), _where(player)])
	await get_tree().physics_frame

	# Founder's exact repro: from the REAL spawn (re-placed, because the control
	# above respawned him elsewhere), hold LEFT and walk off the start platform.
	f = await _frames_until_death(player, spawn, "move_left")
	_check("stage %d: holding LEFT from the spawn %s ends in a pit death (<= %d frames)"
			% [idx, str(spawn), DEATH_DEADLINE_FRAMES],
		f > 0, "no death after %d frames — endless fall, %s" % [DEATH_DEADLINE_FRAMES, _where(player)])
	_check("stage %d: ...and it happens OFF THE LEFT END (x<0), not in an interior pit" % idx,
		_death_pos.x < 0.0, "died at %s" % str(_death_pos))
	await get_tree().physics_frame
	_check("stage %d: respawned on solid ground after the left-edge death" % idx,
		_respawned_in_level(player, kill_y), "pos=%s playing=%s" % [str(player.global_position), str(StateMachine.is_playing())])
	print("    [INFO] left-edge walk-off: died at x=%.0f after %d physics frames (%.2fs)" % [_death_pos.x, f, f / 60.0])

	# Dropped far outside either end (knockback, dash, a long air drift).
	f = await _frames_until_death(player, Vector2(-FAR_OUTSIDE, 300.0), "")
	_check("stage %d: body %dpx left of the level ends in a pit death" % [idx, int(FAR_OUTSIDE)],
		f > 0 and _death_pos.x < 0.0, "endless fall, %s" % _where(player))
	await get_tree().physics_frame
	f = await _frames_until_death(player, Vector2(width + FAR_OUTSIDE, 300.0), "")
	_check("stage %d: body %dpx right of the level ends in a pit death" % [idx, int(FAR_OUTSIDE)],
		f > 0 and _death_pos.x > width, "endless fall, %s" % _where(player))
	await get_tree().physics_frame

	level.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

func _test_lounge() -> void:
	print(" Smoke Lounge (real scene):")
	_reset_world_state()
	var lounge := LOUNGE.instantiate()
	add_child(lounge)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
	if player == null:
		_check("lounge: scene spawned a player", false)
		lounge.queue_free()
		return
	var bounds: float = lounge.BOUNDS
	var floor_y: float = lounge.FLOOR_Y

	var spawn: Vector2 = player.global_position
	var f: int = await _frames_until_death(player, spawn, "move_left")
	_check("lounge: holding LEFT from the spawn ends in a pit death (<= %d frames)" % DEATH_DEADLINE_FRAMES,
		f > 0, "endless fall, %s" % _where(player))
	_check("lounge: ...and it happens OFF THE LEFT END (x<0)",
		_death_pos.x < 0.0, "died at %s" % str(_death_pos))
	await get_tree().physics_frame
	_check("lounge: respawned on solid ground after the left-edge death",
		_respawned_in_level(player, floor_y + 250.0), "pos=%s" % str(player.global_position))
	print("    [INFO] lounge left-edge walk-off: died at x=%.0f after %d physics frames (%.2fs)" % [_death_pos.x, f, f / 60.0])

	# Straight past either end of the floor. (Dropped, not walked: the return
	# portal sits near the right end and would leave the scene mid-test.)
	f = await _frames_until_death(player, Vector2(-60.0, floor_y - 130.0), "")
	_check("lounge: body just left of the room floor ends in a pit death",
		f > 0 and _death_pos.x < 0.0, "endless fall, %s" % _where(player))
	await get_tree().physics_frame
	f = await _frames_until_death(player, Vector2(bounds + 60.0, floor_y - 130.0), "")
	_check("lounge: body just right of the room floor ends in a pit death",
		f > 0 and _death_pos.x > bounds, "endless fall, %s" % _where(player))
	await get_tree().physics_frame
	f = await _frames_until_death(player, Vector2(-FAR_OUTSIDE, floor_y - 130.0), "")
	_check("lounge: body %dpx left of the room ends in a pit death" % int(FAR_OUTSIDE),
		f > 0 and _death_pos.x < 0.0, "endless fall, %s" % _where(player))
	await get_tree().physics_frame

	lounge.queue_free()
	await get_tree().process_frame
