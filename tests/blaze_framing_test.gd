extends Node
## Blaze Rush FRAMING gate: the same course must read on a phone, a tablet and a
## desktop, in landscape AND portrait, and survive a rotation mid-run.
##
## The run was framed for 16:9 only. Under the project's canvas_items + expand
## stretch (1280x720 or larger) that gave, measured:
##   phone landscape 844x390@2 -> 1558x720   cube 15 dp                    (fine)
##   tablet 1024x768@1         -> 1280x960   240 u of plate under the band
##   phone portrait 390x844@2  -> 1280x2770  cube 8.5 dp, plate magnified 4.8x
## so BlazeFraming zooms the camera until the cube is >= 14 dp, keeps the ground
## ~66% down a tall view, deepens the floor band downward (VISUAL only) and lays the
## backdrop as a horizon band over a gradient in portrait.
##
## Every number below is read from a LIVE run of blaze_rush.tscn at a real window
## size (headless windows are resizable; the viewport math is the engine's), with a
## TouchMetrics posing as a 2x phone injected through `framing_metrics_override`
## (a headless display has density 1).
##
## NOT verifiable here: the pixels. Headless renders nothing; this asserts GEOMETRY
## (camera, band extents, plate scale / coverage). The browser playtest owns pixels.
##
## Run: godot --headless res://tests/blaze_framing_test.tscn
## Verdict: BLAZE_FRAMING: ALL PASS | N FAILURE(S)

const BLAZE_RUSH := preload("res://src/dashmode/blaze_rush.tscn")
const BR := preload("res://src/dashmode/blaze_rush.gd")
const PORTAL := preload("res://src/dashmode/blaze_portal.gd")
const PORTAL_SCENE := preload("res://src/dashmode/blaze_portal.tscn")
const GROUND_Y: float = BlazeRushLayouts.GROUND_Y

## Device windows in physical pixels + density (dp = css px).
const PHONE_LANDSCAPE := Vector2i(1688, 780)   # 844x390 @2
const PHONE_PORTRAIT := Vector2i(780, 1688)    # 390x844 @2
const TABLET := Vector2i(1024, 768)            # @1
const DESKTOP := Vector2i(1280, 720)           # @1

var _fail: int = 0
var _checks: int = 0
var _was_touch: bool = false

func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _ready() -> void:
	await get_tree().process_frame
	print("BLAZE FRAMING:")
	_was_touch = MobileLayoutManager.is_touch_device
	BlazeRotateCue.reset_for_test()
	_test_pure_framing()
	_test_sky_stops_match_plates()
	_test_readability_contrast()
	GameManager.dash_return = {
		"scene_path": "res://src/level/level_01_smoke_realm.tscn",
		"position": Vector2(500.0, 400.0),
		"level_index": 1,
	}
	await _test_portal_hint_font()
	await _test_phone_run_and_rotation()
	await _test_tablet_run()
	await _test_desktop_run_is_unchanged()
	MobileLayoutManager.is_touch_device = _was_touch
	get_window().size = DESKTOP
	await get_tree().process_frame
	if _checks < 40:
		_fail += 1
		print("  [FAIL] only %d checks ran - a false green" % _checks)
	print("BLAZE_FRAMING: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

# ---- helpers -----------------------------------------------------------------------

## Resize the window, let the stretch settle, and pose a TouchMetrics for it.
func _pose(window: Vector2i, density: float) -> TouchMetrics:
	get_window().size = window
	await get_tree().process_frame
	await get_tree().process_frame
	var view: Vector2 = get_viewport().get_visible_rect().size
	return TouchMetrics.compute(view, Vector2(window), density, Vector4.ZERO, true)

func _new_run(m: TouchMetrics) -> Node2D:
	var run: Node2D = BLAZE_RUSH.instantiate()
	run.set("framing_metrics_override", m)
	add_child(run)
	return run

func _expected(view: Vector2, m: TouchMetrics) -> Dictionary:
	return BlazeFraming.compute(view, m)

## Where the ground line lands on screen, as a share of the visible height.
func _ground_frac(cam: Camera2D, view: Vector2) -> float:
	var vis_h: float = view.y / cam.zoom.y
	return (GROUND_Y - (cam.position.y - vis_h * 0.5)) * cam.zoom.y / view.y

func _band_bottom_world(run: Node) -> float:
	var bodies: Array = run.get("_band_bodies")
	if bodies.is_empty():
		return -INF
	var body: ColorRect = bodies[0]
	return body.global_position.y + body.size.y

func _contrast(a: Color, b: Color) -> float:
	var la: float = _luminance(a)
	var lb: float = _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)

func _luminance(c: Color) -> float:
	return 0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b)

func _lin(v: float) -> float:
	return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)

# ---- pure maths ------------------------------------------------------------------------

func _test_pure_framing() -> void:
	# Hand-posed canvases: the stretch maths of canvas_items + expand.
	var cases: Array[Dictionary] = [
		{"name": "phone landscape 844x390@2", "view": Vector2(1558.0, 720.0), "window": Vector2(1688, 780), "density": 2.0,
			"zoom": 1.0, "cam_y": 360.0, "band": 220.0},
		{"name": "tablet 1024x768@1", "view": Vector2(1280.0, 960.0), "window": Vector2(1024, 768), "density": 1.0,
			"zoom": 1.0, "cam_y": 346.4, "band": 390.4},
		{"name": "phone portrait 390x844@2", "view": Vector2(1280.0, 2770.0), "window": Vector2(780, 1688), "density": 2.0,
			"zoom": 1.641, "cam_y": 229.8, "band": 638.0},
		{"name": "desktop 1280x720@1", "view": Vector2(1280.0, 720.0), "window": Vector2(1280, 720), "density": 1.0,
			"zoom": 1.0, "cam_y": 360.0, "band": 220.0},
	]
	for c: Dictionary in cases:
		var m: TouchMetrics = TouchMetrics.compute(c["view"], c["window"], c["density"], Vector4.ZERO, true)
		var f: Dictionary = BlazeFraming.compute(c["view"], m)
		var tag: String = str(c["name"])
		_check("%s: zoom %.3f" % [tag, float(f["zoom"])], absf(float(f["zoom"]) - float(c["zoom"])) < 0.01,
			"expected %.3f" % float(c["zoom"]))
		_check("%s: camera y %.1f" % [tag, float(f["cam_y"])], absf(float(f["cam_y"]) - float(c["cam_y"])) < 0.6,
			"expected %.1f" % float(c["cam_y"]))
		_check("%s: floor band depth %.1f" % [tag, float(f["band_depth"])], absf(float(f["band_depth"]) - float(c["band"])) < 1.5,
			"expected %.1f" % float(c["band"]))
		# The cube is never smaller than 14 dp on the glass.
		var cube_dp: float = BlazeFraming.PLAYER_SIZE * float(f["zoom"]) / m.dp
		_check("%s: cube is %.1f dp (>= 14)" % [tag, cube_dp], cube_dp >= 13.99)
		# Candles (18 u body) >= 9 dp wide, telegraph (14 u) >= 6 dp wide on the glass.
		var candle_dp: float = 18.0 * float(f["zoom"]) / m.dp
		var tele_dp: float = BR.TELEGRAPH_W * float(f["zoom"]) / m.dp
		_check("%s: candle body %.1f dp (>= 9) and telegraph %.1f dp (>= 6)" % [tag, candle_dp, tele_dp],
			candle_dp >= 8.95 and tele_dp >= 6.0)
		# The warning must be on screen 450 u ahead of the cube.
		var vis: Vector2 = f["vis"]
		_check("%s: the telegraph lead fits on screen" % tag,
			float(f["look_ahead"]) + vis.x * 0.5 >= BlazeFraming.TELEGRAPH_SIGHT - 0.01)
		# A tall view keeps the ground ~66% down, a 16:9 view keeps its classic spot.
		var frac: float = float(f["ground_frac"])
		_check("%s: ground line at %.0f%% of the height" % [tag, frac * 100.0], frac >= 0.64 and frac <= 0.70)
		# The band reaches the bottom of the view.
		var bottom_world: float = float(f["cam_y"]) + vis.y * 0.5
		_check("%s: the floor band reaches the view bottom" % tag,
			GROUND_Y + float(f["band_depth"]) >= bottom_world)
	# The audit's zoom formula was INVERTED (dp is canvas units per dp): pin the direction.
	var phone_portrait: TouchMetrics = TouchMetrics.compute(Vector2(1280.0, 2770.0), Vector2(780, 1688), 2.0, Vector4.ZERO, true)
	_check("zoom grows with canvas-units-per-dp (the corrected formula), it does not clamp to 1",
		float(BlazeFraming.compute(Vector2(1280.0, 2770.0), phone_portrait)["zoom"]) > 1.5)

func _test_sky_stops_match_plates() -> void:
	# SKY_STOPS were measured offline from the v2 plates; a regenerated plate must update them.
	var plates: Dictionary = {
		1: "res://src/assets/backgrounds/bg_blaze_l1_smoke_v2.jpg",
		2: "res://src/assets/backgrounds/bg_blaze_l2_crystal_v2.jpg",
		3: "res://src/assets/backgrounds/bg_blaze_l3_gold_v2.jpg",
	}
	for level: int in plates.keys():
		var img: Image = Image.load_from_file(ProjectSettings.globalize_path(str(plates[level])))
		if img == null or img.is_empty():
			_check("L%d plate loads for the sky-stop check" % level, false, str(plates[level]))
			continue
		var top: Color = _row_mean(img, 0)
		var join: Color = _row_mean(img, int(floor(float(img.get_height()) * BlazeFraming.HORIZON_REGION_TOP)))
		var stops: Array[Color] = BlazeFraming.sky_stops(level)
		var d_top: float = absf(top.r - stops[0].r) + absf(top.g - stops[0].g) + absf(top.b - stops[0].b)
		var d_join: float = absf(join.r - stops[1].r) + absf(join.g - stops[1].g) + absf(join.b - stops[1].b)
		_check("L%d sky gradient top stop matches the plate's top-row average (drift %.3f)" % [level, d_top], d_top < 0.04)
		_check("L%d sky gradient horizon stop matches the plate's band-top-row average (drift %.3f)" % [level, d_join], d_join < 0.04)

## Mean colour of rows [row, row+1] across the plate.
func _row_mean(img: Image, row: int) -> Color:
	var acc := Vector3.ZERO
	var n: int = 0
	for y in range(row, mini(row + 2, img.get_height())):
		for x in range(0, img.get_width(), 2):
			var c: Color = img.get_pixel(x, y)
			acc += Vector3(c.r, c.g, c.b)
			n += 1
	acc /= float(maxi(n, 1))
	return Color(acc.x, acc.y, acc.z)

func _test_readability_contrast() -> void:
	# INFORMATIONAL numbers (printed) + a regression floor: before the silhouette the red
	# candle's contrast against the plate band was 2.99 / 2.42 / 1.30 (stages 1/2/3). The
	# candle is still red; the dark outline + cream rim give its EDGE a high contrast.
	var plates: Dictionary = {
		1: "res://src/assets/backgrounds/bg_blaze_l1_smoke_v2.jpg",
		2: "res://src/assets/backgrounds/bg_blaze_l2_crystal_v2.jpg",
		3: "res://src/assets/backgrounds/bg_blaze_l3_gold_v2.jpg",
	}
	var hazard: Color = BR.COLOR_HAZARD
	var outline: Color = BR.CANDLE_OUTLINE_COLOR
	var rim: Color = BR.CANDLE_RIM_COLOR
	for level: int in plates.keys():
		var img: Image = Image.load_from_file(ProjectSettings.globalize_path(str(plates[level])))
		if img == null or img.is_empty():
			_check("L%d plate loads for the contrast report" % level, false)
			continue
		# Candle band: screen y 466..500 on a 720 canvas = plate rows y / fill.
		var fill: float = (720.0 + 2.0) / float(img.get_height())
		var acc := Vector3.ZERO
		var n: int = 0
		for y in range(int(466.0 / fill), int(500.0 / fill)):
			for x in range(0, img.get_width(), 4):
				var c: Color = img.get_pixel(x, y)
				acc += Vector3(c.r, c.g, c.b)
				n += 1
		acc /= float(maxi(n, 1))
		var plate := Color(acc.x, acc.y, acc.z)
		var c_haz: float = _contrast(hazard, plate)
		var c_out: float = _contrast(outline, plate)
		var c_rim: float = _contrast(rim, plate)
		var edge: float = maxf(c_out, c_rim)
		print("     (info) L%d candle contrast vs plate band: red body %.2f | dark outline %.2f | cream rim %.2f | best edge %.2f" % [
			level, c_haz, c_out, c_rim, edge])
		_check("L%d: the candle silhouette reads >= 3:1 against the plate (best edge %.2f)" % [level, edge], edge >= 3.0)

# ---- the portal's hint label -----------------------------------------------------------------

## The level portal's hint ("BLAZE RUSH!" / "??? 1500 PTS") was a fixed 12 px label: 6.5 dp
## tall on a 2x phone (unreadable). On touch it is sized in dp; on desktop it stays 12 px.
func _test_portal_hint_font() -> void:
	var px_phone: int = PORTAL.touch_hint_font_px(1.846)        # 844x390@2: 1.846 canvas units per dp
	var px_portrait: int = PORTAL.touch_hint_font_px(3.282)     # 390x844@2
	_check("portal hint on a 2x landscape phone: %d px = %.1f dp (was 12 px = 6.5 dp)" % [px_phone, float(px_phone) / 1.846],
		float(px_phone) / 1.846 >= 10.0 and px_phone > PORTAL.HINT_FONT_PX)
	_check("portal hint on a 2x portrait phone: %d px = %.1f dp" % [px_portrait, float(px_portrait) / 3.282],
		float(px_portrait) / 3.282 >= 10.0)
	_check("the touch hint size is clamped (never absurd)",
		PORTAL.touch_hint_font_px(0.01) == PORTAL.TOUCH_HINT_MIN_PX and PORTAL.touch_hint_font_px(99.0) == PORTAL.TOUCH_HINT_MAX_PX)
	# The real node: desktop keeps 12 px, touch gets the dp-sized label.
	MobileLayoutManager.is_touch_device = false
	var portal_d: Area2D = PORTAL_SCENE.instantiate()
	portal_d.set("level_index", 3)
	add_child(portal_d)
	await get_tree().process_frame
	var hint_d: Label = portal_d.get("_hint")
	_check("desktop: the portal hint stays 12 px", hint_d != null and hint_d.get_theme_font_size("font_size") == PORTAL.HINT_FONT_PX)
	MobileLayoutManager.is_touch_device = true
	var portal_t: Area2D = PORTAL_SCENE.instantiate()
	portal_t.set("level_index", 3)
	add_child(portal_t)
	await get_tree().process_frame
	var hint_t: Label = portal_t.get("_hint")
	_check("touch: the portal hint is larger than the desktop 12 px", hint_t != null and hint_t.get_theme_font_size("font_size") > PORTAL.HINT_FONT_PX,
		"size %d" % (hint_t.get_theme_font_size("font_size") if hint_t != null else -1))
	_check("touch: the wider hint label is centred over the ring (left edge = -half width)",
		hint_t != null and is_equal_approx(hint_t.position.x, -PORTAL.TOUCH_HINT_WIDTH * 0.5))
	portal_d.queue_free()
	portal_t.queue_free()
	await get_tree().process_frame

# ---- live runs ----------------------------------------------------------------------------

func _test_phone_run_and_rotation() -> void:
	MobileLayoutManager.is_touch_device = true
	var m_land: TouchMetrics = await _pose(PHONE_LANDSCAPE, 2.0)
	var run: Node2D = _new_run(m_land)
	await get_tree().process_frame
	await get_tree().process_frame
	var cam: Camera2D = run.get("_camera")
	var view: Vector2 = get_viewport().get_visible_rect().size
	_check("phone landscape window yields a 1558x720 canvas", absf(view.x - 1558.0) < 2.0 and absf(view.y - 720.0) < 1.0, str(view))
	_check("phone landscape: camera zoom 1.0 and y 360 (the 16:9 camera)",
		is_equal_approx(cam.zoom.x, 1.0) and is_equal_approx(cam.position.y, 360.0))
	_check("phone landscape: band reaches the view bottom", _band_bottom_world(run) >= cam.position.y + view.y * 0.5 - 0.5)
	_check("phone landscape: the left apron stays hidden at zoom 1", not (run.get("_left_apron") as Node2D).visible)
	_check_backdrop(run, view, "phone landscape", false)
	_check("no rotate cue in landscape", run.get_node_or_null("RotateCueLayer") == null)

	# --- rotate to portrait MID-RUN: no scene reload, framing and backdrop follow ---
	# The override is set to the metrics of the FINAL canvas BEFORE the window changes, and
	# nothing is called by hand afterwards: only the root's size_changed signal may re-frame.
	var m_port: TouchMetrics = TouchMetrics.compute(Vector2(1280.0, 2770.0), Vector2(PHONE_PORTRAIT), 2.0, Vector4.ZERO, true)
	run.set("framing_metrics_override", m_port)
	get_window().size = PHONE_PORTRAIT
	await get_tree().process_frame
	await get_tree().process_frame
	view = get_viewport().get_visible_rect().size
	_check("rotation: the canvas is now 1280x2770", absf(view.x - 1280.0) < 2.0 and absf(view.y - 2770.0) < 3.0, str(view))
	var f: Dictionary = BlazeFraming.compute(view, m_port)
	cam = run.get("_camera")
	_check("rotation: camera zoom %.2f (cube >= 14 dp)" % cam.zoom.x, absf(cam.zoom.x - float(f["zoom"])) < 0.01 and cam.zoom.x > 1.5)
	_check("rotation: camera y %.1f lifts the ground to ~66%% of the height" % cam.position.y,
		absf(cam.position.y - float(f["cam_y"])) < 0.6)
	var frac: float = _ground_frac(cam, view)
	_check("rotation: ground line at %.0f%% of the screen" % (frac * 100.0), frac >= 0.64 and frac <= 0.70)
	_check("rotation: the floor band was deepened to reach the view bottom (visual only)",
		_band_bottom_world(run) >= cam.position.y + (view.y / cam.zoom.y) * 0.5 - 0.5,
		"band bottom %.0f, view bottom %.0f" % [_band_bottom_world(run), cam.position.y + (view.y / cam.zoom.y) * 0.5])
	_check_collision_depth_unchanged(run)
	_check("rotation: the left apron is shown at zoom > 1", (run.get("_left_apron") as Node2D).visible)
	_check_backdrop(run, view, "portrait", true)
	_check("portrait on a touch device shows the one-time rotate cue", run.get_node_or_null("RotateCueLayer") != null)
	_check("the cue is remembered as shown for the session", BlazeRotateCue.was_shown())
	_check_cue_is_wordless_and_inert(run)
	var dust: CPUParticles2D = run.get("_dust")
	_check("portrait: the speed-cue dust box grows with the visible height",
		dust != null and dust.emission_rect_extents.y > 300.0 and dust.amount > 20, "extents %s amount %d" % [dust.emission_rect_extents, dust.amount])
	_check("portrait: the HUD and the run are still alive (no scene reload)", run.is_inside_tree() and not bool(run.get("_finished")))

	# --- and back to landscape (again only the size_changed signal re-frames) ---
	run.set("framing_metrics_override", m_land)
	get_window().size = PHONE_LANDSCAPE
	await get_tree().process_frame
	await get_tree().process_frame
	view = get_viewport().get_visible_rect().size
	cam = run.get("_camera")
	_check("back to landscape: zoom 1.0 and y 360 again", is_equal_approx(cam.zoom.x, 1.0) and is_equal_approx(cam.position.y, 360.0))
	_check_backdrop(run, view, "landscape again", false)
	_check("back to landscape: the left apron is hidden again", not (run.get("_left_apron") as Node2D).visible)
	run.queue_free()
	await get_tree().process_frame

func _test_tablet_run() -> void:
	MobileLayoutManager.is_touch_device = true
	var m: TouchMetrics = await _pose(TABLET, 1.0)
	var run: Node2D = _new_run(m)
	await get_tree().process_frame
	await get_tree().process_frame
	var cam: Camera2D = run.get("_camera")
	var view: Vector2 = get_viewport().get_visible_rect().size
	_check("tablet window yields a 1280x960 canvas", absf(view.x - 1280.0) < 2.0 and absf(view.y - 960.0) < 2.0, str(view))
	_check("tablet: zoom stays 1.0 (cube is already 22 dp)", is_equal_approx(cam.zoom.x, 1.0))
	var bottom_view: float = cam.position.y + view.y * 0.5
	_check("tablet: NO strip under the floor band (band bottom %.0f >= view bottom %.0f)" % [_band_bottom_world(run), bottom_view],
		_band_bottom_world(run) >= bottom_view - 0.5)
	_check_collision_depth_unchanged(run)
	_check_backdrop(run, view, "tablet", false)
	_check("tablet: no rotate cue (landscape)", run.get_node_or_null("RotateCueLayer") == null)
	run.queue_free()
	await get_tree().process_frame

func _test_desktop_run_is_unchanged() -> void:
	MobileLayoutManager.is_touch_device = false
	var m: TouchMetrics = await _pose(DESKTOP, 1.0)
	var run: Node2D = _new_run(m)
	await get_tree().process_frame
	await get_tree().process_frame
	var cam: Camera2D = run.get("_camera")
	var view: Vector2 = get_viewport().get_visible_rect().size
	_check("desktop 1280x720: camera is exactly the old one (zoom 1, y 360)",
		is_equal_approx(cam.zoom.x, 1.0) and is_equal_approx(cam.position.y, 360.0))
	_check("desktop: floor band keeps its authored 220 u depth", is_equal_approx(_band_bottom_world(run), GROUND_Y + 220.0),
		"bottom %.1f" % _band_bottom_world(run))
	var dust: CPUParticles2D = run.get("_dust")
	_check("desktop: the dust field is the original 20 particles in a 200x260 box",
		dust.amount == 20 and dust.emission_rect_extents == Vector2(200.0, 260.0))
	_check_backdrop(run, view, "desktop", false)
	_check("desktop: no portrait extras were built", run.find_child("PortraitSky", true, false) == null)
	run.queue_free()
	await get_tree().process_frame

# ---- shared run checks --------------------------------------------------------------------------

## Collision stays the authored 220 u whatever the VISUAL depth (the fairness windows
## were measured against it).
func _check_collision_depth_unchanged(run: Node) -> void:
	var worst: float = 220.0
	var seen: int = 0
	for child in run.get_children():
		if child is StaticBody2D and not child.has_meta("fud_wall"):
			for c in child.get_children():
				if c is CollisionShape2D:
					seen += 1
					worst = maxf(worst, (c.shape as RectangleShape2D).size.y)
	_check("floor COLLISION depth is still 220 u on %d segments" % seen, seen > 0 and is_equal_approx(worst, 220.0), "worst %.1f" % worst)

## Backdrop geometry: the plate is drawn at exactly the plan's scale (NOT multiplied by the
## camera zoom), covers the view width, and in portrait is the horizon band + gradient.
func _check_backdrop(run: Node, view: Vector2, tag: String, expect_horizon: bool) -> void:
	var layer: ParallaxLayer = run.get("_backdrop_layer")
	_check("%s: the backdrop plate exists" % tag, layer != null and is_instance_valid(layer))
	if layer == null or not is_instance_valid(layer):
		return
	var spr: Sprite2D = layer.get_child(0) as Sprite2D
	var tex: Texture2D = spr.texture
	var plan: Dictionary = BlazeFraming.backdrop_plan(view, Vector2(float(tex.get_width()), float(tex.get_height())),
		float((run.get("_framing") as Dictionary)["ground_screen_y"]))
	var on_screen: float = spr.get_global_transform_with_canvas().get_scale().x
	_check("%s: the plate is drawn at scale %.3f (plan %.3f), not multiplied by the camera zoom" % [tag, on_screen, float(plan["fill"])],
		absf(on_screen - float(plan["fill"])) < 0.01)
	_check("%s: the plate covers the view width (%.0f >= %.0f)" % [tag, float(plan["drawn_width"]), view.x],
		float(plan["drawn_width"]) >= view.x)
	_check("%s: mirroring period == drawn width (no seam)" % tag, is_equal_approx(layer.motion_mirroring.x, float(plan["drawn_width"])))
	var horizon: bool = StringName(plan["mode"]) == &"horizon"
	_check("%s: plate mode is %s" % [tag, "horizon band" if expect_horizon else "classic cover"], horizon == expect_horizon)
	if horizon:
		_check("%s: the horizon band is never magnified past %.1fx (the 4.8x blur is gone)" % [tag, BlazeFraming.PORTRAIT_FILL_LIMIT],
			float(plan["fill"]) < BlazeFraming.PORTRAIT_FILL_LIMIT)
		var sky: Control = run.get("_backdrop_sky")
		_check("%s: a sky gradient fills the screen above the band" % tag,
			sky != null and is_instance_valid(sky) and sky.size.y >= float(plan["sky_height"]) and sky.mouse_filter == Control.MOUSE_FILTER_IGNORE)
		var band_bottom: float = float(plan["pos_y"]) + (plan["region"] as Rect2).size.y * float(plan["fill"])
		_check("%s: the horizon band runs down behind the floor (bottom %.0f >= ground line %.0f)" % [
				tag, band_bottom, float((run.get("_framing") as Dictionary)["ground_screen_y"])],
			band_bottom >= float((run.get("_framing") as Dictionary)["ground_screen_y"]))
	else:
		_check("%s: the classic plate covers the view height (%.0f >= %.0f)" % [tag, spr.texture.get_height() * float(plan["fill"]), view.y],
			float(spr.texture.get_height()) * float(plan["fill"]) >= view.y)
		_check("%s: no portrait sky left over" % tag, run.get("_backdrop_sky") == null or not is_instance_valid(run.get("_backdrop_sky")))

func _check_cue_is_wordless_and_inert(run: Node) -> void:
	var layer: Node = run.get_node_or_null("RotateCueLayer")
	if layer == null:
		return
	var texty: Array[String] = []
	var blocking: Array[String] = []
	var stack: Array[Node] = [layer]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Label or n is BaseButton or n is RichTextLabel or n is LineEdit:
			texty.append(n.name)
		if n is Control and (n as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
			blocking.append(n.name)
		stack.append_array(n.get_children())
	_check("the rotate cue has no text and no button (wordless)", texty.is_empty(), ", ".join(texty))
	_check("the rotate cue never blocks a tap (every Control IGNOREs the mouse)", blocking.is_empty(), ", ".join(blocking))
