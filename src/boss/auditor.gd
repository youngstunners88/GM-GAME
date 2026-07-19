extends CharacterBody2D
## Boss 1 — The Auditor (Tax Collector). Three HP-scaled phases:
##   P1 (100-66%): patrol + lob a single aimed clipboard on a cadence.
##   P2 (66-33%):  faster, throws a 2-shot; charges more often.
##   P3 (33-0%):   enraged — +50% speed, TRIPLE spread clipboard, hops often.
## Damage window is still the post-charge VULNERABLE state (readable tell), but
## the ranged clipboards make him a threat at all times. Voice via BossVoiceSystem.
## Design: docs/architecture/adr-boss-ai-overhaul.md.

enum State { PATROL, CHARGE, VULNERABLE, DEFEATED }
const BOSS_ID := "tax"
const CLIPBOARD := preload("res://src/boss/boss_projectile.tscn")

@export var patrol_speed: float = 90.0
@export var charge_speed: float = 320.0
@export var vulnerable_time: float = 1.8
@export var max_health: int = 6

var current_state: State = State.PATROL
var health: int = 6
var patrol_direction: float = 1.0
var charge_target: Vector2 = Vector2.ZERO
var state_timer: float = 0.0
var throw_timer: float = 2.0
var hop_timer: float = 6.0
var phase: int = 1
var _base_patrol_speed: float = 90.0

@onready var sprite: BossSprite = $ColorRect
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var hitbox: Area2D = $Hitbox
@onready var hitbox_shape: CollisionShape2D = $Hitbox/CollisionShape2D

func _ready() -> void:
	add_to_group("enemy")
	add_to_group("boss")
	health = max_health
	_base_patrol_speed = patrol_speed
	sprite.color = Color(0.4, 0.25, 0.15, 1.0)
	sprite.size = Vector2(96, 96)
	collision.position = Vector2(48, 48)
	hitbox.position = Vector2(48, 48)
	hitbox_shape.shape = collision.shape
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	hitbox.area_entered.connect(_on_hitbox_area_entered)
	BossVoiceSystem.set_active(self, BOSS_ID)
	BossVoiceSystem.say(self, BOSS_ID, "intro", true)

func _physics_process(delta: float) -> void:
	if current_state == State.DEFEATED:
		return
	state_timer -= delta
	throw_timer -= delta
	hop_timer -= delta

	match current_state:
		State.PATROL:
			velocity.x = patrol_speed * patrol_direction
			velocity.y += 980.0 * delta
			move_and_slide()
			if is_on_wall():
				patrol_direction *= -1.0
				sprite.scale.x = 1.0 if patrol_direction > 0 else -1.0
			# Ranged pressure — cadence tightens per phase.
			if throw_timer <= 0.0:
				throw_timer = [0.0, 2.6, 2.0, 1.4][phase]
				_throw_clipboard()
			# Occasional reposition hop.
			if hop_timer <= 0.0:
				hop_timer = 6.0 if phase < 3 else 3.5
				velocity.y = -320.0
				velocity.x = -patrol_direction * 160.0
			if state_timer <= 0.0:
				state_timer = 1.4
				current_state = State.CHARGE
				var p := get_tree().get_first_node_in_group("player")
				if p:
					charge_target = p.global_position

		State.CHARGE:
			var dir := global_position.direction_to(charge_target)
			velocity.x = dir.x * charge_speed
			velocity.y += 980.0 * delta
			move_and_slide()
			if state_timer <= 0.0 or is_on_wall():
				state_timer = vulnerable_time
				current_state = State.VULNERABLE
				sprite.color = Color(1.0, 0.2, 0.2, 1.0)
				hitbox.monitorable = true
				hitbox.monitoring = true

		State.VULNERABLE:
			velocity.x = move_toward(velocity.x, 0.0, 200.0)
			velocity.y += 980.0 * delta
			move_and_slide()
			sprite.modulate = Color(1.0, 0.3, 0.3, 1.0) if fmod(state_timer, 0.3) < 0.15 else Color(1.0, 0.1, 0.1, 1.0)
			if state_timer <= 0.0:
				sprite.modulate = Color(1, 1, 1, 1)
				sprite.color = Color(0.4, 0.25, 0.15, 1.0)
				current_state = State.PATROL
				state_timer = maxf(1.4, 3.0 - phase * 0.5)
				hitbox.monitorable = false
				hitbox.monitoring = false

## Aimed clipboard(s) — one shot in P1, two in P2, a triple fan in P3.
func _throw_clipboard() -> void:
	var p := get_tree().get_first_node_in_group("player")
	var base := Vector2.RIGHT if patrol_direction > 0 else Vector2.LEFT
	if p:
		base = global_position.direction_to(p.global_position)
	var spreads: Array = [[0.0], [0.0], [-0.18, 0.18], [-0.32, 0.0, 0.32]][phase]
	for s: float in spreads:
		var proj := CLIPBOARD.instantiate()
		proj.direction = base.rotated(s)
		proj.speed = 240.0 + phase * 40.0
		proj.tint = Color(0.95, 0.92, 0.8, 1.0)  # paper
		proj.global_position = global_position + Vector2(48, 40)
		get_parent().add_child(proj)
	AudioManager.play_sfx("throw")

func take_damage(amount: int) -> void:
	if current_state == State.DEFEATED or current_state != State.VULNERABLE:
		return
	health -= amount
	AudioManager.play_sfx("damage")
	BossVoiceSystem.say(self, BOSS_ID, "hurt")
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(10, 10, 10, 1), 0.05)
	tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.05)
	if health <= 0:
		die()
		return
	_update_phase()
	current_state = State.PATROL
	state_timer = maxf(1.4, 2.0 - phase * 0.3)
	sprite.color = Color(0.4, 0.25, 0.15, 1.0)
	hitbox.monitorable = false
	hitbox.monitoring = false

## Recompute phase from HP ratio; on a new phase, escalate + taunt.
func _update_phase() -> void:
	var ratio := float(health) / float(max_health)
	var new_phase := 1
	if ratio <= 0.33:
		new_phase = 3
	elif ratio <= 0.66:
		new_phase = 2
	if new_phase != phase:
		phase = new_phase
		patrol_speed = _base_patrol_speed * (1.0 + 0.25 * (phase - 1))
		if phase == 2:
			BossVoiceSystem.say(self, BOSS_ID, "phase50", true)
		elif phase == 3:
			patrol_speed = _base_patrol_speed * 1.5
			BossVoiceSystem.say(self, BOSS_ID, "phase25", true)
			ScreenShake.medium()

func die() -> void:
	current_state = State.DEFEATED
	BossVoiceSystem.say(self, BOSS_ID, "death", true)
	BossVoiceSystem.clear_active()
	GameManager.add_score(500)
	ScreenShake.shake(0.5, 8.0)
	hitbox.monitorable = false
	hitbox.monitoring = false
	StateMachine.change_state(StateMachine.State.LEVEL_COMPLETE)
	# AgentMail milestone hook: first Auditor kill triggers the victory email
	# server-side (idempotent there — safe to report every kill).
	Web3Bridge.report_event("boss_defeat", {
		"boss": "tax", "score": GameManager.total_score, "first_time": true})
	ScreenShake.zoom_to(1.0, 0.6)
	AudioManager.play_voice("victory")
	ScreenShake.heavy()
	GameManager.save_session()
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 1.0)
	tween.parallel().tween_property(self, "rotation", PI * 4, 1.0)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 1.0)
	await tween.finished
	# Movie/Video-Game Layer: wallet-gated badge claim + on-chain score + NFT
	# funnel. The level is already won; this screen is purely additive and skips
	# cleanly with no wallet/backend. See src/ui/victory_screen.gd + LAYER_SHIFT.md.
	var victory := preload("res://src/ui/victory_screen.tscn").instantiate()
	victory.setup(GameManager.total_score, 1)
	get_tree().current_scene.add_child(victory)
	queue_free()

func _on_hitbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(1)
		BossVoiceSystem.say(self, BOSS_ID, "mock")

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("projectile"):
		take_damage(1)
