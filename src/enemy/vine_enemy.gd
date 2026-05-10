class_name VineEnemy
extends EnemyBase

@export var attack_range: float = 150.0
@export var attack_cooldown: float = 2.0

var attack_timer: float = 0.0
var in_attack_anim: bool = false

func _ready() -> void:
	super()
	max_health = 2
	health = max_health
	damage = 1
	sprite.color = Color(0.3, 0.6, 0.2, 1.0)
	sprite.size = Vector2(48, 48)
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	attack_timer -= delta

	var player = get_tree().get_first_node_in_group("player")
	if player and attack_timer <= 0:
		var dist = global_position.distance_to(player.global_position)
		if dist < attack_range:
			_perform_attack()

	velocity.y += 980.0 * delta
	move_and_slide()

func _perform_attack() -> void:
	if in_attack_anim:
		return
	in_attack_anim = true
	attack_timer = attack_cooldown
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.2, 0.8), 0.1)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15)
	tween.finished.connect(func(): in_attack_anim = false)
