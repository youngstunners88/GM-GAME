extends Area2D
## Thrown axe — Lil Blunt's base attack. Flies flat in the facing direction,
## spinning as it travels; kills a minion on contact and shatters boulders.
## A vertical component lets the purple-power fan spread axes up and down.
##
## Collision: layer 7 (Projectiles), masks Enemies (bit 3) + Hazards (bit 6, the
## rolling-boulder layer). It deliberately does NOT mask World, so a low throw
## skims the ground instead of despawning on the first floor tile.

var direction: float = 1.0        ## -1 = left, +1 = right
var speed: float = 620.0
var vertical: float = 0.0         ## px/s vertical drift (fan spread)
var damage: int = 1
var lifetime: float = 1.2
var _spin: float = 0.0

## BIG AXE (founder, 2026-08-04): "when he throws his axe it is much larger
## and more powerful so that it immediately kills any enemy with one strike
## but that it also damages the ladder and anything that comes in its way. Of
## course it shouldnt kill the boss with one strike but must be able to do
## more damage than Lil Blunt's normal strikes."
##
## So the big axe is a PIERCING projectile: it does not despawn on its first
## kill, it one-shots ordinary enemies, it smashes destructibles it passes
## through, and it does BOSS_DAMAGE to a boss — more than the normal 1, but
## deliberately less than any boss's max health (Auditor 10, Distributor 14,
## Claim Jumper 18) so it can never be a one-hit boss kill.
##
## OWNER-RAGE RESIDUAL (2026-08-18): a same-day session added real impact
## feedback (bigaxe_impact SFX, heavy screenshake, boss hitstop — kept below,
## it's good work) but in doing so reset these two numbers back to their
## PRE-fix values (1.95/5/3), silently undoing the previous session's
## increase that a live capture had proven necessary (at 1.95 the thrown
## axe still read as marginal next to the base throw). Restored to the
## measured values — do not lower them again without a fresh capture
## showing they're excessive.
var big: bool = false
const BIG_DAMAGE := 8
const BIG_BOSS_DAMAGE := 4
## The BIG axe is drawn as an actual big axe now, so the projectile is scaled
## against ITS pixel size, not the pickaxe's. sprite_item_bigaxe.png is 40x44
## against the pickaxe's 18x34, and the NORMAL thrown axe reuses the pickaxe
## sprite at 0.5 scale — a ~9x17px projectile, nearly invisible at 1280x720.
## 2.6 renders the thrown big axe at ~104x114px: unmistakably a different,
## larger, heavier weapon than the base throw. The circle hitbox scales with
## it, which only makes the power-fantasy throw MORE forgiving for the
## player, never less fair to them.
const BIG_SCALE := 2.6
const BIG_SPEED_MULT := 1.15
## Art for the upgraded axe. Until now the "big axe" was the PICKAXE sprite
## blown up and tinted gold — which is also why the big-axe PICKUP and the
## pickaxe pickup were indistinguishable on Stage 3 (founder T5).
const BIG_ART := "res://src/assets/sprites/sprite_item_bigaxe.png"

## PICKAXE TIER — the middle weight class.
##
## Founder (2026-08-19): "The axe is still exactly the same as it doesnt have a
## more powerful impact than Lil Blunt's default axes", with a screenshot whose
## HUD reads PICKAXE; and, next to it, "the strange thing is that this HAMMER
## has precisely the correct impact ... so I dont understand why I have to ask
## countless times for you to fix the other axe".
##
## He is comparing two DIFFERENT weapons, and he is right about both. The
## "hammer" is the big axe (sprite_item_bigaxe.png reads as a mallet in
## flight) and it already has the full heavy stack: bigaxe_impact SFX,
## ScreenShake.heavy(), boss hitstop, 2.6x scale, 8 damage. The "axe" he is
## complaining about is what he throws while the PICKAXE tool is active — and
## combat_handler._spawn_axe only ever set `big` from the "bigaxe" power-up, so
## a pickaxe throw was byte-for-byte the DEFAULT axe: 1 damage, "hit" ping,
## 0.5-scale sprite. It did not feel more powerful because it was not more
## powerful. Every previous pass tuned the big axe, which was never the weapon
## he was pointing at.
##
## The pickaxe now lands as a genuine middle tier, deliberately NOT a big-axe
## clone (the directive: "The power axe and hammer can have different
## identities while sharing the principle of heavy impact"):
##   default  1 dmg  | 0.5x | "hit" ping        | no shake     | no hitstop | despawns
##   PICKAXE  4 dmg  | 1.5x | "bigaxe_impact"   | medium shake | no hitstop | despawns
##   BIG AXE  8 dmg  | 2.6x | "bigaxe_impact"   | heavy shake  | hitstop    | PIERCES
## So the pickaxe reads as a solid miner's strike, and piercing + hitstop stay
## the big axe's exclusive signature.
var heavy: bool = false
const PICK_DAMAGE := 4
const PICK_BOSS_DAMAGE := 2
const PICK_SCALE := 1.5
const PICK_SPEED_MULT := 1.08

@onready var sprite: Sprite2D = $Sprite

func _ready() -> void:
	add_to_group("projectile")
	# `big` wins if both are somehow set — it is the strictly stronger tier.
	if heavy and not big:
		damage = PICK_DAMAGE
		speed *= PICK_SPEED_MULT
		scale = Vector2(PICK_SCALE, PICK_SCALE)
	if big:
		damage = BIG_DAMAGE
		speed *= BIG_SPEED_MULT
		scale = Vector2(BIG_SCALE, BIG_SCALE)
		if sprite:
			sprite.texture = load(BIG_ART)
		# No gold tint any more — the art carries its own gold collar, and
		# tinting on top of it washed the steel out.
		modulate = Color(1.0, 1.0, 1.0, 1.0)
	body_entered.connect(_on_body_entered)
	# Some enemies (e.g. HostileVine) are a Node2D with an Area2D hitbox rather
	# than a physics body — those only surface through area_entered.
	area_entered.connect(_on_area_entered)
	var t := get_tree().create_timer(lifetime)
	t.timeout.connect(_despawn)

func _physics_process(delta: float) -> void:
	position.x += direction * speed * delta
	position.y += vertical * delta
	# Spin in the direction of travel so the blade reads as thrown, not sliding.
	_spin += delta * 20.0 * signf(direction)
	if sprite:
		sprite.rotation = _spin

func _on_body_entered(body: Node2D) -> void:
	if _hit(body):
		_impact()
	elif body.has_method("smash"):        # rolling boulder
		body.smash()
		_impact()
	elif _try_break_block(body):
		# ANY axe breaks a breakable block. Founder (session 4): "this hammer
		# doesnt work" — pointing at a Bitcoin block his thrown weapon passed
		# straight through. Two bugs: (1) breakable_block sat on collision_layer
		# 1 (World) only, which the axe's mask (164 = Destructible|Hazards|
		# Enemies) never sees — fixed by adding the Destructible bit (layer 129)
		# so the axe detects it; (2) `_smash_destructible` was big-axe-only, but
		# a breakable block is meant to be broken by the BASE attack too (he was
		# in Blaze Mode, not holding the big axe). Ladders stay big-axe-only (see
		# _smash_destructible) — only the `breakable` group is opened up here.
		# A normal axe despawns on the break (piercing stays a big-axe trait).
		_impact()
	elif big and _smash_destructible(body):
		# Big axe ploughs through scenery ("damages the ladder and anything
		# that comes in its way") without stopping.
		pass

## Break a `breakable`-group block with any axe. Returns true if it broke one.
## Deliberately narrower than _smash_destructible: it only touches the
## `breakable` group (Bitcoin blocks etc.), NEVER the take_structural_damage
## props (ladders), which must remain big-axe-only so a normal throw can't
## shear a vault/escape ladder.
func _try_break_block(node: Node) -> bool:
	if node != null and node.is_in_group("breakable") and node.has_method("break_block"):
		node.break_block()
		AudioManager.play_sfx_at("hit", global_position)
		return true
	return false

func _on_area_entered(area: Area2D) -> void:
	# The hitbox Area2D itself usually isn't the enemy — the enemy is its owner.
	if _hit(area) or _hit(area.get_parent()):
		_impact()
	elif _try_break_block(area) or _try_break_block(area.get_parent()):
		_impact()
	elif big and (_smash_destructible(area) or _smash_destructible(area.get_parent())):
		pass

## Big-axe only: break scenery in the flight path. Returns true if something
## was actually destroyed. Never despawns the axe — piercing is the point.
func _smash_destructible(node: Node) -> bool:
	if node == null:
		return false
	# PROGRESSIVE structural damage, not instant destruction.
	#
	# Founder: "They mustn't break completely as in disappear, but there needs
	# to be structural damage and if the player persists then we see that the
	# damage increases until the object is completely wrecked."
	#
	# Anything exposing take_structural_damage() (ladders today, any prop that
	# adds a Destructible tomorrow) absorbs a hit and shows cracks/missing
	# chunks; only the final hit in the chain removes it. This branch is
	# checked BEFORE `breakable`, so a prop that has both a damage model and a
	# legacy break_block() degrades properly instead of vanishing.
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
		# Bosses take a reduced-but-still-elevated amount: strictly more than a
		# normal axe's 1, strictly less than any boss's max health, so the big
		# axe can never one-shot a boss (founder's explicit constraint).
		var dmg := damage
		if big and node.is_in_group("boss"):
			dmg = BIG_BOSS_DAMAGE
			# A boss chip is the moment the founder wants to feel most.
			_boss_hitstop()
		elif heavy and node.is_in_group("boss"):
			# Pickaxe tier against a boss: more than the default 1, less than
			# the big axe's 4, and NO hitstop — the freeze-frame stays the big
			# axe's signature (see the `heavy` block at the top of this file).
			dmg = PICK_BOSS_DAMAGE
		node.take_damage(dmg)
		# Shared "vo_attack" id across all three hit paths (axe / flame /
		# fire-breath) so ONE cooldown absorbs fan-axe multi-hits and
		# continuous flame ticks collectively, not per-weapon. 3.0s is set
		# from the real clip length: vo_attack.mp3 is 1.23s, so anything under
		# ~1.5s would cut itself off mid-line during sustained combat, while a
		# much longer gap stops it reading as a reaction to the hit at all.
		AudioManager.play_bark("vo_attack", 3.0)
		return true
	return false

func _impact() -> void:
	# Founder: "The axe still doesn't work" — it always DID deal damage, but the
	# feedback was a 0.1s/2.0 `light()` nudge and the same generic "hit" ping the
	# 1-damage starter axe uses, so a 5-damage cleave was indistinguishable from
	# a pea-shooter. The hit now has to be FELT: its own heavy metal SFX, a real
	# screenshake, and a hitstop on boss connects.
	if big:
		AudioManager.play_sfx_at("bigaxe_impact", global_position)
		ScreenShake.heavy()
		# The big axe PIERCES — it keeps flying through whatever it just killed,
		# which is what makes "anything that comes in its way" true rather than
		# "the first thing in its way".
		return
	if heavy:
		# PICKAXE tier — see the `heavy` block above. Same heavy impact SFX as
		# the big axe so a hit is unmistakably meatier than the default ping,
		# but only a MEDIUM shake and no pierce/hitstop, so the big axe keeps
		# its own identity as the top of the ladder.
		AudioManager.play_sfx_at("bigaxe_impact", global_position)
		ScreenShake.medium()
		_despawn()
		return
	AudioManager.play_sfx_at("hit", global_position)
	_despawn()

## Momentary freeze so a heavy connect reads as impact rather than a graze.
## Boss hits only — a hitstop on every trash-mob kill would make the stage
## feel laggy rather than weighty.
func _boss_hitstop() -> void:
	Engine.time_scale = 0.05
	await get_tree().create_timer(0.06 * 0.05, true, false, true).timeout
	Engine.time_scale = 1.0

func _despawn() -> void:
	if is_instance_valid(self):
		queue_free()
