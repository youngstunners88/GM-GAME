extends Node
## Gate for src/level/stage2_revolver_reveal.gd — the golden revolver reveal
## beat inserted between the Stage 2 boss-defeat video and the Stage 3
## transition (founder brief, 2026-09-16). Proves it actually plays to
## completion, spawns the revolver sprite with the right texture, and frees
## itself — the same standard stage2_defeat_cutscene_test.gd holds the video
## cutscene to.
##
## Run: .godot-cache/Godot_v4.3-stable_linux.x86_64 --headless \
##        res://tests/stage2_revolver_reveal_test.tscn

const REVEAL := preload("res://src/level/stage2_revolver_reveal.gd")
const REVOLVER_ART := "res://src/assets/sprites/sprite_item_golden_revolver.png"

var _fail: int = 0

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _ready() -> void:
	await get_tree().process_frame
	print("STAGE2 REVOLVER REVEAL:")
	_check("revolver art exists on disk", ResourceLoader.exists(REVOLVER_ART))

	var reveal: CanvasLayer = REVEAL.new()
	add_child(reveal)
	var start_ms := Time.get_ticks_msec()

	var saw_revolver_sprite := false
	var revolver_texture_path := ""

	reveal.play()

	while is_instance_valid(reveal):
		for c in reveal.get_children():
			if c is Sprite2D and c.texture != null:
				saw_revolver_sprite = true
				revolver_texture_path = c.texture.resource_path
		await get_tree().create_timer(0.1, true, false, true).timeout

	var elapsed := (Time.get_ticks_msec() - start_ms) / 1000.0
	_check("finishes", true)
	_check("ran a plausible, bounded duration (took %.1fs)" % elapsed,
		elapsed > 1.5 and elapsed < 8.0,
		"took %.1fs — too short means it skipped the beat; too long means it hung" % elapsed)
	_check("spawned a Sprite2D using the real founder-art revolver texture",
		saw_revolver_sprite and revolver_texture_path == REVOLVER_ART,
		"(saw_sprite=%s, texture_path=%s)" % [saw_revolver_sprite, revolver_texture_path])

	await get_tree().process_frame
	await get_tree().process_frame
	_check("frees itself after finishing", not is_instance_valid(reveal))

	print("STAGE2_REVOLVER_REVEAL: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)
