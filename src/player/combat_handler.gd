class_name CombatHandler
extends Node
## Lil Blunt's attacks. Base move: throw an axe in the facing direction. The
## Purple Weed power-up is where the attack fantasy opens up — a tap throws a
## three-axe fan, and holding the button lights the ETH flask for a fire-breath
## channel. Keyboard ("attack" action) and the mobile attack button both route
## through here.
##
## Design/numbers live in docs/architecture/adr-combat-system.md.

const AXE_SCENE := preload("res://src/combat/axe.tscn")
const FIRE_BREATH_SCENE := preload("res://src/combat/fire_breath.tscn")
const FLAME_SCENE := preload("res://src/combat/flame_projectile.tscn")

## Cooldowns (seconds). Fan is a touch slower than a single throw so the
## purple burst doesn't become a strictly-better spam; fire breath is the
## heavy hitter and gates hardest. Torch shares the axe's cooldown slot (see
## _axe_cd) rather than adding a second timer — torch and purple are never
## both active (single-slot power-up), so there's no case where both moves
## need independent cooldowns at once.
const AXE_COOLDOWN := 0.4
const FAN_COOLDOWN := 0.5
const FIRE_COOLDOWN := 1.4
const TORCH_COOLDOWN := 0.5
## Fan spread as a vertical velocity fraction of axe speed (outer axes drift).
const FAN_SPREAD := 0.28
## How long the button must be held (purple only) before the flask ignites.
const HOLD_THRESHOLD := 0.28

var _axe_cd := 0.0
var _fire_cd := 0.0
var _held := 0.0
var _mobile_press := false      ## one-shot: set by touch, consumed next frame
var _mobile_down := false       ## true between mobile press and release
var player: Player

func _ready() -> void:
	player = get_parent()
	if MobileInputHandler and MobileInputHandler.has_signal("touch_attack"):
		MobileInputHandler.touch_attack.connect(_on_mobile_attack_pressed)
		MobileInputHandler.touch_attack_released.connect(_on_mobile_attack_released)

func _physics_process(delta: float) -> void:
	if _axe_cd > 0.0:
		_axe_cd -= delta
	if _fire_cd > 0.0:
		_fire_cd -= delta
	if not StateMachine.is_playing():
		_mobile_press = false
		return

	var pressed := Input.is_action_just_pressed("attack") or _mobile_press
	var holding := Input.is_action_pressed("attack") or _mobile_down
	_mobile_press = false
	var purple := GameManager.has_power_up("purple")
	var torch := GameManager.has_power_up("torch")

	if pressed:
		_held = 0.0
		if torch:
			_throw_flame()
		elif purple:
			_throw_fan()
		else:
			_throw_axe()

	# Purple + sustained hold → ETH-flask fire breath, on its own cooldown.
	if holding and purple:
		_held += delta
		if _held >= HOLD_THRESHOLD and _fire_cd <= 0.0:
			_breathe_fire()
	else:
		_held = 0.0

func _facing() -> float:
	return 1.0 if player.input_handler.facing_right else -1.0

func _throw_axe() -> void:
	if _axe_cd > 0.0:
		return
	_axe_cd = AXE_COOLDOWN
	_spawn_axe(0.0)
	AudioManager.play_sfx("throw")

## Three axes: one straight, two drifting up/down — the purple power flex.
func _throw_fan() -> void:
	if _axe_cd > 0.0:
		return
	_axe_cd = FAN_COOLDOWN
	_spawn_axe(-FAN_SPREAD)
	_spawn_axe(0.0)
	_spawn_axe(FAN_SPREAD)
	AudioManager.play_sfx("throw")

## Torch's tap attack — a shallow-arc thrown flame, replacing the axe throw
## for the duration of the torch power-up. Shares _axe_cd (see TORCH_COOLDOWN
## comment above) rather than its own timer.
func _throw_flame() -> void:
	if _axe_cd > 0.0:
		return
	_axe_cd = TORCH_COOLDOWN
	var flame := FLAME_SCENE.instantiate()
	flame.direction = _facing()
	flame.global_position = player.smoke_spawn.global_position
	player.get_tree().current_scene.add_child(flame)
	AudioManager.play_sfx("torch_throw")

func _spawn_axe(spread: float) -> void:
	var axe := AXE_SCENE.instantiate()
	axe.direction = _facing()
	axe.vertical = spread * axe.speed
	axe.global_position = player.smoke_spawn.global_position
	player.get_tree().current_scene.add_child(axe)

func _breathe_fire() -> void:
	_fire_cd = FIRE_COOLDOWN
	_held = 0.0
	var fb := FIRE_BREATH_SCENE.instantiate()
	fb.direction = _facing()
	# Local offset in front of the body; direction sign puts it on the correct side.
	fb.position = Vector2(16.0 * _facing(), 8.0)
	player.add_child(fb)
	AudioManager.play_sfx("fire")

func _on_mobile_attack_pressed() -> void:
	_mobile_press = true
	_mobile_down = true

func _on_mobile_attack_released() -> void:
	_mobile_down = false
