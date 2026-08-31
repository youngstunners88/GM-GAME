extends Area2D
## Tax Collector ARROW — a self-drawn shaft, steel head and fletching, rotated
## to its travel direction.
##
## FOUNDER: "arrows must look like arrows, not circular boss orbs."
##
## He was describing a real bug, not a preference. The gnomes' shot reused
## boss_projectile.tscn, whose art is `fx_dot.png` — a spinning CIRCLE. So the
## "bow and arrow" enemy fired the exact same round pellet the bosses throw,
## tinted a slightly different colour. Nothing on screen said archery, and the
## shot was indistinguishable from a boss attack in a stage where both are on
## screen at once. Reusing the orb was a shortcut taken because it "already
## flies, damages the player and despawns"; that is a behaviour argument, and
## the complaint was about the picture.
##
## Drawn in code rather than as a PNG so it is always crisp at any angle, and
## so no new texture has to be --import-ed before it can be preloaded.
##
## Deliberately has NO `class_name`: a brand-new global class is not in Godot's
## class cache until the editor re-imports, which makes a headless export fail
## with "Could not find type". Loaded by path instead — see tax_collector.gd.

## Set by the firer before it enters the tree.
var direction: Vector2 = Vector2.RIGHT
var speed: float = 330.0
var lifetime: float = 3.0

## Half-length and half-thickness of the drawn arrow, in px.
const HALF_LEN: float = 13.0
const HALF_THICK: float = 4.0

var _age: float = 0.0

func _ready() -> void:
	# Rotating the NODE (not a child sprite) is what makes an arrow read as an
	# arrow: it always points where it is going, which a spinning orb never did.
	rotation = direction.angle()
	# Same layer/mask pair boss_projectile.tscn uses: layer 64 is the shared
	# projectile layer, mask 3 = world (bit 1) + player body (bit 2, the
	# player's collision_layer). Copied deliberately rather than guessed — an
	# arrow that only collided with walls would be decorative.
	collision_layer = 64
	collision_mask = 3
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(HALF_LEN * 2.0, HALF_THICK * 2.0)
	shape.shape = rect
	add_child(shape)
	body_entered.connect(_on_body_entered)
	# NOT added to group "projectile": that group marks PLAYER attacks, and the
	# bosses' hitboxes take damage from anything in it. A gnome arrow in that
	# group would let the gnomes kill the boss for you.
	add_to_group("boss_projectile")
	get_tree().create_timer(lifetime).timeout.connect(_despawn)
	queue_redraw()

func _physics_process(delta: float) -> void:
	_age += delta
	position += direction * speed * delta

func _draw() -> void:
	# Local space points along +X; the node's rotation supplies the heading, so
	# every part below is drawn once and is correct at any angle.
	var wood := Color(0.55, 0.38, 0.20, 1.0)
	var steel := Color(0.86, 0.88, 0.92, 1.0)
	var feather := Color(0.90, 0.76, 0.42, 1.0)
	# Shaft — stops short of the head so the head reads as a separate part.
	draw_line(Vector2(-HALF_LEN, 0.0), Vector2(6.0, 0.0), wood, 2.5)
	# Triangular steel head at the front.
	draw_colored_polygon(PackedVector2Array([
		Vector2(HALF_LEN, 0.0),
		Vector2(5.0, -HALF_THICK),
		Vector2(5.0, HALF_THICK),
	]), steel)
	# Two fletching feathers at the tail, so the silhouette is unmistakably an
	# arrow even at one or two pixels of motion blur.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-HALF_LEN, -HALF_THICK),
		Vector2(-6.0, -1.0),
		Vector2(-HALF_LEN, -1.0),
	]), feather)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-HALF_LEN, HALF_THICK),
		Vector2(-6.0, 1.0),
		Vector2(-HALF_LEN, 1.0),
	]), feather)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(1)
		_despawn()
	elif body.is_in_group("world"):
		_despawn()

func _despawn() -> void:
	if is_instance_valid(self):
		queue_free()
