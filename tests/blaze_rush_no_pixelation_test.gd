extends Node
## Regression test for "The lil blunt icon is so pixelated i cant see whats
## going on here... I dont want any of the artworks to ever be pixelated
## period!!!" (founder, with screenshots).
##
## Both reported spots (TAP OUT face, the "DIAMOND LOUNGE" band card) turned
## out to be the same mechanism: a source PNG scaled down far more steeply
## than its sharp neighbours, combined with this project's universal
## mipmaps/generate=false import default (confirmed on every .import file
## checked — CI regenerates `.import` from project-wide settings, so a
## per-file override would not have survived a real export anyway). At a
## steep enough ratio LINEAR filtering has nothing usable to sample and the
## art reads as blocky/soft even though the filter mode itself is correct.
##
## This encodes the fix as a standing rule rather than a one-time asset swap:
## every texture actually placed on the Blaze Rush band, and the TAP OUT
## face, must sit within a bounded minification ratio (source px / on-screen
## px) — the same healthy ~2-3x range every sharp badge already uses. A
## future asset drop that reintroduces a hundreds-of-percent oversized source
## fails this gate instead of shipping pixelated again.
##
## Run: godot --headless res://tests/blaze_rush_no_pixelation_test.tscn

const BAND_ART_SIZE: float = 190.0
## Generous ceiling: every currently-sharp badge sits at ~2.7x; this allows
## headroom up to 3.2x before flagging, so it catches real regressions
## (4-10x, what T1/T2 actually shipped) without being brittle to a pixel or
## two of rounding on a resize.
const MAX_SAFE_RATIO: float = 3.2

var _fail: int = 0

func _ready() -> void:
	print("BLAZE RUSH — NO PIXELATION (minification ratio):")
	_check_tapout_face()
	_check_band_art()
	print("BLAZE_RUSH_NO_PIXELATION: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _check_tapout_face() -> void:
	var tex: Texture2D = load("res://src/assets/sprites/sprite_lil-blunt_tapout.png")
	_check("TAP OUT face resolved", tex != null)
	if tex == null:
		return
	# Displayed at custom_minimum_size 58x58 with STRETCH_KEEP_ASPECT_CENTERED
	# (blaze_rush.gd _build_hud/_build_lounge — see TapOutFace wiring).
	var ratio: float = maxf(tex.get_width(), tex.get_height()) / 58.0
	_check("TAP OUT face minification ratio stays within the safe range",
		ratio <= MAX_SAFE_RATIO,
		"source %dx%d displayed at 58x58 -> %.1fx downscale (max safe %.1fx)"
			% [tex.get_width(), tex.get_height(), ratio, MAX_SAFE_RATIO])

func _check_band_art() -> void:
	# Mirrors blaze_rush.gd's BR_ART_ORDER — kept as a literal list here
	# rather than reaching into the private const, so this test still catches
	# a regression even if that const's structure changes shape.
	var entries: Array = [
		["res://src/assets/art/badge_lilblunt.png", false],
		["res://src/assets/art/badge_diamonds.png", false],
		["res://src/assets/art/br_robinhood.png", true],
		["res://src/assets/art/badge_smokering.png", false],
		["res://src/assets/art/badge_hood.png", false],
		["res://src/assets/art/br_diamond_certificate.png", true],
		["res://src/assets/logos/founder/blaze_diamond_correct.png", false],
		["res://src/assets/art/badge_goldmine.png", false],
		["res://src/assets/art/badge_h420.png", false],
	]
	for entry: Array in entries:
		var path: String = entry[0]
		var is_wide: bool = entry[1]
		if not ResourceLoader.exists(path):
			continue
		var tex: Texture2D = load(path)
		if tex == null:
			_check("%s resolves" % path, false)
			continue
		# Matches _build_protocol_landmarks()'s own scale math exactly: wide
		# art scales by height only (aspect preserved), square art scales
		# both axes to BAND_ART_SIZE.
		var ratio: float
		if is_wide:
			ratio = float(tex.get_height()) / BAND_ART_SIZE
		else:
			ratio = maxf(tex.get_width(), tex.get_height()) / BAND_ART_SIZE
		_check("%s minification ratio stays within the safe range" % path.get_file(),
			ratio <= MAX_SAFE_RATIO,
			"source %dx%d, wide=%s -> %.1fx downscale to BAND_ART_SIZE=%.0f (max safe %.1fx)"
				% [tex.get_width(), tex.get_height(), is_wide, ratio, BAND_ART_SIZE, MAX_SAFE_RATIO])
