class_name LevelData
extends Resource

## 1-based level number — drives which GameManager checkpoint slot this
## level reads/writes. Must match the level's position in the game (1, 2, 3).
@export var level_index: int = 1
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
## Per-level ledge tint. Defaults match the original hardcoded values so
## levels that don't set these keep looking exactly as they did before —
## every realm's ground/platforms rendered in the same green-lipped dark
## body regardless of theme, which is why Gold Rush's moment-to-moment
## platforming read as "Crystal Caverns with different wallpaper" even
## though the backdrop art was distinct. Backdrop parallax was never the
## problem; the ledges you actually stand on 90% of the time were.
@export var platform_body_color: Color = Color(0.10, 0.07, 0.14, 0.94)
@export var platform_lip_color: Color = Color(0.45, 0.9, 0.5, 1.0)
@export var floating_platform_body_color: Color = Color(0.12, 0.09, 0.18, 0.92)
@export var floating_platform_lip_color: Color = Color(0.55, 0.95, 0.7, 1.0)
