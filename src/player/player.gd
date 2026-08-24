class_name Player
extends CharacterBody2D

enum Outfit { DEFAULT, MINER, CRYSTAL }

signal died

@export var walk_speed: float = 200.0
@export var jump_force: float = -430.0
@export var gravity: float = 1000.0
## Mario-style stomp: landing on an enemy's head damages/kills it and bounces
## the player back up — smaller than a real jump (jump_force=-430) so it
## chains into another stomp or a normal jump without feeling like a full
## reset. Founder defect #10: no stomp existed before this; every enemy
## contact (including landing on its head) hurt the PLAYER instead.
@export var stomp_bounce_force: float = -300.0
## Minimum downward speed for contact to count as a stomp — filters out
## brushing an enemy at the apex of a jump.
@export var stomp_min_fall_speed: float = 40.0
## How far above the enemy's own origin the player's origin must be to count
## as "landed on its head" rather than a side/below hit. Margin is generous
## (most enemy sprites in this project are ~32-96px) but still excludes a
## same-height side bump.
const STOMP_Y_MARGIN: float = 8.0
## How close the player's ORIGIN must get to a ladder's top before "still
## holding up" tops him out onto the platform.
##
## This was 6.0, which made the top-out physically unreachable whenever a
## solid platform sat at the ladder's top — i.e. the normal case, and the
## reason "climbing a ladder doesn't get me onto the platform" survived
## several offset re-tunings. Climbing runs through move_and_slide(), so the
## player COLLIDES with the platform's underside on the way up: with a 20px
## platform whose top edge is level with the ladder top, and a 32px collision
## box (half-height 16), he is stopped with his origin ~36px below the
## ladder top and can never satisfy a 6px threshold. He just presses up
## forever under the platform.
##
## 44 clears that worst case (20 platform + 16 half-box + slack). Topping out
## a little early is harmless: _top_out_ladder() teleports to the ladder's
## defined top_exit_position() and then nudges out of any overlap, so the
## landing spot is identical either way.
const LADDER_TOP_OUT_MARGIN: float = 44.0
@export var double_jump_force: float = -370.0
## Falling pulls harder than rising — same jump height (level gaps unchanged),
## ~15% less airtime, kills the floaty feel.
@export var fall_gravity_mult: float = 1.65
@export var max_fall_speed: float = 720.0
## px/s² — ~0.1s from standstill to full run on the ground.
@export var ground_accel: float = 2000.0
@export var ground_decel: float = 2800.0
@export var air_accel: float = 1400.0
@export var air_decel: float = 900.0
## Friction applied when moving faster than input speed in the same direction —
## lets dash/knockback/wall-jump momentum bleed off instead of hard-snapping.
@export var momentum_friction_floor: float = 1200.0
@export var momentum_friction_air: float = 350.0
## Bong "fly" power-up: hold jump/up to rise, release to drift down gently.
## No gravity while active — pure floaty control for the ~10s duration.
@export var fly_rise_speed: float = 260.0
@export var fly_sink_speed: float = 90.0

var current_outfit: Outfit = Outfit.DEFAULT
var _last_fall_speed: float = 0.0
## True from the killing blow until the respawn/game-over resolves. Guards
## die() against re-entry from multiple lethal hits in the same frame.
var _dying: bool = false

## Optional external horizontal steer, in the same -1..1 space as keyboard
## input. Set by the Smoke Lounge so the founder's "or using the mouse to
## direct Lil Blunt to the tokens" works. Inert everywhere else — the
## campaign levels never touch it, so their input handling is unchanged.
var steer_override_active: bool = false
var steer_override: float = 0.0

## Ambient level-driven movement scaling (e.g. the Smoke Lounge's chill pace).
## Separate from power_up_handler's speed/jump multiplier so a level's mood
## and an active power-up compose multiplicatively instead of one clobbering
## the other. 1.0 on all four = no effect; a level scene calls
## set_movement_scale() once, before or after add_child (no _ready dependency).
var level_speed_scale: float = 1.0
var level_jump_scale: float = 1.0
var level_gravity_scale: float = 1.0

# Ladder climbing state (task #23): zone refcount maintained by ladder.gd via
# enter/exit_ladder_zone(); _climbing is the CLIMB state flag.
var _ladder_zones: int = 0
var _climbing: bool = false
var _active_ladder: Node2D = null   # the ladder whose zone we're in (top-out)

## Rolling "last safe ground" buffer for death respawn. Two slots so a pit
## death respawns at the sample BEFORE the crumbling lip, not on the edge the
## player just walked off. Sampled ~2x/sec while grounded (see _physics_process).
## Founder (session 4): dying in Stage 3 "he appears somewhere else!!! He must
## reappear exactly or close to where he died." Root cause: _respawn_or_game_over
## fell back to get_checkpoint(1) — a LEVEL-1 coordinate — when the current
## level had no checkpoint; this replaces that with the real death-adjacent spot.
var _last_safe_position: Vector2 = Vector2.ZERO
var _prev_safe_position: Vector2 = Vector2.ZERO
var _safe_pos_timer: float = 0.0
@export var climb_speed: float = 150.0

@onready var sprite: LilBluntVisual = $Visual
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var camera: Camera2D = $Camera2D
@onready var smoke_spawn: Marker2D = $SmokeSpawn
@onready var hurtbox: Area2D = $Hurtbox
@onready var aura: Area2D = $Aura
@onready var power_up_handler: PowerUpHandler = $PowerUpHandler
@onready var input_handler: InputHandler = $InputHandler
@onready var wall_sparks: CPUParticles2D = $WallSparks
@onready var sprint_dust: CPUParticles2D = $SprintDust

func _ready() -> void:
	add_to_group("player")
	GameManager.reset_level()
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	hurtbox.body_entered.connect(_on_hurtbox_body_entered)
	aura.body_entered.connect(_on_aura_body_entered)
	ScreenShake.register_camera(camera)
	GameManager.blaze_celebration.connect(_on_blaze_celebration)

	if MobileInputHandler:
		MobileInputHandler.touch_jump.connect(_on_mobile_jump)
		MobileInputHandler.touch_dash.connect(_on_mobile_dash)

## Called by a level scene (e.g. the Smoke Lounge) to apply an ambient pace
## on top of whatever power-up multiplier is already active. `anim_scale`
## needs `sprite` to exist, so it's a no-op if called before add_child — call
## this after the player is in the tree, not before.
func set_movement_scale(speed_scale: float = 1.0, jump_scale: float = 1.0, gravity_scale: float = 1.0, anim_scale: float = 1.0) -> void:
	level_speed_scale = speed_scale
	level_jump_scale = jump_scale
	level_gravity_scale = gravity_scale
	if is_instance_valid(sprite):
		sprite.set_speed_scale(anim_scale)

func _physics_process(delta: float) -> void:
	if not StateMachine.is_playing():
		return

	# Roll the "last safe ground" buffer while grounded, ~2x/sec. Two slots so a
	# fall respawns at the sample before the lip, not the edge just left (see the
	# field comment). Cheap; runs every frame but only samples on the timer.
	if is_on_floor() and not _dying:
		_safe_pos_timer -= delta
		if _safe_pos_timer <= 0.0:
			_safe_pos_timer = 0.5
			_prev_safe_position = _last_safe_position if _last_safe_position != Vector2.ZERO else global_position
			_last_safe_position = global_position

	var speed_mult: float = power_up_handler.speed_multiplier
	var jump_mult: float = power_up_handler.jump_multiplier
	var sprint_mult: float = input_handler.get_sprint_multiplier()

	# Get movement input from keyboard OR mobile
	var movement_direction: float = input_handler.get_movement_direction()
	if MobileInputHandler:
		movement_direction = MobileInputHandler.get_movement_input()
	# Smoke Lounge skate cruise: the level can drive steering directly (mouse
	# aim) on frames where the player isn't already pressing a direction.
	# Keyboard always wins so arrows never feel unresponsive. Opt-in and
	# off by default, so no campaign level's handling changes.
	if steer_override_active and is_zero_approx(movement_direction):
		movement_direction = steer_override

	# Bong flight: hold jump/up to rise, otherwise sink slowly. Overrides all
	# normal gravity/wall/jump vertical logic for the duration. Trippy green
	# smoke trail sells the "lifted" fantasy.
	if GameManager.has_power_up("fly"):
		_update_fly(delta, movement_direction)
		return

	# Ladder climbing (task #23). Enter by pressing up/down inside a ladder
	# zone; while climbing gravity is off and vertical input drives movement.
	# Jump exits with a full jump (mid-climb hop-off); leaving the zone exits.
	if _climbing:
		_update_climb(delta, movement_direction)
		return
	if _ladder_zones > 0 and (Input.is_action_pressed("move_up") or Input.is_action_pressed("move_down")):
		_climbing = true
		velocity = Vector2.ZERO
		_last_fall_speed = 0.0  # else a stale pre-climb value can false-trigger a stomp mid-climb
		input_handler.is_wall_sliding = false
		wall_sparks.emitting = false
		# MUST return here. Without it, the rest of this function (gravity,
		# then the floor/coyote jump check further down) still runs on the
		# SAME frame — and since "jump" and "move_up" share the W key on the
		# default WASD binding, the exact keypress that starts a climb also
		# satisfies the jump check, firing a real jump that stomps the
		# velocity=ZERO just set above. Entering climb state is a hard mode
		# switch, same as the `if _climbing: ...; return` case above it.
		return

	# Gravity — wall slide uses reduced gravity while pressing into the wall
	if not is_on_floor():
		var pressing_wall := is_on_wall() and movement_direction != 0
		if pressing_wall and velocity.y > 0:
			input_handler.is_wall_sliding = true
			velocity.y = minf(velocity.y + InputHandler.WALL_SLIDE_GRAVITY * delta,
					InputHandler.WALL_SLIDE_MAX_SPEED)
			wall_sparks.emitting = true
		else:
			input_handler.is_wall_sliding = false
			var g := gravity * level_gravity_scale * (fall_gravity_mult if velocity.y > 0.0 else 1.0)
			velocity.y = minf(velocity.y + g * delta, max_fall_speed)
			wall_sparks.emitting = false
		_last_fall_speed = velocity.y
		input_handler.on_left_ground()
	else:
		input_handler.is_wall_sliding = false
		wall_sparks.emitting = false
		var had_buffer := input_handler.jump_buffer_timer > 0
		# First frame back on the ground after a hard fall → landing squash.
		if input_handler.coyote_timer <= 0 and _last_fall_speed > 380.0 and not had_buffer:
			_play_land_squash()
		_last_fall_speed = 0.0
		input_handler.on_landed()
		if had_buffer:
			velocity.y = jump_force * jump_mult * level_jump_scale
			_play_jump_stretch()
			AudioManager.play_sfx("jump")

	# Variable jump height — release early to cut arc (Skill 3)
	if input_handler.is_jump_released() and velocity.y < 0:
		velocity.y *= 0.5

	# Movement + sprint — accelerate toward input speed instead of snapping.
	# Excess same-direction momentum (dash, knockback, wall jump) bleeds off
	# through gentler friction so those moves keep their punch.
	var direction := movement_direction
	if direction != 0:
		input_handler.handle_facing_direction(direction)
		var target_speed := direction * walk_speed * speed_mult * sprint_mult * level_speed_scale
		if signf(velocity.x) == signf(target_speed) and absf(velocity.x) > absf(target_speed):
			var friction := momentum_friction_floor if is_on_floor() else momentum_friction_air
			velocity.x = move_toward(velocity.x, target_speed, friction * delta)
		else:
			var accel := ground_accel if is_on_floor() else air_accel
			velocity.x = move_toward(velocity.x, target_speed, accel * delta)
	else:
		var decel := ground_decel if is_on_floor() else air_decel
		velocity.x = move_toward(velocity.x, 0.0, decel * delta)

	# Sprint dust — only when running fast on ground
	sprint_dust.emitting = is_on_floor() and direction != 0 and sprint_mult > 1.0

	# Jump — floor/coyote, wall jump, double jump
	if input_handler.is_jump_pressed():
		if is_on_floor() or input_handler.coyote_timer > 0:
			velocity.y = jump_force * jump_mult * level_jump_scale
			input_handler.reset_coyote()
			input_handler.can_double_jump = true
			input_handler.can_air_dash = true
			_play_jump_stretch()
			AudioManager.play_sfx("jump")
		elif input_handler.is_wall_sliding:
			var wall_dir := -1.0 if input_handler.facing_right else 1.0
			velocity.x = wall_dir * input_handler.wall_jump_force.x * 1.2
			velocity.y = input_handler.wall_jump_force.y
			input_handler.is_wall_sliding = false
			input_handler.can_double_jump = true
			input_handler.can_air_dash = true
			_play_jump_stretch()
			AudioManager.play_sfx("jump")
		elif input_handler.consume_double_jump():
			# Big Mode KEEPS its double jump now (brief correction F) — it was
			# a pure downgrade before. Slightly heavier arc while big to sell
			# the mass without removing the ability.
			var dj := double_jump_force * jump_mult
			if GameManager.has_power_up("big"):
				dj *= 0.9
			velocity.y = dj * jump_mult * level_jump_scale
			input_handler.can_air_dash = true
			_play_jump_stretch()
			AudioManager.play_sfx("double_jump")
		else:
			input_handler.buffer_jump()

	# Big Mode ground pound (brief correction F): the real upgrade. Press Down
	# in the air while big → slam down, break breakable/secret walls below and
	# stun nearby enemies on impact. This is the advantage that makes the
	# larger hitbox worth it.
	if GameManager.has_power_up("big") and not is_on_floor() \
			and Input.is_action_just_pressed("move_down") and not _ground_pounding:
		_start_ground_pound()

	# Air dash (Tier 2 Skill 1) — horizontal dash in mid-air
	if Input.is_action_just_pressed("dash"):
		_try_air_dash()

	# Ground pound overrides fall velocity while active and resolves on landing.
	if _ground_pounding:
		velocity.y = ground_pound_speed
		if is_on_floor():
			_resolve_ground_pound()

	_update_sprite_color()
	_update_tool_visual()
	sprite.facing_right = input_handler.facing_right
	sprite.moving = is_on_floor() and absf(velocity.x) > 10.0
	sprite.play_animation(_pick_animation())
	move_and_slide()
	# Torch heat shares the diamond damage aura — both burn enemies on contact.
	aura.monitoring = GameManager.has_power_up("diamond") or GameManager.has_power_up("torch")
	_check_pickaxe_breaks()
	GameManager.player_position = global_position

## Bong flight physics: hold jump/up to ascend, otherwise a slow chill sink.
## Horizontal control stays normal so you can steer to hard-to-reach places.
func _update_fly(delta: float, direction: float) -> void:
	var rising := Input.is_action_pressed("jump") or input_handler.jump_buffer_timer > 0.0
	if MobileInputHandler and MobileInputHandler.get_movement_input() == 0.0:
		pass  # movement handled below; jump comes through the buffer/signal
	if rising:
		velocity.y = -fly_rise_speed
	else:
		velocity.y = fly_sink_speed
	# Horizontal: same accel model as normal air control.
	if direction != 0:
		input_handler.handle_facing_direction(direction)
		var target := direction * walk_speed * power_up_handler.speed_multiplier * level_speed_scale
		velocity.x = move_toward(velocity.x, target, air_accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, air_decel * delta)
	# Puff a smoke trail every few frames for the lifted look.
	if Engine.get_physics_frames() % 8 == 0:
		emit_blaze_smoke()
	sprite.facing_right = input_handler.facing_right
	sprite.moving = absf(velocity.x) > 10.0
	move_and_slide()
	GameManager.player_position = global_position

## With the pickaxe out, walking into a breakable block smashes it.
func _check_pickaxe_breaks() -> void:
	if not GameManager.has_power_up("pickaxe"):
		return
	for i in range(get_slide_collision_count()):
		var collider := get_slide_collision(i).get_collider()
		if collider and collider.is_in_group("breakable") and collider.has_method("break_block"):
			collider.break_block()

# ---- Big Mode ground pound (brief correction F) ---------------------------
var _ground_pounding: bool = false
@export var ground_pound_speed: float = 900.0

## Slam straight down fast; on landing, break breakables below and stun nearby
## enemies. Cancels horizontal control for the slam so it reads as committed.
func _start_ground_pound() -> void:
	_ground_pounding = true
	velocity.y = ground_pound_speed
	velocity.x = 0.0
	_play_land_squash()
	AudioManager.play_sfx("jump")

## Called on landing: shatter breakable blocks touching us, stun enemies in a
## radius, shake the screen. Big Mode's payoff.
func _resolve_ground_pound() -> void:
	_ground_pounding = false
	ScreenShake.shake(0.3, 7.0)
	AudioManager.play_sfx("damage")
	# Break any breakable/secret wall we're standing on or beside.
	for i in range(get_slide_collision_count()):
		var collider := get_slide_collision(i).get_collider()
		if collider and collider.is_in_group("breakable") and collider.has_method("break_block"):
			collider.break_block()
	# Stun (damage) enemies within a short radius of the impact. Bosses keep
	# their own VULNERABLE-window contract (same reason _try_stomp excludes
	# them) -- a free AoE pound would otherwise bypass it.
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy is Node2D and is_instance_valid(enemy) \
				and not enemy.is_in_group("boss") \
				and global_position.distance_to(enemy.global_position) < 120.0 \
				and enemy.has_method("take_damage"):
			enemy.take_damage(1)

## Show the held tool sprite while a tool power-up is active.
func _update_tool_visual() -> void:
	# BIG AXE FIRST — and it must come before "pickaxe", because both use the
	# same pickaxe artwork and whichever branch is tested first wins.
	#
	# Founder F3: "the 1st bigger axe still throws the smaller axes even though
	# he has the bigger one in his hand. When he collects the 2nd axe WE DON'T
	# SEE IT but he ends up throwing bigger axes."
	#
	# There was no "bigaxe" branch at all, so holding the big axe fell through
	# to the else and CLEARED the held sprite — he could never see which axe he
	# had. The scale comes from the projectile's own BIG_SCALE constant, so the
	# weapon in his hand and the weapon that leaves it can never disagree.
	if GameManager.has_power_up("bigaxe"):
		# Held art and thrown art both come from axe.gd, so the weapon in his
		# hand and the weapon that leaves it can never disagree.
		#
		# This ALSO fixes a silent bug: set_tool() early-returns when the path
		# is unchanged, so while both branches passed the SAME pickaxe path,
		# upgrading pickaxe -> big axe kept the old scale and he saw no change
		# at all. That is the founder's "WE DON'T SEE IT but he ends up
		# throwing bigger axes", still half-live after the previous fix.
		var axe_script: GDScript = load("res://src/combat/axe.gd")
		var consts: Dictionary = axe_script.get_script_constant_map()
		sprite.set_tool(str(consts["BIG_ART"]), float(consts["BIG_SCALE"]))
	elif GameManager.has_power_up("pickaxe"):
		sprite.set_tool("res://src/assets/sprites/sprite_item_pickaxe.png")
	elif GameManager.has_power_up("torch"):
		sprite.set_tool("res://src/assets/sprites/sprite_item_torch.png")
	else:
		sprite.set_tool("")

func _update_sprite_color() -> void:
	# Tints over the real sprite art; WHITE = untinted.
	if GameManager.has_power_up("diamond"):
		sprite.color = Color(0.55, 1.0, 1.0, 0.95)
	elif GameManager.has_power_up("purple"):
		sprite.color = Color(0.85, 0.6, 1.0, 0.95)
	elif GameManager.has_power_up("blaze"):
		sprite.color = Color(0.7, 1.0, 0.6, 0.95)
	elif GameManager.has_power_up("big"):
		sprite.color = Color(1.0, 0.7, 0.7, 0.95)
	elif GameManager.has_power_up("torch"):
		sprite.color = Color(1.0, 0.85, 0.65, 1.0)
	elif GameManager.has_power_up("fly"):
		sprite.color = Color(0.6, 1.0, 0.75, 0.95)
	else:
		sprite.color = Color.WHITE

## Movement-state → animation name; one-shots (attack/hurt/death) are played
## directly at their trigger sites and hold via LilBluntVisual.
func _pick_animation() -> String:
	if not is_on_floor():
		return "jump_up" if velocity.y < 0.0 else "jump_down"
	return "run" if absf(velocity.x) > 10.0 else "idle"

## Stretch on launch, snap back — skipped in big mode to avoid fighting PowerUpHandler.
func _play_jump_stretch() -> void:
	if GameManager.has_power_up("big"):
		return
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(0.7, 1.4), 0.06)
	tween.tween_property(self, "scale", Vector2.ONE, 0.14)

## Squash on land.
func _play_land_squash() -> void:
	if GameManager.has_power_up("big"):
		return
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.4, 0.7), 0.05)
	tween.tween_property(self, "scale", Vector2.ONE, 0.12)

func emit_blaze_smoke() -> void:
	var puff := preload("res://src/effects/smoke_puff.tscn").instantiate()
	puff.global_position = smoke_spawn.global_position
	var base_dir := Vector2.RIGHT if input_handler.facing_right else Vector2.LEFT
	puff.direction = base_dir + Vector2(velocity.x * 0.3 / walk_speed, 0.0)
	get_tree().current_scene.add_child(puff)

## The eccentric weed-leaf celebration the founder asked for: Lil Blunt does a
## full spin with a squash-and-stretch pop, throws out a ring of smoke puffs,
## and a hype word pops over his head. Deliberately loud VISUALLY so the pickup
## feels special WITHOUT changing the music (see GameManager._celebrate_blaze).
func _on_blaze_celebration() -> void:
	if not is_instance_valid(sprite):
		return
	# Ring of smoke — 8 puffs thrown outward, not the usual single trail puff.
	for i in range(8):
		var puff := preload("res://src/effects/smoke_puff.tscn").instantiate()
		puff.global_position = smoke_spawn.global_position
		var ang := TAU * float(i) / 8.0
		puff.direction = Vector2(cos(ang), sin(ang))
		get_tree().current_scene.add_child(puff)

	# 360 spin + squash/stretch pop, then settle back exactly where it started
	# (base_scale captured live so a Mushroom-grown Lil Blunt doesn't shrink).
	var base_scale: Vector2 = sprite.scale
	var tw := create_tween()
	tw.tween_property(sprite, "rotation", sprite.rotation + TAU, 0.45) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(sprite, "scale", base_scale * 1.35, 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(sprite, "scale", base_scale, 0.18) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.finished.connect(func() -> void:
		if is_instance_valid(sprite):
			sprite.rotation = 0.0
			sprite.scale = base_scale)

	_pop_celebration_word()

## Floating hype word over Lil Blunt's head. Node2D-parented to the scene (not
## the player) so it doesn't inherit the spin we just started.
func _pop_celebration_word() -> void:
	var words := ["BLAAAZE!", "SO CHILL", "LEVITATIN'", "PUFF PUFF!", "VIBES!"]
	var label := Label.new()
	label.text = words[randi() % words.size()]
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.45))
	label.add_theme_constant_override("outline_size", 7)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.z_index = 100
	label.global_position = global_position + Vector2(-60, -90)
	get_tree().current_scene.add_child(label)
	var t := create_tween()
	t.tween_property(label, "global_position:y", label.global_position.y - 60, 0.9) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(label, "modulate:a", 0.0, 0.9)
	t.finished.connect(label.queue_free)

func take_damage(amount: int) -> void:
	# Damage only exists while PLAYING. This also protects the boss-victory
	# window (LEVEL_COMPLETE): dying there used to wedge the StateMachine
	# into an unrecoverable state and boot the player to the main menu.
	if not StateMachine.is_playing() or power_up_handler.invincible_timer > 0:
		return
	GameManager.take_damage(amount)
	ComboSystem.break_combo()
	ScreenShake.shake(0.2, 5.0)
	if GameManager.player_health <= 0:
		# Bark here (not in die()) so it fires exactly once on the killing blow.
		AudioManager.play_bark("vo_death", 5.0)
		die()
	else:
		_hitstop()
		sprite.play_animation("hurt")
		velocity.y = -260.0
		velocity.x = -240.0 if input_handler.facing_right else 240.0
		power_up_handler.activate_invincibility(1.0)
		AudioManager.play_sfx("damage")
		# Lil Blunt's own voice. Safe in this branch only: the fatal case took
		# the die() path above, so vo_hurt can never double up with vo_death.
		AudioManager.play_bark("vo_hurt", 4.0)

## Freeze-frame on impact — ~4 frames at 5% speed reads as a hit, not lag.
## Timer ignores time_scale so the freeze always ends on schedule.
## Token-guarded restore (Kimi audit): overlapping hitstops used to race — the
## first timer's restore could stomp a later legitimate time_scale change.
## Only the MOST RECENT hitstop is allowed to restore.
var _hitstop_token: int = 0
func _hitstop(duration: float = 0.07) -> void:
	_hitstop_token += 1
	var my_token := _hitstop_token
	Engine.time_scale = 0.05
	# Restore off the TIMER's own timeout signal, not this coroutine's resume.
	# Founder, 2026-08-23 freeze: if this node is freed during the hitstop (Stage
	# 3 boss contact reloads the level within the 0.06s window), the coroutine is
	# abandoned and the line after `await` never runs, stranding the GLOBAL
	# Engine.time_scale at 0.05. The SceneTreeTimer is owned by the tree, not by
	# this node, so binding the restore to its timeout fires even after this node
	# is gone. (SceneRouter.load_scene also resets time_scale as the real safety
	# net; this stops the strand happening in the first place.)
	var t := get_tree().create_timer(duration, true, false, true)
	t.timeout.connect(func() -> void:
		if my_token == _hitstop_token:
			Engine.time_scale = 1.0)

## Ladder zone refcount — called by ladder.gd on Area2D enter/exit. Tracks the
## active ladder node so top-out has geometry to target (brief correction E).
func enter_ladder_zone(ladder: Node2D = null) -> void:
	_ladder_zones += 1
	if ladder != null:
		_active_ladder = ladder

func exit_ladder_zone(ladder: Node2D = null) -> void:
	_ladder_zones = maxi(0, _ladder_zones - 1)
	if _ladder_zones == 0:
		_climbing = false
		_active_ladder = null

## CLIMB state: vertical movement on the ladder, no gravity. Jump = hop off
## with a full jump; touching the floor while pushing down also exits.
## TOP-OUT (brief correction E): climbing up past the ladder top with up held
## moves the player to the ladder's data-driven top-exit standing position,
## nudged out of any collider — never a raw teleport, never stuck under the
## platform.
func _update_climb(delta: float, movement_direction: float) -> void:
	var vertical := Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	# Top-out: at/above the ladder top and still pushing up → stand on top.
	if vertical < 0.0 and _active_ladder != null and is_instance_valid(_active_ladder) \
			and _active_ladder.has_method("top_y") \
			and global_position.y <= _active_ladder.top_y() + LADDER_TOP_OUT_MARGIN:
		_top_out_ladder()
		return
	velocity.y = vertical * climb_speed
	velocity.x = movement_direction * climb_speed * 0.6
	if input_handler.is_jump_pressed():
		_climbing = false
		velocity.y = jump_force * power_up_handler.jump_multiplier
		_play_jump_stretch()
		AudioManager.play_sfx("jump")
		move_and_slide()
		return
	move_and_slide()
	if is_on_floor() and vertical > 0.0:
		_climbing = false

## Place the player at the ladder's top-exit position, then push out of any
## overlap so they land on the surface with clearance instead of inside it.
func _top_out_ladder() -> void:
	_climbing = false
	velocity = Vector2.ZERO
	var target: Vector2 = _active_ladder.top_exit_position()
	# Force-exit the zone bookkeeping HERE, after reading top_exit_position()
	# but before anything else, rather than waiting for the ladder's Area2D
	# body_exited signal. The exit point sits only ~20px above the ladder's
	# own top, and the player's collision box (28x28) still overlaps the
	# zone's y-range at that distance — so if the player keeps holding UP after
	# mounting, the very next physics frame reads `_ladder_zones > 0 and
	# move_up pressed` as still true and re-enters climb state, which
	# immediately re-triggers this same top-out, forever: visibly a stuck
	# flicker at the top rung instead of standing on the platform.
	# exit_ladder_zone() still fires later when the shapes genuinely separate;
	# clamping with maxi(0, ...) there makes this early clear harmless.
	_ladder_zones = 0
	_active_ladder = null
	global_position = Vector2(target.x, target.y)
	# Never leave the player inside geometry: if the exit point overlaps a
	# collider, nudge upward a few steps until free. Bounded — a fully blocked
	# exit just leaves them at the target rather than tunneling (per the brief:
	# "define behaviour for blocked top exits").
	var attempts := 0
	while move_and_collide(Vector2.ZERO, true) != null and attempts < 8:
		global_position.y -= 4.0
		attempts += 1
	AudioManager.play_sfx("jump")
	_play_jump_stretch()

## Falling into a pit — a HARD fail. Plays a devastating sound, costs a LIFE
## (not just health), and respawns at the last checkpoint if lives remain;
## out of lives ends the run to the main menu. Called by the level kill zone.
func pit_death() -> void:
	if StateMachine.is_dead() or _dying:
		return
	_dying = true
	AudioManager.play_sfx("fall")
	# "fall" is environmental; the bark is Lil Blunt's own reaction, so they
	# complement rather than duplicate. The 5s per-id cooldown covers the
	# pit-death-then-real-die() sequence when this was the last life.
	AudioManager.play_bark("vo_death", 5.0)
	ScreenShake.shake(0.5, 10.0)
	# Heatmap: pits are obstacle deaths; surviving ones count as a retry.
	Web3Bridge.report_metric("death", {"obstacle": "pit"})
	# Unified with the enemy/boss death path (R2): one respawn/game-over helper
	# so pit and combat deaths can never diverge again.
	_respawn_or_game_over()

func die() -> void:
	# Re-entry guard (multiple lethal hits in one frame) — NOT an is_dead()
	# guard. The old code bailed on `if StateMachine.is_dead(): return`, but
	# GameManager.take_damage() had already flipped the state to GAME_OVER, so
	# die() returned immediately and the death/respawn sequence NEVER ran — the
	# player just froze in GAME_OVER with no control and no respawn. State
	# ownership now lives here (GameManager no longer steals it).
	if _dying:
		return
	_dying = true
	# Take the death state ourselves. From LEVEL_COMPLETE (boss just won) this
	# is refused, which is correct: abort the death rather than wedge the SM.
	if not StateMachine.is_dead():
		if not StateMachine.change_state(StateMachine.State.GAME_OVER):
			_dying = false
			return
	# AgentMail digest hook: attribute the death to the active boss (if any)
	# so the weekly email can say "you died to the Tax Collector N times".
	if BossVoiceSystem._active_boss_id != "":
		Web3Bridge.report_event("death", {"boss": BossVoiceSystem._active_boss_id})
	# Granular heatmap (task #23): enemy attribution feeds dynamic difficulty.
	var src := BossVoiceSystem._active_boss_id
	if src == "":
		src = GameManager.last_damage_source
	if src != "":
		Web3Bridge.report_metric("death", {"enemy": src})
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.5)
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.finished.connect(_on_death_anim_done)

func _on_death_anim_done() -> void:
	died.emit()
	# R2 (2026-08-08): this used get_checkpoint(1) — HARDCODED level 1 — then
	# fell through to reload_current_scene() when it found nothing. On Level 2/3
	# there is no level-1 checkpoint, so every enemy/boss death hit the reload
	# branch. reload_current_scene() is deferred and does NOT restore PLAYING by
	# itself; combined with the tween/await timing this presented as the "death
	# freezes instead of restarting" the founder reported. It also never spent a
	# life (infinite free retries) — diverging from pit_death()'s correct flow.
	# Now unified through _respawn_or_game_over(), which spends a life, respawns
	# at the CURRENT level's checkpoint, and guarantees a return to PLAYING.
	_respawn_or_game_over()

## Single source of truth for "the player just died": spend a life; if any
## remain, respawn at the current level's checkpoint and hand control back
## (PLAYING); if not, run the game-over fade to the main menu. Both the
## enemy/boss death path (die → death anim → here) and the pit path call this,
## so respawn behaviour can never diverge between them again.
func _respawn_or_game_over() -> void:
	if GameManager.lose_life():
		# Out of lives — real game over, fade to menu. GAME_OVER is already the
		# current state on the die() path; assert it on the pit path too.
		if not StateMachine.is_dead():
			StateMachine.change_state(StateMachine.State.GAME_OVER)
		# FULL LIFE WIPE (lives == 0): restart at the START of the CURRENT level,
		# not the mid-level checkpoint and not the main menu. Founder rule:
		#   lives remaining > 0 after a hit -> checkpoint respawn (below)
		#   lives == 0 / full wipe -> reload THIS level from its start marker
		# Clearing the checkpoint makes the reloaded level's _spawn_player fall
		# back to player_spawn (level start) instead of the boss-door checkpoint
		# where the last life was lost. Lives + health refill for the retry.
		var wipe_level := GameManager.current_level
		GameManager.clear_checkpoint(wipe_level)
		GameManager.refill_run()
		var t := create_tween()
		t.tween_property(self, "modulate:a", 0.0, 0.5)
		await get_tree().create_timer(1.2).timeout
		SceneRouter.load_scene(GameManager.level_scene(wipe_level), SceneRouter.Transition.FADE)
		return
	# Lives remain — respawn at THIS level's checkpoint, else near where the
	# player died. Founder (session 4): dying in Stage 3 "he appears somewhere
	# else!!! He must reappear exactly or close to where he died." The bug was
	# the cross-level fallback below (get_checkpoint(1)) firing when the current
	# level had no checkpoint yet — it dropped the player at a LEVEL-1 coordinate
	# inside the Level-3 scene. Removed. Now: this level's checkpoint if any,
	# else the last safe grounded spot (the sample before the lip, so a pit
	# death lands on solid ground near the death, not on the crumbling edge),
	# else the level's own start marker as a final safety.
	Web3Bridge.report_metric("retry", {})
	var checkpoint := GameManager.get_checkpoint(GameManager.current_level)
	if checkpoint != Vector2.ZERO:
		global_position = checkpoint + Vector2(0, -50)
	elif _prev_safe_position != Vector2.ZERO:
		global_position = _prev_safe_position + Vector2(0, -10)
	elif _last_safe_position != Vector2.ZERO:
		global_position = _last_safe_position + Vector2(0, -10)
	else:
		global_position = GameManager.player_position + Vector2(0, -260)
	GameManager.player_health = GameManager.max_health
	GameManager.health_changed.emit(GameManager.player_health)
	scale = Vector2.ONE
	modulate.a = 1.0
	velocity = Vector2.ZERO
	power_up_handler.activate_invincibility(1.5)
	# Return control. GAME_OVER→PLAYING is an allowed transition; this is what
	# was missing on the old reload path and caused the freeze. Guard the
	# from==to case (pit path may still be PLAYING) to avoid a warning.
	if not StateMachine.is_playing():
		StateMachine.change_state(StateMachine.State.PLAYING)
	_dying = false

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("collectible") and area.has_method("collect"):
		area.collect()
	elif area.is_in_group("powerup") and area.has_method("collect"):
		area.collect()

func _on_hurtbox_body_entered(body: Node2D) -> void:
	# Pickaxe shatters boulders instead of them hurting us.
	if GameManager.has_power_up("pickaxe") and body.has_method("smash"):
		body.smash()
		return
	if body.is_in_group("enemy"):
		# Stomp (defect #10): landing on a head is an attack, not a hit —
		# damage THEM, bounce US. Must run and `return` BEFORE deal_damage,
		# or the same contact would also hurt the player on the exact hit
		# that killed the thing standing on.
		if _try_stomp(body):
			return
		if body.has_method("deal_damage"):
			body.deal_damage(self)
	elif body.is_in_group("hazard"):
		take_damage(1)

## True (and fully handled) if this enemy contact is a head-stomp: player
## falling, player's origin clearly above the enemy's. Side/below contact
## returns false and stays a normal player-takes-damage hit. Bosses are
## excluded — they keep their own VULNERABLE-window damage contract, which a
## free stomp would bypass. velocity.y OR _last_fall_speed: move_and_slide
## can zero velocity.y on the exact physics frame this Area2D signal fires,
## but _last_fall_speed still holds the pre-landing value (player.gd only
## resets it once is_on_floor() is true).
func _try_stomp(body: Node2D) -> bool:
	if _climbing:
		return false  # ladder contact uses the enemy's normal deal_damage path
	if body.is_in_group("boss"):
		return false
	if not body.has_method("take_damage"):
		return false
	if body.get("is_dead") == true:
		return false  # don't re-stomp a corpse mid-death-tween
	var falling: bool = velocity.y > stomp_min_fall_speed \
			or _last_fall_speed > stomp_min_fall_speed
	if not falling:
		return false
	if global_position.y >= body.global_position.y - STOMP_Y_MARGIN:
		return false
	body.take_damage(1)
	_ground_pounding = false  # a pound resolves as a stomp, doesn't fight the bounce
	velocity.y = stomp_bounce_force
	input_handler.can_double_jump = true
	input_handler.can_air_dash = true
	_play_jump_stretch()
	AudioManager.play_sfx("jump")
	ComboSystem.add_score(20)
	return true

func _on_aura_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy") and body.has_method("take_damage"):
		body.take_damage(1)

## Switch player visual outfit by level theme.
func set_outfit(outfit: Outfit) -> void:
	current_outfit = outfit
	sprite.set_outfit(outfit)

func _on_mobile_jump() -> void:
	input_handler.buffer_jump()

func _on_mobile_dash() -> void:
	_try_air_dash()

## Shared keyboard/mobile air dash: flat horizontal burst — zeroing vertical
## speed is what makes it read as a punch instead of a nudge mid-fall.
func _try_air_dash() -> void:
	if not input_handler.is_air_dash_available():
		return
	var dash_dir := input_handler.get_movement_direction()
	if dash_dir == 0:
		dash_dir = 1.0 if input_handler.facing_right else -1.0
	velocity.x = dash_dir * InputHandler.AIR_DASH_SPEED
	velocity.y = 0.0
	input_handler.consume_air_dash()
	EffectSpawner.burst("dash_trail", global_position)
	AudioManager.play_sfx("dash")
