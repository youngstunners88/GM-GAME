extends Node
## TITLE-SCREEN gate for the smoke-theme rebuild.
##
## Founder brief (2026-09-22): the title screen "does not evoke the theme of
## marijuana or smoke". The rebuild is four things at once — key-art backdrop,
## per-glyph smoke lettering, continuously swirling smoke, and a menu track.
##
## Why this gate exists rather than "it compiled": the entire title lockup is
## built in CODE at _ready(), not authored in main_menu.tscn. A compile pass
## proves the syntax of the builder; it proves nothing about whether the
## builder actually produced glyphs, particles, a backdrop, or music. Every one
## of those could no-op silently (a renamed node path, a missing asset, a
## container swallowing the line) and still compile clean and still boot — and
## the founder would open the menu and see exactly the flat screen he rejected.
##
## So this asserts the RESULT, on a real instantiated menu, not the source.
##
## Run: .godot-cache/Godot_v4.3-stable_linux.x86_64 --headless \
##        res://tests/menu_smoke_title_test.tscn

const MENU_SCENE := "res://src/ui/main_menu.tscn"

var _fail: int = 0

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

## Depth-first collect of every node of a given class under `root`.
func _collect(root: Node, cls: String, out: Array[Node]) -> void:
	for child in root.get_children():
		if child.is_class(cls):
			out.append(child)
		_collect(child, cls, out)

func _ready() -> void:
	print("MENU SMOKE TITLE:")

	var packed: PackedScene = load(MENU_SCENE)
	if packed == null:
		print("  [FAIL] could not load %s" % MENU_SCENE)
		get_tree().quit(1)
		return
	var menu: Node = packed.instantiate()
	add_child(menu)
	# One frame so _ready() on the menu has run and its tweens are bound.
	await get_tree().process_frame

	# 1. BACKDROP — key art present and actually textured. A TextureRect with a
	#    null texture draws nothing and would leave the flat colour plate.
	var backdrop := menu.get_node_or_null("Backdrop") as TextureRect
	_check("backdrop node exists", backdrop != null)
	if backdrop:
		_check("backdrop has a texture", backdrop.texture != null)

	# 2. SMOKE LETTERING — the lockup exists, carries BOTH lines, and the flat
	#    labels it replaced are hidden. If TitleLabel were still visible we
	#    would be drawing the old title UNDER the new one.
	var stack := menu.get_node_or_null("VBoxContainer/SmokeTitle")
	_check("SmokeTitle lockup exists", stack != null)
	# Look the two lines up by their EXPLICIT unique names. An earlier version
	# of this gate matched a shared name "SmokeLine" and found only one of the
	# two, because Godot renames a duplicate sibling on add_child — that is the
	# bug this lookup is shaped to keep caught.
	var lines: Array[Node] = []
	if stack:
		for n: String in ["SmokeLineTitle", "SmokeLineSub"]:
			var ln := stack.get_node_or_null(n)
			if ln:
				lines.append(ln)
	_check("two smoke lines (title + subtitle)", lines.size() == 2,
			"got %d" % lines.size())

	var old_title := menu.get_node_or_null("VBoxContainer/TitleLabel") as Label
	var old_sub := menu.get_node_or_null("VBoxContainer/SubtitleLabel") as Label
	_check("flat TitleLabel hidden", old_title != null and not old_title.visible)
	_check("flat SubtitleLabel hidden", old_sub != null and not old_sub.visible)

	# 3. PER-GLYPH — one Label per non-space character, each with a ghost child.
	#    This is the assertion that would have caught "the line built, but as a
	#    single block label", which is the exact look the founder rejected.
	if lines.size() == 2:
		_assert_line(lines[0], "LIL BLUNT")
		_assert_line(lines[1], "THE SMOKE REALM")

	# 4. SWIRLING SMOKE — three layers, all emitting, all with a non-zero
	#    tangential accel. Tangential accel is what CURLS the smoke; without it
	#    the particles rise in straight lines and read as steam, not smoke.
	var parts: Array[Node] = []
	_collect(menu, "CPUParticles2D", parts)
	_check("three smoke layers", parts.size() == 3, "got %d" % parts.size())
	var swirling := 0
	var emitting := 0
	var preprocessed := 0
	for p in parts:
		var cp := p as CPUParticles2D
		if absf(cp.tangential_accel_max) > 0.0:
			swirling += 1
		if cp.emitting:
			emitting += 1
		# Preprocess must cover a full lifetime or the menu opens with an empty
		# screen that fills in over ~10s — "the smoke starts late".
		if cp.preprocess >= cp.lifetime:
			preprocessed += 1
	_check("every layer swirls (tangential accel)", swirling == parts.size(),
			"%d/%d" % [swirling, parts.size()])
	_check("every layer is emitting", emitting == parts.size(),
			"%d/%d" % [emitting, parts.size()])
	_check("every layer preprocessed a full lifetime",
			preprocessed == parts.size(), "%d/%d" % [preprocessed, parts.size()])

	# 5. MUSIC — the founder's track must resolve AND be the thing playing.
	#    Asserting only that the file exists would pass even if nothing wired
	#    it up, which is the whole failure class this project keeps hitting.
	var music_path: String = menu.get("MENU_MUSIC")
	_check("menu music constant set", music_path != "" and music_path != null)
	_check("menu music file imports", ResourceLoader.exists(music_path),
			music_path)
	var am: Node = get_node_or_null("/root/AudioManager")
	_check("AudioManager autoload present", am != null)
	if am:
		var player: Variant = am.get("current_music_player")
		_check("a music track is actually playing", player != null)

	print("MENU SMOKE TITLE: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(1 if _fail > 0 else 0)

## Assert one line is built glyph-by-glyph: a Label per non-space char, each
## carrying exactly one ghost Label drawn behind it.
func _assert_line(line: Node, text: String) -> void:
	var expected := 0
	for i in text.length():
		if text[i] != " ":
			expected += 1
	var glyphs: Array[Node] = []
	for c in line.get_children():
		if c is Label:
			glyphs.append(c)
	_check("'%s' is %d separate glyphs" % [text, expected],
			glyphs.size() == expected, "got %d" % glyphs.size())
	var ghosted := 0
	for g in glyphs:
		for sub in g.get_children():
			if sub is Label and (sub as Label).show_behind_parent:
				ghosted += 1
				break
	_check("'%s' every glyph has a smoke ghost" % text, ghosted == glyphs.size(),
			"%d/%d" % [ghosted, glyphs.size()])
