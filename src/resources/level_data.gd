class_name LevelData
extends Resource

@export var level_name: String = ""
@export var bounds: Vector2 = Vector2(3400, 720)
@export var kill_zone_y: float = 800.0
## Painted full-screen backdrop (client key art). Empty = fall back to color parallax.
@export var background_path: String = ""
## Backdrop shown once the boss arena triggers (villain key art). Optional.
@export var boss_background_path: String = ""
@export var parallax_layers: Array[Dictionary] = []
@export var ground_segments: Array[Vector4] = []
@export var platforms: Array[Vector4] = []
@export var enemy_spawns: Array[Dictionary] = []
@export var collectible_spawns: Array[Dictionary] = []
@export var powerup_spawns: Array[Dictionary] = []
@export var breakable_blocks: Array[Vector2] = []
@export var checkpoints: Array[Vector2] = []
@export var melt_forges: Array[Dictionary] = []
@export var mine_carts_fast: Array[Dictionary] = []
@export var mine_carts_slow: Array[Dictionary] = []
@export var boss_arena: Dictionary = {"start_x": 0, "end_x": 0, "spawn": Vector2.ZERO}
