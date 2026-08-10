extends BossBase
## Boss 3 — The Claim Jumper (Bandit). Lobs dynamite that lands ON the player's
## position (telegraphed danger zones); phase escalation adds more sticks and
## faster patrol, with increasingly unhinged taunts. Final phase rains dynamite.

const BOSS_ID := "bandit"
const DYNAMITE := preload("res://src/boss/dynamite.tscn")

enum State { PATROL, THROW, VULNERABLE }

@export var patrol_speed: float = 165.0
@export var throw_cooldown: float = 1.05

var current_state: State = State.PATROL
var throw_timer: float = 0.0
var direction: float = 1.0
## Motion feel + traversal, matching the Auditor's tuned values so the two
## bosses move with the same weight rather than each having its own dialect.
var _hop_cooldown: float = 0.0
const WALK_ACCEL: float = 620.0
const TURN_DECEL: float = 1400.0
const TURN_DEAD_ZONE: float = 34.0
## Clears ~196px at gravity 980 — same envelope the Auditor uses.
const HOP_VELOCITY: float = -620.0

## Assigned, NOT redeclared: EnemyBase already owns `sprite`, and shadowing
## it is a parse error that leaves this entire script unattached.
@onready var boss_sprite: BossSprite = $ColorRect
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var hitbox: Area2D = $Hitbox
@onready var hitbox_shape: CollisionShape2D = $Hitbox/CollisionShape2D

func _ready() -> void:
	# STAGE 3 OF 3 — the hardest stage boss. Was 6 HP, i.e. weaker than both
	# bosses before him (see the distributor note on the inverted curve).
	max_health = 18
	# MUST be set explicitly. EnemyBase.health defaults to 1, and this boss was
	# the only one of the four that set max_health without also setting health
	# — so the Claim Jumper had 1 HP and died to a single hit, while its bar
	# and phase thresholds ([4,2]) were configured for a 6-HP fight that could
	# never happen. Found while wiring the health bar; the bar would have made
	# it obvious on screen, but it was invisible before.
	health = max_health
	phase_thresholds = [12, 6]
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
	boss_display_name = "The Claim Jumper"
	_setup_health_bar()
	BossVoiceSystem.set_active(self, BOSS_ID)
	BossVoiceSystem.say(self, BOSS_ID, "intro", true)

## HARD ARENA BOX — the boss physically cannot leave the fight.
##
## Founder: "There is a massive glistch with the final boss as he is fucking
## dumb and dies by falling off the ledge... Lil Blunt is unable to deal with
## him so the game cannot proceed."
##
## He was right that it makes the game unfinishable, and the cause was simply
## that this boss had NO bounds of any kind: he applied gravity, walked toward
## the player, and the moment the stalk carried him past the lip of a platform
## he fell into the void below the arena and the fight could never end. The
## Distributor already solved exactly this (see distributor.gd's
## _clamp_to_arena, added after he "fell in the trench and disappeared"), but
## the fix was never carried across to this boss.
##
## Set by level_03_gold_rush.gd from the level's own boss_arena data BEFORE
## add_child, so the clamp is live on the very first physics frame.
## Zero size = unset, in which case only the ledge sense below applies.
var arena_min: Vector2 = Vector2.ZERO
var arena_max: Vector2 = Vector2.ZERO

func _clamp_to_arena() -> void:
	if arena_max == Vector2.ZERO:
		return
	global_position.x = clampf(global_position.x, arena_min.x, arena_max.x)
	# Only the FLOOR is clamped, not the ceiling: he hops, and pinning his
	# maximum height would cancel the hop mid-air.
	if global_position.y > arena_max.y:
		global_position.y = arena_max.y
		if velocity.y > 0.0:
			velocity.y = 0.0

## How far ahead of himself he checks for solid ground, and how far down.
const LEDGE_PROBE_AHEAD: float = 56.0
const LEDGE_PROBE_DROP: float = 120.0

## True when there is NO floor ahead in `facing` — i.e. the next step walks off
## a ledge. Belt and braces alongside the arena clamp: the clamp stops him
## leaving the arena box, this stops him walking into a pit INSIDE it.
func _ledge_ahead(facing: float) -> bool:
	var space := get_world_2d().direct_space_state
	# Cast from just above his feet, ahead of the body, straight down.
	# Body is 80x80 with its ORIGIN AT THE TOP-LEFT (collision sits at +40,+40),
	# so the feet are at origin.y + 80 and the centre at origin.x + 40.
	var foot_y: float = global_position.y + 80.0
	var from := Vector2(global_position.x + 40.0 + LEDGE_PROBE_AHEAD * facing, foot_y - 8.0)
	var params := PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, LEDGE_PROBE_DROP))
	# World geometry only (layer 1) — never treat the player or a pickup as floor.
	params.collision_mask = 1
	params.exclude = [get_rid()]
	return space.intersect_ray(params).is_empty()

## Horizontal reach of one hop. HOP_VELOCITY -620 against gravity 980 is ~1.26s
## of airtime; at the fastest phase-3 patrol speed (275) that is ~348px. Probed
## a little short of the true maximum so he only commits to a landing he can
## comfortably make.
const HOP_REACH: float = 300.0

## True when there IS ground to land on across the gap ahead.
##
## Without this the ledge sense made things WORSE, not better: spotting a ledge
## triggered the hop, and the hop then carried him over the edge and into the
## void anyway — the test caught him at y=2242 with the floor at 600. A gap is
## only worth jumping if something is waiting on the other side.
func _gap_crossable(facing: float) -> bool:
	var space := get_world_2d().direct_space_state
	var foot_y: float = global_position.y + 80.0
	for dist: float in [140.0, 200.0, 260.0, HOP_REACH]:
		var from := Vector2(global_position.x + 40.0 + dist * facing, foot_y - 8.0)
		var params := PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, LEDGE_PROBE_DROP))
		params.collision_mask = 1
		params.exclude = [get_rid()]
		if not space.intersect_ray(params).is_empty():
			return true
	return false

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	throw_timer -= delta
	_hop_cooldown -= delta

	match current_state:
		State.PATROL:
			# STALK the live player rather than pacing wall to wall. The
			# founder's "the bosses need to be more challenging" applies here
			# too: this boss only ever bounced between walls, so a player who
			# stood still was never approached.
			var pl := get_tree().get_first_node_in_group("player")
			if pl:
				var dx: float = pl.global_position.x - global_position.x
				if absf(dx) > TURN_DEAD_ZONE:
					direction = signf(dx)
			# Ease into the target speed so he reads as heavy, not robotic.
			var target_vx: float = patrol_speed * direction
			var rate: float = (TURN_DECEL
				if signf(target_vx) != signf(velocity.x) and not is_zero_approx(velocity.x)
				else WALK_ACCEL)
			velocity.x = move_toward(velocity.x, target_vx, rate * delta)
			# LEDGE SENSE. Standing on solid ground with a drop directly ahead,
			# he refuses to take the step — he holds the lip instead of walking
			# into the void. Only while GROUNDED, so a hop across a gap is never
			# cancelled mid-air.
			var at_ledge := false
			if is_on_floor() and not is_zero_approx(target_vx):
				at_ledge = _ledge_ahead(signf(target_vx))
				if at_ledge:
					velocity.x = 0.0
			velocity.y += 980.0 * delta
			move_and_slide()
			_clamp_to_arena()
			if absf(velocity.x) > 12.0:
				boss_sprite.set_facing(velocity.x > 0.0)
			# Blocked by terrain, or the player is above him -> hop. A ledge now
			# also triggers the hop: if the player is across a gap he JUMPS it
			# rather than standing at the edge forever, which keeps him
			# threatening instead of merely safe.
			if is_on_floor() and _hop_cooldown <= 0.0:
				# A ledge only justifies a hop when there is somewhere to LAND.
				# Otherwise he holds the lip: still blocking the arena, never
				# suiciding into the void.
				var want_hop := is_on_wall() or (at_ledge and _gap_crossable(direction))
				if pl and pl.global_position.y < global_position.y - 80.0:
					want_hop = true
				if want_hop:
					velocity.y = HOP_VELOCITY
					_hop_cooldown = 0.7
			if throw_timer <= 0:
				_throw_dynamite()

		State.THROW:
			velocity.x = move_toward(velocity.x, 0.0, 100.0 * delta * 60.0)
			velocity.y += 980.0 * delta
			move_and_slide()
			_clamp_to_arena()

		State.VULNERABLE:
			velocity.x = move_toward(velocity.x, 0.0, 150.0 * delta * 60.0)
			velocity.y += 980.0 * delta
			move_and_slide()
			_clamp_to_arena()
			boss_sprite.modulate = Color(1.0, 0.3, 0.3, 1.0) if fmod(throw_timer, 0.2) < 0.1 else Color(1.0, 0.1, 0.1, 1.0)

## Accelerate patrol + taunt on phase transition (BossBase calls this).
func _on_phase_changed() -> void:
	if current_phase >= 2:
		patrol_speed = 215.0
		BossVoiceSystem.say(self, BOSS_ID, "phase50", true)
	if current_phase >= 3:
		patrol_speed = 275.0
		BossVoiceSystem.say(self, BOSS_ID, "phase25", true)
		ScreenShake.medium()

## Lob dynamite so it lands on the player's position — a telegraphed blast
## zone. Phase 1: 1 stick. Phase 2: 2. Phase 3: 3 spread around the player.
func _throw_dynamite() -> void:
	throw_timer = maxf(0.8, throw_cooldown - 0.3 * (current_phase - 1))
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

func take_damage(amount: int) -> void:
	if is_dead:
		return
	health -= amount
	AudioManager.play_sfx("damage")
	BossVoiceSystem.say(self, BOSS_ID, "hurt")
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(4.0, 0.25, 0.25, 1), 0.05)
	tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.05)
	_update_health_bar()
	if health <= 0:
		die()
	else:
		_check_phase_change()

func die() -> void:
	is_dead = true
	BossVoiceSystem.say(self, BOSS_ID, "death", true)
	BossVoiceSystem.clear_active()
	set_physics_process(false)
	GameManager.add_score(750)
	ScreenShake.shake(0.6, 10.0)
	hitbox.monitorable = false
	hitbox.monitoring = false
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
		GameManager.last_damage_source = BOSS_ID
		BossVoiceSystem.say(self, BOSS_ID, "mock")
		# Founder stakes rule: ANY boss touch returns Lil Blunt to the START of
		# the level, regardless of remaining lives — not hurt-and-continue.
		# See GameManager.boss_contact_restart().
		GameManager.boss_contact_restart()

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("projectile"):
		take_damage(1)
