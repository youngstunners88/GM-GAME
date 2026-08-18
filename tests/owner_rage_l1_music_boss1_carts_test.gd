extends Node2D
## Regression gate for PROMPT_LEVEL1_MUSIC_ORDER_BOSS1_SIZE_CARTS_CHASE.md
## (2026-08-18) — covers what the OWNER_RAGE + LEVEL1_MUSIC residuals
## actually needed proven, after another session's independent work on
## master both fixed some real bugs and regressed others:
##
##   1. Level 1 music must deterministically open on the founder-supplied
##      "always first" track, not a coin flip. Root cause:
##      `_play_next_in_playlist()` picked `candidates[randi() % ...]`
##      UNCONDITIONALLY — the old `fade_in` bool never controlled track
##      choice. Fixed with a real `force_first` param.
##   2. level01_theme_alt.ogg (the founder's "remove this song" track) is
##      gone from both the project and Level 1's playlist array.
##   3. Auditor (boss1) BODY raised 168 -> 220 (was the visible outlier next
##      to Distributor 240 / Claim Jumper 280) with hurtbox scaled by the
##      same ratio, not hand-tuned independently.
##   4. Mine carts render real Sprite2D art again (a same-day session's
##      independent "carts" fix only repositioned the old bare ColorRect
##      Y-coordinate, never restored the sprite/trigger rewrite).
##   5. big_axe scale/damage restored to the previously-proven values after
##      the same session's impact-feedback work silently reset them.
##
## Run: godot --headless res://tests/owner_rage_l1_music_boss1_carts_test.tscn

const MINE_CART := preload("res://src/level/mine_cart.tscn")
const AUDITOR := preload("res://src/boss/auditor.tscn")

var _fail: int = 0

func _ready() -> void:
	await get_tree().process_frame
	print("OWNER RAGE / L1 MUSIC / BOSS1 / CARTS:")
	await _check_music_force_first()
	_check_alt_song_gone()
	_check_auditor_size()
	_check_mine_cart_real_art()
	_check_axe_constants_restored()
	print("OWNER_RAGE_L1_MUSIC_BOSS1_CARTS: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

## The actual behavioural proof: call play_playlist with force_first several
## times in a row and confirm the resolved first track is ALWAYS paths[0],
## never a random pick. Pre-fix, this would pass only ~1/3 of the time (or
## whatever the array size implies) — a flaky test is exactly the bug.
func _check_music_force_first() -> void:
	var paths := [
		"res://src/assets/music/level01_theme_always_first.mp3",
		"res://src/assets/music/level01_theme_oxbow.mp3",
		"res://src/assets/music/level01_theme.ogg",
	]
	var all_first := true
	for _i in range(8):
		AudioManager.play_playlist(paths, true)
		await get_tree().process_frame
		if AudioManager._last_track != paths[0]:
			all_first = false
	_check("play_playlist(force_first=true) always resolves paths[0], not a random pick",
		all_first, "AudioManager._last_track=%s" % AudioManager._last_track)
	AudioManager._stop_music()

func _check_alt_song_gone() -> void:
	_check("level01_theme_alt.ogg deleted from the project",
		not ResourceLoader.exists("res://src/assets/music/level01_theme_alt.ogg"))
	var src := FileAccess.get_file_as_string("res://src/level/level_01_smoke_realm.gd")
	_check("level_01_smoke_realm.gd's playlist no longer references level01_theme_alt.ogg",
		src.find("\"res://src/assets/music/level01_theme_alt.ogg\"") == -1)
	_check("level01_theme_oxbow.mp3 (the founder's 'also feature' track) is wired",
		src.find("level01_theme_oxbow.mp3") != -1)
	_check("level01_theme_always_first.mp3 is wired with force_first=true",
		src.find("level01_theme_always_first.mp3") != -1 and src.find("], true)") != -1)

func _check_auditor_size() -> void:
	var boss: Node = AUDITOR.instantiate()
	add_child(boss)
	# BODY is a const, not exposed via get() — read the actual collision
	# shape instead, which is the real proof of on-screen/physical size.
	var col := boss.get_node("CollisionShape2D") as CollisionShape2D
	var shape := col.shape as RectangleShape2D
	_check("Auditor body size raised above the old 168 outlier (>=220)",
		shape.size.x >= 220.0 and shape.size.y >= 220.0,
		"size=%s" % str(shape.size))
	_check("Auditor still smaller than Distributor (240) — stage escalation intact",
		shape.size.x < 240.0, "size.x=%.0f" % shape.size.x)
	boss.queue_free()
	await get_tree().process_frame

func _check_mine_cart_real_art() -> void:
	var cart: Node = MINE_CART.instantiate()
	cart.cart_type = 0
	cart.global_position = Vector2(500, 300)
	add_child(cart)
	await get_tree().process_frame
	await get_tree().process_frame
	var sprite_child: Sprite2D = null
	for child in cart.get_children():
		if child is Sprite2D:
			sprite_child = child
	_check("mine cart renders real Sprite2D art (not a same-session-regressed bare ColorRect)",
		sprite_child != null and sprite_child.texture != null
			and sprite_child.texture.resource_path.find("minecart") != -1,
		"sprite=%s" % (sprite_child.texture.resource_path if sprite_child and sprite_child.texture else "null"))
	cart.queue_free()
	await get_tree().process_frame

func _check_axe_constants_restored() -> void:
	var src := FileAccess.get_file_as_string("res://src/combat/axe.gd")
	var big_scale := 0.0
	var big_damage := 0
	for line in src.split("\n"):
		var t := line.strip_edges()
		if t.begins_with("const BIG_SCALE"):
			big_scale = float(t.split(":=")[1])
		elif t.begins_with("const BIG_DAMAGE"):
			big_damage = int(t.split(":=")[1])
	_check("big_axe BIG_SCALE restored to the proven value (>=2.5, was reset to 1.95)",
		big_scale >= 2.5, "BIG_SCALE=%.2f" % big_scale)
	_check("big_axe BIG_DAMAGE restored to the proven value (>=8, was reset to 5)",
		big_damage >= 8, "BIG_DAMAGE=%d" % big_damage)
