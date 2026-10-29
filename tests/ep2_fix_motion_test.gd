extends Node
var checks := 0
var failed := 0

func check(label: String, ok: bool) -> void:
	checks += 1
	if not ok: failed += 1
	print("[PASS] " + label if ok else "[FAIL] " + label)

func measure(folk: Ep2TownFolk, clip: String) -> void:
	var ap: AnimationPlayer = folk.anim_player()
	var skel: Skeleton3D = folk.model.find_children("*", "Skeleton3D", true, false)[0]
	var feet: Array = [Ep2RanchPose._find(skel, "LeftFoot"), Ep2RanchPose._find(skel, "RightFoot")]
	var data: Dictionary = Ep2GroundedWalk.config
	var duration: float = float(data.cycle_seconds)
	var speed: float = float(data.reference_speed)
	var max_contact: float = 0.0
	var max_slide: float = 0.0
	var max_lift: float = 0.0
	var last: Array = [Vector3.ZERO, Vector3.ZERO]
	var stance_before := [false, false]
	ap.play(clip)
	for frame in 257:
		var time: float = float(frame) / 128.0 * duration
		folk.position.z = speed * time
		ap.seek(fposmod(time, duration), true)
		ap.advance(0.0)
		skel.force_update_all_bone_transforms()
		for i in 2:
			var phase: float = fposmod(time / duration + i * 0.5, 1.0)
			var stance: bool = phase < float(data.stance_fraction)
			var foot: Vector3 = skel.global_transform * skel.get_bone_global_pose(feet[i]).origin
			var ground: float = (skel.global_transform * skel.get_bone_global_rest(feet[i]).origin).y
			if stance:
				max_contact = maxf(max_contact, absf(foot.y - ground))
				if stance_before[i]: max_slide = maxf(max_slide, Vector2(foot.x-last[i].x, foot.z-last[i].z).length())
			max_lift = maxf(max_lift, foot.y - ground)
			last[i] = foot
			stance_before[i] = stance
	print("CONTACT %s %s error=%.6f slide/frame=%.6f lift=%.6f" % [folk.name, clip, max_contact, max_slide, max_lift])
	check(str(folk.name) + " " + clip + " planted contact < 15 mm", max_contact < 0.015)
	check(str(folk.name) + " " + clip + " stance sliding < 6 mm/frame", max_slide < 0.006)
	check(str(folk.name) + " " + clip + " feet clear ground on swing", max_lift > 0.045 and max_lift < 0.11)
	folk.position.z = 0.0

func _ready() -> void:
	for row in [["Sheriff", GoldTownChamber.SHERIFF_MODEL, GoldTownChamber.SHERIFF_HEIGHT], ["Utah", Ep2Extras.UTAH, GoldTownChamber.UTAH2_HEIGHT]]:
		var folk := Ep2TownFolk.new()
		folk.name = row[0]
		add_child(folk)
		folk.setup(row[1], row[2])
		check(str(folk.name) + " has a real skeleton and animated gait", Ep2GroundedWalk.install(folk) and folk.anim_player().has_animation("GroundedWalk"))
		check(str(folk.name) + " has no extra whole-body bounce", not folk.procedural_bob)
		measure(folk, "GroundedWalk")
		if folk.anim_player().has_animation("GroundedCarry"): measure(folk, "GroundedCarry")
		folk.free()
	print("EP2_FIX_MOTION: %d checks, %d failed" % [checks, failed])
	get_tree().quit(failed)
