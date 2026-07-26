# Lil Blunt — Corrections Brief Investigation

Investigation record for the GM-GAME corrections brief (PDF prompt +
GMGAMECLAUDECODECORRECTIONS.md). **Local-only work per brief rule 3: no push,
commit, merge, deploy, or remote change.** The live repo tree is authority.

## Reconciliation: brief assumptions vs. actual tree

The brief describes a "placeholder-shaped one-level platformer" and references
paths like `autoload/audio_manager.gd`, `powerups/`, `ui/main_menu.gd`. **The
actual project has moved well past that description** — it is a shipped,
backend-live game. Real paths:

| Brief path | Actual path |
|---|---|
| `autoload/*.gd` | `src/autoload/*.gd` (AudioManager, GameManager, StateMachine, Web3Bridge, DifficultyManager all exist) |
| `player/player.gd` | `src/player/player.gd` (+ `input_handler.gd`, `lil_blunt_visual.gd`, `power_up_handler.gd`) |
| `powerups/magic_mushroom.gd` | `src/powerups/magic_mushroom.gd` |
| `ui/main_menu.gd` | `src/ui/main_menu.gd` |
| 1 level | **3 levels + secret realm already exist and are wired** (`level_01_smoke_realm`, `level_02_crystal_caverns`, `level_03_gold_rush`, `secret_realm`) |

**Consequence:** several brief items (multi-level progression G, secret realm
H, candle system I) are already substantially built. For those, the job is
*reconcile + fix gaps*, NOT build-from-scratch. I will not create duplicate
levels/managers (brief rule 7).

## Per-issue findings

### A. Blaze audio overlap — CONFIRMED REAL BUG
- Root cause: `GameManager.activate_power_up("blaze")` (game_manager.gd:100–102)
  calls `AudioManager.play_sfx("fresh_boost")`. `play_sfx` spawns a **new
  AudioStreamPlayer on the SFX bus** and does NOT touch the music player — so
  the 1.5s+ `fresh_boost.ogg` jingle plays ON TOP of the still-running level
  music. That is exactly the "mesh of noise" reported.
- `fresh_boost.ogg` is 1.5MB / `fresh_boost_alt.ogg` 2.4MB — these are full
  music-length stingers, not short SFX, which makes the overlap egregious.
- AudioManager already owns music cleanly (`current_music_player`, playlist,
  duck). It has NO concept of a temporary music override with save/restore.
- Fix: add a music-override API to AudioManager (token-guarded, saves prior
  playlist + track + position, plays Blaze track exclusively on the Music bus,
  restores on release). Route Blaze/Purple activation + expiry through it.
  Keep it on the MUSIC bus (brief: "Blaze music", not SFX).
- Verify: exported/headless playtest + code inspection that only one music
  player exists during Blaze and the prior track resumes once on expiry.

### B. Menu/wallet text readability — CONFIRMED (design gap)
- Base viewport is 1280×720 (project.godot:31–32), brief says target 1920×1080
  responsive. Layer-shift menu buttons use `custom_minimum_size 240×36` and
  `font_size 14–16` — small on a 720p canvas scaled into an itch iframe.
- Title uses default sizing; wallet status reuses button text.
- Fix: establish an intentional size hierarchy (title/subtitle/body/button/
  status/error), stronger contrast plate, focus visibility, wrap long wallet
  errors. Scale-aware where cheap.

### C. MetaMask → Rabby — CONFIRMED, player-facing refs exist
- `src/ui/crypto_onboarding.tscn` + `.gd`: a "GET METAMASK" button, MetaMask
  setup copy, `_metamask` node, opens metamask.io. This is the only
  player-facing wallet-brand reference. `web/web3.js` uses plain
  `window.ethereum` (provider-agnostic — Rabby injects the same EIP-1193
  interface), so the BRIDGE already works with Rabby; only the BRANDING is
  MetaMask.
- Fix: rebrand onboarding to Rabby (rabby.io), keep provider access through
  the existing `window.ethereum` bridge (Rabby overrides it), leave a
  historical note. Wallet-connect error handling already exists in
  web3_bridge.connect_wallet (poll loop + connectError from the Kimi pass).

### D. Facing / walk animation — LIKELY ALREADY CORRECT, verify
- `lil_blunt_visual.gd` is a single animation owner: `facing_right` setter
  flips sprite/anim/tool; `handle_facing_direction` in input_handler sets it
  from movement. Legs/arms animate procedurally (swinging legs added in a
  prior turn). No obvious double-mirror (art isn't pre-flipped; only code
  flips). **Provisional verdict: already meets the brief.** Verify at runtime
  and document; only fix if a real defect appears.

### E. Ladder top-out — CONFIRMED GAP
- `src/level/ladder.gd` (added task #23) handles climb up/down + jump-off but
  has NO top-out: reaching the top and pressing up just runs the player into
  the platform underside (climb state, no collision resolution onto the
  surface). Matches "climbs underneath a platform and cannot get onto it."
- Fix: add an explicit top-exit marker + clearance check; when at the top of
  the climb span pressing up, move to a collision-valid standing position on
  the intended surface (data-driven offset via export var, not hardcoded).

### F. Mushroom / Big Mode — CONFIRMED DOWNGRADE
- `player.gd:165` — double jump is explicitly disabled while `big`:
  `elif input_handler.consume_double_jump() and not GameManager.has_power_up("big")`.
  Combined with a bigger hitbox, Big Mode is a pure downgrade — matches brief.
- Fix (brief preferred): restore double jump in Big Mode AND add a real
  advantage — a ground-pound that breaks `breakable`/`secret_wall` blocks and
  stuns nearby enemies. Keep hitbox/scale/ladder-clearance consistent.

### G. Multi-level progression — ALREADY BUILT, reconcile reachability
- All 3 levels + secret realm exist and load. Gaps to check: does beating a
  boss ADVANCE to the next level or just dump to menu? (distributor.gd shows
  "Diamonds unlocked!" then likely menu.) Is there a level-select? Fix
  progression continuity + reachability, do NOT rebuild levels.

### H. Secret doorway/realm — ALREADY BUILT (`secret_door` + `secret_realm`
  Chill Lounge with return loop). Reconcile against brief's multi-room spec;
  improve if thin, don't duplicate.

### I. Crypto-candle system — investigate `crypto_coin.gd` / candle art. Likely
  partial. Art-spec-before-batch per brief; treat as lower priority vs. A–F
  functional bugs.

### J. 14 reference images — **BLOCKER: images are NOT in this environment.**
  The brief stages them at `/home/workspace/Documents/.../reference-images/`
  which does not exist here, and they are not among the session uploads. Will
  document each expected slot in SOURCE-MANIFEST.md as "not supplied to this
  environment — cannot inspect/import" rather than fabricate.

## Priority order (functional bugs first, per brief implementation order)
A (audio) → F (Big Mode) → E (ladder top-out) → C (Rabby) → B (menu text) →
D (verify facing) → G/H (reconcile) → I (candle) → J (documented blocker).
