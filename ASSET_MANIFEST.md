# Asset Manifest — Lil Blunt: The Smoke Realm

## Status: Sprite Pipeline Ready
- **Background Images**: 6/6 imported (engine integration complete)
- **Music Tracks**: 12/12 imported (3 levels + 3 bosses × 2 variants) at `src/assets/music/`
- **SFX Jingles**: 2/2 imported (Fresh Boost × 2 variants) at `src/assets/sounds/`
- **Player Sprites**: 0/18 frames (ColorRect placeholder active)
- **Enemy Sprites**: 0/24 frames (ColorRect placeholders active)
- **Boss Sprites**: 0/12 frames (ColorRect placeholders active)
- **Collectibles**: 0/6 types (ColorRect placeholders active)
- **Power-ups**: 0/9 frames (ColorRect placeholders active)
- **UI**: 0/8 elements (basic labels active)

All systems use ColorRect placeholders tinted by color. Replace with actual sprites per timeline below.

---

## PRIORITY 0 — BLOCKS GAMEPLAY
*Required before Level 1 playable release*

### Player Sprites
| Asset | Dimensions | Frames | Description |
|-------|-----------|--------|-------------|
| sprite_lil_blunt_idle | 48×48 | 1 | Standing pose, facing right |
| sprite_lil_blunt_run | 48×48 | 4 | Running animation, facing right |
| sprite_lil_blunt_jump | 48×48 | 1 | Jump pose, mid-air |
| sprite_lil_blunt_fall | 48×48 | 1 | Falling pose |
| sprite_lil_blunt_blaze | 48×48 | 4 | Blaze mode (orange/red aura) |
| sprite_lil_blunt_big | 64×64 | 1 | Mushroom power-up size |
| sprite_lil_blunt_crystal | 48×48 | 1 | Crystal armor (Distributor boss arena) |

**Notes**: 
- All sprites must include 1-pixel walk-left variant (flip in-engine)
- Idle should be "chill" expression
- Run should show leg animation
- Blaze version has smoke/fire aura effect
- Big version is 1.5× scale with stomp-ready pose
- Crystal version has blue/purple gemstone helmet + chest plate

### Enemy Sprites
| Asset | Dimensions | Frames | Description |
|-------|-----------|--------|-------------|
| sprite_tax_collector_patrol | 48×48 | 2 | Walks back-and-forth with clipboard |
| sprite_tax_collector_charge | 48×48 | 2 | Charging attack animation |
| sprite_fly_swarm_idle | 32×32 | 4 | Hovering sine-wave pattern |
| sprite_rolling_boulder_roll | 32×32 | 4 | Boulder rolling (spin) |
| sprite_hostile_vine_idle | 48×48 | 2 | Vine swaying |
| sprite_hostile_vine_attack | 48×48 | 2 | Vine striking (extends forward) |

**Notes**:
- Tax Collector: bureaucrat appearance with clipboard, "IRS" vibes
- Fly Swarm: buzzing animation, appears hostile but silly
- Rolling Boulder: round gray rock, simple rotation
- Hostile Vine: green/brown winding plant, attacks downward

### Boss Sprites
| Asset | Dimensions | Frames | Description |
|-------|-----------|--------|-------------|
| sprite_auditor_patrol | 96×96 | 2 | Walking pose, bureaucrat |
| sprite_auditor_charge | 96×96 | 2 | Charging attack |
| sprite_distributor_idle | 96×96 | 2 | Crystal golem, hoarding orbs |
| sprite_distributor_vulnerable | 96×96 | 1 | Flashing red when vulnerable |
| sprite_bandit_boss_patrol | 96×96 | 2 | Cowboy/bandit pose |
| sprite_bandit_boss_throw | 96×96 | 2 | Throwing dynamite |

**Notes**:
- Auditor: IRS agent in suit, menacing but comical
- Distributor: top-heavy crystal golem with 3 glowing orbs circling it
- Bandit: Wild West bandit with hat, dynamite sticks, evil smile

### Platform & Geometry
| Asset | Dimensions | Frames | Description |
|-------|-----------|--------|-------------|
| tileset_wood_platform | 16×16 | 1 | Brown wood planks (Level 1 & 3) |
| tileset_crystal_platform | 16×16 | 1 | Glowing cyan/purple crystal (Level 2) |
| tileset_ground_grass | 16×16 | 1 | Grass/dirt ground block (Level 1) |
| tileset_stone_ground | 16×16 | 1 | Stone ground (Level 2 & 3) |
| sprite_mushroom_large | 64×64 | 1 | Giant mushroom platform (Level 1) |

---

## PRIORITY 1 — POLISH
*Required before QA handoff*

### Collectibles
| Asset | Dimensions | Frames | Description |
|-------|-----------|--------|-------------|
| sprite_coin_gold | 16×16 | 4 | Spinning gold coin (10 pts) |
| sprite_ethereum_ring | 24×24 | 4 | Glowing ETH logo ring (50 pts) |
| sprite_wbtc_bar | 16×16 | 1 | Golden bar, shiny (100 pts, Level 3 only) |
| sprite_diamond_shard | 20×20 | 2 | Sparkling diamond (power-up) |
| sprite_health_pickup | 16×16 | 2 | Heart/health icon (restore 1 HP) |

### Power-ups
| Asset | Dimensions | Frames | Description |
|-------|-----------|--------|-------------|
| sprite_weed_leaf | 24×24 | 4 | Glowing weed/leaf (Blaze mode, 10s) |
| sprite_magic_mushroom | 24×24 | 1 | Colorful mushroom (Big size, 8s) |
| sprite_diamond_shard_powerup | 20×20 | 4 | Diamond shield effect (invincible, 5s) |

### VFX & Particles
| Asset | Dimensions | Frames | Description |
|-------|-----------|--------|-------------|
| sprite_smoke_puff | 32×32 | 6 | Blaze smoke cloud particle |
| sprite_explosion_burst | 48×48 | 5 | Dynamite/TNT explosion effect |
| sprite_crystal_sparkle | 16×16 | 4 | Crystal glint particle (Level 2) |

### UI Elements
| Asset | Dimensions | Frames | Description |
|-------|-----------|--------|-------------|
| icon_heart | 24×24 | 1 | Health indicator icon |
| icon_coin | 16×16 | 1 | Coin UI icon |
| icon_ethereum | 16×16 | 1 | ETH logo for ring counter |
| icon_weed | 16×16 | 1 | Weed leaf for collectible count |
| hud_health_bar_bg | 64×16 | 1 | Health bar background |
| hud_health_bar_fill | 64×16 | 1 | Health bar fill (red gradient) |
| hud_boss_bar_bg | 200×16 | 1 | Boss health bar background |
| hud_boss_bar_fill | 200×16 | 1 | Boss health bar fill (red → green) |

---

## PRIORITY 2 — JUICE
*Optional before ship, post-launch content*

### Parallax Layers
| Asset | Dimensions | Frames | Description |
|-------|-----------|--------|-------------|
| bg_parallax_level1_far | 3400×720 | 1 | Smoke Realm far layer (hazy trees) |
| bg_parallax_level1_mid | 3400×720 | 1 | Smoke Realm mid layer (leaves) |
| bg_parallax_level2_far | 4400×720 | 1 | Crystal Caverns far layer (cave depth) |
| bg_parallax_level2_mid | 4400×720 | 1 | Crystal Caverns mid layer (crystal columns) |
| bg_parallax_level3_far | 4400×720 | 1 | Gold Rush far layer (desert mountains) |
| bg_parallax_level3_mid | 4400×720 | 1 | Gold Rush mid layer (town silhouette) |

### Menu & Transitions
| Asset | Dimensions | Frames | Description |
|-------|-----------|--------|-------------|
| logo_lil_blunt | 128×128 | 1 | Game title logo (animated spin OK) |
| bg_main_menu | 1280×720 | 1 | Main menu background (Smoke Realm vibe) |
| button_play | 200×48 | 2 | Play button (normal/hover) |
| button_continue | 200×48 | 2 | Continue button (normal/hover) |
| button_quit | 200×48 | 2 | Quit button (normal/hover) |

---

## IMPORT INSTRUCTIONS

### Step 1: Download the 6 Background Images
The 6 level/boss background images are located in the `assets/` folder:
1. `bg_level_01_gm_forest.jpg` → `src/assets/images/backgrounds/`
2. `bg_boss_01_tax_collector.jpg` → `src/assets/images/backgrounds/`
3. `bg_level_02_crystal_caves.jpg` → `src/assets/images/backgrounds/`
4. `bg_boss_02_crystalline_bureaucrat.jpg` → `src/assets/images/backgrounds/`
5. `bg_level_03_gold_rush.jpg` → `src/assets/images/backgrounds/`
6. `bg_boss_03_bandit_boss.jpg` → `src/assets/images/backgrounds/`

### Step 2: Import into Godot
1. Copy the 6 images to `res://src/assets/images/backgrounds/`
2. Godot will auto-import as textures
3. In the Inspector for each TextureRect Background node:
   - Set **Texture** to the corresponding background image
   - Verify **Filter** is set to **NEAREST** (pixel art style)
   - Verify **Stretch Mode** is **KEEP_ASPECT_COVERED**

### Step 3: Wire Up Scenes
Scenes ready for background integration:
- `level_01_smoke_realm.tscn` — has TextureRect "Background" node (needs `bg_level_01_gm_forest.jpg`)
- `level_02_crystal_caverns.tscn` — has TextureRect "Background" node (needs `bg_level_02_crystal_caves.jpg`)
- `level_03_gold_rush.tscn` — has TextureRect "Background" node (needs `bg_level_03_gold_rush.jpg`)
- `auditor.tscn` → `boss_01_tax_collector.tscn` (has ColorRect, needs sprite + background arena scene)
- `distributor.tscn` → `boss_02_crystalline_bureaucrat.tscn` (has ColorRect, needs sprite + background arena scene)
- `bandit_boss.tscn` → `boss_03_bandit_boss.tscn` (has ColorRect, needs sprite + background arena scene)

### Step 4: Create Boss Arena Scenes
Each boss needs its own full scene (like level scenes):
- `boss_01_tax_collector.tscn` — use `bg_boss_01_tax_collector.jpg` as background
- `boss_02_crystalline_bureaucrat.tscn` — use `bg_boss_02_crystalline_bureaucrat.jpg` as background
- `boss_03_bandit_boss.tscn` — use `bg_boss_03_bandit_boss.jpg` as background

### Step 5: Replace ColorRect Placeholders
As Priority 0/1 sprites are completed:
1. Create sprite sheets or individual frames
2. Replace ColorRect visual with Sprite2D nodes
3. Wire up animations (AnimationPlayer)
4. Update sprite.color tints for outfit changes

---

## Sprite Generation Strategy

### Timeline-Friendly Approach
1. **Vertical Slice (Week 1)**: Player idle/run + Tax Collector + platforms only
2. **Full Polish (Week 2-3)**: All enemies, bosses, collectibles, VFX
3. **Post-Launch (Week 4+)**: Menu art, parallax, juice animations

### Tool Recommendations
- **Aseprite** or **Piskel** for pixel art authoring
- **TexturePacker** or manual atlas layout for sprite sheets
- Godot's built-in AnimationPlayer for frame playback

### Naming Convention
```
sprite_[entity]_[action]_[variant].[ext]
sprite_tax_collector_patrol_right.png
sprite_auditor_charge_left.png
sprite_lil_blunt_blaze_idle.png
```

---

## Completion Checklist

- [ ] Background images imported to `assets/images/backgrounds/`
- [ ] Level TextureRect nodes wired to backgrounds
- [ ] Boss arena scenes created with backgrounds
- [ ] Player sprites (P0): idle, run, jump, blaze
- [ ] Enemy sprites (P0): tax collector, fly swarm
- [ ] Boss sprites (P0): auditor, distributor, bandit
- [ ] Platform tilesets created
- [ ] Collectible sprites added (P1)
- [ ] Power-up animations (P1)
- [ ] VFX particles (P1)
- [ ] UI icons and HUD (P1)
- [ ] Menu art and transitions (P2)
- [ ] All ColorRect placeholders replaced with sprites

---

**Last Updated**: 2026-05-09  
**Project**: Lil Blunt: The Smoke Realm (Godot 4.3)
