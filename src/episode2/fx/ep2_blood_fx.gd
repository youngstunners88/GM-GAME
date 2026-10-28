class_name Ep2BloodFx
extends RefCounted
## Restrained blood for the Compatibility renderer: short particle spurts, surface-following
## stains, and flat drying pools. All positions and directions passed to these helpers are
## world-space. No decals, shaders, image files, autoloads, or per-frame manager are needed.

const FRESH: Color = Color(0.68, 0.018, 0.024, 1.0)
const STAIN_WET: Color = Color(0.48, 0.012, 0.016, 0.88)
const STAIN_DRY: Color = Color(0.30, 0.006, 0.009, 0.94)
const POOL_WET: Color = Color(0.44, 0.009, 0.013, 0.90)
const POOL_DRY: Color = Color(0.26, 0.005, 0.008, 0.96)
const DRY_SECONDS: float = 20.0

static var _splat: ImageTexture = null


## A one-shot spurt of small dark-red droplets and a faint mist. The root frees itself
## after 1.2 seconds; at man size the droplets travel less than half a metre forward.
static func spurt(parent: Node3D, at: Vector3, dir: Vector3, size: float = 1.0) -> Node3D:
	var s: float = maxf(size, 0.1)
	var d: Vector3 = dir.normalized() if dir.length_squared() > 0.000001 else Vector3.FORWARD
	var root := Node3D.new()
	root.name = "BloodSpurt"
	parent.add_child(root)
	if root.is_inside_tree():
		root.top_level = true
		root.global_transform = Transform3D(Basis.IDENTITY, at)
	else:
		root.position = at

	var drop_mesh := SphereMesh.new()
	drop_mesh.radius = 0.006 * s
	drop_mesh.height = 0.012 * s
	drop_mesh.radial_segments = 6
	drop_mesh.rings = 3
	var drop_mat := StandardMaterial3D.new()
	drop_mat.albedo_color = FRESH
	drop_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop_mat.roughness = 0.34
	var drops := CPUParticles3D.new()
	drops.name = "Droplets"
	drops.amount = 16
	drops.lifetime = 0.52
	drops.lifetime_randomness = 0.22
	drops.one_shot = true
	drops.explosiveness = 1.0
	drops.randomness = 0.3
	drops.local_coords = false
	drops.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	drops.emission_sphere_radius = 0.008 * s
	drops.direction = d
	drops.spread = 16.0
	drops.gravity = Vector3(0.0, -4.0, 0.0)
	drops.initial_velocity_min = 0.32 * sqrt(s)
	drops.initial_velocity_max = 0.68 * sqrt(s)
	drops.scale_amount_min = 0.7
	drops.scale_amount_max = 1.25
	drops.mesh = drop_mesh
	drops.material_override = drop_mat
	drops.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(drops)

	var mist_mesh := QuadMesh.new()
	mist_mesh.size = Vector2.ONE * (0.065 * s)
	var mist_mat := StandardMaterial3D.new()
	mist_mat.albedo_color = Color(0.25, 0.012, 0.017, 0.16)
	mist_mat.albedo_texture = _splat_texture()
	mist_mat.roughness = 1.0
	mist_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mist_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mist_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mist_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var mist := CPUParticles3D.new()
	mist.name = "Mist"
	mist.amount = 4
	mist.lifetime = 0.26
	mist.one_shot = true
	mist.explosiveness = 1.0
	mist.local_coords = false
	mist.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	mist.emission_sphere_radius = 0.012 * s
	mist.direction = d
	mist.spread = 24.0
	mist.gravity = Vector3.ZERO
	mist.initial_velocity_min = 0.08 * sqrt(s)
	mist.initial_velocity_max = 0.20 * sqrt(s)
	mist.scale_amount_min = 0.7
	mist.scale_amount_max = 1.4
	mist.mesh = mist_mesh
	mist.material_override = mist_mat
	mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mist)
	drops.emitting = true
	mist.emitting = true
	if root.is_inside_tree():
		var cleanup: Tween = root.create_tween()
		cleanup.tween_interval(1.2)
		cleanup.tween_callback(root.queue_free)
	return root


## A small irregular stain facing `normal`, four millimetres off the wound. On a rig it is
## attached to the closest torso-like bone (or the closest bone if the rig has unusual names),
## so it follows both the skeleton and the body's fall. Without a rig it follows `body`.
static func stain(body: Node3D, at: Vector3, normal: Vector3, size: float = 1.0) -> Node3D:
	var n: Vector3 = normal.normalized() if normal.length_squared() > 0.000001 else Vector3.FORWARD
	var mark := MeshInstance3D.new()
	mark.name = "BloodStain"
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * (0.15 * maxf(size, 0.1))
	mark.mesh = quad
	mark.material_override = _splat_material(STAIN_WET, 0.30)
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var desired := Transform3D(_quad_basis(n), at + n * 0.004)
	var chosen: Array = _nearest_torso(body, at)
	if not chosen.is_empty():
		var skel: Skeleton3D = chosen[0]
		var bone_idx: int = int(chosen[1])
		var attachment := BoneAttachment3D.new()
		attachment.name = "StainBoneAttachment"
		skel.add_child(attachment)
		attachment.bone_name = skel.get_bone_name(bone_idx)
		attachment.add_child(mark)
		# BoneAttachment3D's world transform is the skeleton transform times this global pose.
		# Computing against it now also compensates for a scaled GLB without waiting a frame.
		mark.transform = _bone_world(skel, bone_idx).affine_inverse() * desired
	else:
		body.add_child(mark)
		if mark.is_inside_tree():
			mark.global_transform = desired
		else:
			mark.transform = desired
	if mark.is_inside_tree():
		var dry: Tween = mark.create_tween()
		dry.tween_property(mark.material_override, "albedo_color", STAIN_DRY, DRY_SECONDS)
	return mark


## A glossy, soft-edged pool lying horizontally 12 mm above `at_ground`. Its local X/Y
## scale is the current radius, growing with an ease-out from 0.08 m to `radius`.
static func pool(parent: Node3D, at_ground: Vector3, radius: float, grow_s: float = 6.0) -> Node3D:
	var r: float = maxf(radius, 0.01)
	var start: float = minf(0.08, r)
	var mark := MeshInstance3D.new()
	mark.name = "BloodPool"
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	mark.mesh = quad
	mark.material_override = _splat_material(POOL_WET, 0.18)
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mark)
	var flat := Basis(Vector3.RIGHT, -PI * 0.5)
	if mark.is_inside_tree():
		mark.top_level = true
		mark.global_transform = Transform3D(flat, at_ground + Vector3(0.0, 0.012, 0.0))
	else:
		mark.transform = Transform3D(flat, at_ground + Vector3(0.0, 0.012, 0.0))
	mark.scale = Vector3(start, start, 1.0)
	if mark.is_inside_tree():
		var grow: Tween = mark.create_tween()
		grow.tween_property(mark, "scale", Vector3(r, r, 1.0), maxf(grow_s, 0.01)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		var dry: Tween = mark.create_tween()
		dry.tween_property(mark.material_override, "albedo_color", POOL_DRY, DRY_SECONDS)
	return mark


static func _splat_material(color: Color, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = _splat_texture()
	mat.roughness = roughness
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	return mat


static func _quad_basis(normal: Vector3) -> Basis:
	var up: Vector3 = Vector3.UP
	if absf(normal.dot(up)) > 0.96:
		up = Vector3.FORWARD
	# QuadMesh's front is +Z; Basis.looking_at aims -Z at its argument.
	return Basis.looking_at(-normal, up)


static func _bone_world(skel: Skeleton3D, bone_idx: int) -> Transform3D:
	var pose: Transform3D = skel.get_bone_global_pose(bone_idx)
	return skel.global_transform * pose if skel.is_inside_tree() else skel.transform * pose


static func _nearest_torso(body: Node3D, at: Vector3) -> Array:
	var best_skel: Skeleton3D = null
	var best_bone: int = -1
	var best_d: float = INF
	var any_skel: Skeleton3D = null
	var any_bone: int = -1
	var any_d: float = INF
	for node in body.find_children("*", "Skeleton3D", true, false):
		var skel: Skeleton3D = node as Skeleton3D
		for i in skel.get_bone_count():
			var d: float = _bone_world(skel, i).origin.distance_squared_to(at)
			if d < any_d:
				any_d = d
				any_skel = skel
				any_bone = i
			var key: String = str(skel.get_bone_name(i)).to_lower()
			if ("spine" in key or "chest" in key or "torso" in key) and d < best_d:
				best_d = d
				best_skel = skel
				best_bone = i
	if best_skel != null:
		return [best_skel, best_bone]
	if any_skel != null:
		return [any_skel, any_bone]
	return []


static func _splat_texture() -> ImageTexture:
	if _splat != null:
		return _splat
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var nx: float = (float(x) + 0.5) / 32.0 - 1.0
			var ny: float = (float(y) + 0.5) / 32.0 - 1.0
			var radius: float = sqrt(nx * nx + ny * ny)
			var angle: float = atan2(ny, nx)
			var edge: float = 0.82 + 0.09 * sin(angle * 5.0 + 0.7) + 0.055 * sin(angle * 9.0 - 1.3) + 0.03 * sin(angle * 17.0 + 2.1)
			var alpha: float = clampf((edge - radius) / 0.18, 0.0, 1.0)
			alpha = alpha * alpha * (3.0 - 2.0 * alpha)
			var grain: float = 0.92 + 0.08 * sin(nx * 37.0 + sin(ny * 21.0)) * sin(ny * 31.0 - nx * 8.0)
			image.set_pixel(x, y, Color(grain, grain, grain, alpha))
	_splat = ImageTexture.create_from_image(image)
	return _splat
