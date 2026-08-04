extends BossBase
## Boss 3 — The Claim Jumper (Bandit). Final-stage boss: a quick-draw charge
## (telegraphed) forces positioning, followed by a dynamite volley that lands
## ON the player's position (also telegraphed — see dynamite.gd), then a
## vulnerable window that SHRINKS each phase so there's less free damage time
## as the fight escalates. Phase escalation adds more dynamite, faster
## charges, and increasingly unhinged taunts.
##
## Previous version's state machine declared CHARGE/THROW/VULNERABLE but never
## transitioned into them — the boss only ever ran PATROL forever, and
## take_damage() had no vulnerable-state gate at all (unlike the Auditor and
## the Distributor), so it was damageable at every moment with zero risk/
## reward structure. That made the intended "final boss" fight the LEAST
## demanding of the three, not the most. Both are fixed here.

const BOSS_ID := "bandit"
const DYNAMITE := preload("res://src/boss/dynamite.tscn")

enum State { PATROL, TELL, CHARGE, THROW, VULNERABLE }

@export var patrol_speed: float = 100.0
@export var charge_speed: float = 420.0
@export var throw_cooldown: float = 1.5
@export var vulnerable_time: float = 1.6
@export var tell_time: float = 0.45

var current_state: State = State.PATROL
var throw_timer: float = 2.2
var state_timer: float = 0.0
var direction: float = 1.0
var charge_dir: Vector2 = Vector2.ZERO

## Assigned, NOT redeclared: EnemyBase already owns `sprite`, and shadowing
## it is a parse error that leaves this entire script unattached.
@onready var boss_sprite: BossSprite = $ColorRect
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var hitbox: Area2D = $Hitbox
@onready var hitbox_shape: CollisionShape2D = $Hitbox/CollisionShape2D

func _ready() -> void:
	max_health = 6
	# MUST be set explicitly. EnemyBase.health defaults to 1, and this boss was
	# the only one of the four that set max_health without also setting health
	# — so the Claim Jumper had 1 HP and died to a single hit, while its bar
	# and phase thresholds ([4,2]) were configured for a 6-HP fight that could
	# never happen. Found while wiring the health bar; the bar would have made
	# it obvious on screen, but it was invisible before.
	health = max_health
	phase_thresholds = [4, 2]
	add_to_group("enemy")
	# Boss 3 was the only boss missing this. Kept consistent with the other two
	# so anything that queries for a live boss (arena logic, analytics, future
	# "is a boss fight active" checks) sees all three, not two of three.
	add_to_group("boss")
	boss_sprite.color = Color(0.6, 0.4, 0.2, 1.0)
	boss_sprite.size = Vector2(80, 80)
	collision.position = Vector2(40, 40)
	hitbox.position = Vector2(40, 40)
	hitbox_shape.shape = collision.shape
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	hitbox.area_entered.connect(_on_hitbox_area_entered)
	# Detect overlaps for the WHOLE fight, not only the VULNERABLE window —
	# the same contract the Distributor uses. Founder: "the third boss is
	# unimpacted by Lil Blunt's strikes and vice versa". Incoming damage is
	# still gated by take_damage()'s own VULNERABLE check below, so this does
	# not make him a free target; it is what makes walking into him actually
	# cost the player something.
	hitbox.set_deferred("monitoring", true)
	hitbox.set_deferred("monitorable", true)
	boss_display_name = "The Claim Jumper"
	_setup_health_bar()
	BossVoiceSystem.set_active(self, BOSS_ID)
	BossVoiceSystem.say(self, BOSS_ID, "intro", true)

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	throw_timer -= delta
	state_timer -= delta

	match current_state:
		State.PATROL:
			velocity.x = patrol_speed * direction
			velocity.y += 980.0 * delta
			move_and_slide()
			if is_on_wall():
				direction *= -1.0
				boss_sprite.set_facing(direction > 0)
			if throw_timer <= 0.0:
				_begin_tell()

		State.TELL:
			# Quick-draw wind-up — a bright flash gives the player a real
			# reaction window before the charge fires, instead of the dash
			# starting with zero warning.
			velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
			velocity.y += 980.0 * delta
			move_and_slide()
			boss_sprite.modulate = Color(2.0, 2.0, 0.6, 1.0) if fmod(state_timer, 0.15) < 0.075 else Color(1, 1, 1, 1)
			if state_timer <= 0.0:
				boss_sprite.modulate = Color(1, 1, 1, 1)
				_begin_charge()

		State.CHARGE:
			velocity = charge_dir * charge_speed
			move_and_slide()
			if state_timer <= 0.0 or is_on_wall():
				_begin_throw()

		State.THROW:
			velocity.x = move_toward(velocity.x, 0.0, 100.0 * delta * 60.0)
			velocity.y += 980.0 * delta
			move_and_slide()
			if state_timer <= 0.0:
				_throw_dynamite()
				_begin_vulnerable()

		State.VULNERABLE:
			velocity.x = move_toward(velocity.x, 0.0, 150.0 * delta * 60.0)
			velocity.y += 980.0 * delta
			move_and_slide()
			boss_sprite.modulate = Color(1.0, 0.3, 0.3, 1.0) if fmod(state_timer, 0.2) < 0.1 else Color(1.0, 0.1, 0.1, 1.0)
			if state_timer <= 0.0:
				boss_sprite.modulate = Color(1, 1, 1, 1)
				current_state = State.PATROL
				direction = -direction
				throw_timer = maxf(0.9, throw_cooldown - 0.3 * (current_phase - 1))
				# Hitbox deliberately stays live — see _ready(). Turning
				# monitoring off here meant the boss could only make contact
				# during the window the player is supposed to be ATTACKING
				# him in, and was otherwise completely intangible. That is
				# the founder's "Lil Blunt is unimpacted by the boss".
				# take_damage()'s own VULNERABLE gate still controls what the
				# player can hurt.

func _begin_tell() -> void:
	current_state = State.TELL
	state_timer = tell_time
	BossVoiceSystem.say(self, BOSS_ID, "taunt")
	var p := get_tree().get_first_node_in_group("player")
	charge_dir = Vector2(direction, 0.0) if p == null else global_position.direction_to(p.global_position)

func _begin_charge() -> void:
	current_state = State.CHARGE
	# Faster, longer charges each phase — the dash itself gets more dangerous,
	# not just the dynamite that follows it.
	state_timer = 0.5 + 0.1 * (current_phase - 1)
	charge_speed = 420.0 + 60.0 * (current_phase - 1)

func _begin_throw() -> void:
	current_state = State.THROW
	state_timer = 0.35
	direction = 1.0 if velocity.x >= 0.0 else -1.0
	boss_sprite.set_facing(direction > 0)

func _begin_vulnerable() -> void:
	current_state = State.VULNERABLE
	# Less free damage time as phases escalate — the risk/reward window
	# shrinks instead of staying flat while everything else gets harder.
	state_timer = maxf(0.7, vulnerable_time - 0.3 * (current_phase - 1))
	boss_sprite.color = Color(1.0, 0.2, 0.2, 1.0)
	hitbox.set_deferred("monitorable", true)
	hitbox.set_deferred("monitoring", true)

## Accelerate patrol + taunt on phase transition (BossBase calls this).
func _on_phase_changed() -> void:
	if current_phase >= 2:
		patrol_speed = 150.0
		BossVoiceSystem.say(self, BOSS_ID, "phase50", true)
	if current_phase >= 3:
		patrol_speed = 190.0
		BossVoiceSystem.say(self, BOSS_ID, "phase25", true)
		ScreenShake.medium()

## Lob dynamite so it lands on the player's position — a telegraphed blast
## zone (dynamite.gd draws its own warning ring + fuse). Phase 1: 1 stick.
## Phase 2: 2. Phase 3: 3 spread around the player.
func _throw_dynamite() -> void:
	var p := get_tree().get_first_node_in_group("player")
	var target := global_position + Vector2(120 * (1.0 if direction > 0 else -1.0), -60)
	if p:
		target = p.global_position + Vector2(0, -80)
	var count: int = [0, 1, 2, 3][current_phase]
	for i in range(count):
		var dyn := DYNAMITE.instantiate()
		dyn.global_position = target + Vector2((i - float(count - 1) / 2.0) * 70.0, 0)
		get_parent().add_child(dyn)
	AudioManager.play_sfx("throw")

## Only takes damage during the telegraphed VULNERABLE window — matches the
## Auditor and the Distributor. Without this gate the fight had NO risk/
## reward structure: free damage at any moment, in any state.
func take_damage(amount: int) -> void:
	if is_dead or current_state != State.VULNERABLE:
		return
	# Captured BEFORE the decrement — BossBase's pip-flash only fires when
	# hp_before > health, so reading it afterwards would leave the flash just
	# as dead as the bare call it replaced.
	var before := health
	health -= amount
	AudioManager.play_sfx("damage")
	BossVoiceSystem.say(self, BOSS_ID, "hurt")
	# Tween `boss_sprite`, NOT `sprite`. EnemyBase resolves `sprite` via
	# get_node_or_null("Sprite") and claim_jumper.tscn has no such child (the
	# art is the BossSprite on "ColorRect"), so `sprite` is null and this
	# tween errored on every hit while showing no flash. Found by the Kimi
	# audit of the Distributor (finding F1) — same defect, same base class.
	# The Auditor is exempt: it declares its own `sprite := $ColorRect`.
	var tween := create_tween()
	tween.tween_property(boss_sprite, "modulate", Color(10, 10, 10, 1), 0.05)
	tween.tween_property(boss_sprite, "modulate", Color(1, 1, 1, 1), 0.05)
	# Pass pre-hit HP so BossBase's pip-flash actually fires (it only runs
	# when hp_before > health; the bare call left it permanently skipped).
	_update_health_bar(before)
	if health <= 0:
		die()
	else:
		current_state = State.PATROL
		direction = -direction
		throw_timer = maxf(0.9, throw_cooldown - 0.3 * (current_phase - 1))
		boss_sprite.color = Color(0.6, 0.4, 0.2, 1.0)
		boss_sprite.modulate = Color(1, 1, 1, 1)
		# Hitbox stays live for the whole fight (see _ready()) — only die()
		# switches it off.
		_check_phase_change()

func die() -> void:
	is_dead = true
	BossVoiceSystem.say(self, BOSS_ID, "death", true)
	BossVoiceSystem.clear_active()
	set_physics_process(false)
	GameManager.add_score(750)
	ScreenShake.shake(0.6, 10.0)
	hitbox.set_deferred("monitorable", false)
	hitbox.set_deferred("monitoring", false)
	StateMachine.change_state(StateMachine.State.LEVEL_COMPLETE)
	ScreenShake.zoom_to(1.0, 0.6)
	AudioManager.play_voice("game_complete")
	ScreenShake.heavy()
	# Gold Rush Auction settlement — whitepaper specifies pro-rata XAUT payout
	# at week end. Player contributes their GOLD pool, settles vs. enemy reserve.
	var player_contribution := GoldMineSystem.gold_balance + GoldMineSystem.auction_gold_pool
	var enemy_reserve := 50  # Strategic Reserve baseline contribution
	var total_pool := player_contribution + enemy_reserve
	GoldMineSystem.forfeit_to_auction(GoldMineSystem.gold_balance)
	var xaut_won := GoldMineSystem.settle_auction(player_contribution, total_pool)
	# Treasury revenue distribution from boss "operations" — 50/20/20/10 split
	var treasury_payout := 100
	GoldMineSystem.distribute_treasury_revenue(treasury_payout)
	GameManager.save_session()
	if is_instance_valid(health_bar):
		health_bar.queue_free()
	# Null it: queue_free() leaves a dangling non-null reference that
	# still passes a truthy check (Kimi audit).
	health_bar = null
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 1.0)
	tween.parallel().tween_property(self, "rotation", PI * 4, 1.0)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 1.0)
	await tween.finished
	var victory := Label.new()
	# Final boss (brief G): the campaign ends here — back to the menu, which
	# now offers every unlocked realm via Continue.
	victory.text = "SMOKE REALM COMPLETE!\nXAUT payout: %d\nFort Knox shares: %d\nYou beat all three realms." % [xaut_won, GoldMineSystem.fort_knox_shares]
	victory.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	victory.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	victory.position = global_position - Vector2(150, 75)
	victory.add_theme_font_size_override("font_size", 28)
	get_tree().current_scene.add_child(victory)
	# Mark the whole campaign cleared (unlocks all realms for Continue/select).
	GameManager.highest_unlocked_level = GameManager.LEVEL_SEQUENCE.size()
	await get_tree().create_timer(3.5).timeout
	# Kimi audit ordering: free BEFORE the scene load.
	queue_free()
	SceneRouter.load_scene("res://src/ui/main_menu.tscn", SceneRouter.Transition.DIAMOND)

func _on_hitbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(1)
		BossVoiceSystem.say(self, BOSS_ID, "mock")

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("projectile"):
		take_damage(1)
