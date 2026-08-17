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

## SPAWN GRACE (residuals, 2026-08-17): a real-browser capture on a fresh
## export caught the player dying to boss contact within ~2s of the fight
## starting, twice independently, well before the boss's first scripted
## action (PATROL's first attack fires at throw_timer=2.2s) — i.e. from raw
## body contact during the boss's opening close-the-gap sweep, not from any
## attack. Distributor's own comments already document this exact failure
## class once ("he killed a player who was standing still and never touched
## a control") and partially guarded it with HOVER_CLEARANCE/PULL_FLOOR_MARGIN
## — but those guard the STEADY-STATE hover, not the very first frames where
## the boss is still closing from his spawn point at up to MIN_PURSUE_SPEED
## with HOVER_ACCEL=1600 ramping fast, which can out-close the safety lock's
## own reaction window. A player who takes a full-run "you touched me, restart
## the level" hit before the fight has even visibly begun reads as "the boss
## doesn't chase" — because they never survive to see him chase.
##
## Root-agnostic fix, not a chase-numbers retune (those are already heavily
## tuned across many prior sessions — see distributor.gd's MIN_PURSUE_SPEED
## history — and should not be blindly re-tuned without stronger evidence):
## a brief window after the boss enters the fight during which boss BODY
## CONTACT cannot trigger the run-ending restart. Damage TO the boss and
## incoming ranged attacks are completely unaffected — this only swallows the
## specific "he materialized/closed distance and grazed me before I could
## even see what's happening" spawn-transition hit.
const SPAWN_GRACE_SEC: float = 1.2
var _spawn_grace_until_msec: int = 0

## Set in _enter_tree(), NOT _ready(). Every concrete boss (distributor.gd,
## claim_jumper.gd, ...) fully overrides _ready() WITHOUT calling super() —
## a pre-existing pattern in this codebase, each boss reimplements its own
## add_to_group/_setup_health_bar inline — so anything this base class needs
## to run unconditionally for every boss must live in a lifecycle hook no
## subclass shadows. _enter_tree() fires before _ready() and isn't overridden
## anywhere in the boss hierarchy, so it is the one place that reliably runs
## first without depending on every boss remembering to call super().
func _enter_tree() -> void:
	_spawn_grace_until_msec = Time.get_ticks_msec() + int(SPAWN_GRACE_SEC * 1000.0)

func _ready() -> void:
	add_to_group("boss")
	health = max_health
	_setup_health_bar()
	super()

## True for SPAWN_GRACE_SEC after this boss entered the tree. Each boss's
## own contact handler should check this before calling
## GameManager.boss_contact_restart() — see distributor.gd / claim_jumper.gd.
func is_spawn_grace_active() -> bool:
	return Time.get_ticks_msec() < _spawn_grace_until_msec

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
