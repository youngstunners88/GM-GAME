extends Node2D
## Painted atlas sprite with its ground integration: a soft contact shadow, a
## light-direction cast shadow and a per-room colour grade, so props sit IN the
## painted room instead of floating over it (founder 2026-09-29: "feel a little
## crowbarred in ... more like gameware compared to the more realism backgrounds").
const CELLS := {
	"smoke": {"ash_ring": 0, "lounge_basket": 1, "arb_well": 2, "paper": 3, "video": 4, "exam": 5, "exit": 6},
	"diamonds": {"blaze_gate": 0, "tight_float": 1, "vault_crush": 2, "handler_bridge": 3, "paper": 4, "video": 5, "exam": 6, "exit": 7},
	"gold": {"vest_clock": 0, "knox_window": 1, "melt_stamp": 2, "rush_board": 3, "paper": 4, "video": 5, "exam": 6, "exit": 7},
}
## Per-room light: grade (tint/saturation/contrast), cast-shadow skew toward the
## painting's shadow direction, and how strong the shadows are.
const LIGHT := {
	"smoke": {"tint": Color(1.0, 0.95, 0.90), "sat": 0.96, "contrast": 1.02, "skew": 0.28, "shadow": 0.30, "ao": 0.45, "darken": 0.20},
	"diamonds": {"tint": Color(0.84, 0.95, 1.0), "sat": 0.88, "contrast": 1.03, "skew": 0.0, "shadow": 0.34, "ao": 0.55, "darken": 0.26},
	"gold": {"tint": Color(1.0, 0.90, 0.75), "sat": 0.90, "contrast": 1.02, "skew": 0.0, "shadow": 0.40, "ao": 0.50, "darken": 0.24,
		"sun_x": 1450.0, "spread": 0.55},
}
const GradeShader := preload("res://src/assets/shaders/prop_integrate.gdshader")
const ShadowShader := preload("res://src/assets/shaders/prop_shadow.gdshader")
static var _blob: GradientTexture2D = null

var kind := "paper"
var protocol := "smoke"
var target_width := 138.0


static func _contact_blob() -> GradientTexture2D:
	if _blob == null:
		var grad := Gradient.new()
		grad.set_color(0, Color(0, 0, 0, 0.9))
		grad.set_color(1, Color(0, 0, 0, 0.0))
		_blob = GradientTexture2D.new()
		_blob.gradient = grad
		_blob.fill = GradientTexture2D.FILL_RADIAL
		_blob.fill_from = Vector2(0.5, 0.5)
		_blob.fill_to = Vector2(1.0, 0.5)
		_blob.width = 128
		_blob.height = 128
	return _blob


func _ready() -> void:
	var texture: Texture2D = load("res://src/assets/portals/fixtures/%s.png" % protocol)
	assert(texture != null, "Missing painted fixture atlas: " + protocol)
	var cell: int = CELLS[protocol][kind]
	var cell_size := texture.get_size() / Vector2(4, 2)
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(Vector2(cell % 4, cell / 4) * cell_size, cell_size)
	atlas.filter_clip = true
	var light: Dictionary = LIGHT.get(protocol, LIGHT["smoke"])
	var factor := target_width / cell_size.x
	var lift := -cell_size.y * 0.45 * factor  # ground contact is near 95% of each cell

	# 1. Soft ambient-occlusion pool where the prop meets the ground.
	var ao := Sprite2D.new()
	ao.name = "ContactShadow"
	ao.texture = _contact_blob()
	ao.scale = Vector2(target_width * 0.95 / 128.0, target_width * 0.32 / 128.0)
	ao.position = Vector2(0, -2)
	ao.modulate = Color(1, 1, 1, minf(float(light["ao"]) * 1.35, 0.85))
	ao.z_index = -2
	add_child(ao)

	# 2. Cast shadow: the prop's silhouette flattened onto the ground, skewed away
	#    from the room's light and blurred by the shader.
	var cast := Sprite2D.new()
	cast.name = "CastShadow"
	cast.texture = atlas
	cast.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var sy := -0.36 * factor
	cast.scale = Vector2(factor, sy)
	cast.position = Vector2(0, -cell_size.y * 0.45 * sy - 2.0)
	cast.skew = float(light["skew"])
	if light.has("sun_x"):
		# Back-lit scene: shadows fan away from the sun, left of it they lean left, right of it right.
		cast.skew -= clampf((global_position.x - float(light["sun_x"])) / 900.0, -1.0, 1.0) * float(light["spread"])
	var shadow_mat := ShaderMaterial.new()
	shadow_mat.shader = ShadowShader
	shadow_mat.set_shader_parameter("strength", float(light["shadow"]))
	shadow_mat.set_shader_parameter("blur", 5.0)
	cast.material = shadow_mat
	cast.z_index = -1
	add_child(cast)

	# 3. The prop itself, graded toward the room's light.
	var sprite := Sprite2D.new()
	sprite.name = "PaintedProp"
	sprite.texture = atlas
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.scale = Vector2.ONE * factor
	sprite.position.y = lift + 5.0  # sunk into the ground so nothing hovers
	var grade := ShaderMaterial.new()
	grade.shader = GradeShader
	grade.set_shader_parameter("tint", light["tint"])
	grade.set_shader_parameter("saturation", float(light["sat"]))
	grade.set_shader_parameter("contrast", float(light["contrast"]))
	grade.set_shader_parameter("ground_darken", float(light["darken"]))
	var v0: float = float(cell / 4) * 0.5
	grade.set_shader_parameter("cell_v", Vector2(v0, v0 + 0.5))
	sprite.material = grade
	add_child(sprite)

	var body := StaticBody2D.new()
	body.name = "Footprint"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var footprint := RectangleShape2D.new()
	footprint.size = Vector2(target_width * 0.48, 22)
	shape.shape = footprint
	shape.position.y = -16
	body.add_child(shape)
	add_child(body)
