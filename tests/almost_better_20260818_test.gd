extends Node
## Regression gate for PROMPT "Almost_Better.md" (2026-08-18) — a same-day
## follow-up after PROMPT_LEVEL1_MUSIC_ORDER_BOSS1_SIZE_CARTS_CHASE.md found
## real regressions that pass had introduced/left in place:
##
##   1. HUDMask (the "backpiece" behind SCORE/lives) was never actually
##      removed on THIS branch's lineage — a prior session's fix lived on a
##      different branch that never merged. Re-removed from all 3 levels.
##   2. All three bosses restarted the run on spawn contact with zero grace
##      window — a live capture showed the level reloading repeatedly within
##      the first second of a ?boss=1 warp. The Auditor's own BODY increase
##      (168->220, a prior fix) made this worse by giving his hitbox more
##      reach. Spawn grace (shared in BossBase, duplicated for the Auditor
##      since it extends CharacterBody2D directly) stops this.
##   3. Boss VO gain dropped 12->9 dB (founder: "slightly too loud now").
##   4. Fort Knox Assay sign text no longer reaches into the Assay Scale's
##      own panel footprint.
##
## Run: godot --headless res://tests/almost_better_20260818_test.tscn

const AUDITOR := preload("res://src/boss/auditor.tscn")
const DISTRIBUTOR := preload("res://src/boss/distributor.tscn")
const CLAIM_JUMPER := preload("res://src/boss/claim_jumper.tscn")

var _fail: int = 0

func _ready() -> void:
	await get_tree().process_frame
	print("ALMOST_BETTER 2026-08-18:")
	_check_hudmask_removed()
	await _check_spawn_grace(AUDITOR, "Auditor")
	await _check_spawn_grace(DISTRIBUTOR, "Distributor")
	await _check_spawn_grace(CLAIM_JUMPER, "ClaimJumper")
	_check_vo_volume()
	_check_assay_sign_clear_of_panel()
	print("ALMOST_BETTER_20260818: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _check_hudmask_removed() -> void:
	for level_path in [
		"res://src/level/level_01_smoke_realm.tscn",
		"res://src/level/level_02_crystal_caverns.tscn",
		"res://src/level/level_03_gold_rush.tscn",
	]:
		var src := FileAccess.get_file_as_string(level_path)
		_check("%s has no HUDMask backpiece (re-removed after a branch reconciliation gap)" % level_path.get_file(),
			src.find("HUDMask") == -1)

## Instantiate a boss, immediately place a player overlapping its hitbox
## (the exact spawn-contact scenario a live capture caught), and confirm
## the run is NOT restarted while spawn grace is active. Every boss's own
## is_spawn_grace_active() must exist and return true immediately after
## _enter_tree().
func _check_spawn_grace(scene: PackedScene, label: String) -> void:
	var boss: Node = scene.instantiate()
	add_child(boss)
	_check("%s: is_spawn_grace_active() true immediately after spawn" % label,
		boss.has_method("is_spawn_grace_active") and boss.is_spawn_grace_active())
	var before_level := GameManager.current_level
	# Directly invoke the hitbox handler the way the real Hitbox Area2D would,
	# with a minimal stand-in player body (group membership + take_damage is
	# all the handler checks for — no need for the full player scene).
	var player := CharacterBody2D.new()
	player.add_to_group("player")
	var script := GDScript.new()
	script.source_code = "extends CharacterBody2D\nfunc take_damage(_amount := 1) -> void:\n\tpass\n"
	script.reload()
	player.set_script(script)
	add_child(player)
	await get_tree().process_frame
	if boss.has_method("_on_hitbox_body_entered"):
		boss._on_hitbox_body_entered(player)
	_check("%s: spawn-grace contact does NOT restart the run" % label,
		GameManager.current_level == before_level,
		"current_level changed from %s to %s" % [before_level, GameManager.current_level])
	player.queue_free()
	boss.queue_free()
	await get_tree().process_frame

func _check_vo_volume() -> void:
	var src := FileAccess.get_file_as_string("res://src/boss/boss_voice_system.gd")
	var db := 0.0
	for line in src.split("\n"):
		var t := line.strip_edges()
		if t.begins_with("const PLAYER_VOLUME_DB"):
			db = float(t.split(":=")[1])
	_check("boss VO gain reduced from 12 to ~9 dB, still >= 8 dB floor",
		db >= 8.0 and db < 12.0, "PLAYER_VOLUME_DB=%.1f" % db)

func _check_assay_sign_clear_of_panel() -> void:
	var src := FileAccess.get_file_as_string("res://src/level/vault_realm.gd")
	# SUPERSEDED 2026-08-19. This used to pin the literal
	# `Vector2(1780.0, SURFACE_Y - 300.0)`, which is exactly the layout the
	# founder rejected a second time ("Raise the FORT KNOX ASSAY text ... no
	# text should mask other text!!!"): the 2026-08-18 sideways move cleared
	# the scale panel and then collided with the 2888-day pool plate instead.
	# Asserting a magic coordinate also meant the test PASSED while the screen
	# was visibly broken. It now asserts the real invariant — the sign's band
	# and the pool plate's band must not intersect — so any future reposition
	# is judged on whether it actually separates the text.
	var sign_y: float = _parse_sign_offset(src)
	# Sign: font 26, outlined -> ~35px line height, 3 lines.
	var sign_top: float = 600.0 - sign_y          # SURFACE_Y is 600.0
	var sign_bottom: float = sign_top + 3.0 * 35.0
	# 2888 pool plate: _setup_altar("long", 1720) places it at altar-local
	# (-160, -200) => world y = SURFACE_Y - 200, font 34 -> ~43px tall.
	var plate_top: float = 600.0 - 200.0
	var plate_bottom: float = plate_top + 43.0
	var overlaps: bool = sign_top < plate_bottom and plate_top < sign_bottom
	_check("Fort Knox Assay sign does not overlap the 2888-day pool plate (sign %.0f..%.0f vs plate %.0f..%.0f)"
			% [sign_top, sign_bottom, plate_top, plate_bottom],
		not overlaps, "bands intersect")

## Reads the literal N out of `sign.position = Vector2(<x>, SURFACE_Y - N)`.
func _parse_sign_offset(src: String) -> float:
	var marker := "sign.position = Vector2("
	var i := src.find(marker)
	if i == -1:
		return -1.0
	var seg := src.substr(i, 120)
	var dash := seg.find("SURFACE_Y - ")
	if dash == -1:
		return -1.0
	var tail := seg.substr(dash + 12, 12)
	return float(tail)
	_check("Fort Knox Assay sign wrapped to short lines (was one long unwrapped line)",
		src.find("FORT KNOX ASSAY —\\nWEIGH IT. STAKE IT.\\n100-DAY MINERS ONLY.") != -1)
