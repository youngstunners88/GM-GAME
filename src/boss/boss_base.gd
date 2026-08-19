class_name BossBase
extends EnemyBase

## Fired when a one-shot boss animation ends — state machines can key
## attack-recovery / death-cleanup transitions off this.
signal animation_finished(anim: String)

@export var max_health: int = 5
@export var phase_thresholds: Array[int] = []

var current_phase: int = 1
var health_bar: BossHealthBar
var _anim_sprite: AnimatedSprite2D

## Player-facing boss name for the health bar. Overridden per boss.
var boss_display_name: String = "BOSS"

## SPAWN GRACE — shared by every BossBase subclass (Distributor, Claim
## Jumper). A real-browser capture caught a boss killing the player via
## body contact within ~2s of a fight starting, before any scripted attack,
## from the opening close-the-gap sweep — indistinguishable, from the
## founder's side, from "the boss won't let me past this point" (the level
## just restarts near the boss over and over). Neither subclass calls
## `super()` in its own `_ready()`, so this can't be set there; `_enter_tree`
## runs unconditionally on every instance regardless of subclass `_ready`
## chains. Each subclass's own `_on_hitbox_body_entered` must check
## `is_spawn_grace_active()` before calling `GameManager.boss_contact_restart()`
## — this base class only tracks the timer, it does not intercept the signal.
const SPAWN_GRACE_SEC: float = 1.2
var _spawn_grace_until_msec: int = 0

func _enter_tree() -> void:
	_spawn_grace_until_msec = Time.get_ticks_msec() + int(SPAWN_GRACE_SEC * 1000.0)

func is_spawn_grace_active() -> bool:
	return Time.get_ticks_msec() < _spawn_grace_until_msec

func _ready() -> void:
	add_to_group("boss")
	health = max_health
	_setup_health_bar()
	super()

func _setup_health_bar() -> void:
	# Screen-anchored CanvasLayer, NOT a child ProgressBar parented to the boss
	# body. The old version rode along with the boss, so it jittered during
	# patrol, slid off-screen when the boss did, and scaled with the boss-arena
	# camera zoom. See src/ui/boss_health_bar.gd for the full reasoning.
	health_bar = BossHealthBar.new()
	# add_child() on a node already inside the tree runs the child's _ready()
	# SYNCHRONOUSLY, so BossHealthBar._build() has completed by the time this
	# returns and the bar can be configured immediately. An earlier version
	# deferred these two calls on the incorrect assumption that _ready() had
	# not run yet — which cost a one-frame blank bar at fight start.
	add_child(health_bar)
	health_bar.set_boss(boss_display_name, max_health, phase_thresholds)
	health_bar.set_health(health)

func take_damage(amount: int) -> void:
	var before := health
	super(amount)
	# super() routes through EnemyBase.take_damage, which calls die() on the
	# killing blow — and die() frees the health bar. Touching the bar after
	# that is a call on a freed instance, so bail out once we're dead. (Kimi
	# audit finding, confirmed by reading EnemyBase.take_damage: it really
	# does call die() inline.)
	if is_dead:
		return
	_update_health_bar(before)
	_check_phase_change()

func _update_health_bar(hp_before: int = -1) -> void:
	# is_instance_valid, not `== null`: queue_free() leaves the variable
	# non-null while the object is already gone, so a null check passes and
	# the next method call errors.
	if not is_instance_valid(health_bar):
		return
	health_bar.set_health(health)
	if hp_before > health:
		# Left-anchored drain: the pip that just went dark is the one at the
		# new HP index (dropping 6 -> 5 darkens pip 5).
		health_bar.flash_damage(health)

func _check_phase_change() -> void:
	if phase_thresholds.is_empty():
		return
	var new_phase = 1
	for threshold in phase_thresholds:
		if health <= threshold:
			new_phase += 1
	if new_phase != current_phase:
		current_phase = new_phase
		if health_bar:
			health_bar.set_phase(current_phase)
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
	if is_instance_valid(health_bar):
		health_bar.queue_free()
	# Null it explicitly. queue_free() alone leaves a dangling reference that
	# still passes a truthy `if health_bar:` check, so later callers would
	# invoke methods on a freed instance.
	health_bar = null
	super()

func lock_camera_to_arena(start_x: float, end_x: float) -> void:
	# Camera lock to arena bounds - override if custom camera needed
	pass
