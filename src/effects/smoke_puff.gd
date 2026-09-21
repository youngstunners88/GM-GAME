extends Area2D

var direction: Vector2 = Vector2.RIGHT
var speed: float = 300.0
var lifetime: float = 3.0
## Pure VFX: skip the damage wiring entirely.
##
## A smoke puff is normally a REAL damaging projectile — it is Blaze Mode's
## auto-puff attack. The Stage 1 smoke bomb reuses the same puff for its impact
## burst, and without this flag that burst would re-damage whatever the bomb
## just hit, five times over, silently making the starter weapon several times
## stronger than the axe it replaces.
var harmless: bool = false

@onready var sprite: ColorRect = $ColorRect

func _ready() -> void:
    if not harmless:
        add_to_group("projectile")
        body_entered.connect(_on_body_entered)
        area_entered.connect(_on_area_entered)
    # NEUTRAL SMOKE, NOT GREEN SMOKE.
    #
    # This was Color(0.8, 0.9, 0.8, 0.6): green-dominant (G beat both R and B
    # by 25/255), soft-edged and translucent - the textbook description of a
    # smudge. emit_blaze_smoke() spawns these from the player into
    # get_tree().current_scene, so in Blaze Mode they land on TOP of every
    # backdrop in the game. That is why the founder kept reporting green
    # blemishes "in each of the stages 1, 2 and 3 as well as the Blaze Rush
    # sections", and why hunting it through the backdrop ART never found
    # anything - the plates were clean, these were being drawn over them.
    #
    # Still real smoke (the Blaze Mode auto-puff is a designed mechanic), just
    # neutral grey now, matching rolling_boulder.gd's puff - no channel
    # dominance, so it cannot read as a colour blotch against the purple Smoke
    # Realm, the cyan Crystal Caverns or the amber Gold Rush alike.
    sprite.color = Color(0.86, 0.86, 0.88, 0.55)
    sprite.size = Vector2(20, 20)
    $CollisionShape2D.position = Vector2(10, 10)
    # Fade out
    var tween := create_tween()
    tween.tween_property(self, "modulate:a", 0.0, lifetime)
    tween.tween_callback(queue_free)

func _physics_process(delta: float) -> void:
    position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
    if body.is_in_group("enemy") and body.has_method("take_damage"):
        body.take_damage(1)
        queue_free()
    elif body.is_in_group("breakable") and body.has_method("break_block"):
        body.break_block()
        queue_free()

func _on_area_entered(area: Area2D) -> void:
    if area.is_in_group("breakable") and area.has_method("break_block"):
        area.break_block()
        queue_free()
