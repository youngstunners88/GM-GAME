class_name Ep2WeaponSelector
extends Control
## Leather-and-brass armory. Icons are transparent renders of the actual weapon meshes.
const FONT := preload("res://src/episode2/assets/weapons/armory/western_bookman.otf")
const ICONS := {
	Ep2ArmoryState.WIN: preload("res://src/episode2/assets/weapons/armory/winchester_icon.png"),
	Ep2ArmoryState.REM: preload("res://src/episode2/assets/weapons/armory/remington_icon.png"),
	Ep2ArmoryState.BOW: preload("res://src/episode2/assets/weapons/armory/bow_icon.svg"),
}
const BRASS := Color("c7a267")
const PAPER := Color("eddbb2")
var state: Ep2ArmoryState
var highlighted: String = ""
var cards: Array[Button] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	for id in Ep2ArmoryState.IDS:
		var card := Button.new()
		card.flat = true
		card.focus_mode = Control.FOCUS_NONE
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		for style in ["normal", "hover", "pressed", "focus", "disabled"]:
			card.add_theme_stylebox_override(style, StyleBoxEmpty.new())
		card.mouse_entered.connect(func() -> void: preview(id))
		card.pressed.connect(func() -> void: preview(id))
		add_child(card)
		cards.append(card)

## Previewing never changes the ammunition/reload transaction; release commits once in the host.
func preview(id: String) -> void:
	if state != null and state.owns(id):
		highlighted = id
		queue_redraw()

func point_at(point: Vector2) -> void:
	for i in cards.size():
		if cards[i].get_global_rect().has_point(point):
			preview(Ep2ArmoryState.IDS[i])

func _process(_delta: float) -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var ui_scale: float = viewport_size.x / 390.0 if viewport_size.x / viewport_size.y < 1.1 else 1.0
	scale = Vector2.ONE * ui_scale
	size = viewport_size / ui_scale
	for i in cards.size():
		cards[i].position = card_rect(i).position
		cards[i].size = card_rect(i).size
		cards[i].disabled = state == null or not state.owns(Ep2ArmoryState.IDS[i])
	queue_redraw()

func card_rect(i: int) -> Rect2:
	if size.x < 650.0:
		var w: float = minf(440.0, size.x - 32.0)
		var h: float = minf(160.0, size.y * 0.20)
		return Rect2(Vector2((size.x - w) * 0.5, size.y * 0.24 + i * (h + 12.0)), Vector2(w, h))
	var w: float = minf(460.0, (size.x - 96.0) / 3.0)
	var h: float = minf(300.0, size.y * 0.45)
	return Rect2(Vector2(size.x * 0.5 + (i - 1) * (w + 14.0) - w * 0.5, size.y * 0.5 - h * 0.45), Vector2(w, h))

func _text(text: String, p: Vector2, font_size: int, color: Color = PAPER, centered: bool = false) -> void:
	if centered:
		p.x -= FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x * 0.5
	draw_string(FONT, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _leather(rect: Rect2, color: Color, selected: bool = false) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = BRASS if selected else Color("765839")
	style.set_border_width_all(2 if selected else 1)
	style.set_corner_radius_all(9)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 12
	draw_style_box(style, rect)
	var inner := rect.grow(-9)
	draw_rect(inner, Color(0.7, 0.5, 0.29, 0.28), false, 1)
	# Fine leather grain and saddle stitching, deterministic and bounded.
	for j in range(12):
		var y: float = inner.position.y + (j + 1) * inner.size.y / 14.0
		draw_line(Vector2(inner.position.x + 3, y), Vector2(inner.end.x - 3, y + sin(j * 2.3) * 3.0), Color(0.3, 0.18, 0.1, 0.12))
	for x in range(int(rect.position.x + 18), int(rect.end.x - 18), 12):
		draw_line(Vector2(x, rect.position.y + 5), Vector2(x + 4, rect.position.y + 5), Color("907150"))
		draw_line(Vector2(x, rect.end.y - 5), Vector2(x + 4, rect.end.y - 5), Color("907150"))
	for p in [rect.position + Vector2(16,16), Vector2(rect.end.x-16,rect.position.y+16), rect.end-Vector2(16,16), Vector2(rect.position.x+16,rect.end.y-16)]:
		draw_circle(p, 3, BRASS)
		draw_circle(p + Vector2(-.7,-.7), 1, PAPER)

func _draw() -> void:
	if state == null:
		return
	var compact: bool = size.x < 650.0
	var title_size: int = 25 if compact else 40
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.035, 0.024, 0.016, 0.83))
	var mid: float = size.x * 0.5
	var top: float = size.y * 0.12
	_text("LIL BLUNT'S", Vector2(mid, top - 12), 14 if compact else 18, BRASS, true)
	_text("PERSONAL ARMORY", Vector2(mid, top + title_size + 4), title_size, PAPER, true)
	var line_y: float = top + title_size + 23
	draw_line(Vector2(mid - minf(270,size.x*.38),line_y),Vector2(mid-14,line_y),BRASS,1)
	draw_line(Vector2(mid + 14,line_y),Vector2(mid+minf(270,size.x*.38),line_y),BRASS,1)
	draw_colored_polygon(PackedVector2Array([Vector2(mid,line_y-5),Vector2(mid+5,line_y),Vector2(mid,line_y+5),Vector2(mid-5,line_y)]),BRASS)
	for i in Ep2ArmoryState.IDS.size():
		var id: String = Ep2ArmoryState.IDS[i]
		var rect: Rect2 = card_rect(i)
		var picked: bool = highlighted == id
		_leather(rect, Color("38261b") if picked else Color("231b15"), picked)
		var icon: Texture2D = ICONS[id]
		var image_rect := Rect2(rect.position + Vector2(18, 15), Vector2(rect.size.x - 36, rect.size.y * 0.65))
		var ratio: float = minf(image_rect.size.x / icon.get_width(), image_rect.size.y / icon.get_height())
		var image_size: Vector2 = icon.get_size() * ratio
		draw_texture_rect(icon, Rect2(image_rect.get_center() - image_size * 0.5, image_size), false, Color.WHITE if state.owns(id) else Color(.45,.4,.34,.5))
		var fs: int = mini(16, int(rect.size.x / 22.0)) if compact else mini(20, int(rect.size.x / 15.0))
		_text(Ep2ArmoryState.NAMES[id].to_upper(),Vector2(rect.get_center().x,rect.position.y+rect.size.y*.75),fs,PAPER,true)
		var gun: Ep2Winchester = state.firearm(id)
		var count: String = ("%d ARROWS" % state.arrows if id == Ep2ArmoryState.BOW else "%d LOADED  /  %d RESERVE" % [gun.rounds,gun.reserve]) if state.owns(id) else "RECOVER FROM AN ARCHER" if id == Ep2ArmoryState.BOW else "NOT YET ACQUIRED"
		_text(count,Vector2(rect.get_center().x,rect.position.y+rect.size.y*.86),12 if compact else 14,BRASS,true)
		var key: String = Ep2ArmoryState.key_label(Ep2ArmoryState.ACTIONS[i])
		_text(key,rect.position+Vector2(24,32),18,BRASS)
		if picked:
			_text("EQUIP ON RELEASE",Vector2(rect.get_center().x,rect.end.y-12),10,BRASS,true)
	var footer_y: float = card_rect(2 if compact else 1).end.y + 26
	_text("BEAR ARROWS  ·  %d" % state.arrows,Vector2(mid,footer_y),13,BRASS,true)
	_text("TIME STANDS STILL",Vector2(mid,footer_y+26),12,PAPER,true)
	var hint: String = "Hold %s / Back · point or choose 1 / 2 / 3 · release to equip" % Ep2ArmoryState.key_label("ep2_armory")
	if compact:
		hint = "Hold holster · drag to a weapon · release"
	_text(hint,Vector2(mid,footer_y+49),10 if compact else 13,BRASS,true)
