class_name CombatHandler
extends Node
## Lil Blunt's attacks. Base move: a thrown projectile in the facing direction —
## WHICH projectile depends on the stage, see `_uses_smoke_bombs()`. The
## Purple Weed power-up is where the attack fantasy opens up — a tap throws a
## three-shot fan of the stage's weapon, and holding the button lights the ETH
## flask for a fire-breath
## channel. Keyboard ("attack" action) and the mobile attack button both route
## through here.
##
## Design/numbers live in docs/architecture/adr-combat-system.md.

const AXE_SCENE := preload("res://src/combat/axe.tscn")
const SMOKE_BOMB_SCENE := preload("res://src/combat/smoke_bomb.tscn")
const REVOLVER_BULLET_SCENE := preload("res://src/combat/revolver_bullet.tscn")
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

## STAGE 1 THROWS SMOKE BOMBS, NOT AXES.
##
## Founder lock (2026-09-14): Lil Blunt only finds the pickaxe/mining gear
## AFTER beating the Stage 1 Tax Collector — the GOV VAULT loot that opens
## Crystal Caverns — so a thrown axe in Stage 1 is a weapon he does not own
## yet. Stage 1's base attack is a smoke bomb; Stage 2 keeps the axe exactly as
## it is, and Stage 3's big axe / hammer are untouched.
##
## Gated on the stage, deliberately NOT a global removal of axes. The axe
## scene, its three weight tiers and every power-up that feeds them are
## untouched — this only chooses which projectile the base throw spawns.
##
## STAGE RESOLUTION READS THE LEVEL, NOT A GLOBAL (founder, 2026-09-22:
## "Lil Blunt is throwing axes in the beginning instead of smoke bombs").
##
## This used to be `GameManager.current_level == 1` alone. That value is a
## mutable global written by level_base, by save-loading (`load_game()` clamps
## it out of the save file) and by level progression, and it is read here at
## THROW time — long after whoever set it last. Any path that leaves it stale
## silently hands Lil Blunt an axe in Stage 1: the exact weapon the founder
## removed on 2026-09-14, reappearing with no code change to blame, which is
## why it kept surviving source review.
##
## The level in front of the player cannot be stale. `current_scene` IS the
## level node here (it is the same node the projectiles get parented to, see
## `_spawn_smoke_bomb`), and its `level_data.level_index` is baked into the
## scene. Ask it first; fall back to the global only when there is no level
## to ask (Blaze Rush, the vault realms, Episode 2 — none of which use this
## base throw anyway).
##
## AND IT FAILS TOWARD THE SMOKE BOMB. If neither source can name a stage, the
## answer is the smoke bomb, not the axe. A wrong smoke bomb in Stage 2 is a
## cosmetic mismatch; a wrong axe in Stage 1 is a weapon the founder has now
## asked to be rid of twice.
func _stage_index() -> int:
	var scene: Node = player.get_tree().current_scene
	if scene != null and "level_data" in scene and scene.level_data != null:
		var idx: int = int(scene.level_data.level_index)
		if idx >= 1:
			return idx
	if GameManager.current_level >= 1:
		return GameManager.current_level
	return 1  # unknown -> Stage 1 -> smoke bomb, never the axe

func _uses_smoke_bombs() -> bool:
	return _stage_index() == 1

## STAGE 3 FIRES THE GOLDEN REVOLVER — UNLESS HE'S HOLDING THE AXE OR HAMMER.
##
## Founder lock (2026-09-16, golden Remington reference art): the revolver is
## picked up in the beat between the Stage 2 boss defeat video and Stage 3
## (see `stage2_revolver_reveal.gd`), so by the time Lil Blunt reaches the
## Gold Rush he is armed with it instead of the axe.
##
## CORRECTED (founder, 2026-09-16, 2nd pass): "when Lil Blunt grabs the axe or
## the hammer he still shoots bullets instead of throwing the axe or hammer."
## The first pass read the founder's earlier "when he grabs the axe and the
## hammer just changes accordingly" as "keep the same tier NUMBERS, just skin
## them as a shot" — wrong. He means the actual WEAPON changes: picking up
## the pickaxe or big axe (the "hammer" — see axe.gd's BIG_ART comment) must
## make Lil Blunt throw THAT weapon, the same as it already does visually in
## his hand (player.gd::_update_tool_visual already shows the pickaxe/bigaxe
## sprite over the revolver whenever one is held — only the THROWN projectile
## was still silently forced to the bullet). So the revolver is Stage 3's
## weapon only when neither tool power-up is currently held; picking either
## one up switches the actual thrown attack back to `_spawn_axe`, which
## already reads the same two power-ups to pick its damage tier and sprite
## (pickaxe vs BIG_ART) — held weapon and thrown weapon can no longer
## disagree, matching the fix already applied to the hand sprite.
func _uses_revolver() -> bool:
	if GameManager.has_power_up("bigaxe") or GameManager.has_power_up("pickaxe"):
		return false
	return _stage_index() == 3

func _throw_axe() -> void:
	if _axe_cd > 0.0:
		return
	_axe_cd = AXE_COOLDOWN
	_spawn_projectile(0.0)
	AudioManager.play_sfx("throw")

## Three projectiles: one straight, two drifting up/down — the purple power
## flex. In Stage 1 that is a three-bomb spread rather than a three-axe fan, so
## the power-up keeps its identity without handing him a weapon he has not
## found yet.
func _throw_fan() -> void:
	if _axe_cd > 0.0:
		return
	_axe_cd = FAN_COOLDOWN
	_spawn_projectile(-FAN_SPREAD)
	_spawn_projectile(0.0)
	_spawn_projectile(FAN_SPREAD)
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

## The base throw. SMOKE BOMB IS THE DEFAULT, EVERYWHERE.
##
## Founder, 2026-09-22/23: "i didnt ever mention the axes and you put them in
## there!!! then when I told you to go back to the smoke bombs you ignored me"
## and "bring back the smoke bombs ... How many times must i tell you the
## fucking same thing". The plain thrown axe was never his request. It was the
## Stage 2 fallthrough of the old router (`else: _spawn_axe`), so every stage
## that was not 1 or 3 silently armed Lil Blunt with a weapon nobody asked for.
##
## Only the weapons the founder DID ask for override the smoke bomb:
##   * holding the axe / hammer pickup (pickaxe, bigaxe) outside Stage 1 ->
##     throw THAT ("when Lil Blunt grabs the axe or the hammer ... throwing the
##     axe or hammer", 2026-09-16);
##   * Stage 3 with no tool -> the golden revolver (2026-09-16 reference art).
## Stage 1 is always the smoke bomb: the pickaxe is its boss REWARD, so a tool
## there would be a weapon he does not own yet.
func _spawn_projectile(spread: float) -> void:
	var stage: int = _stage_index()
	var holding_tool: bool = GameManager.has_power_up("bigaxe") \
		or GameManager.has_power_up("pickaxe")
	if stage != 1 and holding_tool:
		_spawn_axe(spread)
	elif _uses_revolver():
		_spawn_revolver_bullet(spread)
	else:
		_spawn_smoke_bomb(spread)


func _spawn_smoke_bomb(spread: float) -> void:
	var bomb := SMOKE_BOMB_SCENE.instantiate()
	bomb.direction = _facing()
	bomb.vertical = spread * bomb.speed
	# No `big`/`heavy` tiers here on purpose. Those come from the bigaxe and
	# pickaxe power-ups, neither of which exists in Stage 1 — the pickaxe IS
	# the Stage 1 boss reward. If a weapon power-up is ever added to Stage 1,
	# it needs its own smoke-bomb tier rather than silently reviving the axe.
	bomb.global_position = player.smoke_spawn.global_position
	player.get_tree().current_scene.add_child(bomb)


func _spawn_axe(spread: float) -> void:
	var axe := AXE_SCENE.instantiate()
	axe.direction = _facing()
	axe.vertical = spread * axe.speed
	# Big-axe power-up: set BEFORE add_child so axe._ready() sees it (same
	# pre-add_child prop contract EntitySpawner uses for MineCart.cart_type).
	axe.big = GameManager.has_power_up("bigaxe")
	# PICKAXE = the middle weight class (see axe.gd's `heavy` block). Without
	# this the pickaxe threw a byte-identical DEFAULT axe, which is exactly the
	# founder's "the axe is still exactly the same ... it doesnt have a more
	# powerful impact than Lil Blunt's default axes" while his HUD read PICKAXE.
	# Guarded on `big` so upgrading pickaxe -> big axe is never a downgrade.
	axe.heavy = GameManager.has_power_up("pickaxe") and not axe.big
	axe.global_position = player.smoke_spawn.global_position
	player.get_tree().current_scene.add_child(axe)

func _spawn_revolver_bullet(spread: float) -> void:
	var bullet := REVOLVER_BULLET_SCENE.instantiate()
	bullet.direction = _facing()
	bullet.vertical = spread * bullet.speed
	# Same pre-add_child prop contract as _spawn_axe: big wins over heavy,
	# exactly mirroring axe.gd's tier resolution.
	bullet.big = GameManager.has_power_up("bigaxe")
	bullet.heavy = GameManager.has_power_up("pickaxe") and not bullet.big
	bullet.global_position = player.smoke_spawn.global_position
	player.get_tree().current_scene.add_child(bullet)

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
