class_name Ep2FpsHud
extends Control
## The first-person HUD of the hideout/range (founder 2026-10-04: "nothing like Modern Warfare"). One full-rect
## Control that draws everything itself so it works in the web build with no theme and no extra textures:
##  * a dynamic crosshair whose gap widens with the weapon's spread (ticks while hip, a small dot when aimed down
##    the sights, as in Call of Duty),
##  * a hit marker (white X; red when a target went down),
##  * the ammo counter (magazine / reserve, big, bottom right) with a RELOAD flag when empty,
##  * an objective strip (top left): the lesson step, with the key to press highlighted,
##  * a toast line (centre, lower) for short messages ("RELOAD - R"),
##  * an ADS vignette that darkens the screen edges when aimed.
## State is pushed in by the facility each frame; nothing here reads gameplay nodes. Skill: ep2-fps-shooter-feel.

const GOLD := Color(1.0, 0.86, 0.45)
const WHITE := Color(1, 1, 1, 0.95)
## WORDLESS icons for a touch device (founder 2026-10-13: a phone has no keys and no written words). Drawn with primitives, so they
## exist in the web build with no texture and no font: a step of the range lesson, a toast. A desktop keeps its words.
enum Token { NONE, BOOT, EYE, CYLINDER, SCOPE, BURST, TARGETS, EMPTY, HEAT, RETRY }
## The range lesson as a path of icons, in the order it is taught: walk to the line, watch, load, aim, fire, clear the plates.
const LESSON_PATH: Array[int] = [Token.BOOT, Token.EYE, Token.CYLINDER, Token.SCOPE, Token.BURST, Token.TARGETS]
signal weapon_selected(id: String)
signal armory_requested
signal search_requested
## The open Tabs panel asks its room to use one of Dude's Chill Buds. The room
## owns health and decides whether a bud can actually be spent.
signal chill_bud_requested
var armory: Ep2ArmoryState = null
var armory_open: bool = false
var armory_enabled: bool = true
var _slots: Array[Button] = []
var _quick: GridContainer = null
var _panel: Ep2WeaponSelector = null
var _search: Button = null
var _mouse_before: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _finger_on: Dictionary = {}
var _last_activation_frame: int = -1
var _hold_button: Button
var _owns_pause: bool = false
var _hold_finger: int = -1
var _hold_mouse: bool = false
var _selector_layer: CanvasLayer

var spread_deg: float = 2.6
var ads: float = 0.0
var rounds: int = 0
var reserve: int = 0
var mag: int = 4
var objective: String = ""
var step_index: int = 0
var step_total: int = 0
## The current lesson step as an icon (a Token), its number (rounds loaded / targets left; -1 = none) and an optional "of N".
## Pushed by the room every frame next to `objective`; only a touch device draws these instead of the words.
var lesson_token: int = Token.NONE
var lesson_count: int = -1
var lesson_count_max: int = -1
var toast_text: String = ""
var toast_token: int = Token.NONE
## Every string the LAST `_draw` wrote (tests read it: the wordless gate cannot look at pixels headless).
var drawn_texts: Array[String] = []
var _toast_t: float = 0.0
var _hit_t: float = 0.0
var _hit_kill: bool = false
var _font: Font = null
var _vignette: TextureRect = null
var show_ammo: bool = true
var show_crosshair: bool = true
## Hearts (bottom left) + the red hurt flash: only shown while something in the room can hurt (the lava river).
var health: int = 3
var health_max: int = 3
var show_health: bool = false
var _hurt_t: float = 0.0
## Fade to black and back (a seat change, a cut): 0 clear .. 1 black. `fade_to` ramps it; drawn over everything.
var fade: float = 0.0
var _fade_goal: float = 0.0
var _fade_rate: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Sized by hand from the viewport every frame: anchors under a CanvasLayer resolved to a 0x0 rect in the
	# headless-free capture rig, which drew nothing (the first lesson capture had no crosshair, ammo or prompt).
	position = Vector2.ZERO
	_fit()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	# the ADS vignette: transparent centre -> dark edge, shown at `ads` strength
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.78)])
	g.offsets = PackedFloat32Array([0.0, 0.52, 1.0])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 256
	gt.height = 256
	_vignette = TextureRect.new()
	_vignette.texture = gt
	_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.modulate.a = 0.0
	_vignette.show_behind_parent = true        # under the crosshair, ammo and prompts, never over them
	add_child(_vignette)
	Ep2ArmoryState.install_actions()
	_build_armory()


func _fit() -> void:
	var vs: Vector2 = get_viewport_rect().size
	if size != vs:
		size = vs
	if _vignette and _vignette.size != vs:
		_vignette.position = Vector2.ZERO
		_vignette.size = vs


func _process(delta: float) -> void:
	_fit()
	_update_armory()
	if armory_open:
		queue_redraw()
		return
	_toast_t = maxf(0.0, _toast_t - delta)
	_hit_t = maxf(0.0, _hit_t - delta)
	_hurt_t = maxf(0.0, _hurt_t - delta)
	fade = move_toward(fade, _fade_goal, _fade_rate * delta)
	if _vignette:
		_vignette.modulate.a = ads * 0.85
	queue_redraw()


func bind_armory(state: Ep2ArmoryState) -> void:
	if armory_open:
		close_armory(false)
	armory = state
	_update_armory()


func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 44)
	button.add_theme_font_size_override("font_size", 15)
	button.pressed.connect(_activate_button.bind(callback))
	button.gui_input.connect(_touch_button.bind(button, callback))
	return button


func _activate_button(callback: Callable) -> void:
	var frame: int = Engine.get_process_frames()
	if frame != _last_activation_frame:
		_last_activation_frame = frame
		callback.call()


func _touch_button(event: InputEvent, button: Button, callback: Callable) -> void:
	if not event is InputEventScreenTouch or button.disabled:
		return
	var touch: InputEventScreenTouch = event
	if touch.pressed:
		_finger_on[touch.index] = button
	else:
		var started: Variant = _finger_on.get(touch.index)
		_finger_on.erase(touch.index)
		if started == button and not touch.canceled and Rect2(Vector2.ZERO, button.size).has_point(touch.position):
			_activate_button(callback)


func _build_armory() -> void:
	_quick = GridContainer.new()
	_quick.columns = 1
	add_child(_quick)
	_hold_button = Button.new()
	_hold_button.custom_minimum_size = Vector2(92, 60)
	_hold_button.expand_icon = true
	_hold_button.add_theme_constant_override("icon_max_width", 56)
	_hold_button.add_theme_font_size_override("font_size", 12)
	_hold_button.add_theme_font_override("font", Ep2WeaponSelector.FONT)
	var leather := StyleBoxFlat.new()
	leather.bg_color = Color("302117")
	leather.border_color = Ep2WeaponSelector.BRASS
	leather.set_border_width_all(1)
	leather.set_corner_radius_all(6)
	_hold_button.add_theme_stylebox_override("normal", leather)
	_hold_button.tooltip_text = "Hold to open your holsters. Time pauses while you choose."
	_quick.add_child(_hold_button)
	# Above mobile controls; the rest of the ordinary HUD stays on its original layer.
	_selector_layer = CanvasLayer.new()
	_selector_layer.layer = 40
	add_child(_selector_layer)
	_panel = Ep2WeaponSelector.new()
	_panel.visible = false
	_selector_layer.add_child(_panel)
	_slots = _panel.cards
	_search = _button("Search bear [E]", func() -> void: search_requested.emit())
	_search.visible = false
	add_child(_search)


func _update_armory() -> void:
	if _quick == null:
		return
	_quick.visible = armory != null and show_ammo and not armory_open
	if armory == null:
		return
	_hold_button.disabled = not armory_enabled
	_hold_button.icon = Ep2WeaponSelector.ICONS[armory.equipped]
	var keys: bool = TouchUi.keys_shown()
	# the holster button is its weapon icon alone on a phone ("HOLD Tab" names a key); the touch hold works on the icon
	_hold_button.text = "HOLD\n%s" % Ep2ArmoryState.key_label("ep2_armory") if keys else ""
	_hold_button.tooltip_text = "Hold to open your holsters. Time pauses while you choose." if keys else ""
	if not keys:
		_search.visible = false
	var ui_scale: float = size.x / 390.0 if size.x / size.y < 1.1 else 1.0
	_quick.scale = Vector2.ONE * ui_scale
	_quick.position = Vector2(size.x * 0.5 - 68 * ui_scale, size.y - 76 * ui_scale)
	_quick.size = Vector2(136, 60)
	_panel.state = armory
	_search.position = Vector2(size.x * 0.5 - 140, size.y * 0.65)
	_search.size.x = 280
	if armory_open and (not is_visible_in_tree() or not armory_enabled or not show_ammo):
		close_armory(false)


func set_search_prompt(text: String) -> void:
	if _search != null:
		_search.text = text
		# "Search bear [E]" names a key and its button sits under the look pad: a phone has the INTERACT button instead
		_search.visible = text != "" and not armory_open and TouchUi.keys_shown()


## Host calls this only after its story/tutorial control guards approve opening.
func toggle_armory() -> void:
	if armory_open:
		close_armory(false)
		return
	if not armory_enabled or armory == null or get_tree().paused:
		return
	if armory.active_gun() is Ep2Bow:
		armory.active_gun().cancel_reload()
	armory_open = true
	_panel.state = armory
	_panel.highlighted = armory.equipped
	_panel.visible = true
	_search.hide()
	_mouse_before = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_owns_pause = true
	get_tree().paused = true
	_update_armory()


## Release commits the preview once, then gives the scene clock back to its owner.
func close_armory(commit: bool = true, restore_mouse: bool = true) -> void:
	if not armory_open:
		return
	if commit and armory.owns(_panel.highlighted):
		weapon_selected.emit(_panel.highlighted)
	armory_open = false
	_panel.hide()
	_hold_finger = -1
	_hold_mouse = false
	if restore_mouse:
		Input.mouse_mode = _mouse_before
	_release_pause()
	_update_armory()


func _release_pause() -> void:
	if _owns_pause and is_inside_tree():
		# Never resume a real pause menu/state change that took ownership afterwards.
		if not StateMachine.is_paused():
			get_tree().paused = false
	_owns_pause = false


func _exit_tree() -> void:
	if armory_open:
		Input.mouse_mode = _mouse_before
	_release_pause()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and armory_open:
		close_armory(false, false)


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or armory == null or not show_ammo:
		return
	if event.is_action_pressed("ep2_armory") and not event.is_echo():
		if not armory_open:
			armory_requested.emit()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_released("ep2_armory") and armory_open:
		close_armory()
		get_viewport().set_input_as_handled()
		return
	# Raw fingers include the second thumb: the armory never injects movement/fire.
	if event is InputEventScreenTouch:
		if event.pressed and not armory_open and _hold_button.get_global_rect().has_point(event.position):
			armory_requested.emit()
			if armory_open:
				_hold_finger = event.index
		elif armory_open:
			_panel.point_at(event.position)
			if not event.pressed and event.index == _hold_finger:
				close_armory(not event.canceled)
		if armory_open or event.index == _hold_finger:
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and armory_open:
		_panel.point_at(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and not armory_open and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and _hold_button.get_global_rect().has_point(event.position):
			armory_requested.emit()
			_hold_mouse = armory_open
		elif not event.pressed and _hold_mouse:
			_panel.point_at(event.position)
			close_armory()
		if armory_open:
			get_viewport().set_input_as_handled()
	if not armory_open:
		return
	# A raw physical key, deliberately not an InputMap action: H belongs to the
	# open ledger and never becomes a gameplay binding in project.godot.
	if event is InputEventKey and event.pressed and not event.is_echo() and event.physical_keycode == KEY_H:
		chill_bud_requested.emit()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		close_armory(false)
	elif event.is_action_pressed("ep2_weapon_1") or event.is_action_pressed("ui_left"):
		_panel.preview(Ep2ArmoryState.WIN)
	elif event.is_action_pressed("ep2_weapon_2") or event.is_action_pressed("ui_right"):
		_panel.preview(Ep2ArmoryState.REM)
	elif event.is_action_pressed("ep2_weapon_previous"):
		_panel.preview(Ep2ArmoryState.REM if _panel.highlighted == Ep2ArmoryState.WIN else Ep2ArmoryState.WIN)
	elif event is InputEventJoypadMotion and event.axis == JOY_AXIS_LEFT_X and absf(event.axis_value) > 0.45:
		_panel.preview(Ep2ArmoryState.WIN if event.axis_value < 0 else Ep2ArmoryState.REM)
	elif event is InputEventMouseMotion:
		_panel.point_at(event.position)
	# All other gameplay input is consumed while the world is frozen.
	get_viewport().set_input_as_handled()


## Ramp the black cover to `goal` (0..1) over `seconds`.
func fade_to(goal: float, seconds: float) -> void:
	_fade_goal = clampf(goal, 0.0, 1.0)
	_fade_rate = absf(_fade_goal - fade) / maxf(seconds, 0.01)


## A short message, centre lower. `token` is its icon: a touch device draws the icon INSTEAD of the words (no token = no toast
## on a phone, e.g. the name of the weapon just selected).
func toast(text: String, seconds: float = 1.6, token: int = Token.NONE) -> void:
	toast_text = text
	toast_token = token
	_toast_t = seconds


## Lil Blunt got hurt: a hot red-orange flash that fades over half a second.
func hurt() -> void:
	_hurt_t = 0.55


func hit_marker(kill: bool) -> void:
	_hit_t = 0.22
	_hit_kill = kill


func set_ammo(r: int, res: int, m: int) -> void:
	rounds = r
	reserve = res
	mag = m


func _draw() -> void:
	drawn_texts.clear()
	if armory_open:
		return
	var c: Vector2 = size * 0.5
	var h: float = size.y
	# a touch device (not driven by a keyboard) gets icons where a desktop gets words
	var wordless: bool = not TouchUi.keys_shown()
	var beat: float = Time.get_ticks_msec() * 0.001
	# --- crosshair ---------------------------------------------------------------------------------------
	var gap: float = 5.0 + spread_deg * 5.2 * (1.0 - ads * 0.8)
	if not show_crosshair:
		pass
	elif ads > 0.55:
		draw_circle(c, 2.4, Color(1.0, 0.95, 0.7, 0.95))
		draw_arc(c, 2.4, 0.0, TAU, 14, Color(0, 0, 0, 0.7), 1.0)
	else:
		var col := Color(1.0, 0.92, 0.55, 0.95 * (1.0 - ads * 1.6))
		var sh := Color(0, 0, 0, 0.6 * (1.0 - ads * 1.6))
		for d in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
			draw_line(c + d * gap + Vector2(1, 1), c + d * (gap + 11.0) + Vector2(1, 1), sh, 3.0)
			draw_line(c + d * gap, c + d * (gap + 11.0), col, 2.0)
		draw_circle(c, 1.4, col)
	# --- hurt flash + hearts ------------------------------------------------------------------------------
	if _hurt_t > 0.0:
		var ha: float = clampf(_hurt_t / 0.55, 0.0, 1.0)
		draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.28, 0.05, 0.42 * ha))
	if show_health:
		for i in health_max:
			_draw_heart(Vector2(46.0 + float(i) * 46.0, size.y - 52.0), 17.0, i < health)
	# --- hit marker --------------------------------------------------------------------------------------
	if _hit_t > 0.0:
		var a: float = clampf(_hit_t / 0.22, 0.0, 1.0)
		var hc: Color = (Color(1.0, 0.25, 0.2, a) if _hit_kill else Color(1, 1, 1, a))
		for d in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			draw_line(c + d * 7.0, c + d * 16.0, hc, 2.5)
	# --- ammo (bottom right) ------------------------------------------------------------------------------
	if show_ammo and _font:
		var base := Vector2(size.x - 40.0, size.y - 42.0)
		if armory != null and armory.owns(armory.equipped):
			var bow_drawing: bool = armory.active_gun() is Ep2Bow and (armory.active_gun() as Ep2Bow).drawing
			if wordless:
				# no status words: a cylinder turning while the gun reloads, a burst while the bow is drawn; nothing when idle
				if bow_drawing or armory.active_gun().reloading:
					_draw_token(Token.BURST if bow_drawing else Token.CYLINDER, Vector2(size.x - 286.0, size.y - 172.0), h * 0.03,
						Color(GOLD.r, GOLD.g, GOLD.b, 0.75 + 0.2 * sin(beat * 9.0)))
			else:
				var status: String = "DRAWING..." if bow_drawing else "RELOADING" if armory.active_gun().reloading else Ep2ArmoryState.NAMES[armory.equipped]
				draw_string_outline(_font, Vector2(size.x - 300.0, size.y - 166.0), status, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 5, Color(0, 0, 0, 0.8))
				drawn_texts.append(status)
				draw_string(_font, Vector2(size.x - 300.0, size.y - 166.0), status, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, GOLD)
		var rcol: Color = GOLD if rounds > 0 else Color(1.0, 0.35, 0.25)
		var big: String = str(rounds)
		var fs_big: int = int(h * 0.085)
		var w_big: float = _font.get_string_size(big, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_big).x
		var small: String = (" ARROWS" if not wordless else "") if armory != null and armory.equipped == Ep2ArmoryState.BOW else " / %d" % reserve
		var fs_small: int = int(h * 0.04)
		var w_small: float = _font.get_string_size(small, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_small).x
		var x0: float = base.x - w_big - w_small
		draw_string_outline(_font, Vector2(x0, base.y), big, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_big, 8, Color(0, 0, 0, 0.8))
		drawn_texts.append(big)
		draw_string(_font, Vector2(x0, base.y), big, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_big, rcol)
		draw_string_outline(_font, Vector2(x0 + w_big, base.y), small, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_small, 6, Color(0, 0, 0, 0.8))
		drawn_texts.append(small)
		draw_string(_font, Vector2(x0 + w_big, base.y), small, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_small, Color(1, 1, 1, 0.8))
		# shell pips above the number: one per tube slot, filled when loaded
		for i in (0 if armory != null and armory.equipped == Ep2ArmoryState.BOW else mag):
			var px: float = base.x - 14.0 - float(mag - 1 - i) * 17.0
			var pr := Rect2(px - 5.0, base.y - fs_big - 22.0, 10.0, 18.0)
			draw_rect(pr, Color(0, 0, 0, 0.55))
			draw_rect(pr.grow(-1.5), GOLD if i < rounds else Color(0.3, 0.26, 0.2, 0.9))
		if rounds == 0 and reserve > 0:
			if wordless:
				# the empty gun asks for a reload with a pulsing cylinder beside the number (the RELOAD button sits just left of it)
				_draw_token(Token.CYLINDER, Vector2(x0 - float(fs_big) * 0.6, base.y - float(fs_big) * 0.4), h * 0.034,
					Color(1.0, 0.45, 0.3, 0.55 + 0.4 * absf(sin(beat * 5.0))))
			else:
				var t := "RELOAD  [R]"
				draw_string_outline(_font, Vector2(base.x - 170.0, base.y + 30.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, int(h * 0.032), 6, Color(0, 0, 0, 0.8))
				drawn_texts.append(t)
				draw_string(_font, Vector2(base.x - 170.0, base.y + 30.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, int(h * 0.032), Color(1.0, 0.45, 0.3))
	# --- objective (top left) -----------------------------------------------------------------------------
	if wordless and lesson_token != Token.NONE:
		_draw_lesson_path(beat)
	elif objective != "" and _font:
		var fs: int = int(h * 0.036)
		var pos := Vector2(158.0 if GameManager.has_region_map else 34.0, 62.0)
		if step_total > 0:
			var hdr := "TARGET PRACTICE   %d / %d" % [step_index, step_total]
			draw_string_outline(_font, pos, hdr, HORIZONTAL_ALIGNMENT_LEFT, -1, int(h * 0.026), 6, Color(0, 0, 0, 0.8))
			drawn_texts.append(hdr)
			draw_string(_font, pos, hdr, HORIZONTAL_ALIGNMENT_LEFT, -1, int(h * 0.026), Color(1.0, 0.7, 0.3))
			pos.y += h * 0.05
		draw_string_outline(_font, pos, objective, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, Color(0, 0, 0, 0.85))
		drawn_texts.append(objective)
		draw_string(_font, pos, objective, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, WHITE)
	# --- toast (centre, lower) ----------------------------------------------------------------------------
	if wordless and _toast_t > 0.0 and toast_text != "":
		# icon or nothing: a toast's words are instructions / status text
		if toast_token != Token.NONE:
			var ta: float = clampf(_toast_t / 0.4, 0.0, 1.0)
			_draw_token(toast_token, Vector2(c.x, size.y * 0.72), h * 0.05, Color(1.0, 0.88, 0.55, ta))
	elif _toast_t > 0.0 and toast_text != "" and _font:
		var fs2: int = int(h * 0.04)
		var w: float = _font.get_string_size(toast_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
		var p := Vector2(c.x - w * 0.5, size.y * 0.74)
		var a2: float = clampf(_toast_t / 0.4, 0.0, 1.0)
		draw_string_outline(_font, p, toast_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, 8, Color(0, 0, 0, 0.85 * a2))
		drawn_texts.append(toast_text)
		draw_string(_font, p, toast_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Color(1.0, 0.85, 0.5, a2))
	if fade > 0.001:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, fade))


## The range lesson on a phone: six icons in teaching order (walk, watch, load, aim, fire, clear the plates). Taught steps fade,
## the current one is bright with a pulsing ring, the rest wait dim. Only a plain NUMBER is ever written (rounds loaded, plates
## left): numbers are the stat labels the rule allows.
func _draw_lesson_path(beat: float) -> void:
	var h: float = size.y
	var u: float = h * 0.034
	var gap: float = u * 3.1
	var origin := Vector2(34.0 + u * 1.5, 62.0 + u * 0.6)
	var current: int = LESSON_PATH.find(lesson_token)
	for i in LESSON_PATH.size():
		var at: Vector2 = origin + Vector2(gap * float(i), 0.0)
		var col := Color(1.0, 1.0, 1.0, 0.28)
		if i < current:
			col = Color(GOLD.r, GOLD.g, GOLD.b, 0.45)
		elif i == current:
			col = Color(1.0, 1.0, 1.0, 0.95)
		if i + 1 < LESSON_PATH.size():
			var a: Vector2 = at + Vector2(u * 1.55, 0.0)
			draw_line(a, a + Vector2(gap - u * 3.1, 0.0), Color(1, 1, 1, 0.22 if i >= current else 0.4), maxf(u * 0.12, 1.5))
		_draw_token(LESSON_PATH[i], at, u, col)
		if i == current:
			var pulse: float = 0.5 + 0.5 * sin(beat * 6.0)
			draw_arc(at, u * (1.75 + 0.18 * pulse), 0.0, TAU, 40, Color(GOLD.r, GOLD.g, GOLD.b, 0.55 + 0.4 * pulse), maxf(u * 0.16, 2.0), true)
	if lesson_count >= 0 and current >= 0 and _font:
		var txt: String = str(lesson_count) if lesson_count_max < 0 else "%d / %d" % [lesson_count, lesson_count_max]
		var fs: int = int(h * 0.04)
		var tw: float = _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var p := Vector2(origin.x + gap * float(current) - tw * 0.5, origin.y + u * 3.5)
		draw_string_outline(_font, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 7, Color(0, 0, 0, 0.85))
		drawn_texts.append(txt)
		draw_string(_font, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, WHITE)


## One wordless icon, centred on `at`, `s` pixels from the centre to its edge, on a dark disc so it reads on any plate.
func _draw_token(kind: int, at: Vector2, s: float, col: Color) -> void:
	var w: float = maxf(s * 0.17, 2.0)
	var ink := Color(col.r, col.g, col.b, col.a)
	var shade := Color(0, 0, 0, col.a * 0.5)
	draw_circle(at, s * 1.4, shade)
	match kind:
		Token.BOOT:
			var boot := PackedVector2Array([
				at + Vector2(-0.5, -1.0) * s, at + Vector2(0.2, -1.0) * s, at + Vector2(0.2, 0.1) * s,
				at + Vector2(1.0, 0.4) * s, at + Vector2(1.0, 0.95) * s, at + Vector2(-0.5, 0.95) * s])
			draw_colored_polygon(boot, ink)
			draw_line(at + Vector2(-0.5, 0.95) * s, at + Vector2(1.0, 0.95) * s, Color(0, 0, 0, col.a * 0.7), w)
		Token.EYE:
			var up := PackedVector2Array()
			var down := PackedVector2Array()
			for i in 13:
				var t: float = float(i) / 12.0
				var y: float = s * 0.62 * sin(PI * t)
				up.append(at + Vector2(lerpf(-s, s, t), -y))
				down.append(at + Vector2(lerpf(-s, s, t), y))
			draw_polyline(up, ink, w, true)
			draw_polyline(down, ink, w, true)
			draw_circle(at, s * 0.32, ink)
		Token.CYLINDER:
			draw_arc(at, s, 0.0, TAU, 32, ink, w, true)
			for i in 6:
				var a: float = TAU * float(i) / 6.0 - PI * 0.5
				draw_circle(at + Vector2(cos(a), sin(a)) * s * 0.58, s * 0.2, ink)
			draw_circle(at, s * 0.14, ink)
		Token.SCOPE:
			draw_arc(at, s * 0.78, 0.0, TAU, 32, ink, w, true)
			for d: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				draw_line(at + d * s * 0.38, at + d * s * 1.15, ink, w * 0.85, true)
			draw_circle(at, s * 0.1, ink)
		Token.BURST:
			for i in 8:
				var a: float = TAU * float(i) / 8.0
				var dir := Vector2(cos(a), sin(a))
				draw_line(at + dir * s * 0.38, at + dir * s * (1.0 if i % 2 == 0 else 0.72), ink, w, true)
			draw_circle(at, s * 0.2, ink)
		Token.TARGETS:
			draw_arc(at, s, 0.0, TAU, 32, ink, w, true)
			draw_arc(at, s * 0.6, 0.0, TAU, 28, ink, w, true)
			draw_circle(at, s * 0.24, ink)
		Token.EMPTY:
			draw_arc(at, s, 0.0, TAU, 32, ink, w, true)
			for i in 6:
				var a: float = TAU * float(i) / 6.0 - PI * 0.5
				draw_arc(at + Vector2(cos(a), sin(a)) * s * 0.58, s * 0.2, 0.0, TAU, 12, ink, w * 0.6, true)
			draw_line(at + Vector2(-1.0, 1.0) * s * 0.95, at + Vector2(1.0, -1.0) * s * 0.95, Color(1.0, 0.3, 0.25, col.a), w * 1.2, true)
		Token.HEAT:
			var flame := PackedVector2Array([
				at + Vector2(0.0, -1.15) * s, at + Vector2(0.55, -0.25) * s, at + Vector2(0.38, 0.1) * s, at + Vector2(0.75, 0.5) * s,
				at + Vector2(0.0, 1.1) * s, at + Vector2(-0.75, 0.5) * s, at + Vector2(-0.4, 0.05) * s, at + Vector2(-0.55, -0.35) * s])
			draw_colored_polygon(flame, Color(1.0, 0.45, 0.12, col.a))
			draw_polyline(flame + PackedVector2Array([flame[0]]), Color(1.0, 0.85, 0.4, col.a), w * 0.6, true)
		Token.RETRY:
			var a0: float = -PI * 0.5 + 0.5
			var a1: float = a0 + TAU * 0.8
			draw_arc(at, s * 0.85, a0, a1, 32, ink, w, true)
			var e: Vector2 = at + Vector2(cos(a1), sin(a1)) * s * 0.85
			var radial := Vector2(cos(a1), sin(a1))
			var tangent := Vector2(-sin(a1), cos(a1))
			draw_colored_polygon(PackedVector2Array([e + tangent * s * 0.6, e + radial * s * 0.5, e - radial * s * 0.5]), ink)
		_:
			pass


## A heart from two circles and a triangle (no font glyph needed, so it also draws in the web build).
func _draw_heart(c: Vector2, r: float, full: bool) -> void:
	var col: Color = Color(1.0, 0.22, 0.2, 0.95) if full else Color(0.25, 0.12, 0.12, 0.8)
	var out := Color(0, 0, 0, 0.8)
	for o in [Vector2(-r * 0.5, -r * 0.25), Vector2(r * 0.5, -r * 0.25)]:
		draw_circle(c + o, r * 0.58 + 2.0, out)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 1.08, -r * 0.1), c + Vector2(r * 1.08, -r * 0.1), c + Vector2(0.0, r * 1.15)]), out)
	for o in [Vector2(-r * 0.5, -r * 0.25), Vector2(r * 0.5, -r * 0.25)]:
		draw_circle(c + o, r * 0.58, col)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 1.0, -r * 0.1), c + Vector2(r * 1.0, -r * 0.1), c + Vector2(0.0, r * 1.05)]), col)
