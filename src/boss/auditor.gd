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

## SPAWN GRACE — a real-browser capture caught the Auditor's own hitbox
## restarting the run within ~1s of a fight starting, before any scripted
## attack, from the opening close-the-gap sweep. Other bosses in this file's
## own history already carried this fix (mirrored from boss_base.gd's
## rationale), but master never had it wired for the Auditor specifically —
## and the BODY increase to 220 (see below) made his hitbox reach further,
## raising the odds of an instant spawn-contact restart being mistaken for
## "the boss won't let me get past this point" (2026-08-18, "Almost_Better"
## residual — a live capture showed the level reloading 3x in the first few
## seconds of a boss=1 warp, which is exactly this).
const SPAWN_GRACE_SEC: float = 1.2
var _spawn_grace_until_msec: int = 0

func _enter_tree() -> void:
	_spawn_grace_until_msec = Time.get_ticks_msec() + int(SPAWN_GRACE_SEC * 1000.0)

func is_spawn_grace_active() -> bool:
	return Time.get_ticks_msec() < _spawn_grace_until_msec
## On-screen body size. Mirrored by auditor.tscn's RectangleShape2D — change
## both together, and keep the collision offset at BODY/2.
##
## Founder (LEVEL1_MUSIC_ORDER_BOSS1_SIZE_CARTS_CHASE, 2026-08-18): "1st boss
## ... has been reduced in size — restore previous larger scale. WHY was it
## shrunk?" No code-level regression against this session's own prior work
## was found (BODY has read 168 across this file's entire git history), but
## the founder's own comparison point is real: Distributor (Stage 2) is 240,
## Claim Jumper (Stage 3) is 280 — Auditor was visibly the smallest of the
## three despite being fought FIRST, which reads exactly as "shrunk" against
## the bosses that follow. Raised to 220 (still smallest of the three, so
## the difficulty-scale identity across stages is untouched, but no longer
## an outlier). HURTBOX_SIZE/CENTER below are scaled by the same 220/168
## ratio to preserve the exact fit this file's own hard-won double-offset
## fix (see below) depends on — do not hand-tune them independently of BODY.
const BODY := 220.0
## Hurtbox matches the scaled OPAQUE silhouette of sprite_boss_tax-collector.png,
## not the full BODY box. Source is 131x150 with opaque bbox (7,0)-(127,143);
## BossSprite._fit() scales it by BODY/150 to fill the body height, so
## the real on-screen character is centered off the body box's own centre
## (BODY/2, BODY/2). Values below = the original 134x160 / (86,80) at
## BODY=168, scaled by 220/168.
##
## Founder, an earlier session: "Lil Blunt will die completely without even
## touching the boss for some reason." Root cause (Kimi K3, verified by hand
## against this scene): the hitbox was double-offset. auditor.tscn already
## positions Hitbox/CollisionShape2D at (84,84) LOCAL TO THE HITBOX NODE, and
## _ready() below used to ALSO move the Hitbox Area2D itself to (84,84) —
## stacking both offsets moved the shape's true centre to (168,168), a full
## half-body diagonally off the visible sprite. The kill zone spanned
## x/y 84..252 while the art only occupies roughly 0..168: ~99px of lethal
## air past the boss's right/bottom edge, while his left/top half could be
## stood inside with no death at all — asymmetric and facing-independent,
## exactly matching "for some reason" and "dies without even touching him".
const HURTBOX_SIZE := Vector2(175.5, 209.5)
const HURTBOX_CENTER := Vector2(112.6, 104.8)
const CLIPBOARD := preload("res://src/boss/boss_projectile.tscn")

## CYCLE-MEAN PURSUIT SPEED, not just the PATROL number.
##
## Kimi K3 (2026-08-19) did for this boss the arithmetic distributor.gd's
## MIN_PURSUE_SPEED comment already does for boss 2, and which nobody had ever
## done for boss 1. The player's top speed is walk_speed 200 * SPRINT 1.2 =
## 240 px/s, and the Auditor's phase-1 cycle is:
##
##   PATROL      2.5 s at patrol_speed
##   CHARGE      1.4 s at charge_speed (430)
##   VULNERABLE  1.1 s at VULNERABLE_DRIFT
##
## At the old 140/120 that is (2.5*140 + 1.4*430 + 1.1*120) / 5.0 = **217 px/s**
## — BELOW a held sprint. A player who simply ran was never caught in phase 1,
## no matter how correct the pursuit logic was, which is the other half of
## "the 1st boss cant get passed this point": he is not only mis-steering, he
## is too slow on average to close.
##
## 235/170 gives (2.5*235 + 1.4*430 + 1.1*170) / 5.0 = **275 px/s**, ~15% over
## a sprint, so he gains ground across a full cycle instead of losing it.
## charge_speed and every state DURATION are untouched, so the fight's rhythm
## and its fair damage window are unchanged — only the average closing rate.
## Phase scaling still multiplies this (see _on_phase_changed).
@export var patrol_speed: float = 235.0
@export var charge_speed: float = 430.0
@export var vulnerable_time: float = 1.1
@export var max_health: int = 10

var current_state: State = State.PATROL
var health: int = 10
var patrol_direction: float = 1.0
var charge_target: Vector2 = Vector2.ZERO
var state_timer: float = 0.0
var throw_timer: float = 2.0
var hop_timer: float = 6.0
var phase: int = 1
var _base_patrol_speed: float = 90.0
## Gate on the leap so he arcs instead of vibrating against a wall every frame.
var _leap_cooldown: float = 0.0
## Clears ~196px at gravity 980 — enough for this project's real ledge heights.
const LEAP_VELOCITY: float = -620.0
## PLATFORM INTELLIGENCE (founder, 2026-08-20): "He is now stuck here as he
## tries jumping up and down and hitting his head on the platform!!!! Give him
## more intelligence to use the block to launch himself over the platform or to
## double jump!"
##
## Root cause: he only ever leapt FROM THE FLOOR, and one leap clears ~196px
## (LEAP_VELOCITY -620 against gravity 980). A terrace higher than that is
## unreachable, so the "player is above me" rule below fired every 0.9s
## forever, each time driving his head into the same platform underside. He had
## no second option and no memory that the attempt had failed.
##
## Two additions, deliberately the ones the founder asked for:
##   AIR JUMP — one mid-air leap, armed on take-off and spent only while
##       ASCENDING TOWARD a player who is still above him. Stacked on the first
##       leap it clears roughly 196 + 196 = ~390px, which covers every terrace
##       in the campaign.
##   CEILING SIDESTEP — if he does clip a platform underside, he stops shoving
##       upward into it and commits to a horizontal search for a gap for
##       CEILING_SIDESTEP_SEC. That is what stops the head-banging LOOP; the
##       air jump is what gets him up once he finds the gap.
const AIR_JUMP_VELOCITY: float = -560.0
## Long enough to clear a real platform at patrol speed: 1.2s * 235px/s = 282px,
## and the campaign's terraces are ~150-300px wide. At the first attempt's 0.7s
## he only made 164px per try and the direction kept flipping, so he oscillated
## around the player's column and netted 123px in 7s — measured, not guessed.
const CEILING_SIDESTEP_SEC: float = 1.2
var _air_jump_ready: bool = false
var _ceiling_sidestep: float = 0.0
## Direction LOCKED for the duration of a sidestep. Without it, patrol_direction
## is recomputed from the player's bearing every frame, so a player standing
## directly above kept reversing him into the blocked column — the head-banging
## simply became head-banging while shuffling.
var _sidestep_dir: float = 1.0

## Which way is the nearer edge of the thing blocking him overhead?
##
## Casts upward at increasing offsets each side and returns the direction of the
## first probe that finds open sky. Falls back to his current heading, so a
## fully-enclosed boss still commits to something rather than dithering.
func _ceiling_escape_dir() -> float:
	var space := get_world_2d().direct_space_state
	var head_y: float = global_position.y + 8.0
	for dist: float in [120.0, 220.0, 320.0, 420.0]:
		for dir: float in [1.0, -1.0]:
			var from := Vector2(global_position.x + BODY / 2.0 + dist * dir, head_y)
			var params := PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, -260.0))
			params.collision_mask = 1
			params.exclude = [get_rid()]
			if space.intersect_ray(params).is_empty():
				return dir
	return signf(patrol_direction) if not is_zero_approx(patrol_direction) else 1.0
## Motion-feel constants (founder: "smoother, less robotic" — capability
## unchanged). Accel is ~4x patrol speed so he still reaches full pace in
## about a quarter second; the harder turn figure keeps direction changes
## crisp rather than floaty.
const WALK_ACCEL: float = 560.0
const TURN_DECEL: float = 1300.0
## Horizontal slack before he commits to a new facing, in px.
const TURN_DEAD_ZONE: float = 34.0
## Speed he keeps while VULNERABLE — half a sprint (player top speed is 240),
## so his damage window is the slowest he ever gets without being a dead stop.
## Mirrors distributor.gd's and claim_jumper.gd's constants of the same name;
## this boss was the only one of the three still hard-braking to zero there.
## See the VULNERABLE branch in _physics_process for the measured symptom.
const VULNERABLE_DRIFT: float = 170.0
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
	# Founder: "Make the Auditor MUCH BIGGER — in fact you have REDUCED his
	# size!!!" 168 vs the old 96 is a 1.75x linear / ~3x area increase. This
	# MUST stay in lockstep with auditor.tscn's RectangleShape2D (168x168) and
	# the collision/hitbox offsets (size/2 = 84) or the art and hurtbox drift.
	sprite.size = Vector2(BODY, BODY)
	collision.position = Vector2(BODY / 2.0, BODY / 2.0)
	# Hitbox stays at the boss's own origin (0,0) — auditor.tscn's
	# Hitbox/CollisionShape2D child already carries the (86,80) offset itself.
	# Setting hitbox.position here too was the double-offset bug (see
	# HURTBOX_SIZE's comment above): DO NOT re-add an offset on this node.
	#
	# Own, distinct shape — NOT `collision.shape`. Sharing one RectangleShape2D
	# resource between the hurtbox and the physical body collider means
	# resizing the hurtbox to the art's silhouette would also shrink the
	# body's real collision, breaking is_on_wall()/is_on_floor() leap triggers.
	var hurt_shape := RectangleShape2D.new()
	hurt_shape.size = HURTBOX_SIZE
	hitbox_shape.shape = hurt_shape
	hitbox_shape.position = HURTBOX_CENTER
	# WALK THROUGH THE PLAYER'S EASTER-EGG WALLS.
	#
	# Founder: "The 1st boss also doesnt move anymore even though he used to
	# chase Lil Blunt". Level 1 deliberately has NO arena seal — this fight is a
	# full-stage hunt by explicit founder request — so nothing was supposed to
	# stop him. Measured instead, with the player parked at the arena's west edge
	# (x=2830): the Auditor hard-stopped at centre x=2905 and never closed the
	# last 75px.
	#
	# The blocker is a `secret_wall` at x=2768 (level_01_smoke_realm.gd places
	# three: 468, 1368, 2768). It is a 32px StaticBody2D on collision_layer 1
	# (World), and this boss's collision_mask is 13, which includes World — so his
	# 220px body jams against it: 2784 (the wall's east face) + 110 (half body) =
	# 2894, matching the 2905 measured. A hidden pickaxe-breakable easter egg was
	# caging the boss out of the western half of the stage.
	#
	# Collision EXCEPTIONS rather than layer surgery: the wall must keep blocking
	# the PLAYER (that is its whole purpose, and its layer is also how the pickaxe
	# smash path finds it), so the only thing that changes is that this boss
	# ignores it. A wall freed later (smashed) drops out of the list harmlessly.
	for w in get_tree().get_nodes_in_group("secret_wall"):
		if w is CollisionObject2D:
			add_collision_exception_with(w)
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	hitbox.area_entered.connect(_on_hitbox_area_entered)
	# CONTACT DETECTION STAYS ON FOR THE WHOLE FIGHT.
	#
	# Founder, several times over: "the moment he touches Lil Blunt the stage
	# needs to restart as Lil Blunt has died." This boss gated `monitoring`
	# to its vulnerable window, which turns this Area2D OFF for roughly 80%
	# of the fight — `body_entered` never fires, so the player walks straight
	# through the boss and nothing happens. That is the whole reported bug:
	# the restart logic was correct, it was simply never reached.
	#
	# Incoming DAMAGE is gated by `monitorable` instead (player attacks detect
	# the boss, not the reverse) plus take_damage()'s own vulnerable-state
	# check, so leaving detection on costs nothing and is what makes contact
	# actually end the run.
	hitbox.monitoring = true
	hitbox.monitorable = false
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
	_leap_cooldown -= delta

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
			# Stalk the live player across the full level instead of bouncing
			# wall-to-wall. If no player is found fall back to the old bounce.
			var _pl := get_tree().get_first_node_in_group("player")
			if _pl:
				# Dead zone: only re-commit once the player is properly to one
				# side, otherwise he vibrates when they stand over him.
				# Explicitly typed: _pl comes from get_first_node_in_group(),
				# which returns Node, so `.global_position.x` is a Variant and
				# `:=` is a HARD parse error in Godot 4.3.
				var dx: float = _pl.global_position.x - global_position.x
				if absf(dx) > TURN_DEAD_ZONE:
					var stalk_dir := signf(dx)
					patrol_direction = stalk_dir
			# Ease toward the target speed instead of snapping to it. Turning
			# round brakes harder than setting off, which reads as weight.
			var target_vx := patrol_speed * patrol_direction
			var rate: float = (TURN_DECEL if signf(target_vx) != signf(velocity.x)
				and not is_zero_approx(velocity.x) else WALK_ACCEL)
			velocity.x = move_toward(velocity.x, target_vx, rate * delta)
			velocity.y += 980.0 * delta
			move_and_slide()
			# Follow committed motion, not the raw player delta, so the sprite
			# cannot strobe while he is turning around.
			if absf(velocity.x) > 12.0:
				sprite.set_facing(velocity.x > 0.0)
			# Blocked by terrain -> LEAP. 196px of clearance vs the old 59px.
			if is_on_wall() and is_on_floor() and _leap_cooldown <= 0.0:
				velocity.y = LEAP_VELOCITY
				_leap_cooldown = 0.55
				_air_jump_ready = true
			# He also hops when the player is well above him, so he pursues up
			# the stage's terraces instead of pacing along the bottom of them.
			if _pl and is_on_floor() and _leap_cooldown <= 0.0 \
					and _pl.global_position.y < global_position.y - 90.0 \
					and _ceiling_sidestep <= 0.0:
				velocity.y = LEAP_VELOCITY
				_leap_cooldown = 0.9
				_air_jump_ready = true
			# CEILING SIDESTEP — he just drove his head into a platform.
			# Kill the upward push (shoving into a ceiling is what produced the
			# jitter the founder filmed) and commit to travelling sideways for a
			# moment so he actually hunts for the edge instead of retrying the
			# same blocked column.
			if is_on_ceiling():
				velocity.y = maxf(velocity.y, 0.0)
				_ceiling_sidestep = CEILING_SIDESTEP_SEC
				_air_jump_ready = false
				# Commit to the nearer OPEN side, not to the player. The player
				# is usually straight above the thing blocking him, so steering
				# at them is what kept him in the blocked column.
				_sidestep_dir = _ceiling_escape_dir()
			if _ceiling_sidestep > 0.0:
				_ceiling_sidestep -= delta
				velocity.x = patrol_speed * _sidestep_dir
				sprite.set_facing(_sidestep_dir > 0.0)
			# AIR JUMP — the second half of the leap, spent only while still
			# rising toward a player who remains above him. Gated on
			# `_air_jump_ready` (armed at take-off, cleared on use and on any
			# ceiling contact) so it can never become an infinite hover.
			elif _air_jump_ready and not is_on_floor() and _pl \
					and velocity.y > -120.0 \
					and _pl.global_position.y < global_position.y - 60.0:
				velocity.y = AIR_JUMP_VELOCITY
				_air_jump_ready = false
			if is_on_floor():
				_air_jump_ready = false
			# Ranged pressure — cadence tightens per phase.
			if throw_timer <= 0.0:
				throw_timer = [0.0, 2.6, 2.0, 1.4][phase]
				_throw_clipboard()
			# Occasional reposition hop.
			if hop_timer <= 0.0:
				hop_timer = 6.0 if phase < 3 else 3.5
				velocity.y = -300.0
				# THE HOP NO LONGER THROWS HIM BACKWARDS.
				#
				# This used to blend toward `-patrol_direction * 150.0` — i.e.
				# AWAY from the side he is currently chasing. Since
				# `patrol_direction` is set from the player's bearing in PATROL,
				# that meant every 6 s (3.5 s in phase 3) he deliberately hopped
				# away from Lil Blunt. Grok 4.6 flagged it as sufficient on its
				# own to drive a NEGATIVE tracking score, which is exactly what
				# instrumentation measured (-0.20: moving opposite the player
				# more often than with them).
				#
				# It stays a reposition — a vertical skip that sheds some
				# horizontal speed so it reads as a hop rather than a sprint —
				# but it no longer reverses his pursuit. Damping to 45% of
				# current velocity keeps the "skip" feel the original comment
				# wanted without the retreat.
				velocity.x = velocity.x * 0.45
			if state_timer <= 0.0:
				state_timer = 1.4
				current_state = State.CHARGE
				var p := get_tree().get_first_node_in_group("player")
				if p:
					charge_target = p.global_position

		State.CHARGE:
			# RE-READ THE LIVE PLAYER EVERY FRAME. `charge_target` used to be a
			# snapshot taken once on entry to CHARGE (see the PATROL branch
			# above) and never refreshed, so a 1.4 s charge against a player
			# sprinting at 240 px/s arrived up to ~336 px behind where they now
			# were — and if they had reversed past him, he charged AWAY from
			# them. Instrumentation caught this as a NEGATIVE tracking score
			# (-0.20: he moved opposite the player more often than with them)
			# while both other bosses scored +0.4..+0.8 on the same harness.
			# That is the founder's "the 1st boss cant get passed this point":
			# he commits to stale ground, then re-commits to stale ground.
			#
			# This is a re-aim, not a homing missile: he still only steers with
			# `charge_speed` for a bounded `state_timer`, and the repo's own
			# boss-chase rule ("re-read the LIVE player position every frame,
			# never a stale snapshot") is what he was violating.
			var live := get_tree().get_first_node_in_group("player")
			if live:
				charge_target = (live as Node2D).global_position
			# AIM FROM THE BODY CENTRE, AND STEER ON THE HORIZONTAL DELTA ONLY.
			# Two further defects found by Grok 4.6 reviewing this file:
			#
			#  1. `global_position` is this node's TOP-LEFT (collision sits at
			#     +BODY/2), so charging "at" the player from the origin biased
			#     every charge ~110 px EAST of where he visibly is.
			#  2. `direction_to()` returns a 2D-NORMALIZED vector, so the
			#     horizontal component was scaled down by the vertical gap: a
			#     player standing above him (he leaps when they are >90 px up)
			#     could shrink dir.x toward zero, making a full-commitment
			#     charge crawl horizontally — or, combined with (1), point the
			#     wrong way entirely.
			#
			# Steering on signf(dx) from the centre gives a charge that always
			# commits at full `charge_speed` toward the player's actual side.
			# The charge is still bounded by `state_timer` and still ends on a
			# wall, so this makes it correct, not unfair.
			var centre_x: float = global_position.x + BODY / 2.0
			var cdx: float = charge_target.x - centre_x
			velocity.x = signf(cdx) * charge_speed if absf(cdx) > TURN_DEAD_ZONE else 0.0
			velocity.y += 980.0 * delta
			move_and_slide()
			if state_timer <= 0.0 or is_on_wall():
				state_timer = vulnerable_time
				current_state = State.VULNERABLE
				sprite.color = Color(1.0, 0.2, 0.2, 1.0)
				hitbox.monitorable = true

		State.VULNERABLE:
			# HE KEEPS CLOSING WHILE EXPOSED — the same fix distributor.gd
			# (VULNERABLE_DRIFT) and claim_jumper.gd already carry, which the
			# Auditor never received.
			#
			# The old line was `move_toward(velocity.x, 0.0, 200.0)` — note the
			# MISSING `* delta`. move_toward's third argument is a per-call
			# delta, so at 60 fps that bled 200 px/s of speed EVERY FRAME
			# (12000 px/s^2): he did not decelerate, he stopped dead within two
			# frames and then stood perfectly still for the whole window.
			# Instrumentation caught him parked at exactly x=3030.0 and x=3280.0
			# with vx=0.000 for seconds at a time — the literal "cant get passed
			# this point" the founder screenshotted.
			#
			# He now drifts toward the player at half a sprint (player top speed
			# is 240 px/s), so the damage window is still the slowest he ever
			# gets and still clearly readable, but it is no longer a free escape
			# — and, critically, it is no longer a dead stop at a fixed
			# coordinate.
			var vuln_target := get_tree().get_first_node_in_group("player")
			var drift_dir := 0.0
			if vuln_target:
				var vdx: float = (vuln_target as Node2D).global_position.x - (global_position.x + BODY / 2.0)
				if absf(vdx) > TURN_DEAD_ZONE:
					drift_dir = signf(vdx)
			velocity.x = move_toward(velocity.x, VULNERABLE_DRIFT * drift_dir, WALK_ACCEL * delta)
			velocity.y += 980.0 * delta
			move_and_slide()
			sprite.modulate = Color(1.0, 0.3, 0.3, 1.0) if fmod(state_timer, 0.3) < 0.15 else Color(1.0, 0.1, 0.1, 1.0)
			if state_timer <= 0.0:
				sprite.modulate = Color(1, 1, 1, 1)
				sprite.color = Color(0.4, 0.25, 0.15, 1.0)
				current_state = State.PATROL
				state_timer = maxf(1.4, 3.0 - phase * 0.5)
				hitbox.monitorable = false

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
		proj.global_position = global_position + Vector2(BODY / 2.0, BODY * 0.42)
		get_parent().add_child(proj)
	AudioManager.play_sfx("throw")

func take_damage(amount: int) -> void:
	if current_state == State.DEFEATED or current_state != State.VULNERABLE:
		return
	var hp_before := health
	health -= amount
	AudioManager.play_sfx("damage")
	BossVoiceSystem.say(self, BOSS_ID, "hurt")
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(4.0, 0.25, 0.25, 1), 0.05)
	tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.05)
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
	hitbox.monitorable = false

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
		shard.global_position = global_position + Vector2(BODY / 2.0, BODY * 0.21 + offset)
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
				and shard.global_position.distance_to(global_position + Vector2(BODY / 2.0, BODY / 2.0)) < BODY * 0.58:
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
		shard.set_meta("dir", shard.global_position.direction_to(global_position + Vector2(BODY / 2.0, BODY / 2.0)))
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
	EffectSpawner.burst("explosion", global_position + Vector2(BODY / 2.0, BODY / 2.0))
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
		# SPAWN GRACE — see this file's own const block above.
		if is_spawn_grace_active():
			# GRACE SWALLOWS THE ENTRY EVENT — RE-CHECK WHEN IT EXPIRES.
			#
			# `body_entered` fires exactly ONCE, on the frame the player first
			# overlaps. Returning outright during spawn grace therefore did not
			# DELAY the contact, it CANCELLED it: a player still standing inside
			# the boss when grace ended was permanently immune to him, because no
			# second entry event ever arrives while they remain inside. Caught by
			# tests/boss_ghost_death_hurtbox_test.gd.
			#
			# Waiting out the remaining grace and then re-testing the REAL overlap
			# keeps the intent (no instant wipe at spawn) without the loophole.
			# Both nodes are re-validated after the wait since the scene can change.
			var remaining: float = float(_spawn_grace_until_msec - Time.get_ticks_msec()) / 1000.0
			if remaining > 0.0:
				await get_tree().create_timer(remaining, true, false, true).timeout
			if not is_instance_valid(self) or not is_instance_valid(body):
				return
			if not is_instance_valid(hitbox) or not hitbox.overlaps_body(body):
				return
		GameManager.last_damage_source = BOSS_ID
		BossVoiceSystem.say(self, BOSS_ID, "mock")
		# Founder stakes rule: ANY boss touch returns Lil Blunt to the START of
		# the level, regardless of remaining lives — not hurt-and-continue.
		# See GameManager.boss_contact_restart().
		GameManager.boss_contact_restart()

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("projectile"):
		take_damage(1)
