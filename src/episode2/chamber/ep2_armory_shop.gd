class_name Ep2ArmoryShop
extends Control
## RICH & UTAH - ARMS: the Armory's trade counter (founder lock PROMPT_EPISODE2_RICH_ARMORY_UTAH_RIVER.md).
## Leather-and-brass, the same cabinet as the personal armory selector (ep2_weapon_selector.gd) so the two
## read as one world. The panel never awards anything: it only raises `buy_requested`, and the host chamber
## debits the Episode 1 crypto purse and asks `Ep2ArmoryState`. The tender is Episode 1 crypto only
## (BTC / ETH / SOL coin faces) - no soft currency, no protocol number, no address.
## Stock and prices live once, in `Ep2ArmoryState.SHOP`.

signal buy_requested(item_id: String, price: int, tender: String)
signal closed

const FONT := preload("res://src/episode2/assets/weapons/armory/western_bookman.otf")
const BRASS := Color("c7a267")
const PAPER := Color("eddbb2")
const LEATHER := Color("38261b")
const LEATHER_DIM := Color("231b15")
const CLOSED := Color("5d4a38")
## Every token in Lil Blunt's purse pays (founder 2026-10-24: ETH, BTC, WBTC, Solana and TitanX, "at Rich or anywhere").
const TENDER_NAMES := {"btc": "BTC", "eth": "ETH", "wbtc": "WBTC", "sol": "SOL", "titanx": "TITANX"}
const TENDERS := ["btc", "eth", "wbtc", "sol", "titanx"]

var state: Ep2ArmoryState = null
var purse: int = 0
var tender: String = "btc"
## The host's balance lookup for a tender (GameManager.purse_balance); when unset the shop keeps the purse it was opened with.
var purse_of: Callable = Callable()
var index: int = 0
var grace: float = 0.25
var flash: String = ""
var _flash_t: float = 0.0
var _rows: Array[Button] = []


func _catalogue() -> Array:
	return Ep2ArmoryState.SHOP


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	for i in _catalogue().size():
		var row := Button.new()
		row.flat = true
		row.focus_mode = Control.FOCUS_NONE
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		for style in ["normal", "hover", "pressed", "focus", "disabled"]:
			row.add_theme_stylebox_override(style, StyleBoxEmpty.new())
		row.mouse_entered.connect(func() -> void: index = i)
		row.pressed.connect(func() -> void: _choose(i))
		add_child(row)
		_rows.append(row)
	preload("res://src/ui/panel_close.gd").install(self, func() -> void: closed.emit())
	set_process(true)


## Host calls this before showing the panel.
func open_shop(armory_state: Ep2ArmoryState, coin_purse: int) -> void:
	state = armory_state
	purse = coin_purse
	if purse_of.is_valid():
		purse = int(purse_of.call(tender))
	index = 0
	grace = 0.25
	flash = ""
	show()


func set_purse(coin_purse: int) -> void:
	purse = coin_purse
	queue_redraw()


## Re-read the balance of the tender now selected (each token is its own purse).
func _refresh_purse() -> void:
	if purse_of.is_valid():
		purse = int(purse_of.call(tender))
	queue_redraw()


func _choose(i: int) -> void:
	if i < 0 or i >= _catalogue().size():
		return
	index = i
	if grace <= 0.0:
		_buy()


func _buy() -> void:
	var item: Dictionary = _catalogue()[index]
	if not _available(item):
		purchase_result(str(item["id"]), false)
		return
	buy_requested.emit(str(item["id"]), int(item["price"]), tender)


## The host reports the purchase outcome back so the panel can answer with leather and brass.
func purchase_result(item_id: String, ok: bool) -> void:
	var item: Dictionary = Ep2ArmoryState.shop_item(item_id)
	if ok:
		flash = "SOLD"
	elif not item.is_empty() and purse < int(item["price"]):
		flash = "NOT ENOUGH CRYPTO"
	else:
		flash = "NOT FOR SALE"
	_flash_t = 1.4
	queue_redraw()


func _owned(item: Dictionary) -> bool:
	var id: String = str(item["id"])
	match id:
		"sniper":
			return state != null and state.sniper_owned
		"river_gear":
			return state != null and state.river_gear
		"rifle_ammo":
			return state != null and state.owns(Ep2ArmoryState.WIN) and (state.firearm(Ep2ArmoryState.WIN) as Ep2Winchester).reserve >= Ep2ArmoryState.RESERVE_CAP
		"revolver_ammo":
			return state != null and state.owns(Ep2ArmoryState.REM) and (state.firearm(Ep2ArmoryState.REM) as Ep2Winchester).reserve >= Ep2ArmoryState.RESERVE_CAP
		"sniper_ammo":
			return state != null and state.sniper_rounds >= Ep2ArmoryState.RESERVE_CAP
	return false


func _available(item: Dictionary) -> bool:
	var id: String = str(item["id"])
	if state == null:
		return false
	if _owned(item):
		return false
	if id == "sniper_ammo" and not state.sniper_owned:
		return false
	if id == "rifle_ammo" and not state.owns(Ep2ArmoryState.WIN):
		return false
	if id == "revolver_ammo" and not state.owns(Ep2ArmoryState.REM):
		return false
	return purse >= int(item["price"])


func _process(delta: float) -> void:
	grace = maxf(0.0, grace - delta)
	if _flash_t > 0.0:
		_flash_t = maxf(0.0, _flash_t - delta)
		if _flash_t == 0.0:
			flash = ""
	var view: Vector2 = get_viewport_rect().size
	var ui: float = view.x / 390.0 if view.x / view.y < 1.1 else 1.0
	scale = Vector2.ONE * ui
	size = view / ui
	for i in _rows.size():
		_rows[i].position = row_rect(i).position
		_rows[i].size = row_rect(i).size
	queue_redraw()


func row_rect(i: int) -> Rect2:
	var compact: bool = size.x < 650.0
	var w: float = minf(560.0 if compact else 700.0, size.x - 40.0)
	var h: float = minf(64.0, size.y * 0.085)
	var x: float = (size.x - w) * 0.5
	var y0: float = size.y * 0.30
	return Rect2(Vector2(x, y0 + i * (h + 10.0)), Vector2(w, h))


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
	for p in [rect.position + Vector2(16, 16), Vector2(rect.end.x - 16, rect.position.y + 16), rect.end - Vector2(16, 16), Vector2(rect.position.x + 16, rect.end.y - 16)]:
		draw_circle(p, 3, BRASS)
		draw_circle(p + Vector2(-0.7, -0.7), 1, PAPER)


func _draw() -> void:
	if state == null:
		return
	var rows: Array = _catalogue()
	var compact: bool = size.x < 650.0
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.035, 0.024, 0.016, 0.86))
	var mid: float = size.x * 0.5
	var top: float = size.y * 0.075
	_text("RICH & UTAH", Vector2(mid, top - 12), 14 if compact else 18, BRASS, true)
	_text("ARMS", Vector2(mid, top + (22 if compact else 34)), 25 if compact else 40, PAPER, true)
	var line_y: float = top + (44 if compact else 58)
	draw_line(Vector2(mid - minf(220, size.x * 0.34), line_y), Vector2(mid - 14, line_y), BRASS, 1)
	draw_line(Vector2(mid + 14, line_y), Vector2(mid + minf(220, size.x * 0.34), line_y), BRASS, 1)
	draw_colored_polygon(PackedVector2Array([Vector2(mid, line_y - 5), Vector2(mid + 5, line_y), Vector2(mid, line_y + 5), Vector2(mid - 5, line_y)]), BRASS)
	_text("PAY WITH  ◂ %s ▸  ·  YOU HOLD %d" % [TENDER_NAMES.get(tender, tender.to_upper()), purse],
		Vector2(mid, line_y + (14 if compact else 20)), 11 if compact else 14, BRASS, true)
	for i in rows.size():
		var item: Dictionary = rows[i]
		var rect: Rect2 = row_rect(i)
		var picked: bool = i == index
		var owned: bool = _owned(item)
		var can: bool = _available(item)
		_leather(rect, LEATHER if picked else LEATHER_DIM, picked)
		var left: float = rect.position.x + 16
		var cy: float = rect.get_center().y
		_text(str(item["name"]), Vector2(left, cy - 4), 15 if compact else 18, PAPER if can or owned else CLOSED)
		_text(str(item["note"]), Vector2(left, cy + 16), 10 if compact else 12, BRASS)
		var right: float = rect.end.x - 16
		var label: String = "OWNED" if owned else "NOT ENOUGH CRYPTO" if purse < int(item["price"]) else "%d %s" % [int(item["price"]), TENDER_NAMES.get(tender, tender.to_upper())]
		var ls: int = FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		_text(label, Vector2(right - ls, cy + 6), 14, BRASS if can else CLOSED)
	var footer: float = row_rect(rows.size() - 1).end.y + 24
	_text("RICH KEEPS THE BOOK  ·  UTAH HAULS THE CRATES", Vector2(mid, footer), 11, BRASS, true)
	_text("NO FREE IRON IN THIS TOWN", Vector2(mid, footer + 19), 11, PAPER, true)
	if flash != "":
		_text(flash, Vector2(mid, footer + 44), 14, BRASS, true)
	if TouchUi.keys_shown():
		_text("Up / Down choose  ·  E or Enter buy  ·  × close", Vector2(mid, size.y - 24), 10 if compact else 12, BRASS, true)


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event.is_action_pressed("ui_down") or event.is_action_pressed("move_down"):
		index = (index + 1) % _catalogue().size()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("move_up"):
		index = (index + _catalogue().size() - 1) % _catalogue().size()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		var k: int = 1 if event.is_action_pressed("ui_right") else -1
		tender = TENDERS[(TENDERS.find(tender) + k + TENDERS.size()) % TENDERS.size()]
		_refresh_purse()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		if grace <= 0.0:
			_buy()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		for i in _rows.size():
			if _rows[i].get_global_rect().has_point((event as InputEventMouseMotion).position):
				index = i
