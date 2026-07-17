extends Node2D
## The Chill Lounge — a bonus secret realm reached through a hidden door.
## Deliberately more decorative and "deep" than the main stages: TWO painted
## parallax layers (a distant cosmic nebula + the near floating-lounge) scroll
## at very different speeds, which reads as real 3D depth in a 2D engine — the
## core trick the game-secret-realm-forge skill documents. Grab the bonus and
## step into the glowing portal to return exactly where you left off.
##
## Authored in code (not a hand-built .tscn) so the skill can generate variants
## by swapping the two background paths + reward list.

const FAR_BG := "res://src/assets/backgrounds/bg_secret_far.jpg"
const MID_BG := "res://src/assets/backgrounds/bg_secret_mid.jpg"
const BOUNDS := 1700.0

func _ready() -> void:
	StateMachine.change_state(StateMachine.State.PLAYING)
	_setup_parallax()
	_setup_floor()
	_spawn_player()
	_setup_rewards()
	_setup_portal()
	_setup_hud()
	AudioManager.set_reverb_profile("cave")  # roomy lounge echo
	AudioManager.play_playlist(["res://src/assets/music/lil_blunt_theme.mp3"])
	# Commentary a beat after the wipe so it lands once the realm is visible.
	get_tree().create_timer(0.8).timeout.connect(func() -> void:
		AudioManager.play_voice("secret_ambient"))

## Two depth layers at very different motion scales = parallax 3D.
func _setup_parallax() -> void:
	var pbg := ParallaxBackground.new()
	pbg.layer = -20
	add_child(pbg)
	_add_layer(pbg, FAR_BG, 0.1, 1.15, Color(0.8, 0.8, 0.95, 1.0))   # deep, slow, slightly zoomed
	_add_layer(pbg, MID_BG, 0.45, 1.0, Color(0.95, 0.95, 1.0, 1.0))  # near lounge, faster

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
	col.position = Vector2(BOUNDS / 2, 690)
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

func _spawn_player() -> void:
	var player := preload("res://src/player/player.tscn").instantiate()
	player.global_position = Vector2(140, 560)
	add_child(player)

## The reward for finding the door: a run of high-value crypto coins + health.
func _setup_rewards() -> void:
	for i in range(8):
		EntitySpawner.spawn("coin_eth", Vector2(360 + i * 130, 520), self)
	EntitySpawner.spawn("coin_btc", Vector2(820, 430), self)
	EntitySpawner.spawn("coin_btc", Vector2(1050, 430), self)
	EntitySpawner.spawn("health_pickup", Vector2(1300, 560), self)

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
