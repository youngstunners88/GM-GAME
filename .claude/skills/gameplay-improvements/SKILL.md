---
name: gameplay-improvements
description: "Improve gameplay for Lil Blunt: The Smoke Realm (Godot 4.3 GDScript platformer). Use when asked to enhance combat, enemy AI, power-up balance, level design, boss fights, collectibles, scoring, or player feel. Covers player movement tuning, enemy behavior patterns, boss phase logic, combo system, and difficulty curve."
license: MIT
compatibility: "Godot 4.3+ with GDScript. Non-threaded HTML5 web export. Works with the existing src/ autoload architecture (GameManager, StateMachine, DifficultyManager, ComboSystem)."
metadata:
  version: '1.0'
  author: Young Stunners
  game: "Lil Blunt: The Smoke Realm"
---

# Gameplay Improvements

## When to Use This Skill

Use when the user asks to:
- Improve combat feel, enemy AI, or boss fight mechanics
- Balance power-ups, collectibles, or scoring systems
- Design or modify level layouts, enemy spawns, or checkpoint placement
- Tune player movement physics (jump, dash, wall-slide, etc.)
- Adjust the difficulty curve or adaptive difficulty system
- Add new gameplay mechanics or refine existing ones

## Codebase Architecture

The game follows an ICM umbrella structure. Game code lives in `src/`:

```
src/
├── autoload/           # Singletons: GameManager, StateMachine, DifficultyManager, etc.
├── player/             # player.gd, input_handler.gd, power_up_handler.gd, lil_blunt_visual.gd
├── level/              # level_base.gd + 3 level scenes + interactive objects
├── enemies/            # enemy_base.gd + 4 enemy types
├── boss/               # boss_base.gd + 3 bosses + boss_voice_system.gd
├── combat/             # axe.gd, fire_breath.gd, flame_projectile.gd
├── collectibles/       # coin.gd, ethereum_ring.gd, wbtc.gd, etc.
├── powerups/           # 8 power-up types
├── effects/            # Particle effects, smoke puffs, explosions
├── ui/                 # HUD, menus, pause, victory, leaderboard, oracle
├── resources/          # LevelData resources (level_01_data.tres, etc.)
├── dashmode/           # Blaze Rush secret mode
└── space/              # Space ship (v1.3 unlockable content)
```

## Player Movement System

Player physics live in `src/player/player.gd` (class_name Player, extends CharacterBody2D).

### Key Parameters (all @export, tunable):
- `walk_speed: 200.0` — base horizontal speed
- `jump_force: -430.0` — initial jump velocity
- `gravity: 1000.0` — rising gravity
- `fall_gravity_mult: 1.65` — falling pulls harder (kills floaty feel)
- `max_fall_speed: 720.0`
- `ground_accel: 2000.0` / `ground_decel: 2800.0` — acceleration model
- `air_accel: 1400.0` / `air_decel: 900.0`
- `momentum_friction_floor: 1200.0` — bleeds off dash/knockback momentum
- `double_jump_force: -370.0`
- `climb_speed: 150.0`
- `fly_rise_speed: 260.0` / `fly_sink_speed: 90.0` (Bong power-up)

### Movement Features (all implemented):
- Variable jump height (release early = shorter arc)
- Coyote time (0.10s) + jump buffer (0.12s)
- Wall slide + wall jump
- Air dash (cooldown 0.5s, speed 400.0)
- Sprint (1.2x multiplier)
- Ladder climbing with top-out logic
- Ground pound (Big Mode only)
- Bong flight (hold jump to rise, release to sink)
- Landing squash + jump stretch tweens

### Tuning Guidelines:
1. **Never hardcode movement values in _physics_process** — always use the @export vars
2. **Level speed scales compose multiplicatively** with power-up multipliers (see `level_speed_scale`, `level_jump_scale`, `level_gravity_scale`)
3. **Big Mode skips squash/stretch tweens** to avoid fighting PowerUpHandler's scale changes
4. **Hitstop uses a token-guarded restore** — overlapping hitstops race; only the most recent restores `time_scale`
5. **Input ownership**: `InputHandler` owns facing direction and all input state. `LilBluntVisual` owns sprite flipping. Do NOT set `scale.x = -1` on the player — it double-mirrors

## Combat System

### Player Weapons:
- **Axe** (`src/combat/axe.gd`) — thrown projectile, arcs and returns
- **Fire Breath** (`src/combat/fire_breath.gd`) — short-range cone attack
- **Flame Projectile** (`src/combat/flame_projectile.gd`) — ranged fireball

### Enemy Damage Flow:
- Enemies extend `EnemyBase` (CharacterBody2D)
- `EnemyBase.deal_damage(target)` stamps `GameManager.last_damage_source` then calls `target.take_damage()`
- `EnemyBase.take_damage(amount)` → flash effect → `die()` on 0 HP
- Bosses extend `BossBase` which extends `EnemyBase` — adds phase thresholds, health bar, animation system
- Hitstop: `Player._hitstop()` freezes time_scale for 0.07s on hit (token-guarded)

### Combat Improvements to Implement:
1. **Attack cooldown system** — currently no formal cooldown tracking; add to `CombatHandler`
2. **Enemy telegraphing** — enemies need wind-up animations before attacks (use procedural scale/rotation tweens until frame sheets ship)
3. **Knockback direction** — enemies should knock back away from the player, not always left
4. **Combo decay tuning** — `ComboSystem` exists but decay rate may need adjustment per difficulty

## Enemy AI Patterns

### Current Enemies (`src/enemies/`):
| Enemy | File | Behavior |
|-------|------|----------|
| Tax Collector | `tax_collector.gd` | Patrols back-and-forth, charges on sight |
| Fly Swarm | `fly_swarm.gd` | Sine-wave hovering, follows player loosely |
| Rolling Boulder | `rolling_boulder.gd` | Rolls in one direction, shatters with pickaxe |
| Hostile Vine | `hostile_vine.gd` | Stationary, attacks downward when player near |

### Enemy Improvement Guidelines:
1. **Add a `_player_ref` cache** — enemies that detect the player should cache the reference instead of calling `get_tree().get_nodes_in_group("player")` every frame
2. **State machine for enemies** — replace ad-hoc booleans with a simple enum-based state machine (IDLE, PATROL, CHASE, ATTACK, STUNNED, DEAD)
3. **Telegraph window** — every enemy attack needs a 0.3-0.5s visual wind-up before dealing damage
4. **Death variety** — add particle burst variations per enemy type (use `EffectSpawner.burst()`)

## Boss System

### Boss Architecture:
- `BossBase` (`src/boss/boss_base.gd`) — extends EnemyBase, adds:
  - Phase thresholds (HP-based phase transitions)
  - `BossHealthBar` (CanvasLayer-anchored, not parented to boss body)
  - `AnimatedSprite2D` integration via `play_animation()`
  - `animation_finished` signal for state transitions
- 3 bosses: Auditor (tax), Distributor (crystal), Claim Jumper (bandit)
- Boss voice system: 33 ElevenLabs voice lines in `src/assets/sounds/voice/boss/`

### Boss Fight Improvements:
1. **Telegraph every attack** — bosses must signal intent 0.5-1.0s before striking
2. **Phase transitions need spectacle** — screen shake, voice line, visual flash, brief invulnerability window
3. **Attack variety per phase** — each phase should introduce at least one new attack pattern
4. **Downtime between attacks** — bosses need recovery windows (0.5-1.5s) so the player can deal damage
5. **Enrage timer** — if the fight drags past a threshold, increase aggression (use `DifficultyManager`)

## Power-Up System

### Current Power-Ups (`src/powerups/`):
| Power-up | Effect | Duration |
|----------|--------|----------|
| Blaze | 1.4x speed, 1.3x jump, smoke trail | ~10s |
| Purple Weed | 1.6x speed, 1.45x jump, faster smoke | ~10s |
| Magic Mushroom (big) | 1.5x scale, ground pound, keep double-jump | ~8s |
| Diamond Shard | Invincible, damage aura | ~5s |
| Torch | Damage aura, warm tint | indefinite while held |
| Pickaxe | Break blocks/boulders on contact | indefinite while held |
| Bong (fly) | Hold jump to fly, release to sink | ~10s |
| Weed Leaf | Blaze Rush mode entry | trigger |

### Power-Up Balance Rules:
1. **Only one active at a time** — `GameManager.current_power_up` is a single string
2. **Blaze/Purple own exclusive music** — token-guarded override in `AudioManager`
3. **Big Mode keeps double jump** (correction F) — it was a pure downgrade before
4. **Diamond deactivates on hit** — absorbs one hit, then expires
5. **Tool power-ups (torch/pickaxe) don't expire** — they're tools, not buffs

## Level Design System

### Level Architecture:
- `LevelBase` (`src/level/level_base.gd`) — base class, handles:
  - Background setup (painted parallax, single layer at 0.35 motion scale)
  - Geometry creation (platforms with blockchain tile texture + glowing lip)
  - Kill zone (400px tall band, collision_mask=2 for Player layer)
  - Entity spawning (enemies, collectibles, power-ups, breakable blocks, checkpoints, mine carts, melt forges)
  - Boss arena walls
  - Adaptive difficulty application
  - Token perks (wallet-gated bonuses)
  - HUD setup (pause menu)

### Level Data Resources:
Each level has a `LevelData` resource (`.tres` file) containing:
- `ground_segments`, `platforms` — Vector4 arrays (x, y, w, h)
- `enemy_spawns`, `collectible_spawns`, `powerup_spawns` — dictionaries with "type" and "pos"
- `breakable_blocks`, `checkpoints` — Vector2 arrays
- `melt_forges`, `mine_carts_fast`, `mine_carts_slow` — dictionaries
- `boss_arena` — dictionary with start_x, end_x
- `background_path`, `boss_background_path` — string paths to art
- `bounds`, `kill_zone_y` — level dimensions

### Level Design Guidelines:
1. **3 routes per level** — main path, skilled route (risky shortcuts), secret route (hidden areas)
2. **Checkpoints every 30-45 seconds** of expected play time
3. **Power-up placement** — put power-ups before challenge sections that benefit from them
4. **Secret walls** — use `SecretWall` (breakable with pickaxe) to hide bonus areas
5. **One-way platforms** — use `OneWayPlatform` for vertical routing
6. **Melt forges** — Level 3 mechanic, player sacrifices collectibles for rewards

## Combo System

`ComboSystem` autoload tracks consecutive enemy kills. Breaking on damage or timeout.
- Improve by adding visual feedback: growing combo counter, pitch-shifted sound per combo step
- Consider combo multipliers affecting score

## Difficulty Manager

`DifficultyManager` autoload provides invisible adaptive tuning:
- `tax_speed_scale` — slows Tax Collector enemies for struggling players
- `extra_checkpoint` — adds a mid-level checkpoint for slow runners
- `hint_leaf` — spawns a glowing leaf that shows the path to next checkpoint
- All adjustments are invisible — no banners or notifications

### Difficulty Tuning Guidelines:
1. **Never penalize skilled players** — adjustments only help strugglers
2. **Use analytics heatmaps** — death attribution feeds the tuning
3. **Apply retroactively** — `_on_difficulty_ready` adjusts already-spawned enemies

## Testing Checklist

After gameplay changes:
1. Run `gdparse` on all modified `.gd` files (web export rejects `:=` Variant inference from array-index/`.get()`)
2. Verify the game boots to MENU state with zero console errors
3. Test PLAYING state: player can move, jump, double-jump, wall-jump, dash, sprint, climb
4. Test each power-up activates and expires correctly
5. Test enemy interactions: damage, death, knockback
6. Test boss trigger and at least one phase transition
7. Test pit death → checkpoint respawn
8. Verify mobile touch input still works (if MobileInputHandler is present)
9. Check that `StateMachine` transitions are valid (no invalid state warnings)
