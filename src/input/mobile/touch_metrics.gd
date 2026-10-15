class_name TouchMetrics
extends RefCounted
## Device + screen metrics for the on-screen touch controls.
##
## ONE place that answers "what kind of screen is this and how big is a thumb
## on it?" so the layout code never guesses from an OS name. Everything that
## needs a live DisplayServer lives in `from_environment()`; every other
## function is pure so the test scene can feed it phone / tablet / notch
## numbers on a desktop CI runner.
##
## Units, because mixing them is how touch layouts go wrong:
##   * px      physical (backing-store) pixels of the window
##   * dp      density-independent pixel. 1dp ~ 1/160 inch on Android, ~1 CSS
##             pixel in a mobile browser. Thumb sizes are designed in dp.
##   * canvas  the game's own coordinate space (project stretch mode
##             canvas_items + aspect expand => the viewport is 1280x720 or
##             larger). Everything drawn on the CanvasLayer is in canvas units.
## `dp` below is "canvas units per dp"; multiply a dp size by it to draw it.

## Android's own rule of thumb: smallest width >= 600dp is a tablet.
const PHONE_MAX_SHORT_DP := 600.0
## Window taller than wide by this ratio counts as portrait.
const PORTRAIT_RATIO := 1.1
## Keep thumbs off the bezel / rounded corners / home-indicator strip even when
## the platform reports no safe-area insets (web never does).
const MIN_EDGE_DP := 14.0
const MIN_BOTTOM_DP := 18.0
## A reported inset larger than this share of the window is treated as junk.
const MAX_INSET_SHARE := 0.2

const CLASS_DESKTOP := &"desktop"
const CLASS_PHONE := &"phone"
const CLASS_TABLET := &"tablet"
const LANDSCAPE := &"landscape"
const PORTRAIT := &"portrait"

## Game viewport in canvas units (`get_visible_rect().size`).
var viewport_size: Vector2 = Vector2(1280, 720)
## Window size in physical pixels.
var window_px: Vector2 = Vector2(1280, 720)
## Physical pixels per dp (device pixel ratio / density).
var density: float = 1.0
## Canvas units per dp.
var dp: float = 1.0
var device_class: StringName = CLASS_DESKTOP
var orientation: StringName = LANDSCAPE
## Rectangle (canvas units) the controls may occupy: the viewport minus any
## platform safe-area inset minus the minimum edge margin.
var safe_rect: Rect2 = Rect2(0, 0, 1280, 720)

# --- detection ---------------------------------------------------------------

## True on a device that has a touchscreen. The Web export reports
## `OS.get_name() == "Web"` even inside a phone browser, so a mobile browser only
## reveals itself through `is_touchscreen_available()` (the 2026-08-01 audit
## root cause for "mobile web got no controls at all").
static func is_touch_capable() -> bool:
	return OS.get_name() in ["Android", "iOS"] or DisplayServer.is_touchscreen_available()

## "phone" / "tablet" from the window's smallest side measured in dp. A device
## without touch is always "desktop" (the controls never show there).
static func classify(short_side_dp: float, touch_capable: bool) -> StringName:
	if not touch_capable:
		return CLASS_DESKTOP
	return CLASS_PHONE if short_side_dp < PHONE_MAX_SHORT_DP else CLASS_TABLET

static func orientation_of(window: Vector2) -> StringName:
	return PORTRAIT if window.y > window.x * PORTRAIT_RATIO else LANDSCAPE

## Which layout scene to use. Tablets in portrait reuse the phone portrait
## arrangement (scaled up by the layout's own tier scale) instead of needing a
## fourth scene nobody will play on.
static func layout_key(device: StringName, orient: StringName) -> StringName:
	if orient == PORTRAIT:
		return &"phone_portrait"
	if device == CLASS_TABLET:
		return &"tablet_landscape"
	return &"phone_landscape"

# --- construction ------------------------------------------------------------

## Pure constructor. `insets_px` is (left, top, right, bottom) in window pixels.
static func compute(viewport: Vector2, window: Vector2, density_px_per_dp: float,
		insets_px: Vector4, touch_capable: bool) -> TouchMetrics:
	var m := TouchMetrics.new()
	m.viewport_size = viewport
	m.window_px = window
	m.density = clampf(density_px_per_dp, 0.5, 6.0)
	# canvas units per window pixel (uniform: stretch aspect is "expand")
	var per_px: float = viewport.y / maxf(window.y, 1.0)
	m.dp = m.density * per_px
	var short_dp: float = minf(window.x, window.y) / m.density
	m.device_class = classify(short_dp, touch_capable)
	m.orientation = orientation_of(window)

	var cap_x: float = window.x * MAX_INSET_SHARE
	var cap_y: float = window.y * MAX_INSET_SHARE
	var left: float = maxf(clampf(insets_px.x, 0.0, cap_x) * per_px, MIN_EDGE_DP * m.dp)
	var top: float = maxf(clampf(insets_px.y, 0.0, cap_y) * per_px, MIN_EDGE_DP * m.dp)
	var right: float = maxf(clampf(insets_px.z, 0.0, cap_x) * per_px, MIN_EDGE_DP * m.dp)
	var bottom: float = maxf(clampf(insets_px.w, 0.0, cap_y) * per_px, MIN_BOTTOM_DP * m.dp)
	m.safe_rect = Rect2(left, top, maxf(viewport.x - left - right, 1.0), maxf(viewport.y - top - bottom, 1.0))
	return m

## Live constructor used by the layout manager. `touch_capable` is the manager's
## own verdict (platform report OR a forced flag OR a real finger seen).
static func from_environment(viewport: Viewport, touch_capable: bool) -> TouchMetrics:
	var win: Window = viewport.get_window()
	var window_px := Vector2(win.size) if win != null else Vector2(1280, 720)
	return compute(viewport.get_visible_rect().size, window_px, read_density(),
			read_safe_insets(window_px), touch_capable)

## Physical pixels per dp. Native mobile reports a DPI (160 dpi == 1.0); in a
## browser the device pixel ratio is exactly "backing pixels per CSS pixel".
static func read_density() -> float:
	var d: float = 1.0
	if OS.get_name() in ["Android", "iOS"]:
		d = float(DisplayServer.screen_get_dpi()) / 160.0
	else:
		d = DisplayServer.screen_get_scale()
	if d <= 0.0 or is_nan(d) or is_inf(d):
		return 1.0
	return clampf(d, 0.5, 6.0)

## (left, top, right, bottom) notch / cutout / home-bar insets in window px.
## Only trusted when the window fills the screen (a phone); on a desktop browser
## the window is smaller than the screen and the numbers would be meaningless.
static func read_safe_insets(window_px: Vector2) -> Vector4:
	var screen: Vector2 = Vector2(DisplayServer.screen_get_size())
	var safe: Rect2 = Rect2(DisplayServer.get_display_safe_area())
	if screen.x <= 0.0 or screen.y <= 0.0 or safe.size.x <= 0.0 or safe.size.y <= 0.0:
		return Vector4.ZERO
	if absf(window_px.x - screen.x) > screen.x * 0.05 or absf(window_px.y - screen.y) > screen.y * 0.05:
		return Vector4.ZERO
	return Vector4(
		maxf(safe.position.x, 0.0),
		maxf(safe.position.y, 0.0),
		maxf(screen.x - safe.end.x, 0.0),
		maxf(screen.y - safe.end.y, 0.0))
