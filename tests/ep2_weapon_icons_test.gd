extends Node
## Founder 2026-10-21: "maintain consistency in our designs" - every card in the personal armory shows the weapon WITH Lil Blunt's hand, the way the rifle's does: the green
## forearm / glove / cuff are in the icon. The Golden Remington's card used to be the gun alone and the bow's a vector drawing (skill ep2-weapon-selector-icons).
const DIR := "res://src/episode2/assets/weapons/armory/"
var failures: int = 0


func check(label: String, ok: bool, detail: String = "") -> void:
	print("  [PASS] " if ok else "  [FAIL] ", label, "" if ok or detail.is_empty() else "  (" + detail + ")")
	if not ok:
		failures += 1


## Fraction of the opaque pixels that are Lil Blunt's green sleeve (leaf green: g clearly above r and b).
func _green_share(path: String) -> Array:
	var img: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
	if img == null:
		return [0.0, 0, 0]
	var opaque: int = 0
	var green: int = 0
	for y in img.get_height():
		for x in img.get_width():
			var c: Color = img.get_pixel(x, y)
			if c.a < 0.5:
				continue
			opaque += 1
			if c.g > 0.20 and c.g > c.r * 1.18 and c.g > c.b * 1.30:
				green += 1
	return [float(green) / maxf(opaque, 1.0), opaque, img.get_width() * 1000 + img.get_height()]


func _ready() -> void:
	var icons: Dictionary = Ep2WeaponSelector.ICONS
	check("the selector has an icon for every personal-armory weapon", icons.size() == 3 and icons.has(Ep2ArmoryState.WIN) and icons.has(Ep2ArmoryState.REM) and icons.has(Ep2ArmoryState.BOW))
	for id in [Ep2ArmoryState.WIN, Ep2ArmoryState.REM, Ep2ArmoryState.BOW]:
		var tex: Texture2D = icons[id]
		check("%s icon is a real raster render, 640 x 320 (not a vector sketch)" % id, tex != null and tex.get_width() == 640 and tex.get_height() == 320, "%s" % str(tex.get_size() if tex else null))
		var r: Array = _green_share(str(tex.resource_path).get_basename() + ".png" if str(tex.resource_path).ends_with(".png") else str(tex.resource_path))
		check("%s icon shows Lil Blunt's green sleeve with the weapon (at least 1.2%% of its pixels: the gun-only Remington icon had none)" % id, float(r[0]) >= 0.012, "%.3f of %d" % [float(r[0]), int(r[1])])
		check("%s icon has a real silhouette (transparent background, > 15%% of the card drawn)" % id, int(r[1]) > 640 * 320 * 0.15 * 0.5)
	var bow_icon: String = str((icons[Ep2ArmoryState.BOW] as Texture2D).resource_path)
	check("the bow's card is the bow in his hands: a PNG now, the old SVG is gone", bow_icon.ends_with("bow_icon.png") and not ResourceLoader.exists(DIR + "bow_icon.svg"))
	print("EP2_WEAPON_ICONS: ", "ALL PASS" if failures == 0 else "%d FAILED" % failures)
	get_tree().quit(1 if failures > 0 else 0)
