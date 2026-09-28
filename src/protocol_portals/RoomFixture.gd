extends Node2D
## Painted atlas sprites retain their alpha, texture and contact shadows.
const CELLS := {
	"smoke": {"ash_ring": 0, "lounge_basket": 1, "arb_well": 2, "paper": 3, "video": 4, "exam": 5, "exit": 6},
	"diamonds": {"blaze_gate": 0, "tight_float": 1, "vault_crush": 2, "handler_bridge": 3, "paper": 4, "video": 5, "exam": 6, "exit": 7},
	"gold": {"vest_clock": 0, "knox_window": 1, "melt_stamp": 2, "rush_board": 3, "paper": 4, "video": 5, "exam": 6, "exit": 7},
}
var kind := "paper"
var protocol := "smoke"
var target_width := 138.0

func _ready() -> void:
	var texture: Texture2D = load("res://src/assets/portals/fixtures/%s.png" % protocol)
	assert(texture != null, "Missing painted fixture atlas: " + protocol)
	var cell: int = CELLS[protocol][kind]
	var cell_size := texture.get_size() / Vector2(4, 2)
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(Vector2(cell % 4, cell / 4) * cell_size, cell_size)
	atlas.filter_clip = true
	var sprite := Sprite2D.new()
	sprite.name = "PaintedProp"
	sprite.texture = atlas
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var factor := target_width / cell_size.x
	sprite.scale = Vector2.ONE * factor
	# The ground contact is near 95% of each cell, including its soft shadow.
	sprite.position.y = -cell_size.y * 0.45 * factor
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
