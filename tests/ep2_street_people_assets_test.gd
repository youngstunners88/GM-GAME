extends Node
## Import/runtime contract for the Meshy cast (2026-10-22: every person rebuilt from their own T-pose photo, own clip set).
## Behaviour remains covered by ep2_town_people_test / ep2_town_autonomy_test.
var failures: int = 0
var checks: int = 0

func check(label: String, passed: bool) -> void:
	checks += 1
	if not passed:
		failures += 1
		print("[FAIL] ", label)

func _ready() -> void:
	var cast: Array = Ep2TownPeople.ROSTER.duplicate(true)
	cast.append({"id": "jail_prisoner", "file": "prisoner_accomplice.glb", "h": GoldTownChamber.ACCOMPLICE_HEIGHT})
	for row in cast:
		var id: String = str(row["id"])
		var folk := Ep2TownFolk.new()
		folk.looping_clips.assign(Ep2TownPeople.LOOPING_CLIPS)
		add_child(folk)
		check(id + " imported GLB loads", folk.setup(Ep2Extras.PEOPLE_DIR + str(row["file"]), float(row["h"]), Color.WHITE))
		check(id + " authored clips bind", folk.has_clips())
		var rigs: Array[Node] = folk.model.find_children("*", "Skeleton3D", true, false)
		check(id + " one humanoid rig (Meshy, >= 20 joints)", rigs.size() == 1 and (rigs[0] as Skeleton3D).get_bone_count() >= 20)
		var mesh_count: int = 0
		for node in folk.model.find_children("*", "MeshInstance3D", true, false):
			var instance := node as MeshInstance3D
			for surface in instance.mesh.get_surface_count():
				mesh_count += 1
				var arrays: Array = instance.mesh.surface_get_arrays(surface)
				var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				if arrays[Mesh.ARRAY_TEX_UV] == null:
					check(id + " UV channel exists after import", false)
					continue
				var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
				check(id + " UVs survive Godot import", uv.size() == positions.size() and uv.size() > 0)
				var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
				check(id + " skin arrays survive import", weights.size() == positions.size() * 4)
				var normalized: bool = true
				if weights.size() == positions.size() * 4:
					for index in positions.size():
						var total: float = weights[index * 4] + weights[index * 4 + 1] + weights[index * 4 + 2] + weights[index * 4 + 3]
						if absf(total - 1.0) > .002: normalized = false
				check(id + " imported weights normalized", normalized)
				var material := instance.mesh.surface_get_material(surface) as BaseMaterial3D
				check(id + " portable Standard/ORM material", material != null)
				if material != null:
					check(id + " real albedo image", material.albedo_texture != null and material.albedo_texture.get_width() >= 512)
					check(id + " tangent normal image", material.normal_enabled and material.normal_texture != null)
					var pbr_maps: bool = false
					if material is StandardMaterial3D:
						pbr_maps = material.roughness_texture != null and material.metallic_texture != null
					elif material is ORMMaterial3D:
						pbr_maps = material.orm_texture != null
					check(id + " image-backed material response", pbr_maps)
		check(id + " one character draw surface", mesh_count == 1)
		if id != "jail_prisoner":
			check(id + " walk clip has a measured stride speed", float(row.get("walk_speed", 0.0)) > 0.4 and float(row.get("walk_speed", 0.0)) < 2.2)
		if folk._anim != null and rigs.size() == 1:
			var skeleton := rigs[0] as Skeleton3D
			var rest_extent: float = 0.0
			for bone in skeleton.get_bone_count():
				rest_extent = maxf(rest_extent, skeleton.get_bone_global_rest(bone).origin.length())
			folk._anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			var clips: Array = ["Idle", "Walk", "Greet", "Observe", "Rest", "Talk", "Inspect", "Alert"]
			if id in Ep2TownPeople.PLAYERS: clips.append("Play")
			for clip in clips:
				check(id + " clip " + clip, folk.play_clip(clip))
				var duration: float = folk._anim.current_animation_length
				check(id + " positive clip duration " + clip, duration > 0.0)
				var finite: bool = true
				for sample in 13:
					folk._anim.seek(duration * float(sample) / 12.0, true)
					for bone in skeleton.get_bone_count():
						var pose: Transform3D = skeleton.get_bone_global_pose(bone)
						# scale-free: a pose may not fly further than 3x the rig's own rest extent (Meshy rigs work in centimetres)
						if not pose.is_finite() or pose.origin.length() > 3.0 * rest_extent: finite = false
				check(id + " finite engine poses " + clip, finite)
				if clip in Ep2TownPeople.LOOPING_CLIPS:
					folk._anim.seek(0, true)
					folk._anim.advance(duration * 2.25)
					check(id + " sustained cyclic animation " + clip, folk._anim.is_playing() and folk._anim.current_animation_position < duration)
		folk.queue_free()
		await get_tree().process_frame
	if failures == 0:
		print("EP2_STREET_PEOPLE_ASSETS: ALL PASS (", checks, " checks)")
	else:
		print("EP2_STREET_PEOPLE_ASSETS: ", failures, " failures / ", checks)
	get_tree().quit(1 if failures > 0 else 0)
