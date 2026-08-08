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
	hitbox.position = Vector2(BODY / 2.0, BODY / 2.0)
	_build_diamond_surfboard()
	hitbox_shape.shape = collision.shape
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
				# Alternate: pull, then volley, then pull... so the fight has a
				# rhythm instead of one attack on repeat.
				if _cycles % 2 == 0:
					_begin_gravity_tell()
				else:
					_throw_shards()
				_cycles += 1

		Phase.GRAVITY_TELL:
			# Orbs snap inward, two dashed rings collapse onto him. The field
			# does NOT pull yet — this is pure reaction time. He keeps closing
			# while he winds up; a boss that brakes to a halt to telegraph is a
			# boss you can ignore.
			_hover_pursue(delta, 0.35)
			queue_redraw()
			if state_timer <= 0.0:
				_begin_hoard_gravity()

		Phase.HOARD_GRAVITY:
			_hover_pursue(delta, 0.25)
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
			_hover_pursue(delta, 0.45)
			if state_timer <= 0.0:
				_begin_vulnerable()

		Phase.VULNERABLE:
			_hover_brake(delta)
			# Vulnerability is telegraphed by a soft CYAN shimmer, not by
			# turning him red — red is reserved for the hit flash so a landed
			# blow actually reads (founder E3).
			boss_sprite.modulate = (Color(0.75, 1.15, 1.35, 1.0)
				if fmod(state_timer, 0.34) < 0.17 else _phase_tint)
			if state_timer <= 0.0:
				_end_vulnerable()

## Free 2D hover pursuit — the "levitate in any direction" the founder asked
## for, and the reason he can no longer fall anywhere.
const HOVER_ACCEL: float = 430.0
const HOVER_MAX: float = 265.0
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
const HOVER_CLEARANCE: float = 60.0
const HOVER_ABOVE: float = BODY + HOVER_CLEARANCE
## Hard arena clamp, set by the level when the fight starts. Zero size = unset,
## in which case only the flight model applies.
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

func _hover_pursue(delta: float, speed_scale: float = 1.0) -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p:
		var target: Vector2 = p.global_position + Vector2(0.0, -HOVER_ABOVE)
		var to: Vector2 = target - global_position
		velocity = velocity.move_toward(
			to.normalized() * HOVER_MAX * speed_scale, HOVER_ACCEL * delta)
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
func _clamp_to_arena() -> void:
	if arena_max == Vector2.ZERO:
		return
	global_position.x = clampf(global_position.x, arena_min.x, arena_max.x)
	global_position.y = clampf(global_position.y, arena_min.y, arena_max.y)

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
		orb.homing = 0.6 if current_phase >= 2 else 0.0
		orb.tint = Color(0.6, 0.8, 1.0, 1.0)  # ETH blue
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
		GameManager.last_damage_source = BOSS_ID
		BossVoiceSystem.say(self, BOSS_ID, "mock")
		# Founder stakes rule: ANY boss touch returns Lil Blunt to the START of
		# the level and forfeits the whole run's score — not hurt-and-continue.
		# See GameManager.boss_contact_restart().
		GameManager.boss_contact_restart()

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("projectile"):
		take_damage(1)
