extends Area2D
## SMOKE BOMB — Lil Blunt's Stage 1 attack.
##
## Founder lock (2026-09-14, PROMPT_2026-09-14_STAGE1_SMOKE_BOMBS_NOT_AXES):
## Lil Blunt does NOT throw axes in Stage 1. He only finds the pickaxe/mining
## gear after beating the Stage 1 Tax Collector (GOV VAULT loot → Crystal
## Caverns), so a thrown axe in Stage 1 is a weapon he does not own yet. The
## Stage 1 attack is a small thrown smoke bomb instead — which is also the
## weapon that actually matches the marijuana-smoke identity.
##
## Founder playtest correction (2026-09-16, overrides the 2026-09-14 build):
## the bomb travels FLAT, exactly like the axe — no gravity, no lob, no dip.
## The founder explicitly rejected an arc as the way to distinguish this
## weapon from the axe. The distinction the player actually feels now is:
##   * it PUFFS. On impact it bursts into a visible green-white smoke
##     explosion, so the hit reads as smoke rather than metal.
##   * optional slow tumble in flight (small, cosmetic — never used to hide
##     any vertical drift).
##
## Collision is intentionally IDENTICAL to axe.gd — layer 7 (Projectiles),
## masking Enemies (bit 3), Hazards (bit 6, rolling boulders) and Destructible.
## It deliberately does NOT mask World, so a low throw skims the ground instead
## of despawning on the first floor tile. Matching the axe exactly means every
## Stage 1 enemy, boulder and breakable block that the axe could hit is still
## hittable — the swap changes the weapon, not the level's solvability.

var direction: float = 1.0        ## -1 = left, +1 = right
var speed: float = 640.0          ## matches/beats the axe's 620 — a shot, not a lob
var vertical: float = 0.0         ## px/s constant vertical drift (fan spread only)
var damage: int = 1               ## same as the base axe — balance unchanged
var lifetime: float = 1.2         ## same as the axe's — no arc to compensate for

var _spin: float = 0.0

@onready var _body: ColorRect = $Body
@onready var _fuse: ColorRect = $Fuse


func _ready() -> void:
	add_to_group("projectile")
	body_entered.connect(_on_body_entered)
	# Some enemies (e.g. HostileVine) are a Node2D with an Area2D hitbox rather
	# than a physics body — those only surface through area_entered. Same
	# reasoning as axe.gd; dropping this would make vines immune in Stage 1.
	area_entered.connect(_on_area_entered)
	var t := get_tree().create_timer(lifetime)
	t.timeout.connect(_fizzle)


## Straight-line travel — identical shape to axe.gd's flat trajectory.
## `vertical` is a constant (not accumulated) so Y velocity never grows after
## spawn: no gravity term exists here at all.
func _physics_process(delta: float) -> void:
	position.x += direction * speed * delta
	position.y += vertical * delta
	# Small cosmetic tumble only — a quarter of the axe's spin rate so the two
	# weapons still read differently in flight. Never used to mask a dip:
	# there is no vertical acceleration to mask.
	_spin += delta * 5.0 * signf(direction)
	rotation = _spin


func _on_body_entered(body: Node2D) -> void:
	if _hit(body):
		_burst()
	elif body.has_method("smash"):        # rolling boulder
		body.smash()
		_burst()
	elif _try_break_block(body):
		_burst()


func _on_area_entered(area: Area2D) -> void:
	# The hitbox Area2D itself usually isn't the enemy — the enemy is its owner.
	if _hit(area) or _hit(area.get_parent()):
		_burst()
	elif _try_break_block(area) or _try_break_block(area.get_parent()):
		_burst()


## Break a `breakable`-group block. Same narrow scope as the axe's version: it
## never touches take_structural_damage props (ladders), which stay big-axe
## only so a starter weapon cannot shear a vault/escape ladder.
func _try_break_block(node: Node) -> bool:
	if node != null and node.is_in_group("breakable") and node.has_method("break_block"):
		node.break_block()
		AudioManager.play_sfx_at("hit", global_position)
		return true
	return false


## Damages `node` if it's a takeable enemy; returns whether a hit landed.
## No boss special-case: the base axe dealt a flat 1 to everything including
## bosses, and the smoke bomb is the same weight class, so the Auditor fight
## keeps exactly the number of hits it had before this swap.
func _hit(node: Node) -> bool:
	if node and node.is_in_group("enemy") and node.has_method("take_damage"):
		node.take_damage(damage)
		# Shared "vo_attack" id and 3.0s cooldown, matching every other hit path
		# (axe / flame / fire-breath), so one cooldown absorbs fan multi-hits
		# collectively rather than per-weapon.
		AudioManager.play_bark("vo_attack", 3.0)
		return true
	return false


## The hit. A visible green smoke EXPLOSION where the bomb landed — the whole
## point of the weapon, and why the impact must never be the axe's metal "hit"
## ping alone. The explosion is pure CPUParticles2D VFX: it has no collision
## shape and cannot deal damage, so it can never re-open the "impact burst
## re-damages the target" trap a previous build had with a reused damaging
## projectile as the impact effect.
func _burst() -> void:
	_spawn_explosion()
	AudioManager.play_sfx_at("hit", global_position)
	ScreenShake.light()
	_despawn()


## Ran out of air without hitting anything — it still puffs, because a thrown
## smoke bomb that silently vanishes looks like a bug.
func _fizzle() -> void:
	if not is_instance_valid(self):
		return
	_spawn_explosion()
	_despawn()


func _spawn_explosion() -> void:
	EffectSpawner.burst("smoke_explosion", global_position)


func _despawn() -> void:
	if is_instance_valid(self):
		queue_free()
