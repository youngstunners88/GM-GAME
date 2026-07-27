class_name WeaponBase
extends Node2D
## Base contract for every Bong Blaster tier (GDD v1.2 §1.3 / §3.5).
##
## A weapon owns FIRING ONLY: rate, ammo cost, recoil, heat, and what leaves
## the muzzle. It owns nothing about movement, cover, or aiming — the shooter
## player passes an aim direction in and gets a recoil impulse back. That
## boundary is what lets tiers 2–4 drop in later without touching the player.
##
## Per the systems architecture (§7.2), lower layers never import upper ones:
## this file knows about projectiles and autoloads, never about ShooterPlayer.

## Emitted whenever ammo changes so the HUD never has to poll.
signal ammo_changed(current: int, maximum: int)
## Emitted when a shot actually leaves the muzzle (not when fire() is refused).
signal fired(direction: Vector2)
## Emitted when the weapon locks itself out (tier 4 overheat).
signal overheated(cooldown: float)

@export var display_name: String = "Weapon"
@export var fire_cooldown: float = 0.17
@export var ammo_cost: int = 1
@export var damage: int = 10
@export var projectile_speed: float = 900.0
## Backward impulse applied to the shooter, in px/s. Halved in the air so
## recoil never fights platforming carried over from v1.0 (GDD §1.3).
@export var recoil: float = 60.0
@export var shake_duration: float = 0.06
@export var shake_strength: float = 2.2
@export var max_ammo: int = 60

var ammo: int = 60

var _cooldown: float = 0.0

func _ready() -> void:
	ammo = max_ammo
	ammo_changed.emit(ammo, max_ammo)

func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta

## True when the trigger would actually produce a shot right now. The reticle
## reads this to show weapon readiness, so it must stay cheap and side-effect
## free.
func can_fire() -> bool:
	return _cooldown <= 0.0 and ammo >= ammo_cost

## Attempt a shot. Returns the recoil impulse to apply to the shooter
## (Vector2.ZERO when nothing was fired), so the caller never has to ask
## whether the shot happened.
func fire(origin: Vector2, direction: Vector2, grounded: bool) -> Vector2:
	if _cooldown > 0.0:
		return Vector2.ZERO
	if ammo < ammo_cost:
		_on_dry_fire()
		return Vector2.ZERO

	_cooldown = fire_cooldown
	ammo -= ammo_cost
	ammo_changed.emit(ammo, max_ammo)
	_spawn_projectiles(origin, direction)
	fired.emit(direction)
	_feedback()
	return -direction * (recoil if grounded else recoil * 0.5)

## Override per tier. Base tier fires one bolt down the aim vector.
func _spawn_projectiles(_origin: Vector2, _direction: Vector2) -> void:
	pass

## Click with an empty magazine. Deliberately has its own short cooldown so
## holding the trigger dry doesn't spam the error sound.
func _on_dry_fire() -> void:
	_cooldown = 0.4
	AudioManager.play_sfx("error")

func _feedback() -> void:
	ScreenShake.shake(shake_duration, shake_strength)
	AudioManager.play_sfx("throw")

## Leaves collected in the platformer are shooter ammo (GDD pillar 3).
func add_ammo(amount: int) -> void:
	ammo = mini(ammo + amount, max_ammo)
	ammo_changed.emit(ammo, max_ammo)

func refill() -> void:
	ammo = max_ammo
	ammo_changed.emit(ammo, max_ammo)
