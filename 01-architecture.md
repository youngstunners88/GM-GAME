# Architecture — how the tracks connect

Four tracks + this root map. One seam rule keeps them decoupled: **the game
talks to everything through `Web3Bridge` (autoload) → the Cloudflare Worker**.
No other cross-track channel exists.

```
                    ┌────────────────────────────────────────────┐
                    │  godot-client (📖 Book + 🎬/🎮 seams)       │
                    │  src/ · project.godot · web/web3.js        │
                    └──────────────┬─────────────────────────────┘
                                   │ Web3Bridge (HTTPRequest + JS eval)
                    ┌──────────────▼─────────────────────────────┐
                    │  backend (🎬/🎮 control plane)              │
                    │  worker.js · marketing.js · agentmail.js   │
                    │  kimi_client.js · KV · wrangler.toml       │
                    └───┬──────────────┬─────────────┬───────────┘
        AgentMail API   │   Mistral /  │  OpenRouter │  window.ethereum
        (email, 🎬/🎮)   │   Kimi / Grok│  (Kimi K3)  │  (wallet, user-signed)
                    ┌───▼──────────────▼─────┐  ┌────▼───────────┐
                    │  marketing (🎬 reach)   │  │ chain (Base)   │
                    │  campaigns · referrals  │  │ SMOKE/DIAMONDS │
                    │  X intents · funnels    │  │ GoldMine/badge │
                    └────────────────────────┘  └────────────────┘
```

## Data loops (what makes this 🎮 Video-Game Layer)

1. **Play → analytics → play**: game fires `/event` → `pstats` KV →
   `/player-analytics` → `DifficultyManager` invisibly tunes the next run.
2. **Play → email**: the same events feed weekly digests, milestone emails,
   and the Monday founder digest (`backend/marketing.js` crons).
3. **Community → game**: lore submitted in-game surfaces on secret walls and
   the Hall of Blaze; the leaderboard paints the top-10 silhouettes.
4. **Wallet → spectacle**: real `balanceOf` reads unlock perks, boss phases,
   and gated rooms — never gate core play.

## Layer rule of thumb

Book = runs without any backend (always true — every feature degrades).
Movie = needs OUR brand/contracts/domain knowledge. Video Game = consumes
its own data loop. Every feature doc states its layer
(`LAYER_SHIFT.md`, `LEVEL_DEPTH.md`, `AGENTMAIL_SETUP.md`).

## Deploy topology

- Game: CI (`.github/workflows/export-game.yml`) → itch.io (butler, primary)
  + gh-pages/Vercel mirrors. Gates: gitleaks → sentinel → export → web3.js
  bundle check → **security-audit.ts** → browser-verifiable artifact → butler.
- Backend: `cd backend && wrangler deploy` (manual, keys as Worker secrets).
- Structural decision (2026-07-19): the Godot project was NOT physically moved
  into `godot-client/` — res:// paths, CI triggers, and the export pipeline
  all key off `src/`; the track folder is the ICM catalog node that routes to
  it. See `godot-client/03-decisions.md`.
