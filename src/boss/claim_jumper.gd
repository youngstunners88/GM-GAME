extends BossBase
## Boss 3 — The Claim Jumper (Bandit). Lobs dynamite that lands ON the player's
## position (telegraphed danger zones); phase escalation adds more sticks and
## faster patrol, with increasingly unhinged taunts. Final phase rains dynamite.

const BOSS_ID := "bandit"
const DYNAMITE := preload("res://src/boss/dynamite.tscn")

enum State { PATROL, THROW, VULNERABLE }

## On-screen body size. Mirrored by claim_jumper.tscn's RectangleShape2D.
##
## Founder, this session: "The final boss still is way to small and
## ineffective against Lil Blunt." Confirmed against every other boss's own
## BODY: Auditor 168, Distributor 240, Claim Jumper was 80 — the LAST boss in
## the campaign was visually the SMALLEST of the three by a wide margin.
## Raised to 280, ahead of both, so the final fight reads as the biggest
## threat, which is what "final boss" should mean. sprite_boss_bandit-cart.png
## is fully opaque edge-to-edge (no transparent padding, unlike the other two
## bosses' art) so the hitbox can stay matched to the full body box without
## the trim T3 needed for the Auditor/Distributor.
const BODY := 280.0

## Stage 3 is the LAST boss and must be the hardest. Player top speed is
## walk_speed 200 * SPRINT_MULTIPLIER 1.2 = 240 px/s, and this boss chased at
## 165 in phase 1 and 215 in phase 2 — slower than a running player for two of
## his three phases. That is the whole of the founder's "stage 3 boss is too
## easy": you could not be caught by simply holding run. Every phase now beats
## a sprint, with the gap widening as his health drops.
##
## Raised again this session (255 -> 290 base) alongside the BODY increase —
## founder: "way to small and ineffective". A bigger silhouette with the same
## old speed would just be a slower-feeling boss; pressure has to rise with
## the size, not just the art.
@export var patrol_speed: float = 290.0
@export var throw_cooldown: float = 0.85
## Floor under any chasing state's speed. THROW used to brake him to a dead
## stop, which handed the player a free escape window on every single attack.
const MIN_CHASE_SPEED: float = 280.0

## Damage window after each dynamite throw, shrinking by phase like the other
## two bosses' vulnerable windows. Player DPS is 2.5/s (0.4s axe cooldown);
## against 18 HP that is a 7.2s floor on pure hit-connecting time — Kimi K3's
## exact number, re-derived this session after the founder called the fight
## "too easy to kill". A player who is never gated at all can pay that in one
## unbroken burst from any range; requiring the window makes them earn it.
@export var vulnerable_time: float = 0.9

## Founder, this session: "too easy to kill." Root cause (Kimi K3 TTK
## analysis): `take_damage()` had NO state gate at all — compare
## `auditor.gd`/`distributor.gd`, both of which only accept damage during an
## explicit VULNERABLE window. Worse: `current_state` NEVER actually left
## PATROL in the shipped code — `_throw_dynamite()` reset `throw_timer` and
## spawned dynamite without ever setting `current_state = State.THROW`, so the
## THROW and VULNERABLE branches below (and their handling comments) were
## dead code. A player standing at axe range (2.5 DPS, 0.4s cooldown) could
## kill 18 HP in 7.2s from any state, any range, with zero exposure to his
## only attack — full risk-free damage output. Both bugs fixed together:
## dynamite now actually enters THROW, then a real VULNERABLE window that
## `take_damage()` requires.
var current_state: State = State.PATROL
## Drains every physics frame; drives the THROW commitment and the
## VULNERABLE window's duration (mirrors auditor.gd's/distributor.gd's own
## state_timer convention).
var state_timer: float = 0.0
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
	boss_sprite.size = Vector2(BODY, BODY)
	collision.position = Vector2(BODY / 2.0, BODY / 2.0)
	# SINGLE offset, on the Hitbox node itself — hitbox_shape (the child
	# CollisionShape2D) stays at its tscn default (0,0). Auditor/Distributor
	# both shipped this session with the offset applied TWICE (once on the
	# tscn child, once again here), which shifted their kill zones a full
	# half-body off the visible art (T3's root cause, Kimi K3). This scene's
	# child shape was never given its own tscn offset, so it was never
	# exposed to that bug — keep it that way rather than "fixing" it to match
	# the other two and reintroducing the exact defect just patched there.
	hitbox.position = Vector2(BODY / 2.0, BODY / 2.0)
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

## Half of the body. The origin is the TOP-LEFT, so the centre — the thing
## that actually has to stay inside the arena — is origin + this.
const HALF_BODY: float = BODY / 2.0

func _clamp_to_arena() -> void:
	if arena_max == Vector2.ZERO:
		return
	# Clamp the body CENTRE, inset by half a body, so the whole sprite stays in
	# the arena. Also zero the velocity pushing into the wall, otherwise he
	# accelerates into the clamp every frame and has to unwind a saturated
	# velocity before he can turn around — he reads as stuck.
	var lo_x: float = arena_min.x + HALF_BODY
	var hi_x: float = maxf(lo_x, arena_max.x - HALF_BODY)
	var centre_x: float = global_position.x + HALF_BODY
	var clamped_x: float = clampf(centre_x, lo_x, hi_x)
	if not is_equal_approx(clamped_x, centre_x):
		global_position.x += clamped_x - centre_x
		velocity.x = 0.0
	# Only the FLOOR is clamped, not the ceiling: he hops, and pinning his
	# maximum height would cancel the hop mid-air.
	if global_position.y > arena_max.y:
		global_position.y = arena_max.y
		if velocity.y > 0.0:
			velocity.y = 0.0

## How far PAST HIS OWN TOE he checks for solid ground, and how far down.
##
## Deliberately a margin past the toe, not a total distance from the body
## centre. It used to be measured from centre (56px, tuned against the old
## 80px BODY's 40px HALF_BODY — i.e. 16px past that toe). When BODY grew to
## 280 this session, HALF_BODY grew to 140 and a still-centre-relative 56px
## probe landed 84px INSIDE his own torso, never reaching the real edge at
## all — he walked straight off ledges he used to correctly hold at (caught
## by tests/stage3_defence_test.gd's real-physics gate, not by inspection).
## Measuring from the toe instead means a future BODY resize can't silently
## repeat this.
const LEDGE_PROBE_MARGIN: float = 16.0
const LEDGE_PROBE_DROP: float = 120.0

## True when there is NO floor ahead in `facing` — i.e. the next step walks off
## a ledge. Belt and braces alongside the arena clamp: the clamp stops him
## leaving the arena box, this stops him walking into a pit INSIDE it.
func _ledge_ahead(facing: float) -> bool:
	var space := get_world_2d().direct_space_state
	# Cast from just above his feet, ahead of the body, straight down. Body is
	# BODYxBODY with its ORIGIN AT THE TOP-LEFT (collision sits at +HALF_BODY),
	# so the feet are at origin.y + BODY and the centre at origin.x + HALF_BODY.
	var foot_y: float = global_position.y + BODY
	var toe_x: float = global_position.x + HALF_BODY + HALF_BODY * facing
	var from := Vector2(toe_x + LEDGE_PROBE_MARGIN * facing, foot_y - 8.0)
	var params := PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, LEDGE_PROBE_DROP))
	# World geometry only (layer 1) — never treat the player or a pickup as floor.
	params.collision_mask = 1
	params.exclude = [get_rid()]
	return space.intersect_ray(params).is_empty()

## Horizontal reach of one hop. HOP_VELOCITY -620 against gravity 980 is ~1.26s
## of airtime; even at phase-1 speed (255) that is ~321px. Deliberately probed
## SHORT of the true maximum so he only commits to a landing he can comfortably
## make — the chase speed-ups above only widen that safety margin, they never
## narrow it, so this stays correct without re-tuning.
const HOP_REACH: float = 300.0

## True when there IS ground to land on across the gap ahead.
##
## Without this the ledge sense made things WORSE, not better: spotting a ledge
## triggered the hop, and the hop then carried him over the edge and into the
## void anyway — the test caught him at y=2242 with the floor at 600. A gap is
## only worth jumping if something is waiting on the other side.
func _gap_crossable(facing: float) -> bool:
	var space := get_world_2d().direct_space_state
	var foot_y: float = global_position.y + BODY
	for dist: float in [140.0, 200.0, 260.0, HOP_REACH]:
		# Probe from within the HOP ENVELOPE, not just at foot level. HOP_VELOCITY
		# -620 vs gravity 980 clears ~196px of rise, so ground HIGHER than his
		# feet (a raised ledge — exactly where a player standing above him is) is
		# reachable. The old probe started at foot_y-8 and only cast DOWN 120px,
		# so any higher landing read as "uncrossable"; PATROL then hopped
		# straight up in place forever (Kimi K3, session 4: the "only jumps
		# directly up / doesn't advance" bug). Starting 190px up and casting 310px
		# down sees both higher ledges and same-level ground within one hop.
		var from := Vector2(global_position.x + HALF_BODY + dist * facing, foot_y - 190.0)
		var params := PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, 310.0))
		params.collision_mask = 1
		params.exclude = [get_rid()]
		if not space.intersect_ray(params).is_empty():
			return true
	return false

## One frame of grounded pursuit at `speed` px/s. Returns true if he is standing
## at a ledge lip and has refused to take the step.
##
## Extracted so PATROL and THROW share ONE chase implementation. They used to
## have two: PATROL stalked, THROW braked to zero — which meant every attack
## handed the player an escape window, and any future fix to the ledge sense
## would have had to be made twice.
func _ground_chase(delta: float, speed: float) -> bool:
	# STALK the live player rather than pacing wall to wall. The founder's "the
	# bosses need to be more challenging" applies here too: this boss only ever
	# bounced between walls, so a player who stood still was never approached.
	#
	# Compared CENTRE to player, not origin to player: the origin is the body's
	# top-left, so an origin-based comparison biased every decision 40px east
	# and made him oscillate around a point he was never actually on.
	var pl := get_tree().get_first_node_in_group("player")
	if pl:
		var dx: float = pl.global_position.x - (global_position.x + HALF_BODY)
		if absf(dx) > TURN_DEAD_ZONE:
			direction = signf(dx)
	# Ease into the target speed so he reads as heavy, not robotic.
	var target_vx: float = speed * direction
	var rate: float = (TURN_DECEL
		if signf(target_vx) != signf(velocity.x) and not is_zero_approx(velocity.x)
		else WALK_ACCEL)
	velocity.x = move_toward(velocity.x, target_vx, rate * delta)
	# LEDGE SENSE. Standing on solid ground with a drop directly ahead, he
	# refuses to take the step — he holds the lip instead of walking into the
	# void. Only while GROUNDED, so a hop across a gap is never cancelled
	# mid-air. Founder explicitly asked that this NOT regress.
	var at_ledge := false
	if is_on_floor() and not is_zero_approx(target_vx):
		at_ledge = _ledge_ahead(signf(target_vx))
		if at_ledge:
			velocity.x = 0.0
	velocity.y += 980.0 * delta
	move_and_slide()
	_clamp_to_arena()
	# Facing is handled every frame in _physics_process now (see below), NOT
	# here — this gated update froze his facing whenever velocity.x hit ~0 (at a
	# ledge, the arena clamp, or a braking state), leaving his back to a player
	# standing beside him (founder session 4). Kept the return; dropped the flip.
	return at_ledge

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# FACE THE PLAYER EVERY FRAME, regardless of velocity. The bandit-cart art
	# faces right natively (art_faces_right defaults true, verified against the
	# sprite), so this is purely about WHEN facing updates: gating it on
	# |velocity.x|>12 meant a stopped boss kept his stale facing and showed his
	# back. Founder: "why is his back facing Lil Blunt?" — this is the fix.
	var pl_face := get_tree().get_first_node_in_group("player")
	if pl_face:
		var fdx: float = pl_face.global_position.x - (global_position.x + HALF_BODY)
		if absf(fdx) > TURN_DEAD_ZONE:
			boss_sprite.set_facing(fdx > 0.0)

	throw_timer -= delta
	_hop_cooldown -= delta
	state_timer -= delta

	match current_state:
		State.PATROL:
			var pl := get_tree().get_first_node_in_group("player")
			var at_ledge: bool = _ground_chase(delta, patrol_speed)
			# Blocked by terrain, or the player is above him -> hop. A ledge now
			# also triggers the hop: if the player is across a gap he JUMPS it
			# rather than standing at the edge forever, which keeps him
			# threatening instead of merely safe.
			if is_on_floor() and _hop_cooldown <= 0.0:
				# A ledge only justifies a hop when there is somewhere to LAND.
				# Otherwise he holds the lip: still blocking the arena, never
				# suiciding into the void.
				var want_hop := is_on_wall() or (at_ledge and _gap_crossable(direction))
				# Player above -> hop ONLY if there's actually reachable ground
				# that way. Without the _gap_crossable gate this fired
				# unconditionally, and since the old _gap_crossable couldn't see
				# higher ledges it also left vx=0 — so he hopped straight up in
				# place forever instead of advancing (Kimi K3, session 4).
				if pl and pl.global_position.y < global_position.y - 80.0 and _gap_crossable(direction):
					want_hop = true
				if want_hop:
					velocity.y = HOP_VELOCITY
					# COMMIT FORWARD on the hop. _ground_chase zeroes velocity.x at
					# a ledge lip, so without re-injecting horizontal speed here the
					# hop is purely vertical (straight up, no progress). Airborne
					# frames skip the ledge sense and _gap_crossable already
					# confirmed a landing, so this carries him toward the player
					# instead of hopping in place.
					velocity.x = patrol_speed * direction
					_hop_cooldown = 0.7
			if throw_timer <= 0:
				_throw_dynamite()

		State.THROW:
			# He KEEPS COMING while he winds up and throws. Braking to a dead
			# stop here gave the player a guaranteed free gap on every attack,
			# so the fight was a series of safe windows joined by short chases.
			# Slower than patrol so the throw still reads as a commitment, but
			# never below a sprint.
			_ground_chase(delta, maxf(patrol_speed * 0.72, MIN_CHASE_SPEED))
			if state_timer <= 0.0:
				_begin_vulnerable()

		State.VULNERABLE:
			velocity.x = move_toward(velocity.x, 0.0, 150.0 * delta * 60.0)
			velocity.y += 980.0 * delta
			move_and_slide()
			_clamp_to_arena()
			boss_sprite.modulate = Color(1.0, 0.3, 0.3, 1.0) if fmod(state_timer, 0.2) < 0.1 else Color(1.0, 0.1, 0.1, 1.0)
			if state_timer <= 0.0:
				_end_vulnerable()

## Opens the real damage window (`take_damage()` requires this state). Shrinks
## per phase like the other two bosses' windows — less free damage time as
## the rest of the fight escalates, same convention as auditor.gd.
func _begin_vulnerable() -> void:
	current_state = State.VULNERABLE
	state_timer = maxf(0.6, vulnerable_time - 0.15 * (current_phase - 1))

## Shared exit — the timeout path is the only path today, but kept as its own
## function (matching distributor.gd's _end_vulnerable convention) so a future
## "hit ends the window early" change has one place to land, not two.
func _end_vulnerable() -> void:
	current_state = State.PATROL
	boss_sprite.modulate = Color(1, 1, 1, 1)
	# The chase-cooldown for his NEXT dynamite throw starts now, not when this
	# throw was launched — see _throw_dynamite()'s comment for why.
	throw_timer = maxf(0.8, throw_cooldown - 0.3 * (current_phase - 1))

## Accelerate patrol + taunt on phase transition (BossBase calls this).
func _on_phase_changed() -> void:
	# Raised again this session alongside BODY and the base speed — founder:
	# "way to small and ineffective". 300/345 were the old phase 2/3 values;
	# every phase now clears a sprint (240 px/s) by an even wider margin.
	if current_phase >= 2:
		patrol_speed = 335.0
		BossVoiceSystem.say(self, BOSS_ID, "phase50", true)
	if current_phase >= 3:
		patrol_speed = 385.0
		BossVoiceSystem.say(self, BOSS_ID, "phase25", true)
		ScreenShake.medium()

## Lob dynamite so it lands on the player's position — a telegraphed blast
## zone. Phase 1: 1 stick. Phase 2: 2. Phase 3: 3 spread around the player.
##
## explosion_delay now shrinks with phase (still telegraphed — never below a
## dodgeable 1.3s — but tighter each phase) alongside throw_cooldown's own
## phase scaling, so the barrage genuinely intensifies rather than just
## adding more sticks at the same leisurely fuse.
func _throw_dynamite() -> void:
	# Actually enters THROW now (see the field comments above `current_state`
	# — it never did before). The chase-cooldown reset moves to
	# `_end_vulnerable()`, not here: THROW's 0.4s commitment plus the
	# VULNERABLE window both drain unconditionally every frame regardless of
	# state, so resetting `throw_timer` here would let the next attack fire
	# again mid-window on short cycles — vulnerable almost back-to-back
	# instead of a real chase-then-opening rhythm.
	current_state = State.THROW
	state_timer = 0.4
	var p := get_tree().get_first_node_in_group("player")
	var target := global_position + Vector2(120 * (1.0 if direction > 0 else -1.0), -60)
	if p:
		target = p.global_position + Vector2(0, -80)
	var count: int = [0, 1, 2, 3][current_phase]
	var delay: float = maxf(1.3, 2.0 - 0.35 * (current_phase - 1))
	for i in range(count):
		var dyn := DYNAMITE.instantiate()
		dyn.global_position = target + Vector2((i - float(count - 1) / 2.0) * 70.0, 0)
		dyn.explosion_delay = delay
		get_parent().add_child(dyn)
	AudioManager.play_sfx("throw")

func take_damage(amount: int) -> void:
	if is_dead or current_state != State.VULNERABLE:
		return
	health -= amount
	AudioManager.play_sfx("damage")
	BossVoiceSystem.say(self, BOSS_ID, "hurt")
	# Tween `boss_sprite`, NOT the inherited `sprite` — EnemyBase resolves
	# `sprite` via get_node_or_null("Sprite") and this boss's scene has no
	# such child (its art is the BossSprite on "ColorRect"), so `sprite` is
	# null here and this tween silently no-op'd on every hit: a landed blow
	# never actually flashed. Same bug, same fix distributor.gd already
	# needed (Kimi audit, last session) — found while wiring the real
	# vulnerable-window feedback this session.
	var tween := create_tween()
	tween.tween_property(boss_sprite, "modulate", Color(4.0, 0.25, 0.25, 1), 0.05)
	tween.tween_property(boss_sprite, "modulate", Color(1, 1, 1, 1), 0.05)
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
