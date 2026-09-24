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
- `/src` — Godot 4.3 engine work: GDScript, scenes, nodes, physics, UI, game state
- `/docs` — Game documentation, marketing copy, changelogs, build instructions

## ⭐ CONTEXT-MANIFEST RULE (read before starting work)
Start every task by reading `.claude/context-manifests/default.md`, then the
manifest matching the domain (`shooter.md`, `icp.md`). Load only what the
manifest lists. **Never load the full repo** — at 100+ source files that spends
the context window before any work happens.

The manifests also carry the traps that cost real time to rediscover: that
`gdparse` is syntax-only and passes files a real export rejects, that the
security sentinel scans `git ls-files` so running it pre-`git add` scans
nothing, and that the circulating `@icp-cli/cli` install command points at a
package that doesn't exist. If a manifest path 404s, fix the manifest in the
same commit — a manifest that lies is worse than none.

## Routing
| Task | Go to | Read | Skills |
|------|-------|------|--------|
| Design a level, mechanic, or boss | /design | CONTEXT.md | — |
| Create art/audio specs or style guide | /assets | CONTEXT.md | pixel-art-skill |
| Write code, build scenes, configure engine | /src | `.claude/context-manifests/default.md` | gdscript-skill |
| Write docs, marketing, or changelogs | /docs | CONTEXT.md | — |
| **Founder reports smudges / blotches / blemishes** | **`blotch-hunter` agent** | `scripts/blotch-oracle.json` | `blotch-forensics`, `blotch-repair-gate` |

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

## ⭐ FOUNDER-LOCKED FRONT PAGE RULE (never change without his say-so)
The title screen is **founder-approved and locked**. It stays exactly as it is
**no matter what, unless the founder explicitly says otherwise** — he builds in
several sessions in parallel, and it has already been lost once to another
session's branch deploying over it.

Locked files (single source: `scripts/front-page-lock.sh list`):
`src/ui/main_menu.gd`, `src/ui/main_menu.tscn`,
`src/assets/backgrounds/bg_menu_gm_keyart.jpg` (his GM key art),
`src/assets/music/menu_mist_theme.mp3` (his MistMenu track),
`src/assets/shaders/title_smoke_flow.gdshader` (the flowing smoke).

Enforced three ways — do not work around any of them:
1. **Session hook** (`.claude/hooks/guard-front-page.sh`): any edit to a locked
   file raises a permission prompt. Only approve it if the founder asked.
2. **CI** (`scripts/front-page-lock.sh check` in `export-game.yml`): a changed
   locked file fails the build, and a failed master build never deploys.
3. **This rule.**

If the founder *does* ask for a front-page change: make it, run
`scripts/front-page-lock.sh update` in the **same commit**, and say in the
commit message that the founder approved it. Never "fix" a failing lock check
by re-fingerprinting unrequested changes — restore the files instead:
`git checkout origin/master -- $(scripts/front-page-lock.sh list)`.

## ⭐ BLOTCH RULE (the founder's longest-running bug — read before touching art)

The "green smudges" report has recurred since 2026-08-20. It cost a month, two
destroyed background plates, and five detectors that all reported the game
clean. It has a **dedicated agent** — `blotch-hunter` — and two skills,
`blotch-forensics` (where does it live) and `blotch-repair-gate` (what you may
do, and what FIXED requires). Route every smudge/blotch/blemish/smear report to
them instead of improvising.

**ROOT CAUSE FOUND 2026-09-23:** the fixed-position smudges were the IDLE
scene-transition overlay (`scene_transition.gd` autoload + `transition_wipe.gdshader`).
At `progress = 0` its smoothstep was non-zero wherever the noise mask < 0.12,
so it painted permanent dark green/purple (smoke) or amber (gold) blobs on
EVERY screen, menu included. Blob positions come from a GPU-precision-dependent
sin() hash — on the founder's GPU they sat in the sky; on the bot's software
renderer they hid under the HUD. L2 Blaze looked clean because its DIAMOND wipe
residue is dark blue on a dark blue scene. Fixed (shader `step` guard + rect
hidden while idle) and gated in `check-green-vfx.py`, which now also scans
`.tscn` files (the L1 cloud platforms and dash trail were translucent green in
scene files the gate never read). If smudges are ever reported again, check
every full-screen autoload overlay's IDLE state first.

Three things that must never be re-litigated:

1. **It is not green.** Measured, the patches multiply the sky by R ×0.86,
   G ×0.89, B ×0.83 — a near-neutral darkening that only *reads* green on a
   warm sky. Every detector that tested `G > R and G > B` found nothing and was
   wrong. Test channel ratios, never a colour name.
2. **`scripts/blotch-oracle.json` is the founder's graded matrix**, and
   `l2_blaze` is graded CLEAN while the other five scenes are blotched. That
   single row kills any theory blaming his GPU, monitor, browser or screenshot
   tool — none of those skip exactly one scene. `scripts/blotch-analyze.py`
   self-grades against it and exits non-zero when uncalibrated. An uncalibrated
   detector has no opinion.
3. **Measure before you change.** Never modify a plate, sprite or VFX without a
   measurement naming that exact file as the carrier, and never soften or blur
   something the founder asked to have removed — that was done once and bought a
   month of re-reports.

One command: `bash scripts/blotch-hunt.sh`.

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

## ⭐ MODEL ROLE SPLIT (cost-aware — read before dispatching anything)

Claude owns the repo, the commits, STATUS.md and every gate. Other models
produce **advice that must be verified**, never changes that land unreviewed.

| Model | OpenRouter ID | Use it for | Rate |
|---|---|---|---|
| **GPT-6 Astra** | `openai/gpt-6-astra` | **Art-direction fidelity review only** — grading a REAL screenshot against the founder references — plus world-building brainstorming where a second creative opinion earns its cost. Accepts image input. | **$10 / $50** per 1M |
| **DeepSeek V4.1 Flash** | `deepseek/deepseek-v4.1-flash` | **Cheap first-pass diagnosis/triage** — combing long logs, big diffs, or a stack of screenshots for candidates before Claude spends its own context verifying them; rubber-duck audits of a script Claude already wrote. Its output is a lead, not a fact — Claude re-derives and confirms every claim against the real files/live build before it informs any commit or STATUS entry. Verified live 2026-09-19 (real dispatch through `scripts/or-call.mjs`, real OpenRouter catalog entry, not assumed). | **$0.15 / $0.60** per 1M |
| **claude-sonnet-5** | — | Pipeline scaffolding, skill authoring, headless scripts (bpy/trimesh), Godot integration, test gates. Most of the asset-pipeline work. | — |
| **claude-opus-4-8 / Opus tier** | — | Asset-pipeline debugging with hidden coupling: a GLB importing with flipped normals, a rig deforming wrong, an API returning malformed data. | — |

**Astra is 5-10x Sonnet per token. Do not use it for routine code, tests, or
mechanical plumbing.** A four-image fidelity review costs ~$0.14-0.20; that is
worth it, and a code review at those rates is not.

**DeepSeek V4.1 Flash is ~65x cheaper than Astra and has a 1M-token context** —
reach for it whenever a task is mostly *volume* (scan every frame, every log
line, every diff hunk) rather than judgment. It never touches the repo and
never gets the final word: Claude still owns the diagnosis, the fix, the
commit, and every "FIXED" claim, per the rule at the top of this section. This
does not relax `live-build-proof` — a DeepSeek read of a screenshot is not a
substitute for Claude's own live-itch verification.

| **Jev (TypeSafe)** | `~typesafe/jev-latest` (pins to `typesafe/jev-1.13`) | **Ship/block DECISIONS on numbers.** Not a chat model — it answers structured questions and is called at `POST https://openrouter.ai/api/alpha/decisions`, NOT `/v1/chat/completions`. Question types: `noul` (0-1 likelihood), `choice` (+`criteria`), `score`. Every question needs `instructions`. Costs ~$0.00002 a call. | ~$0.00002/call |

**CORRECTION (2026-09-20).** A previous version of this file stated that no
"typesafe"/"jev" model existed, on the strength of a `GET /v1/models` grep. That
was WRONG and it cost the founder real time. Decisions models are NOT listed in
`/v1/models`. The catalog is not proof of absence — only a real HTTP call to the
right endpoint is. Verified working; a 400 from that endpoint is a SCHEMA error
(it names the missing field), never "model does not exist".

**Jev is text-only — it does NOT see images.** Control-tested 2026-09-20: an
image with a black bar scored `noul` 0.22, an identical image without one scored
0.19, and the token count tracked the base64 STRING length, not the picture. So
never hand Jev a screenshot and treat the number as a verdict on the pixels —
that is fake verification. Feed it the NUMERIC METRICS from
`scripts/seam-smudge-gate.py`; let DeepSeek V4.1 Flash (real vision, verified
same day) do the looking.

Dispatch with `scripts/or-call.mjs`, which carries every guard that matters —
`@include` file inlining, abort-before-spending on a missing path, live `/models`
pricing with `--dry-run`, HTTPS_PROXY handling, and an input-modality check so an
image never gets silently dropped by a text-only model:

```bash
node scripts/or-call.mjs openai/gpt-6-astra <prompt.md> <out.md> --image <shot.png> --image <ref.jpg>
```

`OPENROUTER_API_KEY` lives in the environment's **Environment Variables** field.
Never inline a key in a script, a committed file, or a log line.

Full workflow: the `art-direction-fidelity-check` skill.

## ⭐ MODEL-ADVICE RULE
End **every** response to the client with a one-line recommendation of which
Claude model to use for the likely next task, with a short reason. Guide:
- **claude-opus-4-8 (or Fable/Opus tier)** — debugging unknowns, architecture,
  multi-system integration, art-pipeline work, anything with hidden root causes.
- **claude-sonnet-5** — well-scoped implementation: new levels from existing
  patterns, tuning constants, docs, routine asset wiring.
- **claude-haiku-4-5** — trivial one-file tweaks, copy edits, quick questions.
