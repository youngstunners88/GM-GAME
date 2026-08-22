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

## Speed he keeps while VULNERABLE — half a sprint (player top speed is 240), so
## he closes slowly rather than freezing solid. See the VULNERABLE case for the
## founder bug this fixes; mirrors distributor.gd's VULNERABLE_DRIFT exactly so
## the two bosses handle their damage window the same way.
## 120 -> 250 (2026-08-18): at 120 the vulnerable window dragged the
## phase-1 cycle average to ~227 px/s, below the player's 240 sprint, so a
## player who just held run was never caught. 250 puts the average at ~273.
const VULNERABLE_DRIFT: float = 250.0

## Hold at least this far from the player while VULNERABLE — do NOT drift point
## blank. The VULNERABLE_DRIFT fix (chase-while-exposed, replacing the old
## vx=0 freeze) also DELIVERED him straight onto the player's axe for free —
## that is the founder's "the third boss is now way too easy to defeat" (Kimi K3:
## "drift toward the player delivers him to the weapon while being harmless").
## He now closes only to here; the player must step INTO range to land hits.
##
## WIRED 2026-08-18, THROUGH A DIFFERENT MECHANISM THAN THE ONE THAT WAS
## REVERTED. `_ground_chase` gained a real min-separation parameter this pass
## (see CHASE_SEPARATION below) that ACTIVELY RETREATS when already closer
## than the standoff, rather than freezing dead — so he still closes
## continuously at VULNERABLE_DRIFT for the whole approach, exactly as before,
## for as long as he's beyond 96px. That preserves the reason the old floor
## was pulled (braking to a hard vx=0 stop for up to 0.7s at melee range,
## ~36% of every cycle motionless — read as "doesn't chase").
##
## What forced re-wiring THIS state specifically, not just PATROL/THROW: a
## direct measurement (tests/claim_jumper_chase_separation_test.gd), not a
## live capture, caught that leaving VULNERABLE unprotected still fed the same
## bug one step removed — a VULNERABLE window that ran its full course left
## him at near-zero separation, and `_end_vulnerable()` hands straight back to
## PATROL at whatever position he's already at, so the very first frame of the
## next chase state inherited contact-radius range regardless of PATROL's own
## floor. Confirmed by re-running that same test after wiring this: the
## transient the min-distance assertion still catches is now bounded to a
## handful of frames during the PATROL/VULNERABLE boundary, not a permanent
## camp — see that test file for the exact numbers.
const VULNERABLE_SEPARATION: float = 96.0

## Hold at least this far from the player during PATROL/THROW — the aggressive
## chase states, and exactly the two a live capture caught causing the loop
## VULNERABLE_SEPARATION's comment describes.
##
## Root cause: PATROL/THROW walk straight at the player until TURN_DEAD_ZONE
## (34px) — effectively zero standoff — and boss contact is
## `GameManager.boss_contact_restart()`, an INSTANT full run-reset, not a
## graze. HALF_BODY is 140, so his own hurtbox alone reaches ~140-160px; with
## no standoff he was walking straight through that radius every single
## engagement. Instrumenting `_on_hitbox_body_entered` in a real browser run
## confirmed it directly: spawn grace correctly expired at 1.2s, and contact
## fired legitimately (not a grace bug) once he'd closed the gap — for a
## stationary player, every single attempt, well before he ever reached his
## own THROW/VULNERABLE attack cycle. `tests/dual_real_level_boss_chase_test.gd`
## never caught this because it explicitly disables the Hitbox's `monitoring`
## before measuring chase distance ("gating the CHASE, not contact") — the
## exact mechanism that kills a real run in play was deliberately switched off
## for that gate.
##
## 200 clears his own contact radius (~155px) with margin for TURN_DECEL
## braking overshoot (up to ~53px at phase-3's 385px/s), and still sits well
## inside the wall-to-wall reach_bar (288px) that same test asserts — so he
## still closes to clearly-threatening, striking-adjacent range, he just no
## longer walks through the player to get there.
const CHASE_SEPARATION: float = 200.0

## Max HP the player can strip in a SINGLE vulnerable window before he shakes it
## off and returns to the hunt. Caps burst-down so the kill takes >= ceil(HP/cap)
## windows (deterministic, ~6 for 18 HP) instead of one point-blank melt — the
## other half of the "too easy" fix.
const MAX_VULN_DAMAGE_PER_WINDOW: int = 3
var _vuln_damage: int = 0

## Damage window after each dynamite throw, shrinking by phase like the other
## two bosses' vulnerable windows. Player DPS is 2.5/s (0.4s axe cooldown);
## against 18 HP that is a 7.2s floor on pure hit-connecting time — Kimi K3's
## exact number, re-derived this session after the founder called the fight
## "too easy to kill". A player who is never gated at all can pay that in one
## unbroken burst from any range; requiring the window makes them earn it.
@export var vulnerable_time: float = 0.7

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
## DOUBLE JUMP (founder, 2026-08-21 final-presentation residual: "why is he
## not jumping. He needs to be able to double jump too!!!!"). Armed on every
## hop takeoff, spent once while still rising, same envelope as the
## Auditor's air-jump — this project's other two bosses (Auditor, and the
## Distributor via its hover) already have a second vertical tool; the
## Claim Jumper had none. Mirrors the Auditor's arm/clear pattern exactly,
## including the fix for the bug Kimi K3 found there: the clear below only
## fires on a genuine landing (`velocity.y >= 0.0`), not on the stale
## `is_on_floor()` read still true on the takeoff frame itself — that
## ordering bug would have silently swallowed every single air hop.
var _air_hop_ready: bool = false
const WALK_ACCEL: float = 620.0
const TURN_DECEL: float = 1400.0
const TURN_DEAD_ZONE: float = 34.0

## SURGE — periodic visible speed burst, added alongside Distributor's
## identical mechanic (PROMPT_PR41_REJECTED / LEVEL1_MUSIC residuals,
## 2026-08-18: "still dont chase!!! You are absolutely useless!!!!" for the
## tenth-plus time). Unlike the Distributor's hover standoff, this boss
## already walks straight at the player's x every frame in `_ground_chase` —
## there is no static-offset illusion to fix here. What a real 2s fleeing
## capture showed instead was his on-screen position barely changing across
## the whole window: patrol/throw/vulnerable each hold their OWN reduced
## speed (0.72x, VULNERABLE_DRIFT), so the cycle-average pace stays close
## enough to the player's sprint that a continuous walk never produces a
## clearly-readable "he's closing in" moment — just a slow, steady drift
## that's easy to read as barely moving at all. A periodic full-commitment
## speed burst (independent of which state he's in) gives the eye a
## punctuated, unambiguous acceleration to track.
const SURGE_INTERVAL: float = 3.2
const SURGE_DURATION: float = 0.65
const SURGE_SPEED_MULT: float = 1.6
## Last known player x, sampled at the end of each _ground_chase frame. Used to
## derive the player's own velocity so the standoff can MATCH it rather than
## stopping or reversing — see the velocity-matching block in _ground_chase.
var _last_player_x: float = 0.0
## Last known player y, sampled alongside `_last_player_x`. Kimi K3 review
## (2026-08-22, PROMPT_CLAIM_JUMPER_STUCK_DOUBLE_JUMP patch audit): the PATROL
## height-ceiling gate (`already_high_enough`) reads `pl.global_position.y`
## directly and "fails OPEN" whenever `pl` is momentarily null (a death/respawn
## or scene-transition window) — the unbounded climb it guards against would
## fully return for that window. Falling back to the last known height instead
## of skipping the gate keeps it engaged even when the live player reference
## drops out.
var _last_player_y: float = 0.0
var _surge_t: float = 0.0
var _surge_active: bool = false
## True on any frame `_clamp_to_arena()` actually held him at an arena bound.
## Replaces `is_on_wall()` as PATROL's hop trigger now that both arena walls are
## player-only — see `_clamp_to_arena`'s own comment.
var _clamp_blocked: bool = false
## Clears ~196px at gravity 980 — same envelope the Auditor uses.
const HOP_VELOCITY: float = -620.0
## Total airtime of one hop: 2 * |HOP_VELOCITY| / gravity ≈ 1.265s. Used to size
## the hop's horizontal commit so he LANDS on the player's x instead of
## overshooting (see the PATROL hop block).
const HOP_AIRTIME: float = -2.0 * HOP_VELOCITY / 980.0
## Second half of the double jump, spent mid-air. Same value as the
## Auditor's AIR_JUMP_VELOCITY so the two bosses share one vocabulary.
const AIR_HOP_VELOCITY: float = -560.0

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
	# CONTACT CORE, NOT THE WHOLE BODY (2026-08-19).
	#
	# This was `hitbox_shape.shape = collision.shape` — the contact Area2D
	# literally SHARED the 280x280 physics box. He was the only one of the
	# three bosses doing that: auditor.gd and distributor.gd both give their
	# hitbox a trimmed shape (HURTBOX_SIZE/HURTBOX_CENTER) rather than the full
	# body box.
	#
	# Why it matters here specifically: boss contact is
	# GameManager.boss_contact_restart(), an INSTANT full-run wipe. With a
	# 280-wide contact box his kill radius is ~140 + the player's ~16 half-width
	# = ~156 px from his centre — LARGER than the VULNERABLE_SEPARATION (96) his
	# own damage window deliberately closes to. So the one moment the fight
	# tells the player to step in and attack was also the moment standing there
	# wiped the run. That contradiction is why every separation value tried so
	# far either camped him inside contact range or stopped him chasing.
	#
	# A 0.62 x 0.78 core (174 x 218, centred) drops the kill radius to ~87+16 =
	# ~103 px, comfortably inside the vulnerable-window standoff, so "close
	# enough to hit him" is no longer "close enough to lose the run". The
	# founder's rule is intact — touching the Claim Jumper still restarts the
	# stage — it now means touching HIM rather than the empty air around his
	# cart. Sharing `collision.shape` was also an aliasing hazard: both nodes
	# pointed at ONE RectangleShape2D resource, so resizing either would have
	# silently resized the other.
	var contact_core := RectangleShape2D.new()
	contact_core.size = Vector2(BODY * 0.62, BODY * 0.78)
	hitbox_shape.shape = contact_core
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	hitbox.area_entered.connect(_on_hitbox_area_entered)
	boss_display_name = "The Claim Jumper"
	# Chase for a beat before the first dynamite (Distributor parity — it starts
	# its own throw_timer positive for the same reason). At the old 0.0 he threw
	# on physics frame 1 and dropped straight into the throw/vulnerable rhythm,
	# so the fight opened on a near-stationary boss instead of a pursuing one.
	throw_timer = 1.2
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

## Margin the boss's CENTRE keeps from the arena wall, in px.
##
## THIS REPLACED A HALF-BODY INSET, AND THAT INSET WAS THE "BOSS DOES NOT MOVE
## BEYOND THIS POINT" BUG — reported by the founder 20+ times across many
## sessions, and never once actually measured until now.
##
## The clamp used to keep the boss's whole BODY inside the arena
## (`arena_min.x + BODY/2 .. arena_max.x - BODY/2`). The PLAYER has no such
## restriction — he walks right up to the wall. So every arena had a dead
## pocket at each end, half a body wide, that the player could stand in and the
## boss could not advance into. Measured on the real levels with the player
## parked at the arena edge:
##
##   Distributor (BODY 240): player at 3730, boss hard-stopped at 3820 — his
##       exact clamp limit — leaving a 90px gap he could never close.
##   Claim Jumper (BODY 280): player at 3730, boss stopped at 3856, 126px gap.
##
## He tracks correctly the whole way in (tracking score +0.57), then hits an
## invisible line and stops dead. That is precisely the screenshot: player at
## one end, boss parked at a fixed coordinate, "not moving beyond this point".
## Every previous fix tuned speed/accel/standoff, none of which can move a boss
## that a clamp is holding.
##
## Clamping the CENTRE (with a small margin, not half a body) still does the
## job the clamp exists for — he cannot leave the fight or drift into a trench
## — while letting him reach any x the player can reach. His body may now
## overhang the arena edge by up to half a body, which is correct: the arena
## boundary is where the FIGHT is, not a shelf his sprite must sit on.
const ARENA_EDGE_MARGIN: float = 24.0

## Returns TRUE when it actually clamped the boss's x this frame — i.e. he is
## pressed against the arena bound and cannot advance further that way.
##
## Founder, 2026-08-22: this used to return nothing, and the ONLY hop trigger in
## PATROL was `is_on_wall()`. Both arena walls are now on a player-only
## collision layer (they were solid to the boss, which froze him for 13.05s of a
## 15s run), so `is_on_wall()` never fires on the flat arena floor and he lost
## every hop — measured 0 air-hops across a 40s kite AND with the player held
## 220px overhead. The barrier did not go away, it just moved: this clamp IS the
## wall now. So the clamp reports the block, and PATROL uses that where it used
## to use `is_on_wall()`. Grok 4.6's audit called this out as the direct
## successor to the removed sensor rather than a new anti-stuck heuristic.
func _clamp_to_arena() -> bool:
	if arena_max == Vector2.ZERO:
		return false
	# Clamp the body CENTRE, inset by half a body, so the whole sprite stays in
	# the arena. Also zero the velocity pushing into the wall, otherwise he
	# accelerates into the clamp every frame and has to unwind a saturated
	# velocity before he can turn around — he reads as stuck.
	var lo_x: float = arena_min.x + ARENA_EDGE_MARGIN
	var hi_x: float = maxf(lo_x, arena_max.x - ARENA_EDGE_MARGIN)
	var centre_x: float = global_position.x + HALF_BODY
	var clamped_x: float = clampf(centre_x, lo_x, hi_x)
	var did_clamp := false
	if not is_equal_approx(clamped_x, centre_x):
		global_position.x += clamped_x - centre_x
		velocity.x = 0.0
		did_clamp = true
	# Only the FLOOR is clamped, not the ceiling: he hops, and pinning his
	# maximum height would cancel the hop mid-air.
	if global_position.y > arena_max.y:
		global_position.y = arena_max.y
		if velocity.y > 0.0:
			velocity.y = 0.0
	return did_clamp

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
	# S10 T7 — THE "FROZEN STATUE" REGRESSION (Kimi-role audit, confirmed here
	# against the live Gold Rush arena constants). When BODY grew to 280,
	# HALF_BODY became 140, so `_clamp_to_arena` pins his CENTRE at
	# arena_max.x - 140. From there this probe casts at toe_x(=arena_max.x) +
	# LEDGE_PROBE_MARGIN(16) — i.e. 16px PAST the arena's own SOLID boundary wall
	# — finds no floor, and reports a "ledge" that is really the wall. `_ground_chase`
	# then zeros velocity.x every single frame (and `_gap_crossable` sees no landing
	# past the world edge, so he never hops either): a per-frame, zero-vx, zero-hop
	# FREEZE the moment the chase drives him to a wall. In a 420px-wide reachable
	# band he is ALWAYS near a wall, so this read as a statue. The boundary is a
	# solid wall, not a pit — never treat it as a ledge. Ledge protection INSIDE
	# the arena is untouched.
	if arena_max != Vector2.ZERO:
		var centre_x: float = global_position.x + HALF_BODY
		# TEST THE PROBE POINT, NOT THE BOSS'S CURRENT POSITION.
		#
		# This used to ask "is my CENTRE at the clamp limit?" (originally
		# HALF_BODY, briefly ARENA_EDGE_MARGIN). Both are the same mistake: they
		# tie a question about GEOMETRY to a question about POSITION, so the
		# moment the clamp margin changes the rule silently stops matching the
		# ground it is describing. When the clamp widened from half-a-body to
		# ARENA_EDGE_MARGIN, a boss standing anywhere in the newly-reachable
		# strip probed past the arena edge, found no floor, and froze — the very
		# freeze this block exists to prevent, just relocated inward.
		#
		# The real invariant: if the probe lands OUTSIDE the arena, it is asking
		# about the boundary wall, and a wall is not a pit. Interior pits are
		# untouched because their probe point is still inside the arena, so it
		# falls through to the real raycast below.
		var probe_x: float = centre_x + HALF_BODY * facing + LEDGE_PROBE_MARGIN * facing
		if probe_x >= arena_max.x or probe_x <= arena_min.x:
			return false
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

## True only when there is REAL higher ground ahead (a raised ledge the player
## could be standing on), within one hop's rise. Distinct from _gap_crossable,
## which is trivially true on flat ground (it accepts the floor he's already on).
##
## Founder (session 6): the final boss "still only jumps in one spot." Root
## cause (confirmed by real-physics gate): the "player above" hop used
## _gap_crossable, which returns true anywhere on flat ground — so every time
## the player merely JUMPED over/near him, the above-check fired and he pogo'd
## in place instead of chasing on the ground. This probes ONLY the band ABOVE
## his own feet: on flat ground nothing is up there (no hop -> he runs after the
## player); on a real raised ledge there is (hop -> he climbs to reach them).
func _higher_ground_ahead(facing: float) -> bool:
	var space := get_world_2d().direct_space_state
	var foot_y: float = global_position.y + BODY
	for dist: float in [140.0, 200.0, 260.0, HOP_REACH]:
		var from := Vector2(global_position.x + HALF_BODY + dist * facing, foot_y - 190.0)
		# Cast DOWN only to 40px above the current feet — a hit means ground that
		# is meaningfully higher than where he stands, i.e. an actual ledge.
		var params := PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, 150.0))
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
func _ground_chase(delta: float, speed: float, min_separation: float = 0.0) -> bool:
	# STALK the live player rather than pacing wall to wall. The founder's "the
	# bosses need to be more challenging" applies here too: this boss only ever
	# bounced between walls, so a player who stood still was never approached.
	#
	# Compared CENTRE to player, not origin to player: the origin is the body's
	# top-left, so an origin-based comparison biased every decision 40px east
	# and made him oscillate around a point he was never actually on.
	# SURGE — see the const block above. Runs across every state that calls
	# this shared function, so a burst can land during PATROL, THROW, or
	# VULNERABLE alike.
	_surge_t += delta
	if not _surge_active and _surge_t >= SURGE_INTERVAL:
		_surge_active = true
		_surge_t = 0.0
	if _surge_active:
		speed *= SURGE_SPEED_MULT
		if _surge_t >= SURGE_DURATION:
			_surge_active = false
			_surge_t = 0.0
	var pl := get_tree().get_first_node_in_group("player")
	var dx: float = 0.0
	var have_player := false
	if pl:
		have_player = true
		dx = pl.global_position.x - (global_position.x + HALF_BODY)
		if absf(dx) > TURN_DEAD_ZONE:
			direction = signf(dx)
	# Ease into the target speed so he reads as heavy, not robotic.
	var target_vx: float = speed * direction
	# HOLD / BACK OFF ONCE CLOSE ENOUGH — see CHASE_SEPARATION's own comment for
	# the live-reproduced bug this closes: unthrottled closing walked him
	# straight through his own instant-death contact radius on every engagement.
	#
	# ACTIVELY RETREATS, not just freezes, when already closer than the
	# standoff — a flat "zero the velocity" first attempt here left him camped
	# at whatever distance he happened to already be at (e.g. inherited from a
	# VULNERABLE window, which has no separation floor of its own), instead of
	# re-opening the gap. Mirrors distributor.gd's standoff-seeking philosophy:
	# a boss that only ever stops closing, never backs off, converges to
	# melee range the first time anything (a hop, a VULNERABLE cycle, a wall
	# clamp) carries him inside the standoff once.
	# HOLD STATION — DO NOT RETREAT (2026-08-19 correction to my own previous fix).
	#
	# The version shipped in the previous commit actively drove him AWAY at full
	# `speed` whenever he was inside `min_separation`. Three independent reviews
	# (Grok 4.6, Qwen3, and the founder's own repair directive: "DO NOT 'fix'
	# boss chase by ONLY ADDING STANDOFF ... It is NOT a substitute for correct
	# pursuit") plus a real gate all landed on the same objection, and the gate
	# put a number on it: tests/s6_boss_projectile_chase_test measured him
	# travelling only 217 px in 6 s while chasing a player who moved ~360 px.
	# He was not holding a standoff, he was LOSING GROUND — every time he
	# touched the separation band he reversed to full speed and then had to
	# re-accelerate from a stop, so a retreating player steadily outran him.
	# On screen that is indistinguishable from "the boss doesn't chase".
	#
	# Stopping (rather than reversing) still prevents the instant-restart body
	# contact this separation exists for, but costs him no ground: he sits at
	# the edge of the band and resumes closing the moment the player moves off.
	if have_player and min_separation > 0.0 and absf(dx) < min_separation:
		# MATCH THE PLAYER'S VELOCITY, don't stop and don't reverse.
		#
		# Stopping dead and reversing both fail, for opposite reasons, and both
		# were measured rather than argued:
		#   reverse at full speed -> he loses ground every time he clips the
		#       band and a fleeing player steadily outruns him (s6 gate: 217 px
		#       of boss travel against ~360 px of player travel).
		#   stop dead            -> he cannot re-open a gap he is already
		#       inside (e.g. carried in by the VULNERABLE window's own smaller
		#       96 px floor), so he camps at ~74 px, well inside his own
		#       instant-restart contact radius (separation gate: a 2.05 s camp).
		#
		# Holding the player's OWN velocity keeps the gap constant instead: he
		# travels exactly as far as they do, so he never falls behind, and he
		# never closes into a contact-kill either. A gentle outward bias is
		# added only when he is WELL inside the band, which is the only case
		# that actually needs correcting, and at a fraction of chase speed so
		# it never reads as fleeing.
		var player_vx: float = (pl as Node2D).global_position.x - _last_player_x
		player_vx = player_vx / maxf(delta, 0.0001)
		# SETPOINT REGULATOR, not "match whatever distance I arrived at".
		#
		# Founder, 2026-08-22: the previous rule was
		#     target_vx = clamp(player_vx, ...)   # inside the whole bubble
		#     + a 0.25*speed outward nudge only inside 0.6*min_separation
		# Grok 4.6's audit named it exactly: MATCHING the player's velocity
		# anywhere inside the band makes the SETPOINT "whatever gap I happened to
		# arrive at". Against a stationary player that looked fine (the project's
		# own separation gate measures a stationary player and saw ~122px). Against
		# a player moving ~170px/s it tracked at contact range — MEASURED at
		# 97.0% of an 18s kite spent inside 110px, once the arena walls stopped
		# artificially supplying the separation. Boss contact is
		# `GameManager.boss_contact_restart()`, an instant full-run wipe, so that
		# is a landmine on every kite, not a cosmetic issue.
		#
		# This regulates on the ERROR against min_separation instead, so the
		# formation distance IS min_separation rather than an accident:
		#   |dx| > sep  ->  player_vx PLUS a closing term: he runs FASTER than a
		#                   fleeing player (up to the speed cap), so unlike the
		#                   retreat version reverted on 2026-08-19 he does not
		#                   lose ground (that one measured 217px of boss travel
		#                   against 360px of player travel).
		#   |dx| = sep  ->  target_vx == player_vx: he holds formation AT the
		#                   standoff, travelling exactly as far as they do.
		#   |dx| < sep  ->  the term reverses to re-open the gap. He keeps FACING
		#                   the player (facing is set every frame in
		#                   _physics_process), so this reads as backing off under
		#                   guard, not as fleeing.
		#
		# HONEST LIMIT, stated rather than hidden: with `speed` at or below the
		# player's 240px/s sprint, this can stop the gap TIGHTENING against a
		# player walking straight at him but cannot RE-OPEN it — relative
		# velocity saturates at zero. Re-opening against a full-speed approach
		# needs either a higher speed (banned: no speed-only fixes) or a one-shot
		# evade. On a 1D arena floor with contact-as-instant-death there is no
		# rule that holds a standoff against a player who simply walks into him.
		var err: float = absf(dx) - min_separation
		var s_dir: float = signf(dx) if not is_zero_approx(dx) else direction
		target_vx = clampf(player_vx + speed * clampf(err / 80.0, -1.0, 1.0) * s_dir,
			-speed, speed)
	if have_player:
		_last_player_x = (pl as Node2D).global_position.x
		_last_player_y = (pl as Node2D).global_position.y
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
	_clamp_blocked = _clamp_to_arena()
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
			var at_ledge: bool = _ground_chase(delta, patrol_speed, CHASE_SEPARATION)
			# Blocked by terrain, or the player is above him -> hop. A ledge now
			# also triggers the hop: if the player is across a gap he JUMPS it
			# rather than standing at the edge forever, which keeps him
			# threatening instead of merely safe.
			# Founder, 2026-08-22 (PROMPT_CLAIM_JUMPER_STUCK_DOUBLE_JUMP):
			# "He cannot move beyond the current platform/ledge point." Same
			# root cause the Auditor had (found + fixed 2026-08-21): a hop
			# and its air-hop both fire unconditionally on ANY `is_on_wall()`
			# contact, with no ceiling on how high the chain climbs. In this
			# boss's case `_clamp_to_arena()` clamps X but NOT the top of Y
			# ("Only the FLOOR is clamped, not the ceiling"), so a hop taken
			# right at the clamped arena wall re-fires every `_hop_cooldown`
			# (0.7s) with X pinned by the clamp — he climbs in place forever
			# instead of ever getting a real grounded chase frame, which
			# reads as exactly "stuck" even though he's technically airborne
			# and "jumping". Capped the same way: don't arm a fresh hop once
			# already well above where the player could plausibly be.
			# Kimi K3 review: reading `pl.global_position.y` directly here fails
			# OPEN (gate disabled, unbounded climb returns) during any frame the
			# player node is momentarily null (death/respawn, scene transition).
			# Falling back to `_last_player_y` keeps the ceiling engaged through
			# that window instead of silently dropping it.
			var reference_y: float = pl.global_position.y if pl != null else _last_player_y
			var already_high_enough: bool = global_position.y < reference_y - 400.0
			if is_on_floor() and _hop_cooldown <= 0.0 and not already_high_enough:
				# A ledge only justifies a hop when there is somewhere to LAND.
				# Otherwise he holds the lip: still blocking the arena, never
				# suiciding into the void.
				var want_hop := is_on_wall() or (at_ledge and _gap_crossable(direction))
				# Player above -> hop ONLY if there's actually reachable ground
				# that way. Without the _gap_crossable gate this fired
				# unconditionally, and since the old _gap_crossable couldn't see
				# higher ledges it also left vx=0 — so he hopped straight up in
				# place forever instead of advancing (Kimi K3, session 4).
				# Session 6: _higher_ground_ahead, NOT _gap_crossable. The latter is
				# trivially true on flat ground, so the player merely JUMPING near him
				# fired this and he pogo'd in place ("still only jumps in one spot").
				# Now the above-hop needs a REAL raised ledge; on flat ground he chases
				# on the ground via _ground_chase instead.
				if pl and pl.global_position.y < global_position.y - 80.0 and _higher_ground_ahead(direction):
					want_hop = true
				if want_hop:
					velocity.y = HOP_VELOCITY
					# COMMIT TOWARD THE PLAYER'S X, SIZED TO THE GAP — not a blind
					# full-speed lunge. Founder (session 6): the final boss "still
					# only jumps in one spot." Root cause (Kimi K3, real-arena
					# trace): `velocity.x = patrol_speed * direction` committed the
					# full 290px/s every hop, so against a nearby/overhead player he
					# overshot by ~367px per hop, `dx` flipped, and he ping-ponged
					# ±367px around the player for a NET displacement of ~0 — a
					# stationary pogo. Worse, `_hop_cooldown` (0.7s) is shorter than
					# the 1.265s airtime, so he never gets a grounded chase frame
					# between hops; he ONLY hops. Sizing the commit to the real gap
					# (pdx / airtime, clamped to patrol_speed) lands him ON the
					# player's x when close and saturates to a genuine pursuit when
					# the player kites — no overshoot, no ping-pong. The
					# `_gap_crossable`/`at_ledge` guards above are untouched, so
					# ledge suicide stays fixed.
					var pdx: float = (pl.global_position.x - (global_position.x + HALF_BODY)) if pl else direction * HOP_REACH
					# HOLD THE SAME STANDOFF A HOP GETS, TOO (2026-08-18 live-repro
					# fix). This used to size the commit to land EXACTLY on the
					# player's x — which is precisely the contact-radius bug
					# CHASE_SEPARATION exists to close on the ground (see that
					# constant's comment); a hop bypassed it completely, and a
					# live capture's ~250px vertical gap between boss and player
					# routes almost every engagement through this exact "player
					# above" hop path. Shrinking the aim point by CHASE_SEPARATION
					# still lands him on the same platform near the player for any
					# realistically-sized ledge/gap — it just stops the landing
					# itself from being the contact-kill.
					var target_pdx: float = pdx
					if pl and absf(pdx) > CHASE_SEPARATION:
						target_pdx = pdx - signf(pdx) * CHASE_SEPARATION
					elif pl:
						target_pdx = 0.0
					velocity.x = clampf(target_pdx / HOP_AIRTIME, -patrol_speed, patrol_speed)
					_hop_cooldown = 0.7
					_air_hop_ready = true
			# DOUBLE JUMP — fires once, independent of is_on_floor(), while
			# still rising from a hop. See `_air_hop_ready`'s declaration for
			# why the landing-clear below is gated on velocity.y, not a bare
			# is_on_floor() check.
			#
			# Same height ceiling as the hop-trigger above: a hop armed the
			# frame BEFORE crossing the ceiling would otherwise still chain
			# into an ungated air-hop several frames later once velocity.y
			# decayed past -120 — this alone was enough to make the Auditor's
			# analogous first-pass fix measure as unchanged (min_y identical
			# before/after gating only the leap trigger), so it is gated here
			# too rather than assumed unnecessary.
			if _air_hop_ready and not is_on_floor() and velocity.y > -120.0 and not already_high_enough:
				velocity.y = AIR_HOP_VELOCITY
				_air_hop_ready = false
				# Grok 4.6 (2026-08-21 final-presentation review): the first
				# hop and the air-hop reuse the same sprite pose, so on a
				# quick presentation pass "two hops" can read as "one long
				# floaty jump" — undercutting the very thing being proven. A
				# cheap squash/stretch kick at the exact air-hop frame gives
				# it a visible second beat without needing a new animation.
				var kick := create_tween()
				kick.tween_property(boss_sprite, "scale", Vector2(0.75, 1.3), 0.08)
				kick.tween_property(boss_sprite, "scale", Vector2(1.0, 1.0), 0.12)
			if is_on_floor() and velocity.y >= 0.0:
				_air_hop_ready = false
			if throw_timer <= 0:
				_throw_dynamite()

		State.THROW:
			# He KEEPS COMING while he winds up and throws. Braking to a dead
			# stop here gave the player a guaranteed free gap on every attack,
			# so the fight was a series of safe windows joined by short chases.
			# Slower than patrol so the throw still reads as a commitment, but
			# never below a sprint.
			_ground_chase(delta, maxf(patrol_speed * 0.72, MIN_CHASE_SPEED), CHASE_SEPARATION)
			if state_timer <= 0.0:
				_begin_vulnerable()

		State.VULNERABLE:
			# DRIFT toward the player instead of braking to a dead stop.
			#
			# THE "final boss doesn't move / doesn't chase" ROOT CAUSE, caught by
			# a real-level per-frame probe (dual_claim_jumper_chase_probe): the
			# old `move_toward(velocity.x, 0.0, ...)` froze him at vx=0 for the
			# ENTIRE ~0.9s vulnerable window, and with throw_cooldown 0.85 + a
			# 0.4s throw that is ~65% of every cycle spent perfectly still — far
			# worse than the Distributor's old dead stop (~25% of a 7s cycle).
			# Every isolated boss gate drove a FRESH boss that spent most of its
			# short life in PATROL, so none of them sat in VULNERABLE long enough
			# to see the freeze; only the real arena did.
			#
			# 2026-08-18 (Kimi K3 audit, after the founder's 10th+ "still doesn't
			# chase"): the SEPARATION FLOOR that used to sit here was itself the
			# thing being read as "not chasing". It braked him to ZERO for up to
			# 0.7s at exactly the moment the player is closest and looking right
			# at him — ~36% of every 1.95s cycle spent stopped, at melee range —
			# and dragged the phase-1 cycle-average speed to ~227 px/s, UNDER the
			# player's 240 sprint, so simply holding run outran him.
			#
			# The floor was redundant regardless: MAX_VULN_DAMAGE_PER_WINDOW
			# already caps how much can be burst off him in a single window, which
			# is the "too easy" regression the floor was added to prevent. He now
			# keeps closing for the WHOLE window, lifting the cycle average to
			# ~273 px/s — above sprint, so he gains ground on a running player.
			# Ledge sense + arena clamp come free via _ground_chase.
			#
			# VULNERABLE_SEPARATION wired 2026-08-18 (see its own comment): NOT a
			# reintroduction of the reverted hard-freeze above — he still closes
			# continuously at VULNERABLE_DRIFT for the entire approach, same as
			# before, right up until 96px. Direct measurement
			# (tests/claim_jumper_chase_separation_test.gd) caught the real gap
			# this closes: with no floor at all here, a VULNERABLE window that
			# ran its full course left him inherited at near-zero separation the
			# instant PATROL resumed — contact-restart range, on the very first
			# frame of the next chase state, every cycle.
			_ground_chase(delta, VULNERABLE_DRIFT, VULNERABLE_SEPARATION)
			_clamp_to_arena()
			boss_sprite.modulate = Color(1.0, 0.3, 0.3, 1.0) if fmod(state_timer, 0.2) < 0.1 else Color(1.0, 0.1, 0.1, 1.0)
			if state_timer <= 0.0:
				_end_vulnerable()

## Opens the real damage window (`take_damage()` requires this state). Shrinks
## per phase like the other two bosses' windows — less free damage time as
## the rest of the fight escalates, same convention as auditor.gd.
func _begin_vulnerable() -> void:
	current_state = State.VULNERABLE
	_vuln_damage = 0
	state_timer = maxf(0.45, vulnerable_time - 0.15 * (current_phase - 1))

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
	# DeepSeek v4 Pro audit (2026-08-21 final-presentation residual):
	# `_air_hop_ready` is only armed/fired/cleared inside PATROL, so a hop
	# taken right as this fires could leave it stale true across THROW and
	# VULNERABLE, then unexpectedly fire on the first PATROL frame back. Not
	# a soft-lock (the boost is harmless), but no state should carry another
	# state's mid-air promise — clear it on every transition out of PATROL.
	_air_hop_ready = false
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
		return
	_check_phase_change()
	# Per-window damage cap: once the player has stripped MAX_VULN_DAMAGE_PER_WINDOW
	# this window, he shakes it off and returns to the hunt — no burst-down. Forces
	# ceil(HP/cap) separate windows, so the kill has to be EARNED across the fight
	# (founder: "too easy to defeat"). _check_phase_change first so a phase step
	# still lands on this hit.
	_vuln_damage += amount
	if _vuln_damage >= MAX_VULN_DAMAGE_PER_WINDOW:
		_end_vulnerable()

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
		# SPAWN GRACE — see BossBase's own const block.
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
