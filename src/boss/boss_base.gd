class_name BossBase
extends EnemyBase

## Fired when a one-shot boss animation ends — state machines can key
## attack-recovery / death-cleanup transitions off this.
signal animation_finished(anim: String)

@export var max_health: int = 5
@export var phase_thresholds: Array[int] = []

var current_phase: int = 1
var health_bar: ProgressBar
var _anim_sprite: AnimatedSprite2D

func _ready() -> void:
	add_to_group("boss")
	health = max_health
	_setup_health_bar()
	super()

func _setup_health_bar() -> void:
	health_bar = ProgressBar.new()
	health_bar.size = Vector2(200, 20)
	health_bar.position = Vector2(-100, -50)
	health_bar.max_value = max_health
	health_bar.value = max_health
	health_bar.modulate = Color(1.0, 0.2, 0.2, 1.0)
	add_child(health_bar)

func take_damage(amount: int) -> void:
	super(amount)
	_update_health_bar()
	_check_phase_change()

func _update_health_bar() -> void:
	if health_bar:
		health_bar.value = health

func _check_phase_change() -> void:
	if phase_thresholds.is_empty():
		return
	var new_phase = 1
	for threshold in phase_thresholds:
		if health <= threshold:
			new_phase += 1
	if new_phase != current_phase:
		current_phase = new_phase
		_on_phase_changed()

func _on_phase_changed() -> void:
	pass  # Override in subclasses for phase-specific behavior

## Plays a named animation once boss art ships as SpriteFrames on an
## AnimatedSprite2D child named "AnimSprite" (specs in ASSET_MANIFEST.md).
## No-ops gracefully on today's single-pose sprites, so callers can wire
## idle/walk/attack/hurt/death states now.
func play_animation(anim: String) -> void:
	if _anim_sprite == null:
		_anim_sprite = get_node_or_null("AnimSprite") as AnimatedSprite2D
		if _anim_sprite and not _anim_sprite.animation_finished.is_connected(_on_anim_sprite_finished):
			_anim_sprite.animation_finished.connect(_on_anim_sprite_finished)
	if _anim_sprite and _anim_sprite.sprite_frames \
			and _anim_sprite.sprite_frames.has_animation(anim):
		_anim_sprite.play(anim)

func _on_anim_sprite_finished() -> void:
	animation_finished.emit(_anim_sprite.animation)

func die() -> void:
	if health_bar:
		health_bar.queue_free()
	super()

func lock_camera_to_arena(start_x: float, end_x: float) -> void:
	# Camera lock to arena bounds - override if custom camera needed
	pass
