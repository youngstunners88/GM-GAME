extends CharacterBody2D
## Shooter-mode Lil Blunt (v1.2 prototype).
##
## WHY THIS IS NOT "the platformer with a gun" (GDD pillar 1):
##  - Aim is DECOUPLED from movement: the arm/muzzle tracks the mouse, so you
##    strafe one way while firing the other. That single change is most of the
##    genre difference.
##  - Firing has weight: fire-rate cooldown, muzzle flash, recoil impulse,
##    screen shake — you commit to a shot instead of spamming.
##  - COVER is the verb: DOWN inside a crate's zone ducks you; while ducked the
##    crate eats the bolts and the drone loses line of sight. Peek-fire (ATTACK)
##    stands you up for a beat, then re-ducks.
##
## Deliberately standalone (composes only autoloads + LilBluntVisual) so the
## v1.0 platformer player is untouched — roadmap anti-pattern rule.

@export var move_speed: float = 250.0
@export var accel: float = 2200.0
@export var decel: float = 2600.0
@export var jump_force: float = -430.0
@export var gravity: float = 1000.0

signal ammo_changed(current: int, maximum: int)
signal health_changed(current: int)

var health: int = 5
var aim_dir: Vector2 = Vector2.RIGHT
var is_ducking: bool = false

## The equipped weapon owns fire rate, ammo, recoil and what leaves the muzzle
## (see weapon_base.gd). Swapping tiers later is a node swap, not a player edit.
var weapon: WeaponBase

var _cover: Node2D = null       # cover we're standing in the zone of
var _peek_timer: float = 0.0
var _invuln: float = 0.0

## Ammo now lives on the weapon. Kept as read-only passthroughs so the room
## HUD and leaf pickups don't need to know about the weapon node.
var ammo: int:
	get: return weapon.ammo if weapon != null else 0
var max_ammo: int:
	get: return weapon.max_ammo if weapon != null else 0

@onready var visual: LilBluntVisual = $Visual
@onready var arm: Node2D = $Arm
@onready var muzzle: Marker2D = $Arm/Muzzle
@onready var flash: ColorRect = $Arm/Flash
## Crosshair. A mouse-aimed shooter without a reticle isn't readable — you
## can't tell where the shot goes until after you've taken it.
@onready var reticle: Node2D = $Reticle

func _ready() -> void:
	add_to_group("shooter_player")
	add_to_group("player")          # so existing hazards/pickups still see us
	collision_layer = 2
	collision_mask = 1              # world + cover
	flash.visible = false
	_equip(WeaponBongBlaster.new())
	health_changed.emit(health)

## Attach a weapon and re-broadcast its ammo as our own, so listeners keep a
## single subscription across weapon swaps.
func _equip(new_weapon: WeaponBase) -> void:
	if weapon != null:
		weapon.queue_free()
	weapon = new_weapon
	add_child(weapon)
	weapon.ammo_changed.connect(func(current: int, maximum: int) -> void:
		ammo_changed.emit(current, maximum))
	ammo_changed.emit(weapon.ammo, weapon.max_ammo)

func _physics_process(delta: float) -> void:
	if not StateMachine.is_playing():
		return
	_invuln -= delta
	if _peek_timer > 0.0:
		_peek_timer -= delta
		if _peek_timer <= 0.0 and _cover != null:
			is_ducking = true          # auto re-duck after the peek

	_update_aim()
	_update_duck()
	_update_movement(delta)

	if Input.is_action_pressed("attack") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_try_fire()

	move_and_slide()
	_update_visual()

## Aim tracks the mouse — independent of which way you're moving.
func _update_aim() -> void:
	var target := get_global_mouse_position()
	var from := global_position
	if from.distance_to(target) > 4.0:
		aim_dir = from.direction_to(target)
	arm.rotation = aim_dir.angle()
	reticle.global_position = target
	# Reticle goes hot when the weapon is actually ready to fire — a free,
	# glanceable read on the fire-rate cooldown and on being out of ammo.
	var ready_to_fire := weapon != null and weapon.can_fire()
	reticle.modulate = Color(1.0, 1.0, 1.0, 1.0) if ready_to_fire \
		else Color(1.0, 0.5, 0.5, 0.45)
	reticle.scale = Vector2.ONE if ready_to_fire else Vector2(0.75, 0.75)

## DOWN inside a cover zone ducks. While ducked you can't move (committed),
## the crate takes hits for you, and drones lose LOS.
func _update_duck() -> void:
	if _cover == null or not is_instance_valid(_cover):
		is_ducking = false
		return
	if Input.is_action_pressed("move_down") and _peek_timer <= 0.0:
		is_ducking = true
	elif not Input.is_action_pressed("move_down") and _peek_timer <= 0.0:
		is_ducking = false

func _update_movement(delta: float) -> void:
	if not is_on_floor():
		velocity.y = minf(velocity.y + gravity * delta, 900.0)
	# Ducking commits you: no strafing behind cover.
	var dir := 0.0 if is_ducking else Input.get_axis("move_left", "move_right")
	if dir != 0.0:
		velocity.x = move_toward(velocity.x, dir * move_speed, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, decel * delta)
	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_ducking:
		velocity.y = jump_force
		AudioManager.play_sfx("jump")

func _try_fire() -> void:
	if weapon == null or not weapon.can_fire():
		# Still route a dry trigger through the weapon so it can play its own
		# empty-magazine feedback and apply its own anti-spam cooldown.
		if weapon != null:
			weapon.fire(muzzle.global_position, aim_dir, is_on_floor())
		return

	# Peek-fire: shooting from cover stands you up briefly, then re-ducks.
	if is_ducking:
		is_ducking = false
		_peek_timer = 0.4

	var kick := weapon.fire(muzzle.global_position, aim_dir, is_on_floor())
	if kick == Vector2.ZERO:
		return

	# WEIGHT: the weapon owns recoil/shake/audio; the player owns the muzzle
	# flash, because the flash is part of the ARM's visuals, not the gun's rules.
	velocity += kick
	flash.visible = true
	get_tree().create_timer(0.05).timeout.connect(func() -> void:
		if is_instance_valid(flash):
			flash.visible = false)

func _update_visual() -> void:
	# Face the AIM, not the movement — shooter convention.
	visual.facing_right = aim_dir.x >= 0.0
	visual.moving = is_on_floor() and absf(velocity.x) > 10.0 and not is_ducking
	visual.play_animation("hurt" if _invuln > 0.0 else ("idle" if is_ducking else ""))
	# Ducking squashes you behind the crate.
	var want_scale := Vector2(1.0, 0.6) if is_ducking else Vector2.ONE
	visual.scale = visual.scale.lerp(want_scale, 0.35)
	arm.visible = not is_ducking or _peek_timer > 0.0

# ---- cover zone callbacks (from cover_system.gd) --------------------------
func enter_cover_zone(cover: Node2D) -> void:
	_cover = cover

func exit_cover_zone(cover: Node2D) -> void:
	if _cover == cover:
		_cover = null
		is_ducking = false

# ---- damage --------------------------------------------------------------
func take_damage(amount: int) -> void:
	if _invuln > 0.0:
		return
	health -= amount
	health_changed.emit(health)
	_invuln = 0.9
	AudioManager.play_sfx("damage")
	ScreenShake.shake(0.25, 7.0)
	ComboSystem.break_combo()
	if health <= 0:
		_die()

func _die() -> void:
	# Prototype: respawn in place with a fresh clip rather than a full game
	# over — keeps the feel-test loop tight. Real levels use checkpoints.
	health = 5
	if weapon != null:
		weapon.refill()
	health_changed.emit(health)
	_invuln = 1.5
	AudioManager.play_sfx("fall")

## Pickups call this (leaf = ammo, per GDD cross-mode economy).
func add_ammo(amount: int) -> void:
	if weapon == null:
		return
	weapon.add_ammo(amount)
	AudioManager.play_sfx("powerup")
