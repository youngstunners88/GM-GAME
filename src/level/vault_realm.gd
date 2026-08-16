extends Node2D
## VAULT REALM — a full, separate Blaze-class environment the vault door loads
## into. Parametric by protocol: the Diamond Vault (DIAMONDS staking) and Fort
## Knox (GOLD staking) share this one scene, differing by palette, backdrop
## art, and which GoldMineSystem stake primitive the altars call.
##
## Founder (session 4): the vaults must be "a different environment completely"
## like Blaze Rush, "where the player can decide to stake their diamonds ... as
## a gamified example of the real application." This is that: enter -> walk a
## real space -> stake at an altar (commit collected diamonds/gold for shares)
## -> return to the stage.
##
## Modeled on secret_realm.gd (the proven separate-scene bonus environment):
## parallax backdrop, own floor + camera limits, a `return_portal` that resumes
## the origin stage via GameManager.secret_return, which vault_door set on entry.
## The RETURN-to-entry-position is handled entirely by level_base._spawn_player()
## reading secret_return — no resume code lives here.

## Set by the two .tscn variants. "diamonds" -> Diamond Vault, "gold" -> Fort Knox.
@export var protocol: String = "diamonds"

const BOUNDS: float = 2600.0
const FLOOR_Y: float = 648.0          # floor collision-shape centre-ish; surface ~ FLOOR_Y-30
const SURFACE_Y: float = 600.0        # where props/altars sit
const KILL_Y: float = 900.0

var _diamonds: bool = true
## Which altar the player is standing in, "" if none. Drives the interact press.
var _at_altar: String = ""
var _staked_short := false
var _staked_long := false
var _staked_assay := false
var _readout: Label = null

# --- Vault clerk (session 6, T1) --------------------------------------------
## Founder: the vault must "speak to a character that asks how many diamond
## tokens to store in the vault and how many blaze diamonds he wants to crush
## according to stack limit from collections." The clerk (Mira "Ledger" Voss,
## Grok s6) is the real diamond utility: a stake-then-crush dialogue flow that
## moves REAL GoldMineSystem balances. Diamond Vault only.
##
## The flow is a small state machine so it is headlessly testable WITHOUT the
## UI: clerk_open() -> step "stake" -> clerk_adjust()/clerk_confirm_step() ->
## step "crush" -> ... -> step "done" applies via GoldMineSystem primitives.
const CLERK_TERM_DAYS: int = 2888   # clerk stakes at the long (2x) commitment
var _at_clerk: bool = false
var _clerk_open: bool = false       # is the big-button panel showing?
var _clerk_stake_amt: int = 0
var _clerk_crush_amt: int = 0
var _clerk_row: int = 0             # 0 = stake row, 1 = crush row (keyboard focus)
var _clerk_panel: CanvasLayer = null
var _clerk_holdings: Label = null
var _clerk_stake_val: Label = null
var _clerk_crush_val: Label = null
var _clerk_msg: Label = null

# --- Stepped dialogue (T1/T6) -----------------------------------------------
## Founder (session 8): pressing E "must not snap the full conversation
## instantly — the player must have time to read and decide." This reveals ONE
## line per E press; only after the last intro line do the stake/crush/confirm
## buttons appear. Reusable by BOTH Mira and Gideon (Fable-5 s8). UI-free so a
## headless gate can drive it without the panel.
class SteppedDialogue extends RefCounted:
	var lines: Array = []
	var farewell: String = ""
	var idx: int = -1
	func advance() -> String:
		idx = mini(idx + 1, lines.size() - 1)
		return lines[idx] if lines.size() > 0 else ""
	func at_end() -> bool:
		return idx >= lines.size() - 1
	func started() -> bool:
		return idx >= 0
	func leave() -> String:
		idx = -1
		return farewell

var _mira_dlg: SteppedDialogue = null
var _mira_sprite: Sprite2D = null
var _clerk_x: float = 0.0
var _clerk_line: Label = null       # the one currently-shown dialogue line
var _clerk_actions: Array = []      # stake/crush/confirm controls, hidden until dialogue ends

# --- Gideon "Goldwater" Vale (Fort Knox NPC, T5) ----------------------------
var _at_gideon: bool = false
var _gideon_open: bool = false
var _gideon_dlg: SteppedDialogue = null
var _gideon_sprite: Sprite2D = null
var _gideon_x: float = 0.0
var _gideon_panel: CanvasLayer = null
var _gideon_line: Label = null
## The bottom prompt line. Stored so gideon_step can keep it HONEST: on a mid
## line E advances ("[E] next"), on the last line E dismisses ("[E] close").
## A static "[E] next   [ESC] leave" was the founder's "I press E to go next
## but it also cancels" — on the final line E closed the panel while the hint
## still promised another line, so a normal advance read as a cancel.
var _gideon_hint: Label = null

## Play a vault character's VO clip (Mira / Gideon). Fire-and-forget: builds a
## throwaway AudioStreamPlayer that frees itself when the line finishes.
## Voices generated via ElevenLabs (see docs/model-responses + STATUS voice note).
func _play_vo(path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	p.bus = "Master"
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

func _make_mira_dialogue() -> SteppedDialogue:
	var d := SteppedDialogue.new()
	# Grok 4.5 s8 copy — chill, positive.
	d.lines = [
		"Hey Lil Blunt — welcome to the Diamond Vault. What can I get you?",
		"Ready to stake? Hit STAKE and lock those diamonds in.",
		"Feeling bold? CRUSH turns Blaze Diamonds into pure power.",
		"Looking good. CONFIRM when you're set — no rush.",
	]
	d.farewell = "Catch you later — vault's always open for you."
	return d

func _make_gideon_dialogue() -> SteppedDialogue:
	var d := SteppedDialogue.new()
	# Grok 4.5 s8 copy — thick western cowboy accent.
	d.lines = [
		"Howdy, partner! Name's Goldwater Vale — Fort Knox's your gold rush stop.",
		"Step up to the assay scale, friend — let's weigh that glitter proper.",
		"Fancy stakin' yer claim? Park that gold on an altar and let it grow.",
		"That'll do, partner. Hit CONFIRM and we'll lock her down tight.",
	]
	d.farewell = "Ride safe now — come back when yer pockets need fillin' again."
	return d

# --- Readability (T1): every vault label/button is big + black-outlined -------
## Founder (session 7), repeated: vault text is "way too small" and unreadable
## on the busy backdrops — a ship-blocker. One helper styles every label so a
## new label can't ship un-outlined, and 24px is the hard mobile-web minimum
## (Fable/Kimi s7). Colours: cyan for the Diamond Vault, gold for Fort Knox.
const MIN_LABEL_SIZE: int = 24
func _fg() -> Color:
	return Color(0.85, 1.0, 1.0, 1.0) if _diamonds else Color(1.0, 0.9, 0.55, 1.0)

func style_label(l: Label, size: int) -> void:
	var s: int = maxi(size, MIN_LABEL_SIZE)
	l.add_theme_font_size_override("font_size", s)
	l.add_theme_color_override("font_color", _fg())
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	l.add_theme_constant_override("outline_size", maxi(4, int(round(s / 4.0))))

func style_button(b: Button, size: int) -> void:
	var s: int = maxi(size, MIN_LABEL_SIZE)
	b.add_theme_font_size_override("font_size", s)
	b.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	b.add_theme_constant_override("outline_size", maxi(4, int(round(s / 4.0))))

func _ready() -> void:
	_diamonds = protocol == "diamonds"
	StateMachine.change_state(StateMachine.State.PLAYING)
	_setup_backdrop()
	_setup_floor()
	_setup_walls()
	_setup_ambient()
	_spawn_player()
	_setup_altar("short", 900.0)   # 288-day pool: safe, base shares
	_setup_altar("long", 1720.0)   # 2888-day pool: 2x shares, behind a hazard
	if _diamonds:
		_setup_clerk(430.0)        # the stake/crush attendant, near spawn
		# S10 T1: the gold-themed "Diamond Scale" instrument was REMOVED from the
		# Diamond Vault — it read as a golden machine that does not belong in a
		# cyan/diamond space (founder). The Gold Scale is Fort Knox's Assay Scale
		# only, where it is on-theme.
	else:
		_setup_fort_knox_depth()   # second chamber: the GOLD Rush Assay Hall (T4)
	# S10 T1/T2: ONE readable, threatening Security Sentinel per vault — it
	# replaces BOTH the oversized faint background "emblem" AND the abstract
	# sweeping "triangle" hazard the founder called useless. It patrols the
	# crossing to the primary pool and deals contact damage: a real guardian.
	_setup_security_sentinel()
	_setup_return_portal()
	_setup_hud()
	_setup_title_card()
	AudioManager.set_reverb_profile("cave")
	# EXCLUSIVE VAULT MUSIC (founder directive, critical). The vaults previously
	# (wrongly) played their PARENT STAGE themes (level02/level03) — the founder
	# was explicit that each vault must play its OWN exclusive track, NEVER the
	# stage theme. A single-track playlist loops that one track; play_playlist
	# supersedes/ducks whatever was playing (stop-previous), and on exit the
	# stage scene reloads and re-establishes its own music, so "restore on exit"
	# and "never plays outside the vault" both hold for free (separate scene).
	#   Diamond Vault -> diamonds_are_forever.mp3 (exclusive)
	#   Fort Knox     -> goldmine.mp3            (exclusive)
	# NOTE: the founder-supplied MP3s were NOT present in the repo / uploads /
	# Drive at wiring time — see STATUS. play_playlist degrades to SILENCE (never
	# the wrong parent theme) until the files are dropped at these exact paths.
	if _diamonds:
		AudioManager.play_playlist(["res://src/assets/music/diamonds_are_forever.mp3"])
	else:
		AudioManager.play_playlist(["res://src/assets/music/goldmine.mp3"])
	if MobileInputHandler:
		MobileInputHandler.touch_interact.connect(_on_mobile_interact)

func _physics_process(_delta: float) -> void:
	# Mira FACES the player whenever he's around (T1). Her art faces left at rest,
	# so flip_h when the player is to her right.
	if _mira_sprite != null and is_instance_valid(_mira_sprite):
		var pl := get_tree().get_first_node_in_group("player")
		if pl:
			_mira_sprite.flip_h = pl.global_position.x > _clerk_x
	# Gideon faces the player too.
	if _gideon_sprite != null and is_instance_valid(_gideon_sprite):
		var pg := get_tree().get_first_node_in_group("player")
		if pg:
			_gideon_sprite.flip_h = pg.global_position.x > _gideon_x

	# Gideon's stepped dialogue (Fort Knox).
	if _gideon_open:
		if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_accept"):
			gideon_step()
		elif Input.is_action_just_pressed("ui_cancel"):
			gideon_close()
		return
	if _at_gideon and Input.is_action_just_pressed("interact"):
		gideon_open()
		return

	# Clerk panel. STEPPED first (T1/T6): while the intro dialogue is still
	# running, E advances ONE line and the stake/crush/confirm buttons stay
	# hidden — no instant dump. Once the dialogue reaches its last line the
	# action controls appear and the keyboard accelerators take over.
	if _clerk_open:
		if _mira_dlg != null and not _mira_dlg.at_end():
			if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_accept"):
				_clerk_advance_dialogue()
			elif Input.is_action_just_pressed("ui_cancel"):
				clerk_close()
			return
		if Input.is_action_just_pressed("ui_up") or Input.is_action_just_pressed("ui_down"):
			_clerk_row = 1 - _clerk_row
			_refresh_clerk_panel()
		elif Input.is_action_just_pressed("ui_left"):
			clerk_adjust(-1)
		elif Input.is_action_just_pressed("ui_right"):
			clerk_adjust(1)
		elif Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_accept"):
			clerk_confirm()
		elif Input.is_action_just_pressed("ui_cancel"):
			clerk_close()
		return
	if _at_clerk and Input.is_action_just_pressed("interact"):
		clerk_open()
		return
	if _at_altar != "" and Input.is_action_just_pressed("interact"):
		_stake_at(_at_altar)

func _on_mobile_interact() -> void:
	if _clerk_open:
		return  # mobile uses the on-screen buttons directly, not this
	if _at_clerk:
		clerk_open()
		return
	if _at_altar != "":
		_stake_at(_at_altar)

# --- Environment ------------------------------------------------------------

func _setup_backdrop() -> void:
	var pbg := ParallaxBackground.new()
	pbg.layer = -20
	add_child(pbg)
	var path := "res://src/assets/art/vaults/diamond_vault_backdrop.png" if _diamonds \
		else "res://src/assets/art/vaults/fort_knox_backdrop.png"
	if ResourceLoader.exists(path):
		var layer := ParallaxLayer.new()
		var tex: Texture2D = load(path)
		layer.motion_scale = Vector2(0.4, 0.0)  # horizontal parallax, vertically screen-locked
		layer.motion_mirroring = Vector2(tex.get_width(), 0)
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.centered = false
		# Scale the art to fill viewport height (~720); tint slightly for depth.
		var s: float = 720.0 / float(tex.get_height())
		spr.scale = Vector2(s, s)
		spr.modulate = Color(0.9, 0.9, 0.95, 1.0)
		layer.add_child(spr)
		pbg.add_child(layer)
	else:
		# Fallback solid so the realm is never a black void if art is missing.
		var bg := ColorRect.new()
		bg.size = Vector2(BOUNDS + 2000, 1200)
		bg.position = Vector2(-1000, -300)
		bg.color = Color(0.08, 0.10, 0.22, 1.0) if _diamonds else Color(0.16, 0.10, 0.05, 1.0)
		bg.z_index = -30
		add_child(bg)

func _setup_floor() -> void:
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 1
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(BOUNDS, 80)
	col.shape = shape
	col.position = Vector2(BOUNDS / 2.0, FLOOR_Y + 40.0)
	floor_body.add_child(col)
	# Visible deck so the walkable plane reads over the painted backdrop.
	var deck := ColorRect.new()
	deck.size = Vector2(BOUNDS, 120)
	deck.position = Vector2(0, FLOOR_Y)
	deck.color = Color(0.16, 0.22, 0.34, 1.0) if _diamonds else Color(0.20, 0.15, 0.09, 1.0)
	deck.z_index = -2
	floor_body.add_child(deck)
	var lip := ColorRect.new()
	lip.size = Vector2(BOUNDS, 4)
	lip.position = Vector2(0, FLOOR_Y)
	lip.color = Color(0.5, 0.9, 1.0, 0.9) if _diamonds else Color(0.95, 0.75, 0.3, 0.9)
	lip.z_index = -1
	floor_body.add_child(lip)
	add_child(floor_body)

	# Safety kill zone well below (shouldn't be reachable — the floor spans the
	# whole realm — but matches secret_realm's belt-and-braces).
	var kz := Area2D.new()
	kz.collision_layer = 0
	kz.collision_mask = 2
	var kc := CollisionShape2D.new()
	var ks := RectangleShape2D.new()
	ks.size = Vector2(BOUNDS, 80)
	kc.shape = ks
	kz.add_child(kc)
	kz.position = Vector2(BOUNDS / 2.0, KILL_Y)
	kz.body_entered.connect(func(b: Node2D) -> void:
		if b.is_in_group("player") and b.has_method("pit_death"):
			b.pit_death())
	add_child(kz)

func _setup_walls() -> void:
	for x: float in [-8.0, BOUNDS + 8.0]:
		var wall := StaticBody2D.new()
		wall.collision_layer = 1
		var col := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(16, 900)
		col.shape = shape
		col.position = Vector2(x, FLOOR_Y - 300.0)
		wall.add_child(col)
		add_child(wall)

func _setup_ambient() -> void:
	var motes := CPUParticles2D.new()
	motes.texture = load("res://src/assets/sprites/fx_dot.png")
	motes.position = Vector2(BOUNDS / 2.0, 300.0)
	motes.amount = 40
	motes.lifetime = 4.0
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2(BOUNDS / 2.0, 260.0)
	motes.gravity = Vector2(0, 6) if _diamonds else Vector2(8, -4)
	motes.scale_amount_min = 0.15
	motes.scale_amount_max = 0.4
	motes.color = Color(0.7, 0.95, 1.0, 0.5) if _diamonds else Color(1.0, 0.8, 0.35, 0.5)
	motes.z_index = -1
	add_child(motes)

func _spawn_player() -> void:
	var player := preload("res://src/player/player.tscn").instantiate()
	player.global_position = Vector2(160.0, SURFACE_Y - 40.0)
	add_child(player)
	var cam: Camera2D = player.get_node_or_null("Camera2D")
	if cam:
		cam.limit_left = 0
		cam.limit_right = int(BOUNDS)
		cam.limit_bottom = int(FLOOR_Y + 160)

# --- Staking altars (the gamified protocol loop) ----------------------------

func _setup_altar(kind: String, x: float) -> void:
	var altar := Area2D.new()
	altar.name = "Altar_" + kind
	altar.collision_layer = 0
	altar.collision_mask = 2
	altar.position = Vector2(x, SURFACE_Y - 20.0)
	add_child(altar)
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(80, 120)
	cs.shape = rect
	cs.position = Vector2(0, -30)
	altar.add_child(cs)

	# Prop: the founder's deposit-pillar / melt-forge art marks the altar.
	var prop_path := ""
	if _diamonds:
		prop_path = "res://src/assets/art/vaults/diamond_deposit_pillar.png"
	else:
		prop_path = "res://src/assets/art/vaults/goldmine_melt_forge.png"
	# The 2888-day "long" pool is the PRIMARY pool — larger & visually distinct
	# from the 288-day pool (founder T4: "primary pool larger and visually
	# distinct; labels clear").
	var primary: bool = kind == "long"
	if ResourceLoader.exists(prop_path):
		var spr := Sprite2D.new()
		spr.texture = load(prop_path)
		spr.scale = Vector2(0.8, 0.8) if primary else Vector2(0.5, 0.5)
		spr.position = Vector2(0, -70 if primary else -55)
		# Primary pool gets a warm golden tint so it stands apart at a glance.
		spr.modulate = Color(1.25, 1.1, 0.7, 1.0) if primary else Color(1, 1, 1, 1)
		altar.add_child(spr)
	# A halo ring behind the primary pool so it reads as the headline option.
	if primary:
		var halo := Sprite2D.new()
		halo.texture = load("res://src/assets/sprites/fx_dot.png")
		halo.modulate = (Color(0.6, 1.0, 1.0, 0.4) if _diamonds else Color(1.0, 0.85, 0.35, 0.4))
		halo.scale = Vector2(6.0, 6.0)
		halo.position = Vector2(0, -70)
		halo.z_index = -2
		altar.add_child(halo)
	# Term plate — big + outlined so it reads on the busy backdrop (T1). The
	# primary plate is bigger and calls itself out.
	var plate := Label.new()
	plate.text = ("288-DAY POOL" if kind == "short" else "★ 2888-DAY POOL — PRIMARY (2x) ★")
	plate.position = Vector2((-160 if primary else -80), (-200 if primary else -170))
	style_label(plate, 34 if primary else 26)
	altar.add_child(plate)

	# Idle glow so it reads interactive.
	var glow := create_tween().set_loops()
	glow.tween_property(altar, "modulate", Color(1.3, 1.3, 1.3, 1.0), 0.8)
	glow.tween_property(altar, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.8)

	altar.body_entered.connect(func(b: Node2D) -> void:
		if b.is_in_group("player"):
			_at_altar = kind
			_refresh_readout())
	altar.body_exited.connect(func(b: Node2D) -> void:
		if b.is_in_group("player") and _at_altar == kind:
			_at_altar = "")

func _stake_at(kind: String) -> void:
	# The Assay Scale (Fort Knox second chamber, T4): weigh 25% of GOLD into a
	# Fort Knox stake at the full 2888-day term. One-shot per visit, like the
	# altars, and guarded against staking with an empty pocket.
	if kind == "assay":
		if _staked_assay:
			return
		if GoldMineSystem.gold_balance <= 0:
			_float_text("NO GOLD TO ASSAY")
			return
		var amt: int = maxi(1, GoldMineSystem.gold_balance / 4)
		var s: int = GoldMineSystem.stake_in_fort_knox(amt, 2888)
		_staked_assay = true
		AudioManager.play_sfx("powerup")
		ScreenShake.light()
		GameManager.add_score(s * 10)
		_float_text("ASSAYED  +%d SHARES" % s)
		_refresh_readout()
		return
	var days := 288 if kind == "short" else 2888
	if kind == "short" and _staked_short:
		return
	if kind == "long" and _staked_long:
		return
	var shares := 0
	if _diamonds:
		var amt: int = maxi(1, GoldMineSystem.diamonds_balance / 4)
		if GoldMineSystem.diamonds_balance <= 0:
			_float_text("NO DIAMONDS TO STAKE")
			return
		shares = GoldMineSystem.stake_diamonds(amt, days)
	else:
		var amt: int = maxi(1, GoldMineSystem.gold_balance / 4)
		if GoldMineSystem.gold_balance <= 0:
			_float_text("NO GOLD TO STAKE")
			return
		shares = GoldMineSystem.stake_in_fort_knox(amt, days)
	if kind == "short":
		_staked_short = true
	else:
		_staked_long = true
	AudioManager.play_sfx("powerup")
	ScreenShake.light()
	GameManager.add_score(shares * 10)
	_float_text("+%d SHARES" % shares)
	_refresh_readout()

func _float_text(text: String) -> void:
	if _readout == null:
		return
	var f := Label.new()
	f.text = text
	style_label(f, 34)
	f.set_anchors_preset(Control.PRESET_CENTER_TOP)
	f.position = Vector2(0, 90)
	_readout.get_parent().add_child(f)
	var tw := f.create_tween()
	tw.tween_property(f, "position:y", 40.0, 1.2)
	tw.parallel().tween_property(f, "modulate:a", 0.0, 1.2)
	tw.finished.connect(f.queue_free)

# --- Vault clerk: the real diamond utility (T1) -----------------------------

## Build Mira "Ledger" Voss from the FOUNDER'S art (session 7 — do not invent a
## clerk when founder art exists): her standing sprite, a big outlined name
## plate, and the Area2D that opens her big-button dialogue on interact.
const MIRA_ART := "res://src/assets/art/vaults/mira_voss.png"
func _setup_clerk(x: float) -> void:
	var clerk := Node2D.new()
	clerk.name = "VaultClerk"
	# ON THE FLOOR, not floating (founder session 8: "same floor level as Lil
	# Blunt"). The clerk node sits on the floor surface (FLOOR_Y); her sprite is
	# bottom-anchored so her feet land exactly there.
	clerk.position = Vector2(x, FLOOR_Y)
	_clerk_x = x
	_mira_dlg = _make_mira_dialogue()
	add_child(clerk)

	# Founder Mira Voss art. Sprite 602x903, feet at the bottom; centre-anchored
	# with position.y = -target_h/2 so the bottom edge (her feet) is at the clerk
	# node's y == the floor surface.
	var spr := Sprite2D.new()
	var target_h := 210.0
	if ResourceLoader.exists(MIRA_ART):
		var tex: Texture2D = load(MIRA_ART)
		spr.texture = tex
		var s: float = target_h / float(tex.get_height())
		spr.scale = Vector2(s, s)
	spr.position = Vector2(0, -target_h / 2.0)
	clerk.add_child(spr)
	_mira_sprite = spr
	# Soft glow so she reads as interactive against the busy backdrop.
	var glow := Sprite2D.new()
	glow.texture = load("res://src/assets/sprites/fx_dot.png")
	glow.modulate = Color(0.6, 1.0, 1.0, 0.35)
	glow.position = Vector2(0, -90)
	glow.scale = Vector2(3.0, 3.0)
	glow.z_index = -1
	clerk.add_child(glow)
	var gtw := clerk.create_tween().set_loops()
	gtw.tween_property(glow, "modulate:a", 0.5, 1.0).set_trans(Tween.TRANS_SINE)
	gtw.tween_property(glow, "modulate:a", 0.25, 1.0).set_trans(Tween.TRANS_SINE)

	var plate := Label.new()
	plate.text = "MIRA \"LEDGER\" VOSS\n[E] TALK"
	plate.position = Vector2(-96, -250)
	style_label(plate, 26)
	clerk.add_child(plate)

	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	clerk.add_child(area)
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(150, 200)
	cs.shape = rect
	cs.position = Vector2(0, -90)
	area.add_child(cs)
	area.body_entered.connect(func(b: Node2D) -> void:
		if b.is_in_group("player"):
			_at_clerk = true)
	area.body_exited.connect(func(b: Node2D) -> void:
		if b.is_in_group("player"):
			_at_clerk = false
			# FAREWELL (T1): float her parting line + VO as the player leaves.
			if _mira_dlg != null:
				_float_text(_mira_dlg.leave())
				_play_vo("res://src/assets/sounds/voice/vault/mira_farewell.mp3")
			if _clerk_open:
				clerk_close())

## Open the clerk's big-button panel. BOTH the stake and crush rows are visible
## at once (founder session 7: "I don't seem to have the options to utilise the
## diamond tokens" — the old sequential text flow hid them). Amounts default to
## everything held, clamped. Public + logic-only so a headless test drives it.
func clerk_open() -> void:
	if not _diamonds:
		return
	_clerk_open = true
	_clerk_row = 0
	_clerk_stake_amt = GoldMineSystem.diamonds_balance
	_clerk_crush_amt = _crush_cap()
	# Start the STEPPED intro (T1/T6): show her first line, keep the action
	# controls hidden until the player has read through the dialogue.
	if _mira_dlg == null:
		_mira_dlg = _make_mira_dialogue()
	_mira_dlg.idx = -1
	_build_clerk_panel()
	_clerk_advance_dialogue()
	_refresh_clerk_panel()
	_play_vo("res://src/assets/sounds/voice/vault/mira_greet.mp3")  # Mira VO (T1)

## Advance the intro dialogue by one line. When the last line is reached, reveal
## the stake/crush/confirm controls so the player can act.
func _clerk_advance_dialogue() -> void:
	if _mira_dlg == null:
		return
	var line := _mira_dlg.advance()
	if _clerk_line != null and is_instance_valid(_clerk_line):
		_clerk_line.text = "MIRA: " + line
	var show_actions: bool = _mira_dlg.at_end()
	for c in _clerk_actions:
		if is_instance_valid(c):
			c.visible = show_actions

## THE VAULT SECURITY SENTINEL (S10 T1/T2).
##
## Founder, with screenshots: the giant faint "emblem" (300px tall, z_index -6,
## behind everything) read as an OVERSIZED USELESS PROP, and the sweeping damage
## hazard was drawn as an abstract "useless triangle". This folds both into ONE
## thing that actually earns its place: the founder's own sentinel art at a
## MODEST, readable size (SENTINEL_H — deliberately well under the old 300px),
## standing on the vault floor between the two pools, slowly patrolling and
## dealing contact damage. A real security presence you time your crossing to
## the richer 2888 pool around — not a decal, not a screen-eater.
##
## Protocol-aware: diamond_sentinel.png in the Diamond Vault, fortknox_sentinel
## in Fort Knox. No collision LAYER (it never blocks walking — T4 stays clear);
## collision MASK 2 so it detects the player and damages on contact.
const SENTINEL_H: float = 172.0    # < the old 300px oversized emblem, still a clear threat
func _setup_security_sentinel() -> void:
	var art := "res://src/assets/art/vaults/diamond_sentinel.png" if _diamonds \
		else "res://src/assets/art/vaults/fortknox_sentinel.png"
	var guard := Area2D.new()
	guard.name = "SecuritySentinel"
	guard.add_to_group("vault_sentinel")
	guard.collision_layer = 0
	guard.collision_mask = 2          # detects the player only; never blocks a walk
	# Between the two altars, feet on the floor — the risk gate to the 2888 pool.
	var feet_y: float = FLOOR_Y - 28.0
	guard.position = Vector2(1300.0, feet_y)
	add_child(guard)

	# Damage box sized to the torso/legs of the sprite (fair — not the whole
	# bounding box, which on a narrow crossing would be an unfair wall of hurt).
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(72.0, SENTINEL_H * 0.78)
	cs.shape = rect
	cs.position = Vector2(0.0, -SENTINEL_H * 0.5)
	guard.add_child(cs)

	# The founder's sentinel art, bottom-anchored so its feet meet the floor.
	var spr := Sprite2D.new()
	if ResourceLoader.exists(art):
		var tex: Texture2D = load(art)
		spr.texture = tex
		var s: float = SENTINEL_H / float(tex.get_height())
		spr.scale = Vector2(s, s)
	spr.position = Vector2(0.0, -SENTINEL_H / 2.0)
	guard.add_child(spr)

	# Menacing scanner pulse so it reads as an ACTIVE security threat, not a statue.
	var aura := Sprite2D.new()
	aura.texture = load("res://src/assets/sprites/fx_dot.png")
	aura.modulate = Color(1.0, 0.25, 0.25, 0.4) if _diamonds else Color(1.0, 0.4, 0.12, 0.4)
	aura.position = Vector2(0.0, -SENTINEL_H * 0.5)
	aura.scale = Vector2(3.4, 3.4)
	aura.z_index = -1
	guard.add_child(aura)
	var pulse := guard.create_tween().set_loops()
	pulse.tween_property(aura, "modulate:a", 0.12, 0.7).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(aura, "modulate:a", 0.4, 0.7).set_trans(Tween.TRANS_SINE)

	# Name plate — big + outlined, above its head, so the threat is legible.
	var plate := Label.new()
	plate.text = "DIAMOND VAULT\nSECURITY SENTINEL" if _diamonds else "FORT KNOX\nSECURITY SENTINEL"
	plate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plate.custom_minimum_size = Vector2(300.0, 0.0)
	plate.position = Vector2(-150.0, -SENTINEL_H - 82.0)
	style_label(plate, 24)
	guard.add_child(plate)

	guard.body_entered.connect(func(b: Node2D) -> void:
		if b.is_in_group("player") and b.has_method("take_damage"):
			b.take_damage(1))

	# Slow patrol across the crossing — a timing gate, never a static wall.
	var sweep := guard.create_tween().set_loops()
	sweep.tween_property(guard, "position:x", 1480.0, 1.6).set_trans(Tween.TRANS_SINE)
	sweep.tween_property(guard, "position:x", 1300.0, 1.6).set_trans(Tween.TRANS_SINE)

## Upper bound on a crush: never more than held, never more than the stack limit.
func _crush_cap() -> int:
	return mini(GoldMineSystem.blaze_diamonds, GoldMineSystem.BLAZE_DIAMOND_STACK_LIMIT)

## Adjust the currently-focused row (keyboard). The on-screen +/- buttons call
## the row-specific setters directly.
func clerk_adjust(dir: int) -> void:
	if _clerk_row == 0:
		clerk_adjust_stake(dir)
	else:
		clerk_adjust_crush(dir)

func clerk_adjust_stake(dir: int) -> void:
	_clerk_stake_amt = clampi(_clerk_stake_amt + dir, 0, GoldMineSystem.diamonds_balance)
	_refresh_clerk_panel()

func clerk_adjust_crush(dir: int) -> void:
	_clerk_crush_amt = clampi(_clerk_crush_amt + dir, 0, _crush_cap())
	_refresh_clerk_panel()

## CONFIRM: apply BOTH the stake and the crush through the clamped GoldMineSystem
## primitives (the UI never mutates balances directly — Fable/DeepSeek s6/s7), so
## this one method is the single source of truth the headless gate exercises.
func clerk_confirm() -> void:
	if not _clerk_open:
		return
	var shares := 0
	if _clerk_stake_amt > 0:
		shares = GoldMineSystem.stake_diamonds(_clerk_stake_amt, CLERK_TERM_DAYS)
	var minted := 0
	if _clerk_crush_amt > 0:
		minted = GoldMineSystem.crush_blaze_diamonds(_clerk_crush_amt)
	AudioManager.play_sfx("powerup")
	ScreenShake.light()
	GameManager.add_score(shares * 10 + minted)
	_float_text("+%d SHARES  +%d $DIAMONDS" % [shares, minted])
	_refresh_readout()
	clerk_close()

func clerk_close() -> void:
	_clerk_open = false
	if _clerk_panel != null and is_instance_valid(_clerk_panel):
		_clerk_panel.queue_free()
	_clerk_panel = null

# --- Gideon "Goldwater" Vale (Fort Knox NPC, T5) ----------------------------
const GIDEON_ART := "res://src/assets/art/vaults/gideon_vale.png"
func _setup_gideon(x: float, y: float) -> void:
	var g := Node2D.new()
	g.name = "GideonVale"
	g.position = Vector2(x, y)
	_gideon_x = x
	_gideon_dlg = _make_gideon_dialogue()
	add_child(g)
	var spr := Sprite2D.new()
	var target_h := 220.0
	if ResourceLoader.exists(GIDEON_ART):
		var tex: Texture2D = load(GIDEON_ART)
		spr.texture = tex
		spr.scale = Vector2(target_h / float(tex.get_height()), target_h / float(tex.get_height()))
	spr.position = Vector2(0, -target_h / 2.0)
	g.add_child(spr)
	_gideon_sprite = spr
	var plate := Label.new()
	plate.text = "GIDEON \"GOLDWATER\" VALE\n[E] TALK"
	plate.position = Vector2(-110, -280)
	style_label(plate, 26)
	g.add_child(plate)
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	g.add_child(area)
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(160, 220)
	cs.shape = rect
	cs.position = Vector2(0, -100)
	area.add_child(cs)
	area.body_entered.connect(func(b: Node2D) -> void:
		if b.is_in_group("player"):
			_at_gideon = true)
	area.body_exited.connect(func(b: Node2D) -> void:
		if b.is_in_group("player"):
			_at_gideon = false
			if _gideon_dlg != null:
				_float_text(_gideon_dlg.leave())
				_play_vo("res://src/assets/sounds/voice/vault/gideon_farewell.mp3")
			if _gideon_open:
				gideon_close())

func gideon_open() -> void:
	_gideon_open = true
	if _gideon_dlg == null:
		_gideon_dlg = _make_gideon_dialogue()
	_gideon_dlg.idx = -1
	_build_gideon_panel()
	gideon_step()
	_play_vo("res://src/assets/sounds/voice/vault/gideon_greet.mp3")  # Gideon VO (T5)

## Advance Gideon's dialogue one line per E; after the last line, staking is via
## the nearby altars / assay scale (he's a guide, not a menu).
func gideon_step() -> void:
	if _gideon_dlg == null:
		return
	# S10 T3 — "E again does nothing" fix. The OLD code let advance() clamp at
	# the last line and just RE-SHOW it forever, so a second E on the final line
	# was dead input (only ESC could leave). Now: if we are already at the end,
	# this E is the continue/close action — it dismisses the dialogue. Pacing is
	# unchanged (still one line per E up to the last); only the terminal press
	# now resolves instead of doing nothing.
	if _gideon_dlg.at_end():
		gideon_close()
		return
	var line := _gideon_dlg.advance()
	if _gideon_line != null and is_instance_valid(_gideon_line):
		_gideon_line.text = "GIDEON: " + line
	# Keep the prompt truthful about what THIS line's E will do. On the last line
	# the next E closes the panel, so say so — never leave it promising "next".
	if _gideon_hint != null and is_instance_valid(_gideon_hint):
		_gideon_hint.text = ("[E] close   [ESC] leave" if _gideon_dlg.at_end()
			else "[E] next   [ESC] leave")

func gideon_close() -> void:
	_gideon_open = false
	if _gideon_panel != null and is_instance_valid(_gideon_panel):
		_gideon_panel.queue_free()
	_gideon_panel = null

func _build_gideon_panel() -> void:
	if _gideon_panel != null and is_instance_valid(_gideon_panel):
		return
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	_gideon_panel = layer
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_CENTER)
	layer.add_child(root)
	if ResourceLoader.exists(GIDEON_ART):
		var portrait := TextureRect.new()
		portrait.texture = load(GIDEON_ART)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		portrait.custom_minimum_size = Vector2(240, 380)
		portrait.position = Vector2(-540, -190)
		root.add_child(portrait)
	var panel := ColorRect.new()
	panel.color = Color(0.14, 0.09, 0.03, 0.95)
	panel.custom_minimum_size = Vector2(780, 200)
	panel.position = Vector2(-260, -110)
	root.add_child(panel)
	var border := ColorRect.new()
	border.color = Color(1.0, 0.85, 0.4, 1.0)
	border.custom_minimum_size = Vector2(780, 6)
	border.position = Vector2(-260, -110)
	root.add_child(border)
	_gideon_line = Label.new()
	_gideon_line.position = Vector2(-236, -84)
	_gideon_line.custom_minimum_size = Vector2(720, 0)
	_gideon_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	style_label(_gideon_line, 28)
	root.add_child(_gideon_line)
	var hint := Label.new()
	hint.text = "[E] next   [ESC] leave"
	hint.position = Vector2(-236, 40)
	style_label(hint, 22)
	root.add_child(hint)
	# Stored so gideon_step can flip it to "[E] close" on the terminal line.
	_gideon_hint = hint

## A big +/- control row: a large label, a "-" Button, a big value Label, a "+"
## Button. Buttons are >=96px tall touch targets (Fable/Kimi s7).
func _clerk_row_ui(parent: Control, y: float, title: String, minus: Callable, plus: Callable) -> Label:
	var title_l := Label.new()
	title_l.position = Vector2(-236, y)
	style_label(title_l, 30)
	title_l.text = title
	parent.add_child(title_l)
	_clerk_actions.append(title_l)
	var minus_b := Button.new()
	minus_b.text = "-"
	minus_b.custom_minimum_size = Vector2(96, 96)
	minus_b.position = Vector2(100, y - 26)
	style_button(minus_b, 44)
	minus_b.pressed.connect(minus)
	parent.add_child(minus_b)
	_clerk_actions.append(minus_b)
	var val := Label.new()
	val.position = Vector2(214, y - 8)
	val.custom_minimum_size = Vector2(180, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	style_label(val, 40)
	parent.add_child(val)
	_clerk_actions.append(val)
	var plus_b := Button.new()
	plus_b.text = "+"
	plus_b.custom_minimum_size = Vector2(96, 96)
	plus_b.position = Vector2(410, y - 26)
	style_button(plus_b, 44)
	plus_b.pressed.connect(plus)
	parent.add_child(plus_b)
	_clerk_actions.append(plus_b)
	return val

func _build_clerk_panel() -> void:
	if _clerk_panel != null and is_instance_valid(_clerk_panel):
		return
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	_clerk_panel = layer
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_CENTER)
	layer.add_child(root)

	# Mira Voss portrait beside the panel (founder art).
	if ResourceLoader.exists(MIRA_ART):
		var portrait := TextureRect.new()
		portrait.texture = load(MIRA_ART)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		portrait.custom_minimum_size = Vector2(260, 400)
		portrait.position = Vector2(-540, -200)
		root.add_child(portrait)

	var panel := ColorRect.new()
	panel.color = Color(0.04, 0.08, 0.16, 0.95) if _diamonds else Color(0.14, 0.09, 0.03, 0.95)
	panel.custom_minimum_size = Vector2(780, 400)
	panel.position = Vector2(-260, -200)
	root.add_child(panel)
	# Gold/cyan border so the panel pops off the busy backdrop.
	var border := ColorRect.new()
	border.color = _fg()
	border.custom_minimum_size = Vector2(780, 6)
	border.position = Vector2(-260, -200)
	root.add_child(border)

	_clerk_holdings = Label.new()
	_clerk_holdings.position = Vector2(-236, -180)
	style_label(_clerk_holdings, 30)
	root.add_child(_clerk_holdings)

	# The stepped dialogue line — the ONE line currently being read. Always
	# visible; the stake/crush/confirm controls below stay hidden until the
	# player has stepped to the last line (T1/T6: no instant dump).
	_clerk_line = Label.new()
	_clerk_line.position = Vector2(-236, -136)
	_clerk_line.custom_minimum_size = Vector2(720, 0)
	_clerk_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	style_label(_clerk_line, 28)
	root.add_child(_clerk_line)
	var hint := Label.new()
	hint.text = "[E] next"
	hint.position = Vector2(440, -190)
	style_label(hint, 22)
	root.add_child(hint)

	_clerk_actions = []
	_clerk_stake_val = _clerk_row_ui(root, -60.0, "STAKE $DIAMONDS",
		func() -> void: clerk_adjust_stake(-1), func() -> void: clerk_adjust_stake(1))
	_clerk_crush_val = _clerk_row_ui(root, 48.0, "CRUSH BLAZE",
		func() -> void: clerk_adjust_crush(-1), func() -> void: clerk_adjust_crush(1))

	var confirm := Button.new()
	confirm.text = "CONFIRM"
	confirm.name = "CONFIRM"
	confirm.custom_minimum_size = Vector2(320, 96)
	confirm.position = Vector2(-40, 128)
	style_button(confirm, 40)
	confirm.pressed.connect(clerk_confirm)
	root.add_child(confirm)
	_clerk_actions.append(confirm)

	var leave := Button.new()
	leave.text = "LEAVE"
	leave.custom_minimum_size = Vector2(180, 72)
	leave.position = Vector2(300, 140)
	style_button(leave, 30)
	leave.pressed.connect(clerk_close)
	root.add_child(leave)

	_clerk_msg = Label.new()
	_clerk_msg.position = Vector2(-236, 236)
	style_label(_clerk_msg, 24)
	root.add_child(_clerk_msg)

func _refresh_clerk_panel() -> void:
	if _clerk_holdings == null or not is_instance_valid(_clerk_holdings):
		return
	_clerk_holdings.text = "$DIAMONDS: %d      BLAZE DIAMONDS: %d / %d" % [
		GoldMineSystem.diamonds_balance, GoldMineSystem.blaze_diamonds, GoldMineSystem.BLAZE_DIAMOND_STACK_LIMIT]
	_clerk_stake_val.text = str(_clerk_stake_amt)
	_clerk_crush_val.text = "%d  (+%d)" % [_clerk_crush_amt, _clerk_crush_amt * GoldMineSystem.BLAZE_DIAMOND_CRUSH_YIELD]
	# Mira's line reacts to what's in the pocket (Grok s7 copy).
	if GoldMineSystem.diamonds_balance <= 0 and _crush_cap() <= 0:
		_clerk_msg.text = "MIRA: Empty pockets, full vibes. Grab some $DIAMONDS first."
	else:
		_clerk_msg.text = "MIRA: Stake 'em or crush 'em, then CONFIRM."
	# Highlight the keyboard-focused row.
	_clerk_stake_val.modulate = Color(1, 1, 0.5) if _clerk_row == 0 else _fg()
	_clerk_crush_val.modulate = Color(1, 1, 0.5) if _clerk_row == 1 else _fg()

# --- Fort Knox second chamber: the GOLD Rush Assay Hall (T4) -----------------

## Founder (session 6): "Fort Knox needs more development" — deeper than one
## gold room. This adds a real second beat to the GOLD side only: a climb up to
## an elevated ASSAY HALL mezzanine (Grok s6 identity — frontier bank-mine, NOT
## a diamond desk), reached by platforming, holding a new interactable beyond
## coins: the ASSAY SCALE, where Lil Blunt weighs GOLD into a Fort Knox stake.
## Distinct from the Diamond Vault's clerk so it never reads as a reskin.
func _setup_fort_knox_depth() -> void:
	# S10 T2: the Fort Knox Security Sentinel is now the shared, correctly-sized
	# _setup_security_sentinel() guardian (called from _ready) — no more oversized
	# faint background emblem here.
	# GIDEON "GOLDWATER" VALE — Fort Knox speaker on the entrance floor (T5), the
	# first face the player meets (Grok s8 hierarchy).
	_setup_gideon(360.0, FLOOR_Y)
	# Timber-and-iron signage announcing the hall (Grok copy).
	var sign := Label.new()
	sign.text = "FORT KNOX ASSAY — WEIGH IT. STAKE IT. 100-DAY MINERS ONLY."
	sign.position = Vector2(1960.0, SURFACE_Y - 300.0)
	style_label(sign, 26)
	add_child(sign)

	# Climb up to the mezzanine: three stepped platforms (jump-legal — each rise
	# is <= the player's ~92px single-jump apex, checked not eyeballed).
	#
	# S-DUAL: the whole hall shifted LEFT. It used to centre the mezzanine at
	# x=2560 and the Assay Scale on top of it — but the camera pins its right
	# edge at limit_right=BOUNDS(2600), and the scale's art, its RETURN label
	# (+150px) and its "[E] WEIGH GOLD" tag all reach ~2710, well past 2600. That
	# is the founder's "this is off too far off screen": half the instrument sat
	# outside the visible window. HALL_CX centres it so the entire scale — art,
	# both pan labels and the tag — stays inside the camera's right limit with
	# margin. The climb is re-spaced to land on the new deck; rises unchanged.
	const HALL_CX: float = 2380.0
	var steps: Array = [
		Vector2(2020.0, SURFACE_Y - 70.0),
		Vector2(2160.0, SURFACE_Y - 150.0),
		Vector2(2300.0, SURFACE_Y - 230.0),
	]
	for p: Vector2 in steps:
		_build_platform(p, Vector2(150.0, 24.0), true)  # golden highlight (T5)
	# The mezzanine deck itself — the Assay Hall floor (golden). Centred on
	# HALL_CX, width 360 → spans 2200..2560, fully inside limit_right=2600.
	var mezz_y: float = SURFACE_Y - 230.0
	_build_platform(Vector2(HALL_CX, mezz_y), Vector2(360.0, 28.0), true)

	# THE ASSAY SCALE — weigh GOLD into a Fort Knox stake. Grouped so the gate can
	# assert the second chamber exists and is reachable/interactive.
	var scale := Area2D.new()
	scale.name = "AssayScale"
	scale.add_to_group("assay_scale")
	scale.collision_layer = 0
	scale.collision_mask = 2
	scale.position = Vector2(HALL_CX, mezz_y - 40.0)
	add_child(scale)
	var scs := CollisionShape2D.new()
	var srect := RectangleShape2D.new()
	srect.size = Vector2(150.0, 140.0)
	scs.shape = srect
	scs.position = Vector2(0, -30)
	scale.add_child(scs)
	# The founder's Gold Scale instrument (T6): art + readable STAKED/RETURN
	# values + a tilting needle. Built by the shared helper below so the Diamond
	# Vault and Fort Knox show the SAME understandable instrument.
	_build_gold_scale(scale, false)
	var tag := Label.new()
	tag.text = "ASSAY SCALE\n[E] WEIGH GOLD"
	tag.position = Vector2(-90.0, -150.0)
	style_label(tag, 26)
	scale.add_child(tag)
	scale.body_entered.connect(func(b: Node2D) -> void:
		if b.is_in_group("player"):
			_at_altar = "assay")
	scale.body_exited.connect(func(b: Node2D) -> void:
		if b.is_in_group("player") and _at_altar == "assay":
			_at_altar = "")

## The founder Gold Scale instrument, shared by both realms (T6). Draws the
## founder art, labels the two pans STAKED / RETURN (Grok s7), and a needle that
## tilts toward whichever side is heavier — so "what is this and what's it
## telling me" reads at a glance. `diamonds` picks which balances it reads.
func _build_gold_scale(parent: Node2D, diamonds: bool) -> void:
	var art := "res://src/assets/art/vaults/gold_scale.png"
	if ResourceLoader.exists(art):
		var spr := Sprite2D.new()
		var tex: Texture2D = load(art)
		spr.texture = tex
		var target_h := 150.0
		var s: float = target_h / float(tex.get_height())
		spr.scale = Vector2(s, s)
		spr.position = Vector2(0, -40)
		parent.add_child(spr)
	# STAKED (left) and RETURN (right) — large + outlined so a player instantly
	# knows what each pan means.
	var left := Label.new()
	left.text = "STAKED"
	left.position = Vector2(-120, -120)
	style_label(left, 24)
	parent.add_child(left)
	var right := Label.new()
	right.text = "RETURN"
	right.position = Vector2(60, -120)
	style_label(right, 24)
	parent.add_child(right)
	# A needle that tilts toward the heavier side (staked vs return value).
	var needle := Polygon2D.new()
	needle.polygon = PackedVector2Array([Vector2(-3, 0), Vector2(3, 0), Vector2(0, -34)])
	needle.color = Color(1, 0.2, 0.1, 1.0)
	needle.position = Vector2(0, -40)
	parent.add_child(needle)
	# Update the tilt live from the real balances.
	var updater := func() -> void:
		if not is_instance_valid(needle):
			return
		var staked: float = float(GoldMineSystem.diamond_shares if diamonds else GoldMineSystem.fort_knox_shares)
		var ret: float = float(GoldMineSystem.diamonds_balance if diamonds else GoldMineSystem.gold_balance)
		var total: float = maxf(1.0, staked + ret)
		# -0.5..+0.5 rad: leans left when more is staked, right when more is held.
		needle.rotation = clampf((ret - staked) / total, -1.0, 1.0) * 0.5
	updater.call()
	if diamonds:
		GoldMineSystem.diamond_shares_changed.connect(func(_s: int) -> void: updater.call())
		GoldMineSystem.diamonds_changed.connect(func(_s: int) -> void: updater.call())
	else:
		GoldMineSystem.gold_changed.connect(func(_s: int) -> void: updater.call())

## A one-way-safe solid platform used by the Assay Hall climb. `golden` makes it
## a bright, obviously-highlighted route (founder T5: "highlighted platforms →
## golden") with a glowing gold deck + bright lip.
func _build_platform(centre: Vector2, size: Vector2, golden: bool = false) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.add_to_group("golden_platform" if golden else "vault_platform")
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	body.position = centre
	var deck := ColorRect.new()
	deck.size = size
	deck.position = -size / 2.0
	deck.color = Color(0.85, 0.62, 0.15, 1.0) if golden else Color(0.24, 0.17, 0.09, 1.0)
	deck.z_index = -2
	body.add_child(deck)
	var lip := ColorRect.new()
	lip.size = Vector2(size.x, 5 if golden else 3)
	lip.position = Vector2(-size.x / 2.0, -size.y / 2.0)
	lip.color = Color(1.0, 0.92, 0.5, 1.0) if golden else Color(0.95, 0.75, 0.3, 0.9)
	lip.z_index = -1
	body.add_child(lip)
	if golden:
		# A soft pulsing glow so the highlighted route reads at a glance.
		var glow := ColorRect.new()
		glow.size = Vector2(size.x + 12, size.y + 12)
		glow.position = Vector2(-size.x / 2.0 - 6, -size.y / 2.0 - 6)
		glow.color = Color(1.0, 0.85, 0.3, 0.25)
		glow.z_index = -3
		body.add_child(glow)
		var gt := body.create_tween().set_loops()
		gt.tween_property(glow, "modulate:a", 0.4, 0.9).set_trans(Tween.TRANS_SINE)
		gt.tween_property(glow, "modulate:a", 0.9, 0.9).set_trans(Tween.TRANS_SINE)
	add_child(body)

# --- Exit -------------------------------------------------------------------

func _setup_return_portal() -> void:
	var portal := preload("res://src/level/return_portal.tscn").instantiate()
	portal.global_position = Vector2(BOUNDS - 180.0, SURFACE_Y - 30.0)
	add_child(portal)
	var tag := Label.new()
	tag.text = "EXIT ->"
	tag.position = Vector2(BOUNDS - 230.0, SURFACE_Y - 170.0)
	style_label(tag, 28)
	add_child(tag)

# --- HUD / title ------------------------------------------------------------

func _setup_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	_readout = Label.new()
	_readout.position = Vector2(24, 24)
	style_label(_readout, 30)
	layer.add_child(_readout)
	_refresh_readout()
	if _diamonds:
		GoldMineSystem.diamond_shares_changed.connect(func(_s: int) -> void: _refresh_readout())
		GoldMineSystem.diamonds_changed.connect(func(_s: int) -> void: _refresh_readout())
	else:
		# gold_changed / a shares readout — Fort Knox uses fort_knox_shares.
		GoldMineSystem.gold_changed.connect(func(_s: int) -> void: _refresh_readout())

func _refresh_readout() -> void:
	if _readout == null:
		return
	if _diamonds:
		_readout.text = "DIAMONDS %d   |   DIAMOND SHARES %d\nWalk to an altar, press E to STAKE 25%%" % [
			GoldMineSystem.diamonds_balance, GoldMineSystem.diamond_shares]
	else:
		_readout.text = "GOLD %d   |   FORT KNOX SHARES %d\nWalk to an altar, press E to STAKE 25%%" % [
			GoldMineSystem.gold_balance, GoldMineSystem.fort_knox_shares]

func _setup_title_card() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 21
	add_child(layer)
	var title := Label.new()
	title.text = "— THE DIAMOND VAULT —" if _diamonds else "— FORT KNOX —"
	style_label(title, 52)
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(-300, 80)
	layer.add_child(title)
	var tw := title.create_tween()
	tw.tween_interval(2.2)
	tw.tween_property(title, "modulate:a", 0.0, 1.0)
	tw.finished.connect(title.queue_free)
