# Source Workspace
This is the Godot 4.3 project. All executable game code, scenes, and resources live here. Claude reads this before writing any code.

## Tech Stack
- Engine: Godot 4.3
- Language: GDScript (typed)
- Renderer: Forward+ (2D)
- Resolution: 1920x1080 base, pixel-perfect scaling for 16-bit aesthetic
- Physics: CharacterBody2D for player/enemies, Area2D for hitboxes/collectibles

## Project Structure
src/
├── project.godot
├── autoload/
│   ├── GameManager.gd          # Global state: score, health, lives, current power-up
│   ├── SceneTransition.gd      # Fade transitions between levels
│   └── AudioManager.gd         # SFX and music bus management
├── player/
│   ├── Player.tscn
│   ├── Player.gd               # Run, jump, double jump, power-up state machine
│   └── PlayerStateMachine.gd   # Idle, Run, Jump, Fall, BlazeMode, BigMode, DiamondMode
├── enemies/
│   ├── base/
│   │   ├── EnemyBase.tscn
│   │   └── EnemyBase.gd        # Shared: health, take_damage(), flash on hit
│   ├── TaxCollector.tscn + .gd
│   ├── FlySwarm.tscn + .gd
│   ├── RollingBoulder.tscn + .gd
│   └── HostileVine.tscn + .gd
├── powerups/
│   ├── PowerUpBase.tscn + .gd
│   ├── WeedLeaf.tscn + .gd
│   ├── MagicMushroom.tscn + .gd
│   └── DiamondShard.tscn + .gd
├── collectibles/
│   ├── Coin.tscn + .gd
│   └── EthereumRing.tscn + .gd
├── level/
│   ├── LevelBase.tscn          # Parallax background, tilemap, camera limits
│   ├── Level01_SmokeRealm.tscn
│   ├── BreakableBlock.tscn + .gd
│   ├── SmokeCloudPlatform.tscn + .gd  # Moving platform, can be jumped through from below
│   └── Checkpoint.tscn + .gd
├── boss/
│   ├── BossBase.tscn + .gd
│   └── Auditor.tscn + .gd
├── ui/
│   ├── HUD.tscn + .gd          # Health hearts, score, coin count, power-up timer
│   ├── MainMenu.tscn + .gd
│   └── PauseMenu.tscn + .gd
└── effects/
    ├── SmokePuff.tscn + .gd    # Blaze Mode auto-attack projectile
    └── ParticleEffects.tscn    # Dust on land, sparkle on collect