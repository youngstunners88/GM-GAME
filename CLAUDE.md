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
