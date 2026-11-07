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
var _tender_btn: Button = null
## The panel's words (the Chill Bud patch reuses this cabinet with its own).
var heading_small: String = "RICH & UTAH"
var heading: String = "ARMS"
var footer_a: String = "RICH KEEPS THE BOOK  ·  UTAH HAULS THE CRATES"
var footer_b: String = "NO FREE IRON IN THIS TOWN"

## THE SHOWCASE (founder 2026-11-01: "I want the weapons ... to appear and spin slowly in the form of a showcase when it is
## highlighted"). The highlighted row's gun turns slowly in a lit display case beside the list (above it on a phone): its own
## SubViewport world, a warm case light, one revolution about every eleven seconds with a slight tilt. It swaps the moment the
## highlight moves, and stops rendering while the panel is closed.
const SHOWCASE_SPEED := 0.55                 # rad/s
const SHOWCASE_TILT := 0.16
const WINCHESTER_MODEL := "res://src/episode2/assets/weapons/winchester_1886_founder.glb"   # his GM lever rifle
const REMINGTON_MODEL := "res://src/episode2/assets/weapons/armory/remington_1875_gold.glb"
var showcase_key: String = ""                # which model is in the case now ("" = empty case); tests read it
var showcase_spin: float = 0.0               # radians the current piece has turned
var _case_box: SubViewportContainer = null
var _case_vp: SubViewport = null
var _case_turn: Node3D = null
var _case_piece: Node3D = null
var _case_cam: Camera3D = null
var _case_min_z: float = 0.72                # the nearest the camera may come and still show the whole piece
## THE WEAPON TABS (founder 2026-11-03): one tab per gun model he supplied, across the top of the counter. A tab puts its model in the case
## and moves the highlight to the row that sells that gun; it never buys. Two tabs are the same guns held in Lil Blunt's hands, so they share
## a row with their gun-only tab. `yaw` lays the model along the barrel axis the case expects.
const TAB_DIR := Ep2Extras.SHOWCASE_DIR
const WEAPON_TABS: Array = [
	{"key": Ep2ArmoryState.BUFF, "label": "SHARPS", "row": Ep2ArmoryState.SHARPS_ITEM, "model": TAB_DIR + "sharps.glb", "yaw": PI * 0.25},
	{"key": Ep2ArmoryState.WIN, "label": "WINCHESTER", "row": Ep2ArmoryState.WIN, "model": TAB_DIR + "winchester_1886.glb", "yaw": PI * 0.5},
	{"key": Ep2ArmoryState.REM, "label": "REMINGTON", "row": Ep2ArmoryState.REM, "model": TAB_DIR + "gold_remington.glb", "yaw": PI * 0.5},
	{"key": Ep2ArmoryState.BORCH, "label": "BORCHARDT", "row": Ep2ArmoryState.BORCH, "model": TAB_DIR + "borchardt.glb", "yaw": PI * 0.5},
	{"key": Ep2ArmoryState.BORCH + "_held", "label": "HELD C93", "row": Ep2ArmoryState.BORCH, "model": TAB_DIR + "borchardt_held.glb", "yaw": PI * 0.5},
	{"key": Ep2ArmoryState.SHOT, "label": "COACH GUN", "row": Ep2ArmoryState.SHOT, "model": TAB_DIR + "coach_shotgun.glb", "yaw": PI * 0.5},
	{"key": Ep2ArmoryState.MP18, "label": "MACHINE GUN", "row": Ep2ArmoryState.MP18, "model": TAB_DIR + "machine_gun.glb", "yaw": PI * 0.5},
	{"key": Ep2ArmoryState.TOMMY, "label": "GOLD TOMMY", "row": Ep2ArmoryState.TOMMY, "model": TAB_DIR + "golden_tommy.glb", "yaw": PI * 0.5},
	{"key": Ep2ArmoryState.TOMMY + "_held", "label": "HELD TOMMY", "row": Ep2ArmoryState.TOMMY, "model": TAB_DIR + "golden_tommy_held.glb", "yaw": PI * 0.5},
	# His own miner's pick in his glove (founder's Verdant War Pick). Nobody sells it, so it has no row: the tab only fills the case.
	{"key": Ep2ArmoryState.PICK, "label": "PICKAXE", "row": "", "model": TAB_DIR + "war_pick_held.glb", "yaw": 0.0},
]
## THE MYSTERY RULE (founder 2026-11-07): a tab shows only what Lil Blunt has in hand now. A gun he never bought, or one the Sheriff holds,
## has no tab, and nothing names it; buying it (or buying it back) reveals the tab. A tab whose model is not loadable never shows as a blank.
const TAB_WIDE_MIN := 600.0                  # from this width the tabs are one strip; narrower they stack three across
const TAB_GAP := 4.0
var _tab_btns: Array[Button] = []
var _tab_key: String = ""                    # the tab chosen by hand, while the highlight stays on its row
var _tab_index: int = -1                     # the row that was highlighted when a row-less tab (the pickaxe) was chosen
const CASE_CAPTION := 20.0                   # the strip under the turning gun where its name is written
## A short screen (a phone held sideways) cannot show all eleven rows at a readable height: the list becomes a window that keeps the
## highlighted row in view, with brass up/down buttons (a finger), the mouse wheel and Up/Down (the keys) moving through it.
const MIN_ROW := 40.0
const MIN_ROW_SHORT := 34.0                  # a phone held sideways (under 520 units tall)
const ARROW_H := 26.0
const SIDE_CASE_MIN_W := 700.0               # from this width the case sits beside the list, not above it
var _scroll: int = 0
var _up_btn: Button = null
var _down_btn: Button = null


func _catalogue() -> Array:
	return Ep2ArmoryState.SHOP


## This panel's weapon tabs as the player sees them now: only the ones he owns (the Chill Bud patch has none).
func _tabs() -> Array:
	var out: Array = []
	for tab in WEAPON_TABS:
		if tab_owned(state, tab) and Ep2Extras.has(str(tab["model"])):
			out.append(tab)
	return out


## Does Lil Blunt have this tab's weapon in hand now? The pickaxe always (his own tool: never bought, never kept by the Sheriff, who hands
## it back with "Take your pick"); a gun only while he owns it and the Sheriff is not holding it. A "_held" tab follows its gun.
static func tab_owned(armory_state: Ep2ArmoryState, tab: Dictionary) -> bool:
	var id: String = str(tab["key"]).trim_suffix("_held")
	if id == Ep2ArmoryState.PICK:
		return true
	return armory_state != null and armory_state.owns(id) and not armory_state.is_held(id)


## Why a row is locked, in the counter's words ("" = it is not).
func _lock_note(id: String) -> String:
	return Ep2ArmoryState.lock_note(state, id)


func _tab_for_key(key: String) -> Dictionary:
	for tab in _tabs():
		if str(tab["key"]) == key:
			return tab
	return {}


## Choose a tab: its model goes in the case and the highlight moves to the row that sells it. Looking is free, so this never buys.
func show_tab(i: int) -> void:
	var tabs: Array = _tabs()
	if i < 0 or i >= tabs.size():
		return
	if str(tabs[i]["row"]) == "":
		_tab_key = str(tabs[i]["key"])             # no row sells it (the pickaxe): the case shows it while the highlight stays put
		_tab_index = index
		_sync_showcase()
		return
	var rows: Array = _catalogue()
	for r in rows.size():
		if str(rows[r]["id"]) == str(tabs[i]["row"]):
			index = r
			_tab_key = str(tabs[i]["key"])
			_sync_showcase()
			return


## The tab whose model is in the case now (-1 = none).
func active_tab() -> int:
	var tabs: Array = _tabs()
	for i in tabs.size():
		if str(tabs[i]["key"]) == showcase_key:
			return i
	return -1


## One row of this panel's stock by id ({} when it is not sold here).
func _item(id: String) -> Dictionary:
	return Ep2ArmoryState.shop_item(id)


## The showcase key for a row: the gun itself, the gun its ammunition feeds, or "" for gear with no gun.
func _showcase_key_for(item: Dictionary) -> String:
	var id: String = str(item["id"])
	if Ep2ArmoryState.SHOP_GUNS.has(id):
		return id
	if Ep2ArmoryState.SHOP_AMMO.has(id):
		return str(Ep2ArmoryState.SHOP_AMMO[id])
	if id == Ep2ArmoryState.GATE_ITEM:
		return Ep2ArmoryState.GATE_ITEM                    # the water gear has its own piece in the case (`_water_gear_model`)
	if id == "sniper" or id == "sniper_ammo":
		return Ep2ArmoryState.BUFF if Ep2ArmoryGunView.meshy(Ep2ArmoryState.BUFF) else "sniper"
	return ""


## A fresh instance of the showcase model for `key` (null = nothing to show).
func _showcase_model(key: String) -> Node3D:
	var tab: Dictionary = _tab_for_key(key)
	if not tab.is_empty() and Ep2Extras.has(str(tab["model"])):
		var laid := Node3D.new()                     # the streamed gun-only model, turned so it comes in broadside like the rest
		var gun: Node3D = (load(str(tab["model"])) as PackedScene).instantiate() as Node3D
		gun.rotation.y = float(tab["yaw"])
		laid.add_child(gun)
		return laid
	if Ep2ArmoryGunView.has_view(key):
		return Ep2ArmoryGunView.model(key)
	if key == Ep2ArmoryState.GATE_ITEM:
		return Ep2ShipmentCrate.model()                    # the same hero crate Tabs spins and the day-88 river carries
	var path: String = ""
	match key:
		Ep2ArmoryState.WIN:
			path = WINCHESTER_MODEL
		Ep2ArmoryState.REM:
			return Ep2RemingtonView.make_held()          # the founder's golden BTC revolver, gun only
		Ep2ArmoryState.BOW:
			path = Ep2ArmoryGunView.MESHY_BOW if Ep2Extras.has(Ep2ArmoryGunView.MESHY_BOW) else (Ep2Extras.BOW if Ep2Extras.has(Ep2Extras.BOW) else "")
		"sniper":
			path = Ep2Extras.SHARPS if Ep2Extras.has(Ep2Extras.SHARPS) else ""
	if path == "" or not ResourceLoader.exists(path):
		return null
	return (load(path) as PackedScene).instantiate() as Node3D


## The water & river gear as one readable display piece (no asset needed, so it always shows): a little plank skiff with an
## oar, two sealed crates lashed in it and a canteen with its strap - about a metre long, which the case fits anyway.
static func _water_gear_model() -> Node3D:
	var root := Node3D.new()
	root.name = "WaterGear"
	var wood := _mat(Color(0.46, 0.30, 0.17), 0.85)
	var dark := _mat(Color(0.28, 0.18, 0.10), 0.9)
	var tin := _mat(Color(0.62, 0.64, 0.62), 0.35, 0.8)
	var rope := _mat(Color(0.72, 0.62, 0.42), 0.95)
	_box(root, Vector3(1.0, 0.05, 0.36), Vector3(0.0, 0.0, 0.0), wood)                       # skiff floor
	_box(root, Vector3(1.0, 0.16, 0.04), Vector3(0.0, 0.08, 0.18), wood)                     # port side
	_box(root, Vector3(1.0, 0.16, 0.04), Vector3(0.0, 0.08, -0.18), wood)                    # starboard side
	_box(root, Vector3(0.04, 0.16, 0.36), Vector3(-0.5, 0.08, 0.0), dark)                    # transom
	var bow := _box(root, Vector3(0.22, 0.16, 0.26), Vector3(0.56, 0.08, 0.0), wood)        # pointed bow block
	bow.rotation.y = PI * 0.25
	_box(root, Vector3(0.05, 0.03, 0.36), Vector3(0.05, 0.15, 0.0), dark)                    # thwart
	_box(root, Vector3(0.24, 0.18, 0.2), Vector3(-0.26, 0.12, 0.0), dark)                    # sealed crate 1
	_box(root, Vector3(0.2, 0.15, 0.18), Vector3(0.28, 0.1, 0.02), dark)                     # sealed crate 2
	_box(root, Vector3(0.25, 0.02, 0.21), Vector3(-0.26, 0.215, 0.0), rope)                  # lashing
	var oar := _box(root, Vector3(0.9, 0.025, 0.035), Vector3(0.0, 0.2, 0.24), wood)
	oar.rotation.z = 0.08
	_box(root, Vector3(0.16, 0.015, 0.08), Vector3(0.48, 0.24, 0.24), wood)                 # oar blade
	var canteen := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.075
	cyl.bottom_radius = 0.075
	cyl.height = 0.05
	canteen.mesh = cyl
	canteen.material_override = tin
	canteen.rotation.x = PI * 0.5
	canteen.position = Vector3(0.05, 0.27, 0.0)
	root.add_child(canteen)
	_box(root, Vector3(0.02, 0.16, 0.012), Vector3(0.05, 0.37, 0.0), rope)                   # canteen strap
	return root


static func _mat(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m


static func _box(parent: Node3D, box_size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = box_size
	mi.mesh = bm
	mi.material_override = material
	mi.position = at
	parent.add_child(mi)
	return mi


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
	# The purse strip is the tender control on a phone: ui_left/ui_right have no touch button, so
	# a player holding ETH/SOL/WBTC read NOT ENOUGH CRYPTO on every row and could not fix it
	# (audit 2026-10-29 P1-1). A tap cycles the same `tender` variable the keys cycle.
	_tender_btn = Button.new()
	_tender_btn.name = "Tender"
	_tender_btn.flat = true
	_tender_btn.focus_mode = Control.FOCUS_NONE
	for style in ["normal", "hover", "pressed", "focus", "disabled"]:
		_tender_btn.add_theme_stylebox_override(style, StyleBoxEmpty.new())
	_tender_btn.pressed.connect(func() -> void: _cycle_tender(1))
	add_child(_tender_btn)
	move_child(_tender_btn, 0)                     # its finger-sized strip reaches under the first rows: a row or a tab wins where they overlap
	_ensure_tab_buttons()
	_up_btn = _arrow_button("ScrollUp", -1)
	_down_btn = _arrow_button("ScrollDown", 1)
	# Wordless way out for a finger: the trade pauses the tree, so Esc / ui_cancel is not
	# reachable on a phone and the counter used to be a softlock (audit 2026-10-29).
	# The shared close keeps raw-finger handling and the panel's own pause owner.
	preload("res://src/ui/panel_close.gd").install(self, func() -> void: closed.emit())
	_build_showcase()
	set_process(true)


## One button per tab he can see now. The list grows when a purchase reveals a tab (a button is never made for a tab that is not shown,
## so the Chill Bud patch has none); a button past the end of the list hides.
func _ensure_tab_buttons() -> void:
	for t in range(_tab_btns.size(), _tabs().size()):
		var tab_btn := Button.new()
		tab_btn.name = "WeaponTab%d" % t
		tab_btn.flat = true
		tab_btn.focus_mode = Control.FOCUS_NONE
		tab_btn.mouse_filter = Control.MOUSE_FILTER_PASS
		for style in ["normal", "hover", "pressed", "focus", "disabled"]:
			tab_btn.add_theme_stylebox_override(style, StyleBoxEmpty.new())
		tab_btn.pressed.connect(func() -> void: show_tab(t))
		add_child(tab_btn)
		_tab_btns.append(tab_btn)


func _arrow_button(label: String, step: int) -> Button:
	var b := Button.new()
	b.name = label
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	for style in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(style, StyleBoxEmpty.new())
	b.pressed.connect(func() -> void: page(step))
	b.visible = false
	add_child(b)
	return b


## Move the highlight one row past the visible window (up or down); the window follows it.
func page(step: int) -> void:
	var n: int = _catalogue().size()
	if step > 0:
		index = mini(n - 1, _scroll + rows_fit())
	else:
		index = maxi(0, _scroll - 1)
	_keep_visible()


func _keep_visible() -> void:
	var n: int = _catalogue().size()
	var fit: int = rows_fit()
	_scroll = clampi(_scroll, index - fit + 1, index)
	_scroll = clampi(_scroll, 0, maxi(0, n - fit))


func scrolling() -> bool:
	return rows_fit() < _catalogue().size()


func is_row_shown(i: int) -> bool:
	return i >= _scroll and i < _scroll + rows_fit()


func _build_showcase() -> void:
	_case_box = SubViewportContainer.new()
	_case_box.name = "Showcase"
	_case_box.stretch = true
	_case_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_case_box)
	_case_vp = SubViewport.new()
	_case_vp.own_world_3d = true
	_case_vp.size = Vector2i(480, 360)
	_case_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_case_box.add_child(_case_vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.16, 0.10, 0.06)
	sky_mat.sky_horizon_color = Color(0.36, 0.25, 0.15)
	sky_mat.ground_horizon_color = Color(0.30, 0.20, 0.12)
	sky_mat.ground_bottom_color = Color(0.07, 0.045, 0.03)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.66, 0.52)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	_case_vp.add_child(world_env)
	var cam := Camera3D.new()
	_case_cam = cam
	cam.fov = 38.0
	cam.position = Vector3(0.0, 0.12, 1.55)
	cam.rotation.x = -0.075
	cam.current = true
	_case_vp.add_child(cam)
	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.86, 0.66)
	key.light_energy = 1.6
	key.rotation = Vector3(-0.7, 0.55, 0.0)
	_case_vp.add_child(key)
	var rim := OmniLight3D.new()
	rim.light_color = Color(1.0, 0.78, 0.48)
	rim.light_energy = 1.3
	rim.omni_range = 4.0
	rim.position = Vector3(-0.9, 0.7, -0.8)
	_case_vp.add_child(rim)
	var tilt := Node3D.new()
	tilt.rotation.x = SHOWCASE_TILT
	_case_vp.add_child(tilt)
	_case_turn = Node3D.new()
	_case_turn.name = "Turntable"
	tilt.add_child(_case_turn)


## Put the highlighted row's piece in the case (only when it changes), fitted to about a metre and centred on the turntable.
func _sync_showcase() -> void:
	var rows: Array = _catalogue()
	var key: String = _showcase_key_for(rows[index]) if index >= 0 and index < rows.size() else ""
	if _tab_key != "":
		var chosen: Dictionary = _tab_for_key(_tab_key)
		if not chosen.is_empty() and str(chosen["row"]) == "" and index == _tab_index:
			key = _tab_key
		elif not chosen.is_empty() and index >= 0 and index < rows.size() and str(chosen["row"]) == str(rows[index]["id"]):
			key = _tab_key
		else:
			_tab_key = ""                            # the highlight moved on to another row
	if key == showcase_key and (_case_piece != null or key == ""):
		return
	showcase_key = key
	showcase_spin = 0.0
	if _case_turn == null:
		return
	_case_turn.rotation.y = PI * 0.5           # it comes in broadside (muzzle to the left), then turns
	if _case_piece != null:
		_case_piece.queue_free()
		_case_piece = null
	var piece: Node3D = _showcase_model(key) if key != "" else null
	if piece == null:
		return
	var holder := Node3D.new()
	holder.add_child(piece)
	var bb: AABB = _bounds(piece)
	# fitted by its diagonal: a long gun is about the size it always was, and a bulky piece (the crate, a bush) still clears the case as it turns
	var s: float = 1.0 / maxf(bb.size.length(), 0.01)
	holder.scale = Vector3.ONE * s
	_case_min_z = maxf(0.72, bb.size.y * s * 0.5 / tan(deg_to_rad(_case_cam.fov * 0.5)) * 1.15 + 0.25)
	piece.position = -bb.get_center()
	_case_turn.add_child(holder)
	_case_piece = holder


static func _bounds(root: Node3D) -> AABB:
	var out := AABB()
	var first: bool = true
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var xf := Transform3D.IDENTITY
		var c: Node = m
		while c != null and c != root:
			if c is Node3D:
				xf = (c as Node3D).transform * xf
			c = c.get_parent()
		var b: AABB = xf * m.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out if not first else AABB(Vector3(-0.5, -0.1, -0.5), Vector3(1, 0.2, 1))


## Where the display case sits: right of the list on a wide screen, above it on a phone.
func showcase_rect() -> Rect2:
	var compact: bool = size.x < SIDE_CASE_MIN_W
	if compact:
		var w: float = minf(560.0, size.x - 40.0)
		var h: float = minf(200.0, size.y * (0.17 if _short() or not _tabs().is_empty() else 0.21))
		return Rect2(Vector2((size.x - w) * 0.5, _list_top_base()), Vector2(w, h))
	var list_w: float = _list_width()
	var case_w: float = minf(420.0, size.x * 0.34)
	var left: float = (size.x - list_w - 18.0 - case_w) * 0.5
	var case_h: float = minf(case_w * 0.78, size.y * 0.93 - _list_top_base() - 30.0)
	return Rect2(Vector2(left + list_w + 18.0, _list_top_base()), Vector2(case_w, case_h))


## Host calls this before showing the panel.
func open_shop(armory_state: Ep2ArmoryState, coin_purse: int) -> void:
	state = armory_state
	purse = coin_purse
	if purse_of.is_valid():
		purse = int(purse_of.call(tender))
	index = 0
	grace = 0.25
	flash = ""
	_ensure_tab_buttons()                       # his tabs are touchable the frame the counter opens
	show()
	if _case_vp != null:
		_case_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sync_showcase()


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
	var item: Dictionary = _item(item_id)
	if ok:
		flash = "SOLD"
	elif not item.is_empty() and _lock_note(item_id) != "":
		flash = "BUY " + _lock_note(item_id).replace(" FIRST", "") + " FIRST"
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
			return state != null and state.sniper_owned and not state.is_held(Ep2ArmoryState.BUFF)
		"river_gear":
			return state != null and state.river_gear
		"sniper_ammo":
			return state != null and state.sniper_rounds >= Ep2ArmoryState.RESERVE_CAP
	if Ep2ArmoryState.SHOP_GUNS.has(id):
		return state != null and state.owns(id) and not state.is_held(id)     # held by the Sheriff -> for sale again
	if Ep2ArmoryState.SHOP_AMMO.has(id):
		var gun_id: String = str(Ep2ArmoryState.SHOP_AMMO[id])
		return state != null and state.owns(gun_id) and (state.firearm(gun_id) as Ep2Winchester).reserve >= Ep2ArmoryState.RESERVE_CAP
	return false


func _available(item: Dictionary) -> bool:
	var id: String = str(item["id"])
	if state == null:
		return false
	if _owned(item):
		return false
	if _lock_note(id) != "":
		return false                                       # the Shipment, then the Sharps (founder 2026-11-03)
	if id == "sniper_ammo" and not state.sniper_owned:
		return false
	if Ep2ArmoryState.SHOP_AMMO.has(id) and not state.owns(str(Ep2ArmoryState.SHOP_AMMO[id])):
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
	if _tender_btn != null:
		var compact: bool = size.x < 650.0 or _short()
		var tw: float = maxf(80.0, minf(560.0 if compact else 700.0, size.x - 80.0))
		var line_y: float = size.y * 0.075 + (44.0 if compact else 58.0)
		_tender_btn.size = Vector2(tw, 88.0)
		_tender_btn.position = Vector2((size.x - tw) * 0.5, line_y - 8.0)
	_keep_visible()
	_ensure_tab_buttons()
	var shown_tabs: int = _tabs().size()
	for t in _tab_btns.size():
		_tab_btns[t].visible = t < shown_tabs
		var tab_r: Rect2 = tab_rect(t)
		_tab_btns[t].position = tab_r.position
		_tab_btns[t].size = tab_r.size
	for i in _rows.size():
		_rows[i].position = row_rect(i).position
		_rows[i].size = row_rect(i).size
		_rows[i].visible = is_row_shown(i)
	var arrows: bool = scrolling()
	if _up_btn != null:
		var top_row: Rect2 = row_rect(_scroll)
		_up_btn.visible = arrows and _scroll > 0
		_up_btn.position = Vector2(top_row.position.x, top_row.position.y - ARROW_H - 4.0)
		_up_btn.size = Vector2(top_row.size.x, ARROW_H)
		var last_row: Rect2 = row_rect(mini(_catalogue().size() - 1, _scroll + rows_fit() - 1))
		_down_btn.visible = arrows and _scroll + rows_fit() < _catalogue().size()
		_down_btn.position = Vector2(last_row.position.x, last_row.end.y + 4.0)
		_down_btn.size = Vector2(last_row.size.x, ARROW_H)
	if _case_box != null:
		var live: bool = is_visible_in_tree()
		_case_box.visible = live and showcase_key != ""
		if _case_vp != null:
			_case_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if _case_box.visible else SubViewport.UPDATE_DISABLED
		if live:
			_sync_showcase()
			var r: Rect2 = showcase_rect().grow(-8.0)
			r.size.y = maxf(24.0, r.size.y - CASE_CAPTION)
			_case_box.position = r.position
			_case_box.size = r.size
			if _case_cam != null:
				# frame a metre-long gun in any case shape: far enough that it spans the width, never closer than its height allows
				var aspect: float = r.size.x / maxf(r.size.y, 1.0)
				_case_cam.position.z = maxf(1.75 / maxf(aspect, 0.1), _case_min_z)
			if _case_turn != null and _case_piece != null:
				showcase_spin += SHOWCASE_SPEED * delta
				_case_turn.rotation.y += SHOWCASE_SPEED * delta
	queue_redraw()


## The list's left edge, width and first row: beside the showcase on a wide screen, under it on a phone.
func _list_width() -> float:
	if size.x < SIDE_CASE_MIN_W:
		return minf(560.0, size.x - 40.0)
	return minf(560.0, size.x * 0.52 - 40.0)


func _short() -> bool:
	return size.y < 520.0


## The top of the tabs: the heading and the purse line end here.
func _tabs_top() -> float:
	if _short():
		return size.y * 0.075 + 44.0 + 30.0          # the compact heading + the purse line, then the list
	return size.y * 0.075 + (44.0 if size.x < 650.0 else 58.0) + 34.0


## Columns are sized for the whole set (one strip on a wide screen), so a tab keeps its width as purchases add tabs beside it.
func _tab_columns() -> int:
	return WEAPON_TABS.size() if size.x >= TAB_WIDE_MIN else 3


func _tab_height() -> float:
	return 26.0 if _short() or _tab_columns() < WEAPON_TABS.size() else 32.0


## The height the tabs take, with the gap under them (0 when this panel has none).
func tabs_height() -> float:
	var n: int = _tabs().size()
	if n == 0:
		return 0.0
	var rows: int = int(ceil(float(n) / float(_tab_columns())))
	return float(rows) * _tab_height() + float(rows - 1) * TAB_GAP + 8.0


func tab_rect(i: int) -> Rect2:
	var total: float = minf(1000.0, size.x - 40.0)
	var cols: int = maxi(1, _tab_columns())
	var w: float = (total - TAB_GAP * float(cols - 1)) / float(cols)
	var in_row: int = mini(cols, _tabs().size() - (i / cols) * cols)        # a short row (few owned) sits centred
	var x: float = (size.x - total) * 0.5 + float(cols - maxi(in_row, 1)) * (w + TAB_GAP) * 0.5 + float(i % cols) * (w + TAB_GAP)
	var y: float = _tabs_top() + float(i / cols) * (_tab_height() + TAB_GAP)
	return Rect2(Vector2(x, y), Vector2(w, _tab_height()))


func _list_top_base() -> float:
	return _tabs_top() + tabs_height()


func _list_top() -> float:
	if size.x < SIDE_CASE_MIN_W:
		return showcase_rect().end.y + 10.0
	return _list_top_base()


func _list_available() -> float:
	return size.y * 0.93 - _list_top() - (36.0 if _short() else 64.0)


func _min_row() -> float:
	return MIN_ROW_SHORT if _short() else MIN_ROW


## How many rows show at once: all of them when each can be at least MIN_ROW tall, otherwise a window (room kept for the arrows).
func rows_fit() -> int:
	var n: int = maxi(1, _catalogue().size())
	var available: float = _list_available()
	if (available - 8.0 * float(n - 1)) / float(n) >= _min_row():
		return n
	return clampi(int(floor((available - 2.0 * (ARROW_H + 4.0) + 8.0) / (_min_row() + 8.0))), 1, n)


func _row_height() -> float:
	var n: int = maxi(1, _catalogue().size())
	if rows_fit() < n:
		return _min_row()
	return clampf((_list_available() - 8.0 * float(n - 1)) / float(n), _min_row(), 64.0)


func row_rect(i: int) -> Rect2:
	var w: float = _list_width()
	var h: float = _row_height()
	var x: float = (size.x - w) * 0.5
	if size.x >= SIDE_CASE_MIN_W:
		var case_w: float = minf(420.0, size.x * 0.34)
		x = (size.x - w - 18.0 - case_w) * 0.5
	var top: float = _list_top() + ((ARROW_H + 4.0) if scrolling() else 0.0)
	return Rect2(Vector2(x, top + float(i - _scroll) * (h + 8.0)), Vector2(w, h))


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
	var compact: bool = size.x < 650.0 or _short()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.035, 0.024, 0.016, 0.86))
	var mid: float = size.x * 0.5
	var top: float = size.y * 0.075
	_text(heading_small, Vector2(mid, top - 12), 14 if compact else 18, BRASS, true)
	_text(heading, Vector2(mid, top + (22 if compact else 34)), 25 if compact else 40, PAPER, true)
	var line_y: float = top + (44 if compact else 58)
	draw_line(Vector2(mid - minf(220, size.x * 0.34), line_y), Vector2(mid - 14, line_y), BRASS, 1)
	draw_line(Vector2(mid + 14, line_y), Vector2(mid + minf(220, size.x * 0.34), line_y), BRASS, 1)
	draw_colored_polygon(PackedVector2Array([Vector2(mid, line_y - 5), Vector2(mid + 5, line_y), Vector2(mid, line_y + 5), Vector2(mid - 5, line_y)]), BRASS)
	_text("PAY WITH  ◂ %s ▸  ·  YOU HOLD %d" % [TENDER_NAMES.get(tender, tender.to_upper()), purse],
		Vector2(mid, line_y + (14 if compact else 20)), 11 if compact else 14, BRASS, true)
	var picked_tab: int = active_tab()
	var tabs: Array = _tabs()
	for t in tabs.size():
		var tab_r: Rect2 = tab_rect(t)
		var box := StyleBoxFlat.new()
		box.bg_color = LEATHER if t == picked_tab else LEATHER_DIM
		box.border_color = BRASS if t == picked_tab else Color("765839")
		box.set_border_width_all(2 if t == picked_tab else 1)
		box.set_corner_radius_all(6)
		draw_style_box(box, tab_r)
		var tab_font: int = 9 if tab_r.size.x < 80.0 else (10 if compact else 12)
		# every tab is a weapon he has (the mystery rule), so none is drawn as locked, whatever the counter's chain says about its row
		_text(str(tabs[t]["label"]), Vector2(tab_r.get_center().x, tab_r.get_center().y + float(tab_font) * 0.36), tab_font, PAPER, true)
	if showcase_key != "":
		var case_rect: Rect2 = showcase_rect()
		_leather(case_rect, LEATHER_DIM, true)
		var shown: String = ""
		var shown_tab: Dictionary = _tab_for_key(showcase_key)
		if not shown_tab.is_empty() and str(shown_tab["row"]) == "":
			shown = str(shown_tab["label"]) + "  ·  IN HAND"           # sold nowhere: named by its tab, never by the highlighted row
		elif index >= 0 and index < rows.size():
			shown = str(rows[index]["name"])
			if showcase_key.ends_with("_held"):
				shown += "  ·  IN HAND"
		_text(shown, Vector2(case_rect.get_center().x, case_rect.end.y - 9.0), 11 if compact else 13, BRASS, true)
	var tall: bool = _row_height() >= 48.0
	if scrolling():
		if _scroll > 0:
			_text("▲  MORE", Vector2(mid, row_rect(_scroll).position.y - 10.0), 12, BRASS, true)
		if _scroll + rows_fit() < rows.size():
			_text("▼  MORE", Vector2(mid, row_rect(_scroll + rows_fit() - 1).end.y + 20.0), 12, BRASS, true)
	for i in rows.size():
		if not is_row_shown(i):
			continue
		var item: Dictionary = rows[i]
		var rect: Rect2 = row_rect(i)
		var picked: bool = i == index
		var owned: bool = _owned(item)
		var can: bool = _available(item)
		_leather(rect, LEATHER if picked else LEATHER_DIM, picked)
		var left: float = rect.position.x + 16
		var cy: float = rect.get_center().y
		_text(str(item["name"]), Vector2(left, cy - (4.0 if tall else 1.0)), (15 if compact else 18) if tall else (13 if compact else 15), PAPER if can or owned else CLOSED)
		_text(str(item["note"]), Vector2(left, cy + (16.0 if tall else 12.0)), (10 if compact else 12) if tall else 9, BRASS)
		var right: float = rect.end.x - 16
		var label: String = "OWNED" if owned else _lock_note(str(item["id"])) if _lock_note(str(item["id"])) != "" \
			else "NOT ENOUGH CRYPTO" if purse < int(item["price"]) else "%d %s" % [int(item["price"]), TENDER_NAMES.get(tender, tender.to_upper())]
		var ls: int = FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		_text(label, Vector2(right - ls, cy + 6), 14, BRASS if can else CLOSED)
	var footer: float = row_rect(mini(rows.size() - 1, _scroll + rows_fit() - 1)).end.y + (24.0 + ARROW_H if scrolling() else 24.0)
	if _short():
		# a short screen keeps only what matters under the list: the sale's answer (the hint line stays at the bottom)
		if flash != "":
			_text(flash, Vector2(mid, footer), 14, BRASS, true)
	else:
		# a short list ends beside the case: its lines sit under the list, not behind the case
		var foot_x: float = row_rect(0).get_center().x if size.x >= SIDE_CASE_MIN_W and footer + 40.0 < showcase_rect().end.y else mid
		_text(footer_a, Vector2(foot_x, footer), 11, BRASS, true)
		_text(footer_b, Vector2(foot_x, footer + 19), 11, PAPER, true)
		if flash != "":
			_text(flash, Vector2(foot_x, footer + 44), 14, BRASS, true)
	_text("Up / Down choose  ·  E or Enter buy  ·  Esc leave" if TouchUi.keys_shown() else "Tap an item to buy",
		Vector2(mid, size.y - 24), 10 if compact else 12, BRASS, true)


## One step through the tender ring. The keyboard's ui_left/ui_right and the tappable purse
## strip both land here, so there is exactly one place that decides what a step means.
func _cycle_tender(k: int) -> void:
	tender = TENDERS[(TENDERS.find(tender) + k + TENDERS.size()) % TENDERS.size()]
	_refresh_purse()


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
		_cycle_tender(1 if event.is_action_pressed("ui_right") else -1)
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
			if _rows[i].visible and _rows[i].get_global_rect().has_point((event as InputEventMouseMotion).position):
				index = i
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and scrolling():
		var wheel: int = (event as InputEventMouseButton).button_index
		if wheel == MOUSE_BUTTON_WHEEL_DOWN or wheel == MOUSE_BUTTON_WHEEL_UP:
			index = clampi(index + (1 if wheel == MOUSE_BUTTON_WHEEL_DOWN else -1), 0, _catalogue().size() - 1)
			get_viewport().set_input_as_handled()
