extends Node
## FOUNDER, 2026-09-16: "In the diamond vault you can see that there is a
## dividing line as if the scene was cutoff and a new background pasted from a
## different design... there is a lot of green shit that is blowing around in
## the air for some reason. Remove it"
##
## Neither the Diamond Vault nor Blaze Rush has a `?stage=`-style URL warp, so
## a browser driver cannot reach either without playing through a door it can't
## reliably find. This gate drives both scenes directly instead and asserts the
## two defects by construction rather than by screenshot.
##
## 1. THE VAULT'S DIVIDING LINE was one missing multiply. `_setup_backdrop()`
##    scaled the 1024x576 plate up to fill the viewport (1.25x at 720p, so it
##    renders 1280 wide) but set `motion_mirroring` to the UNSCALED 1024. Each
##    repeat therefore restarted 256px before the previous copy ended, slicing
##    the painting mid-image and butting an unrelated part of it against the
##    cut — exactly "a new background pasted from a different design". It also
##    hardcoded a 720px fill height, so on a taller-than-16:9 window the art
##    stopped short and left the flat strip along the bottom of his screenshot.
##
## 2. THE GREEN STUFF was a 40-particle lime streak field parented to Blaze
##    Rush's camera, drifting across the view for the whole run on every
##    backdrop.
##
## Run: .godot-cache/Godot_v4.3-stable_linux.x86_64 --headless \
##        res://tests/backdrop_seam_and_vfx_test.tscn

const VAULT := preload("res://src/level/diamond_vault_realm.tscn")
const BLAZE := preload("res://src/dashmode/blaze_rush.tscn")

var _fail: int = 0

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _ready() -> void:
	await get_tree().process_frame
	print("BACKDROP SEAM + VFX:")
	await _run_vault()
	await _run_blaze_particles()
	print("BACKDROP_SEAM_AND_VFX: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

func _find(node: Node, cls: String) -> Array:
	var out: Array = []
	if node.get_class() == cls:
		out.append(node)
	for c in node.get_children():
		out.append_array(_find(c, cls))
	return out

func _run_vault() -> void:
	var vault: Node = VAULT.instantiate()
	add_child(vault)
	await get_tree().process_frame
	await get_tree().process_frame

	var layers := _find(vault, "ParallaxLayer")
	_check("vault builds a parallax backdrop layer", layers.size() >= 1,
		"(found %d)" % layers.size())
	if layers.is_empty():
		vault.queue_free()
		return

	var layer: ParallaxLayer = layers[0]
	var sprites := _find(layer, "Sprite2D")
	_check("backdrop layer carries its painting", sprites.size() >= 1)
	if sprites.is_empty():
		vault.queue_free()
		return

	var spr: Sprite2D = sprites[0]
	var tex_w := float(spr.texture.get_width())
	var tex_h := float(spr.texture.get_height())
	var scale_x := spr.scale.x
	var rendered := tex_w * scale_x

	# THE BUG: mirroring at the raw texture width while the art renders wider.
	_check("repeat distance matches the RENDERED width, not the raw texture",
		absf(layer.motion_mirroring.x - rendered) < 1.0,
		"mirroring=%.1f but the plate renders %.1f wide (raw texture is %.1f) — " % [
			layer.motion_mirroring.x, rendered, tex_w] +
		"a repeat that restarts early slices the painting and shows a hard join")

	# And the tell-tale of the original defect specifically.
	_check("repeat distance is NOT the unscaled texture width (the old defect)",
		not (scale_x > 1.001 and absf(layer.motion_mirroring.x - tex_w) < 1.0),
		"mirroring equals the raw %.0f while scaling %.2fx" % [tex_w, scale_x])

	# The bottom strip: art must cover the whole viewport height.
	var view_h: float = get_viewport().get_visible_rect().size.y
	_check("backdrop covers the full viewport height (no uncovered bottom strip)",
		tex_h * spr.scale.y >= view_h - 1.0,
		"art covers %.0fpx of a %.0fpx viewport" % [tex_h * spr.scale.y, view_h])

	vault.queue_free()
	await get_tree().process_frame

func _run_blaze_particles() -> void:
	var rush: Node = BLAZE.instantiate()
	add_child(rush)
	await get_tree().process_frame
	await get_tree().process_frame

	# AMBIENT emitters only. The Blaze Rush avatar is itself a neon-green cube
	# and carries a short green trail pinned to his own body — that is his
	# motion cue, it moves with him, and it is not what the founder meant by
	# stuff "blowing around in the air for some reason". What he saw was a
	# camera-parented lime field spraying across the whole viewport
	# independently of the player, which is gone. This gate draws exactly that
	# line so a future ambient field cannot creep back while leaving the
	# avatar's own trail alone.
	var player: Node = rush.get("_player")
	var greens: Array = []
	for p in _find(rush, "CPUParticles2D"):
		var em: CPUParticles2D = p
		if player != null and is_instance_valid(player) and player.is_ancestor_of(em):
			continue
		var c: Color = em.color
		# "Green" = clearly green-dominant and actually visible. The warm
		# ember/gold bursts this mode legitimately uses are red-dominant and
		# the neutral speed dust is near-white, so neither trips this.
		if c.g > 0.5 and c.g > c.r * 1.25 and c.g > c.b * 1.25 and c.a > 0.05:
			greens.append("%s rgba(%.2f,%.2f,%.2f,%.2f)" % [em.name, c.r, c.g, c.b, c.a])

	_check("no AMBIENT green particle field drifting through Blaze Rush",
		greens.is_empty(),
		"still emitting: %s" % str(greens))

	rush.queue_free()
	await get_tree().process_frame
