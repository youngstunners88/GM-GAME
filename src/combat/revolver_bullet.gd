extends Area2D
## GOLDEN REVOLVER BULLET — Lil Blunt's Stage 3 attack.
##
## Founder lock (2026-09-16, golden Remington reference art): Stage 3 (Gold
## Rush) is where Lil Blunt picks up the golden revolver dropped from the
## smashed bus after the Stage 2 boss (see `stage2_revolver_reveal.gd`), so
## his base attack there is a fired bullet, not a thrown axe.
##
## Founder's explicit instruction: "when he grabs the axe and the hammer just
## changes accordingly" — the pickaxe/bigaxe power-up tiers keep doing exactly
## what they already do to `axe.gd` (same damage numbers, same boss-damage
## caps, same big-tier piercing), they just read as an upgraded SHOT instead
## of a bigger thrown weapon. So this mirrors axe.gd's tier constants exactly
## rather than inventing new balance:
##   default  1 dmg  | small streak            | despawns
##   PICKAXE  6 dmg  | bigger, brighter streak | despawns
##   BIG AXE  8 dmg  | large piercing slug     | PIERCES
##
## Collision is intentionally IDENTICAL to axe.gd — layer 7 (Projectiles),
## masking Enemies (bit 3), Hazards (bit 6, rolling boulders) and Destructible.
## Every Stage 3 enemy, boulder and breakable block the axe could hit stays
## hittable — the swap changes the weapon's SKIN, not the level's solvability.
##
## Unlike the axe, a fired bullet does not spin and does not arc — it is a
## shot, not a throw. Speed is well above the axe's 620 so it reads as
## instantaneous gunfire rather than a lobbed object.

var direction: float = 1.0        ## -1 = left, +1 = right
var speed: float = 900.0
var vertical: float = 0.0         ## px/s constant drift (fan spread only)
var damage: int = 1
var lifetime: float = 1.0

## Mirrors axe.gd's BIG AXE tier exactly (same numbers — see that file's
## founder-lock comment for the full history of why these are what they are).
var big: bool = false
const BIG_DAMAGE := 8
const BIG_BOSS_DAMAGE := 4
const BIG_SCALE := 2.2

## Mirrors axe.gd's PICKAXE tier exactly.
var heavy: bool = false
const PICK_DAMAGE := 6
const PICK_BOSS_DAMAGE := 2
const PICK_SCALE := 1.5

@onready var _slug: ColorRect = $Slug
@onready var _core: ColorRect = $Core

func _ready() -> void:
	add_to_group("projectile")
	if heavy and not big:
		damage = PICK_DAMAGE
		scale = Vector2(PICK_SCALE, PICK_SCALE)
	if big:
		damage = BIG_DAMAGE
		scale = Vector2(BIG_SCALE, BIG_SCALE)
	body_entered.connect(_on_body_entered)
	# Some enemies (e.g. HostileVine) are a Node2D with an Area2D hitbox rather
	# than a physics body — those only surface through area_entered. Same
	# reasoning as axe.gd; dropping this would make vines immune in Stage 3.
	area_entered.connect(_on_area_entered)
	AudioManager.play_sfx_at("gunshot", global_position)
	# Muzzle flash at the barrel — the slug itself is a small fast streak
	# (deliberately, same "default tier is subtle" philosophy as axe.gd's
	# default throw), so without a flash the shot barely reads as gunfire.
	EffectSpawner.burst("coin_sparkle", global_position)
	var t := get_tree().create_timer(lifetime)
	t.timeout.connect(_despawn)

func _physics_process(delta: float) -> void:
	# Flat, fast travel — a shot, not a lob. `vertical` is a constant (not
	# accelerating) drift term for the fan-spread power-up, exactly like
	# axe.gd and smoke_bomb.gd: no gravity term exists here at all.
	position.x += direction * speed * delta
	position.y += vertical * delta

func _on_body_entered(body: Node2D) -> void:
	if _hit(body):
		_impact()
	elif body.has_method("smash"):        # rolling boulder
		body.smash()
		_impact()
	elif _try_break_block(body):
		_impact()
	elif big and _smash_destructible(body):
		pass

func _on_area_entered(area: Area2D) -> void:
	if _hit(area) or _hit(area.get_parent()):
		_impact()
	elif _try_break_block(area) or _try_break_block(area.get_parent()):
		_impact()
	elif big and (_smash_destructible(area) or _smash_destructible(area.get_parent())):
		pass

## Break a `breakable`-group block. Same narrow scope as axe.gd's version.
func _try_break_block(node: Node) -> bool:
	if node != null and node.is_in_group("breakable") and node.has_method("break_block"):
		node.break_block()
		AudioManager.play_sfx_at("hit", global_position)
		return true
	return false

## Big-tier only: break scenery in the flight path without stopping the shot.
## Mirrors axe.gd's _smash_destructible exactly.
func _smash_destructible(node: Node) -> bool:
	if node == null:
		return false
	if node.has_method("take_structural_damage"):
		node.take_structural_damage(1)
		AudioManager.play_sfx_at("hit", global_position)
		ScreenShake.light()
		return true
	if node.is_in_group("breakable") and node.has_method("break_block"):
		node.break_block()
		return true
	return false

## Damages `node` if it's a takeable enemy; returns whether a hit landed.
func _hit(node: Node) -> bool:
	if node and node.is_in_group("enemy") and node.has_method("take_damage"):
		var dmg := damage
		if big and node.is_in_group("boss"):
			dmg = BIG_BOSS_DAMAGE
		elif heavy and node.is_in_group("boss"):
			dmg = PICK_BOSS_DAMAGE
		node.take_damage(dmg)
		# Shared "vo_attack" id and cooldown, same as every other hit path
		# (axe / smoke bomb / flame), so one cooldown absorbs fan multi-hits.
		AudioManager.play_bark("vo_attack", 3.0)
		return true
	return false

func _impact() -> void:
	# "explosion" (not "smoke_explosion" — that's the smoke bomb's own green
	# identity) is the project's existing generic hit-impact burst, already
	# used for enemy deaths and boss projectiles: a quick orange-gold flash
	# that reads as a bullet strike, not a bomb.
	EffectSpawner.burst("explosion", global_position)
	if big:
		AudioManager.play_sfx_at("bigaxe_impact", global_position)
		ScreenShake.heavy()
		# BIG tier pierces, mirroring axe.gd's big-axe behaviour exactly.
		return
	if heavy:
		AudioManager.play_sfx_at("bigaxe_impact", global_position)
		ScreenShake.medium()
		_despawn()
		return
	AudioManager.play_sfx_at("hit", global_position)
	_despawn()

func _despawn() -> void:
	if is_instance_valid(self):
		queue_free()
