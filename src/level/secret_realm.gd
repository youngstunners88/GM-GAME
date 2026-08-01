extends Node2D
## The Smoke Lounge — a bonus secret realm reached through a hidden door.
## Formerly "the Chill Lounge"; renamed and expanded per the client's own
## protocol design docs (design/client_protocol_updates.md), which had
## already flagged this exact room as the natural in-game reskin target for
## the tokenomics "Smoke Lounge" destination once he wanted it felt by
## players, rather than only existing as a treasury-routing line item.
##
## Deliberately more decorative and "deep" than the main stages: TWO painted
## parallax layers (a distant cosmic nebula + the near floating-lounge) scroll
## at very different speeds, which reads as real 3D depth in a 2D engine — the
## core trick the game-secret-realm-forge skill documents. Atmospheric, not
## combat: no enemies, no traps, just a long chill walk, ground-level rising
## smoke, three decorative rest stops, and a return portal that drops the
## player back exactly where they left.
##
## Authored in code (not a hand-built .tscn) so the skill can generate variants
## by swapping the two background paths + reward list.

const FAR_BG := "res://src/assets/backgrounds/bg_secret_far.jpg"
const MID_BG := "res://src/assets/backgrounds/bg_secret_mid.jpg"
## 3x the original 1700px — a chill destination should feel like a journey,
## not a room (NEXT_SESSION_Smoke_Lounge_and_Torch.md section 1.3).
const BOUNDS := 5100.0
const FLOOR_Y := 690.0
const FLOOR_SURFACE_Y := FLOOR_Y - 30.0

## Palette (Grok 4.5 art-direction dispatch, docs/model-responses/2026-07-29-grok-smoke-lounge.md)
## Purple-grey haze, chill, nocturnal — deliberately distinct from Smoke Realm's
## forest green and Crystal Caverns' cave cyan.
const COLOR_PLATFORM_BODY := Color(0.239, 0.208, 0.329, 1.0)   # #3d3554
const COLOR_LIP_ACCENT := Color(0.659, 0.565, 0.627, 1.0)      # #a890a0 ash rose
const COLOR_CUSHION := Color(0.361, 0.329, 0.439, 1.0)         # #5c5470
const COLOR_MURAL_MAT := Color(0.165, 0.133, 0.220, 1.0)       # #2a2238
const COLOR_SMOKE_NEAR := Color(0.176, 0.106, 0.306, 0.0)      # #2D1B4E dark purple
const COLOR_SMOKE_MID := Color(0.420, 0.357, 0.478, 0.0)       # #6B5B7A smoke gray

var _smoke: CPUParticles2D
var _perf_timer: float = 0.0

func _ready() -> void:
	StateMachine.change_state(StateMachine.State.PLAYING)
	_setup_ambient_bg_shader()
	_setup_parallax()
	_setup_floor()
	_setup_ground_smoke()
	_spawn_player()
	_setup_rewards()
	_setup_bong_alcove(BOUNDS * 0.33)
	_setup_protocol_plinth(BOUNDS * 0.55)
	_setup_founder_mural(BOUNDS * 0.80)
	_setup_portal()
	_setup_hud()
	_setup_title_card()
	AudioManager.set_reverb_profile("cave")  # roomy lounge echo
	AudioManager.play_ambient_loop("res://src/assets/music/smoke_lounge.mp3", 0.7, 2.0)
	# Commentary a beat after the wipe so it lands once the realm is visible.
	get_tree().create_timer(0.8).timeout.connect(func() -> void:
		AudioManager.play_voice("secret_ambient"))

func _process(delta: float) -> void:
	# Performance budget (spec 1.2): dynamic emission reduction below 45 FPS
	# rather than a fixed cap that never adapts to a slower device.
	if _smoke == null or not is_instance_valid(_smoke):
		return
	_perf_timer -= delta
	if _perf_timer <= 0.0:
		_perf_timer = 1.0
		if Engine.get_frames_per_second() < 45.0 and _smoke.amount > 40:
			_smoke.amount = maxi(40, _smoke.amount - 20)

## Screen-space "living background" layer, behind everything else (Godot
## draws lower CanvasLayer numbers first/further back — the painted parallax
## below sits at -20, so this must be more negative still, or it would fully
## occlude the parallax in front of it; the same layering bug this project
## already caught once in blaze_rush.gd's void/haze layers). A looping video
## background was requested for this room, but the only footage supplied
## depicted sexualized figures and aggressive drug-paraphernalia imagery that
## violates this project's own content rules (no aggressive/stereotypical
## drug imagery; Lil Blunt's brand stays chill, not depicted that way) — this
## procedural shader delivers the same "always-moving atmospheric backdrop"
## brief without that footage: continuous drifting smoke + a slow color
## breathe, zero file size, no video decode cost on the non-threaded web export.
func _setup_ambient_bg_shader() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -21
	add_child(layer)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://src/assets/shaders/smoke_lounge_ambient.gdshader")
	bg.material = mat
	layer.add_child(bg)

## Two depth layers at very different motion scales = parallax 3D. Both
## layers already tile indefinitely via motion_mirroring (keyed to the
## texture's own width, not level length), so the 3x BOUNDS extension needs
## no structural change here — only the mid layer's tone shifts toward the
## Smoke Lounge's purple-grey palette instead of the old neutral lounge tint.
func _setup_parallax() -> void:
	var pbg := ParallaxBackground.new()
	pbg.layer = -20
	add_child(pbg)
	_add_layer(pbg, FAR_BG, 0.1, 1.15, Color(0.8, 0.8, 0.95, 1.0))       # deep, slow, slightly zoomed
	_add_layer(pbg, MID_BG, 0.45, 1.0, Color(0.68, 0.62, 0.82, 1.0))     # near lounge, multiply-tinted purple-grey

func _add_layer(pbg: ParallaxBackground, path: String, speed: float, zoom: float, mod: Color) -> void:
	var tex: Texture2D = load(path)
	if tex == null:
		return
	var layer := ParallaxLayer.new()
	layer.motion_scale = Vector2(speed, speed * 0.6)
	layer.motion_mirroring = Vector2(tex.get_width() * zoom, 0.0)
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.centered = false
	spr.scale = Vector2(zoom, zoom)
	spr.modulate = mod
	layer.add_child(spr)
	pbg.add_child(layer)

func _setup_floor() -> void:
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 1
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(BOUNDS, 60)
	col.shape = shape
	col.position = Vector2(BOUNDS / 2, FLOOR_Y)
	floor_body.add_child(col)
	add_child(floor_body)
	# Kill zone below, in case (shouldn't be reachable, but safe).
	var kz := Area2D.new()
	kz.collision_layer = 0
	kz.collision_mask = 2
	var kc := CollisionShape2D.new()
	var ks := RectangleShape2D.new()
	ks.size = Vector2(BOUNDS, 80)
	kc.shape = ks
	kz.add_child(kc)
	kz.position = Vector2(BOUNDS / 2, 900)
	kz.body_entered.connect(func(b: Node2D) -> void:
		if b.is_in_group("player") and b.has_method("pit_death"):
			b.pit_death())
	add_child(kz)

## Ground-level rising smoke (spec 1.2). Reuses fx_dot.png and the "drifting
## smoke" recipe already proven in src/ui/main_menu.gd's ambience — same
## texture, same CPUParticles2D approach, tuned slower/smaller/hazier for a
## walkable room instead of a menu backdrop. No new art dependency.
func _setup_ground_smoke() -> void:
	_smoke = CPUParticles2D.new()
	_smoke.texture = load("res://src/assets/sprites/fx_dot.png")
	# Negative z_index draws behind the player and platforms (both default to
	# 0) without touching the ParallaxBackground, which is on its own
	# CanvasLayer (-20) and always draws behind regardless of z_index here.
	_smoke.z_index = -1
	_smoke.amount = 130  # ~26/s over a 5s lifetime; under the 200-particle budget
	_smoke.lifetime = 5.0
	_smoke.preprocess = 5.0
	_smoke.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_smoke.emission_rect_extents = Vector2(BOUNDS / 2.0, 4.0)
	_smoke.position = Vector2(BOUNDS / 2.0, FLOOR_SURFACE_Y - 4.0)
	_smoke.direction = Vector2(0, -1)
	_smoke.spread = 15.0
	_smoke.gravity = Vector2.ZERO
	_smoke.initial_velocity_min = 20.0
	_smoke.initial_velocity_max = 40.0

	# Size: 8px base growing to 32px near mid-life, easing back slightly as it
	# fades (fx_dot.png is a 32x32 source, so scale_amount 0.25 = 8px, 1.0 = 32px).
	_smoke.scale_amount_min = 0.25
	_smoke.scale_amount_max = 0.25
	var size_curve := Curve.new()
	size_curve.add_point(Vector2(0.0, 1.0))
	size_curve.add_point(Vector2(0.6, 4.0))
	size_curve.add_point(Vector2(1.0, 3.5))
	_smoke.scale_amount_curve = size_curve

	# Color: dark purple -> smoke gray -> transparent, fading in from nothing at
	# ground level so it doesn't pop, peaking mid-rise, gone before it reaches
	# head height (light ground mist, not a fog wall — platforms stay legible).
	var grad := Gradient.new()
	grad.set_offset(0, 0.0)
	grad.set_color(0, COLOR_SMOKE_NEAR)
	grad.add_point(0.15, Color(COLOR_SMOKE_NEAR.r, COLOR_SMOKE_NEAR.g, COLOR_SMOKE_NEAR.b, 0.5))
	grad.add_point(0.6, Color(COLOR_SMOKE_MID.r, COLOR_SMOKE_MID.g, COLOR_SMOKE_MID.b, 0.32))
	grad.set_offset(1, 1.0)
	grad.set_color(1, COLOR_SMOKE_MID)
	_smoke.color_ramp = grad

	add_child(_smoke)

func _spawn_player() -> void:
	var player := preload("res://src/player/player.tscn").instantiate()
	player.global_position = Vector2(140, 560)
	add_child(player)
	# Slower, chiller pace (spec 1.4): 60% walk speed, 80% jump force, 110%
	# gravity (heavier arc, still clears the flat floor's zero platforming),
	# 80% animation speed. Must run AFTER add_child — set_movement_scale's
	# anim_scale path needs `sprite` (@onready) to already exist.
	player.set_movement_scale(0.6, 0.8, 1.1, 0.8)
	# The Smoke Lounge's camera limit must match its own 5100px width, not the
	# 3400px baked into player.tscn for the main-sequence levels — otherwise
	# the camera stops panning 1700px short of the real end of the room.
	var cam: Camera2D = player.get_node_or_null("Camera2D")
	if cam:
		cam.limit_left = 0
		cam.limit_right = int(BOUNDS)

## The reward for finding the door: a run of high-value crypto coins + health,
## spread across the full 5100px walk (scaled 3x from the original 1700px
## layout) so they're "hidden in the haze" along the journey rather than
## clustered in the first quarter of the room.
func _setup_rewards() -> void:
	for i in range(8):
		EntitySpawner.spawn("coin_eth", Vector2(1080 + i * 390, FLOOR_SURFACE_Y - 170), self)
	EntitySpawner.spawn("coin_btc", Vector2(2460, FLOOR_SURFACE_Y - 260), self)
	EntitySpawner.spawn("coin_btc", Vector2(3150, FLOOR_SURFACE_Y - 260), self)
	EntitySpawner.spawn("health_pickup", Vector2(3900, FLOOR_SURFACE_Y - 170), self)

func _setup_portal() -> void:
	var portal := preload("res://src/level/return_portal.tscn").instantiate()
	portal.global_position = Vector2(BOUNDS - 160, 600)
	add_child(portal)

func _setup_hud() -> void:
	var pm := preload("res://src/ui/pause_menu.tscn").instantiate()
	add_child(pm)
	pm.get_node("VBox/ResumeBtn").pressed.connect(pm._on_resume_pressed)
	pm.get_node("VBox/RestartBtn").pressed.connect(pm._on_restart_pressed)
	pm.get_node("VBox/TalkBtn").pressed.connect(pm._on_talk_pressed)
	pm.get_node("VBox/QuitBtn").pressed.connect(pm._on_quit_pressed)
	add_child(preload("res://src/ui/hud.tscn").instantiate())

## A quiet name-card so the destination reads as "Smoke Lounge" rather than
## an unlabeled side room — fades in, holds, fades out. Screen-space, matches
## the boss health bar's screen-anchored CanvasLayer convention.
func _setup_title_card() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 3
	add_child(layer)
	var label := Label.new()
	label.text = "SMOKE LOUNGE"
	label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	label.position = Vector2(-160, 60)
	label.custom_minimum_size = Vector2(320, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(0.85, 0.78, 0.95, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.10, 0.06, 0.16, 1.0))
	label.add_theme_constant_override("outline_size", 5)
	label.modulate.a = 0.0
	layer.add_child(label)
	var tw := label.create_tween()
	tw.tween_property(label, "modulate:a", 1.0, 1.0)
	tw.tween_interval(2.2)
	tw.tween_property(label, "modulate:a", 0.0, 1.2)
	tw.finished.connect(layer.queue_free)

# ---- Rest stops (Grok 4.5 art-direction dispatch) --------------------------
# Decorative only — no mechanical effect. Built from primitives + the one
# real asset available today (sprite_item_bong.png); founder/protocol art
# slots are placeholders per NEXT_SESSION_Smoke_Lounge_and_Torch.md rule 7
# ("placeholder art is acceptable... do not let missing art block the
# implementation") and drop in later without relayout — only the inner field
# of each sign/mural needs to change.

## Decorative-only platform dressing, shared by all three rest stops. NOT a
## StaticBody2D / no collision shape — the room's single full-width floor
## (_setup_floor) already provides walkable collision across all of BOUNDS,
## including every rest-stop x. A first version gave each rest stop its own
## StaticBody2D flush with the floor's top surface, which stacked a second,
## slightly-raised collision box directly on top of the floor's — a ~10px
## unintended ledge the player caught on and stalled against, found by
## actually walking a browser probe through the room, not by reading the
## code. This just draws on top of the already-solid floor.
func _add_rest_stop_platform(x: float, width: float, height: float = 20.0) -> Node2D:
	var body := Node2D.new()
	body.position = Vector2(x, FLOOR_SURFACE_Y)
	var base := ColorRect.new()
	base.color = COLOR_PLATFORM_BODY
	base.size = Vector2(width, height)
	base.position = Vector2(-width / 2.0, -height)
	body.add_child(base)
	var lip := ColorRect.new()
	lip.color = COLOR_LIP_ACCENT
	lip.size = Vector2(width, 3.0)
	lip.position = Vector2(-width / 2.0, -height)
	body.add_child(lip)
	add_child(body)
	return body

## Small round "cushion" — a Panel with corner_radius set to half its size
## reads as a circle without needing a dedicated sprite.
func _make_cushion(diameter: float, color: Color) -> Panel:
	var p := Panel.new()
	p.size = Vector2(diameter, diameter)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(int(diameter / 2.0))
	p.add_theme_stylebox_override("panel", sb)
	return p

## Drop-in real-art support for the two rest-stop placeholders (logos,
## founder mural). Deliberately NOT a generic AssetSwapper autoload — there
## are exactly four call sites, all already known, and each one is a single
## ResourceLoader.exists() check. A registry/swap-by-key system would be
## more machinery than four call sites justify. If a real texture exists at
## `path`, it replaces the placeholder's children (hidden, not freed, so
## nothing else needs to change if the file is later removed again); if not,
## this is a silent no-op and the placeholder keeps showing, matching every
## other missing-asset convention already used in this codebase.
func _swap_placeholder_texture(container: Control, path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	var tex: Texture2D = load(path)
	if tex == null:
		return
	for child in container.get_children():
		child.visible = false
	var art := TextureRect.new()
	art.texture = tex
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# "Smoke haze overlay" per the original Smoke Lounge spec — reduced
	# opacity, slight desaturation — so real art still reads as part of this
	# hazy room rather than a sharp foreign image pasted on top.
	art.modulate = Color(0.88, 0.85, 0.92, 0.9)
	container.add_child(art)

## Soft radial-falloff light pool, generated once and cached — the same
## "no art dependency for a one-off cosmetic effect" technique already used
## for the player's tool glow (src/player/lil_blunt_visual.gd _make_glow_texture).
var _glow_tex: ImageTexture
func _make_glow_texture() -> ImageTexture:
	if _glow_tex:
		return _glow_tex
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size / 2.0, size / 2.0)
	for x in range(size):
		for y in range(size):
			var d := Vector2(x, y).distance_to(center) / (size / 2.0)
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	_glow_tex = ImageTexture.create_from_image(img)
	return _glow_tex

## Rest stop A — Bong Alcove: a sit/spot landmark, ~1/3 into the run.
func _setup_bong_alcove(x: float) -> void:
	var platform := _add_rest_stop_platform(x, 140.0)
	var glow := Sprite2D.new()
	glow.texture = _make_glow_texture()
	glow.modulate = Color(0.42, 0.36, 0.55, 0.35)
	glow.scale = Vector2(1.4, 0.8)
	glow.position = Vector2(0, -30)
	platform.add_child(glow)
	var bong := Sprite2D.new()
	bong.texture = load("res://src/assets/sprites/sprite_item_bong.png")
	bong.position = Vector2(0, -28)
	platform.add_child(bong)
	var cushion_l := _make_cushion(24.0, COLOR_CUSHION)
	cushion_l.position = Vector2(-46, -24)
	platform.add_child(cushion_l)
	var cushion_r := _make_cushion(24.0, COLOR_CUSHION)
	cushion_r.position = Vector2(22, -24)
	platform.add_child(cushion_r)

## Rest stop B — Protocol Signage Plinth: a mid-run wayfinding beat with three
## logo-placeholder slots (SmokeRing / DIAMONDS / GoldMine), so each protocol
## has a home before real art drops in.
func _setup_protocol_plinth(x: float) -> void:
	_add_rest_stop_platform(x, 60.0, 24.0)
	var post := ColorRect.new()
	post.color = COLOR_PLATFORM_BODY
	post.size = Vector2(16, 70)
	post.position = Vector2(x - 8, FLOOR_SURFACE_Y - 24 - 70)
	add_child(post)

	var sign_names := ["SMOKERING", "DIAMONDS", "GOLDMINE"]
	var slot_w := 90.0
	var total_w := slot_w * sign_names.size() + 12.0 * (sign_names.size() - 1)
	var start_x := x - total_w / 2.0
	for i in range(sign_names.size()):
		var slot_x := start_x + i * (slot_w + 12.0)
		var sign := Panel.new()
		sign.position = Vector2(slot_x, FLOOR_SURFACE_Y - 24 - 70 - 78)
		sign.size = Vector2(slot_w, 70.0)
		sign.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = COLOR_MURAL_MAT
		sb.border_width_left = 2
		sb.border_width_top = 2
		sb.border_width_right = 2
		sb.border_width_bottom = 2
		sb.border_color = COLOR_LIP_ACCENT
		sb.set_corner_radius_all(4)
		sign.add_theme_stylebox_override("panel", sb)
		add_child(sign)
		var label := Label.new()
		label.text = sign_names[i]
		label.set_anchors_preset(Control.PRESET_FULL_RECT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 11)
		label.add_theme_color_override("font_color", COLOR_LIP_ACCENT)
		sign.add_child(label)
		# Bolt-head corners — cosmetic detail, no function.
		for corner in [Vector2(4, 4), Vector2(slot_w - 10, 4), Vector2(4, 60), Vector2(slot_w - 10, 60)]:
			var bolt := _make_cushion(6.0, COLOR_LIP_ACCENT)
			bolt.position = corner
			sign.add_child(bolt)
		# Drop-in real art: res://src/assets/logos/<name>.png, lowercased. No
		# code change needed to go from placeholder to real logo.
		_swap_placeholder_texture(sign, "res://src/assets/logos/%s.png" % sign_names[i].to_lower())

## Rest stop C — Founder Mural Ledge: the destination beat near the far
## third, before the return portal. A long low platform with a wide mural mat
## on the implied back wall and two bongs as symmetric end-caps.
func _setup_founder_mural(x: float) -> void:
	var platform := _add_rest_stop_platform(x, 260.0, 18.0)

	var mat := ColorRect.new()
	mat.color = COLOR_MURAL_MAT
	mat.size = Vector2(220, 130)
	mat.position = Vector2(-110, -18 - 150)
	platform.add_child(mat)
	# inner is a child of mat, not of platform — its position is a small inset
	# relative to mat's own top-left, NOT another absolute platform-relative
	# offset (an earlier version repeated mat's own offset formula here, which
	# double-applied and threw the inset badly out of place; caught by an
	# actual screenshot of the mural, not by reading the numbers).
	var inner := ColorRect.new()
	inner.color = Color(COLOR_PLATFORM_BODY.r, COLOR_PLATFORM_BODY.g, COLOR_PLATFORM_BODY.b, 0.9)
	inner.size = Vector2(190, 95)
	inner.position = Vector2(15, 15)
	mat.add_child(inner)
	var label := Label.new()
	label.text = "FOUNDER MURAL"
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", COLOR_LIP_ACCENT)
	inner.add_child(label)
	# Drop-in real art: res://src/assets/art/founder_portrait.png. No code
	# change needed to go from placeholder to real portrait.
	_swap_placeholder_texture(inner, "res://src/assets/art/founder_portrait.png")
	# "Flickering gently" (spec 1.5) — a slow, subtle alpha breathe, not a hard
	# strobe; a holographic mural should feel alive, not broken.
	var flicker := mat.create_tween().set_loops()
	flicker.tween_property(mat, "modulate:a", 0.82, 1.6).set_trans(Tween.TRANS_SINE)
	flicker.tween_property(mat, "modulate:a", 1.0, 1.6).set_trans(Tween.TRANS_SINE)

	var bong_tex := load("res://src/assets/sprites/sprite_item_bong.png")
	var bong_l := Sprite2D.new()
	bong_l.texture = bong_tex
	bong_l.position = Vector2(-110, -18)
	platform.add_child(bong_l)
	var bong_r := Sprite2D.new()
	bong_r.texture = bong_tex
	bong_r.flip_h = true
	bong_r.position = Vector2(110, -18)
	platform.add_child(bong_r)
