extends Node
## Regression test for "Stage 2 boss is invisible".
##
## Instantiates every boss and asserts the things that actually make a sprite
## render: the BossSprite child exists, it resolved a Texture2D, it is visible
## up the whole parent chain, and its alpha is not zero. Comparing all three
## bosses in one run is the point — a property that differs only on the
## Distributor is the bug, and a property they share is not.
##
## Run: godot --headless res://tests/boss_visibility_test.tscn

const BOSSES := {
	"auditor (L1)": "res://src/boss/auditor.tscn",
	"distributor (L2)": "res://src/boss/distributor.tscn",
	"claim_jumper (L3)": "res://src/boss/claim_jumper.tscn",
}

var _failures: int = 0

func _ready() -> void:
	for label in BOSSES:
		await _inspect(label, BOSSES[label])
	if _failures == 0:
		print("BOSS_VISIBILITY: ALL PASS")
		get_tree().quit(0)
	else:
		print("BOSS_VISIBILITY: %d FAILURE(S)" % _failures)
		get_tree().quit(1)

func _check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("    [PASS] %s" % label)
	else:
		_failures += 1
		print("    [FAIL] %s %s" % [label, detail])

func _inspect(label: String, path: String) -> void:
	print("%s:" % label)
	var scene: PackedScene = load(path)
	if scene == null:
		_check("scene loads", false, path)
		return
	var boss := scene.instantiate()
	add_child(boss)
	# One physics frame so _ready has run all the way down the tree.
	await get_tree().process_frame

	# THE GATE THAT MATTERS. A GDScript parse error does not stop the scene from
	# instantiating — Godot logs it and attaches NO script, so the boss becomes
	# an inert body with no AI, no health bar and no death. Every visual
	# assertion below still passed happily while bosses 2 and 3 were in exactly
	# that state. Check the script first, or the rest of this file is theatre.
	_check("script attached (parse succeeded)", boss.get_script() != null,
		"script failed to compile — boss has no AI at all")
	_check("inherited EnemyBase API present", boss.has_method("take_damage"))
	_check("boss registered in 'boss' group", boss.is_in_group("boss"))
	_check("health initialised above zero", int(boss.get("health")) > 0,
		str(boss.get("health")))

	var visual := boss.get_node_or_null("ColorRect")
	_check("BossSprite node present", visual != null)
	if visual == null:
		boss.queue_free()
		return

	# The Sprite2D is built in code by BossSprite._ready().
	var spr: Sprite2D = null
	for child in visual.get_children():
		if child is Sprite2D:
			spr = child
			break
	_check("Sprite2D created", spr != null)
	if spr == null:
		boss.queue_free()
		return

	_check("texture resolved", spr.texture != null,
		"texture_path='%s'" % str(visual.get("texture_path")))
	_check("sprite visible", spr.visible and visual.visible and boss.visible)
	_check("alpha not zero",
		spr.modulate.a > 0.0 and visual.modulate.a > 0.0 and boss.modulate.a > 0.0,
		"spr=%.2f visual=%.2f boss=%.2f" % [
			spr.modulate.a, visual.modulate.a, boss.modulate.a])
	_check("self_modulate alpha not zero", spr.self_modulate.a > 0.0,
		str(spr.self_modulate))
	_check("scale non-degenerate",
		absf(spr.scale.x) > 0.001 and absf(spr.scale.y) > 0.001, str(spr.scale))

	if spr.texture != null:
		var on_screen := spr.texture.get_size() * spr.scale
		_check("rendered size >= 32px", on_screen.y >= 32.0, str(on_screen))

	print("      (z_index=%d  pos=%s  scale=%s)" % [
		spr.z_index, str(spr.position), str(spr.scale)])
	boss.queue_free()
	await get_tree().process_frame
