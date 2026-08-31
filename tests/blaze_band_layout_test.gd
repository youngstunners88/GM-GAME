extends Node
## Blaze Rush purple-band layout — the founder's placement/scale corrections.
##
## Each assertion here maps to a specific annotated screenshot, and every one of
## them is a REGRESSION test: all of these shipped wrong at least once, and two
## of them shipped wrong twice because the previous fix was verified against
## constants rather than against what the scene actually built.
##
## So nothing here reads a constant. Every check instantiates the real Blaze
## Rush scene and measures the live nodes — texture actually assigned, position
## actually resolved, on-screen width actually drawn (scale x texture size, not
## the nominal WIDTH const, which is precisely the gap the masking bug lived in).
##
##   image1/4/5/6/7  entry wordmark FILLS the band, and is not a small plate
##                   floating in it or a card up in the sky
##   image2          badge_blaze.png (bronze disc, RED flaming diamond) is gone
##   image3/8        the lounge banner is at the END and NOTHING overlaps it
##   image9/10       GoldMine sits right of Robin Hood, both present
##   image4          course pickups are the BLUE flaming diamond

const BLAZE_RUSH := preload("res://src/dashmode/blaze_rush.tscn")

## Band geometry from blaze_rush.gd — the band runs GROUND_Y..GROUND_Y+220.
const BAND_HEIGHT: float = 220.0
## The old plate was 340x118. Anything near that is the bug the founder called
## "TOO SMALL"; the replacement is a 900px cover-fit.
const MIN_ENTRY_WIDTH: float = 700.0

var _fail: int = 0

func _ready() -> void:
	await get_tree().process_frame
	print("BLAZE BAND LAYOUT:")
	for lvl in [1, 2, 3]:
		await _check_level(lvl)
	print("BLAZE_BAND_LAYOUT: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

## Every band-art Sprite2D in the run, as {node, x, half_width, path}.
##
## half_width is measured from the LIVE scale and texture, including a region
## crop when one is set — the world card is a cover fit, so its drawn width is
## its region width times its scale, not its texture width times its scale.
func _band_art(run: Node2D) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for child in run.get_children():
		var spr := child as Sprite2D
		if spr == null or spr.texture == null:
			continue
		# Band art only: the run line and its hazards sit well above the band.
		if spr.position.y < 400.0:
			continue
		var src_w: float = float(spr.texture.get_width())
		if spr.region_enabled and spr.region_rect.size.x > 0.0:
			src_w = spr.region_rect.size.x
		out.append({
			"node": spr,
			"x": spr.position.x,
			"half": absf(spr.scale.x) * src_w * 0.5,
			"path": spr.texture.resource_path,
		})
	return out

func _check_level(level_index: int) -> void:
	GameManager.dash_return = {
		"scene_path": "res://src/level/level_01_smoke_realm.tscn",
		"position": Vector2(500, 400),
		"level_index": level_index,
	}
	var run: Node2D = BLAZE_RUSH.instantiate()
	add_child(run)
	await get_tree().process_frame
	await get_tree().process_frame

	var course: float = float(run.get("_course_length"))
	var art: Array[Dictionary] = _band_art(run)

	# --- image2: the banned prop stays banned ---------------------------------
	var has_blaze_badge := false
	for a in art:
		if str(a["path"]).contains("badge_blaze"):
			has_blaze_badge = true
	_check("L%d badge_blaze (red flaming diamond) absent from band" % level_index,
		not has_blaze_badge, "founder struck this out: 'WHY do you have this again'")

	# --- image1/5/6/7: the entry wordmark fills the band -----------------------
	var card := run.get_node_or_null("WorldCard") as Sprite2D
	_check("L%d entry wordmark exists" % level_index, card != null)
	if card != null:
		var src_w: float = float(card.texture.get_width())
		if card.region_enabled and card.region_rect.size.x > 0.0:
			src_w = card.region_rect.size.x
		var drawn_w: float = absf(card.scale.x) * src_w
		var src_h: float = float(card.texture.get_height())
		if card.region_enabled and card.region_rect.size.y > 0.0:
			src_h = card.region_rect.size.y
		var drawn_h: float = absf(card.scale.y) * src_h
		_check("L%d entry wordmark is LARGE (>= %dpx wide)" % [level_index, int(MIN_ENTRY_WIDTH)],
			drawn_w >= MIN_ENTRY_WIDTH, "drawn %.0fpx wide - founder: 'TOO SMALL'" % drawn_w)
		# "Fills that section of real estate" — the band is 220px tall.
		_check("L%d entry wordmark fills the band height" % level_index,
			drawn_h >= BAND_HEIGHT * 0.9, "drawn %.0fpx tall of %.0f" % [drawn_h, BAND_HEIGHT])
		# image4: "You fucked it up by having the text above" — it must be IN the
		# band, not floating in the sky, and not on a CanvasLayer at all.
		_check("L%d entry wordmark sits in the band, not the sky" % level_index,
			card.position.y > 400.0, "y = %.0f" % card.position.y)
		_check("L%d entry wordmark is at the ENTRY" % level_index,
			card.position.x < course * 0.35, "x = %.0f of %.0f" % [card.position.x, course])
		# Aspect must be preserved — squashing the founder's brand art is its own
		# complaint. A cover fit scales both axes equally.
		_check("L%d entry wordmark is not distorted" % level_index,
			absf(absf(card.scale.x) - absf(card.scale.y)) < 0.01,
			"scale %.3f x %.3f" % [card.scale.x, card.scale.y])

	# --- image3/8: lounge banner at the end, and NOT masked -------------------
	var banner := run.get_node_or_null("SmokeLoungeBanner") as Node2D
	_check("L%d lounge banner exists" % level_index, banner != null)
	if banner != null:
		_check("L%d lounge banner is at the END of the course" % level_index,
			banner.position.x > course * 0.8,
			"x = %.0f of %.0f" % [banner.position.x, course])
		# THE MASKING CHECKS. Two independent causes have produced the founder's
		# "WHY ARE YOU MASKING THE FUCKING ARTWORK" screenshot, so both are
		# asserted: the banner overhanging a floor GAP (the void showing through
		# behind it), and another piece of band art drawn across it.
		#
		# Both are measured against the banner's REAL drawn half-width, read off
		# its own sprite rather than a nominal constant — using the constant
		# while the sprite is height-fit is the bug class itself.
		var b_half: float = 0.0
		for c in banner.get_children():
			var bs := c as Sprite2D
			if bs != null and bs.texture != null:
				b_half = maxf(b_half, absf(bs.scale.x) * float(bs.texture.get_width()) * 0.5)
		_check("L%d lounge banner drawn width is measurable" % level_index, b_half > 0.0)

		var over_gap: bool = bool(run.call("_x_over_gap", banner.position.x, b_half))
		_check("L%d lounge banner does NOT overhang a floor gap" % level_index, not over_gap,
			"the void showing through behind it reads as masked")

		var masked_by: String = ""
		for a in art:
			if absf(float(a["x"]) - banner.position.x) < b_half + float(a["half"]):
				masked_by = str(a["path"]).get_file()
		_check("L%d NOTHING overlaps the lounge banner" % level_index,
			masked_by == "", "overlapped by %s" % masked_by)

	# --- the general invariant: no two band pieces overlap at all -------------
	var overlaps: String = ""
	for i in range(art.size()):
		for j in range(i + 1, art.size()):
			var a: Dictionary = art[i]
			var b: Dictionary = art[j]
			if absf(float(a["x"]) - float(b["x"])) < float(a["half"]) + float(b["half"]):
				overlaps = "%s <-> %s" % [str(a["path"]).get_file(), str(b["path"]).get_file()]
	_check("L%d no two pieces of band art overlap" % level_index,
		overlaps == "", overlaps)

	# --- image9/10: GoldMine moved right, Robin Hood in the slot it vacated ---
	# CYCLE-AWARE. The art list repeats along the band (MAX_BAND_CYCLES), so a
	# long course carries several GoldMine and Robin Hood marks. Comparing only
	# the last-seen x of each is wrong: L3's final cycle is truncated after
	# Robin Hood before it reaches GoldMine, which made a correct layout look
	# like a violation. The founder's instruction is about their ORDER within
	# the repeating pattern, so that is what is asserted — for every cycle where
	# both appear, GoldMine follows Robin Hood.
	var gm_xs: Array[float] = []
	var rh_xs: Array[float] = []
	for a in art:
		var p: String = str(a["path"])
		if p.contains("goldmine"):
			gm_xs.append(float(a["x"]))
		if p.contains("robinhood"):
			rh_xs.append(float(a["x"]))
	gm_xs.sort()
	rh_xs.sort()
	_check("L%d GoldMine mark is present on the band" % level_index, gm_xs.size() > 0,
		"dropped - founder asked for it MOVED, not removed")
	_check("L%d Robin Hood artwork is present on the band" % level_index, rh_xs.size() > 0)
	var bad_cycle: String = ""
	for i in range(mini(gm_xs.size(), rh_xs.size())):
		if gm_xs[i] <= rh_xs[i]:
			bad_cycle = "cycle %d: GM x=%.0f, RH x=%.0f" % [i + 1, gm_xs[i], rh_xs[i]]
	_check("L%d GoldMine sits RIGHT of Robin Hood in every cycle" % level_index,
		bad_cycle == "", bad_cycle)

	# --- image4: course pickups are the BLUE flaming diamond ------------------
	var tokens: Array = run.get("_smoke_tokens")
	var wrong_token: String = ""
	var checked_tokens: int = 0
	for t in tokens:
		var area := t as Area2D
		if area == null:
			continue
		for c in area.get_children():
			var spr := c as Sprite2D
			if spr == null or spr.texture == null:
				continue
			checked_tokens += 1
			if not spr.texture.resource_path.contains("flame_diamond_blue"):
				wrong_token = spr.texture.resource_path
	_check("L%d course pickups exist" % level_index, checked_tokens > 0)
	_check("L%d course pickups are the BLUE flaming diamond" % level_index,
		wrong_token == "", "found %s" % wrong_token)

	run.queue_free()
	await get_tree().process_frame
