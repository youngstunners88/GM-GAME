# Godot Workspace

This is where the game is built. The actual Godot 4.3 project lives here. All code, scenes, nodes, physics, and engine configuration. This is the /src layer of the project.

## What Happens Here
- GDScript coding for player controller, enemies, power-ups, collectibles, UI
- Scene composition using Godot's node system (instancing, signals, groups)
- Physics configuration (CharacterBody2D, gravity, collision layers, Area2D triggers)
- UI implementation (HUD, health bar, score counter, coin counter, pause menu)
- Game state management (score, health, lives, collectibles, level progression, save/load)
- Boss AI and arena logic

## Tech Stack
- **Engine**: Godot 4.3
- **Renderer**: Forward+ (2D)
- **Scripting**: GDScript
- **Physics**: Godot Physics 2D
- **Resolution**: 480x270 base, stretch mode = `canvas_items`, stretch aspect = `expand`
- **Input**: Keyboard (WASD / Arrows + Space) + Gamepad support via InputMap

## Code Organization
```
godot/
├── project.godot
├── autoload/
│   ├── game_state.gd       (singleton: score, health, lives, current level)
│   ├── audio_manager.gd    (singleton: music, SFX, bus mixing)
│   └── scene_manager.gd    (singleton: level transitions, pause)
├── entities/
│   ├── player/
│   │   ├── lil_blunt.gd
│   │   ├── lil_blunt.tscn
│   │   └── states/           (idle, run, jump, double_jump, blaze_mode, grow, shield)
│   ├── enemies/
│   │   ├── base_enemy.gd
│   │   ├── tax_collector.gd / .tscn
│   │   ├── fly_swarm.gd / .tscn
│   │   ├── rolling_boulder.gd / .tscn
│   │   ├── hostile_vine.gd / .tscn
│   │   └── boss_auditor.gd / .tscn
│   ├── powerups/
│   │   ├── blunt_bud.gd / .tscn      (Blaze Mode)
│   │   ├── magic_mushroom.gd / .tscn (Grow)
│   │   └── diamond_shard.gd / .tscn  (Shield)
│   └── collectibles/
│       ├── eth_ring.gd / .tscn
│       └── gold_coin.gd / .tscn
├── levels/
│   ├── level_01_smoke_realm.tscn
│   └── boss_arena_smoke_realm.tscn
├── ui/
│   ├── hud.gd / .tscn
│   ├── main_menu.gd / .tscn
│   └── pause_menu.gd / .tscn
└── world/
    ├── smoke_cloud_platform.gd / .tscn
    ├── breakable_block.gd / .tscn
    └── hazard_zone.gd / .tscn
```

## Coding Standards
- Use `snake_case` for files, variables, functions, signals
- Use `PascalCase` for class names (`class_name LilBlunt`) and node names in scenes
- Use `@export` for ALL designer-tweakable variables (speed, jump_force, damage, timer durations)
- Use signals for decoupled communication (`player_died`, `coin_collected`, `enemy_defeated`)
- Comment every function with `# Purpose: ...` and `# Params: ...`
- Use `const` for magic numbers, `enum` for states
- Group related nodes in containers (Node2D for world, CanvasLayer for UI)
- Use collision layers: Layer 1 = World, Layer 2 = Player, Layer 3 = Enemies, Layer 4 = Collectibles, Layer 5 = Hazards

## Good Code Looks Like
- Modular: Player controller is separate from UI, separate from game logic
- Reusable: All enemies inherit from `BaseEnemy` with virtual methods `_chase()`, `_attack()`, `_take_damage()`
- Debug-friendly: `if DEBUG: print()` wrappers, visible collision shapes toggle
- Performance-conscious: Object pooling for particle effects, free nodes when off-screen, use `call_deferred` for spawn logic
