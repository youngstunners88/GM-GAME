---
name: smoke-realm-architect
description: "Turn messy intent into an ICM-shaped, verifiable implementation path for the GM-GAME project (Lil Blunt: The Smoke Realm, Godot 4.3). Use when Claude Code is asked to add, restructure, debug, or plan a game feature and needs to decide where to look, what not to load, where the single source of truth lives, and how to prove the change. Applies the coach's ICM (Interpretable Context Methodology) workspace discipline plus the anydoc single-shared-model principle: find the one seam or model the change belongs in before writing code."
license: MIT
compatibility: "Claude Code inside the GM-GAME repo (github.com/youngstunners88/GM-GAME). Godot 4.3 GDScript, non-threaded HTML5 web export, GitHub Actions CI, Cloudflare Worker backend, ICP canister layer."
metadata:
  version: '1.0'
  author: Young Stunners
  game: "Lil Blunt: The Smoke Realm"
  method: "ICM (Interpretable Context Methodology) — Van Clief & McDermott, arXiv:2603.16021"
  inspired_by: "github.com/RinDig/icm-architect (ICM method) and github.com/firecrawl/anydoc (single shared model → one serializer)"
---

# Smoke Realm Architect

Turn a vague request — "add a level," "fix the boss," "wire up a new power-up," "the leaderboard is broken" — into a precise, minimal, verifiable change inside the GM-GAME workspace. This skill does not teach GDScript or restate the tech stack; it teaches the discipline of deciding *where to look, what not to load, where the single source of truth lives, and how to prove the change*.

Two ideas run through everything:

1. **ICM workspace discipline** (from the coach's method): the repo is an umbrella of tracks, each track routes through four numbered state files, context manifests gate what you load, and the filesystem *is* the state machine. Orient, act, and report status from the files alone.
2. **Single shared model** (from anydoc's architecture): every format funnels through one document model and one serializer, so a fix applies everywhere. In this codebase that means: find the one autoload, seam, or base class the change belongs in before touching five files. Do not patch the same concept in five places.

## When to Use This Skill

Use when the user asks Claude Code to:

- Add a new feature, level, enemy, boss, power-up, or game system
- Debug or fix a bug in the game, backend, or canister layer
- Restructure or refactor an existing system
- Plan a sprint, a batch of work, or a multi-step feature
- Turn a design doc, a bug report, a screenshot, or a vague idea into an actionable task
- Figure out "where does this change go" in the workspace

Do **not** use this skill for:

- Pure GDScript syntax or Godot engine questions (use the `game-development` skill)
- Deploy or export operations (use the `itch-deploy` or `export-deploy` skill)
- Security audit runs (use the `game-security-sentinel` skill or `security-audit` command)
- Routine code review (use `scripts/kimi-review.sh`)

## Light mode vs full mode

Not every task needs the full 7-step protocol. Match the weight to the task:

- **Light mode** (trivial one-file fixes, constant tweaks, copy edits, quick questions): skip the full contract. Orient via the relevant manifest entry + identify the shared model, then implement + verify. One sentence of intent in your response is enough — do not write a formal contract block.
- **Full mode** (new features, multi-file changes, debugging unknowns, restructuring, anything that touches a shared model): run the complete protocol below.

When in doubt, start light. If the task grows beyond a single file or you hit an unknown, escalate to full mode. The protocol is a safety net, not a tax on every keystroke.

## The protocol

### 1. Orient — read the catalog, not the shelves

Never load the full repo. At 100+ source files that burns the context window before any work happens. Read in this order, stopping as soon as you can answer "where am I and what's the next task":

1. `CLAUDE.md` — the root entry file. Identity, routing table, non-negotiables.
2. `.claude/context-manifests/default.md` — the always-load set + on-demand table. This is the authoritative routing system. If a manifest path 404s, fix the manifest in the same commit.
3. The domain manifest if the task matches one: `.claude/context-manifests/shooter.md` (v1.2 Blunt Force) or `.claude/context-manifests/icp.md` (canister layer).
4. The target track's four files: `00-context.md` → `01-current-state.md` → `02-next-task.md` → `03-decisions.md`. These live in `godot-client/`, `backend/`, `marketing/`, or `docs/`.

The track folder is a catalog node — it routes to the real code in `src/`, `backend/*.js`, etc. It does not duplicate it. The catalog holds no books.

**If a track file is missing or sparse**, do not block on it. The manifests (`CLAUDE.md` + `.claude/context-manifests/`) are the authoritative routing system and are actively maintained. Fall back to the manifest's on-demand table for file paths, read the target source files directly, and note in your response that the track's state files are out of date. Do not invent state that is not written down — if `01-current-state.md` or `02-next-task.md` is empty or stale, derive status from `STATUS.md` and the actual code instead. If you update state, backfill the missing track file so the next agent is not sent on the same detour.

### 2. Normalize the task — any input → structured contract

Turn whatever the user gave you — a sentence, a design doc, a bug report, a screenshot, a pasted error — into a task contract before writing any code. Write it as a short block in your response or in a scratch file:

```
INTENT:       one sentence — what the user wants
TRACK:        godot-client | backend | marketing | docs
SHARED MODEL: the one autoload / seam / base class this change belongs in
FILES TO READ: exact paths from the manifest, not the whole folder
ACCEPTANCE:   what must be true for this to be done
VERIFY:       which gates from the manifest's verification section
RISK:         what could break (save compat, web export, collision layers, security)
```

If the input is an office document, PDF, or spreadsheet, convert it to Markdown first with the `convert-documents-to-markdown` skill (already locked in `skills-lock.json`):

```bash
npx -y @firecrawl/anydoc <file> -o out.md
```

Then read the Markdown, not the binary.

### 3. Find the shared model — one seam, not five patches

This is the single most important step. Before writing code, identify the one place this change belongs. The codebase already has shared models for most things:

| Concept | Single source of truth | What NOT to do |
|---|---|---|
| Network calls | `Web3Bridge` autoload (`src/autoload/web3_bridge.gd`) | Never add direct `HTTPRequest` or `JavaScriptBridge.eval` outside it |
| Global game state | `GameManager` autoload | Never read/write progression from a scene script directly |
| Scene / mode routing | `StateMachine` + `SceneRouter` autoloads | Never `get_tree().change_scene` from gameplay code |
| Adaptive difficulty | `DifficultyManager` autoload | Never tune difficulty from a level script |
| Weapon behavior | `WeaponBase` (`src/shooter/weapon_base.gd`) | Never put fire rate / ammo on the player script |
| Enemy AI | `enemy_drone.gd` is the reference FSM | New enemies follow the same FSM shape |
| Level structure | `level_base.gd` + the specific level file | Never duplicate level logic across levels |
| Boss phases | `boss_base.gd` + the specific boss | Never copy-paste phase logic |
| Runtime config | `config.json` (contracts, backend URL, canister IDs) | Never hardcode addresses, keys, or URLs in code |
| Canister IDs | `config.json` `icp` block | Never interpolate a canister ID without charset validation |
| Security checks | `scripts/security-sentinel.sh` (one implementation) | Never write a second security check script |

If you cannot find a shared model for the change, that is a signal: either the change needs a new base class (propose it in `03-decisions.md` first), or the change is bigger than it looks. Do not silently patch five files.

### 4. Plan as an ICM contract

Write the plan as a stage contract — the same shape the coach's method uses:

```
JOB:       one sentence
INPUTS:    exact file paths (working + reference)
PROCESS:   numbered steps
OUTPUT:    what files change or get created
HUMAN CHECK: what a person verifies (or what gate proves it)
```

If the task spans multiple tracks, split it into one contract per track. The seam rule keeps tracks decoupled: the game talks to everything through `Web3Bridge` → the Cloudflare Worker. No other cross-track channel exists.

### 5. Implement minimally

- Load only what the step needs (2k–8k tokens is the healthy range from the ICM method).
- Follow the existing patterns in the files you read — naming, typing, signal conventions, collision layers.
- Every online call degrades gracefully. The game must run with zero backend (Book layer always works).
- Type all GDScript variables explicitly. The web export compiler rejects `:=` Variant inference from `.get()` and array indexing — this is a hard error, not a warning.
- Use `is_instance_valid()`, not `!= null`, for freed nodes.
- No `class_name` on autoload scripts (parse error in Godot 4).

### 6. Verify through gates — before claiming anything works

The manifest's verification section is the live source of truth for which gates to run. Do not freeze a copy here — it will drift. The canonical gates are:

```bash
gdparse <changed>.gd                          # syntax (but syntax-only — not ground truth)
<godot> --headless --export-release Web …      # real compile, expect 0 SCRIPT ERROR
node scripts/verify-game.mjs <url>            # v1.0 campaign, 5 gates
node scripts/verify-shooter.mjs <url>         # v1.2 prototype, 6 gates
godot --headless res://tests/save_compat_test.tscn   # save format
bash scripts/security-sentinel.sh            # 18 checks, 0 blockers (run AFTER git add)
```

Read the manifest for the full, current list and for the traps that cost real time to rediscover — like `gdparse` passing files a real export rejects, or the sentinel scanning `git ls-files` so it must run after `git add`.

### 7. Ship — ALWAYS-SHIP

After every significant change, in the same session:

1. Update `STATUS.md` — the client-facing living report (what changed, what works, what's next).
2. Update the track's `01-current-state.md` and `02-next-task.md` if the state changed.
3. Append a decision to `03-decisions.md` if a structural call was made (append-only, dated).
4. Commit with a clear message. Push. Keep master current — the client looks at the default branch.
5. Security gates run without being asked. Never bypass them to ship faster.

## Guardrails

- **No big rewrites.** If the shared model is not broken, extend it; do not replace it. A change that touches more than ~5 files without a structural reason is a red flag — propose it in `03-decisions.md` first.
- **No physical moves that fight the catalog.** The Godot project lives in `src/`; the track folders are ICM catalog nodes that route to it. Moving `src/` into `godot-client/` would break `res://` paths, CI, and the export pipeline for zero function. This was already decided (see `godot-client/03-decisions.md`, 2026-07-19).
- **No duplicated facts.** One home per fact; a link beats a copy. If something needs explaining, it goes in that folder's `CONTEXT.md`, not in a wiki or anyone's head.
- **No bypassing non-threaded web export.** `variant/thread_support=false` forever. Threaded builds need SharedArrayBuffer and silently fail on itch.io, iframes, and mobile. This was the root cause of "game sometimes doesn't play."
- **No bypassing security gates.** gitleaks → sentinel → export → web3.js bundle → security-audit → browser verify. Three layers, one implementation (`scripts/security-sentinel.sh`).
- **No wallet gate on gameplay.** Never wallet-gate core gameplay or progression; token holdings may drive optional cosmetics, spectacle, perks, or non-core rooms only through the approved seams (`Web3Bridge` → `config.json`). "Prove a stake → unlock content" was proposed and rejected.
- **Enemies are never weed-themed.** Approved: Tax Collectors, flies, boulders, hostile vines, Compliance machines.
- **Do not over-structure.** The ladder runs: chat → saved prompt → skill → folders + one agent. Only climb when the rung below is genuinely repeating. A workspace for a thing done twice is scaffolding, not architecture.

## The walk test

Before declaring done, walk the change cold as an agent with no memory:

- Can you state what changed and why from the updated state files alone?
- Does the change route through the single shared model it belongs in?
- Did the verification gates pass (not just "no console errors" — a real export, a real browser verify)?
- Is any fact now stored in two places? Pick one home; link from the other.
- Did you update `STATUS.md` and push?

If a step fails, fix the structure — not by explaining more, but by moving or splitting until the walk works.

## Examples

### Example: "Add a new enemy that throws projectiles"

**1. Orient:** Read `CLAUDE.md` → `default.md` manifest → `godot-client/00-context.md` → `godot-client/02-next-task.md`. Load on demand: `src/enemies/` (the existing enemy patterns), `docs/architecture/adr-combat-system.md`.

**2. Normalize:**
```
INTENT:       Add a projectile-throwing enemy to the platformer
TRACK:        godot-client
SHARED MODEL: enemy FSM pattern from enemy_drone.gd (shooter) or fly_swarm.gd (platformer)
FILES TO READ: src/enemies/fly_swarm.gd, src/enemies/*.tscn, docs/architecture/adr-combat-system.md
ACCEPTANCE:   enemy spawns, telegraphs ≥0.8s before throwing, projectile uses collision layer 7, degrades gracefully offline
VERIFY:       gdparse + real export + verify-game.mjs + browser verify (PLAYING state)
RISK:         collision layer mismatch (projectile passes through player), web export `:=` inference
```

**3. Find the shared model:** The enemy FSM pattern is the shared model. The projectile is a new scene following `smoke_projectile.gd`'s shape. The enemy extends the existing enemy base, not a copy-paste. Collision layer 7 (Projectiles) must be set or the bolts pass through everything.

**4-7.** Plan as contract → implement → verify → ship (update `STATUS.md`, `01-current-state.md`, append to `03-decisions.md` if a new enemy type was approved, commit, push).

### Example: "The wallet panel shows stale token balances after a player sells"

**1. Orient:** Read `CLAUDE.md` → `icp.md` manifest → `backend/00-context.md` → `backend/02-next-task.md`.

**2. Normalize:**
```
INTENT:       Wallet panel or token perk shows stale balances — a player sold tokens but the UI still shows old holdings
TRACK:        backend (and godot-client if the UI caches)
SHARED MODEL: ICP canister reads (attribution + history) + Web3Bridge (the only network seam)
FILES TO READ: lil-blunt-icp/src/leaderboard.mo, src/autoload/icp_backend.gd, src/autoload/web3_bridge.gd, config.json
ACCEPTANCE:   balances are never persisted; reads are live; a sold token is reflected on next query
VERIFY:       icp-price-fixture.mjs + icp_contract_test.tscn (13/13 with fixture)
RISK:         persisting a balance = a stale balance that could claim tokens a player has sold (explicit domain rule in icp.md)
```

**3. Find the shared model:** The ICP manifest already states the rule: "Never persist prices or balances. They are a live cache (`GameManager.crypto_state`)." The fix is to ensure the wallet/perk query path reads live, not from a saved cache. If the UI is caching, the fix belongs in `Web3Bridge` or `IcpBackend`, not in the wallet panel scene.

**4-7.** Plan → implement → verify → ship.
