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
	# NOTE: assets/music/smoke_lounge.mp3 does not exist in the repo as of this
	# session (checked — only bg_secret_far/mid.jpg and sprite_item_bong.png
	# were placed). play_ambient_loop degrades to silence, same convention
	# play_playlist already uses for any missing track, so dropping the real
	# file in later needs no code change — just the file at this exact path.
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

## Two depth layers at very different motion scales = parallax 3D. Both
## layers already tile indefinitely via motion_mirroring (keyed to the
## texture's own width, not level length), so the 3x BOUNDS extension needs
## no structural change here — only the mid layer's tone shifts toward the
## Smoke Lounge's purple-grey palette instead of the old neutral lounge tint.
func _setup_parallax() -> void:
	var pbg := ParallaxBackground.new()
	pbg.layer = -20
	add_child(pbg)
	# FAR = the deep nebula/skyline. MID = bg_secret_mid.jpg, which IS the whole
	# lounge room (panelled walls, couches, hookah, patterned carpet floor) at
	# exactly 1280x720 — the viewport's own size.
	_add_layer(pbg, FAR_BG, 0.1, Color(0.8, 0.8, 0.95, 1.0))
	_add_layer(pbg, MID_BG, 0.45, Color(0.92, 0.88, 0.98, 1.0))

## WHY THE ROOM LAYER IS VERTICALLY SCREEN-LOCKED (motion_scale.y = 0)
##
## Founder, twice: "the bottom is not an expression of the original image of
## the actual smoke lounge". Both previous attempts treated this as a missing
## OBJECT — first hunting for a stray slab node (there wasn't one), then (me,
## last build) PAINTING an opaque purple ColorRect over the gap. That second
## "fix" is the flat purple band he circled in this round's screenshot: I had
## replaced a wrong image with a wrong rectangle.
##
## The actual cause is layer arithmetic. A ParallaxLayer renders at
##   screen_y = sprite_y - motion_scale.y * camera_top_left.y
## The room art was on motion_scale.y = 0.27, so as the camera sat low in a
## 5100px-wide room the art slid UP the screen and simply ran out below its
## own 720px height — exposing whatever was behind it (the far layer's ocean,
## then my slab).
##
## Setting motion_scale.y = 0 removes the camera's vertical term entirely: the
## room stays pinned to the viewport vertically and can never run out at the
## bottom, while motion_scale.x keeps the horizontal parallax that sells depth.
## Scaling to the LIVE viewport height (not the baked 720) matters because
## project.godot uses stretch/aspect="expand" — on a tall browser window the
## viewport is taller than 720 and a 1:1 sprite would leave a gap again.
func _add_layer(pbg: ParallaxBackground, path: String, speed: float, mod: Color) -> void:
	var tex: Texture2D = load(path)
	if tex == null:
		return
	var view_h: float = get_viewport_rect().size.y
	var fill: float = maxf(1.0, view_h / float(tex.get_height()))
	var layer := ParallaxLayer.new()
	layer.motion_scale = Vector2(speed, 0.0)
	layer.motion_mirroring = Vector2(tex.get_width() * fill, 0.0)
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.centered = false
	spr.scale = Vector2(fill, fill)
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
	# NO under-floor skirt here — deliberately removed, do not re-add.
	#
	# The previous build painted an opaque purple ColorRect across the bottom
	# 300px to hide the far layer's ocean. The founder circled that exact
	# rectangle in his very next screenshot: "the bottom is not an expression
	# of the original image of the actual smoke lounge". Covering wrong art
	# with a flat slab just swaps one wrong thing for another.
	#
	# The room layer is now vertically screen-locked (see _add_layer), so the
	# lounge art itself reaches the bottom of the frame and there is nothing
	# left to cover.

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
	# ON THE BOARD he glides rather than plods: 1.15x speed (the old 0.6 "chill
	# walk" is what made him read as WALKING), 0.8 jump, 1.1 gravity, 0.8 anim.
	player.set_movement_scale(1.15, 0.8, 1.1, 0.8)
	_attach_skateboard(player)
	# The Smoke Lounge's camera limit must match its own 5100px width, not the
	# 3400px baked into player.tscn for the main-sequence levels — otherwise
	# the camera stops panning 1700px short of the real end of the room.
	var cam: Camera2D = player.get_node_or_null("Camera2D")
	if cam:
		cam.limit_left = 0
		cam.limit_right = int(BOUNDS)
		# Prevent the camera from panning below the floor — the parallax
		# background art (bg_secret_far.jpg) has ocean water in its bottom
		# quarter which bleeds through if the camera travels below floor level.
		cam.limit_bottom = int(FLOOR_Y + 120)

# ---- Magic marijuana skateboard (founder defect, raised three times) -------
#
# "I told you that Lil Blunt needs to be on his marijuana skateboard but he's
# still walking in the Smoke Lounge!!!!"
#
# Lounge-ONLY. It is a child of the player node, so it inherits his transform
# for free — no _process follow loop that can jitter or desync, and nothing to
# clean up when the scene changes. Nothing here touches the player script, so
# platforming in every other level is bit-for-bit unchanged.
#
# Geometry: the player's collision box is 32x32 with its ORIGIN AT TOP-LEFT
# (player.tscn CollisionShape2D sits at +16,+16 of a 32x32 rect), so his feet
# are at local y = 32 and his centre line is local x = 16. The deck therefore
# sits at (16, 34) — directly under the soles, not at the sprite centre, which
# is the mistake that put a previous held-tool visual down by his ankles.
const BOARD_DECK_W := 52.0
const BOARD_DECK_H := 7.0
const BOARD_WHEEL_R := 4.5
## Deck centre in player-local Y. His collision box runs 0..32 from the node
## origin, so 31 puts the deck right at the sole line with the wheels just
## below it — he rides ON the board rather than hovering over it.
const BOARD_DECK_Y := 31.0

func _attach_skateboard(player: Node2D) -> void:
	var board := Node2D.new()
	board.name = "Skateboard"
	# Under his VISIBLE soles, not the collision floor.
	#
	# Founder: "I love the skateboard, but it is so far from his feet!!! He
	# needs to be standing ON the skateboard... I notice that he wombles above
	# the skateboard."
	#
	# The board used to sit at the collision floor (local y=32). The character
	# art has transparent padding below its feet, so his painted soles are
	# ~14px higher than that line — the board was correctly placed and still
	# looked detached. lil_blunt_visual now drops the art onto the collision
	# floor (_art_offset_y), which closes the gap from the other side; the deck
	# sits just under that line so the wheels read as touching the ground.
	board.position = Vector2(16, BOARD_DECK_Y)
	# Behind the player so his legs read in front of the deck.
	board.z_index = -1
	player.add_child(board)

	# Trucks + wheels first (drawn under the deck).
	for wx: float in [-BOARD_DECK_W * 0.32, BOARD_DECK_W * 0.32]:
		var truck := ColorRect.new()
		truck.color = Color(0.62, 0.62, 0.68, 1.0)
		truck.size = Vector2(6, 5)
		truck.position = Vector2(wx - 3, 2)
		board.add_child(truck)
		var wheel := _make_cushion(BOARD_WHEEL_R * 2.0, Color(0.98, 0.78, 0.25, 1.0))
		wheel.position = Vector2(wx - BOARD_WHEEL_R, 5)
		board.add_child(wheel)

	# Deck — weed green with a lighter grip strip.
	var deck := ColorRect.new()
	deck.color = Color(0.16, 0.52, 0.18, 1.0)
	deck.size = Vector2(BOARD_DECK_W, BOARD_DECK_H)
	deck.position = Vector2(-BOARD_DECK_W / 2.0, -BOARD_DECK_H / 2.0)
	board.add_child(deck)
	var grip := ColorRect.new()
	grip.color = Color(0.34, 0.78, 0.30, 1.0)
	grip.size = Vector2(BOARD_DECK_W - 6, 2)
	grip.position = Vector2(-BOARD_DECK_W / 2.0 + 3, -BOARD_DECK_H / 2.0)
	board.add_child(grip)

	# The "marijuana" part: the real leaf sprite already in the project, laid
	# on the deck. Guarded — a missing texture must not take the board with it.
	var leaf_path := "res://src/assets/sprites/sprite_item_weed-leaf.png"
	if ResourceLoader.exists(leaf_path):
		var leaf := Sprite2D.new()
		leaf.texture = load(leaf_path)
		leaf.scale = Vector2(0.34, 0.34)
		leaf.position = Vector2(0, -1)
		leaf.z_index = 1
		board.add_child(leaf)

	# Under-deck glow — sells "magic" board and keeps it readable against the
	# lounge's dark carpet.
	var glow := Sprite2D.new()
	glow.texture = _make_glow_texture()
	glow.modulate = Color(0.45, 1.0, 0.45, 0.30)
	glow.scale = Vector2(1.5, 0.42)
	glow.position = Vector2(0, 4)
	glow.z_index = -1
	board.add_child(glow)

	# Idle bob so the board never looks like a static decal stuck to his feet.
	var bob := board.create_tween().set_loops()
	bob.tween_property(board, "position:y", BOARD_DECK_Y - 1.5, 0.9).set_trans(Tween.TRANS_SINE)
	bob.tween_property(board, "position:y", BOARD_DECK_Y, 0.9).set_trans(Tween.TRANS_SINE)

## The reward for finding the door: a run of high-value crypto coins + health,
## spread across the full 5100px walk (scaled 3x from the original 1700px
## layout) so they're "hidden in the haze" along the journey rather than
## clustered in the first quarter of the room.
## SKATE HEIGHT, derived — not guessed.
##
## Founder: "Lil Blunt having a skateboard... not jumping to the token" and
## "the token is still unclaimed even though Lil Blunt is standing in front
## of it."
##
## Every reward here used to sit at FLOOR_SURFACE_Y - 170 (y=490) or -260
## (y=400). The player's body is the 32x32 box from his origin, and with his
## feet on the floor surface (660) that box spans y 628..660. A pickup at 490
## is 138px above the top of his head: it was not "hard to reach", it was
## unreachable without a jump, in a room where the whole point is that he
## never has to jump.
##
## 630 puts a 16px pickup's span at 630..646 — inside the body band with
## ~14px of margin on both sides, so it collects on contact while skating.
## HEIGHT ABOVE THE FLOOR SURFACE (an offset, not an absolute Y).
## FLOOR_SURFACE_Y - 28 = 632, and a pickup there spans 632..676 with its
## 44px trigger — squarely across the standing hurtbox band of 630..660.
const SKATE_PICKUP_Y := 28.0

func _setup_rewards() -> void:
	# A long collectible trail along the skate line — this is the run's reward.
	for i in range(14):
		EntitySpawner.spawn("coin_eth", Vector2(900 + i * 270, FLOOR_SURFACE_Y - SKATE_PICKUP_Y), self)
	EntitySpawner.spawn("coin_btc", Vector2(2460, FLOOR_SURFACE_Y - SKATE_PICKUP_Y), self)
	EntitySpawner.spawn("coin_btc", Vector2(3150, FLOOR_SURFACE_Y - SKATE_PICKUP_Y), self)
	EntitySpawner.spawn("coin_btc", Vector2(4380, FLOOR_SURFACE_Y - SKATE_PICKUP_Y), self)
	EntitySpawner.spawn("health_pickup", Vector2(1750, FLOOR_SURFACE_Y - SKATE_PICKUP_Y), self)
	EntitySpawner.spawn("health_pickup", Vector2(3900, FLOOR_SURFACE_Y - SKATE_PICKUP_Y), self)
	# Founder G2: "in the Smoke Lounge Lil Blunt should also be able to collect
	# some weed nuggets and joints as extra points along with what is currently
	# available there." Drawn in code from the existing leaf art — no new asset
	# dependency, same skate-height band so they collect by rolling through.
	for i in range(18):
		_spawn_nugget(760.0 + i * 230.0, i % 3 == 0)

## A collectable nugget (or joint) worth bonus score. Built as a plain Area2D
## rather than a new .tscn so it needs no scene/import round-trip.
func _spawn_nugget(x: float, is_joint: bool) -> void:
	var pick := Area2D.new()
	pick.collision_layer = 8
	pick.collision_mask = 2
	pick.position = Vector2(x, FLOOR_SURFACE_Y - SKATE_PICKUP_Y)
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(44, 44)   # same forgiving trigger as every other pickup
	cs.shape = rect
	pick.add_child(cs)
	if is_joint:
		var body := ColorRect.new()
		body.color = Color(0.94, 0.90, 0.80, 1.0)
		body.size = Vector2(26, 7)
		body.position = Vector2(-13, -3)
		pick.add_child(body)
		var ember := ColorRect.new()
		ember.color = Color(1.0, 0.45, 0.12, 1.0)
		ember.size = Vector2(6, 7)
		ember.position = Vector2(13, -3)
		pick.add_child(ember)
	else:
		var leaf_path := "res://src/assets/sprites/sprite_item_weed-leaf.png"
		if ResourceLoader.exists(leaf_path):
			var spr := Sprite2D.new()
			spr.texture = load(leaf_path)
			spr.scale = Vector2(0.5, 0.5)
			pick.add_child(spr)
		else:
			var nug := ColorRect.new()
			nug.color = Color(0.30, 0.66, 0.28, 1.0)
			nug.size = Vector2(18, 18)
			nug.position = Vector2(-9, -9)
			pick.add_child(nug)
	var pts: int = 50 if is_joint else 25
	pick.body_entered.connect(func(b: Node2D) -> void:
		if not b.is_in_group("player"):
			return
		ComboSystem.add_score(pts)
		GameManager.add_smoke(1)
		AudioManager.play_sfx_at("coin", pick.global_position)
		pick.set_deferred("monitoring", false)
		var tw := pick.create_tween()
		tw.tween_property(pick, "position:y", pick.position.y - 22.0, 0.22)
		tw.parallel().tween_property(pick, "modulate:a", 0.0, 0.22)
		tw.finished.connect(pick.queue_free))
	add_child(pick)
	var bob := pick.create_tween().set_loops()
	bob.tween_property(pick, "position:y", pick.position.y - 5.0, 0.7)
	bob.tween_property(pick, "position:y", pick.position.y, 0.7)

func _setup_portal() -> void:
	var portal := preload("res://src/level/return_portal.tscn").instantiate()
	portal.global_position = Vector2(BOUNDS - 160, 600)
	add_child(portal)

func _setup_hud() -> void:
	var pm := preload("res://src/ui/pause_menu.tscn").instantiate()
	add_child(pm)
	pm.get_node("VBox/ResumeBtn").pressed.connect(pm._on_resume_pressed)
	pm.get_node("VBox/RestartBtn").pressed.connect(pm._on_restart_pressed)
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
	# KEEP_ASPECT_CENTERED, not SCALE: the protocol logos are square-ish and the
	# frames are not, so STRETCH_SCALE was squashing them — part of why the
	# founder read them as "pixellated". Never distort supplied brand art.
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Near-full brightness. The old 0.9-alpha haze wash was applied on top of
	# art that was already too small to read; dimming legibility for atmosphere
	# is the wrong trade when the founder's complaint IS legibility.
	art.modulate = Color(1.0, 0.98, 1.0, 1.0)
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
## Founder: "These logos are way too small and pixellated to an extent where
## they are not visible. Make these bigger by extending them as if they were
## BILLBOARDS HIGH UP."
##
## The old slots were 90x70 on a 1280-wide viewport — ~7% of screen width, and
## Qwen's vision pass measured them at ~6%, below the threshold where a logo
## reads as a logo at all. These are now 340x260 (~27% of width each), mounted
## high on the back wall with support masts running down to the floor, so they
## read as billboards in the room rather than postage stamps on a plinth.
## SQUARE, so a circular plate is a true circle rather than an ellipse.
## Founder B2/B5: "remove the background of the logo so that we only have it in
## its circular shape" and "they need to fit seamlessly as circular billboards".
## The supplied protocol art is already circular with dark corners, so a round
## plate of the same tone makes the corners disappear instead of reading as a
## square sticker pasted on a square sign.
const BILLBOARD_W := 300.0
const BILLBOARD_H := 300.0
const BILLBOARD_GAP := 60.0
## Top edge, in world Y. Floor surface is 660, so this hangs the boards well
## above head height — "high up", as asked — while staying inside the frame.
const BILLBOARD_TOP := 150.0

func _setup_protocol_plinth(x: float) -> void:
	_add_rest_stop_platform(x, 60.0, 24.0)

	var sign_names := ["SMOKERING", "DIAMONDS", "GOLDMINE"]
	var total_w := BILLBOARD_W * sign_names.size() + BILLBOARD_GAP * (sign_names.size() - 1)
	var start_x := x - total_w / 2.0
	for i in range(sign_names.size()):
		var slot_x: float = start_x + i * (BILLBOARD_W + BILLBOARD_GAP)
		var board_mid: float = slot_x + BILLBOARD_W / 2.0

		# Twin support masts from the board's bottom edge down to the floor, so
		# a 260px board reads as MOUNTED rather than floating.
		for mast_off: float in [-BILLBOARD_W * 0.3, BILLBOARD_W * 0.3]:
			var mast := ColorRect.new()
			mast.color = COLOR_PLATFORM_BODY
			mast.size = Vector2(14, FLOOR_SURFACE_Y - (BILLBOARD_TOP + BILLBOARD_H))
			mast.position = Vector2(board_mid + mast_off - 7, BILLBOARD_TOP + BILLBOARD_H)
			mast.z_index = -2
			add_child(mast)

		var sign := Panel.new()
		sign.position = Vector2(slot_x, BILLBOARD_TOP)
		sign.size = Vector2(BILLBOARD_W, BILLBOARD_H)
		sign.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.06, 0.05, 0.09, 1.0)  # matches the art's own dark field
		sb.border_width_left = 4
		sb.border_width_top = 4
		sb.border_width_right = 4
		sb.border_width_bottom = 4
		sb.border_color = COLOR_LIP_ACCENT
		sb.set_corner_radius_all(int(BILLBOARD_W / 2.0))  # a full circle
		sign.add_theme_stylebox_override("panel", sb)
		add_child(sign)

		var label := Label.new()
		label.text = sign_names[i]
		label.set_anchors_preset(Control.PRESET_FULL_RECT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 30)
		label.add_theme_color_override("font_color", COLOR_LIP_ACCENT)
		sign.add_child(label)
		# Bolt-head corners — cosmetic detail, no function.

		# Warm spill light so the board reads as lit signage in a dim room.
		var spill := Sprite2D.new()
		spill.texture = _make_glow_texture()
		spill.modulate = Color(0.95, 0.75, 0.55, 0.22)
		spill.scale = Vector2(BILLBOARD_W / 42.0, BILLBOARD_H / 40.0)
		spill.position = Vector2(board_mid, BILLBOARD_TOP + BILLBOARD_H / 2.0)
		spill.z_index = -1
		add_child(spill)

		# Drop-in real art: res://src/assets/logos/<name>.png, lowercased.
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
