extends Node
## Gate for the 2026-08-18 owner-rage residual. One assertion per founder
## complaint, so a future session cannot silently re-break any of them (several
## of these ARE re-breaks of previously-shipped fixes — that is the whole
## reason this file exists).
##
## Founder items covered:
##   1 orange box on the Stage 3 track  -> melt forges removed entirely
##   2 88/288 mining carts "removed"    -> present AND at a visible height
##   3 BTC logo illegible (20th ask)    -> hi-res, high-contrast sprite
##   5 axe "doesn't work"               -> heavy shake + its own impact SFX
##   6 boss voices too quiet            -> non-positional player, >= +8 dB
##   7 HUD text big again               -> sizes back down
##   8 leaf switches music              -> no music override on blaze/purple
##                                      -> celebration SFX + bark exist

const L3 := "res://src/resources/level_03_data.tres"

var _fail := 0

func _bad(m: String) -> void:
	_fail += 1
	push_error(m)
	print("  [FAIL] ", m)

func _ok(m: String) -> void:
	print("  [PASS] ", m)

func _ready() -> void:
	_check_orange_box()
	_check_carts()
	_check_btc_logo()
	_check_axe_feel()
	_check_boss_voice()
	_check_hud_text()
	_check_leaf_music_and_celebration()
	if _fail == 0:
		print("OWNER_RAGE_20260818: ALL PASS")
		get_tree().quit(0)
	else:
		print("OWNER_RAGE_20260818: FAIL (%d)" % _fail)
		get_tree().quit(1)

# 1 — the solid orange rectangle the founder circled twice (shots 1 + 4) was the
# melt-forge prop, grounded onto the track by an earlier session.
func _check_orange_box() -> void:
	var data = load(L3)
	var forges: Array = data.get("melt_forges")
	if forges.is_empty():
		_ok("no melt forges on Stage 3 (orange box gone)")
	else:
		_bad("%d melt forge(s) still on the Stage 3 track" % forges.size())

# 2 — the carts were never deleted from data; they sat at y=280-300, which with
# a 720-tall viewport centred on a grounded player is the very top edge, so they
# were sliced off screen. They must stay airborne but fully visible.
func _check_carts() -> void:
	var data = load(L3)
	var fast: Array = data.get("mine_carts_fast")
	var slow: Array = data.get("mine_carts_slow")
	if fast.size() >= 3 and slow.size() >= 2:
		_ok("mine carts present (%d fast / %d slow)" % [fast.size(), slow.size()])
	else:
		_bad("mine carts missing: %d fast / %d slow" % [fast.size(), slow.size()])
	var bad_y: Array = []
	for c in fast + slow:
		var y: float = (c.get("pos", Vector2.ZERO) as Vector2).y
		# Airborne (well above the y=650 ground) but not in the clipped band.
		if y < 350.0 or y > 540.0:
			bad_y.append(y)
	if bad_y.is_empty():
		_ok("every cart floats in the visible band (350 < y < 540)")
	else:
		_bad("cart(s) outside the visible floating band: %s" % str(bad_y))

# 3 — the gold coin read as a yellow blob: tiny source art, low contrast.
func _check_btc_logo() -> void:
	for p in ["res://src/assets/sprites/sprite_item_wbtc.png",
			  "res://src/assets/sprites/sprite_item_coin-btc.png"]:
		var tex: Texture2D = load(p)
		if tex == null:
			_bad("missing BTC sprite %s" % p); continue
		var img: Image = tex.get_image()
		# Footprint must stay at the original size — a bigger master made the
		# coins render ~3x too large in the first browser capture. Legibility is
		# asserted below via contrast, which is what actually failed.
		if img.get_width() > 64:
			_bad("%s is %dpx — oversized art blows the coin up on screen" % [p, img.get_width()])
			continue
		# High contrast = real white glyph pixels present, not gold-on-gold.
		var white := 0
		for x in range(0, img.get_width(), 3):
			for y in range(0, img.get_height(), 3):
				var c: Color = img.get_pixel(x, y)
				if c.a > 0.5 and c.r > 0.9 and c.g > 0.9 and c.b > 0.9:
					white += 1
		if white < 5:
			_bad("%s has no white glyph pixels (%d) — illegible" % [p, white])
		else:
			_ok("%s is %dpx with a white glyph (%d sampled px)" % [p.get_file(), img.get_width(), white])

# 5 — the axe always dealt damage; it just never FELT like it.
func _check_axe_feel() -> void:
	var src := FileAccess.get_file_as_string("res://src/combat/axe.gd")
	if src.contains("ScreenShake.heavy()"):
		_ok("big axe impact uses a heavy screenshake")
	else:
		_bad("big axe impact is not using ScreenShake.heavy()")
	if src.contains("bigaxe_impact"):
		_ok("big axe has its own impact SFX (not the generic 'hit')")
	else:
		_bad("big axe still uses the generic hit SFX")
	if not ResourceLoader.exists("res://src/assets/sounds/bigaxe_impact.mp3"):
		_bad("bigaxe_impact.mp3 missing on disk")

# 6 — a positional player attenuates with distance; that ate the gain.
func _check_boss_voice() -> void:
	var src := FileAccess.get_file_as_string("res://src/boss/boss_voice_system.gd")
	# Check what is actually INSTANTIATED, not every mention of the type — the
	# comment above the fix names the old positional class on purpose.
	if src.contains("AudioStreamPlayer2D.new()") or src.contains("_player: AudioStreamPlayer2D"):
		_bad("boss VO is still POSITIONAL (AudioStreamPlayer2D) — distance attenuation will bury it")
	else:
		_ok("boss VO player is non-positional (no distance attenuation)")
	var re := RegEx.new()
	re.compile("PLAYER_VOLUME_DB\\s*:=\\s*([0-9.]+)")
	var m := re.search(src)
	if m == null:
		_bad("PLAYER_VOLUME_DB not found")
	elif float(m.get_string(1)) < 8.0:
		_bad("boss VO gain %s below the +8 dB floor" % m.get_string(1))
	else:
		_ok("boss VO gain = +%s dB" % m.get_string(1))
	if not src.contains("MUSIC_DUCK_DB"):
		_bad("boss VO does not duck the music")

# 7 — previously reduced, silently back to 30/26.
func _check_hud_text() -> void:
	var src := FileAccess.get_file_as_string("res://src/ui/hud.tscn")
	var re := RegEx.new()
	re.compile("theme_override_font_sizes/font_size = (\\d+)")
	var big: Array = []
	for m in re.search_all(src):
		var v := int(m.get_string(1))
		if v > 22:
			big.append(v)
	if big.is_empty():
		_ok("HUD label font sizes are all <= 22 (reduction restored)")
	else:
		_bad("HUD still has oversized labels: %s" % str(big))

# 8 — the leaf must not swap the track; it gets a celebration instead.
func _check_leaf_music_and_celebration() -> void:
	var src := FileAccess.get_file_as_string("res://src/autoload/game_manager.gd")
	# The override call must not survive inside the blaze/purple branch.
	var idx := src.find("if type == \"blaze\" or type == \"purple\":")
	if idx == -1:
		_bad("blaze/purple power-up branch not found in game_manager")
	else:
		var branch := src.substr(idx, 400)
		if branch.contains("push_music_override"):
			_bad("weed-leaf pickup STILL pushes a music override (founder: music must not change)")
		else:
			_ok("weed-leaf pickup does not change the music")
		if branch.contains("_celebrate_blaze"):
			_ok("weed-leaf pickup fires the celebration")
		else:
			_bad("no celebration on weed-leaf pickup")
	if not ResourceLoader.exists("res://src/assets/sounds/blaze_leaf.mp3"):
		_bad("unique stoner leaf SFX (blaze_leaf.mp3) missing")
	else:
		_ok("unique stoner leaf SFX present")
	var barks := 0
	for n in ["vo_blaze_hype", "vo_blaze_hype_2", "vo_blaze_hype_3"]:
		if ResourceLoader.exists("res://src/assets/sounds/voice/%s.mp3" % n):
			barks += 1
	if barks >= 3:
		_ok("Lil Blunt has %d celebration barks for the leaf" % barks)
	else:
		_bad("only %d/3 leaf celebration barks on disk" % barks)
