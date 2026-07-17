extends BossBase
## Boss 2 — The Distributor (Crystalline Bureaucrat). Fires aimed, slightly
## homing ETH orbs; phase escalation (BossBase.current_phase 1→2→3 at
## phase_thresholds) widens the spread and tightens cadence, with corporate
## taunts per phase. Damage window is the post-throw VULNERABLE state.

const BOSS_ID := "crystal"
const ORB := preload("res://src/boss/boss_projectile.tscn")

enum Phase { PATROL, SHARD_THROW, VULNERABLE }

@export var patrol_speed: float = 80.0
@export var throw_cooldown: float = 2.0

var current_phase_state: Phase = Phase.PATROL
var throw_timer: float = 0.0
var direction: float = 1.0

@onready var sprite: BossSprite = $ColorRect
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var hitbox: Area2D = $Hitbox
@onready var hitbox_shape: CollisionShape2D = $Hitbox/CollisionShape2D

func _ready() -> void:
	max_health = 7
	health = 7
	phase_thresholds = [4, 2]
	add_to_group("enemy")
	add_to_group("boss")
	sprite.color = Color(0.3, 0.2, 0.6, 1.0)
	sprite.size = Vector2(96, 96)
	collision.position = Vector2(48, 48)
	hitbox.position = Vector2(48, 48)
	hitbox_shape.shape = collision.shape
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	hitbox.area_entered.connect(_on_hitbox_area_entered)
	_setup_health_bar()
	BossVoiceSystem.set_active(self, BOSS_ID)
	BossVoiceSystem.say(self, BOSS_ID, "intro", true)

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	throw_timer -= delta

	match current_phase_state:
		Phase.PATROL:
			velocity.x = patrol_speed * direction
			velocity.y += 980.0 * delta
			move_and_slide()
			if is_on_wall():
				direction *= -1.0
				sprite.scale.x = 1.0 if direction > 0 else -1.0
			if throw_timer <= 0:
				_throw_shards()

		Phase.SHARD_THROW:
			velocity.x = move_toward(velocity.x, 0.0, 100.0)
			velocity.y += 980.0 * delta
			move_and_slide()
			if throw_timer <= 0:
				current_phase_state = Phase.VULNERABLE
				sprite.color = Color(1.0, 0.2, 0.2, 1.0)
				hitbox.monitorable = true
				hitbox.monitoring = true

		Phase.VULNERABLE:
			velocity.x = move_toward(velocity.x, 0.0, 100.0)
			velocity.y += 980.0 * delta
			move_and_slide()
			sprite.modulate = Color(1.0, 0.3, 0.3, 1.0) if fmod(throw_timer, 0.3) < 0.15 else Color(1.0, 0.1, 0.1, 1.0)

## Aimed, slightly-homing ETH orbs. Count + spread + cadence scale with the
## BossBase HP phase (1/2/3): 3 orbs → 5 orbs → 5 fast orbs.
func _throw_shards() -> void:
	throw_timer = maxf(1.0, throw_cooldown - 0.4 * (current_phase - 1))
	current_phase_state = Phase.SHARD_THROW
	var count: int = [0, 3, 5, 5][current_phase]
	var p := get_tree().get_first_node_in_group("player")
	var base := Vector2.DOWN if p == null else global_position.direction_to(p.global_position)
	for i in range(count):
		var spread := (float(i) - float(count - 1) / 2.0) * 0.22
		var orb := ORB.instantiate()
		orb.direction = base.rotated(spread)
		orb.speed = 170.0 + 40.0 * (current_phase - 1)
		orb.homing = 0.6 if current_phase >= 2 else 0.0
		orb.tint = Color(0.6, 0.8, 1.0, 1.0)  # ETH blue
		orb.global_position = global_position + Vector2(48, 20)
		get_parent().add_child(orb)
	AudioManager.play_sfx("throw")

## Corporate taunt on each phase escalation (BossBase calls this).
func _on_phase_changed() -> void:
	if current_phase == 2:
		BossVoiceSystem.say(self, BOSS_ID, "phase50", true)
	elif current_phase == 3:
		BossVoiceSystem.say(self, BOSS_ID, "phase25", true)
		ScreenShake.medium()

func take_damage(amount: int) -> void:
	if is_dead or current_phase_state != Phase.VULNERABLE:
		return
	health -= amount
	AudioManager.play_sfx("damage")
	BossVoiceSystem.say(self, BOSS_ID, "hurt")
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(10, 10, 10, 1), 0.05)
	tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.05)
	_update_health_bar()
	if health <= 0:
		die()
	else:
		current_phase_state = Phase.PATROL
		throw_timer = 2.0
		sprite.color = Color(0.3, 0.2, 0.6, 1.0)
		hitbox.monitorable = false
		hitbox.monitoring = false
		_check_phase_change()

func die() -> void:
	is_dead = true
	BossVoiceSystem.say(self, BOSS_ID, "death", true)
	BossVoiceSystem.clear_active()
	set_physics_process(false)
	GameManager.add_score(1000)
	ScreenShake.shake(0.6, 10.0)
	hitbox.monitorable = false
	hitbox.monitoring = false
	StateMachine.change_state(StateMachine.State.LEVEL_COMPLETE)
	ScreenShake.zoom_to(1.0, 0.6)
	AudioManager.play_voice("victory")
	ScreenShake.heavy()
	GameManager.save_session()
	if health_bar:
		health_bar.queue_free()
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 1.0)
	tween.parallel().tween_property(self, "rotation", PI * 4, 1.0)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 1.0)
	await tween.finished
	var victory := Label.new()
	victory.text = "LEVEL COMPLETE!\nDiamonds unlocked!"
	victory.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	victory.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	victory.position = global_position - Vector2(100, 50)
	victory.add_theme_font_size_override("font_size", 32)
	get_tree().current_scene.add_child(victory)
	await get_tree().create_timer(3.0).timeout
	SceneRouter.load_scene("res://src/ui/main_menu.tscn", SceneRouter.Transition.DIAMOND)
	queue_free()

func _on_hitbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(1)
		BossVoiceSystem.say(self, BOSS_ID, "mock")

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("projectile"):
		take_damage(1)
