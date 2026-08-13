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
var _clerk_step: String = ""        # "", "stake", "crush", "done"
var _clerk_stake_amt: int = 0
var _clerk_crush_amt: int = 0
var _clerk_panel: CanvasLayer = null
var _clerk_prompt: Label = null
var _clerk_amount: Label = null
var _clerk_hint: Label = null

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
	else:
		_setup_fort_knox_depth()   # second chamber: the GOLD Rush Assay Hall (T4)
	_setup_hazard()
	_setup_return_portal()
	_setup_hud()
	_setup_title_card()
	AudioManager.set_reverb_profile("cave")
	if MobileInputHandler:
		MobileInputHandler.touch_interact.connect(_on_mobile_interact)

func _physics_process(_delta: float) -> void:
	# Clerk dialogue takes priority over altar staking when its panel is open.
	if _clerk_step != "":
		if Input.is_action_just_pressed("ui_left"):
			clerk_adjust(-1)
		elif Input.is_action_just_pressed("ui_right"):
			clerk_adjust(1)
		elif Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_accept"):
			clerk_confirm_step()
		elif Input.is_action_just_pressed("ui_cancel"):
			clerk_close()
		return
	if _at_clerk and Input.is_action_just_pressed("interact"):
		clerk_open()
		return
	if _at_altar != "" and Input.is_action_just_pressed("interact"):
		_stake_at(_at_altar)

func _on_mobile_interact() -> void:
	if _clerk_step != "":
		clerk_confirm_step()
		return
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
	if ResourceLoader.exists(prop_path):
		var spr := Sprite2D.new()
		spr.texture = load(prop_path)
		spr.scale = Vector2(0.55, 0.55)
		spr.position = Vector2(0, -60)
		altar.add_child(spr)
	# Term plate.
	var plate := Label.new()
	plate.text = ("288-DAY POOL" if kind == "short" else "2888-DAY POOL  (2x)")
	plate.position = Vector2(-70, -150)
	plate.add_theme_font_size_override("font_size", 13)
	plate.modulate = Color(0.7, 1.0, 1.0, 1.0) if _diamonds else Color(1.0, 0.85, 0.4, 1.0)
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
	f.add_theme_font_size_override("font_size", 22)
	f.modulate = Color(0.7, 1.0, 1.0, 1.0) if _diamonds else Color(1.0, 0.85, 0.4, 1.0)
	f.set_anchors_preset(Control.PRESET_CENTER_TOP)
	f.position = Vector2(0, 90)
	_readout.get_parent().add_child(f)
	var tw := f.create_tween()
	tw.tween_property(f, "position:y", 40.0, 1.2)
	tw.parallel().tween_property(f, "modulate:a", 0.0, 1.2)
	tw.finished.connect(f.queue_free)

# --- Vault clerk: the real diamond utility (T1) -----------------------------

## Build Mira "Ledger" Voss (Grok s6): a slim attendant drawn from primitives —
## a faceted cyan vest, a coin-visor cap, and a floating share-token halo — plus
## the Area2D that opens her dialogue on interact.
func _setup_clerk(x: float) -> void:
	var clerk := Node2D.new()
	clerk.name = "VaultClerk"
	clerk.position = Vector2(x, SURFACE_Y)
	add_child(clerk)

	# Body — faceted diamond-cut vest.
	var vest := Polygon2D.new()
	vest.polygon = PackedVector2Array([
		Vector2(-16, -6), Vector2(16, -6), Vector2(12, 40), Vector2(-12, 40)])
	vest.color = Color(0.55, 0.9, 1.0, 1.0)
	clerk.add_child(vest)
	# Head + coin-visor cap.
	var head := Polygon2D.new()
	head.polygon = PackedVector2Array([
		Vector2(-11, -34), Vector2(11, -34), Vector2(11, -8), Vector2(-11, -8)])
	head.color = Color(0.85, 0.98, 1.0, 1.0)
	clerk.add_child(head)
	var visor := Polygon2D.new()
	visor.polygon = PackedVector2Array([
		Vector2(-15, -34), Vector2(15, -34), Vector2(12, -28), Vector2(-12, -28)])
	visor.color = Color(1.0, 0.85, 0.35, 1.0)
	clerk.add_child(visor)
	# Floating share-token halo behind the head.
	var halo := Sprite2D.new()
	halo.texture = load("res://src/assets/sprites/fx_dot.png")
	halo.modulate = Color(0.6, 1.0, 1.0, 0.7)
	halo.position = Vector2(0, -46)
	halo.scale = Vector2(1.4, 1.4)
	clerk.add_child(halo)
	var bob := clerk.create_tween().set_loops()
	bob.tween_property(halo, "position:y", -52.0, 1.0).set_trans(Tween.TRANS_SINE)
	bob.tween_property(halo, "position:y", -46.0, 1.0).set_trans(Tween.TRANS_SINE)

	var plate := Label.new()
	plate.text = "MIRA \"LEDGER\" VOSS\n[E] TALK"
	plate.position = Vector2(-70, -100)
	plate.add_theme_font_size_override("font_size", 13)
	plate.modulate = Color(0.7, 1.0, 1.0, 1.0)
	clerk.add_child(plate)

	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	clerk.add_child(area)
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(120, 130)
	cs.shape = rect
	cs.position = Vector2(0, -20)
	area.add_child(cs)
	area.body_entered.connect(func(b: Node2D) -> void:
		if b.is_in_group("player"):
			_at_clerk = true)
	area.body_exited.connect(func(b: Node2D) -> void:
		if b.is_in_group("player"):
			_at_clerk = false
			if _clerk_step != "":
				clerk_close())

## Open the clerk dialogue. Starts on the STAKE step, pre-clamped to holdings.
## Public + logic-only so a headless test can drive the whole flow.
func clerk_open() -> void:
	if not _diamonds:
		return
	_clerk_step = "stake"
	_clerk_stake_amt = clampi(GoldMineSystem.diamonds_balance, 0, GoldMineSystem.diamonds_balance)
	_clerk_crush_amt = clampi(_crush_cap(), 0, _crush_cap())
	_build_clerk_panel()
	_refresh_clerk_panel()

## Upper bound on a crush: never more than held, never more than the stack limit.
func _crush_cap() -> int:
	return mini(GoldMineSystem.blaze_diamonds, GoldMineSystem.BLAZE_DIAMOND_STACK_LIMIT)

## Adjust the current step's amount by `dir` (clamped to that step's bounds).
func clerk_adjust(dir: int) -> void:
	match _clerk_step:
		"stake":
			_clerk_stake_amt = clampi(_clerk_stake_amt + dir, 0, GoldMineSystem.diamonds_balance)
		"crush":
			_clerk_crush_amt = clampi(_clerk_crush_amt + dir, 0, _crush_cap())
	_refresh_clerk_panel()

## Confirm the current step and advance. stake -> crush -> done(apply) -> close.
func clerk_confirm_step() -> void:
	match _clerk_step:
		"stake":
			_clerk_step = "crush"
			_clerk_crush_amt = clampi(_clerk_crush_amt, 0, _crush_cap())
		"crush":
			_clerk_apply()
			_clerk_step = "done"
		_:
			clerk_close()
			return
	_refresh_clerk_panel()

## Apply BOTH decisions through the clamped GoldMineSystem primitives. The UI
## never mutates balances directly (Fable-5 s6), so this is the single source of
## truth for the flow and is what the headless gate exercises.
func _clerk_apply() -> void:
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

func clerk_close() -> void:
	_clerk_step = ""
	if _clerk_panel != null and is_instance_valid(_clerk_panel):
		_clerk_panel.queue_free()
	_clerk_panel = null

func _build_clerk_panel() -> void:
	if _clerk_panel != null and is_instance_valid(_clerk_panel):
		return
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	_clerk_panel = layer
	var panel := ColorRect.new()
	panel.color = Color(0.04, 0.08, 0.16, 0.92)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(560, 200)
	panel.position = Vector2(-280, -100)
	layer.add_child(panel)
	_clerk_prompt = Label.new()
	_clerk_prompt.position = Vector2(24, 18)
	_clerk_prompt.add_theme_font_size_override("font_size", 18)
	_clerk_prompt.modulate = Color(0.8, 1.0, 1.0, 1.0)
	panel.add_child(_clerk_prompt)
	_clerk_amount = Label.new()
	_clerk_amount.position = Vector2(24, 96)
	_clerk_amount.add_theme_font_size_override("font_size", 26)
	_clerk_amount.modulate = Color(1.0, 0.95, 0.6, 1.0)
	panel.add_child(_clerk_amount)
	_clerk_hint = Label.new()
	_clerk_hint.position = Vector2(24, 150)
	_clerk_hint.add_theme_font_size_override("font_size", 13)
	_clerk_hint.modulate = Color(0.7, 0.85, 0.95, 1.0)
	panel.add_child(_clerk_hint)

func _refresh_clerk_panel() -> void:
	if _clerk_prompt == null or not is_instance_valid(_clerk_prompt):
		return
	match _clerk_step:
		"stake":
			_clerk_prompt.text = "MIRA: How many $DIAMONDS you locking in?\nLonger days, fatter share mint. (held: %d)" % GoldMineSystem.diamonds_balance
			_clerk_amount.text = "STAKE  %d  $DIAMONDS" % _clerk_stake_amt
		"crush":
			if _crush_cap() <= 0:
				_clerk_prompt.text = "MIRA: No Blaze Diamonds to crush.\nDash a Blaze Rush and come back glowing."
			else:
				_clerk_prompt.text = "MIRA: How many Blaze Diamonds we crushing?\nStack limit's whatever you collected. (held: %d / %d)" % [GoldMineSystem.blaze_diamonds, GoldMineSystem.BLAZE_DIAMOND_STACK_LIMIT]
			_clerk_amount.text = "CRUSH  %d  ->  +%d $DIAMONDS" % [_clerk_crush_amt, _clerk_crush_amt * GoldMineSystem.BLAZE_DIAMOND_CRUSH_YIELD]
		"done":
			_clerk_prompt.text = "MIRA: Locked and ledgered.\nShares minted — pools drip when the epoch turns."
			_clerk_amount.text = ""
	_clerk_hint.text = "[<-]/[->] adjust    [E] confirm    [ESC] leave"

# --- Fort Knox second chamber: the GOLD Rush Assay Hall (T4) -----------------

## Founder (session 6): "Fort Knox needs more development" — deeper than one
## gold room. This adds a real second beat to the GOLD side only: a climb up to
## an elevated ASSAY HALL mezzanine (Grok s6 identity — frontier bank-mine, NOT
## a diamond desk), reached by platforming, holding a new interactable beyond
## coins: the ASSAY SCALE, where Lil Blunt weighs GOLD into a Fort Knox stake.
## Distinct from the Diamond Vault's clerk so it never reads as a reskin.
func _setup_fort_knox_depth() -> void:
	# Timber-and-iron signage announcing the hall (Grok copy).
	var sign := Label.new()
	sign.text = "FORT KNOX ASSAY — WEIGH IT. STAKE IT. 100-DAY MINERS ONLY."
	sign.position = Vector2(1980.0, SURFACE_Y - 250.0)
	sign.add_theme_font_size_override("font_size", 15)
	sign.modulate = Color(1.0, 0.85, 0.4, 1.0)
	add_child(sign)

	# Climb up to the mezzanine: three stepped platforms (jump-legal — each rise
	# is <= the player's ~92px single-jump apex, checked not eyeballed).
	var steps: Array = [
		Vector2(2020.0, SURFACE_Y - 70.0),
		Vector2(2200.0, SURFACE_Y - 150.0),
		Vector2(2380.0, SURFACE_Y - 230.0),
	]
	for p: Vector2 in steps:
		_build_platform(p, Vector2(150.0, 24.0))
	# The mezzanine deck itself — the Assay Hall floor.
	var mezz_y: float = SURFACE_Y - 230.0
	_build_platform(Vector2(2560.0, mezz_y), Vector2(360.0, 28.0))

	# THE ASSAY SCALE — weigh GOLD into a Fort Knox stake. Grouped so the gate can
	# assert the second chamber exists and is reachable/interactive.
	var scale := Area2D.new()
	scale.name = "AssayScale"
	scale.add_to_group("assay_scale")
	scale.collision_layer = 0
	scale.collision_mask = 2
	scale.position = Vector2(2560.0, mezz_y - 40.0)
	add_child(scale)
	var scs := CollisionShape2D.new()
	var srect := RectangleShape2D.new()
	srect.size = Vector2(120.0, 100.0)
	scs.shape = srect
	scale.add_child(scs)
	# A balance-scale silhouette from primitives (Grok's "Assay Scale & Claim
	# Wheel"): a post, a beam, two pans.
	var post := Polygon2D.new()
	post.polygon = PackedVector2Array([Vector2(-4,0), Vector2(4,0), Vector2(4,40), Vector2(-4,40)])
	post.color = Color(0.5, 0.4, 0.2, 1.0)
	scale.add_child(post)
	var beam := Polygon2D.new()
	beam.polygon = PackedVector2Array([Vector2(-44,-2), Vector2(44,-2), Vector2(44,4), Vector2(-44,4)])
	beam.color = Color(0.85, 0.7, 0.35, 1.0)
	scale.add_child(beam)
	for sx: float in [-44.0, 44.0]:
		var pan := Polygon2D.new()
		pan.polygon = PackedVector2Array([Vector2(sx-14,10), Vector2(sx+14,10), Vector2(sx+9,22), Vector2(sx-9,22)])
		pan.color = Color(1.0, 0.82, 0.3, 1.0)
		scale.add_child(pan)
	var tag := Label.new()
	tag.text = "ASSAY SCALE\n[E] WEIGH GOLD"
	tag.position = Vector2(-56.0, -78.0)
	tag.add_theme_font_size_override("font_size", 13)
	tag.modulate = Color(1.0, 0.88, 0.5, 1.0)
	scale.add_child(tag)
	scale.body_entered.connect(func(b: Node2D) -> void:
		if b.is_in_group("player"):
			_at_altar = "assay")
	scale.body_exited.connect(func(b: Node2D) -> void:
		if b.is_in_group("player") and _at_altar == "assay":
			_at_altar = "")

## A one-way-safe solid platform used by the Assay Hall climb.
func _build_platform(centre: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	body.position = centre
	var deck := ColorRect.new()
	deck.size = size
	deck.position = -size / 2.0
	deck.color = Color(0.24, 0.17, 0.09, 1.0)
	deck.z_index = -2
	body.add_child(deck)
	var lip := ColorRect.new()
	lip.size = Vector2(size.x, 3)
	lip.position = Vector2(-size.x / 2.0, -size.y / 2.0)
	lip.color = Color(0.95, 0.75, 0.3, 0.9)
	lip.z_index = -1
	body.add_child(lip)
	add_child(body)

# --- Hazard (risk half of the stake loop, protocol-flavoured) ---------------

func _setup_hazard() -> void:
	# Between the two altars: crossing to the richer 2888 pool costs a little
	# risk. Diamond = a slow crystal sentry sweep; Fort Knox = a steam vent.
	var hz := Area2D.new()
	hz.collision_layer = 0
	hz.collision_mask = 2
	hz.position = Vector2(1300.0, SURFACE_Y - 20.0)
	add_child(hz)
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(28, 60)
	cs.shape = rect
	hz.add_child(cs)
	var poly := Polygon2D.new()
	if _diamonds:
		poly.polygon = PackedVector2Array([Vector2(0,-30),Vector2(12,20),Vector2(-12,20)])
		poly.color = Color(0.55, 0.9, 1.0, 0.9)
	else:
		poly.polygon = PackedVector2Array([Vector2(-12,-24),Vector2(12,-24),Vector2(12,24),Vector2(-12,24)])
		poly.color = Color(1.0, 0.6, 0.2, 0.9)
	hz.add_child(poly)
	hz.body_entered.connect(func(b: Node2D) -> void:
		if b.is_in_group("player") and b.has_method("take_damage"):
			b.take_damage(1))
	# Sweep it back and forth so it's a timing crossing, not a static wall.
	var sweep := create_tween().set_loops()
	sweep.tween_property(hz, "position:x", 1480.0, 1.4).set_trans(Tween.TRANS_SINE)
	sweep.tween_property(hz, "position:x", 1300.0, 1.4).set_trans(Tween.TRANS_SINE)

# --- Exit -------------------------------------------------------------------

func _setup_return_portal() -> void:
	var portal := preload("res://src/level/return_portal.tscn").instantiate()
	portal.global_position = Vector2(BOUNDS - 180.0, SURFACE_Y - 30.0)
	add_child(portal)
	var tag := Label.new()
	tag.text = "EXIT ->"
	tag.position = Vector2(BOUNDS - 210.0, SURFACE_Y - 150.0)
	tag.add_theme_font_size_override("font_size", 14)
	tag.modulate = Color(0.8, 1.0, 1.0, 1.0) if _diamonds else Color(1.0, 0.85, 0.4, 1.0)
	add_child(tag)

# --- HUD / title ------------------------------------------------------------

func _setup_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	_readout = Label.new()
	_readout.add_theme_font_size_override("font_size", 20)
	_readout.position = Vector2(24, 24)
	_readout.modulate = Color(0.8, 1.0, 1.0, 1.0) if _diamonds else Color(1.0, 0.88, 0.5, 1.0)
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
	title.add_theme_font_size_override("font_size", 44)
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(-260, 80)
	title.modulate = Color(0.7, 1.0, 1.0, 1.0) if _diamonds else Color(1.0, 0.85, 0.4, 1.0)
	layer.add_child(title)
	var tw := title.create_tween()
	tw.tween_interval(2.2)
	tw.tween_property(title, "modulate:a", 0.0, 1.0)
	tw.finished.connect(title.queue_free)
