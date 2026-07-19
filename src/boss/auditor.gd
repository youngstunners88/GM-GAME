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

# Token-gated spectacle phases (task #23, Movie Layer). Flags read once at
# fight start from real wallet holdings (Web3Bridge). No wallet → all false →
# the fight is EXACTLY the shipped 3-phase version; holders get extra
# spectacle, never extra difficulty for non-holders.
var _has_diamonds: bool = false   # Phase "Diamond Surge": reflectable shards
var _has_gold: bool = false       # Phase "Gold Rush": golden safe platforms
var _has_smoke: bool = false      # Blaze Mode lasts 2x during the fight
var _shard_timer: float = 7.0
var _gold_platforms_spawned: bool = false

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
	# Movie-Layer spectacle gates — real balances, read at fight start.
	_has_diamonds = Web3Bridge.holds("diamonds")
	_has_gold = Web3Bridge.holds("goldmine")
	_has_smoke = Web3Bridge.holds("smoke")
	if _has_smoke:
		# SMOKE holders: any Blaze grabbed during this fight lasts twice as
		# long (direct timer write — no re-emit, so no feedback loop).
		GameManager.power_up_changed.connect(_on_powerup_smoke_bonus)

func _physics_process(delta: float) -> void:
	if current_state == State.DEFEATED:
		return
	state_timer -= delta
	throw_timer -= delta
	hop_timer -= delta

	# "Diamond Surge" (DIAMONDS holders, phase 2+): the Auditor summons slow
	# diamond shards — hit one with an attack and it reflects back for damage
	# that lands even outside his vulnerable window. Spectacle + skill reward.
	if _has_diamonds and phase >= 2:
		_shard_timer -= delta
		if _shard_timer <= 0.0:
			_shard_timer = 7.0
			_summon_diamond_shards()

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
		Web3Bridge.report_metric("boss_phase_reached", {"boss": BOSS_ID, "phase": phase})
		if phase == 2:
			BossVoiceSystem.say(self, BOSS_ID, "phase50", true)
		elif phase == 3:
			patrol_speed = _base_patrol_speed * 1.5
			BossVoiceSystem.say(self, BOSS_ID, "phase25", true)
			ScreenShake.medium()
			# "Gold Rush" (GoldMine holders): golden one-way platforms rise as
			# safe zones for the endgame — the fight LOOKS different.
			if _has_gold and not _gold_platforms_spawned:
				_gold_platforms_spawned = true
				_spawn_gold_platforms()

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
	# Pacing metric for adaptive difficulty: level completion time in seconds.
	var lvl := get_tree().current_scene
	if lvl != null and "level_start_ms" in lvl:
		Web3Bridge.report_metric("level_complete", {
			"seconds": (Time.get_ticks_msec() - int(lvl.level_start_ms)) / 1000})
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

# ---- Token-gated spectacle helpers (task #23) ----------------------------

## Double any Blaze grabbed mid-fight for SMOKE holders. Direct timer write:
## power_up_changed is emitted BY activate_power_up, we only extend the clock.
func _on_powerup_smoke_bonus(type: String, duration: float) -> void:
	if type == "blaze" and duration > 0.0 and current_state != State.DEFEATED:
		GameManager.power_up_timer = duration * 2.0

## Two slow cyan shards that drift at the player. An attack projectile
## touching one reflects it back at the Auditor for out-of-window damage.
func _summon_diamond_shards() -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p == null:
		return
	AudioManager.play_sfx("throw")
	for offset: float in [-40.0, 40.0]:
		var shard := Area2D.new()
		shard.collision_layer = 0
		shard.collision_mask = 2
		var spr := Sprite2D.new()
		spr.texture = load("res://src/assets/sprites/sprite_item_eth-ring.png")
		spr.modulate = Color(0.5, 0.95, 1.6, 1.0)
		spr.scale = Vector2(0.7, 0.7)
		shard.add_child(spr)
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(26, 26)
		cs.shape = rect
		shard.add_child(cs)
		shard.global_position = global_position + Vector2(48, 20 + offset)
		shard.set_meta("reflected", false)
		var dir: Vector2 = shard.global_position.direction_to(p.global_position)
		shard.set_meta("dir", dir)
		shard.body_entered.connect(_on_shard_body.bind(shard))
		shard.area_entered.connect(_on_shard_area.bind(shard))
		shard.set_physics_process(false)
		get_parent().add_child(shard)
		_drive_shard(shard)

## Manual drive via tween-less per-frame timer (Area2D has no physics tick of
## its own here; a 0.016s repeating timer keeps it dependency-free).
func _drive_shard(shard: Area2D) -> void:
	var tick := Timer.new()
	tick.wait_time = 0.016
	tick.autostart = true
	shard.add_child(tick)
	tick.timeout.connect(func() -> void:
		if not is_instance_valid(shard):
			tick.stop()
			return
		var dir: Vector2 = shard.get_meta("dir")
		var spd: float = 220.0 if bool(shard.get_meta("reflected")) else 110.0
		shard.global_position += dir * spd * 0.016
		if bool(shard.get_meta("reflected")) and is_instance_valid(self) \
				and shard.global_position.distance_to(global_position + Vector2(48, 48)) < 56.0:
			_take_reflected_damage()
			shard.queue_free())
	get_tree().create_timer(8.0).timeout.connect(func() -> void:
		if is_instance_valid(shard):
			shard.queue_free())

func _on_shard_body(body: Node2D, shard: Area2D) -> void:
	if bool(shard.get_meta("reflected")):
		return
	if body.is_in_group("player") and body.has_method("take_damage"):
		GameManager.last_damage_source = BOSS_ID
		body.take_damage(1)
		shard.queue_free()

func _on_shard_area(area: Area2D, shard: Area2D) -> void:
	# Player attack (axe/fire) reflects the shard back at the Auditor.
	if area.is_in_group("projectile") and not bool(shard.get_meta("reflected")):
		shard.set_meta("reflected", true)
		shard.set_meta("dir", shard.global_position.direction_to(global_position + Vector2(48, 48)))
		var spr := shard.get_child(0) as Sprite2D
		if spr:
			spr.modulate = Color(1.4, 1.6, 2.2, 1.0)
		AudioManager.play_sfx("powerup")

## Reflected shards damage the Auditor even outside VULNERABLE — the reward
## for the reflect skill-shot. Never fires once DEFEATED.
func _take_reflected_damage() -> void:
	if current_state == State.DEFEATED:
		return
	health -= 2
	AudioManager.play_sfx("damage")
	BossVoiceSystem.say(self, BOSS_ID, "hurt")
	EffectSpawner.burst("explosion", global_position + Vector2(48, 48))
	if health <= 0:
		die()
	else:
		_update_phase()

## Golden safe-zone platforms for the phase-3 endgame (GoldMine holders).
func _spawn_gold_platforms() -> void:
	for x_off: float in [-180.0, 180.0]:
		var plat := preload("res://src/level/one_way_platform.tscn").instantiate()
		plat.width = 110.0
		plat.global_position = global_position + Vector2(x_off, -90.0)
		get_parent().add_child(plat)
		var deck := plat.get_node_or_null("Deck")
		if deck:
			deck.color = Color(0.95, 0.8, 0.3, 1.0)  # gold
		EffectSpawner.burst("explosion", plat.global_position)

func _on_hitbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		GameManager.last_damage_source = BOSS_ID
		body.take_damage(1)
		BossVoiceSystem.say(self, BOSS_ID, "mock")

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("projectile"):
		take_damage(1)
