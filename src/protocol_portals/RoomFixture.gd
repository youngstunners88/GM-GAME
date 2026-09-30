extends Node2D
## Painted atlas sprite with a shared foot anchor, compact contact shadow and
## per-room colour grade, so props sit in the
## painted room instead of floating over it (founder 2026-09-29: "feel a little
## crowbarred in ... more like gameware compared to the more realism backgrounds").
const CELLS := {
	"smoke": {"ash_ring": 0, "lounge_basket": 1, "arb_well": 2, "paper": 3, "video": 4, "exam": 5, "exit": 6},
	"diamonds": {"blaze_gate": 0, "tight_float": 1, "vault_crush": 2, "handler_bridge": 3, "paper": 4, "video": 5, "exam": 6, "exit": 7},
	"gold": {"vest_clock": 0, "knox_window": 1, "melt_stamp": 2, "rush_board": 3, "paper": 4, "video": 5, "exam": 6, "exit": 7},
}
## Restrained per-room grading; compact contact shadows use a shared foot anchor.
const LIGHT := {
	"smoke": {"tint": Color(1.0, 0.95, 0.90), "sat": 0.96, "contrast": 1.02, "darken": 0.20},
	"diamonds": {"tint": Color(0.84, 0.95, 1.0), "sat": 0.88, "contrast": 1.03, "darken": 0.26},
	"gold": {"tint": Color(1.0, 0.90, 0.75), "sat": 0.90, "contrast": 1.02, "darken": 0.24},
}
const GradeShader := preload("res://src/assets/shaders/prop_integrate.gdshader")
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
	# The admitted atlases have opaque feet at y=410/443 (not the cell edge).
	# Use the SAME origin for art, contact shadow, collider and approach zone.
	var contact := Vector2(cell_size.x * 0.5, cell_size.y * (410.0 / 443.0))
	var art_offset := (cell_size * 0.5 - contact) * factor

	# 1. Soft ambient-occlusion pool where the prop meets the ground.
	var contacts: Array = [Vector4(0, -3, target_width * 0.60, 14)]
	if protocol == "gold":
		# Measured feet in 443px atlas cells: avoid shadows in empty space between legs.
		var pads := {
			"vest_clock": [Vector4(220, 377, 185, 52)],
			"knox_window": [Vector4(222, 377, 225, 50)],
			"melt_stamp": [Vector4(220, 380, 230, 48)],
			"rush_board": [Vector4(73, 315, 34, 16), Vector4(326, 405, 34, 16)],
			"paper": [Vector4(88, 345, 32, 16), Vector4(272, 408, 36, 16), Vector4(345, 340, 28, 14)],
			"video": [Vector4(143, 402, 30, 14), Vector4(281, 403, 30, 14)],
			"exam": [Vector4(88, 326, 34, 16), Vector4(239, 372, 36, 16), Vector4(315, 405, 42, 18)],
			"exit": [Vector4(230, 400, 58, 22)],
		}
		contacts = []
		for pad in pads[kind]:
			contacts.append(Vector4((pad.x - 221.5) * target_width / 443.0, (pad.y - 410.0) * target_width / 443.0, pad.z * target_width / 443.0, pad.w * target_width / 443.0))
	for i in contacts.size():
		var pad: Vector4 = contacts[i]
		var ao := Sprite2D.new()
		ao.name = "ContactShadow" if i == 0 else "ContactShadow%d" % i
		ao.texture = _contact_blob()
		ao.scale = Vector2(pad.z, pad.w) / 128.0
		ao.position = Vector2(pad.x, pad.y)
		ao.modulate = Color(0.40, 0.27, 0.16, 0.40) if protocol == "gold" else Color(1, 1, 1, 0.34)
		ao.z_index = -2
		add_child(ao)

	# A detached flattened silhouette reads as levitation. Keep the small contact
	# shadow directly under the feet; the painting supplies the broad sunlight.

	# 3. The prop itself, graded toward the room's light.
	var sprite := Sprite2D.new()
	sprite.name = "PaintedProp"
	sprite.texture = atlas
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.scale = Vector2.ONE * factor
	sprite.position = art_offset
	var grade := ShaderMaterial.new()
	grade.shader = GradeShader
	grade.set_shader_parameter("tint", light["tint"])
	grade.set_shader_parameter("saturation", float(light["sat"]))
	grade.set_shader_parameter("contrast", float(light["contrast"]))
	grade.set_shader_parameter("ground_darken", float(light["darken"]))
	grade.set_shader_parameter("top_light", 0.035)
	var v0: float = float(cell / 4) * 0.5
	grade.set_shader_parameter("cell_v", Vector2(v0, v0 + 0.5))
	sprite.material = grade
	add_child(sprite)

	var body := StaticBody2D.new()
	body.name = "Footprint"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var footprint := RectangleShape2D.new()
	footprint.size = Vector2(target_width * 0.48, 22)
	shape.shape = footprint
	shape.position.y = -11
	body.add_child(shape)
	add_child(body)
