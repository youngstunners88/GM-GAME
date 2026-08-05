extends BossBase
## Boss 2 — The Distributor (Crystalline Bureaucrat). Fires aimed, slightly
## homing ETH orbs; phase escalation (BossBase.current_phase 1→2→3 at
## phase_thresholds) widens the spread and tightens cadence, with corporate
## taunts per phase. Damage window is the post-throw VULNERABLE state.

const BOSS_ID := "crystal"
const ORB := preload("res://src/boss/boss_projectile.tscn")
## On-screen body size. Mirrored by distributor.tscn's RectangleShape2D.
const BODY := 176.0

enum Phase { PATROL, SHARD_THROW, VULNERABLE }

@export var patrol_speed: float = 80.0
@export var throw_cooldown: float = 2.0

var current_phase_state: Phase = Phase.PATROL
var throw_timer: float = 0.0
var direction: float = 1.0
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
	max_health = 7
	health = 7
	phase_thresholds = [4, 2]
	add_to_group("enemy")
	add_to_group("boss")
	boss_sprite.color = Color(0.3, 0.2, 0.6, 1.0)
	# Founder: "The Boss in the 2nd stage doesn't have the same impact as
	# before as he is MUCH smaller and doesn't have his diamond surfboard!!!"
	# 176 vs the old 96. Mirrored by distributor.tscn (176x176 shape, offsets
	# at 88) — the two must move together or art and hurtbox separate.
	boss_sprite.size = Vector2(BODY, BODY)
	collision.position = Vector2(BODY / 2.0, BODY / 2.0)
	hitbox.position = Vector2(BODY / 2.0, BODY / 2.0)
	_build_diamond_surfboard()
	hitbox_shape.shape = collision.shape
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	hitbox.area_entered.connect(_on_hitbox_area_entered)
	boss_display_name = "The Distributor"
	_setup_health_bar()
	BossVoiceSystem.set_active(self, BOSS_ID)
	BossVoiceSystem.say(self, BOSS_ID, "intro", true)

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	throw_timer -= delta

	match current_phase_state:
		Phase.PATROL:
			velocity.x = patrol_speed * direction
			velocity.y += 980.0 * delta
			move_and_slide()
			if is_on_wall():
				direction *= -1.0
				boss_sprite.set_facing(direction > 0)
			if throw_timer <= 0:
				_throw_shards()

		Phase.SHARD_THROW:
			velocity.x = move_toward(velocity.x, 0.0, 100.0)
			velocity.y += 980.0 * delta
			move_and_slide()
			if throw_timer <= 0:
				current_phase_state = Phase.VULNERABLE
				boss_sprite.color = Color(1.0, 0.2, 0.2, 1.0)
				hitbox.monitorable = true
				hitbox.monitoring = true

		Phase.VULNERABLE:
			velocity.x = move_toward(velocity.x, 0.0, 100.0)
			velocity.y += 980.0 * delta
			move_and_slide()
			boss_sprite.modulate = Color(1.0, 0.3, 0.3, 1.0) if fmod(throw_timer, 0.3) < 0.15 else Color(1.0, 0.1, 0.1, 1.0)

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

## Aimed, slightly-homing ETH orbs. Count + spread + cadence scale with the
## BossBase HP phase (1/2/3): 3 orbs → 5 orbs → 5 fast orbs.
func _throw_shards() -> void:
	throw_timer = maxf(1.0, throw_cooldown - 0.4 * (current_phase - 1))
	current_phase_state = Phase.SHARD_THROW
	var count: int = [0, 3, 5, 5][current_phase]
	var p := get_tree().get_first_node_in_group("player")
	var base := Vector2.DOWN if p == null else global_position.direction_to(p.global_position)
	for i in range(count):
		var spread := (float(i) - float(count - 1) / 2.0) * 0.22
		var orb := ORB.instantiate()
		orb.direction = base.rotated(spread)
		orb.speed = 170.0 + 40.0 * (current_phase - 1)
		orb.homing = 0.6 if current_phase >= 2 else 0.0
		orb.tint = Color(0.6, 0.8, 1.0, 1.0)  # ETH blue
		orb.global_position = global_position + Vector2(BODY / 2.0, BODY * 0.21)
		get_parent().add_child(orb)
	AudioManager.play_sfx("throw")

## Corporate taunt on each phase escalation (BossBase calls this).
func _on_phase_changed() -> void:
	if current_phase == 2:
		BossVoiceSystem.say(self, BOSS_ID, "phase50", true)
	elif current_phase == 3:
		BossVoiceSystem.say(self, BOSS_ID, "phase25", true)
		ScreenShake.medium()

func take_damage(amount: int) -> void:
	if is_dead or current_phase_state != Phase.VULNERABLE:
		return
	health -= amount
	AudioManager.play_sfx("damage")
	BossVoiceSystem.say(self, BOSS_ID, "hurt")
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(4.0, 0.25, 0.25, 1), 0.05)
	tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.05)
	_update_health_bar()
	if health <= 0:
		die()
	else:
		current_phase_state = Phase.PATROL
		throw_timer = 2.0
		boss_sprite.color = Color(0.3, 0.2, 0.6, 1.0)
		hitbox.monitorable = false
		hitbox.monitoring = false
		_check_phase_change()

func die() -> void:
	is_dead = true
	BossVoiceSystem.say(self, BOSS_ID, "death", true)
	BossVoiceSystem.clear_active()
	set_physics_process(false)
	GameManager.add_score(1000)
	ScreenShake.shake(0.6, 10.0)
	hitbox.monitorable = false
	hitbox.monitoring = false
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
		# the level, regardless of remaining lives — not hurt-and-continue.
		# See GameManager.boss_contact_restart().
		GameManager.boss_contact_restart()

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("projectile"):
		take_damage(1)
