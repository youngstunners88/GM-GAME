extends BossBase
## Boss 2 — The Distributor (Crystalline Bureaucrat). A bloated crystal golem
## surfing a diamond board, hoarding three ETH reward orbs he refuses to share
## (the DIAMONDS protocol's three payout pools).
##
## Design: Grok 4.5 brief, docs/model-responses/2026-07-30-grok-distributor-spectacle.md.
##
## Three systems carry the fight, none of them copied from the other bosses:
##   HOARD GRAVITY  — a telegraphed radial PULL field (not a dash, which is
##                    what both other bosses already do). Forces repositioning
##                    and punishes standing still.
##   FORCED DISTRIBUTION — every orb spawns with a brief unstable window; a
##                    player attack inside it flips the orb back for damage
##                    OUTSIDE the vulnerable state. Redirect a whole volley to
##                    trigger POOL DRAIN. This is the fight's signature.
##   TOKEN SPECTACLE — player-favourable only. A non-holder fights EXACTLY the
##                    base fight; nothing here gates content or adds difficulty.
##
## HISTORY, so this cannot quietly happen again: commit 2992000 ("boss facing,
## quit button, lives cap...") rewrote this file wholesale as collateral to a
## sprite-facing fix and cut it from 121 lines to 20 — deleting Hoard Gravity,
## Forced Distribution and Pool Drain outright. Nothing announced it; the boss
## simply became "float and lob orbs", and
## tests/distributor_behaviour_test.gd has been red ever since. That loss is a
## direct cause of the founder's "the stakes aren't high" / "the bosses need
## to be more challenging with each stage". All three systems are restored
## here, merged onto the newer free-hover pursuit rather than replacing it.

const BOSS_ID := "crystal"
const ORB := preload("res://src/boss/boss_projectile.tscn")
## On-screen body size. Mirrored by distributor.tscn's RectangleShape2D.
const BODY := 240.0

enum Phase { PATROL, GRAVITY_TELL, HOARD_GRAVITY, SHARD_THROW, VULNERABLE }

## Hurtbox matches the scaled OPAQUE silhouette of sprite_boss_crystalline.png,
## not the full BODY box. Source is 104x150 with opaque bbox (3,19)-(100,126);
## BossSprite._fit() scales it by BODY/150 = 1.6 to fill the body height, so
## the real on-screen character is ~155x171, centered ~0.8px left and ~4px up
## from the body box's own centre (120,120).
##
## Same double-offset bug as auditor.gd (Kimi K3, found re-deriving the L1
## boss and confirmed by hand against this scene): `hitbox.position` below
## used to ALSO move the Area2D to (120,120) on top of
## distributor.tscn's Hitbox/CollisionShape2D, which already carried that same
## (120,120) offset — stacking both put the shape's true centre at (240,240),
## a full half-body diagonally off the visible sprite. Same class of bug, same
## fix as the Auditor.
const HURTBOX_SIZE := Vector2(155.0, 171.0)
const HURTBOX_CENTER := Vector2(119.0, 116.0)

@export var patrol_speed: float = 80.0
@export var throw_cooldown: float = 1.5
@export var vulnerable_time: float = 1.6

## How fast the field drags the player, in px/s at the centre of the field.
##
## THIS IS A DISPLACEMENT SPEED, NOT A VELOCITY INJECTION — and that
## distinction is the whole mechanic. Two earlier versions wrote
## `player.velocity.x += strength * delta` and BOTH moved the player exactly
## 0.0 px, measured by tests/distributor_behaviour_test.gd:
##
##   1. strength 520 lost to the player's own `ground_decel = 2800`.
##   2. strength 4200 "won" that arithmetic and still moved nothing, because
##      the real problem is node processing order: the boss runs its
##      _physics_process AFTER the player has already called move_and_slide(),
##      so the injected velocity is wiped by the player's deceleration on the
##      next frame before it is ever used to move anything. No strength value
##      fixes that — it is structural.
##
## Displacing with move_and_collide() sidesteps both: it moves the body now,
## it respects collision (no tunnelling through the arena walls), and it is
## immune to processing order. Player walk_speed is 200 px/s, so at 130 the
## pull is clearly felt but can be out-run by holding away — which is exactly
## the counter-play the telegraph is promising.
@export var pull_speed: float = 130.0
@export var pull_radius: float = 420.0
## Pull at the FIELD EDGE as a fraction of full strength. Not 0.0: a linear
## falloff to zero meant the outer half of the radius was below ground_decel
## and therefore inert, so the field's usable area was far smaller than the
## ring drawn on screen — a telegraph that overstates the threat.
const PULL_EDGE_FRACTION := 0.6

var current_phase_state: Phase = Phase.PATROL
## Starts positive so he CHASES for a beat before his first action. At 0.0 he
## acted on the very first physics frame.
var throw_timer: float = 2.2
## Counts the current state down. Without it VULNERABLE never ended and he sat
## motionless for the rest of the fight — the founder's "the 2nd boss doesn't
## chase Lil Blunt!!!".
var state_timer: float = 0.0
var direction: float = 1.0
## Counts actions so the pull and the volley ALTERNATE instead of one attack
## on repeat.
var _cycles: int = 0
var _tell_duration: float = 0.65

## --- Forced Distribution bookkeeping ---
## Every orb carries the id of the volley it came from. Without that, an orb
## left over from the PREVIOUS volley (they live 4s, volleys are ~2s apart)
## would count toward the current volley's tally and fire a false POOL DRAIN.
var _volley_id: int = 0
var _volley_size: int = 0
var _volley_redirected: int = 0
## Damage already taken from redirects in this volley. Capped, because
## uncapped it is degenerate: a phase-3 volley is 5 orbs, and 5 arrival hits
## plus the POOL DRAIN bonus is 6 damage in one volley.
var _volley_damage: int = 0
const MAX_REDIRECT_DAMAGE_PER_VOLLEY := 1

## --- Token-gated spectacle (read once at fight start, never re-read) ---
var _has_diamonds: bool = false   # Prism Pools — sparkle anchors + louder tell
var _has_gold: bool = false       # Gold Ballast — resist the pull
var _has_smoke: bool = false      # Haze Softener — Blaze slows incoming orbs
var _prisms: Array[Node2D] = []

## Persistent per-phase body tint. Every place that "restores" the sprite
## restores THIS rather than plain white — otherwise the phase colour is wiped
## the first time the boss leaves a flash or a vulnerable window, which is how
## the phase-2/3 palette shift ended up being a no-op (Kimi F6).
var _phase_tint: Color = Color(1, 1, 1, 1)

## The surfboard deck itself, exposed so the alignment gate in
## tests/founder_critical_probe_test.gd can measure the board's real rendered
## footprint against the boss's collision centre — the "he falls off his
## diamond surfboard" defect, checked rather than eyeballed.
var _disc: Polygon2D

## Assigned, NOT redeclared: EnemyBase already owns `sprite`, and shadowing
## it is a parse error that leaves this entire script unattached.
@onready var boss_sprite: BossSprite = $ColorRect
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var hitbox: Area2D = $Hitbox
@onready var hitbox_shape: CollisionShape2D = $Hitbox/CollisionShape2D

func _ready() -> void:
	# STAGE 2 OF 3 — must be harder than the Auditor (10 HP), easier than the
	# Claim Jumper (18). The curve used to run BACKWARDS: 10 -> 7 -> 6, so each
	# stage's boss was weaker than the last. Founder: "the bosses need to be
	# more challenging with each stage!!!"
	max_health = 14
	health = 14
	phase_thresholds = [9, 4]
	add_to_group("enemy")
	add_to_group("boss")
	boss_sprite.color = Color(0.3, 0.2, 0.6, 1.0)
	# Founder: "The Boss in the 2nd stage doesn't have the same impact as
	# before as he is MUCH smaller and doesn't have his diamond surfboard!!!"
	# 240 now (was 176, was 96 before that). Mirrored by distributor.tscn —
	# the two must move together or art and hurtbox separate.
	boss_sprite.size = Vector2(BODY, BODY)
	collision.position = Vector2(BODY / 2.0, BODY / 2.0)
	# Hitbox stays at the boss's own origin (0,0) — see HURTBOX_SIZE's comment
	# above. DO NOT set hitbox.position here; that was the double-offset bug.
	_build_diamond_surfboard()
	var hurt_shape := RectangleShape2D.new()
	hurt_shape.size = HURTBOX_SIZE
	hitbox_shape.shape = hurt_shape
	hitbox_shape.position = HURTBOX_CENTER
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	hitbox.area_entered.connect(_on_hitbox_area_entered)
	# CONTACT DETECTION STAYS ON FOR THE WHOLE FIGHT.
	#
	# Founder, several times over: "the moment he touches Lil Blunt the stage
	# needs to restart." Gating `monitoring` to the vulnerable window (what the
	# gutted version did, and what auditor.gd/bandit_boss.gd still did) turns
	# this Area2D off for ~80% of the fight, so `body_entered` never fires and
	# the player can walk straight through the boss untouched. Incoming DAMAGE
	# is gated by `monitorable` instead (player attacks detect the boss, not
	# the reverse) plus take_damage()'s own VULNERABLE check, so leaving
	# detection on is safe and it is what makes contact actually cost the run.
	hitbox.monitoring = true
	hitbox.monitorable = false
	boss_display_name = "The Distributor"
	throw_timer = 2.2
	_setup_health_bar()
	BossVoiceSystem.set_active(self, BOSS_ID)
	BossVoiceSystem.say(self, BOSS_ID, "intro", true)
	# Spectacle gates — real balances, read once at fight start.
	_has_diamonds = Web3Bridge.holds("diamonds")
	_has_gold = Web3Bridge.holds("goldmine")
	_has_smoke = Web3Bridge.holds("smoke")
	if _has_diamonds:
		_spawn_prism_pools()

## The boss can be freed WITHOUT die() (scene change mid-fight); don't leave
## the BossVoiceSystem pointing at a dead node. Same fix the Auditor carries.
func _exit_tree() -> void:
	BossVoiceSystem.clear_active()

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	throw_timer -= delta
	state_timer -= delta

	match current_phase_state:
		Phase.PATROL:
			_hover_pursue(delta, 1.0)
			if throw_timer <= 0.0:
				# THREE-WAY ROTATION: crystal shards FIRST, then pull, then the
				# ETH-orb volley (Forced Distribution), then repeat.
				#
				# Founder, this session (again): "not firing diamonds / crystals
				# / crystal shards as requested" — despite the attack existing
				# and firing correctly in every headless gate. Kimi K3 re-derived
				# the full rotation timeline from this file: crystal shards sat
				# THIRD in the cycle, so the first volley didn't fire until
				# ~9.3s into the fight — and any engagement that ends earlier
				# (very possible: he chases at 345px/s, and boss contact is an
				# instant run-wipe) never reaches it at all. Moving crystals to
				# slot 0 fires the first volley at ~2.2s instead — inside every
				# realistic engagement, not just long ones. Zero mechanical
				# risk: same three functions, only the order changes.
				match _cycles % 3:
					0:
						_throw_crystal_shards()
					1:
						_begin_gravity_tell()
					_:
						_throw_shards()
				_cycles += 1

		Phase.GRAVITY_TELL:
			# Orbs snap inward, two dashed rings collapse onto him. The field
			# does NOT pull yet — this is pure reaction time. He keeps closing
			# while he winds up; a boss that brakes to a halt to telegraph is a
			# boss you can ignore.
			_hover_pursue(delta, 0.62)
			queue_redraw()
			if state_timer <= 0.0:
				_begin_hoard_gravity()

		Phase.HOARD_GRAVITY:
			_hover_pursue(delta, 0.55)
			_apply_pull(delta)
			queue_redraw()
			if state_timer <= 0.0:
				# Phase 2+: he fires the instant the field drops, so escaping
				# the pull and immediately dodging a volley is the real test.
				if current_phase >= 2:
					_throw_shards()
				else:
					current_phase_state = Phase.PATROL
					throw_timer = _cadence()
					queue_redraw()

		Phase.SHARD_THROW:
			# Keeps closing while he throws, just slower. He was braking to a
			# dead stop here, which is half of why he never felt like a threat.
			_hover_pursue(delta, 0.70)
			if state_timer <= 0.0:
				_begin_vulnerable()

		Phase.VULNERABLE:
			# HE STILL DRIFTS TOWARD YOU WHILE VULNERABLE.
			#
			# He used to brake to a dead stop here, and at 1.6s of a ~7.1s
			# cycle that is nearly a quarter of the fight spent motionless. Do
			# the arithmetic against a player holding run: even with every
			# other state now above sprint speed, one full cycle came out at
			# roughly 50px NET LOST — the open-runway gate measured the gap
			# going 600 -> 787. He was only ever "catching" the player because
			# the arena has walls.
			#
			# VULNERABLE is the player's damage window and it stays: he is
			# still the slowest he ever gets, at half a sprint, and visibly
			# so. But drifting is not the same as free escape, and the founder
			# asked for stakes.
			_hover_pursue(delta, 0.0, VULNERABLE_DRIFT)
			# Vulnerability is telegraphed by a soft CYAN shimmer, not by
			# turning him red — red is reserved for the hit flash so a landed
			# blow actually reads (founder E3).
			boss_sprite.modulate = (Color(0.75, 1.15, 1.35, 1.0)
				if fmod(state_timer, 0.34) < 0.17 else _phase_tint)
			if state_timer <= 0.0:
				_end_vulnerable()

## Free 2D hover pursuit — the "levitate in any direction" the founder asked
## for, and the reason he can no longer fall anywhere.
##
## RAISED 430 -> 1600 (Kimi K3, session 7). The founder reported "still not
## chasing" across MANY sessions even as MIN_PURSUE_SPEED was raised three times
## — because every chase gate drove a STRAIGHT-LINE player, and the real problem
## is only visible against a WEAVING one: at accel 430, a full horizontal
## reversal (±345 px/s) took 690/430 ≈ 1.6s of near-zero net horizontal velocity,
## while a real player reverses in ~0.1s. The boss just oscillated overhead,
## average horizontal closing ≈ 0 — exactly "hovers but doesn't chase". At 1600
## a reversal is ~0.43s and 0->345 is ~0.22s, so he actually tracks a juking
## player. Speed floors were never the missing piece; the acceleration was.
const HOVER_ACCEL: float = 1600.0
## Lock hysteresis (session 9): after the climb lock releases it cannot re-arm
## for LOCK_COOLDOWN seconds — so a hopping player can't perma-arm it every jump
## and pin the boss overhead. A genuine imminent sweep (|dx| < LOCK_ARM_OVERLAP,
## a strict subset of the could_touch band) bypasses the cooldown so the
## spawn/approach sweep-kill guard is preserved.
const LOCK_COOLDOWN: float = 0.9
const LOCK_ARM_OVERLAP: float = 96.0
var _climb_locked: bool = false
var _lock_cd: float = 0.0

## STANDOFF + SURGE — real root cause of the founder's TENTH-PLUS "still
## doesn't chase" report (PROMPT_PR41_REJECTED / LEVEL1_MUSIC residuals,
## 2026-08-18), diagnosed by reading this exact function: `target` used to be
## `player.global_position + Vector2(0.0, -HOVER_ABOVE)` — steering directly
## at the player's OWN x. A live Playwright capture (2s of active player
## fleeing, boss's on-screen position measured before/after) showed the
## boss's SCREEN position barely moves even though `to` is genuinely nonzero
## every frame: the camera follows the player, and a boss that steers at the
## player's exact x rides at an almost-fixed screen offset near the player at
## all times — there is no MOMENT where he visibly closes a gap, because he
## is never meaningfully behind.
##
## Two changes, not one, because they fix two different failures:
##
## 1. STANDOFF_X: steer at a point held to one side of the player instead of
##    directly on top of them, so a genuine gap can open and close rather
##    than a permanent near-zero offset (this was tried once before, in an
##    earlier session on a different branch, and measured to work — but that
##    branch never reached this codebase's live lineage, which kept tuning
##    the center-lock instead).
## 2. SURGE: even a standoff that holds a CONSTANT offset reads as "parked
##    beside me", not "chasing", because holding steady state has no visible
##    motion of its own. Periodically (SURGE_INTERVAL) he closes in past the
##    standoff toward the player (SURGE_CLOSE_FACTOR) for SURGE_DURATION at
##    SURGE_SPEED_MULT, then eases back out — a punctuated, readable
##    "lunge in, fall back" that moves his SCREEN position dramatically in
##    both directions, which a constant hold can never produce regardless of
##    how correct the underlying pursuit speed is.
const STANDOFF_X: float = 168.0
const STALK_WEAVE_AMP: float = 70.0
const STALK_WEAVE_RATE: float = 1.35
var _stalk_t: float = 0.0
var _standoff_side: float = 0.0
const STANDOFF_FLIP_DEADZONE: float = 24.0
const SURGE_INTERVAL: float = 3.2
const SURGE_DURATION: float = 0.65
const SURGE_CLOSE_FACTOR: float = 0.25  ## fraction of STANDOFF_X he closes to during a surge
const SURGE_SPEED_MULT: float = 1.6
var _surge_t: float = 0.0
var _surge_active: bool = false
## Player top speed is walk_speed 200 * SPRINT_MULTIPLIER 1.2 = 240 px/s.
##
## Founder: "the boss is not chasing Lil Blunt which makes it too easy."
## 265 looked like it beat 240, but he only moves at FULL speed in PATROL — the
## scales below dropped him to 93 (tell), 66 (hoard) and 119 (throw) px/s, i.e.
## far slower than a running player for roughly half of every cycle, so a
## player who simply held the run key was never caught. Raised so the slowest
## pursuing state still roughly matches a sprint, with real headroom in PATROL.
const HOVER_MAX: float = 330.0
## Ride height above the player, measured from the player to this node's ORIGIN.
##
## Must clear the body, not just the origin. This node's origin is the body's
## TOP-LEFT and the body is BODY tall, so at the old 150 the boss's feet sat
## 90px BELOW the player's head — he was permanently inside them. That was
## harmless only because contact detection happened to be switched off for most
## of the fight; the moment contact was fixed to fire whenever he touches Lil
## Blunt (which is what the founder asked for), 150 would have meant an
## unavoidable kill about one second into every attempt. BODY + 60 keeps a
## readable 60px gap under his board, so touching him is something the player
## does — by jumping into him, or by losing the tug-of-war with HOARD GRAVITY —
## rather than something the fight does to them on spawn.
## Clear air between the bottom of his board and the top of the player.
##
## RAISED FROM 60 WITH THE CENTRE-SEEKING FIX, and it had to be. While he
## steered his ORIGIN at the player his 240px body sat entirely to one side of
## them, so a vertical overshoot on the way down met empty space. Centre-
## seeking parks that body directly overhead, where the only thing between him
## and a contact kill is this gap — and he closes on it at up to 330 px/s with
## 430 px/s^2 of braking, which overshoots a 60px gap easily. A distributor
## behaviour run caught it immediately: he killed a player who was standing
## still and never touched a control.
##
## That is the exact failure this constant already existed to prevent. From
## its original note: touching him must be "something the player does — by
## jumping into him, or by losing the tug-of-war with HOARD GRAVITY — rather
## than something the fight does to them on spawn." 130 restores that margin
## against the new approach speed without moving him further away
## horizontally, which is the axis the chase is actually judged on.
## 130 -> 55 (2026-08-18, Kimi K3 audit). THE reason every previous speed
## fix failed to satisfy the founder: he was never failing to close, he was
## closing onto a point HOVER_ABOVE = BODY/2 + CLEARANCE = 250px over the
## player's head, then braking to a dead hover. Chase gates measure
## horizontal closing and pass; the founder watches a boss that arrived and
## parked. Halving the clearance brings him down into the player's space so
## the pursuit reads as "coming at me" rather than "floating up there".
const HOVER_CLEARANCE: float = 55.0
## Ride height measured from the player to the body's CENTRE, so the drawn gap
## under his board is the same 60px regardless of where this node's origin is.
const HOVER_ABOVE: float = BODY / 2.0 + HOVER_CLEARANCE
## He must be this far clear of the player's head before he moves sideways at
## all — see the climb rule in _hover_pursue.
const CLIMB_CLEAR_MARGIN: float = 60.0
## Speed used ONLY while the climb lock (above) is active — pure vertical
## motion, so it carries none of the lateral-sweep collision risk that caps
## every other pursuing state at MIN_PURSUE_SPEED. Set above the normal chase
## floor so getting clear of the safety lock is faster, not a multi-cycle drag
## on the actual chase — but NOT set higher than this: 520 was tried first and
## REGRESSED the real-arena-bounds gate (boss travelled only 385px in 7s,
## under the 400px pass bar) by overshooting the climb target hard enough,
## inside the arena's own y-bounds, that he spent longer recovering from the
## overshoot than he saved climbing faster. 400 is the value that improved the
## open-ground case without costing the bounded-arena one — verified by
## running both real-physics gates, not assumed.
const CLIMB_SPEED: float = 400.0
## Clear air the gravity field must always leave under his board.
##
## RAISED 48 -> 72 (CLIMB_CLEAR_MARGIN + 12 buffer). Founder, this session,
## again: "The 2nd boss is still not chasing Lil Blunt". Kimi K3 re-derived
## the FULL multi-phase cycle (not just phase 2) inside the real bounded
## arena, not just open ground, and found the open-ground gate's own math
## (+164px/cycle at the old MIN_PURSUE_SPEED=315) doesn't survive contact
## with HOARD_GRAVITY: `_apply_pull` could winch the player up to exactly
## PULL_FLOOR_MARGIN (48) of clear air under his board — INSIDE the
## CLIMB_CLEAR_MARGIN=60 band that locks him to vertical-only movement. Every
## pull could therefore re-arm his own "don't sweep sideways through you"
## safety lock mid-fight, at ~4x the cost in dead time that the speed floor
## clawed back, which is why the fight still read as "not chasing" live even
## though the bounded real-arena gate passed. 72 keeps the pull's clear-air
## floor physically outside the lock band, so it can no longer trigger this.
const PULL_FLOOR_MARGIN: float = 72.0

## Floor under every pursuing state's speed, in px/s.
##
## FOUNDER, THREE TIMES NOW: "the 2nd boss doesn't chase Lil Blunt", then
## after HOVER_MAX went to 330, "still not moving/chasing", then again after
## this floor was first added at 265: "The boss in stage 2 is still not
## chasing!!!!"
##
## The first two fixes were real and are why he chases at all in phase 1 — but
## every gate written for them (including the real-arena-bounds one) drove a
## FRESH, undamaged boss, which never leaves phase 1. Kimi K3 was asked to
## re-derive the numbers from this file with no memory of any prior fix, and
## reconstructed the FULL phase-2 cycle independently — confirmed by hand
## here against every actual duration/scale constant in this file, not
## estimated: at the old 265 floor, one full phase-2 super-cycle (a
## HOARD_GRAVITY-and-SHARD_THROW long cycle plus a SHARD_THROW-only short
## cycle, 8.2s total — this is the real alternation the state machine runs
## once damage has dropped him below the phase_thresholds[9,4] first
## threshold) nets to **-1.5px against a player who does nothing but hold
## sprint on open ground**. Not slow — a dead heat, trending backward. Every
## previous gate passed because it never damaged the boss into phase 2, and
## the one gate that ran long enough to matter also clamped the player at an
## arena wall, where a bounded arena hides an open-ground net rate of zero.
##
## Raised 265 -> 315 -> 345 across two sessions. 315 solved the open-ground
## math (~+164px/8.2s super-cycle) but the founder still reported "still not
## chasing" live — see PULL_FLOOR_MARGIN's comment for why the climb lock was
## the real remaining drag once the pull could no longer re-arm it. With that
## fixed, 345 (Kimi K3's re-derivation) pushes the pursuing floor further
## still, per the founder's explicit "push further... prefer stronger pursuit
## over leaving him outrunnable": ~+262.5px/8.2s in phase 2 (worst phase),
## ~+340.5 in phase 1, ~+378 in phase 3 — comfortably positive in every phase,
## not just the open-ground case. VULNERABLE_DRIFT (his actual damage window,
## kept at half a sprint on purpose) and every state's duration/pacing are
## untouched — the fair hit window the founder liked does not shrink.
const MIN_PURSUE_SPEED: float = 345.0

## Hard arena clamp, set by the level when the fight starts. Zero size = unset,
## in which case only the flight model applies.
##
## These are the RAW arena bounds in world space (the level passes start_x /
## end_x untouched). The half-body inset is applied HERE, by the only object
## that knows how big it is — see _clamp_to_arena.
var arena_min: Vector2 = Vector2.ZERO
var arena_max: Vector2 = Vector2.ZERO

## Centre of the boss's body in world space. The body box runs from this node's
## origin to +BODY, so the centre is half a body along both axes — NOT the
## hardcoded +48 that predates the 96 -> 240 resize.
func hit_centre() -> Vector2:
	return global_position + Vector2(BODY / 2.0, BODY / 2.0)

## Cadence between actions, tightening per phase.
func _cadence() -> float:
	return maxf(1.2, throw_cooldown - 0.4 * (current_phase - 1))

## Speed he keeps while vulnerable — half a sprint, so he closes slowly rather
## than handing over a free window. See the VULNERABLE case in _physics_process.
const VULNERABLE_DRIFT: float = 120.0

func _hover_pursue(delta: float, speed_scale: float = 1.0,
		min_speed: float = MIN_PURSUE_SPEED) -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p:
		# Hold a side of the player (with hysteresis so he doesn't oscillate
		# through them when the player runs underneath) and breathe around it
		# so a stalled player doesn't turn the standoff into a new static
		# park. See STANDOFF_X's block comment for why this exists at all.
		var dx_now: float = hit_centre().x - p.global_position.x
		if absf(dx_now) > STANDOFF_FLIP_DEADZONE:
			_standoff_side = signf(dx_now)
		if _standoff_side == 0.0:
			_standoff_side = 1.0
		_stalk_t += delta
		var breathe: float = sin(_stalk_t * STALK_WEAVE_RATE) * STALK_WEAVE_AMP
		var standoff_now: float = STANDOFF_X + breathe
		# SURGE: periodically lunge past the standoff toward the player, then
		# ease back out. This is what actually reads as "chasing" on screen —
		# see STANDOFF_X's comment for why holding even a correct constant
		# offset cannot, by itself, look like pursuit under a player-following
		# camera.
		_surge_t += delta
		if not _surge_active and _surge_t >= SURGE_INTERVAL:
			_surge_active = true
			_surge_t = 0.0
		if _surge_active:
			standoff_now = STANDOFF_X * SURGE_CLOSE_FACTOR
			if _surge_t >= SURGE_DURATION:
				_surge_active = false
				_surge_t = 0.0
		var target: Vector2 = p.global_position + Vector2(
			_standoff_side * standoff_now, -HOVER_ABOVE)
		# STEERS FROM THE BODY CENTRE, NOT THE ORIGIN. This node's origin is the
		# body's TOP-LEFT and the body is 240 wide, so aiming the origin at the
		# player parked his visible centre a permanent 120px EAST of them — he
		# was chasing a point he had already overshot. Combined with the arena
		# clamp below that was enough to pin him motionless for the whole
		# western third of the arena, which is exactly what the founder saw.
		var to: Vector2 = target - hit_centre()
		# CLIMB CLEAR FIRST, CLOSE SECOND.
		#
		# Centre-seeking fixed the chase and immediately introduced a new way to
		# die. He spawns at roughly the player's own height, so steering his
		# centre at them swept a 240px body SIDEWAYS THROUGH them on the
		# approach — and boss contact is an instant restart, not a hit, so a
		# player who never touched a control lost the run on his opening move.
		# A logging build caught him doing it with his centre at (-262, 61)
		# against a player at (-200, 300): 119px of daylight at the moment the
		# print ran, and a body that had already passed straight over them.
		#
		# This is exactly what HOVER_CLEARANCE exists to prevent — from its own
		# note, contact must be "something the player does... rather than
		# something the fight does to them on spawn."
		#
		# The rule is therefore geometric, not a fudge factor: until the BOTTOM
		# OF HIS BODY is clear of the top of the player, he does not move
		# sideways at all. He rises straight up, and only starts closing once
		# he can no longer collide on the way. A softer version of this (damping
		# the horizontal to 15%) was not enough — damped is still lateral, and
		# he covered the gap during the climb anyway.
		# The lock only applies where a collision is actually possible: he must
		# be low enough to hit them AND close enough horizontally for their
		# spans to meet. Locking unconditionally was too blunt — approaching
		# from 600px away at the player's own height, he froze his horizontal
		# closing for the whole climb and LOST ground to a sprinting player,
		# which the open-runway gate caught at once (gap 600 -> 787). A full
		# body width of horizontal separation is half a body more than contact
		# needs, so he starts rising well before he could reach them.
		var centre: Vector2 = hit_centre()
		var body_bottom: float = centre.y + BODY / 2.0
		var too_low: bool = body_bottom > p.global_position.y - CLIMB_CLEAR_MARGIN
		# BODY * 0.6 (Kimi K3, session 8), down from 0.75. THE live "still not
		# chasing" cause: in the REAL Stage-2 arena the boss's centre can only
		# travel ~460px (700px arena minus his own half-body inset at each wall).
		# The old 0.75 band (±180px) covered 78% of that range, and `too_low`
		# re-arms every time the player rises ~70px — so a player who WEAVES AND
		# HOPS (which every prior chase gate's ground-runner never did) kept the
		# climb lock armed almost continuously, zeroing his horizontal closing:
		# he hovered overhead instead of chasing. That is exactly the
		# headless-green / live-broken divergence. Contact needs only half a body
		# (120) + the player's 16px collision half-width = 136px, so 0.6*BODY
		# (144px) preserves the sideways-sweep-kill margin while dropping lock
		# coverage 78% -> 63% and breaking the weave-hop perma-lock. (A proper
		# hysteresis on the lock is the deeper fix — flagged for a follow-up.)
		_lock_cd = maxf(0.0, _lock_cd - delta)
		# LOCK HYSTERESIS (Kimi/Fable/Qwen s9). The single-frame `too_low and
		# could_touch` climb lock re-armed on EVERY player hop, pinning the boss
		# into vertical-only motion in the 700px arena — the live "hovers, doesn't
		# chase". Now: once the lock RELEASES it cannot re-arm for LOCK_COOLDOWN,
		# UNLESS a genuine imminent body-sweep is happening (|dx| < LOCK_ARM_OVERLAP,
		# a strict subset of the could_touch band so the cooldown actually bites) —
		# that bypass preserves the spawn/approach sweep-kill guard. And while
		# locked he no longer hard-stalls: he still CREEPS toward the player at 25%
		# (Qwen) so the fight reads as pursuit, not a freeze.
		var raw_lock: bool = too_low and absf(centre.x - p.global_position.x) < BODY * 0.6
		var imminent: bool = raw_lock and absf(centre.x - p.global_position.x) < LOCK_ARM_OVERLAP
		if _climb_locked:
			if not raw_lock:
				_climb_locked = false
				_lock_cd = LOCK_COOLDOWN
		else:
			if imminent or (_lock_cd <= 0.0 and raw_lock):
				_climb_locked = true
		var climbing: bool = _climb_locked
		if climbing:
			# S10 T6 (Kimi-role audit): at close range `imminent` (|dx|<96) re-arms
			# the lock every frame regardless of the cooldown, so against a close+
			# hopping player (exactly the founder's play pattern) the lock is
			# effectively continuous and 0.25 damping left only ~52px/s of horizontal
			# closing — well under a 240px/s sprint, i.e. still "hovers, doesn't chase".
			# Doubling the in-lock horizontal to 0.5 (~104px/s) is the SAFE half of
			# the fix: it does NOT reintroduce the sideways-sweep contact-kill that a
			# full bypass-defeat would (contact = instant run restart — a worse
			# regression than a slow chase). The remaining verdict is deferred to a
			# real browser capture (T6), per "claim FIXED only with capture".
			to.x *= 0.5   # damped, not zeroed — he keeps closing during the lock
		# CLIMBING GETS ITS OWN, FASTER FLOOR.
		#
		# Found by driving a REAL fight through Phase 2 for a sustained
		# open-ground kite (distributor_phase2_open_ground_chase_test.gd) after
		# raising MIN_PURSUE_SPEED alone did almost nothing: he and the player
		# spawn at roughly the same height very often (right after a pull, a
		# vulnerable window, or simply the fight's own opening), which means
		# EVERY one of those moments re-triggers the climb lock above, and at
		# the ordinary chase floor a ~180px climb costs 0.6-0.8s of ZERO
		# horizontal progress before he's even pointed at the player again —
		# that dead window, repeated every cycle, was the real reason a
		# sprinting player never felt caught, not the pursuing-state floor.
		#
		# This is safe to speed up on its own: the lock's entire job is
		# "no LATERAL movement while a sideways sweep could still hit them",
		# and pure vertical motion has no lateral component to sweep with —
		# raising it cannot reintroduce the spawn-kill bug HOVER_CLEARANCE and
		# this lock exist to prevent. It only shortens how long he spends
		# getting out of the way of his own safety check.
		var speed: float = CLIMB_SPEED if climbing else maxf(HOVER_MAX * speed_scale, min_speed)
		if _surge_active:
			speed *= SURGE_SPEED_MULT
		velocity = velocity.move_toward(to.normalized() * speed, HOVER_ACCEL * delta)
		boss_sprite.set_facing(to.x > 0.0)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, HOVER_ACCEL * delta)
	# NO gravity term anywhere in this script any more.
	move_and_slide()
	_clamp_to_arena()

func _hover_brake(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, HOVER_ACCEL * delta)
	move_and_slide()
	_clamp_to_arena()

## Last line of defence against "he fell in the trench and disappeared". Even
## if some future force pushes him, he physically cannot leave the arena box.
##
## Clamps the body CENTRE, inset by half a body, so the whole 240px sprite
## stays inside the arena. The previous version clamped the ORIGIN to bounds
## the level had already inset by a magic 90 — which let the body hang 150px
## past the east wall while blocking the centre from ever reaching the western
## 210px of the arena.
##
## It also RESETS the velocity component pushing into the wall. Without that,
## `move_toward` kept accelerating into the clamp every frame and the boss sat
## glued to the boundary with a saturated velocity, so the instant the player
## moved back into reach he still needed a full deceleration to unstick — he
## read as frozen.
func _clamp_to_arena() -> void:
	if arena_max == Vector2.ZERO:
		return
	var half: float = BODY / 2.0
	var lo_x: float = arena_min.x + half
	var hi_x: float = maxf(lo_x, arena_max.x - half)
	var centre: Vector2 = hit_centre()
	var clamped_x: float = clampf(centre.x, lo_x, hi_x)
	var clamped_y: float = clampf(centre.y, arena_min.y, arena_max.y)
	if not is_equal_approx(clamped_x, centre.x):
		velocity.x = 0.0
	if not is_equal_approx(clamped_y, centre.y):
		velocity.y = 0.0
	global_position += Vector2(clamped_x - centre.x, clamped_y - centre.y)

## THE DIAMOND SURFBOARD.
##
## Founder, furious: "the boss falls off his Diamond surfboard" and then "he
## doesn't have his diamond surfboard!!! WHAT THE FUCK!!!"
##
## Both complaints have the same origin. There has never been a surfboard NODE
## in this codebase — a search of the whole repo returns nothing. What existed
## was a separate decorative diamond placed in the arena that he read as a
## board; the boss "fell off" it because every boss used to face left by
## negating the sprite's x-scale, and BossSprite anchors its inner Sprite2D at
## size/2, so negating the parent's x-scale MIRRORS that offset and teleports
## the art ~160px sideways while the arena diamond stayed put.
##
## Two fixes, both needed: facing now flips `flip_h` in place (BossSprite.
## set_facing), and the board is a CHILD of the boss, so it is carried by his
## transform and cannot be separated from him by any movement or flip.
func _build_diamond_surfboard() -> void:
	var board := Node2D.new()
	board.name = "DiamondSurfboard"
	# Under the soles: the body box is BODY tall from this node's origin.
	board.position = Vector2(BODY / 2.0, BODY - 6.0)
	board.z_index = -1
	add_child(board)

	var half_w: float = BODY * 0.62
	var half_h: float = BODY * 0.085

	# Crystal underglow so it reads on the cavern's dark floor.
	var glow := Sprite2D.new()
	glow.texture = preload("res://src/assets/sprites/fx_dot.png")
	glow.modulate = Color(0.45, 0.9, 1.0, 0.34)
	glow.scale = Vector2(half_w / 12.0, half_h / 7.0)
	glow.position = Vector2(0, 4)
	board.add_child(glow)

	# Faceted deck — a stretched diamond built from two mirrored triangles so
	# it reads as cut crystal rather than a plain lozenge.
	var deck := Polygon2D.new()
	deck.polygon = PackedVector2Array([
		Vector2(-half_w, 0.0),
		Vector2(-half_w * 0.45, -half_h),
		Vector2(half_w * 0.45, -half_h),
		Vector2(half_w, 0.0),
		Vector2(half_w * 0.45, half_h),
		Vector2(-half_w * 0.45, half_h),
	])
	deck.color = Color(0.62, 0.93, 1.0, 0.96)
	board.add_child(deck)
	_disc = deck

	# Bright top facet + dark keel give the flat polygon depth.
	var facet := Polygon2D.new()
	facet.polygon = PackedVector2Array([
		Vector2(-half_w * 0.82, -half_h * 0.18),
		Vector2(-half_w * 0.35, -half_h * 0.86),
		Vector2(half_w * 0.35, -half_h * 0.86),
		Vector2(half_w * 0.82, -half_h * 0.18),
	])
	facet.color = Color(0.90, 0.99, 1.0, 0.95)
	board.add_child(facet)

	var keel := Polygon2D.new()
	keel.polygon = PackedVector2Array([
		Vector2(-half_w * 0.5, half_h * 0.2),
		Vector2(half_w * 0.5, half_h * 0.2),
		Vector2(0.0, half_h * 1.5),
	])
	keel.color = Color(0.20, 0.52, 0.78, 0.95)
	board.add_child(keel)

	# Hover bob — he SURFS on it rather than standing on a slab.
	var bob := board.create_tween().set_loops()
	bob.tween_property(board, "position:y", BODY - 12.0, 1.1).set_trans(Tween.TRANS_SINE)
	bob.tween_property(board, "position:y", BODY - 6.0, 1.1).set_trans(Tween.TRANS_SINE)

# --- HOARD GRAVITY -------------------------------------------------------

func _begin_gravity_tell() -> void:
	current_phase_state = Phase.GRAVITY_TELL
	state_timer = _tell_duration
	BossVoiceSystem.say(self, BOSS_ID, "taunt")
	AudioManager.play_sfx("powerup")

func _begin_hoard_gravity() -> void:
	current_phase_state = Phase.HOARD_GRAVITY
	# Longer and stronger each phase.
	state_timer = 1.4 + 0.4 * (current_phase - 1)
	ScreenShake.shake(0.25, 3.0)

## Drag the player toward the hoard.
func _apply_pull(delta: float) -> void:
	# Cast to a CONCRETE type immediately. get_first_node_in_group() is typed
	# `Node`, so `p.global_position` is a Variant and `var x := <Variant>` is a
	# HARD PARSE ERROR in Godot 4.3 — it does not warn, it refuses to load the
	# whole script, leaving the boss with no behaviour at all. That is the exact
	# silent failure that once shipped bosses 2 and 3 with no AI. `gdparse`
	# passes this file happily; only a real engine load catches it.
	var body := get_tree().get_first_node_in_group("player") as CharacterBody2D
	if body == null:
		return
	# Never drag a dead or respawning player — the field would fight the
	# respawn placement and could yank them straight back off a ledge.
	if StateMachine.is_dead():
		return
	var centre := hit_centre()
	var to_centre := body.global_position.direction_to(centre)
	var dist := body.global_position.distance_to(centre)
	if dist > pull_radius or dist < 8.0:
		return
	# Falls off with distance so the gradient is learnable, but never below
	# PULL_EDGE_FRACTION — see that constant for why a falloff to zero made
	# most of the drawn field inert.
	var falloff := lerpf(PULL_EDGE_FRACTION, 1.0, 1.0 - clampf(dist / pull_radius, 0.0, 1.0))
	var speed := pull_speed * falloff * (1.0 + 0.25 * (current_phase - 1))
	# GOLD "Gold Ballast": holders are heavier and resist the drag. Purely
	# player-favourable — non-holders get the shipped speed, not more.
	if _has_gold:
		speed *= 0.6
	# Vertical drag is gentler: a strong up-pull fights gravity in a way that
	# reads as a bug rather than a threat.
	var step := Vector2(to_centre.x, to_centre.y * 0.35) * speed * delta
	# THE FIELD MAY NOT DELIVER THE CONTACT KILL ITSELF.
	#
	# While he hovered 120px to one side of the player this pull was mostly
	# SIDEWAYS and the question never came up. Centre-seeking put him directly
	# overhead, which turns the same field into a vertical winch pointed at an
	# instant-restart hitbox. The upward step is therefore capped at whatever
	# clear air is left under his board, minus a margin — so the drag can lift
	# you, it can absolutely make you fight it, and it can never finish the job
	# for him.
	#
	# A radial no-pull core was the first attempt and was wrong: at the ranges
	# the field is actually measured at it disabled the mechanic outright,
	# which is the "cosmetic pull" regression this fight has already shipped
	# once. Capping the step keeps the pull real at every distance.
	if step.y < 0.0:
		var clear_air: float = body.global_position.y - (centre.y + BODY / 2.0)
		step.y = -minf(-step.y, maxf(0.0, clear_air - PULL_FLOOR_MARGIN))
	# move_and_collide, not a velocity write — see pull_speed's comment. This
	# also means the arena walls and floor stop the drag instead of the player
	# being pulled through geometry.
	body.move_and_collide(step)

# --- SHARD THROW / FORCED DISTRIBUTION -----------------------------------

## Aimed, slightly-homing ETH orbs. Count + spread + cadence scale with the
## HP phase (1/2/3): 3 orbs -> 5 orbs -> 5 fast orbs. Every orb is
## redirectable during its unstable window (Forced Distribution).
func _throw_shards() -> void:
	current_phase_state = Phase.SHARD_THROW
	state_timer = 0.45
	throw_timer = _cadence()
	# _draw() only paints during the two gravity states, but it is not re-run
	# until something requests it — without this the collapsing rings would
	# stay frozen on screen after the field ends.
	queue_redraw()
	var count: int = [0, 3, 5, 5][current_phase]
	_volley_id += 1
	_volley_size = count
	_volley_redirected = 0
	_volley_damage = 0
	var p := get_tree().get_first_node_in_group("player")
	var base := Vector2.DOWN if p == null else global_position.direction_to(p.global_position)
	for i in range(count):
		var spread := (float(i) - float(count - 1) / 2.0) * 0.22
		var orb := ORB.instantiate()
		orb.direction = base.rotated(spread)
		orb.speed = 170.0 + 40.0 * (current_phase - 1)
		# LONG RANGE (founder session 7: "the diamond bomb and shards don't reach
		# Lil Blunt when he's far away"). At 170-250 px/s the default 4s lifetime
		# only carried them 680-1000px — short of the ~1226px diagonal across the
		# arena to a player hovering below. Extend the lifetime (Kimi K3 s7) rather
		# than the speed, so range grows to 1360-2000px WITHOUT shrinking the
		# Forced-Distribution redirect window that raising speed would gut.
		orb.lifetime = 8.0
		orb.homing = 0.6 if current_phase >= 2 else 0.0
		# DIAMONDS, NOT CIRCLES. Founder (session 6): "the 2nd boss still fires
		# circles" — the redirectable volley was a recolored fx_dot (a blue disc),
		# which reads identically to the Stage-1 boss's dot. Every S2 projectile
		# must now be a diamond or a crystal shard (distinct geometry), so this
		# volley gets the SAME treatment _throw_crystal_shards already uses: the
		# base dot is hidden (tint alpha 0) and an angular DIAMOND Polygon2D rides
		# on top. The Forced-Distribution redirect + homing are untouched — they
		# live on the orb root; the poly is a passive child (Fable-5 / Kimi s6).
		orb.tint = Color(0.7, 0.9, 1.0, 0.0)  # base dot hidden
		orb.redirectable = true
		orb.owner_boss = self
		# SMOKE "Haze Softener": holders running Blaze meet slower orbs.
		# Never changes orb COUNT or pattern — only incoming speed.
		if _has_smoke and GameManager.has_power_up("blaze"):
			orb.speed *= 0.6
		orb.volley_id = _volley_id
		orb.redirected.connect(_on_orb_redirected.bind(_volley_id))
		# add_child BEFORE setting global_position: on a node outside the tree
		# global_position is just local position, so if the parent ever gains a
		# non-identity transform the orbs would spawn offset from the muzzle.
		get_parent().add_child(orb)
		orb.global_position = global_position + Vector2(BODY / 2.0, BODY * 0.21)
		# The visible DIAMOND — a classic rhombus, distinct from the crystal
		# shard's elongated kite so the two attacks read apart. Passive child of
		# the orb; the redirect/homing logic never reads it.
		var gem := Polygon2D.new()
		gem.polygon = PackedVector2Array([
			Vector2(0, -11), Vector2(8, 0), Vector2(0, 11), Vector2(-8, 0)])
		gem.color = Color(0.72, 0.93, 1.0, 0.96)
		orb.add_child(gem)
		var facet := Polygon2D.new()
		facet.polygon = PackedVector2Array([
			Vector2(0, -11), Vector2(8, 0), Vector2(0, 0), Vector2(-8, 0)])
		facet.color = Color(0.92, 0.99, 1.0, 0.95)
		orb.add_child(facet)
	AudioManager.play_sfx("throw")

## CRYSTAL SHARDS — a third, distinct ranged attack.
##
## Founder, this session: "lets make the 2nd boss fire crystals rather and
## crystal shards at times." Deliberately NOT the same mechanic as the ETH-orb
## volley above (Forced Distribution's redirect window is that attack's whole
## identity) and NOT the Auditor's clipboard fan on Level 1 — a tighter,
## faster, non-redirectable barrage with its own crystalline-white tint, so it
## reads as raw pressure rather than another skill-shot window. Count + speed
## scale with phase, same convention as every other attack in this fight.
func _throw_crystal_shards() -> void:
	current_phase_state = Phase.SHARD_THROW
	state_timer = 0.4
	throw_timer = _cadence()
	queue_redraw()
	var count: int = [0, 2, 3, 4][current_phase]
	var p := get_tree().get_first_node_in_group("player")
	var base := Vector2.DOWN if p == null else global_position.direction_to(p.global_position)
	# Tighter fan than the ETH-orb volley (0.12 vs 0.22 rad step) — reads as a
	# focused barrage rather than a wide spread.
	for i in range(count):
		var spread := (float(i) - float(count - 1) / 2.0) * 0.12
		var shard := ORB.instantiate()
		shard.direction = base.rotated(spread)
		# Faster and non-homing: a straight-line barrage, not a tracking one —
		# the counter-play is footwork, not waiting out a redirect window.
		shard.speed = 260.0 + 50.0 * (current_phase - 1)
		# Same long-range fix as the ETH-diamond volley (Kimi K3 s7): 260-360 px/s
		# over the default 4s only reached 1040-1440px; 5s clears the ~1226px
		# diagonal at every phase so the shards actually connect across the arena.
		shard.lifetime = 5.0
		shard.homing = 0.0
		# VISUALLY DISTINCT CRYSTAL SHARD, not a recolored dot. Founder
		# (session 4): "not firing the diamonds nor the shards which makes his
		# attack the same as the 1st boss." Root cause (Kimi K3, confirmed):
		# _throw_crystal_shards, _throw_shards AND the Stage-1 clipboard all
		# instantiate boss_projectile.tscn, which draws fx_dot.png recolored by
		# `tint` — so a white-tinted dot reads identical to the Stage-1 dot. Fix:
		# hide the base dot (transparent tint -> boss_projectile sets
		# sprite.modulate = tint) and draw an actual angular crystal shard on top.
		shard.tint = Color(0.85, 0.98, 1.0, 0.0)  # base dot hidden
		shard.redirectable = false
		get_parent().add_child(shard)
		shard.global_position = global_position + Vector2(BODY / 2.0, BODY * 0.21)
		var poly := Polygon2D.new()
		poly.polygon = PackedVector2Array([
			Vector2(16, 0), Vector2(2, 6), Vector2(-14, 3),
			Vector2(-14, -3), Vector2(2, -6)])
		poly.color = Color(0.85, 0.98, 1.0, 1.0)
		poly.rotation = shard.direction.angle()
		shard.add_child(poly)
	AudioManager.play_sfx("throw")

## A redirected orb reached him — damage outside the vulnerable window. This
## is the skill payoff, and it is the ONLY path that bypasses the window.
## Damage is capped per volley (see MAX_REDIRECT_DAMAGE_PER_VOLLEY); orbs past
## the cap still fly back and burst, they just stop stacking damage.
func take_redirected_orb(from_volley: int = -1) -> void:
	if is_dead:
		return
	# Validity checks run BEFORE the feedback. Playing the shake and the
	# "DISTRIBUTED" text on a stale-volley or over-cap arrival that deals no
	# damage is the same "looks real, does nothing" lie as the invisible
	# dynamite — cosmetic edition. Kimi audit finding F3.
	if from_volley != _volley_id:
		return
	if _volley_damage >= MAX_REDIRECT_DAMAGE_PER_VOLLEY:
		return
	_volley_damage += 1
	ScreenShake.medium()
	EffectSpawner.float_text(global_position, "DISTRIBUTED", Color(0.7, 0.95, 1.0))
	_damage(1)

func _on_orb_redirected(from_volley: int) -> void:
	# Ignore flips of orbs left over from an earlier volley.
	if from_volley != _volley_id:
		return
	_volley_redirected += 1
	if _volley_size > 0 and _volley_redirected >= _volley_size:
		_pool_drain()

## POOL DRAIN — every orb in one volley flipped back. Stuns him straight into
## an extended vulnerable window plus a bonus point of damage.
func _pool_drain() -> void:
	if is_dead:
		return
	_volley_size = 0
	BossVoiceSystem.say(self, BOSS_ID, "hurt", true)
	EffectSpawner.float_text(global_position, "POOL DRAIN!", Color(1.0, 0.9, 0.4))
	ScreenShake.heavy()
	_damage(1)
	if is_dead:
		return
	_begin_vulnerable()
	state_timer += 1.5   # extended window on top of the phase-scaled one

# --- VULNERABLE ----------------------------------------------------------

func _begin_vulnerable() -> void:
	current_phase_state = Phase.VULNERABLE
	# Shrinks per phase (the Claim Jumper pattern) — less free damage time as
	# everything else about the fight gets harder.
	state_timer = maxf(0.8, vulnerable_time - 0.35 * (current_phase - 1))
	boss_sprite.color = Color.WHITE
	# `monitoring` is already true for the whole fight (see _ready); only
	# expose the boss to INCOMING damage here.
	hitbox.set_deferred("monitorable", true)

## Shared exit from the vulnerable window — closes the damage gate and puts
## him straight back on the hunt. Both the timeout path and take_damage() call
## this one function, so a future edit cannot leave one route closing the gate
## and the other not.
func _end_vulnerable() -> void:
	current_phase_state = Phase.PATROL
	throw_timer = _cadence()
	boss_sprite.color = Color(0.3, 0.2, 0.6, 1.0)
	boss_sprite.modulate = _phase_tint
	# Only `monitorable` is gated — `monitoring` stays ON for the whole fight.
	# Toggling it off here meant the boss's own contact never fired outside the
	# vulnerable window, so HOARD GRAVITY could drag the player straight into
	# his body for free (Kimi audit F2), and the founder's "the moment he
	# touches Lil Blunt the stage restarts" was unreachable most of the fight.
	hitbox.set_deferred("monitorable", false)
	queue_redraw()

# --- TELEGRAPH DRAWING ---------------------------------------------------

## Two dashed rings collapsing onto him during the tell, then the live field
## boundary while the pull is active. Procedural _draw keeps this asset-free.
func _draw() -> void:
	if is_dead:
		return
	var centre := Vector2(BODY / 2.0, BODY / 2.0)
	if current_phase_state == Phase.GRAVITY_TELL:
		var t: float = 1.0 - clampf(state_timer / maxf(_tell_duration, 0.01), 0.0, 1.0)
		for ring in 2:
			var start := pull_radius * (1.0 - 0.25 * float(ring))
			var r := lerpf(start, 70.0, t)
			var a := 0.25 + 0.45 * t
			draw_arc(centre, r, 0.0, TAU, 40, Color(0.65, 0.45, 1.0, a), 3.0)
	elif current_phase_state == Phase.HOARD_GRAVITY:
		var pulse := 0.5 + 0.5 * sin(state_timer * 12.0)
		draw_circle(centre, pull_radius, Color(0.35, 0.2, 0.75, 0.08 + 0.05 * pulse))
		draw_arc(centre, pull_radius, 0.0, TAU, 48, Color(0.7, 0.5, 1.0, 0.35 + 0.2 * pulse), 2.0)

# --- TOKEN SPECTACLE -----------------------------------------------------

## DIAMONDS "Prism Pools": three cyan prisms idling at arena anchors, one per
## DIAMONDS payout pool. Pure decoration + a readability aid — they sparkle
## brighter while orbs are redirectable, hinting at the timing window. They
## grant no damage and block nothing.
func _spawn_prism_pools() -> void:
	for i in 3:
		var prism := Node2D.new()
		prism.global_position = global_position + Vector2(-260.0 + 200.0 * float(i), -170.0)
		var spr := Sprite2D.new()
		spr.texture = load("res://src/assets/sprites/sprite_item_eth-ring.png")
		spr.modulate = Color(0.5, 0.95, 1.6, 0.75)
		spr.scale = Vector2(0.55, 0.55)
		prism.add_child(spr)
		var sparkle := CPUParticles2D.new()
		sparkle.texture = load("res://src/assets/sprites/fx_dot.png")
		sparkle.amount = 8
		sparkle.lifetime = 1.6
		sparkle.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		sparkle.emission_sphere_radius = 22.0
		sparkle.gravity = Vector2.ZERO
		sparkle.initial_velocity_min = 4.0
		sparkle.initial_velocity_max = 14.0
		sparkle.scale_amount_min = 0.15
		sparkle.scale_amount_max = 0.4
		sparkle.color = Color(0.6, 0.95, 1.0, 0.5)
		prism.add_child(sparkle)
		get_parent().add_child(prism)
		_prisms.append(prism)

# --- PHASE / DAMAGE ------------------------------------------------------

## Corporate taunt + a visible escalation on each phase step (BossBase calls
## this). The palette shift is the readability cue: a player should SEE the
## fight change, not just feel the numbers move.
func _on_phase_changed() -> void:
	if current_phase == 2:
		BossVoiceSystem.say(self, BOSS_ID, "phase50", true)
		ScreenShake.medium()
		# Violet overdrive — the DIAMONDS palette pushed hot.
		_phase_tint = Color(1.25, 0.85, 1.7, 1.0)
		_tell_duration = 0.6
	elif current_phase == 3:
		BossVoiceSystem.say(self, BOSS_ID, "phase25", true)
		ScreenShake.medium()
		# Core blows out to near-white cyan.
		_phase_tint = Color(1.1, 1.7, 2.1, 1.0)
		# Tell gets shorter but never disappears — the fight stays fair.
		_tell_duration = 0.5
	boss_sprite.modulate = _phase_tint
	Web3Bridge.report_metric("boss_phase_reached", {"boss": BOSS_ID, "phase": current_phase})

## Shared damage application for BOTH damage paths (vulnerable-window hits and
## redirected orbs). Keeping one implementation is deliberate: the Auditor
## shipped a second damage path that skipped the health bar and silently
## desynced the display by 2 HP (Kimi audit) — this cannot repeat that.
func _damage(amount: int) -> void:
	if is_dead:
		return
	var before := health
	health -= amount
	AudioManager.play_sfx("damage")
	BossVoiceSystem.say(self, BOSS_ID, "hurt")
	# Tween `boss_sprite`, NOT `sprite`. EnemyBase resolves `sprite` via
	# get_node_or_null("Sprite") and this boss's scene has no such child (its
	# art is the BossSprite on "ColorRect"), so `sprite` is null here and the
	# old tween errored on every single hit while showing no flash at all.
	# Kimi audit finding F1.
	var tween := create_tween()
	tween.tween_property(boss_sprite, "modulate", Color(4.0, 0.25, 0.25, 1), 0.05)
	tween.tween_property(boss_sprite, "modulate", _phase_tint, 0.05)
	# Pass the pre-hit HP: BossBase._update_health_bar defaults hp_before to
	# -1, and its pip-flash only fires when hp_before > health, so calling it
	# bare silently skipped the damage flash on both paths (Kimi F4).
	_update_health_bar(before)
	if health <= 0:
		die()
	else:
		_check_phase_change()

func take_damage(amount: int) -> void:
	if is_dead or current_phase_state != Phase.VULNERABLE:
		return
	_damage(amount)
	if is_dead:
		return
	_end_vulnerable()

func die() -> void:
	is_dead = true
	BossVoiceSystem.say(self, BOSS_ID, "death", true)
	BossVoiceSystem.clear_active()
	set_physics_process(false)
	# Clear orbs still in flight. Their 4s lifetime outlives the death tween
	# plus the 3s victory timer, so without this the player could be hit —
	# and lose the whole run — AFTER the level was already won. Kimi audit F5.
	get_tree().call_group("boss_projectile", "queue_free")
	for prism in _prisms:
		if is_instance_valid(prism):
			prism.queue_free()
	_prisms.clear()
	GameManager.add_score(1000)
	ScreenShake.shake(0.6, 10.0)
	hitbox.set_deferred("monitorable", false)
	hitbox.set_deferred("monitoring", false)
	StateMachine.change_state(StateMachine.State.LEVEL_COMPLETE)
	ScreenShake.zoom_to(1.0, 0.6)
	AudioManager.play_voice("victory")
	ScreenShake.heavy()
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
	victory.text = "LEVEL COMPLETE!\nOnward to the Gold Rush!"
	victory.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	victory.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	victory.position = global_position - Vector2(100, 50)
	victory.add_theme_font_size_override("font_size", 32)
	get_tree().current_scene.add_child(victory)
	await get_tree().create_timer(3.0).timeout
	# Kimi audit: free BEFORE the scene load. Brief G: advance to Level 3
	# (Gold Rush), not the menu — this is Level 2's boss.
	queue_free()
	SceneRouter.load_scene(GameManager.next_level_scene(2), SceneRouter.Transition.DIAMOND)


func _on_hitbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		# SPAWN GRACE — see BossBase's own const block.
		if is_spawn_grace_active():
			return
		GameManager.last_damage_source = BOSS_ID
		BossVoiceSystem.say(self, BOSS_ID, "mock")
		# Founder stakes rule: ANY boss touch returns Lil Blunt to the START of
		# the level and forfeits the whole run's score — not hurt-and-continue.
		# See GameManager.boss_contact_restart().
		GameManager.boss_contact_restart()

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("projectile"):
		take_damage(1)
