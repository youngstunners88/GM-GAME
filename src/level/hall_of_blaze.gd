extends Area2D
## Hall of Blaze + community graffiti wall (task #23, Movie-Layer marketing
## surface). A token-gated easter room: hold ANY SmokeRing-ecosystem token
## (SMOKE / DIAMONDS / GoldMine) and stepping into the alcove unfurls
##   - the graffiti wall: top community lore submissions, painted in-world,
##   - the Hall of Blaze: silhouettes of the weekly top-10 (backend-fed).
## Non-holders get a friendly velvet-rope hint and lose nothing — the room is
## spectacle, never progression. Data comes from /community-lore and
## /hall-of-blaze via Web3Bridge; offline the wall shows the house graffiti.

## Themed reuse (task #23 extension): L1 = "THE HALL OF BLAZE"; L3 places the
## same room as the Fort Knox vault. Same gate, same community data.
@export var room_title: String = "— THE HALL OF BLAZE —"

var _opened: bool = false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_on_body_entered)
	# Faint golden shimmer marks the alcove (discoverable, not invisible).
	var glow := ColorRect.new()
	glow.size = Vector2(140, 90)
	glow.position = Vector2(-70, -80)
	glow.color = Color(1.0, 0.85, 0.4, 0.06)
	add_child(glow)
	var tw := create_tween().set_loops()
	tw.tween_property(glow, "color:a", 0.14, 1.4)
	tw.tween_property(glow, "color:a", 0.05, 1.4)

func _on_body_entered(body: Node2D) -> void:
	if _opened or not body.is_in_group("player"):
		return
	_opened = true
	var holder := Web3Bridge.holds("smoke") or Web3Bridge.holds("diamonds") or Web3Bridge.holds("goldmine")
	if not holder:
		_float_label("HALL OF BLAZE\nSMOKE / DIAMONDS / GoldMine holders only.\nConnect a wallet at the menu.", Vector2(-90, -150), Color(1, 0.9, 0.6))
		_opened = false  # let them come back after connecting
		return
	Web3Bridge.report_metric("secret_found", {"kind": "hall_of_blaze"})
	AudioManager.play_sfx("powerup")
	ScreenShake.shake(0.2, 3.0)
	_float_label(room_title, Vector2(-80, -170), Color(1.0, 0.85, 0.4))
	# Graffiti wall: three community lore snippets, sprayed in sequence.
	if Web3Bridge.has_backend():
		for i in range(3):
			Web3Bridge.get_community_lore(_paint_graffiti.bind(i))
		Web3Bridge.get_hall_of_blaze(_raise_silhouettes)
	else:
		_paint_graffiti({"text": "The Realm remembers those who chill hardest."}, 0)

func _paint_graffiti(res: Variant, slot: int) -> void:
	var text := ""
	if typeof(res) == TYPE_DICTIONARY:
		text = str((res as Dictionary).get("text", ""))
	if text == "":
		return
	_float_label("\"%s\"" % text, Vector2(-130, -120 + slot * 34), Color(0.75, 1.0, 0.8), 0)

## Weekly top-10 as glowing silhouettes with truncated addresses.
func _raise_silhouettes(rows: Variant) -> void:
	if typeof(rows) != TYPE_ARRAY:
		return
	var i := 0
	for r in (rows as Array).slice(0, 10):
		var col := ColorRect.new()
		col.size = Vector2(14, 34 + (10 - i) * 3)
		col.position = Vector2(-120 + i * 26, -20 - col.size.y)
		col.color = Color(0.3, 0.9, 0.5, 0.55)
		add_child(col)
		if i < 3:
			var tag := Label.new()
			tag.text = str((r as Dictionary).get("addr", ""))
			tag.add_theme_font_size_override("font_size", 9)
			tag.position = col.position + Vector2(-8, -14)
			tag.modulate = Color(1, 1, 1, 0.8)
			add_child(tag)
		i += 1

func _float_label(text: String, offset: Vector2, color: Color, fade_after: float = 8.0) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size = Vector2(260, 0)
	lbl.position = offset
	lbl.modulate = color
	lbl.z_index = 45
	add_child(lbl)
	if fade_after > 0.0:
		var tw := lbl.create_tween()
		tw.tween_interval(fade_after)
		tw.tween_property(lbl, "modulate:a", 0.0, 1.0)
		tw.finished.connect(lbl.queue_free)
