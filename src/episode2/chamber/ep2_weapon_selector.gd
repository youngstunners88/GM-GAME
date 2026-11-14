class_name Ep2WeaponSelector
extends Control
## Leather-and-brass armory. Icons are transparent renders of the actual weapon meshes.
const BUD_ICON := preload("res://src/episode2/ui/icons/chill_bud.svg")
var _bud_art: Texture2D = null
const FONT := preload("res://src/episode2/assets/weapons/armory/western_bookman.otf")
const ICONS := {
	Ep2ArmoryState.WIN: preload("res://src/episode2/assets/weapons/armory/winchester_icon.png"),
	Ep2ArmoryState.REM: preload("res://src/episode2/assets/weapons/armory/remington_icon.png"),
	Ep2ArmoryState.BOW: preload("res://src/episode2/assets/weapons/armory/bow_icon.png"),
	Ep2ArmoryState.SHOT: preload("res://src/episode2/assets/weapons/armory/coach_shotgun_icon.png"),
	Ep2ArmoryState.MP18: preload("res://src/episode2/assets/weapons/armory/bergmann_mp18_icon.png"),
	Ep2ArmoryState.TOMMY: preload("res://src/episode2/assets/weapons/armory/thompson_gold_icon.png"),
	Ep2ArmoryState.BORCH: preload("res://src/episode2/assets/weapons/armory/borchardt_icon.png"),
	Ep2ArmoryState.BUFF: preload("res://src/episode2/assets/weapons/armory/sharps_buffalo_icon.png"),
}
## The purse (founder 2026-10-24: "Lil Blunt has been collecting Eth, BTC, WBTC, Solana and TitanX. These need to be reflected in the
## tab when he is selecting his weapon"): the game's own coin art for each token, in GameManager.PURSE_TOKENS order.
const PURSE_ICONS := {
	"eth": preload("res://src/assets/sprites/sprite_item_coin-eth.png"),
	"btc": preload("res://src/assets/sprites/sprite_item_coin-btc.png"),
	"wbtc": preload("res://src/assets/sprites/sprite_item_wbtc.png"),
	"sol": preload("res://src/assets/sprites/sprite_item_coin-sol.png"),
	"titanx": preload("res://src/episode2/assets/textures/logos/logo_titanx.png"),
}
const BRASS := Color("c7a267")
const PAPER := Color("eddbb2")
var state: Ep2ArmoryState
var highlighted: String = ""
var cards: Array[Button] = []
## Every string the LAST `_draw` wrote (tests read it: the wordless gate cannot look at pixels headless).
var drawn_text: PackedStringArray = []
signal chill_bud_requested
var health: int = 3
var bud_selected: bool = false
var bud_card: Button
var bud_use: Button
var _supply_fingers: Dictionary = {}
## THE SHIPMENT (founder lock 2026-11-04): logistics, not a gun - once it is bought at Rich & Utah's, Tabs shows the same hero crate the
## day-88 river carries (Ep2ShipmentCrate), turning slowly in its own little case. `shipment_live` pulses it while the run is on.
var shipment_tile: SubViewportContainer
var shipment_live: bool = false
var _ship_vp: SubViewport
var _ship_turn: Node3D
var _ship_source: String = ""
## HIS OWN PICKAXE (founder 2026-11-14: the native melee is always usable): a tile of its own in the top right corner, opposite the Shipment,
## never one of the gun cards (the mystery rule and the eight-gun grid are untouched). Pointing at it previews it like a card; release equips it.
## Its picture streams with the extras (the war pick in his glove); until then the tile is the leather alone, with its name where keys are shown.
const PICK_ICON := "res://src/episode2/extras/armory/showcase/war_pick_icon.png"
var pick_card: Button
var _pick_art: Texture2D = null

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
	pick_card = Button.new()
	pick_card.name = "Pickaxe"
	pick_card.flat = true
	pick_card.focus_mode = Control.FOCUS_NONE
	pick_card.mouse_filter = Control.MOUSE_FILTER_PASS
	for style in ["normal", "hover", "pressed", "focus", "disabled"]:
		pick_card.add_theme_stylebox_override(style, StyleBoxEmpty.new())
	pick_card.mouse_entered.connect(func() -> void: preview(Ep2ArmoryState.PICK))
	pick_card.pressed.connect(func() -> void: preview(Ep2ArmoryState.PICK))
	add_child(pick_card)
	bud_card = _supply_button("ChillBud", select_bud)
	bud_card.icon = BUD_ICON
	bud_card.expand_icon = true
	bud_card.add_theme_constant_override("icon_max_width", 44)
	bud_use = _supply_button("UseChillBud", func() -> void: chill_bud_requested.emit())
	bud_use.icon = preload("res://src/episode2/ui/icons/full_hearts.svg")
	bud_use.expand_icon = true
	bud_use.add_theme_constant_override("icon_max_width", 54)
	_build_shipment_tile()

func _build_shipment_tile() -> void:
	shipment_tile = SubViewportContainer.new()
	shipment_tile.name = "ShipmentTile"
	shipment_tile.stretch = true
	shipment_tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shipment_tile.visible = false
	add_child(shipment_tile)
	_ship_vp = SubViewport.new()
	_ship_vp.own_world_3d = true
	_ship_vp.transparent_bg = true
	_ship_vp.size = Vector2i(192, 192)
	_ship_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	shipment_tile.add_child(_ship_vp)
	var cam := Camera3D.new()
	cam.fov = 34.0
	cam.position = Vector3(0, 0.75, 2.6)
	cam.rotation.x = -0.22
	cam.current = true
	_ship_vp.add_child(cam)
	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.88, 0.70)
	key.light_energy = 1.7
	key.rotation = Vector3(-0.7, 0.6, 0)
	_ship_vp.add_child(key)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.80, 0.68, 0.52)
	env.environment.ambient_light_energy = 0.6
	_ship_vp.add_child(env)
	_ship_turn = Node3D.new()
	_ship_turn.name = "Turntable"
	_ship_vp.add_child(_ship_turn)

## The crate in the tile: (re)built when the streamed model arrives, so Tabs always shows what the river will carry.
func _sync_shipment_model() -> void:
	var src: String = Ep2ShipmentCrate.source()
	if src == _ship_source and _ship_turn.get_child_count() > 0:
		return
	for c in _ship_turn.get_children():
		c.queue_free()
	_ship_source = src
	_ship_turn.add_child(Ep2ShipmentCrate.model(1.3))

## The pickaxe tile: the Shipment's place mirrored to the right edge, the top right corner (the close button is top left).
func pick_rect() -> Rect2:
	var compact: bool = size.x < 650.0
	var w: float = 76.0 if compact else 150.0
	var h: float = 44.0 if compact else 84.0
	return Rect2(Vector2(size.x - w - 10.0, 8.0), Vector2(w, h))


## The pickaxe's picture once the streamed pack has it (null before: the tile draws without one).
func pick_icon() -> Texture2D:
	if _pick_art == null and Ep2Extras.has(PICK_ICON):
		_pick_art = load(PICK_ICON) as Texture2D
	return _pick_art


func shipment_rect() -> Rect2:
	var side: float = 64.0 if size.x < 650.0 else 120.0
	return Rect2(Vector2(10.0, 6.0), Vector2(side, side))

func _supply_button(label: String, action: Callable) -> Button:
	var b := Button.new()
	b.name = label
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 15)
	for kind in ["normal","hover","pressed","disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("38291b") if kind == "hover" else Color("241b14")
		style.border_color = Color("765839") if kind == "disabled" else BRASS
		style.set_border_width_all(1)
		style.set_corner_radius_all(5)
		b.add_theme_stylebox_override(kind,style)
	var last_frame := [-1]
	var activate: Callable = func() -> void:
		if b.disabled or last_frame[0] == Engine.get_process_frames(): return
		last_frame[0] = Engine.get_process_frames()
		action.call()
	b.pressed.connect(activate)
	b.gui_input.connect(func(event: InputEvent) -> void:
		if not event is InputEventScreenTouch or b.disabled: return
		if event.pressed: _supply_fingers[event.index] = b
		else:
			var started: Variant = _supply_fingers.get(event.index)
			_supply_fingers.erase(event.index)
			if started == b and not event.canceled and Rect2(Vector2.ZERO,b.size).has_point(event.position): activate.call()
		b.accept_event())
	add_child(b)
	return b

func select_bud() -> void:
	bud_selected = true
	refresh_supplies()
	queue_redraw()

func supply_gui_point(point: Vector2) -> bool:
	return bud_card != null and (bud_card.get_global_rect().has_point(point) or bud_use.get_global_rect().has_point(point))

## Previewing never changes the ammunition/reload transaction; release commits once in the host.
func preview(id: String) -> void:
	if state != null and state.can_select(id):
		bud_selected = false
		refresh_supplies()
		highlighted = id
		queue_redraw()

func point_at(point: Vector2) -> void:
	for i in cards.size():
		if cards[i].visible and cards[i].get_global_rect().has_point(point):
			preview(Ep2ArmoryState.IDS[i])
	if pick_card.visible and pick_card.get_global_rect().has_point(point):
		preview(Ep2ArmoryState.PICK)


## THE MYSTERY RULE (founder 2026-11-07): the cards are the weapons he has in hand now, in slot order. A gun he never acquired, or one the
## Sheriff holds, has no card and is named nowhere on this panel; acquiring it (or buying it back) brings its card in.
func shown_ids() -> Array:
	var out: Array = []
	if state == null:
		return out
	for id in Ep2ArmoryState.IDS:
		if state.owns(id) and not state.is_held(id):
			out.append(id)
	return out


## Where a weapon's card sits in the grid (-1 = it has no card). Its quick-switch key stays the slot's own key, wherever the card lands.
func card_slot(id: String) -> int:
	return shown_ids().find(id)

func _process(_delta: float) -> void:
	# The actual bud streams with the ranch assets, preserving the main pack's small headroom.
	if _bud_art == null and Ep2Extras.has(Ep2Extras.PATCH_BUD_ICON):
		_bud_art = load(Ep2Extras.PATCH_BUD_ICON) as Texture2D
		if _bud_art != null:
			bud_card.icon = _bud_art
	var viewport_size: Vector2 = get_viewport_rect().size
	var ui_scale: float = viewport_size.x / 390.0 if viewport_size.x / viewport_size.y < 1.1 else 1.0
	scale = Vector2.ONE * ui_scale
	size = viewport_size / ui_scale
	var shown: Array = shown_ids()
	for i in cards.size():
		var slot: int = shown.find(Ep2ArmoryState.IDS[i])
		cards[i].visible = slot >= 0
		cards[i].disabled = slot < 0
		if slot >= 0:
			cards[i].position = card_rect(slot).position
			cards[i].size = card_rect(slot).size
	pick_card.visible = not bud_selected                # the selected bud's picture takes that corner
	pick_card.position = pick_rect().position
	pick_card.size = pick_rect().size
	var band: Rect2 = _ledger_band()
	var action_width: float = 112.0 if size.x < 650 else 150.0
	var supply_scale: float = _supply_scale()
	action_width = maxf(action_width,88.0*supply_scale)
	var button_height: float = 48.0*supply_scale
	bud_card.position = band.position+Vector2(10,27)
	bud_card.size = Vector2(band.size.x-action_width-28,button_height)
	bud_use.position = Vector2(band.end.x-action_width-10,band.position.y+27)
	bud_use.size = Vector2(action_width,button_height)
	bud_card.add_theme_constant_override("icon_max_width",int(44*supply_scale))
	bud_use.add_theme_constant_override("icon_max_width",int(54*supply_scale))
	bud_card.add_theme_font_size_override("font_size",int(15*supply_scale))
	var owns_shipment: bool = state != null and state.river_gear and visible and not bud_selected
	shipment_tile.visible = owns_shipment
	_ship_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if owns_shipment else SubViewport.UPDATE_DISABLED
	if owns_shipment:
		_sync_shipment_model()
		var r: Rect2 = shipment_rect()
		var pulse: float = 1.0 + (0.08 * sin(Time.get_ticks_msec() * 0.006) if shipment_live else 0.0)
		shipment_tile.position = r.position + r.size * (1.0 - pulse) * 0.5
		shipment_tile.size = r.size * pulse
		_ship_turn.rotation.y = fmod(_ship_turn.rotation.y + _delta * 0.55, TAU)     # a slow Y spin
	refresh_supplies()
	queue_redraw()

func refresh_supplies() -> void:
	if bud_card==null or bud_use==null:return
	bud_card.text = ("DUDE'S CHILL BUD  ×%d" if TouchUi.keys_shown() else "×%d") % GameManager.chill_buds
	bud_card.modulate = Color.WHITE
	bud_card.add_theme_color_override("font_color", Color("ffd482") if bud_selected else PAPER)
	bud_use.text = "USE" if TouchUi.keys_shown() else ""
	bud_use.disabled = not bud_selected or health <= 0 or health >= 3 or GameManager.chill_buds <= 0
	queue_redraw()

## The title/purse/ledger geometry is shared by the cards, so the ledger is a
## real band under the purse rather than something drawn over the weapon art.
func _purse_band() -> Rect2:
	var compact: bool = size.x < 650.0
	var mid: float = size.x * 0.5
	var title_size: int = 25 if compact else 40
	var line_y: float = size.y * 0.12 + title_size + 23.0
	return Rect2(Vector2(mid - minf(350.0, size.x * 0.5 - 16.0), line_y + 10.0),
		Vector2(minf(700.0, size.x - 32.0), 40.0 if compact else 44.0))

func _supply_scale() -> float:
	# Metrics are canvas units per dp; portrait already scales this panel.
	return maxf(1.0,TouchUi.metrics().dp/maxf(.01,scale.x)) if not TouchUi.keys_shown() else 1.0

func _ledger_band() -> Rect2:
	var purse: Rect2 = _purse_band()
	return Rect2(purse.position + Vector2(0.0, purse.size.y + 6.0),
		Vector2(purse.size.x, 53.0+48.0*_supply_scale()))

## Six slots (founder 2026-11-01 added the coach gun, the MP18 and the golden Thompson): three across and two down on a wide screen,
## two across and three down on a phone.
func card_rect(i: int) -> Rect2:
	var n: int = Ep2ArmoryState.IDS.size()
	if size.x < 650.0:
		var cols: int = 2
		var rows: int = int(ceil(float(n) / float(cols)))
		var total_w: float = minf(440.0, size.x - 32.0)
		var w: float = (total_w - 10.0) * 0.5
		var top: float = _ledger_band().end.y + 10.0
		var available: float = maxf(96.0, size.y - top - 82.0)
		var h: float = maxf(28.0, minf(160.0, minf(size.y * 0.20, (available - 10.0 * float(rows - 1)) / float(rows))))
		var used: float = h * float(rows) + 10.0 * float(rows - 1)
		var y: float = top + maxf(0.0, (available - used) * 0.25)
		var x0: float = (size.x - total_w) * 0.5 + float(cols - _in_row(i, cols)) * (w + 10.0) * 0.5     # a short row sits centred
		return Rect2(Vector2(x0 + float(i % cols) * (w + 10.0), y + floorf(float(i) / float(cols)) * (h + 10.0)), Vector2(w, h))
	var cols_w: int = 4 if n > 6 else 3          # the founder's eight guns: two rows of four
	var rows_w: int = int(ceil(float(n) / float(cols_w)))
	var top_w: float = _ledger_band().end.y + 14.0
	var available_w: float = maxf(120.0, size.y - top_w - 88.0)
	var h_w: float = maxf(70.0, minf(260.0, (available_w - 12.0 * float(rows_w - 1)) / float(rows_w)))
	var y_w: float = top_w + maxf(0.0, (available_w - h_w * float(rows_w) - 12.0 * float(rows_w - 1)) * 0.30)
	var w_w: float = minf(460.0, (size.x - 96.0) / float(cols_w))
	var centre: float = float(_in_row(i, cols_w) - 1) * 0.5                                          # a short row sits centred
	return Rect2(Vector2(size.x * 0.5 + (float(i % cols_w) - centre) * (w_w + 14.0) - w_w * 0.5, y_w + floorf(float(i) / float(cols_w)) * (h_w + 12.0)), Vector2(w_w, h_w))


## How many of his cards share slot `i`'s row (the grid keeps room for all eight; the cards he has fill it in order).
func _in_row(i: int, cols: int) -> int:
	var shown: int = maxi(1, shown_ids().size())
	if i >= shown:
		return cols                                    # a slot with no card keeps the full grid's place (the footer and hints measure from it)
	return clampi(shown - (i / cols) * cols, 1, cols)

func _text(text: String, p: Vector2, font_size: int, color: Color = PAPER, centered: bool = false) -> void:
	drawn_text.append(text)
	if centered:
		p.x -= FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x * 0.5
	draw_string(FONT, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _fit_font_size(text: String, max_width: float, start: int, minimum: int = 8) -> int:
	var fs: int = start
	while fs > minimum and FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > max_width:
		fs -= 1
	return fs

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
	drawn_text.clear()
	if state == null:
		return
	var keys: bool = TouchUi.keys_shown()
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
	_draw_purse(_purse_band(), compact)
	if state.river_gear and keys and not bud_selected:                       # wordless on touch: the turning crate is the label there
		var sr: Rect2 = shipment_rect()
		_text("THE SHIPMENT", Vector2(sr.get_center().x, sr.end.y + (10 if compact else 14)), 9 if compact else 12, BRASS, true)
		if not compact:
			_text("DAY-88 LIVE" if shipment_live else "DAY-88 CARGO", Vector2(sr.get_center().x, sr.end.y + 29), 10, PAPER, true)
	if bud_selected:
		# The exact founder-supplied bud, rendered from the mesh; the health transaction stays in the host.
		var br: Rect2 = shipment_rect()
		if size.y < 520.0:
			br.size = Vector2(64.0, 64.0)
		br.position.x = size.x - br.size.x - 10.0
		draw_texture_rect(_bud_art if _bud_art != null else BUD_ICON, br, false)
		if keys:
			_text("CHILL BUD", Vector2(br.get_center().x, br.end.y + (10 if compact else 14)), 9 if compact else 12, BRASS, true)
	_draw_ledger(_ledger_band(), compact)
	if not bud_selected:
		var pr: Rect2 = pick_rect()
		var pick_on: bool = highlighted == Ep2ArmoryState.PICK
		_leather(pr, Color("38261b") if pick_on else Color("231b15"), pick_on)
		var art: Texture2D = pick_icon()
		if art != null:
			var room := Rect2(pr.position + Vector2(6, 4), pr.size - Vector2(12, 8 if not keys else (16 if compact else 24)))
			var k: float = minf(room.size.x / art.get_width(), room.size.y / art.get_height())
			draw_texture_rect(art, Rect2(room.get_center() - art.get_size() * k * 0.5, art.get_size() * k), false)
		if keys:
			_text(Ep2ArmoryState.PICK_NAME.to_upper(), Vector2(pr.get_center().x, pr.end.y - (5 if compact else 8)), 9 if compact else 13, PAPER, true)
			_text(Ep2ArmoryState.key_label(Ep2ArmoryState.PICK_ACTION), pr.position + Vector2(10, 18 if compact else 24), 11 if compact else 15, BRASS)
	var shown: Array = shown_ids()
	if shown.is_empty():
		# the Sheriff holds every iron: say so in the first card's place, and name only what he does carry
		var first: Rect2 = card_rect(0)
		_text("THE SHERIFF HOLDS YOUR IRONS", Vector2(first.position.x + 8.0, first.get_center().y - 8.0), 12 if compact else 16, PAPER)
		_text("PICKAXE IN HAND  ·  BUY THEM BACK AT RICH & UTAH'S", Vector2(first.position.x + 8.0, first.get_center().y + 14.0), 10 if compact else 13, BRASS)
	for slot in shown.size():
		var id: String = shown[slot]
		var i: int = Ep2ArmoryState.IDS.find(id)                # the weapon's own slot: its quick-switch key
		var rect: Rect2 = card_rect(slot)
		var picked: bool = highlighted == id and not bud_selected
		_leather(rect, Color("38261b") if picked else Color("231b15"), picked)
		var icon: Texture2D = ICONS[id]
		var image_rect := Rect2(rect.position + Vector2(18, 15), Vector2(rect.size.x - 36, rect.size.y * 0.65))
		var ratio: float = minf(image_rect.size.x / icon.get_width(), image_rect.size.y / icon.get_height())
		var image_size: Vector2 = icon.get_size() * ratio
		draw_texture_rect(icon, Rect2(image_rect.get_center() - image_size * 0.5, image_size), false)
		var fs: int = mini(16, int(rect.size.x / 22.0)) if compact else mini(20, int(rect.size.x / 15.0))
		_text(Ep2ArmoryState.NAMES[id].to_upper(),Vector2(rect.get_center().x,rect.position.y+rect.size.y*.75),fs,PAPER,true)
		var count: String = card_status(id)
		_text(count,Vector2(rect.get_center().x,rect.position.y+rect.size.y*.86),12 if compact else 14,BRASS,true)
		# key names and mouse instructions are desktop-only (audit 2026-10-29 P1-3: the bud line was
		# already gated, so the selector's own labels were an oversight)
		if keys:
			var key: String = Ep2ArmoryState.key_label(Ep2ArmoryState.SLOT_ACTIONS[i])
			_text(key,rect.position+Vector2(24,32),18,BRASS)
		if picked and keys:
			_text("EQUIP ON RELEASE",Vector2(rect.get_center().x,rect.end.y-12),10,BRASS,true)
	var footer_y: float = card_rect(Ep2ArmoryState.IDS.size() - 1).end.y + 26
	if state.owns(Ep2ArmoryState.BOW) or state.arrows > 0:      # arrows only once there is a bow or a quiver to speak of
		_text("BEAR ARROWS  ·  %d" % state.arrows,Vector2(mid,footer_y),13,BRASS,true)
	_text("TIME STANDS STILL",Vector2(mid,footer_y+26),12,PAPER,true)
	if keys:
		var hint: String = "Hold %s / Back · point or choose 1 - %d · release to equip" % [Ep2ArmoryState.key_label("ep2_armory"), Ep2ArmoryState.IDS.size()]
		if compact:
			hint = "Hold holster · drag to a weapon · release"
		_text(hint,Vector2(mid,footer_y+49),10 if compact else 13,BRASS,true)

## The ammunition/acquisition line on one card. Confiscated irons stay visible
## but cannot be previewed or equipped until the Sheriff returns them.
func card_status(id: String) -> String:
	if state == null:
		return ""
	if state.is_held(id):
		return "HELD - REBUY AT RICH & UTAH'S"
	if not state.owns(id):
		if Ep2ArmoryState.SHOP_GUNS.has(id):
			return "SOLD AT RICH & UTAH'S"
		return "RECOVER FROM AN ARCHER" if id == Ep2ArmoryState.BOW else "NOT YET ACQUIRED"
	if id == Ep2ArmoryState.BOW:
		return "%d ARROWS" % state.arrows
	var gun: Ep2Winchester = state.firearm(id)
	return "%d LOADED  /  %d RESERVE" % [gun.rounds, gun.reserve]


## The purse strip: a leather band under the title with every token he carries and how many faces of it - what Rich (or anyone in
## town) will take from him. Balances come straight from GameManager.purse_balance, so the tab and the shop can never disagree.
func _draw_purse(band: Rect2, compact: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("2a1d14")
	style.border_color = Color("765839")
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	draw_style_box(style, band)
	var label_w: float = 0.0 if compact else 74.0
	if not compact:
		_text("PURSE", band.position + Vector2(14.0, band.size.y * 0.5 + 6.0), 15, BRASS)
	var tokens: Array = GameManager.PURSE_TOKENS
	var slot: float = (band.size.x - label_w - 12.0) / float(tokens.size())
	var icon_px: float = band.size.y - (18.0 if compact else 14.0)
	var fs: int = 11 if compact else 16          # the phone keeps the names (BTC and WBTC share an orange coin face)
	for i in tokens.size():
		var t: String = tokens[i]
		var x0: float = band.position.x + label_w + 6.0 + slot * float(i)
		var tex: Texture2D = PURSE_ICONS.get(t)
		if tex != null:
			draw_texture_rect(tex, Rect2(Vector2(x0 + 4.0, band.position.y + 7.0), Vector2(icon_px, icon_px)), false)
		var amount: int = GameManager.purse_balance(t)
		var token_name: String = str(GameManager.PURSE_NAMES.get(t, t.to_upper()))
		var ink: Color = PAPER if amount > 0 else Color(0.6, 0.52, 0.42)
		var tx: float = x0 + icon_px + (6.0 if compact else 9.0)
		if compact:                                  # phone: the count over the token's name, so five fit in 358 px
			_text("%d" % amount, Vector2(tx, band.position.y + band.size.y * 0.5 - 1.0), 13, ink)
			_text(token_name, Vector2(tx, band.position.y + band.size.y * 0.5 + 11.0), 8, BRASS)
		else:
			_text("%s %d" % [token_name, amount], Vector2(tx, band.position.y + band.size.y * 0.5 + fs * 0.36), fs, ink)


## Lil Blunt's ledger: his own bear kills (never Bull's), the Dude's Chill Buds
## he has stored, and the tunnel BTC banked by the runner leg he just finished.
## Everything is read live from GameManager, so H and Rich's counter update the
## same panel without a second copy of any number.
func _draw_ledger(band: Rect2, compact: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("211710")
	style.border_color = Color("765839")
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	draw_style_box(style, band)
	var bear_line: String = "BEARS DOWN %d · WOUNDED %d" % [GameManager.bear_total(), GameManager.bears_wounded]
	var kinds: Array = GameManager.bear_tally.keys()
	kinds.sort()
	for kind in kinds:
		var count: int = int(GameManager.bear_tally[kind])
		if count > 0:
			bear_line += "   %s %d" % [str(kind).to_upper(), count]
	var bud_line: String = "%d / 3 · RESTORES ALL THREE HEARTS" % health
	if health >= 3: bud_line = "3 / 3 · FEELING CHILL"
	if GameManager.chill_buds <= 0: bud_line = "VISIT DUDE FOR CHILL BUDS"
	if TouchUi.keys_shown(): bud_line += " · H TO USE"
	else: bud_line = "%d / 3" % health
	var runner_btc: int = GameManager.runner_btc_credited
	if runner_btc > 0:
		bud_line += "   RUNNER BTC +%d" % runner_btc
	var max_width: float = band.size.x - 20.0
	var bear_fs: int = _fit_font_size(bear_line, max_width, 11 if compact else 15)
	var bud_fs: int = _fit_font_size(bud_line, max_width, 10 if compact else 13)
	var x: float = band.get_center().x
	_text(bear_line, Vector2(x, band.position.y + (18.0 if compact else 20.0)), bear_fs, PAPER, true)
	_text(bud_line, Vector2(x, band.end.y-9), bud_fs, BRASS, true)
