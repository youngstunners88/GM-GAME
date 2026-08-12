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
var _readout: Label = null

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
	_setup_hazard()
	_setup_return_portal()
	_setup_hud()
	_setup_title_card()
	AudioManager.set_reverb_profile("cave")
	if MobileInputHandler:
		MobileInputHandler.touch_interact.connect(_on_mobile_interact)

func _physics_process(_delta: float) -> void:
	if _at_altar != "" and Input.is_action_just_pressed("interact"):
		_stake_at(_at_altar)

func _on_mobile_interact() -> void:
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
