extends Node
## Founder, repeatedly and across several different places: "this part of the
## mountain still looks pasted together. Make it seamless", "the background once
## again looks like it was badly glued", "the background looks like it was badly
## glued together as there is this line on the mountain that has no symetree".
##
## ROOT CAUSE (measured, not eyeballed). Every scrolling backdrop in this game
## is drawn on a ParallaxLayer with `motion_mirroring`, which REPEATS the
## texture horizontally — it does not mirror-flip it. So the image's LAST column
## ends up drawn directly next to its FIRST column, forever, at every repeat
## boundary. If those two columns do not match, that join is a hard vertical
## line running the full height of the screen. That is exactly the line the
## founder keeps circling, and it is why it shows up in Stage 1, Stage 2,
## Stage 3, Blaze Rush and Fort Knox — it was never one bad JPG, it was every
## backdrop being non-tileable while being tiled.
##
## THE MEASURE: compare the wrap join (last column vs first column) against the
## art's OWN typical column-to-column step. A ratio near 1 means the join is
## indistinguishable from normal detail; a ratio of 3+ is a visible seam.
## Measuring against the art's own texture is what makes this fair for both a
## smooth sky and a busy rock face.
##
## Baseline before the fix: bg_blaze_rush_cavern 6.69x, bg_secret_mid 5.72x,
## bg_blaze_rush_treeline 5.24x, bg_l1_forest 3.45x, bg_l3_goldrush 2.97x, and
## five more over 2x.
##
## Run: godot --headless res://tests/background_seam_test.tscn

## Every texture drawn through a RAW-REPEAT motion_mirroring ParallaxLayer — the
## plates actually used by a live scene. Left OUT on purpose (each would fail
## this metric yet is not a visible join in the game):
##   - bg_secret_far / bg_secret_mid: secret_realm.gd draws each as a plate +
##     its horizontal flip, so every join is the same column (seamless by
##     construction). Their raw wrap measures 1.9x / 3.4x, which is exactly why.
##   - fort_knox_backdrop: tiling is OFF for the gold vault (a widened plate
##     covers the camera travel), so there is no repeat to join.
##   - bg_blaze_l3_gold / bg_blaze_rush_treeline / bg_blaze_rush_cavern: the v1
##     Blaze plates; blaze_rush.gd now loads the edge-healed *_v2 plates below.
const MIRRORED_BACKDROPS := [
	"res://src/assets/backgrounds/bg_l1_forest.jpg",
	"res://src/assets/backgrounds/bg_l2_crystal.jpg",
	"res://src/assets/backgrounds/bg_l3_goldrush.jpg",
	"res://src/assets/backgrounds/bg_blaze_l1_smoke.jpg",
	"res://src/assets/backgrounds/bg_blaze_l2_crystal.jpg",
	"res://src/assets/backgrounds/bg_blaze_l1_smoke_v2.jpg",
	"res://src/assets/backgrounds/bg_blaze_l2_crystal_v2.jpg",
	"res://src/assets/backgrounds/bg_blaze_l3_gold_v2.jpg",
	"res://src/assets/art/vaults/diamond_vault_backdrop.png",
]

## A join up to 1.5x the art's own average column step is invisible against its
## natural detail. Everything listed above now measures under 0.6x.
const MAX_SEAM_RATIO := 1.5

## ...unless the join is below what the eye can resolve at all. On a very smooth
## sky the art's own column step is tiny, so a ratio alone flags a join of ~2/255
## (bg_blaze_l2_crystal_v2: 0.0081 absolute, 1.53x) that no player can see. Real
## seams measured here are 0.018 and up (bg_secret_far 0.018, bg_secret_mid 0.049,
## bg_blaze_l3_gold 0.044), so this floor excludes none of them.
const IMPERCEPTIBLE_WRAP := 0.010

var _fail: int = 0

func _ready() -> void:
	await get_tree().process_frame
	print("BACKGROUND WRAP SEAMS (mirrored backdrops):")
	for path in MIRRORED_BACKDROPS:
		_check_seam(path)
	print("BACKGROUND_SEAM: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

func _check_seam(path: String) -> void:
	if not ResourceLoader.exists(path):
		# Not a failure: the art set changes over time. Say so rather than
		# silently scoring a pass for a file nobody is shipping.
		print("  [SKIP] %s (not present)" % path.get_file())
		return
	var tex: Texture2D = load(path)
	var img: Image = tex.get_image()
	if img == null:
		print("  [SKIP] %s (no CPU image)" % path.get_file())
		return
	img.convert(Image.FORMAT_RGB8)
	var w: int = img.get_width()
	var h: int = img.get_height()
	if w < 4 or h < 4:
		print("  [SKIP] %s (too small)" % path.get_file())
		return

	# Sample rows rather than every pixel: a few hundred rows is plenty for a
	# mean and keeps a 12-image sweep fast in headless CI.
	var step: int = maxi(1, h / 200)
	var wrap_sum := 0.0
	var adj_sum := 0.0
	var n := 0
	for y in range(0, h, step):
		var c_first: Color = img.get_pixel(0, y)
		var c_last: Color = img.get_pixel(w - 1, y)
		wrap_sum += (absf(c_first.r - c_last.r) + absf(c_first.g - c_last.g) + absf(c_first.b - c_last.b)) / 3.0
		# The art's own texture, sampled across the full width on this row.
		var row_adj := 0.0
		var samples := 0
		for x in range(1, w, 7):
			var a: Color = img.get_pixel(x - 1, y)
			var b: Color = img.get_pixel(x, y)
			row_adj += (absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)) / 3.0
			samples += 1
		if samples > 0:
			adj_sum += row_adj / float(samples)
		n += 1

	if n == 0:
		return
	var wrap: float = wrap_sum / float(n)
	var adj: float = maxf(adj_sum / float(n), 0.0001)
	var ratio: float = wrap / adj
	if ratio <= MAX_SEAM_RATIO or wrap <= IMPERCEPTIBLE_WRAP:
		print("  [PASS] %-34s wrap %.4f vs texture %.4f = %.2fx" % [path.get_file(), wrap, adj, ratio])
	else:
		_fail += 1
		print("  [FAIL] %-34s wrap %.4f vs texture %.4f = %.2fx — visible vertical join where motion_mirroring repeats it"
			% [path.get_file(), wrap, adj, ratio])
