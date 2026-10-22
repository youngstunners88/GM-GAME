class_name BlazeFraming
extends RefCounted
## Pure framing maths for Blaze Rush: where to point the Camera2D, how deep to
## draw the ground band and how to lay the backdrop plate so the cube, the
## candles and the floor read at ANY screen shape. No nodes, no autoloads: the
## test feeds it phone / tablet / desktop numbers on a headless runner.
##
## WHY THIS EXISTS. The course was framed for 16:9 only (camera fixed at
## (0, 360), a 220 u floor band that ends exactly at the 720 u viewport bottom,
## a backdrop fill computed once). Under the project's canvas_items + expand
## stretch that means (measured, docs/audit blaze):
##   phone landscape 844x390@2  -> 1558x720  canvas, cube 15 dp   (fine)
##   tablet 1024x768@1          -> 1280x960  canvas, 240 u of plate below the band
##   phone portrait 390x844@2   -> 1280x2770 canvas, cube 8.5 dp, plate magnified 4.8x
## Portrait is a real shape (the web shell allows both orientations), and a 5 dp
## candle is unplayable. The fix is geometry, not a bigger cube:
##   * ZOOM the camera so the cube is never smaller than MIN_PLAYER_DP,
##   * keep the ground ~66% down the screen when the view is tall,
##   * extend the floor band DOWNWARD (visual only, collision stays 220 u),
##   * in portrait show a horizon band + gradient instead of a 4.8x blur.
##
## `TouchMetrics.dp` is CANVAS UNITS PER dp (touch_metrics.gd), so the cube is
## PLAYER_SIZE / dp dp tall and the zoom that makes it MIN_PLAYER_DP is
## MIN_PLAYER_DP * dp / PLAYER_SIZE (the audit wrote it inverted; a first
## draft of this file would have clamped to 1.0 everywhere).
##
## DESKTOP IS UNCHANGED: at 1280x720 (any density) dp = 1 so zoom clamps to 1.0,
## the camera stays at y = 360 and the band depth stays 220.

## Smallest the cube may ever be on screen, in dp (a thumb-sized readable cube).
const MIN_PLAYER_DP: float = 14.0
## Cube visual size in canvas units (blaze_rush.gd PLAYER_SIZE).
const PLAYER_SIZE: float = 28.0
const MAX_ZOOM: float = 2.0
## The 16:9 camera height. A view this short or shorter keeps it exactly.
const BASE_CAM_Y: float = 360.0
## Camera x lead over the cube (cube sits this far left of screen centre).
const BASE_LOOK_AHEAD: float = 240.0
const GROUND_Y: float = BlazeRushLayouts.GROUND_Y
## Where the ground line sits on a TALL view (share of the visible height).
const GROUND_SCREEN_FRAC: float = 0.66
## The telegraph shows a hazard TELEGRAPH_LEAD (450) ahead; keep that on screen
## with a little margin.
const TELEGRAPH_SIGHT: float = 490.0
## The floor band's authored depth (lit top 60 + body 160) and the extra bleed
## drawn below the view so a rounding error can never show a strip under it.
const BAND_DEPTH: float = 220.0
const BAND_BLEED: float = 64.0
## Window taller than wide by this ratio counts as portrait (same rule as
## TouchMetrics.orientation_of).
const PORTRAIT_RATIO: float = 1.1

## Pad added to the backdrop fill so the drawn tile is always slightly larger
## than the viewport (see blaze_rush.gd TILE_SAFE_PAD_PX for the two-times-wrong
## history of this constant).
const PLATE_PAD_PX: float = 2.0
## A plate magnified more than this to cover the view is a blur, not a backdrop.
const PORTRAIT_FILL_LIMIT: float = 2.2
## The horizon band is the plate's rows from this fraction down (the glow + the
## treeline), drawn width-fit. Above it a 2-stop gradient takes over.
const HORIZON_REGION_TOP: float = 0.40
## The band's bottom tucks this far below the floor top (behind the floor band).
const HORIZON_TUCK: float = 120.0
## Height of the soft fade that hides the seam between gradient and band.
const HORIZON_FADE_H: float = 56.0

## Sky gradient stops per realm, measured offline from the v2 plates (row 0
## average = top, row at HORIZON_REGION_TOP average = bottom, where the band
## starts). tests/blaze_framing_test.gd re-measures the shipped plates and fails
## if these drift (a regenerated plate must update this table).
const SKY_STOPS: Dictionary = {
	1: [Color(0.200, 0.148, 0.349), Color(0.677, 0.220, 0.606)],
	2: [Color(0.007, 0.148, 0.341), Color(0.031, 0.422, 0.649)],
	3: [Color(0.639, 0.219, 0.133), Color(0.949, 0.543, 0.223)],
}

## Camera + band numbers for a viewport of `view` canvas units under `m`.
## Returns {zoom, cam_y, look_ahead, band_depth, vis, ground_screen_y,
## ground_frac, portrait}. `vis` is the world area on screen (view / zoom).
static func compute(view: Vector2, m: TouchMetrics) -> Dictionary:
	var dp: float = 1.0
	if m != null and m.dp > 0.0:
		dp = m.dp
	var zoom: float = clampf(MIN_PLAYER_DP * dp / PLAYER_SIZE, 1.0, MAX_ZOOM)
	var vis: Vector2 = view / zoom
	var cam_y: float = minf(BASE_CAM_Y, GROUND_Y - (GROUND_SCREEN_FRAC - 0.5) * vis.y)
	var look_ahead: float = maxf(BASE_LOOK_AHEAD, TELEGRAPH_SIGHT - vis.x * 0.5)
	var need: float = (cam_y + vis.y * 0.5) - GROUND_Y
	var band_depth: float = BAND_DEPTH
	if need > BAND_DEPTH + 0.01:
		band_depth = need + BAND_BLEED
	var ground_screen_y: float = view.y * 0.5 + zoom * (GROUND_Y - cam_y)
	return {
		"zoom": zoom,
		"cam_y": cam_y,
		"look_ahead": look_ahead,
		"band_depth": band_depth,
		"vis": vis,
		"ground_screen_y": ground_screen_y,
		"ground_frac": ground_screen_y / maxf(view.y, 1.0),
		"portrait": is_portrait(view),
	}

static func is_portrait(view: Vector2) -> bool:
	return view.y > view.x * PORTRAIT_RATIO

## How to lay the backdrop plate of `tex_size` pixels on a `view` canvas whose
## ground line is at screen y `ground_screen_y`. Returns
##   {mode: &"cover"|&"horizon", fill, drawn_width, region: Rect2, pos_y,
##    sky_height, fade_y}
## `cover` is the classic plate (identical to the pre-framing behaviour at every
## landscape shape). `horizon` (portrait) draws only the plate's lower rows,
## width-fit (~1.25x, never the 4.8x blur) over a gradient that fills the sky.
## The Sprite2D `scale` is `fill` and the ParallaxBackground must ignore the
## camera zoom (blaze_rush.gd sets scroll_ignore_camera_zoom), so `fill` is the
## true on-screen scale.
static func backdrop_plan(view: Vector2, tex_size: Vector2, ground_screen_y: float) -> Dictionary:
	var tw: float = maxf(tex_size.x, 1.0)
	var th: float = maxf(tex_size.y, 1.0)
	var cover: float = maxf((view.y + PLATE_PAD_PX) / th, (view.x + PLATE_PAD_PX) / tw)
	if cover <= PORTRAIT_FILL_LIMIT:
		var drawn_w: float = ceilf(tw * cover)
		return {
			"mode": &"cover",
			"fill": drawn_w / tw,
			"drawn_width": drawn_w,
			"region": Rect2(0.0, 0.0, tw, th),
			"pos_y": 0.0,
			"sky_height": 0.0,
			"fade_y": 0.0,
		}
	var fill: float = (view.x + PLATE_PAD_PX) / tw
	var drawn_width: float = ceilf(tw * fill)
	fill = drawn_width / tw
	var top_row: float = floorf(th * HORIZON_REGION_TOP)
	var region := Rect2(0.0, top_row, tw, th - top_row)
	var band_h: float = region.size.y * fill
	var band_bottom: float = ground_screen_y + HORIZON_TUCK
	var band_top: float = maxf(band_bottom - band_h, 0.0)
	return {
		"mode": &"horizon",
		"fill": fill,
		"drawn_width": drawn_width,
		"region": region,
		"pos_y": band_top,
		"sky_height": band_top,
		"fade_y": band_top,
	}

## The two gradient colours (top, horizon) for a realm.
static func sky_stops(level_index: int) -> Array[Color]:
	var raw: Array = SKY_STOPS.get(level_index, SKY_STOPS[1])
	var out: Array[Color] = []
	for c: Color in raw:
		out.append(c)
	return out
