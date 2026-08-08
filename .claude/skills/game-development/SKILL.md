---
name: game-development
description: "Development workflow and conventions for Lil Blunt: The Smoke Realm (Godot 4.3 GDScript platformer). Use when setting up CI/CD, writing new code, adding tests, managing dependencies, or improving the development pipeline. Covers GDScript conventions, web export constraints, security gates, testing harnesses, and project architecture."
license: MIT
compatibility: "Godot 4.3+ with GDScript. Non-threaded HTML5 web export. GitHub Actions CI. Cloudflare Worker backend."
metadata:
  version: '1.0'
  author: Young Stunners
  game: "Lil Blunt: The Smoke Realm"
---

# Game Development

## When to Use This Skill

Use when the user asks to:
- Set up or fix CI/CD pipelines
- Write new GDScript code following project conventions
- Add tests or verification scripts
- Manage the project structure or dependencies
- Improve the build/export pipeline
- Fix web export issues (threading, SharedArrayBuffer, etc.)
- Review code before merging
- Set up security checks or audits
- Configure Godot project settings

## Project Architecture

### ICM Umbrella Structure:
The repo follows an ICM (Idea-Content-Medium) umbrella form. The root is a map; each track is self-contained:

| Track | Purpose | Code Location |
|-------|---------|---------------|
| `godot-client/` | The game itself | `src/`, `project.godot` |
| `backend/` | APIs, analytics, LLM proxy | `backend/*.js`, `wrangler.toml` |
| `marketing/` | Campaigns, social, funnels | `backend/marketing.js`, templates |
| `docs/` | Framework, guides, security | `docs/`, root `*.md` |

### Each track has 4 standard files:
- `00-context.md` — what + which layer + dependencies
- `01-current-state.md` — built / in-progress / blocked
- `02-next-task.md` — single next action + acceptance criteria
- `03-decisions.md` — append-only decision log

### The Seam Rule:
The game talks to everything through `Web3Bridge` (autoload) → Cloudflare Worker. No other cross-track channel exists. Never add direct network calls outside of `Web3Bridge`.

## GDScript Conventions

### Critical Web Export Constraint:
Godot's web export compiler rejects `:=` Variant inference from array-index access and `.get()` calls. Always type explicitly:
```gdscript
# WRONG — will fail on web export:
var speed := data.get("speed")

# CORRECT:
var speed: float = float(data.get("speed", 0.0))
```

### Variable Typing:
- Use `var name: Type = value` for all variables
- Use `const NAME: Type = value` for constants
- Use `@export var name: Type = default` for inspector-exposed properties
- Use `@onready var name: Type = $NodePath` for node references
- Use `class_name ClassName` for classes that other scripts reference

### Signal Conventions:
- Define signals at the top of the script, before variables
- Use `signal name(args)` with typed parameters where possible
- Connect signals in `_ready()` or via the editor
- Systems architecture v3.0: "Write global state — only via GameManager methods with signals"

### Function Conventions:
- `_ready()`, `_physics_process(delta)`, `_process(delta)`, `_input(event)` — standard Godot overrides
- Public API functions: camelCase, documented with `##` doc comments
- Private functions: prefix with `_` (e.g., `_setup_background()`)
- Always include `##` doc comments explaining WHY, not WHAT

### Instance Validity:
Godot's `queue_free()` leaves variables non-null. Always use `is_instance_valid()`:
```gdscript
# WRONG:
if health_bar != null:
    health_bar.set_health(health)

# CORRECT:
if is_instance_valid(health_bar):
    health_bar.set_health(health)
```

### Collision Layer Convention:
```
Layer 1 = World (static geometry)
Layer 2 = Player
Layer 3 = Enemies
Layer 4 = Collectibles
Layer 5 = PowerUps
Layer 6 = Hazards
Layer 7 = Projectiles
```

### Group Names:
- `"player"`, `"enemy"`, `"boss"`, `"collectible"`, `"powerup"`, `"hazard"`, `"breakable"`
- Added via `add_to_group()` in `_ready()` or set in the editor

## Autoload System

### Registered Autoloads (in order):
1. `GoldMineSystem` — `src/autoload/goldmine_system.gd`
2. `GameManager` — `src/autoload/game_manager.gd`
3. `SceneTransition` — `src/autoload/scene_transition.tscn`
4. `AudioManager` — `src/autoload/audio_manager.gd`
5. `ScreenShake` — `src/autoload/screen_shake.gd`
6. `StateMachine` — `src/autoload/state_machine.gd`
7. `SceneRouter` — `src/autoload/scene_router.gd`
8. `EntitySpawner` — `src/autoload/entity_spawner.gd`
9. `EffectSpawner` — `src/autoload/effect_spawner.gd`
10. `BossVoiceSystem` — `src/boss/boss_voice_system.gd`
11. `Web3Bridge` — `src/autoload/web3_bridge.gd`
12. `DifficultyManager` — `src/autoload/difficulty_manager.gd`
13. `DevCoordinator` — `src/autoload/dev_coordinator.gd`
14. `MobileInputHandler` — `src/autoload/mobile_input_handler.gd`
15. `ComboSystem` — `src/autoload/combo_system.gd`
16. `IcpBackend` — `src/autoload/icp_backend.gd`

### Autoload Rules:
1. **No class_name on autoload scripts** — a `class_name` matching an autoload name is a parse error in Godot 4
2. **Autoloads are singletons** — accessed globally by name (e.g., `GameManager.add_score(10)`)
3. **process_mode = PROCESS_MODE_ALWAYS** on StateMachine and GameManager — they run even when the tree is paused
4. **Autoload order matters** — GameManager loads before Web3Bridge, so GameManager._ready() uses `call_deferred()` to wire offline mode

## Web Export Constraints

### Non-Threaded Export (CRITICAL):
The project MUST export with `variant/thread_support=false`. Threaded web export needs SharedArrayBuffer, which silently fails on:
- itch.io default sandbox
- itch.io iframes
- Some mobile browsers
- Cross-origin isolated contexts without proper COOP/COEP headers

This was the root cause of "game sometimes doesn't play."

### Project.godot Settings:
```ini
[rendering]
renderer/rendering_method="gl_compatibility"  # NOT "forward_plus"
2d/snap_2d_transforms_to_pixel=true
2d/snap_2d_vertices_to_pixel=true

[display]
window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
```

### Web-Specific Code:
- Use `OS.has_feature("web")` to detect web export
- Use `JavaScriptBridge.eval()` for browser interaction (postMessage, etc.)
- `DisplayServer.is_touchscreen_available()` detects mobile web (OS.get_name() returns "Web", never "Android"/"iOS")
- `window.ethereum` access via `web/web3.js` bridge file

## CI/CD Pipeline

### GitHub Actions (`.github/workflows/export-game.yml`):
```
gitleaks → security-sentinel.sh → Godot export → web3.js bundle check →
security-audit.ts → browser-verify (PLAYING state) → butler deploy
```

### Security Gates (never bypass):
1. **gitleaks** — scans for committed secrets/API keys
2. **security-sentinel.sh** — 18 security checks
3. **security-audit.ts** — 33-check adapted gate
4. **Browser verify** — strict PLAYING state verification (game must actually boot and reach gameplay)
5. **Butler deploy** — pushes to itch.io (when BUTLER_API_KEY secret is set)

### Deploy Targets:
- **itch.io** (primary): https://youngstunners88.itch.io/lil-blunt-adventure
- **Vercel** (mirror): https://lil-blunt-game.vercel.app
- **Backend**: Cloudflare Workers (`wrangler deploy`)

### Scripts:
- `scripts/verify-game.mjs` — Playwright headless browser verification
- `scripts/stress-game.mjs` — 45s input mash stress test
- `scripts/deploy_itch.sh` — manual itch.io push via butler
- `scripts/release-game.sh` — full release orchestration
- `scripts/security-sentinel.sh` — 18-check security gate
- `scripts/kimi-review.sh` — cheap pre-merge code review

## Testing

### Verification Tiers:
- **HARNESS** — exercised in a real headless-Chromium run of the shipped web export
- **LOGIC** — verified by code-path reading + parse check (gdparse), not driven end-to-end
- **FLAGGED** — cannot be honestly verified headless; needs a human playtest

### Testing Commands:
```bash
# Parse check all GDScript files (catches syntax errors before export)
find src/ -name "*.gd" -exec gdparse {} \;

# Headless browser verification
node scripts/verify-game.mjs

# Stress test (mashes all inputs for 45s)
node scripts/stress-game.mjs

# Security gate
./scripts/security-sentinel.sh

# Full release pipeline
./scripts/release-game.sh
```

### Test Files (`tests/`):
- `save_compat_test.gd` / `.tscn` — save file compatibility
- `icp_contract_test.gd` / `.tscn` — ICP canister integration
- `boss_visibility_test.gd` / `.tscn` — boss rendering
- `script_compile_test.gd` / `.tscn` — script compilation

## Code Review Checklist

Before committing:
1. Run `gdparse` on all modified `.gd` files
2. Check for `:=` Variant inference from `.get()` or array indexing (web export rejector)
3. Verify no hardcoded secrets, API keys, or contract addresses (use `config.json`)
4. Verify `is_instance_valid()` used instead of `!= null` for freed nodes
5. Check that all new signals are connected properly
6. Verify collision layers match the convention
7. Verify group names match existing conventions
8. Check that all network calls go through `Web3Bridge`
9. Verify all `@export` vars have sensible defaults
10. Run `scripts/kimi-review.sh` for a cheap pre-merge review

## Configuration Management

### config.json (runtime wiring):
- Contract addresses (SMOKE, DIAMONDS, GoldMine)
- Backend URL
- NEVER hardcode addresses, keys, or URLs in code

### .gitleaks.toml / .gitleaksignore:
- Configure allowed patterns for gitleaks scanner
- Add false positives to ignore file

### Security Checklist:
- `docs/security/GAME_SECURITY_CHECKLIST.md` (Sections A-H)
- `SECURITY_CHECKLIST_INTEGRATION.md`
- `ANDROID_EXPORT_SECURITY.md`

## ALWAYS-SHIP Rule

Every significant change must:
1. Update `STATUS.md` with what changed
2. Commit and push to keep master current
3. Run security gates (never bypass to ship faster)
4. Verify the web export boots and reaches PLAYING state

## ICP Canister

The game has an ICP (Internet Computer Protocol) backend at `lil-blunt-icp/`:
- `src/player_registry.mo` — player registration
- `src/leaderboard.mo` — leaderboard canister
- `src/price_feed.mo` — crypto price feeds
- Uses `mops.toml` for dependency management
- Deployed separately from the Godot game

## Known Technical Debt

1. **Renderer mismatch**: project uses `forward_plus` but should use `gl_compatibility` for web
2. **No bitmap font**: emoji stripped from canvas UI (Godot default font lacks glyphs)
3. **No real animation frames**: all animations are procedural (system is wired, just needs art)
4. **Boss AI needs human playtest**: full boss runs haven't been verified end-to-end
5. **Mobile touch controls need real-device testing**: headless Chromium can't verify them
6. **Audio mix needs ears**: loudness and mixing need human verification
