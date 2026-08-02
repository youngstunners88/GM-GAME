extends BossBase
## Boss 2 — The Distributor (Crystalline Bureaucrat). A bloated crystal golem
## hoarding three ETH reward orbs he refuses to share (the DIAMONDS protocol's
## three payout pools).
##
## Design: Grok 4.5 brief, docs/model-responses/2026-07-30-grok-distributor-spectacle.md.
## Closes the Stage 2 gap flagged in the 2026-07-30 audit — he had real phase
## thresholds but was mechanically thinner than the Auditor: no movement
## threat at all (float + ranged only), no token-gated spectacle, and no
## skill-expression moment.
##
## Three systems answer that, without copying either other boss:
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
## Damage window is still the post-throw VULNERABLE state, and it now shrinks
## per phase (the Claim Jumper pattern) so there is less free damage time as
## the fight escalates.

const BOSS_ID := "crystal"
const ORB := preload("res://src/boss/boss_projectile.tscn")

enum Phase { PATROL, GRAVITY_TELL, HOARD_GRAVITY, SHARD_THROW, VULNERABLE }

@export var patrol_speed: float = 80.0
@export var throw_cooldown: float = 2.0
@export var vulnerable_time: float = 1.8
## How fast the field drags the player, in px/s at the centre of the field.
##
## THIS IS A DISPLACEMENT SPEED, NOT A VELOCITY INJECTION — and that
## distinction is the whole mechanic. Two earlier versions wrote
## `player.velocity.x += strength * delta` and BOTH moved the player exactly
## 0.0 px, measured in tests/distributor_behaviour_test.gd:
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
var throw_timer: float = 0.0
var state_timer: float = 0.0
var direction: float = 1.0
# R7/R8 (2026-08-08): the Distributor now FLOATS on a levitating diamond disc
# instead of walking with gravity. Old behaviour applied `velocity.y += 980`
# every frame with no floor/bounds guarantee, so a pit in the L2 arena let him
# fall out forever and soft-lock the fight (Kimi audit: CRITICAL). Floating
# removes that class of bug categorically AND delivers the "bigger, scarier,
# levitating diamonds" redesign. Numbers from the Grok float-feel brief.
var _hover_home_y: float = 0.0     # captured from spawn on first physics frame
var _arena_center_x: float = 0.0
var _anchored: bool = false
var _bob_t: float = 0.0
var _disc: Polygon2D = null
const HOVER_BOB_AMP := 12.0        # px
const HOVER_BOB_PERIOD := 2.4      # s
const HOVER_RISE := 180.0          # float this far ABOVE the spawn (off the floor)
const HOVER_BAND := 70.0           # max +/- Y drift from home before clamp
const FLOAT_DRIFT_SPEED := 110.0   # px/s horizontal pursuit
const FLOAT_DEADZONE := 80.0       # don't jitter when roughly above the player
const ARENA_HALF_W := 300.0        # clamp X within +/- this of the spawn anchor
const BOSS_SCALE := 1.7            # "much larger, reads as a final boss"
## Counts how many gravity-to-throw cycles have run, so the pull and the volley
## alternate instead of the pull firing every single time.
var _cycles: int = 0
var _tell_duration: float = 0.65

## --- Forced Distribution bookkeeping ---
## Orbs alive from the CURRENT volley, and how many of them the player flipped.
## Redirecting every orb in one volley is the POOL DRAIN payoff.
##
## Every orb carries the id of the volley it came from. Without that, an orb
## left over from the PREVIOUS volley (they live 4s, volleys are ~2s apart)
## would count toward the current volley's tally and fire a false POOL DRAIN.
var _volley_id: int = 0
var _volley_size: int = 0
var _volley_redirected: int = 0
## Damage already taken from redirects in this volley. Capped, because
## uncapped it is degenerate: a phase-3 volley is 5 orbs, and 5 arrival hits
## plus the POOL DRAIN bonus is 6 damage against a 7 HP boss — one good
## volley would end the fight.
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

## Assigned, NOT redeclared: EnemyBase already owns `sprite`, and shadowing
## it is a parse error that leaves this entire script unattached.
@onready var boss_sprite: BossSprite = $ColorRect
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var hitbox: Area2D = $Hitbox
@onready var hitbox_shape: CollisionShape2D = $Hitbox/CollisionShape2D

func _ready() -> void:
	max_health = 7
	health = 7
	phase_thresholds = [4, 2]
	add_to_group("enemy")
	add_to_group("boss")
	boss_sprite.color = Color(0.3, 0.2, 0.6, 1.0)
	boss_sprite.size = Vector2(96, 96)
	collision.position = Vector2(48, 48)
	hitbox.position = Vector2(48, 48)
	# Scale the whole body (sprite + collision + hitbox together, so the
	# hitbox never desyncs from the art) — R8 "much larger". A levitating
	# diamond disc is drawn under him in _add_levitating_disc().
	scale = Vector2(BOSS_SCALE, BOSS_SCALE)
	_add_levitating_disc()
	hitbox_shape.shape = collision.shape
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	hitbox.area_entered.connect(_on_hitbox_area_entered)
	# Detect overlaps for the WHOLE fight, not just the vulnerable window.
	# Incoming damage is gated separately by `monitorable` + take_damage's own
	# VULNERABLE check, so leaving this on is safe and it is what makes
	# walking (or being dragged) into the boss actually cost the player.
	hitbox.set_deferred("monitoring", true)
	boss_display_name = "The Distributor"
	throw_timer = throw_cooldown
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

	# Capture the hover anchor on the first frame — the level sets our
	# global_position (boss_spawn) before add_child, so it is valid here.
	if not _anchored:
		_anchored = true
		_arena_center_x = global_position.x
		_hover_home_y = global_position.y - HOVER_RISE

	throw_timer -= delta
	state_timer -= delta
	_bob_t += delta

	match current_phase_state:
		Phase.PATROL:
			# Drift toward the player instead of a fixed patrol, with a deadzone
			# so he doesn't jitter when already overhead. No gravity — floats.
			var pdx := _player_dx()
			if absf(pdx) > FLOAT_DEADZONE:
				velocity.x = signf(pdx) * FLOAT_DRIFT_SPEED
				boss_sprite.scale.x = 1.0 if pdx > 0.0 else -1.0
			else:
				velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
			_apply_float(delta)
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
			# does NOT pull yet — this is pure reaction time.
			velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
			_apply_float(delta)
			queue_redraw()
			if state_timer <= 0.0:
				_begin_hoard_gravity()

		Phase.HOARD_GRAVITY:
			velocity.x = move_toward(velocity.x, 0.0, 200.0 * delta)
			_apply_float(delta)
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
			velocity.x = move_toward(velocity.x, 0.0, 100.0 * delta * 60.0)
			_apply_float(delta)
			if state_timer <= 0.0:
				_begin_vulnerable()

		Phase.VULNERABLE:
			velocity.x = move_toward(velocity.x, 0.0, 100.0 * delta * 60.0)
			_apply_float(delta)
			boss_sprite.modulate = Color(1.0, 0.3, 0.3, 1.0) if fmod(state_timer, 0.3) < 0.15 else Color(1.0, 0.1, 0.1, 1.0)
			if state_timer <= 0.0:
				_end_vulnerable()

## Signed horizontal distance to the player (0 if none). Used for float pursuit.
func _player_dx() -> float:
	var pl := get_tree().get_first_node_in_group("player")
	if pl == null:
		return 0.0
	return pl.global_position.x - global_position.x

## Drive vertical hover toward the bob target and move; then HARD-CLAMP X and Y
## into the arena band so the boss can NEVER leave the fight (R7). No gravity,
## no floor dependency — he floats. Replaces the old `velocity.y += 980` +
## bare move_and_slide() in every phase.
func _apply_float(delta: float) -> void:
	var target_y := _hover_home_y + sin(_bob_t * TAU / HOVER_BOB_PERIOD) * HOVER_BOB_AMP
	# Ease Y toward the bob target rather than teleporting, so knockback/pull
	# interactions still read smoothly.
	velocity.y = (target_y - global_position.y) * 6.0
	move_and_slide()
	# Belt-and-braces: clamp position every frame. Even if something (a future
	# knockback, a physics quirk) shoves him, he is snapped back into the band.
	global_position.x = clampf(global_position.x,
		_arena_center_x - ARENA_HALF_W, _arena_center_x + ARENA_HALF_W)
	global_position.y = clampf(global_position.y,
		_hover_home_y - HOVER_BAND, _hover_home_y + HOVER_BAND)

## The levitating diamond disc he rides — a flat cyan gem drawn under the body,
## purely cosmetic (no collision). Sells "floats on diamonds" (R8) and bobs a
## touch deeper than the body so it reads as the lift source.
func _add_levitating_disc() -> void:
	_disc = Polygon2D.new()
	# A wide, flat diamond centred under the 96px body box (local space; node
	# scale enlarges it with everything else).
	_disc.polygon = PackedVector2Array([
		Vector2(48, 96), Vector2(96, 112), Vector2(48, 128), Vector2(0, 112)])
	_disc.color = Color(0.5, 0.95, 1.6, 0.85)
	_disc.z_index = -1
	add_child(_disc)
	var glow := Polygon2D.new()
	glow.polygon = PackedVector2Array([
		Vector2(48, 90), Vector2(108, 112), Vector2(48, 134), Vector2(-12, 112)])
	glow.color = Color(0.4, 0.85, 1.4, 0.25)
	glow.z_index = -2
	add_child(glow)

## Cadence between actions, tightening per phase.
func _cadence() -> float:
	return maxf(1.0, throw_cooldown - 0.4 * (current_phase - 1))

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

## Drag the player toward the hoard. Deliberately injected into velocity
## rather than teleporting the player: the player controller's own
## move_toward() then fights it every frame, so holding "away" genuinely
## resists the pull instead of the boss overriding player input outright.
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
	var centre := global_position + Vector2(48, 48)
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
		# Correct today only by accident (the level root sits at origin).
		get_parent().add_child(orb)
		orb.global_position = global_position + Vector2(48, 20)
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
	boss_sprite.color = Color(1.0, 0.2, 0.2, 1.0)
	# `monitoring` is already true for the whole fight; only expose the boss
	# to incoming damage here.
	hitbox.set_deferred("monitorable", true)

func _end_vulnerable() -> void:
	boss_sprite.modulate = _phase_tint
	boss_sprite.color = Color(0.3, 0.2, 0.6, 1.0)
	current_phase_state = Phase.PATROL
	throw_timer = _cadence()
	# Only `monitorable` is gated — `monitoring` stays ON for the whole fight
	# (see _ready). Toggling it off here meant the boss's own contact damage
	# never fired outside the vulnerable window, so HOARD GRAVITY could drag
	# the player straight into his body for free. Kimi audit finding F2.
	hitbox.set_deferred("monitorable", false)
	queue_redraw()

# --- TELEGRAPH DRAWING ---------------------------------------------------

## Two dashed rings collapsing onto him during the tell, then the live field
## boundary while the pull is active. Procedural _draw keeps this asset-free.
func _draw() -> void:
	if is_dead:
		return
	var centre := Vector2(48, 48)
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
	tween.tween_property(boss_sprite, "modulate", Color(10, 10, 10, 1), 0.05)
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
	# and lose a life — AFTER the level was already won. Kimi audit F5.
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
		body.take_damage(1)
		BossVoiceSystem.say(self, BOSS_ID, "mock")

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("projectile"):
		take_damage(1)
