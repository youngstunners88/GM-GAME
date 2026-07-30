extends Area2D
## Aimed boss projectile — flies in a set direction, damages the player on
## contact, despawns after its lifetime or on hitting the player/world. Used
## by all three bosses for their ranged attacks (clipboard / ETH orb / diamond
## shard); the look is set by `tint`. Spawn it, set `direction`, add to the
## scene. Optional slight homing for the crystal boss's orbs.
##
## REDIRECT ("Forced Distribution", Distributor only): when `redirectable` is
## true the projectile spawns with a brief unstable window during which a
## PLAYER attack that touches it flips it back at its owner for damage that
## lands outside the boss's normal vulnerable state. Opt-in per projectile so
## the Auditor's clipboards and the base orb behaviour are unchanged.

## Emitted when the player successfully redirects this projectile. The boss
## connects to this rather than the projectile reaching into the boss.
signal redirected

var direction: Vector2 = Vector2.RIGHT
var speed: float = 260.0
var lifetime: float = 4.0
var homing: float = 0.0      ## 0 = straight; >0 curves toward player per sec
var tint: Color = Color(1, 0.9, 0.4, 1)

## --- Forced Distribution (opt-in) ---
var redirectable: bool = false
## Seconds after spawn during which a player attack can flip this projectile.
var unstable_time: float = 0.35
## Set by the spawning boss so a redirected orb knows what to fly back at.
var owner_boss: Node2D = null
## Which volley this orb belongs to, so the boss can ignore stale orbs from an
## earlier volley when tallying its all-orbs-flipped bonus.
var volley_id: int = -1

var _t := 0.0
var _redirected := false

@onready var sprite: Sprite2D = $Sprite

func _ready() -> void:
	add_to_group("boss_projectile")
	body_entered.connect(_on_body_entered)
	if redirectable:
		# Boss projectiles sit on layer 64 — and so do PLAYER projectiles, so
		# masking 64 makes this orb see player attacks. It also makes it see
		# other boss orbs, which is why every check below requires group
		# "projectile" (player attacks) and not "boss_projectile" (our own).
		collision_mask |= 64
		area_entered.connect(_on_area_entered)
	if sprite:
		sprite.modulate = tint
	get_tree().create_timer(lifetime).timeout.connect(_despawn)

func _physics_process(delta: float) -> void:
	_t += delta
	if homing > 0.0 and not _redirected:
		var p := get_tree().get_first_node_in_group("player")
		if p:
			var want := global_position.direction_to(p.global_position)
			direction = direction.lerp(want, clampf(homing * delta, 0.0, 1.0)).normalized()
	if _redirected and is_instance_valid(owner_boss):
		# Home hard on the boss so a good redirect actually connects.
		var centre: Vector2 = owner_boss.global_position + Vector2(48, 48)
		var to_boss := global_position.direction_to(centre)
		direction = direction.lerp(to_boss, clampf(6.0 * delta, 0.0, 1.0)).normalized()
		# Arrival is a distance check, NOT a collision callback: the boss body's
		# layer is not in this projectile's mask, and widening the mask to reach
		# it would also make orbs collide with unrelated bodies. The Auditor's
		# reflect-shard already settled on this same approach.
		if global_position.distance_to(centre) < 56.0:
			if owner_boss.has_method("take_redirected_orb"):
				owner_boss.take_redirected_orb(volley_id)
			EffectSpawner.burst("explosion", global_position)
			_despawn()
			return
	position += direction * speed * delta
	if sprite:
		sprite.rotation += delta * 6.0
		if redirectable and not _redirected:
			# Unstable window reads as a bright white-cyan flash; once it lapses
			# the orb settles back to its normal tint and can no longer be hit.
			if _t <= unstable_time:
				var f := 0.5 + 0.5 * sin(_t * 40.0)
				sprite.modulate = tint.lerp(Color(2.2, 2.6, 2.8, 1.0), 0.45 + 0.4 * f)
				sprite.scale = Vector2.ONE * (0.9 + 0.25 * f)
			else:
				sprite.modulate = tint
				sprite.scale = Vector2.ONE * 0.9

func _on_area_entered(area: Area2D) -> void:
	if _redirected or not redirectable:
		return
	# Only a PLAYER attack redirects, and only inside the unstable window.
	# "boss_projectile" is excluded explicitly: our own orbs share layer 64.
	if area.is_in_group("boss_projectile") or not area.is_in_group("projectile"):
		return
	if _t > unstable_time:
		return
	_redirect()

func _redirect() -> void:
	_redirected = true
	speed = 420.0
	homing = 0.0
	if is_instance_valid(owner_boss):
		direction = global_position.direction_to(owner_boss.global_position + Vector2(48, 48))
	if sprite:
		sprite.modulate = Color(2.4, 2.8, 3.0, 1.0)
		sprite.scale = Vector2.ONE * 1.25
	AudioManager.play_sfx("powerup")
	EffectSpawner.burst("explosion", global_position)
	redirected.emit()

func _on_body_entered(body: Node2D) -> void:
	if _redirected:
		# A redirected orb no longer harms the player and passes through them.
		if body.is_in_group("player"):
			return
		_despawn()
		return
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(1)
		_despawn()
	elif body.is_in_group("world"):
		_despawn()

func _despawn() -> void:
	if is_instance_valid(self):
		queue_free()
