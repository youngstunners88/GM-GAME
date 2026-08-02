---
name: game-logic
description: "Improve game logic for Lil Blunt: The Smoke Realm (Godot 4.3 GDScript platformer). Use when asked to fix or enhance physics, collision detection, save/load systems, scoring logic, difficulty algorithms, Web3 integration, crypto token perks, or any game system logic. Covers the GameManager state model, DifficultyManager heatmap, ComboSystem, GoldMineSystem, and ICP backend integration."
license: MIT
compatibility: "Godot 4.3+ with GDScript. Non-threaded HTML5 web export. Works with existing autoload architecture."
metadata:
  version: '1.0'
  author: Young Stunners
  game: "Lil Blunt: The Smoke Realm"
---

# Game Logic

## When to Use This Skill

Use when the user asks to:
- Fix physics bugs (collision tunneling, stuck-in-wall, etc.)
- Improve or fix the save/load system
- Modify scoring, combo, or progression logic
- Adjust the adaptive difficulty algorithm
- Fix or enhance Web3/crypto integration (wallet, token perks, balances)
- Modify the GoldMineSystem or ICP backend logic
- Fix state management bugs
- Improve entity spawning logic
- Fix combat math or damage calculation
- Modify checkpoint or respawn logic

## Physics and Collision

### Player Physics (`src/player/player.gd`):
The player is a `CharacterBody2D` with a custom physics implementation in `_physics_process()`.

#### Movement Model:
- **Acceleration-based**: `move_toward(velocity.x, target_speed, accel * delta)` — not instant snap
- **Momentum preservation**: excess same-direction momentum (dash, knockback, wall jump) bleeds off through gentler friction (`momentum_friction_floor/air`) instead of hard-snapping
- **Variable jump height**: releasing jump early cuts upward velocity by 50% (`velocity.y *= 0.5`)
- **Fall gravity multiplier**: `fall_gravity_mult = 1.65` — falling pulls harder than rising for the same jump height but ~15% less airtime

#### Collision Layers:
```
Player collision_layer = 2 (Player)
Player collision_mask = 1 (World) + 3 (Enemies) + 6 (Hazards)
Hurtbox collision_layer = 0, collision_mask = 4 (Collectibles) + 5 (PowerUps)
Aura collision_layer = 0, collision_mask = 3 (Enemies)
Kill zone collision_layer = 0, collision_mask = 2 (Player)
```

#### Common Physics Bugs:
1. **Tunneling**: `max_fall_speed = 720.0` means ~12px/frame. The kill zone is 400px tall to prevent tunneling past it. If adding new fast-moving objects, ensure collision shapes are thick enough.
2. **Wall slide detection**: `is_on_wall() and movement_direction != 0` — must be pressing INTO the wall. Releasing direction stops the slide.
3. **Coyote/jump buffer race**: `on_landed()` checks `if jump_buffer_timer > 0` and fires a buffered jump immediately. The order matters: reset coyote, then check buffer.
4. **Ladder top-out flicker**: the player's collision box (28×28) still overlaps the ladder zone at the exit point. `_top_out_ladder()` force-clears `_ladder_zones = 0` before the body_exited signal fires, preventing re-entry.
5. **Double-mirror bug**: `InputHandler.handle_facing_direction()` must NOT set `scale.x = -1` — `LilBluntVisual` owns the flip via `_spr.flip_h`. Two mirrors compose to identity.

### Collision Improvement Guidelines:
1. **Use `move_and_collide()` for ray casts** — `move_and_slide()` doesn't report individual collisions; use `get_slide_collision()` for contact info
2. **Area2D default mask is 1 (World)** — always set `collision_mask` explicitly on new Area2D nodes, or they detect the wrong layer
3. **Test fast-moving objects** — anything moving >500px/s needs thick collision shapes or ray-cast pre-checks

## Save/Load System

### Architecture (`GameManager.save_session()` / `load_session()`):
- **Format**: JSON file at `user://save.json`
- **Clamped on load**: all numeric values are clamped to valid ranges (health 1-max, level 1-3, etc.)
- **Load order matters**: `max_health` loads BEFORE `player_health` so the health clamp uses the loaded ceiling

### Saved Data:
```json
{
    "total_score": int,
    "coins": int,
    "rings": int,
    "smoke": int,
    "blaze_rush": {level_index: bool},
    "health": int (clamped 1-max_health),
    "max_health": int (clamped 1-10),
    "lives": int (clamped 0-max_lives),
    "current_level": int (clamped 1-3),
    "highest_unlocked_level": int (clamped 1-3),
    "checkpoints": {level: {id, x, y}},
    "goldmine": {...},
    "progression_state": {
        "levels_completed": [int],
        "bosses_defeated": [string],
        "shooter_unlocked": bool,
        "space_unlocked": bool,
        "total_play_time": float
    },
    "wallet_address": string
}
```

### NOT Persisted (by design):
- `crypto_state` — prices and balances are a runtime cache; a saved balance is stale
- `current_power_up` / `power_up_timer` — power-ups don't persist across sessions
- `last_damage_source` — ephemeral analytics attribution
- `level_checkpoints` — wait, these ARE persisted (via `_serialize_checkpoints`)

### Save System Rules:
1. **Always clamp loaded values** — `user://save.json` is player-editable; unclamped values corrupt the session
2. **max_health loads FIRST** — so the health clamp uses the correct ceiling
3. **Backward compatibility** — v1.0 saves have no `progression_state` key; `_deserialize_progression()` merges key-by-key so new fields degrade safely
4. **Self-heal for v1.0 saves** — if `levels_completed` is empty but `highest_unlocked_level > 1`, reconstruct the history
5. **Crypto state is NEVER persisted** — prices go stale in seconds; a saved balance could claim tokens the player has sold

### Save System Improvements:
1. **Save corruption recovery** — currently `load_session()` returns false on invalid JSON; add a backup save mechanism
2. **Versioned saves** — add a `"save_version": 2` field for future migration support
3. **Atomic writes** — write to a temp file, then rename, to prevent corruption on crash mid-write
4. **Checkpoint validation** — verify checkpoint positions are still valid level geometry

## Scoring and Progression

### Score Sources:
| Action | Points |
|--------|--------|
| Coin collected | 10 |
| Ethereum Ring collected | 50 |
| Enemy defeated | `score_value` (default 50) |
| Boss defeated | `score_value` (varies) |
| Blaze Rush completion | variable |

### Progression State (`GameManager.progression_state`):
```gdscript
{
    "levels_completed": [],     # Array[int] — 1-based level indices
    "bosses_defeated": [],      # Array[String] — boss ids
    "shooter_unlocked": false,  # v1.2 Blunt Force
    "space_unlocked": false,    # v1.3 Cosmic Blunt
    "total_play_time": 0.0,
}
```

### Progression Rules:
1. **Idempotent completion** — replaying level 2 doesn't append it twice
2. **Completing all 3 levels unlocks the shooter** — never gated by wallet
3. `highest_unlocked_level` is the authoritative int for level routing
4. `next_level_scene(cleared_level_index)` advances the campaign; returns MENU when complete

### GoldMineSystem (`src/autoload/goldmine_system.gd`):
- Tracks player achievements and milestones
- `on_player_death()` and `reset_session()` hooks
- Save data serialized under the `"goldmine"` key

## Difficulty Manager

### Architecture (`src/autoload/difficulty_manager.gd`):
`DifficultyManager` provides invisible adaptive tuning based on player analytics.

### Tuning Parameters:
- `tax_speed_scale` — multiplies Tax Collector patrol speed ( < 1.0 = slower for struggling players)
- `extra_checkpoint` — spawns an additional mid-level checkpoint
- `hint_leaf` — spawns a glowing leaf that shows the path to next checkpoint

### How It Works:
1. `LevelBase._ready()` calls `DifficultyManager.refresh()` which fetches the player's heatmap from the backend
2. `DifficultyManager.tuning_ready` signal fires when analytics arrive (or immediately with neutral defaults offline)
3. `LevelBase._on_difficulty_ready()` applies adjustments:
   - Retro-scales already-spawned enemies (meta-guard prevents double-apply)
   - Spawns extra checkpoint if needed
   - Spawns hint leaf if needed

### Rules:
1. **Never penalize skilled players** — adjustments only help strugglers
2. **Invisible** — no banners, toasts, or notifications
3. **Analytics-driven** — death heatmaps (enemy attribution, obstacle type) feed the tuning
4. **Meta-guarded** — `e.set_meta("dd_scaled", true)` prevents double-applying to the same enemy
5. **Offline fallback** — neutral defaults (no adjustment) when backend is unreachable

### Difficulty Improvements:
1. **Add more tuning dimensions** — health pickups frequency, enemy spawn density, boss aggression
2. **Time-based adjustment** — track time-per-level and adjust if too fast/slow
3. **Retry detection** — if a player dies 3+ times at the same spot, spawn a helpful item
4. **Skill recovery** — if a player who was struggling improves, gradually remove assistance

## Combo System

### Architecture (`src/autoload/combo_system.gd`):
- Tracks consecutive enemy kills
- Breaks on damage or timeout
- `ComboSystem.break_combo()` called from `Player.take_damage()`

### Web Beacon:
Posts `{type:"combo", value:<count>}` to the parent page via postMessage for browser verification.

### Improvements:
1. **Visual feedback** — growing combo counter, pitch-shifted sound per step
2. **Score multiplier** — combo count could multiply score gains
3. **Combo decay tuning** — adjustable timeout per difficulty

## Web3 Integration

### Architecture (`src/autoload/web3_bridge.gd`):
The `Web3Bridge` autoload is the SINGLE seam between the game and all external services. No other script may make network calls.

### Responsibilities:
- Wallet connection (user-signed only via `window.ethereum`)
- Token balance reads (SMOKE on Base, DIAMONDS+GOLD on Ethereum)
- Event/metric reporting to the Cloudflare Worker backend
- Connectivity monitoring (online/offline detection)
- Analytics queueing and silent reconnect sync

### Token Perks (Movie Layer):
Applied in `LevelBase._apply_token_perks()` at level start:
| Token | Condition | Perk |
|-------|-----------|------|
| SMOKE | balance > 0 | 30s Blaze Mode head-start |
| GoldMine | balance > 0 | Golden skin tint (cosmetic) |
| DIAMONDS | balance > 0 + Level 1 | Crystal Caverns bonus portal |

### Web3 Rules:
1. **Never gate core gameplay** — token perks are additive bonuses, not requirements
2. **Graceful degradation** — zero holdings / no wallet / offline = no perks, no penalty
3. **Contract addresses in config.json** — never hardcoded in scripts
4. **User-signed transactions only** — the game never holds private keys
5. **Balances are runtime cache** — never persisted in save file (stale balance risk)

### Offline Mode:
When backend is unreachable:
- `offline_mode` flag set to true
- Banner appears: "OFFLINE MODE — scores saved locally, will sync when reconnected"
- Leaderboard uses cached data
- Oracle panel shows static FAQ
- Wallet button disabled
- Analytics queued locally, sync on reconnect

## ICP Backend

### Architecture (`lil-blunt-icp/`):
- Motoko canisters on the Internet Computer Protocol
- `player_registry.mo` — player registration and identity
- `leaderboard.mo` — leaderboard data
- `price_feed.mo` — crypto price feeds
- Accessed via `IcpBackend` autoload (`src/autoload/icp_backend.gd`)

### ICP Integration Rules:
1. **Canister calls are async** — use `await` or signal callbacks
2. **Degraded mode** — if ICP is unreachable, fall back to Cloudflare Worker or local cache
3. **Identity is wallet-based** — the player's wallet address is their identity

## Entity Spawning

### Architecture (`src/autoload/entity_spawner.gd`):
`EntitySpawner.spawn(type, position, parent, props)` — factory pattern for all game entities.

### Spawn Types:
- Enemies: "tax_collector", "fly_swarm", "rolling_boulder", "hostile_vine"
- Collectibles: "coin", "ethereum_ring", "coin_btc", "coin_eth", "coin_sol", "wbtc", "gold_token", "health_pickup"
- Power-ups: "blaze", "purple", "magic_mushroom", "diamond_shard", "torch", "pickaxe", "bong", "weed_leaf"
- Objects: "breakable_block", "checkpoint", "melt_forge", "mine_cart"

### Pre-Add_Child Props:
Some entities read properties in `_ready()` that MUST be set before `add_child()`:
- `MineCart.CartType` — set via `props` parameter (FAST vs SLOW determines speed/reward/visual)
- `Checkpoint.checkpoint_id` and `level_index` — read immediately on body_entered wiring

## Logic Checklist

Before shipping logic changes:
- [ ] All save values are clamped on load
- [ ] max_health loads before player_health
- [ ] No `:=` Variant inference from `.get()` or array indexing
- [ ] `is_instance_valid()` used instead of `!= null` for freed nodes
- [ ] All network calls go through Web3Bridge
- [ ] Contract addresses are in config.json, not in code
- [ ] Crypto state is never persisted to save file
- [ ] Difficulty adjustments only help, never penalize
- [ ] Entity spawn props set before add_child where required
- [ ] StateMachine transitions are in the allowed list
- [ ] No direct `get_tree().change_scene()` — use SceneRouter
- [ ] Hitstop token is checked before restoring time_scale
