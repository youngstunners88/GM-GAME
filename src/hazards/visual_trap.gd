extends Node2D
## Founder, 2026-08-20 (Block_Fixes_1): the floating checkpoint block "solid
## all of a sudden" in six screenshots was never meant to be a visible hazard
## — it's a save trigger, now invisible again (see checkpoint.gd). What the
## founder actually wants at those spots is a REAL environmental hazard: "a
## beautiful trap ... that harms Lil Blunt when he touches it" using his own
## reference art (deadly flower / crystal shard / gold bloom, one alluring
## pair per level).
##
## Same contact-damage convention as hostile_vine.gd: an always-on Area2D
## Hitbox on the hazard collision layer (32), calling the player's own
## take_damage() — invincibility frames there already debounce repeated
## contact, so this hazard needs no cooldown of its own. Unlike the vine it
## never retracts: it's a static decoration the player must simply avoid,
## with a slow idle pulse so it doesn't read as a dead sprite.

@export var damage: int = 1
## Subtle "don't touch me" breathing — big enough to notice, small enough
## not to read as an animated character.
const PULSE_SCALE: float = 1.06
const PULSE_SEC: float = 1.4

@onready var visual: Sprite2D = $Visual
@onready var hitbox: Area2D = $Hitbox

func _ready() -> void:
    add_to_group("hazard")
    hitbox.body_entered.connect(_on_hitbox_body_entered)
    var tween := create_tween().set_loops()
    tween.tween_property(visual, "scale", visual.scale * PULSE_SCALE, PULSE_SEC).set_trans(Tween.TRANS_SINE)
    tween.tween_property(visual, "scale", visual.scale, PULSE_SEC).set_trans(Tween.TRANS_SINE)

func _on_hitbox_body_entered(body: Node2D) -> void:
    if body.is_in_group("player") and body.has_method("take_damage"):
        GameManager.last_damage_source = "trap"
        body.take_damage(damage)
