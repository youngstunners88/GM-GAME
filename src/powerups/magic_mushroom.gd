extends PowerUpBase
## Magic Mushroom — grow bigger and stronger, break certain blocks.

func _ready() -> void:
    super._ready()
    power_up_type = "big"
    duration = 10.0
    # NOTE: no sprite.color / sprite.size here.
    #
    # Those two lines were left over from the ColorRect placeholder era. The
    # scene has used a real Sprite2D (sprite_item_mushroom.png) for a long time,
    # and a Sprite2D has neither property — so every mushroom that spawned threw
    # "Invalid assignment of property or key 'color' ... on a base object of
    # type 'Sprite2D'" and ABORTED _ready() on that line. Everything after it
    # (the size, the collision offset) never ran at all. The scene already sets
    # both offsets to (14, 14), so nothing here needs to override them; the
    # fix is to stop fighting the art, not to re-tint it.
    #
    # weed_leaf.gd carried the identical defect. Those two were the last
    # placeholder-era stragglers — every other power-up had been migrated.
