# 🌿 Lil Blunt: The Smoke Realm

A complete Godot 4.3 2D platformer starring Lil Blunt, the chill weed mascot of SmokeRing (SMOKE), navigating realms tied to three crypto protocols: SmokeRing, DIAMONDS, and GoldMine.

## 🚀 Quick Start

1. Download Godot 4.3 from https://godotengine.org/download
2. Open this folder as a project in Godot
3. Press F5 to play

## 🎮 Controls

| Action | PC | Mobile |
|--------|-----|--------|
| Move Left | A / ← | ◀ button |
| Move Right | D / → | ▶ button |
| Jump | Space / W | JUMP button |
| Double Jump | Jump again in air | Tap JUMP again |

## 📂 Project Structure

```
lil-blunt-game/
├── project.godot              # Engine config
├── autoload/                  # Global systems
│   ├── game_manager.gd
│   ├── scene_transition.gd/.tscn
│   └── audio_manager.gd
├── player/
│   ├── player.gd/.tscn
├── enemies/
│   ├── tax_collector.gd/.tscn
│   ├── fly_swarm.gd/.tscn
│   ├── hostile_vine.gd/.tscn
│   └── rolling_boulder.gd/.tscn
├── powerups/
│   ├── weed_leaf.gd/.tscn
│   ├── magic_mushroom.gd/.tscn
│   └── diamond_shard.gd/.tscn
├── collectibles/
│   ├── coin.gd/.tscn
│   └── ethereum_ring.gd/.tscn
├── level/
│   ├── level_01_smoke_realm.gd/.tscn
│   ├── breakable_block.gd/.tscn
│   ├── smoke_cloud_platform.gd/.tscn
│   └── checkpoint.gd/.tscn
├── boss/
│   └── auditor.gd/.tscn
├── effects/
│   └── smoke_puff.gd/.tscn
└── ui/
    ├── main_menu.gd/.tscn
    ├── hud.gd/.tscn
    └── touch_controls.gd/.tscn
```

## ⚡ Power-Ups

| Power-Up | Duration | Effect |
|----------|----------|--------|
| 🔥 Blaze (Weed Leaf) | 12s | 1.4x speed, 1.3x jump, auto-smoke attack |
| 🍄 Big (Mushroom) | 10s | 1.5x size, break brown blocks |
| 💎 Diamond (Shard) | 8s | Invincible + damaging aura |

## 👾 Enemies

| Enemy | Behavior | Health |
|-------|----------|--------|
| Tax Collector | Patrols platforms | 1 HP |
| Fly Swarm | Sine-wave flight | 3 HP |
| Hostile Vine | Extends/retracts | 1 HP (when extended) |
| Rolling Boulder | Rolls downhill | Unkillable |

## 💀 Boss: The Auditor

- 5 HP, 3-phase combat (Patrol → Charge → Vulnerable)
- Defeat = 500 points + Level Complete

## 🎨 Customization

### Difficulty
Edit constants in `player/player.gd`:
```gdscript
const WALK_SPEED: float = 200.0
const JUMP_FORCE: float = -420.0
const GRAVITY: float = 980.0
```

### Add Audio
Create folders:
```
assets/sounds/   # jump.ogg, damage.ogg, powerup.ogg, coin.ogg, ring.ogg
assets/music/    # level01_theme.ogg, menu_theme.ogg, boss_theme.ogg
```

### Replace Graphics
Swap `ColorRect` nodes in `.tscn` files with `Sprite2D` pointing to your pixel art.

## 📱 Mobile Export

Export presets pre-configured for Android. Project → Export → Android → Export APK.

## 🌐 Protocol Lore

- **SmokeRing (SMOKE)** — Lil Blunt's home. Blaze Mode, chill vibes.
- **DIAMONDS** — Future Crystal Caverns level. ETH rewards, diamond shards.
- **GoldMine** — Future Gold Rush level. Wild West, Fort Knox staking.

---

**Chill vibes only. You can't tax the vibe.** 🌿
