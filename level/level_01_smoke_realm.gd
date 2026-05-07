extends Node2D

@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var boss_trigger: Area2D = $BossTrigger
@onready var boss_spawn: Marker2D = $BossSpawn
@onready var hud: CanvasLayer = $HUD
@onready var touch: CanvasLayer = $TouchControls

var boss_spawned: bool = false

func _ready() -> void:
    boss_trigger.body_entered.connect(_on_boss_trigger)
    spawn_player()
    setup_platforms()
    setup_enemies()
    setup_collectibles()
    setup_powerups()
    setup_breakable_blocks()
    setup_checkpoints()
    setup_smoke_platforms()

    # Background music
    AudioManager.play_music("res://assets/music/level01_theme.ogg")

func spawn_player() -> void:
    var player := preload("res://player/player.tscn").instantiate()
    var checkpoint := GameManager.get_checkpoint(1)
    if checkpoint != Vector2.ZERO:
        player.global_position = checkpoint
    else:
        player.global_position = player_spawn.global_position
    add_child(player)

func setup_platforms() -> void:
    # Ground segments
    create_platform(0, 650, 400, 70, Color(0.2, 0.5, 0.2, 1.0))
    create_platform(500, 650, 300, 70, Color(0.2, 0.5, 0.2, 1.0))
    create_platform(900, 650, 400, 70, Color(0.2, 0.5, 0.2, 1.0))
    create_platform(1400, 650, 400, 70, Color(0.2, 0.5, 0.2, 1.0))
    create_platform(1900, 650, 300, 70, Color(0.2, 0.5, 0.2, 1.0))
    create_platform(2300, 650, 500, 70, Color(0.2, 0.5, 0.2, 1.0))

    # Boss arena floor
    create_platform(2800, 650, 600, 70, Color(0.3, 0.2, 0.15, 1.0))

    # Floating platforms
    create_platform(300, 500, 100, 20, Color(0.3, 0.6, 0.3, 1.0))
    create_platform(500, 400, 100, 20, Color(0.3, 0.6, 0.3, 1.0))
    create_platform(750, 350, 120, 20, Color(0.3, 0.6, 0.3, 1.0))
    create_platform(1100, 450, 100, 20, Color(0.3, 0.6, 0.3, 1.0))
    create_platform(1400, 350, 100, 20, Color(0.3, 0.6, 0.3, 1.0))
    create_platform(1700, 400, 150, 20, Color(0.3, 0.6, 0.3, 1.0))
    create_platform(2100, 300, 100, 20, Color(0.3, 0.6, 0.3, 1.0))
    create_platform(2400, 450, 120, 20, Color(0.3, 0.6, 0.3, 1.0))
    create_platform(2600, 350, 100, 20, Color(0.3, 0.6, 0.3, 1.0))

    # Boss arena platforms
    create_platform(2850, 500, 100, 20, Color(0.4, 0.3, 0.2, 1.0))
    create_platform(3150, 500, 100, 20, Color(0.4, 0.3, 0.2, 1.0))
    create_platform(3000, 400, 80, 20, Color(0.4, 0.3, 0.2, 1.0))

func create_platform(x: float, y: float, w: float, h: float, color: Color) -> void:
    var plat := StaticBody2D.new()
    plat.position = Vector2(x, y)
    plat.collision_layer = 1  # World layer

    var visual := ColorRect.new()
    visual.color = color
    visual.size = Vector2(w, h)
    plat.add_child(visual)

    var col := CollisionShape2D.new()
    var shape := RectangleShape2D.new()
    shape.size = Vector2(w, h)
    col.shape = shape
    col.position = Vector2(w / 2, h / 2)
    plat.add_child(col)

    add_child(plat)

func setup_enemies() -> void:
    spawn_enemy(Vector2(600, 600), "tax_collector")
    spawn_enemy(Vector2(1100, 600), "tax_collector")
    spawn_enemy(Vector2(1600, 600), "tax_collector")
    spawn_enemy(Vector2(2200, 600), "tax_collector")

    spawn_enemy(Vector2(450, 300), "fly_swarm")
    spawn_enemy(Vector2(1200, 300), "fly_swarm")
    spawn_enemy(Vector2(1800, 250), "fly_swarm")

    spawn_enemy(Vector2(800, 600), "hostile_vine")
    spawn_enemy(Vector2(1500, 600), "hostile_vine")
    spawn_enemy(Vector2(2000, 600), "hostile_vine")

    spawn_enemy(Vector2(1300, 200), "rolling_boulder")
    spawn_enemy(Vector2(2500, 200), "rolling_boulder")

func spawn_enemy(pos: Vector2, type: String) -> void:
    var enemy: Node = null
    match type:
        "tax_collector":
            enemy = preload("res://enemies/tax_collector.tscn").instantiate()
        "fly_swarm":
            enemy = preload("res://enemies/fly_swarm.tscn").instantiate()
        "hostile_vine":
            enemy = preload("res://enemies/hostile_vine.tscn").instantiate()
        "rolling_boulder":
            enemy = preload("res://enemies/rolling_boulder.tscn").instantiate()
    if enemy:
        enemy.global_position = pos
        add_child(enemy)

func setup_collectibles() -> void:
    # Coins
    var coin_positions := [
        Vector2(320, 450), Vector2(520, 350), Vector2(770, 300),
        Vector2(1120, 400), Vector2(1420, 300), Vector2(1720, 350),
        Vector2(2120, 250), Vector2(2420, 400), Vector2(2620, 300),
        Vector2(100, 600), Vector2(550, 600), Vector2(950, 600),
        Vector2(1450, 600), Vector2(1950, 600), Vector2(2350, 600)
    ]
    for pos in coin_positions:
        var coin := preload("res://collectibles/coin.tscn").instantiate()
        coin.global_position = pos
        add_child(coin)

    # Ethereum rings (hidden/rare)
    var ring_positions := [
        Vector2(500, 250), Vector2(1400, 250), Vector2(2400, 200)
    ]
    for pos in ring_positions:
        var ring := preload("res://collectibles/ethereum_ring.tscn").instantiate()
        ring.global_position = pos
        add_child(ring)

func setup_powerups() -> void:
    var leaf := preload("res://powerups/weed_leaf.tscn").instantiate()
    leaf.global_position = Vector2(400, 550)
    add_child(leaf)

    var mush := preload("res://powerups/magic_mushroom.tscn").instantiate()
    mush.global_position = Vector2(1000, 550)
    add_child(mush)

    var diamond := preload("res://powerups/diamond_shard.tscn").instantiate()
    diamond.global_position = Vector2(1800, 550)
    add_child(diamond)

    # Secret diamond in high area
    var secret := preload("res://powerups/diamond_shard.tscn").instantiate()
    secret.global_position = Vector2(2100, 200)
    add_child(secret)

func setup_breakable_blocks() -> void:
    var block_positions := [
        Vector2(850, 500), Vector2(950, 500), Vector2(1350, 500),
        Vector2(1750, 500), Vector2(1850, 500)
    ]
    for pos in block_positions:
        var block := preload("res://level/breakable_block.tscn").instantiate()
        block.global_position = pos
        add_child(block)

func setup_checkpoints() -> void:
    var cp_positions := [Vector2(900, 580), Vector2(1800, 580), Vector2(2500, 580)]
    for i in range(cp_positions.size()):
        var cp := preload("res://level/checkpoint.tscn").instantiate()
        cp.global_position = cp_positions[i]
        cp.checkpoint_id = i + 1
        add_child(cp)

func setup_smoke_platforms() -> void:
    var platform_data := [
        {"pos": Vector2(650, 300), "dist": 80.0, "vert": false},
        {"pos": Vector2(1250, 350), "dist": 60.0, "vert": true},
        {"pos": Vector2(1900, 300), "dist": 100.0, "vert": false}
    ]
    for data in platform_data:
        var plat := preload("res://level/smoke_cloud_platform.tscn").instantiate()
        plat.global_position = data.pos
        plat.move_distance = data.dist
        plat.vertical = data.vert
        add_child(plat)

func _on_boss_trigger(body: Node2D) -> void:
    if body.is_in_group("player") and not boss_spawned:
        boss_spawned = true
        var boss := preload("res://boss/auditor.tscn").instantiate()
        boss.global_position = boss_spawn.global_position
        add_child(boss)
        # Trigger boss music
        AudioManager.play_music("res://assets/music/boss_theme.ogg")
