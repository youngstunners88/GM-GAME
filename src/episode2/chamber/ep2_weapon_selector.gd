class_name Ep2WeaponSelector
extends Control
## Leather-and-brass armory. Icons are transparent renders of the actual weapon meshes.
const FONT := preload("res://src/episode2/assets/weapons/armory/western_bookman.otf")
const ICONS := {
	Ep2ArmoryState.WIN: preload("res://src/episode2/assets/weapons/armory/winchester_icon.png"),
	Ep2ArmoryState.REM: preload("res://src/episode2/assets/weapons/armory/remington_icon.png"),
	Ep2ArmoryState.BOW: preload("res://src/episode2/assets/weapons/armory/bow_icon.png"),
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
signal chill_bud_requested
var health: int = 3
var bud_selected: bool = false
var bud_card: Button
var bud_use: Button
var _supply_fingers: Dictionary = {}

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
	bud_card = _supply_button("ChillBud", select_bud)
	bud_card.icon = preload("res://src/episode2/ui/icons/chill_bud.svg")
	bud_card.expand_icon = true
	bud_card.add_theme_constant_override("icon_max_width", 32)
	bud_use = _supply_button("UseChillBud", func() -> void: chill_bud_requested.emit())
	bud_use.icon = preload("res://src/episode2/ui/icons/full_hearts.svg")
	bud_use.expand_icon = true
	bud_use.add_theme_constant_override("icon_max_width", 54)

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
	if state != null and not state.firearms_confiscated and state.owns(id):
		bud_selected = false
		refresh_supplies()
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
		cards[i].disabled = state == null or state.firearms_confiscated or not state.owns(Ep2ArmoryState.IDS[i])
	var band: Rect2 = _ledger_band()
	var action_width: float = 112.0 if size.x < 650 else 150.0
	bud_card.position = band.position+Vector2(10,27)
	bud_card.size = Vector2(band.size.x-action_width-28,48)
	bud_use.position = Vector2(band.end.x-action_width-10,band.position.y+27)
	bud_use.size = Vector2(action_width,48)
	refresh_supplies()
	queue_redraw()

func refresh_supplies() -> void:
	if bud_card==null or bud_use==null:return
	bud_card.text = ("DUDE'S CHILL BUD  ×%d" if TouchUi.keys_shown() else "×%d") % GameManager.chill_buds
	bud_card.modulate = Color("ffd482") if bud_selected else Color.WHITE
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

func _ledger_band() -> Rect2:
	var purse: Rect2 = _purse_band()
	return Rect2(purse.position + Vector2(0.0, purse.size.y + 6.0),
		Vector2(purse.size.x, 101.0))

func card_rect(i: int) -> Rect2:
	if size.x < 650.0:
		var w: float = minf(440.0, size.x - 32.0)
		var top: float = _ledger_band().end.y + 10.0
		var available: float = maxf(96.0, size.y - top - 82.0)
		var h: float = maxf(28.0, minf(160.0, minf(size.y * 0.20, (available - 24.0) / 3.0)))
		var used: float = h * 3.0 + 24.0
		var y: float = top + maxf(0.0, (available - used) * 0.25)
		return Rect2(Vector2((size.x - w) * 0.5, y + i * (h + 12.0)), Vector2(w, h))
	var top: float = _ledger_band().end.y + 14.0
	var available: float = maxf(120.0, size.y - top - 88.0)
	var h: float = maxf(80.0, minf(300.0, minf(size.y * 0.45, available)))
	var y: float = top + maxf(0.0, (available - h) * 0.30)
	var w: float = minf(460.0, (size.x - 96.0) / 3.0)
	return Rect2(Vector2(size.x * 0.5 + (i - 1) * (w + 14.0) - w * 0.5, y), Vector2(w, h))

func _text(text: String, p: Vector2, font_size: int, color: Color = PAPER, centered: bool = false) -> void:
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
	_draw_purse(_purse_band(), compact)
	_draw_ledger(_ledger_band(), compact)
	for i in Ep2ArmoryState.IDS.size():
		var id: String = Ep2ArmoryState.IDS[i]
		var rect: Rect2 = card_rect(i)
		var picked: bool = highlighted == id and not bud_selected
		_leather(rect, Color("38261b") if picked else Color("231b15"), picked)
		var icon: Texture2D = ICONS[id]
		var image_rect := Rect2(rect.position + Vector2(18, 15), Vector2(rect.size.x - 36, rect.size.y * 0.65))
		var ratio: float = minf(image_rect.size.x / icon.get_width(), image_rect.size.y / icon.get_height())
		var image_size: Vector2 = icon.get_size() * ratio
		draw_texture_rect(icon, Rect2(image_rect.get_center() - image_size * 0.5, image_size), false, Color.WHITE if state.owns(id) else Color(.45,.4,.34,.5))
		var fs: int = mini(16, int(rect.size.x / 22.0)) if compact else mini(20, int(rect.size.x / 15.0))
		_text(Ep2ArmoryState.NAMES[id].to_upper(),Vector2(rect.get_center().x,rect.position.y+rect.size.y*.75),fs,PAPER,true)
		var count: String = card_status(id)
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

## The ammunition/acquisition line on one card. Confiscated irons stay visible
## but cannot be previewed or equipped until the Sheriff returns them.
func card_status(id: String) -> String:
	if state == null:
		return ""
	if state.firearms_confiscated and state.owns(id):
		return "HELD BY THE SHERIFF"
	if not state.owns(id):
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
	var bear_line: String = "BEARS  %d" % GameManager.bear_total()
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
