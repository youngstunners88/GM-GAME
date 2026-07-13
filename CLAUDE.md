# Lil Blunt Adventure — Godot 4.3 2D Platformer

I am building a complete Godot 4.3 2D platformer for my client **Rich**, founder of three interconnected crypto projects: **SmokeRing** (SMOKE token / Lil Blunt mascot), **DIAMONDS** (ETH rewards protocol), and **GoldMine** (gamified DeFi mining). The game stars **Lil Blunt**, an anthropomorphic chill weed nugget character, in a retro 16-bit pixel art style inspired by classic Super Mario / GBA side-scrollers with light RPG progression.

## Client Ecosystem Context
- **SmokeRing**: OFT token on BASE, ETH, BSC, PulseChain. Lil Blunt is the brand mascot (muscular green weed character, FOMO rocket imagery). "Blaze Mode" is a core game mechanic.
- **DIAMONDS**: ETH rewards protocol with three payout pools. Diamond imagery. Diamond Shards = invincibility shield power-up. Ethereum rings = collectible nod to ETH rewards.
- **GoldMine**: Wild West gold rush DeFi platform. 100-day miners, Fort Knox staking, GOLD Rush Auctions. Gold coins = main collectible. Tax Collector enemies = crypto tax/FUD metaphor.

## Game Identity
- **Hero**: Lil Blunt — small, cute, chill, friendly, cool. NOT aggressive.
- **Core Abilities**: Run, jump, double jump.
- **Power-ups**: 
  - Weed Leaves / Blunt Buds → Blaze Mode (faster movement, higher jumps, auto-puff defensive smoke clouds that damage enemies)
  - Magic Mushrooms → Grow bigger and stronger, break certain blocks
  - Diamond Shards → Diamond shield (invincibility + damaging aura)
- **Level 1 Theme**: The Smoke Realm — colorful, hazy, trippy forest/swamp. Floating smoke clouds as platforms. Giant leaves, mushrooms, glowing flowers.
- **Collectibles**: Ethereum rings (golden glowing rings), regular small coins.
- **Enemies**: Greedy Tax Collector creatures, Annoying Fly swarms, Rolling boulders, Hostile vines (non-weed-themed).
- **End of Level**: Simple boss arena.
- **Systems**: Health system, score/collectible counter, basic enemy AI, proper level design with secrets and flow.

## Workspaces
- `/design` — Game design, level layouts, mechanics specs, lore integration, boss design
- `/assets` — Pixel art direction, sprite specs, audio direction, tileset definitions, animation frame guides
- `/godot` — Godot 4.3 engine work: GDScript, scenes, nodes, physics, UI, game state
- `/docs` — Game documentation, marketing copy, changelogs, build instructions

## Routing
| Task | Go to | Read | Skills |
|------|-------|------|--------|
| Design a level, mechanic, or boss | /design | CONTEXT.md | — |
| Create art/audio specs or style guide | /assets | CONTEXT.md | pixel-art-skill |
| Write code, build scenes, configure engine | /godot | CONTEXT.md | gdscript-skill |
| Write docs, marketing, or changelogs | /docs | CONTEXT.md | — |

## Naming Conventions
- Levels: `level-[number]_[realm-name].tscn` (e.g., `level-01_smoke-realm.tscn`)
- Scripts: `snake_case.gd`
- Scenes: `PascalCase.tscn`
- Assets: `[type]_[entity]_[action]_[frame].[ext]` (e.g., `sprite_lil-blunt_run_01.png`)
- Design docs: `[topic]_design.md`
- Docs: `[topic]_doc.md`

## Global Rules
- Never hardcode real wallet addresses or contract addresses in game code. Use `config.json` if needed.
- All weed-related content must be positive, chill, and symbiotic to Lil Blunt. No aggressive or stereotypical drug imagery.
- Enemies must NOT be weed-themed. Approved enemy types: Tax Collectors, Fly swarms, Rolling boulders, Hostile vines.
- Code must be well-commented, modular, and follow Godot 4.3 best practices.
- The game must feel fun, polished, and true to Lil Blunt's chill personality.

## Deployment (itch.io is primary)
- **Primary platform: itch.io** — https://youngstunners88.itch.io/lil-blunt-adventure
  Game-native CDN, no cold starts, discovery + analytics. Vercel is a mirror only.
- CI (`.github/workflows/export-game.yml`) exports on every push to
  `master`/`claude/**`, packages an itch-ready zip artifact, and auto-deploys
  via butler when the `BUTLER_API_KEY` repo secret is set.
- **Web export MUST stay non-threaded** (`variant/thread_support=false`).
  Threaded builds need SharedArrayBuffer and silently fail to boot on itch.io,
  in iframes, and on some mobile browsers. This was the root cause of the
  "game sometimes doesn't play" bug — never regress it.
- Full pipeline, page setup, and verification gates: `/itch-deploy` skill.

## ⭐ ALWAYS-SHIP RULE (never forget)
After **every significant** change to the game, in the same working session:
1. **Update `STATUS.md`** — the client's living report (what changed, what
   works, what's next). It is the single page the client checks for progress.
2. **Commit** with a clear message referencing the change.
3. **Push** to the working branch. Never end a turn with unpushed game changes.
4. **Keep the repo homepage current**: the client looks at
   https://github.com/youngstunners88/GM-GAME — that shows the **default
   branch (master)**. After each verified milestone, merge the working branch
   into master (merge PR or fast-forward master) so the full codebase is
   always visible there, not hidden on a feature branch.
This is mandatory, not optional — the client relies on always-current state.
The Stop hook re-checks for uncommitted/unpushed work as a backstop.

## ⭐ SECURITY-GATE RULE (autonomous — no prompt required)
Security scanning runs **without being asked, every time**, at three layers:
1. **Mid-session, proactively**: the `game-security-sentinel` skill
   (`.claude/skills/game-security-sentinel/SKILL.md`) activates itself the
   moment you're about to touch secrets, wallet/crypto UI, dynamic execution
   (`OS.execute`, `Expression`, `JavaScriptBridge.eval`), file I/O, deploy
   config, or CI — read its "When to activate" section, it is not optional
   and does not require the user to say "run a security check."
2. **Every release**: `scripts/release-game.sh` Step 1/6 runs
   `scripts/security-sentinel.sh` and blocks the pipeline on any
   critical/high finding. Never remove or bypass this step to "get a release
   out faster."
3. **Every CI push**: `.github/workflows/export-game.yml` runs both
   `gitleaks` (full-history secret scan) and `scripts/security-sentinel.sh`
   (working-tree checks) independent of any chat session existing at all.

All three layers call the **same script** (`scripts/security-sentinel.sh`) —
there is exactly one implementation of these checks, not three copies that
can drift. The full checklist and adaptation reasoning live in
`docs/security/GAME_SECURITY_CHECKLIST.md` (why most of a general SaaS
checklist is N/A for a client-only static-hosted game — no backend/DB/auth/
payments exist today). Append every audit run to `docs/security/audit-log.md`
(the sentinel's `--log` flag does this automatically).

**The moment any of these change, re-audit the N/A items in that checklist
immediately, unprompted**: a real backend, user accounts, a leaderboard,
real payments, or multiplayer. Those items are N/A *because* the
architecture doesn't have the surface yet, not permanently.

`/security-audit` (full mode) is the deeper engine-level companion — run it
before major milestones, not just routine ships. See the sentinel skill's
"Relationship to /security-audit" section for how the two divide labor.

## ⭐ MODEL-ADVICE RULE
End **every** response to the client with a one-line recommendation of which
Claude model to use for the likely next task, with a short reason. Guide:
- **claude-opus-4-8 (or Fable/Opus tier)** — debugging unknowns, architecture,
  multi-system integration, art-pipeline work, anything with hidden root causes.
- **claude-sonnet-5** — well-scoped implementation: new levels from existing
  patterns, tuning constants, docs, routine asset wiring.
- **claude-haiku-4-5** — trivial one-file tweaks, copy edits, quick questions.
