extends CharacterBody2D
## Boss 1 — The Auditor (Tax Collector). Three HP-scaled phases:
##   P1 (100-66%): patrol + lob a single aimed clipboard on a cadence.
##   P2 (66-33%):  faster, throws a 2-shot; charges more often.
##   P3 (33-0%):   enraged — +50% speed, TRIPLE spread clipboard, hops often.
## Damage window is still the post-charge VULNERABLE state (readable tell), but
## the ranged clipboards make him a threat at all times. Voice via BossVoiceSystem.
## Design: docs/architecture/adr-boss-ai-overhaul.md.
##
## auditor.tscn's root CharacterBody2D collision_mask was 15 (world + PLAYER +
## enemy + collectible) — Kimi audit 2026-08-02: CharacterBody2D-vs-
## CharacterBody2D means the player physically collided with the boss's body,
## so `is_on_wall()` could trip on touching the player, not just real
## geometry, ending a chase/charge on contact before it ever closed the gap.
## Contact damage is owned entirely by the separate Hitbox Area2D below, which
## doesn't need the main body to physically collide with the player at all —
## fixed to mask=13 (dropped the player layer, value 2).

enum State { PATROL, ALERT, PURSUE, VULNERABLE, DEFEATED }
const BOSS_ID := "tax"
const CLIPBOARD := preload("res://src/boss/boss_projectile.tscn")

@export var patrol_speed: float = 90.0
@export var vulnerable_time: float = 1.8
@export var max_health: int = 6
## Founder defect C3: "noticeably larger" — was the only boss with no scale
## treatment while Distributor already shipped BOSS_SCALE=1.7 (R8). Grok 4.5
## size-progression brief (docs/model-responses dispatch this session):
## Auditor 1.3x -> Distributor 1.7x -> Claim Jumper ~2.0x reads as escalating
## across the 3-boss campaign instead of flat/inverted (first boss should
## stay readable/fair, not out-scale the final-style Stage 2 boss).
const BOSS_SCALE := 1.3
## Founder defect #6: CHARGE used to dash at a POSITION SNAPSHOTTED once when
## the charge began — never the live player — so it never actually chased.
## Replaced with a continuously-retargeting PURSUE state (below); this is its
## base speed, scaled by phase the same way patrol_speed already is.
@export var pursue_speed: float = 170.0
@export var pursue_duration: float = 7.0
## Fairness contract telegraph (house style, see tax_collector.gd's ALERT):
## a frozen beat facing the player before the chase begins. Deliberately
## generous — this is most players' first-ever boss fight.
@export var alert_time: float = 0.6
@export var jump_force: float = -430.0
## Widest gap worth attempting during PURSUE. Derived from this boss's own
## kinematics (house style, see tax_collector.gd's max_jump_gap comment):
## jump_force=-430 / gravity 980 -> ~0.88s airtime; at base pursue_speed=170
## that's ~149px horizontal reach. 110 leaves margin for a raised ledge
## (shorter horizontal reach for the same launch) and DifficultyManager-style
## slowdowns.
@export var max_jump_gap: float = 110.0
var _jump_cooldown: float = 0.0
# Founder feel-review fairness tune (2026-08-04): PURSUE speed ramps 55%->100%
# over 0.7s and the contact hitbox stays inert for the first 0.35s — the
# ALERT telegraph already existed, but full speed + live contact damage used
# to land on the exact same frame PURSUE began. Not a redesign: top speed,
# live tracking, jump gating, and throw cadence are all unchanged.
var _pursue_elapsed: float = 0.0
var _pursue_hitbox_live: bool = false

var current_state: State = State.PATROL
var health: int = 6
var patrol_direction: float = 1.0
# Kimi audit (2026-08-02): 0.0 meant "state_timer <= 0.0" was already true on
# the very first physics frame, so the boss charged/pursued the instant it
# spawned, at whatever position the player happened to be standing in —
# before the player even had a beat to register the fight had started.
var state_timer: float = 2.0
var throw_timer: float = 2.0
var hop_timer: float = 6.0
var phase: int = 1
var _base_patrol_speed: float = 90.0
## Shared screen-anchored bar (src/ui/boss_health_bar.gd). Named with a leading
## underscore because this boss does NOT extend BossBase — it has no inherited
## `health_bar` member to match, and shadowing an inherited member is the exact
## parse-error class that left bosses 2/3/4 scriptless once before.
var _health_bar: BossHealthBar

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
	# Scale the whole body (sprite + collision + hitbox together, so the
	# hitbox never desyncs from the art) — same pattern as Distributor's R8.
	scale = Vector2(BOSS_SCALE, BOSS_SCALE)
	hitbox_shape.shape = collision.shape
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	hitbox.area_entered.connect(_on_hitbox_area_entered)
	# The Auditor extends CharacterBody2D directly rather than BossBase, so it
	# inherits none of BossBase's health-bar wiring — which is why the FIRST
	# boss every player meets was the only one fighting with no HP feedback at
	# all. Wire the same shared bar manually. Thresholds mirror _update_phase()
	# below, which switches at 50% and 25% of max_health.
	_health_bar = BossHealthBar.new()
	# Synchronous: add_child on an in-tree node runs the child's _ready() before
	# returning, so the bar is fully built here.
	add_child(_health_bar)
	_health_bar.set_boss(
		"The Auditor", max_health,
		[int(max_health * 0.5), int(max_health * 0.25)])
	_health_bar.set_health(health)
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

## Kimi audit: the boss can be freed WITHOUT die() (scene change mid-fight).
## The autoload signal + BossVoiceSystem ref must not dangle.
func _exit_tree() -> void:
	if _has_smoke and GameManager.power_up_changed.is_connected(_on_powerup_smoke_bonus):
		GameManager.power_up_changed.disconnect(_on_powerup_smoke_bonus)
	BossVoiceSystem.clear_active()

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
			# STALK, don't pace. Founder: "He must actively chase... The
			# Auditor should be able to chase him all the way through the
			# stage". The old behaviour walked back and forth on
			# patrol_direction and reversed on is_on_wall() — which, combined
			# with the arena seal wall that used to cage him (removed in
			# level_01_smoke_realm.gd), is why he read as stuck at one spot.
			# Now even his "calm" state closes distance on the live player, so
			# there is no state in which he stops hunting.
			var pl := get_tree().get_first_node_in_group("player")
			velocity.y += 980.0 * delta
			if pl:
				var stalk_dir := signf(pl.global_position.x - global_position.x)
				if stalk_dir == 0.0:
					stalk_dir = patrol_direction
				patrol_direction = stalk_dir
				velocity.x = patrol_speed * stalk_dir
				sprite.set_facing(stalk_dir > 0.0)
				# Hop over anything blocking the stalk (a ledge, a platform
				# edge) instead of grinding into it forever.
				if is_on_wall() and is_on_floor() and _jump_cooldown <= 0.0:
					velocity.y = jump_force
					_jump_cooldown = 0.9
			else:
				velocity.x = patrol_speed * patrol_direction
			move_and_slide()
			# Ranged pressure — cadence tightens per phase.
			if throw_timer <= 0.0:
				throw_timer = [0.0, 2.6, 2.0, 1.4][phase]
				_throw_clipboard()
			# Occasional reposition hop — now a forward vault toward the
			# player rather than a retreat away from the patrol direction.
			if hop_timer <= 0.0:
				hop_timer = 6.0 if phase < 3 else 3.5
				velocity.y = -320.0
				velocity.x = patrol_direction * 160.0
			if state_timer <= 0.0:
				# Telegraph BEFORE the chase — freeze, face the player, tell.
				state_timer = alert_time
				current_state = State.ALERT
				velocity.x = 0.0
				var p := get_tree().get_first_node_in_group("player")
				if p:
					sprite.set_facing(p.global_position.x > global_position.x)
				sprite.color = Color(0.85, 0.5, 0.15, 1.0)  # amber wind-up
				AudioManager.play_sfx_at("tax_alert", global_position)

		State.ALERT:
			velocity.x = 0.0
			velocity.y += 980.0 * delta
			move_and_slide()
			if state_timer <= 0.0:
				state_timer = pursue_duration
				current_state = State.PURSUE
				sprite.color = Color(0.55, 0.3, 0.12, 1.0)
				# Contact hurts during the chase; take_damage() stays gated to
				# VULNERABLE, so a stray projectile hitting this is a no-op.
				# The actual set_deferred enables are delayed — see the
				# hitbox-grace block in State.PURSUE below.
				_pursue_elapsed = 0.0
				_pursue_hitbox_live = false

		State.PURSUE:
			_jump_cooldown -= delta
			# Elapsed-PURSUE-time accumulator: frame-rate independent driver
			# for both the speed ramp and the hitbox grace window below.
			_pursue_elapsed += delta
			# Hitbox grace: contact damage arms 0.35s into the chase instead
			# of on the same frame the chase starts.
			if not _pursue_hitbox_live and _pursue_elapsed >= 0.35:
				_pursue_hitbox_live = true
				hitbox.set_deferred("monitorable", true)
				hitbox.set_deferred("monitoring", true)
			# Cast immediately: get_first_node_in_group() is typed `Node`, so
			# `p.global_position` is a Variant and `var x := <Variant>` is a
			# HARD PARSE ERROR in Godot 4.3 (it does not warn — it refuses to
			# load the whole script). See distributor.gd's _apply_pull() for
			# the same documented trap; missed once already in this session's
			# first draft.
			var p := get_tree().get_first_node_in_group("player") as CharacterBody2D
			if p == null:
				current_state = State.PATROL
				state_timer = 1.4
				sprite.color = Color(0.4, 0.25, 0.15, 1.0)
				hitbox.set_deferred("monitorable", false)
				hitbox.set_deferred("monitoring", false)
				return
			# LIVE tracking — re-read the player every frame, never a snapshot.
			# Phase speed scaling comes for free: _update_phase already scales
			# patrol_speed off _base_patrol_speed, so reuse that ratio.
			var speed_scale := patrol_speed / _base_patrol_speed
			# Speed ramp: 55% -> 100% of target speed over the first 0.7s of
			# PURSUE. Multiplies the final velocity.x — pursue_speed,
			# speed_scale, and all phase math stay untouched. Also scales the
			# max_jump_gap check below (Kimi post-tune audit): the gap was
			# derived at full speed's horizontal reach, so a jump launched
			# mid-ramp must be held to a smaller gap or it can fall short.
			var ramp := lerpf(0.55, 1.0, clampf(_pursue_elapsed / 0.7, 0.0, 1.0))
			var dx := p.global_position.x - global_position.x
			var toward := signf(dx)
			velocity.x = toward * pursue_speed * speed_scale * ramp
			sprite.set_facing(toward > 0.0)
			# Jump when the player is above or a wall blocks the chase — gated
			# on max_jump_gap so he never commits to a leap he can't land.
			var dy := p.global_position.y - global_position.y
			if is_on_floor() and _jump_cooldown <= 0.0:
				var wants_up := dy < -48.0
				var blocked := is_on_wall()
				# Kimi post-tune audit: max_jump_gap was derived at FULL
				# pursue_speed's horizontal reach. During the ramp window a
				# jump launches with less speed and covers less ground, so
				# the gate must shrink with `ramp` too, or a leap taken in
				# the first ~0.2s of a chase can now fall short of a gap it
				# was supposedly guaranteed to clear.
				if (wants_up or blocked) and absf(dx) <= max_jump_gap * ramp:
					velocity.y = jump_force
					_jump_cooldown = 0.9
			# Attack WHILE chasing — same per-phase cadence, slightly tighter.
			if throw_timer <= 0.0:
				throw_timer = [0.0, 2.2, 1.7, 1.2][phase]
				_throw_clipboard()
			velocity.y += 980.0 * delta
			move_and_slide()
			# Overextended — the readable damage window, unchanged from before.
			if state_timer <= 0.0:
				state_timer = vulnerable_time
				current_state = State.VULNERABLE
				sprite.color = Color(1.0, 0.2, 0.2, 1.0)
				hitbox.set_deferred("monitorable", true)
				hitbox.set_deferred("monitoring", true)

		State.VULNERABLE:
			velocity.x = move_toward(velocity.x, 0.0, 200.0)
			velocity.y += 980.0 * delta
			move_and_slide()
			sprite.modulate = Color(1.0, 0.3, 0.3, 1.0) if fmod(state_timer, 0.3) < 0.15 else Color(1.0, 0.1, 0.1, 1.0)
			# C1 residual (Kimi audit): PATROL/ALERT/PURSUE all re-face the live
			# player every frame, but VULNERABLE never did — it kept whatever
			# facing PURSUE last set, frozen for the whole ~1.8s damage window.
			# If the player moves during that window (likely — it's the window
			# they're supposed to attack in), the boss goes stale-faced exactly
			# while being hit, which reads as "still facing back."
			var vuln_pl := get_tree().get_first_node_in_group("player")
			if vuln_pl:
				sprite.set_facing(vuln_pl.global_position.x > global_position.x)
			if state_timer <= 0.0:
				sprite.modulate = Color(1, 1, 1, 1)
				sprite.color = Color(0.4, 0.25, 0.15, 1.0)
				current_state = State.PATROL
				state_timer = maxf(1.4, 3.0 - phase * 0.5)
				hitbox.set_deferred("monitorable", false)
				hitbox.set_deferred("monitoring", false)

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
	var hp_before := health
	health -= amount
	AudioManager.play_sfx("damage")
	BossVoiceSystem.say(self, BOSS_ID, "hurt")
	# RED pain flash (founder: "On hit the Auditor must flash red and play a
	# pain voice line"). This was Color(10,10,10,1) — a blown-out WHITE
	# over-exposure, which reads as a generic sparkle rather than damage.
	# The pain line is the BossVoiceSystem "hurt" call just above.
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(4.0, 0.25, 0.25, 1), 0.05)
	tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.12)
	if _health_bar:
		_health_bar.set_health(health)
		# Left-anchored drain: the darkened pip is at the new HP index.
		_health_bar.flash_damage(health)
	if health <= 0:
		die()
		return
	_update_phase()
	current_state = State.PATROL
	state_timer = maxf(1.4, 2.0 - phase * 0.3)
	sprite.color = Color(0.4, 0.25, 0.15, 1.0)
	hitbox.set_deferred("monitorable", false)
	hitbox.set_deferred("monitoring", false)

## Recompute phase from HP ratio; on a new phase, escalate + taunt.
func _update_phase() -> void:
	var ratio := float(health) / float(max_health)
	var new_phase := 1
	# Kimi audit (2026-08-02): with max_health=6, health=2 is exactly 1/3
	# (0.3333...) which float-compares GREATER than the literal 0.33 — phase 3
	# never started at the documented "25%" threshold, only at 1 HP (a one-hit
	# enrage window). Integer comparison is exact, no float rounding involved.
	if health * 3 <= max_health:
		new_phase = 3
	elif ratio <= 0.66:
		new_phase = 2
	if new_phase != phase:
		phase = new_phase
		if _health_bar:
			_health_bar.set_phase(phase)
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
	# Free the bar explicitly: it is a CanvasLayer child, so it would otherwise
	# linger on screen through the whole death tween and the level transition.
	if _health_bar:
		_health_bar.queue_free()
		_health_bar = null
	BossVoiceSystem.say(self, BOSS_ID, "death", true)
	BossVoiceSystem.clear_active()
	GameManager.add_score(500)
	ScreenShake.shake(0.5, 8.0)
	hitbox.set_deferred("monitorable", false)
	hitbox.set_deferred("monitoring", false)
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
	# Lil Blunt's hype bark lands AFTER the announcer's victory line instead of
	# talking over it. 3.3s measured from the real clip (victory.mp3 = 3.13s) —
	# not a guess. The SceneTreeTimer is owned by the tree and the lambda only
	# touches the AudioManager autoload, so this still fires after this boss
	# node frees itself below. 60s cooldown: bosses are rare, never repeat.
	get_tree().create_timer(3.3).timeout.connect(
		func() -> void: AudioManager.play_bark("vo_boss_hype", 60.0))
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
	var hp_before := health
	health -= 2
	AudioManager.play_sfx("damage")
	BossVoiceSystem.say(self, BOSS_ID, "hurt")
	EffectSpawner.burst("explosion", global_position + Vector2(48, 48))
	# This is the SECOND damage path into this boss and it previously skipped
	# the health bar entirely, so a reflected shard silently desynced the
	# display by 2 HP until the next melee hit repainted it (Kimi audit).
	if is_instance_valid(_health_bar):
		_health_bar.set_health(health)
		_health_bar.flash_damage(maxi(health, 0))
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
