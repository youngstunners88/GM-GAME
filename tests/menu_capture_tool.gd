extends Node
## Dev tool: render the REAL main menu under a virtual display and save a PNG.
##
## This exists because two genuine bugs shipped in one session that every
## headless assertion passed. The smoke layers were given z_index = -1 and drew
## behind the opaque backdrop — correctly configured, completely invisible. The
## per-glyph ghosts were pivoted from an un-parented node's minimum size and
## rendered as a double-image. Neither is expressible as a property check;
## both were obvious in one screenshot.
##
## Without this the only way to see the title screen was a ~10 minute CI export
## plus a 200MB artifact download. With it the loop is about thirty seconds.
##
## Lives under tests/ deliberately: the web export's exclude_filter drops
## tests/, so this never ships inside the .pck.
##
## Run (needs a virtual display — the sandbox has no Vulkan, so force the
## OpenGL compatibility driver, which is what the web build uses anyway):
##
##   SHOT_OUT=/tmp/menu.png xvfb-run -a -s "-screen 0 1280x720x24" \
##     .godot-cache/Godot_v4.3-stable_linux.x86_64 --path . \
##     --display-driver x11 --rendering-driver opengl3 \
##     --resolution 1280x720 res://tests/menu_capture_tool.tscn
func _ready() -> void:
	var packed: PackedScene = load("res://src/ui/main_menu.tscn")
	add_child(packed.instantiate())
	# Let smoke preprocess settle and the per-glyph tweens reach mid-motion.
	for i in 240:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var out: String = OS.get_environment("SHOT_OUT")
	if out == "":
		out = "/tmp/menu_shot.png"
	img.save_png(out)
	print("SHOT SAVED: %s (%dx%d)" % [out, img.get_width(), img.get_height()])
	get_tree().quit(0)
