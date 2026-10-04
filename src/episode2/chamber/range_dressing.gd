class_name RangeDressing
extends RefCounted
## Inferno Bull's TARGET PRACTICE range inside the hideout (founder 2026-10-04: "build out the target practice area
## ... Inferno must lead you there, conduct a demo and then have the player play"). Skill ep2-range-lesson.
##
## This file is the VISUAL owner of the range; `SmeltingFacilityChamber` owns the GAMEPLAY and only talks to it
## through this contract, so the range can be restyled without touching the lesson logic:
##   * `LINE`            where Lil Blunt stands to shoot (the firing line), on the floor.
##   * `BULL_LINE`       where Inferno stands for his demonstration, beside the line.
##   * `TARGET_SPOTS`    where the three steel targets stand (centre of each plate); near, mid, far.
##   * `build(parent, timber)` -> {"targets": Array[MeshInstance3D] (one plate each, same order as TARGET_SPOTS),
##                                 "blockers": Array of [Vector2, radius], "line": Vector3}
##   * `set_target_state(plate, broken)` the plate's hit/standing look; the gameplay calls it every time it syncs.
##   * `lane_clear` is the free strip a shot travels down; nothing may be built inside it.

const LINE := Vector3(-4.2, 0.0, -5.8)
const BULL_LINE := Vector3(-2.7, 0.0, -5.8)
const LANE_X := -4.2
const PLATE_UP_Y := 1.15
## near / mid / far: 5.8 m, 8.8 m, 11.8 m from the firing line.
const TARGET_SPOTS := [Vector3(-4.2, PLATE_UP_Y, 0.0), Vector3(-4.2, PLATE_UP_Y, 3.0), Vector3(-4.2, PLATE_UP_Y, 6.0)]
const PLATE_RADIUS := 0.34


## Builds the range under `parent` (the facility's visuals node). Returns the contract dictionary.
static func build(parent: Node3D, timber: Material) -> Dictionary:
	var targets: Array = []
	var blockers: Array = []
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.13, 0.11, 0.10)
	iron.metallic = 0.7
	iron.roughness = 0.5
	for i in TARGET_SPOTS.size():
		var spot: Vector3 = TARGET_SPOTS[i]
		# post
		var post := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.05
		pm.bottom_radius = 0.06
		pm.height = spot.y
		post.mesh = pm
		post.material_override = iron
		post.position = Vector3(spot.x, spot.y * 0.5, spot.z)
		parent.add_child(post)
		# steel plate, painted rings so a hit and a miss are both readable
		var plate := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = PLATE_RADIUS
		cm.bottom_radius = PLATE_RADIUS
		cm.height = 0.06
		cm.radial_segments = 28
		plate.mesh = cm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.9, 0.55, 0.12)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.45, 0.12)
		mat.emission_energy_multiplier = 0.35
		plate.material_override = mat
		plate.rotation = Vector3(PI * 0.5, 0.0, 0.0)          # face the firing line (-Z)
		plate.position = Vector3(spot.x, spot.y + 0.3, spot.z)
		parent.add_child(plate)
		targets.append(plate)
		blockers.append([Vector2(spot.x, spot.z), 0.5])
	# marked lane + firing line
	var lane_mat := StandardMaterial3D.new()
	lane_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lane_mat.albedo_color = Color(1.0, 0.62, 0.15, 1.0)
	var lane := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.12, 0.02, 12.0)
	lane.mesh = bm
	lane.material_override = lane_mat
	lane.position = Vector3(LANE_X, 0.015, 0.2)
	parent.add_child(lane)
	var line := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(1.6, 0.02, 0.1)
	line.mesh = lm
	line.material_override = lane_mat
	line.position = Vector3(LINE.x, 0.02, LINE.z + 0.6)
	parent.add_child(line)
	var sign := Label3D.new()
	sign.text = "TARGET PRACTICE"
	sign.font_size = 56
	sign.pixel_size = 0.004
	sign.modulate = Color(1.0, 0.75, 0.3)
	sign.outline_size = 12
	sign.position = Vector3(LANE_X, 2.6, LINE.z - 0.2)
	parent.add_child(sign)
	return {"targets": targets, "blockers": blockers, "line": LINE}


## Standing plates glow; a hit plate swings back and goes dark.
static func set_target_state(plate: MeshInstance3D, broken: bool) -> void:
	if plate == null or not is_instance_valid(plate):
		return
	plate.rotation = Vector3(PI * 0.5 + (0.9 if broken else 0.0), 0.0, 0.0)
	var m: StandardMaterial3D = plate.material_override as StandardMaterial3D
	if m:
		m.albedo_color = Color(0.2, 0.17, 0.15) if broken else Color(0.9, 0.55, 0.12)
		m.emission_energy_multiplier = 0.0 if broken else 0.35
