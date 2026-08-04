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
## deliberately less than any boss's max health (Auditor 6, Distributor 7) so
## it can never be a one-hit boss kill.
var big: bool = false
const BIG_DAMAGE := 5
const BIG_BOSS_DAMAGE := 3
const BIG_SCALE := 2.0
const BIG_SPEED_MULT := 1.15

@onready var sprite: Sprite2D = $Sprite

func _ready() -> void:
	add_to_group("projectile")
	if big:
		damage = BIG_DAMAGE
		speed *= BIG_SPEED_MULT
		scale = Vector2(BIG_SCALE, BIG_SCALE)
		modulate = Color(1.35, 1.1, 0.55, 1.0)   # hot gilded edge
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
	elif big and _smash_destructible(body):
		# Big axe ploughs through scenery ("damages the ladder and anything
		# that comes in its way") without stopping.
		pass

func _on_area_entered(area: Area2D) -> void:
	# The hitbox Area2D itself usually isn't the enemy — the enemy is its owner.
	if _hit(area) or _hit(area.get_parent()):
		_impact()
	elif big and (_smash_destructible(area) or _smash_destructible(area.get_parent())):
		pass

## Big-axe only: break scenery in the flight path. Returns true if something
## was actually destroyed. Never despawns the axe — piercing is the point.
func _smash_destructible(node: Node) -> bool:
	if node == null:
		return false
	if node.is_in_group("breakable") and node.has_method("break_block"):
		node.break_block()
		return true
	# Ladders have no damage API of their own; a big axe shearing one off is
	# pure spectacle, so fade-and-free it rather than adding a health model
	# to a piece of level furniture.
	if node is Node2D and node.get_script() != null \
			and String(node.get_script().resource_path).ends_with("ladder.gd"):
		var t := (node as Node2D).create_tween()
		t.tween_property(node, "modulate:a", 0.0, 0.25)
		t.finished.connect(node.queue_free)
		AudioManager.play_sfx_at("hit", global_position)
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
	AudioManager.play_sfx_at("hit", global_position)
	# The big axe PIERCES — it keeps flying through whatever it just killed,
	# which is what makes "anything that comes in its way" true rather than
	# "the first thing in its way".
	if big:
		ScreenShake.light()
		return
	_despawn()

func _despawn() -> void:
	if is_instance_valid(self):
		queue_free()
