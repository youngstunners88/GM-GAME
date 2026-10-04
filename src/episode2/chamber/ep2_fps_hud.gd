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

var spread_deg: float = 2.6
var ads: float = 0.0
var rounds: int = 0
var reserve: int = 0
var mag: int = 4
var objective: String = ""
var step_index: int = 0
var step_total: int = 0
var toast_text: String = ""
var _toast_t: float = 0.0
var _hit_t: float = 0.0
var _hit_kill: bool = false
var _font: Font = null
var _vignette: TextureRect = null
var show_ammo: bool = true


func _ready() -> void:
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


func _fit() -> void:
	var vs: Vector2 = get_viewport_rect().size
	if size != vs:
		size = vs
	if _vignette and _vignette.size != vs:
		_vignette.position = Vector2.ZERO
		_vignette.size = vs


func _process(delta: float) -> void:
	_fit()
	_toast_t = maxf(0.0, _toast_t - delta)
	_hit_t = maxf(0.0, _hit_t - delta)
	if _vignette:
		_vignette.modulate.a = ads * 0.85
	queue_redraw()


func toast(text: String, seconds: float = 1.6) -> void:
	toast_text = text
	_toast_t = seconds


func hit_marker(kill: bool) -> void:
	_hit_t = 0.22
	_hit_kill = kill


func set_ammo(r: int, res: int, m: int) -> void:
	rounds = r
	reserve = res
	mag = m


func _draw() -> void:
	var c: Vector2 = size * 0.5
	var h: float = size.y
	# --- crosshair ---------------------------------------------------------------------------------------
	var gap: float = 5.0 + spread_deg * 5.2 * (1.0 - ads * 0.8)
	if ads > 0.55:
		draw_circle(c, 2.4, Color(1.0, 0.95, 0.7, 0.95))
		draw_arc(c, 2.4, 0.0, TAU, 14, Color(0, 0, 0, 0.7), 1.0)
	else:
		var col := Color(1.0, 0.92, 0.55, 0.95 * (1.0 - ads * 1.6))
		var sh := Color(0, 0, 0, 0.6 * (1.0 - ads * 1.6))
		for d in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
			draw_line(c + d * gap + Vector2(1, 1), c + d * (gap + 11.0) + Vector2(1, 1), sh, 3.0)
			draw_line(c + d * gap, c + d * (gap + 11.0), col, 2.0)
		draw_circle(c, 1.4, col)
	# --- hit marker --------------------------------------------------------------------------------------
	if _hit_t > 0.0:
		var a: float = clampf(_hit_t / 0.22, 0.0, 1.0)
		var hc: Color = (Color(1.0, 0.25, 0.2, a) if _hit_kill else Color(1, 1, 1, a))
		for d in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			draw_line(c + d * 7.0, c + d * 16.0, hc, 2.5)
	# --- ammo (bottom right) ------------------------------------------------------------------------------
	if show_ammo and _font:
		var base := Vector2(size.x - 40.0, size.y - 42.0)
		var rcol: Color = GOLD if rounds > 0 else Color(1.0, 0.35, 0.25)
		var big: String = str(rounds)
		var fs_big: int = int(h * 0.085)
		var w_big: float = _font.get_string_size(big, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_big).x
		var small: String = " / %d" % reserve
		var fs_small: int = int(h * 0.04)
		var w_small: float = _font.get_string_size(small, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_small).x
		var x0: float = base.x - w_big - w_small
		draw_string_outline(_font, Vector2(x0, base.y), big, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_big, 8, Color(0, 0, 0, 0.8))
		draw_string(_font, Vector2(x0, base.y), big, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_big, rcol)
		draw_string_outline(_font, Vector2(x0 + w_big, base.y), small, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_small, 6, Color(0, 0, 0, 0.8))
		draw_string(_font, Vector2(x0 + w_big, base.y), small, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_small, Color(1, 1, 1, 0.8))
		# shell pips above the number: one per tube slot, filled when loaded
		for i in mag:
			var px: float = base.x - 14.0 - float(mag - 1 - i) * 17.0
			var pr := Rect2(px - 5.0, base.y - fs_big - 22.0, 10.0, 18.0)
			draw_rect(pr, Color(0, 0, 0, 0.55))
			draw_rect(pr.grow(-1.5), GOLD if i < rounds else Color(0.3, 0.26, 0.2, 0.9))
		if rounds == 0 and reserve > 0:
			var t := "RELOAD  [R]"
			draw_string_outline(_font, Vector2(base.x - 170.0, base.y + 30.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, int(h * 0.032), 6, Color(0, 0, 0, 0.8))
			draw_string(_font, Vector2(base.x - 170.0, base.y + 30.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, int(h * 0.032), Color(1.0, 0.45, 0.3))
	# --- objective (top left) -----------------------------------------------------------------------------
	if objective != "" and _font:
		var fs: int = int(h * 0.036)
		var pos := Vector2(34.0, 62.0)
		if step_total > 0:
			var hdr := "TARGET PRACTICE   %d / %d" % [step_index, step_total]
			draw_string_outline(_font, pos, hdr, HORIZONTAL_ALIGNMENT_LEFT, -1, int(h * 0.026), 6, Color(0, 0, 0, 0.8))
			draw_string(_font, pos, hdr, HORIZONTAL_ALIGNMENT_LEFT, -1, int(h * 0.026), Color(1.0, 0.7, 0.3))
			pos.y += h * 0.05
		draw_string_outline(_font, pos, objective, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, Color(0, 0, 0, 0.85))
		draw_string(_font, pos, objective, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, WHITE)
	# --- toast (centre, lower) ----------------------------------------------------------------------------
	if _toast_t > 0.0 and toast_text != "" and _font:
		var fs2: int = int(h * 0.04)
		var w: float = _font.get_string_size(toast_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
		var p := Vector2(c.x - w * 0.5, size.y * 0.74)
		var a2: float = clampf(_toast_t / 0.4, 0.0, 1.0)
		draw_string_outline(_font, p, toast_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, 8, Color(0, 0, 0, 0.85 * a2))
		draw_string(_font, p, toast_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Color(1.0, 0.85, 0.5, a2))
