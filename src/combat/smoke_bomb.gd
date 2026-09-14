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
## This is a REAL replacement, not a reskinned axe, and the difference is
## deliberate in three places a player can feel:
##   * it ARCS. The axe flies dead flat; a thrown bomb falls. That alone reads
##     as "lobbed object" rather than "hurled blade" before any art exists.
##   * it TUMBLES SLOWLY. The axe spins fast to read as a blade; a bomb turns
##     lazily end over end.
##   * it PUFFS. On impact it bursts into the same green-white smoke the Blaze
##     auto-puff uses, so the hit reads as smoke rather than metal.
##
## Collision is intentionally IDENTICAL to axe.gd — layer 7 (Projectiles),
## masking Enemies (bit 3), Hazards (bit 6, rolling boulders) and Destructible.
## It deliberately does NOT mask World, so a low throw skims the ground instead
## of despawning on the first floor tile. Matching the axe exactly means every
## Stage 1 enemy, boulder and breakable block that the axe could hit is still
## hittable — the swap changes the weapon, not the level's solvability.

const PUFF_SCENE := preload("res://src/effects/smoke_puff.tscn")

var direction: float = 1.0        ## -1 = left, +1 = right
var speed: float = 520.0          ## slower than the axe's 620: it is lobbed
var vertical: float = 0.0         ## px/s initial vertical drift (fan spread)
var damage: int = 1               ## same as the base axe — balance unchanged
var lifetime: float = 1.6         ## longer than the axe's 1.2 to offset the arc

## Arc. A bomb is thrown, not thrown-at — a modest gravity is what separates it
## from a blade without making it hard to aim. At 520 px/s and 560 px/s² a
## throw drops roughly 55 px over its first half-second, which crosses a screen
## of enemies comfortably while still visibly falling.
const GRAVITY := 560.0
## Slight upward launch so the arc peaks ahead of the player rather than
## starting to drop immediately — the shape of an underarm lob.
const LAUNCH_LIFT := -120.0
const PUFF_COUNT := 5
const PUFF_SPEED := 90.0

var _vy: float = 0.0
var _spin: float = 0.0

@onready var _body: ColorRect = $Body
@onready var _fuse: ColorRect = $Fuse


func _ready() -> void:
	add_to_group("projectile")
	_vy = LAUNCH_LIFT + vertical
	body_entered.connect(_on_body_entered)
	# Some enemies (e.g. HostileVine) are a Node2D with an Area2D hitbox rather
	# than a physics body — those only surface through area_entered. Same
	# reasoning as axe.gd; dropping this would make vines immune in Stage 1.
	area_entered.connect(_on_area_entered)
	var t := get_tree().create_timer(lifetime)
	t.timeout.connect(_fizzle)


func _physics_process(delta: float) -> void:
	_vy += GRAVITY * delta
	position.x += direction * speed * delta
	position.y += _vy * delta
	# Lazy end-over-end tumble — a quarter of the axe's spin rate, so the two
	# weapons read differently in flight even at a glance.
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


## The hit. A ring of green-white smoke where the bomb landed — the whole point
## of the weapon, and why the impact must never be the axe's metal "hit" ping
## alone.
func _burst() -> void:
	_spawn_smoke()
	AudioManager.play_sfx_at("hit", global_position)
	ScreenShake.light()
	_despawn()


## Ran out of air without hitting anything — it still puffs, because a thrown
## smoke bomb that silently vanishes looks like a bug. Smaller burst than a
## connect so a hit still reads as the louder event.
func _fizzle() -> void:
	if not is_instance_valid(self):
		return
	_spawn_smoke(3)
	_despawn()


func _spawn_smoke(count: int = PUFF_COUNT) -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	for i in count:
		var puff := PUFF_SCENE.instantiate()
		# HARMLESS: these are the impact VFX, not a second damage source.
		# Without this the burst would re-damage whatever the bomb just hit
		# (smoke_puff is itself a damaging projectile for Blaze Mode), which
		# would silently make the Stage 1 weapon several times stronger than
		# the axe it replaces.
		puff.harmless = true
		puff.speed = PUFF_SPEED
		puff.lifetime = 0.7
		var ang := TAU * float(i) / float(count)
		puff.direction = Vector2(cos(ang), sin(ang) * 0.7)
		puff.global_position = global_position
		root.add_child(puff)


func _despawn() -> void:
	if is_instance_valid(self):
		queue_free()
