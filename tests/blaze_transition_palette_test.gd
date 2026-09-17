extends Node
## FOUNDER, 2026-09-17: "There's also this green blemish shit that is [in]
## the blaze rush of level 2 and after exiting it ends up on the stage screen
## too!!!" and "The same green shit piece blemishes from the previous blaze
## rush is here" (Level 3's Blaze Rush).
##
## ROOT CAUSE, confirmed by capturing the real transition mid-dissolve in a
## browser: entering/exiting Blaze Rush hardcoded `SceneRouter.Transition.
## SMOKE` for EVERY realm. The smoke pattern's tint is intentionally
## weed-green/purple (see transition_wipe.gdshader — "the Smoke Realm
## signature") and reads correctly ONLY over Level 1. Flashed over Level 2's
## cyan Crystal Caverns or Level 3's amber Gold Rush canyon, that same green/
## purple cloud dissolve looks exactly like an unrelated smear or leftover
## overlay, which is what the founder is describing. Nothing was leaking or
## stuck — the dissolve completes correctly, it was just the wrong colour
## for the scene, every single time (confirmed on both entry and exit).
##
## Fix: blaze_portal.gd (entry) and blaze_rush.gd (exit) now both route
## through SceneRouter.blaze_transition_for_level(level_index), which this
## gate pins down: 1->SMOKE, 2->DIAMOND (cyan, already existed for the vault
## doors and fits Crystal Caverns), 3->GOLD (new warm amber pattern added to
## the shader, matching the Gold Rush canyon).
##
## Run: .godot-cache/Godot_v4.3-stable_linux.x86_64 --headless
##        res://tests/blaze_transition_palette_test.tscn

var _fail: int = 0

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _ready() -> void:
	print("BLAZE TRANSITION PALETTE:")

	_check("Level 1 (actual Smoke Realm) keeps the SMOKE pattern",
		SceneRouter.blaze_transition_for_level(1) == SceneRouter.Transition.SMOKE,
		"(got %s)" % SceneRouter.blaze_transition_for_level(1))
	_check("Level 2 (Crystal Caverns) uses DIAMOND, not SMOKE",
		SceneRouter.blaze_transition_for_level(2) == SceneRouter.Transition.DIAMOND,
		"(got %s) — a green/purple wipe over a cyan crystal cave is the founder's exact complaint" %
			SceneRouter.blaze_transition_for_level(2))
	_check("Level 3 (Gold Rush) uses GOLD, not SMOKE",
		SceneRouter.blaze_transition_for_level(3) == SceneRouter.Transition.GOLD,
		"(got %s) — a green/purple wipe over an amber canyon is the founder's exact complaint" %
			SceneRouter.blaze_transition_for_level(3))

	# The shader itself: pattern 2 ("gold") must actually be warm-toned, not a
	# silent fallback to the green/purple smoke branch (an off-by-one in the
	# shader's if/else chain would look identical in GDScript but wrong on
	# screen — this is why the check inspects the real .gdshader source, not
	# just the enum wiring above).
	var shader_src := FileAccess.get_file_as_string("res://src/effects/transition_wipe.gdshader")
	_check("shader file exists and is non-empty", shader_src.length() > 0)
	_check("shader has a THIRD pattern branch (pattern == 1) ... else (2)",
		shader_src.contains("pattern == 1") and shader_src.contains("else {"),
		"gold must be its own else-branch, not folded into the smoke/diamond ones")
	_check("the gold branch's tint is warm (does not reuse the smoke green/purple constants)",
		shader_src.contains("0.85, 0.55, 0.15") and not (
			shader_src.count("0.16, 0.34, 0.20") > 1 or shader_src.count("0.30, 0.16, 0.40") > 1),
		"gold tint constant not found, or the smoke tint appears more than once (reused)")

	# The two call sites must actually USE the helper, not a hardcoded SMOKE
	# constant — the exact regression that caused this bug in the first place.
	var portal_src := FileAccess.get_file_as_string("res://src/dashmode/blaze_portal.gd")
	var rush_src := FileAccess.get_file_as_string("res://src/dashmode/blaze_rush.gd")
	_check("blaze_portal.gd (entry) no longer hardcodes Transition.SMOKE",
		not portal_src.contains("SceneRouter.Transition.SMOKE"),
		"a hardcoded SMOKE here is exactly the bug that shipped this defect")
	_check("blaze_portal.gd (entry) calls blaze_transition_for_level",
		portal_src.contains("SceneRouter.blaze_transition_for_level("))
	_check("blaze_rush.gd (exit) no longer hardcodes Transition.SMOKE",
		not rush_src.contains("SceneRouter.Transition.SMOKE"),
		"a hardcoded SMOKE here is exactly the bug that shipped this defect")
	_check("blaze_rush.gd (exit) calls blaze_transition_for_level",
		rush_src.contains("SceneRouter.blaze_transition_for_level("))

	print("BLAZE_TRANSITION_PALETTE: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)
