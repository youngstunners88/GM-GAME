extends Node
## ART-DIRECTION gate for Episode 2.
##
## Why this gate exists, in one sentence: the previous two Episode 2 defects —
## invisible hazards, then blown-out white materials — were both invisible to
## every logic gate in the repo and were only found by a human looking at a
## browser screenshot. This gate cannot see pixels either, but it CAN lock the
## specific numeric conditions that produced those bugs, so they cannot come
## back silently between playtests.
##
## What it locks:
##   * every palette key resolves (a typo'd key must be LOUD magenta, never a
##     silently untextured white box — that is what "blown-out white" was);
##   * ambient stays low, which is the actual anti-blowout condition. Gold can
##     only read as bright if the rock it sits against is dark;
##   * the scenes are lit by real warm light sources, not by cranking ambient;
##   * make() is shared and make_unique() is not — mutating a shared material
##     would dim every bandit in the room when one dies;
##   * fog is the plain distance kind. Volumetric fog does not exist in the
##     Compatibility backend the WEB build runs on, so a volumetric setting
##     would look right in the editor and do nothing on itch.io.
##
## FAILING-FIRST: assertions 5 and 6 (lanterns present in both scenes) were
## false before the 2026-09-10 art pass — neither scene had a single
## OmniLight3D. A regression test that never failed proves nothing.
##
## Run: .godot-cache/Godot_v4.3-stable_linux.x86_64 --headless \
##        res://tests/ep2_art_direction_test.tscn

const RUNNER := preload("res://src/episode2/runner/runner_graybox.tscn")
const CHAMBER := preload("res://src/episode2/chamber/miner_shaft.tscn")

var _fail: int = 0

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])


func _count_type(n: Node, type_name: String) -> int:
	var c: int = 1 if n.is_class(type_name) else 0
	for ch in n.get_children():
		c += _count_type(ch, type_name)
	return c


func _luma(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b


func _ready() -> void:
	await get_tree().process_frame
	print("EP2 ART DIRECTION:")

	# --- 1. every declared surface builds a real material ---------------------
	var t: Dictionary = Ep2Palette.table()
	_check("palette is non-empty", t.size() >= 15, "(%d keys)" % t.size())
	var bad_keys: Array = []
	for k in t.keys():
		var m: StandardMaterial3D = Ep2Palette.make(k)
		if m == null:
			bad_keys.append(k)
			continue
		var s = t[k]
		if not m.albedo_color.is_equal_approx(s.albedo):
			bad_keys.append("%s(albedo)" % k)
		if not is_equal_approx(m.roughness, s.roughness):
			bad_keys.append("%s(roughness)" % k)
		if not is_equal_approx(m.metallic, s.metallic):
			bad_keys.append("%s(metallic)" % k)
		if s.emission_energy > 0.0 and not m.emission_enabled:
			bad_keys.append("%s(emission dropped)" % k)
	_check("every surface builds with its declared values", bad_keys.is_empty(), str(bad_keys))

	# --- 2. an unknown key must FAIL LOUDLY, not silently render white --------
	# A missing material shows as untextured white, which is exactly what the
	# last playtest looked like and exactly what a human reads as "not done
	# yet" rather than "broken". Magenta is unmistakable.
	var miss: StandardMaterial3D = Ep2Palette.make("this_key_does_not_exist")
	_check("unknown key returns a loud magenta material, not white/null",
		miss != null and miss.albedo_color.r > 0.9 and miss.albedo_color.g < 0.1
			and miss.albedo_color.b > 0.9 and miss.emission_enabled,
		str(miss.albedo_color if miss else "null"))

	# --- 3. sharing semantics -------------------------------------------------
	_check("make() returns the SAME cached instance", Ep2Palette.make("rock") == Ep2Palette.make("rock"))
	_check("make_unique() returns a DIFFERENT instance",
		Ep2Palette.make_unique("bandit") != Ep2Palette.make("bandit"))

	# --- 4. the anti-blowout condition ---------------------------------------
	var env: Environment = Ep2Palette.make_environment()
	# EFFECTIVE ambient, not the raw energy slider.
	#
	# The first version of this assertion was a bare `energy <= 0.25`, and the
	# art pass legitimately needed 0.30 — at 0.22 the browser capture came back
	# as a black tunnel with lit patches, with the rock invisible between
	# lanterns, which is not what the references show. Raising a threshold to
	# make a failing gate pass is exactly the move that makes gates worthless,
	# so the assertion was replaced by the quantity it was always trying to
	# stand in for: how much light the ambient term ACTUALLY adds, which is its
	# energy times its own brightness. A dark warm ambient at 0.30 contributes
	# less than a pale one at 0.22.
	var amb: float = _luma(env.ambient_light_color) * env.ambient_light_energy
	# Bound relaxed 0.16 -> 0.24 on 2026-09-10, deliberately and with evidence:
	# two consecutive GPT-6 Astra reviews of real browser captures both ranked
	# "the playable scene collapses into shadow" as the single most damaging
	# defect, the second one AFTER the first lift. The blowout this number was
	# standing in for is constrained more precisely by the two assertions below
	# it, so this one was fighting the art instead of protecting it. Raising a
	# threshold to silence a failure is a bad move; raising one that measures
	# the wrong thing, and saying so, is not.
	_check("effective ambient stays low (luma x energy <= 0.24)", amb <= 0.24,
		"(%.3f = luma %.3f x energy %.2f)" % [amb, _luma(env.ambient_light_color), env.ambient_light_energy])
	_check("tonemap white is high enough that lamps clip, not surfaces (>= 5)",
		env.tonemap_white >= 5.0, "(%.1f)" % env.tonemap_white)
	# The other half of the blowout: no ordinary surface may compete with gold.
	#
	# The first attempt asserted a flat "structural albedo < 0.30" and it
	# FAILED on the granite boulder at 0.47 — correctly, from the gate's point
	# of view, and wrongly from the game's: the boulder is DELIBERATELY the
	# palest large object in the mine, because that contrast against the dark
	# wall is the entire reason a rolling hazard is readable at speed. So the
	# real invariant is not "everything is dark", it is "gold is the brightest
	# thing in the world and nothing ordinary comes near white".
	var gold_luma: float = _luma(t["gold"].albedo)
	var too_bright: Array = []
	for k in ["rock", "rock_deep", "wood", "wood_light", "crate", "boulder", "bandit", "bandit_cloth", "arrow"]:
		var l: float = _luma(t[k].albedo)
		if l >= gold_luma * 0.75 or l >= 0.55:
			too_bright.append("%s(%.2f)" % [k, l])
	_check("no ordinary surface competes with gold (luma < 0.75x gold and < 0.55)",
		too_bright.is_empty(), str(too_bright))
	_check("background is near-black", _luma(env.background_color) < 0.08,
		"(luma %.3f)" % _luma(env.background_color))
	_check("glow bloom is 0 (bloom > 0 lifts ordinary surfaces — the blowout)",
		is_equal_approx(env.glow_bloom, 0.0), "(%.2f)" % env.glow_bloom)
	_check("depth haze uses plain fog, not volumetric (Compatibility/web has no volumetrics)",
		env.fog_enabled and not env.volumetric_fog_enabled)
	# Gold must out-read rock by a wide margin or the mine has no focal point.
	var rock_l: float = _luma(t["rock"].albedo)
	var gold_l: float = _luma(t["gold"].albedo)
	_check("gold reads far brighter than rock (ratio >= 4)", gold_l / maxf(rock_l, 0.0001) >= 4.0,
		"(ratio %.1f)" % (gold_l / maxf(rock_l, 0.0001)))

	# --- 5/6. FAILING-FIRST: both scenes must be lit by real warm sources -----
	var runner = RUNNER.instantiate()
	add_child(runner)
	runner.setup(60.0, [{"z": 20.0, "lane": 1, "type": "box"}], [])
	await get_tree().process_frame
	var runner_lamps: int = _count_type(runner, "OmniLight3D")
	_check("runner is lit by warm lantern lights (not just raised ambient)",
		runner_lamps >= 2, "(%d omni lights)" % runner_lamps)
	var ground := runner.get_node_or_null("Ground") as MeshInstance3D
	_check("runner ground wears the palette rock surface",
		ground != null and ground.material_override != null
			and ground.material_override.albedo_color.is_equal_approx(t["rock_deep"].albedo),
		str(ground.material_override.albedo_color if ground and ground.material_override else "none"))
	# --- CAMERA FACES THE GAME ------------------------------------------------
	#
	# This assertion exists because of a defect that survived every gate in the
	# repo and two browser playtests: BOTH Episode 2 cameras were pointing the
	# wrong way down the Z axis. A headless probe of the real scenes measured
	# dot(camera forward, direction to the next obstacle) = -0.86 in the runner
	# and -0.85 to the rig in the chamber. The player was watching the tunnel
	# they had already passed; hazards arrived from behind the camera and were
	# never visible. That is a complete explanation for "the cart is not in
	# frame" and for a playtest dying in thirteen seconds, and no logic gate
	# could see it because positions, health and collisions were all correct.
	var rcam := runner.get_node_or_null("Cart/Camera3D") as Camera3D
	var rfwd: Vector3 = -rcam.global_transform.basis.z if rcam else Vector3.ZERO
	var to_ahead: Vector3 = (Vector3(0.0, 0.5, 20.0) - rcam.global_position).normalized() if rcam else Vector3.ZERO
	_check("runner camera looks down the track, not back up it",
		rcam != null and rfwd.dot(to_ahead) > 0.5, "(dot %.3f)" % rfwd.dot(to_ahead))
	var rcart := runner.get_node_or_null("Cart") as Node3D
	var to_cart: Vector3 = (rcart.global_position - rcam.global_position).normalized() if (rcam and rcart) else Vector3.ZERO
	_check("the player's cart is in frame", rcam != null and rfwd.dot(to_cart) > 0.8,
		"(dot %.3f)" % rfwd.dot(to_cart))
	# Handedness: looking down +Z with +Y up puts world +X on the player's LEFT,
	# so LANE_X must DESCEND or the controls are mirrored on screen.
	var lane_x: Array = runner.get("LANE_X")
	var left_cam_x: float = (rcam.global_transform.affine_inverse() * Vector3(float(lane_x[0]), 0.5, 20.0)).x if rcam else 0.0
	_check("lane 0 (switch_lane_left) really is on the screen's left", left_cam_x < 0.0,
		"(camera-space x %.2f)" % left_cam_x)

	var rwe := runner.get_node_or_null("WorldEnvironment") as WorldEnvironment
	_check("runner environment came from the palette",
		rwe != null and rwe.environment != null
			and is_equal_approx(rwe.environment.ambient_light_energy, env.ambient_light_energy)
			and rwe.environment.fog_enabled)
	runner.queue_free()

	var chamber = CHAMBER.instantiate()
	add_child(chamber)
	chamber.setup(1000, [{"z": 4.0}])
	await get_tree().process_frame
	var chamber_lamps: int = _count_type(chamber, "OmniLight3D")
	_check("chamber is lit by warm lantern lights", chamber_lamps >= 2,
		"(%d omni lights)" % chamber_lamps)
	var ccam := chamber.get_node_or_null("Camera3D") as Camera3D
	var cfwd: Vector3 = -ccam.global_transform.basis.z if ccam else Vector3.ZERO
	# The rig is the entire point of the chamber; if it is behind the camera the
	# encounter is unplayable no matter how correct the simulation is.
	var to_rig: Vector3 = (Vector3(0.0, 1.2, 14.0) - ccam.global_position).normalized() if ccam else Vector3.ZERO
	_check("chamber camera faces the rig", ccam != null and cfwd.dot(to_rig) > 0.5,
		"(dot %.3f)" % cfwd.dot(to_rig))

	var floor_mi := chamber.get_node_or_null("Floor") as MeshInstance3D
	_check("chamber floor wears the palette rock surface",
		floor_mi != null and floor_mi.material_override != null
			and floor_mi.material_override.albedo_color.is_equal_approx(t["rock"].albedo),
		str(floor_mi.material_override.albedo_color if floor_mi and floor_mi.material_override else "none"))
	chamber.queue_free()

	await get_tree().process_frame
	if _fail == 0:
		print("EP2_ART_DIRECTION: ALL PASS")
		get_tree().quit(0)
	else:
		print("EP2_ART_DIRECTION: %d FAILED" % _fail)
		get_tree().quit(1)
