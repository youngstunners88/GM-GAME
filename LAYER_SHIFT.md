# LAYER SHIFT — Moving Lil Blunt Up the Value Stack

> Coach's framework (the attached deck): output lives on three layers, and each
> captures more value than the one below because each is **harder to copy**.
>
> | Layer | What it is | Copyability | Value captured |
> |-------|-----------|-------------|----------------|
> | 📖 **Book** | Raw output. Generic, self-contained, commoditized. | Trivial to copy | Least |
> | 🎬 **Movie** | Context-specific. Production value + domain knowledge baked in. | Hard to copy | More |
> | 🎮 **Video Game** | Bespoke + interactive + **self-improving from its own data**. | Very hard to copy | Most |
>
> This document maps every feature added in the Layer-Shift work to the layer it
> serves, explains *why* it's hard to copy, and lists the exact contract
> addresses / API endpoints each one uses (and which are live vs. awaiting your
> infra).

The **platformer itself is the Book Layer** and was **not refactored** — every
feature below sits *on top* of it through one seam (`Web3Bridge` autoload) and
**degrades gracefully**: with no wallet, no backend, and no deployed contracts,
the game plays exactly as it did before. The Movie/Video-Game value is additive,
never a gate on core play.

---

## 📖 Book Layer — the platformer (unchanged)

The complete, generic Lil Blunt platformer: run/jump/double-jump, power-ups,
enemies, three bosses, secret realm, lives, score. A polished 2D platformer is
the *commodity* here — anyone with an engine and time can produce one. It stays
exactly as shipped. Everything in this doc is built around it, not into it.

**Why easy to copy:** it's self-contained output with no context or data moat.

---

## 🎬 Movie Layer — context + production value only *you* have

The Movie Layer bakes in the SmokeRing / DIAMONDS / GoldMine ecosystem — the
client's real tokens, real chain, real brand — so the game is only fully itself
*in that context*. A cloner would have to reproduce your token deployments and
brand to get the same thing.

### M1 — Wallet-gated boss badge ("SmokeRing Survivor" ERC-721)
- **What:** Beat The Auditor → the Level-Complete screen offers **CLAIM YOUR
  BADGE** → connects the browser wallet → mints a `SmokeRing Survivor` NFT.
  Skippable; the win counts without it.
- **Files:** `src/ui/victory_screen.gd/.tscn` (screen), `src/boss/auditor.gd`
  (spawns it on death), `src/autoload/web3_bridge.gd::mint_survivor_badge()`,
  `web/web3.js::mintBadge()`.
- **On-chain call:** `mint()` — selector `0x1249c58b`, no args, user-signed
  `eth_sendTransaction`. Free-to-write contract; user pays only gas.
- **Contract:** `contracts.survivor_badge_erc721` in `config.json`.
- **Why hard to copy:** the badge only has meaning inside the SmokeRing brand —
  it's proof *you* beat *this* game, minted to *your* wallet. A generic clone
  has nothing to mint against.

### M2 — Token-tied power-ups (real `balanceOf` gating)
- **What:** At level start, `Web3Bridge` reads the connected wallet's **real
  ERC-20 balances** and grants additive perks:
  - `SMOKE > 0` → **Blaze Mode**, 30s head-start.
  - `GoldMine > 0` → **golden skin tint** (cosmetic flex).
  - `DIAMONDS > 0` → a **Crystal Caverns** bonus portal appears in Level 1.
- **Files:** `src/level/level_base.gd::_apply_token_perks()`,
  `web3_bridge.gd::_refresh_token_balances()/holds()`, `web/web3.js::balanceOf()`.
- **On-chain call:** `balanceOf(address)` — selector `0x70a08231`, read-only
  `eth_call`. No gas, no signature.
- **Contracts:** `contracts.smoke_erc20`, `.diamonds_erc20`, `.goldmine_erc20`.
- **Why hard to copy:** the perks are keyed to *your* token holders. The game
  literally plays differently depending on the player's on-chain relationship
  with the client's projects — a moat a generic platformer cannot reproduce.

---

## 🎮 Video-Game Layer — interactive + self-improving from its own data

The Video-Game Layer is where the game **generates and consumes its own data**,
so it gets better/richer the more it's played — the copy-resistant part.

### V1 — Mistral Oracle NPC (living, lore-aware AI sage)
- **What:** The **Smoke Oracle** NPC (hub + main menu). Ask it anything; it
  answers in-character as a chill, cryptic stoner sage who knows SmokeRing /
  DIAMONDS / GoldMine lore. Powered by Mistral via a **server-side proxy** — the
  API key never touches the client.
- **Files:** `src/npc/oracle.gd/.tscn`, `src/ui/oracle_panel.gd/.tscn`,
  `web3_bridge.gd::ask_oracle()`, `backend/worker.js` (`POST /oracle`).
- **Endpoint:** `POST {backend_base_url}/oracle {question, wallet_address}` →
  proxy calls `https://api.mistral.ai/v1/chat/completions`
  (`model: mistral-small-latest`) with the key from `env.MISTRAL_API_KEY`.
- **Why hard to copy:** the persona + ecosystem lore are bespoke, and the proxy
  holds the key server-side. Each conversation is unique and grounded in the
  client's world — not reproducible by copying the client bundle.

### V2 — On-chain-identity leaderboard
- **What:** A dedicated `Leaderboard` screen (NOT itch.io's) showing the top 20
  runs by **wallet identity** (`0x1234…5678`). On game-over / level-complete the
  player is offered **SUBMIT SCORE TO CHAIN**.
- **Files:** `src/ui/leaderboard.gd/.tscn`, `src/ui/victory_screen.gd`
  (submit prompt), `web3_bridge.gd::submit_score()/get_leaderboard()`,
  `backend/worker.js` (`POST /score`, `GET /leaderboard`).
- **Endpoints:** `POST /score {score, level, wallet_address}`,
  `GET /leaderboard` → top 20.
- **Data / gas tradeoff:** scores are stored in the backend KV keyed by wallet
  (cheap, instant, no gas per score); the **on-chain artifact is the badge NFT**
  (M1). Writing every score on-chain would cost gas per submission for no added
  trust — see `backend/README.md`. The leaderboard is "on-chain-identity"
  (wallet = identity), not "every-score-on-chain".
- **Why hard to copy:** it accumulates *your community's* run history tied to
  *their* wallets — a dataset that only grows on your deployment.

### V3 — Community lore submission → loading-screen tips
- **What:** A **SUBMIT LORE** menu button. Players write a ≤200-char SmokeRing
  lore snippet; it's stored in the backend. Top-voted entries (weekly) surface
  as **loading-screen tips** — the community writes the game's flavor text.
- **Files:** `src/ui/lore_panel.gd/.tscn`, `src/ui/main_menu.gd`,
  `web3_bridge.gd::submit_lore()`, `backend/worker.js` (`POST /lore`).
- **Endpoint:** `POST /lore {text (≤200), wallet_address}`.
- **Why hard to copy:** this is the self-improving loop — the game's content is
  co-authored by its players over time. A fresh clone starts with an empty
  archive; your deployment's mythos compounds.

### V4 — Marketing funnel (anonymous)
- **What:** **JOIN THE SMOKERING** (Telegram/Discord) on the menu and **VIEW
  YOUR NFT** (block-explorer link) on the victory screen. Button clicks are
  tracked anonymously to the backend to measure the funnel.
- **Files:** `src/ui/main_menu.gd::_on_join()`,
  `src/ui/victory_screen.gd::_on_view_nft()`, `web3_bridge.gd::track()`,
  `backend/worker.js` (`POST /track`).
- **Endpoints:** `POST /track {event}`; explorer link built from
  `explorer_base_url` + badge contract.
- **Why hard to copy:** the funnel data (which layer-shift features convert to
  community joins) is proprietary telemetry on *your* audience.

---

## The single seam: `Web3Bridge` (why the Book Layer stayed intact)

Everything above routes through **one autoload**, `src/autoload/web3_bridge.gd`.
It is the only place the platformer touches wallet/chain/backend. Design rules:

1. **Degrade gracefully, always.** No config / not on web / no wallet / backend
   down → every method returns empty/false and the game plays as before.
2. **No secrets or real addresses in code.** All wiring loads at runtime from
   `res://config.json` (per `CLAUDE.md` Global Rules). API keys live *only* in
   the backend proxy — the client bundle exposes zero secrets.
3. **Injection-safe browser calls.** Anything interpolated into
   `JavaScriptBridge.eval` (wallet/contract addresses) is first run through
   `_hex()` — a strict `^0x[0-9a-fA-F]+$` sanitizer. A validated hex string
   cannot carry quotes or JS, so the eval is injection-proof. This invariant is
   enforced by the security sentinel's **INJ-003** check.

The browser half is `web/web3.js` — plain `window.ethereum` JSON-RPC + `fetch`,
**no external library** (no ethers CDN) so it works inside itch.io's sandbox
with no CSP issues. It's bundled next to `index.html` by CI and loaded via
`head_include`.

---

## Wiring reference — what's live vs. what needs your infra

| Feature | Live now | Needs from you |
|---------|----------|----------------|
| Platformer (Book) | ✅ fully playable | — |
| Wallet connect | ✅ code complete | a wallet extension in the browser |
| Badge mint (M1) | ⏳ inert until wired | deploy the ERC-721; set `survivor_badge_erc721` |
| Token perks (M2) | ⏳ inert until wired | set `smoke_erc20`/`diamonds_erc20`/`goldmine_erc20` |
| Oracle (V1) | ⏳ inert until wired | **valid `MISTRAL_API_KEY`** + deploy `backend/` |
| Leaderboard (V2) | ⏳ inert until wired | deploy `backend/`; set `backend_base_url` |
| Lore (V3) | ⏳ inert until wired | deploy `backend/`; set `backend_base_url` |
| Funnel (V4) | ✅ Telegram link live; ⏳ NFT link + tracking need contract/backend | set social URLs, contract, backend |

### Everything is wired to `config.json` (single source of truth)

```json
{
  "backend_base_url": "",            // Cloudflare Worker / Express base URL
  "chain_id": "0x2105",              // Base mainnet
  "contracts": {
    "survivor_badge_erc721": "",     // M1 badge NFT
    "smoke_erc20": "",               // M2 SMOKE perk
    "diamonds_erc20": "",            // M2 DIAMONDS perk
    "goldmine_erc20": ""             // M2 GoldMine perk
  },
  "explorer_base_url": "https://basescan.org",
  "social": { "telegram": "https://t.me/LilBluntdotWin", "x": "https://x.com/smokering25", "discord": "" }
}
```

### Backend

`backend/worker.js` (Cloudflare Worker + KV) implements `/oracle`, `/score`,
`/leaderboard`, `/lore`, `/track`. `backend/README.md` has the deploy steps, the
Node/Express equivalent, and the honest notes on the two current blockers:

1. **The `MISTRAL_API_KEY` in the environment returns `Unauthorized`** — the
   Oracle proxy is correct but needs a working key to answer.
2. **No contracts are deployed yet** — badge/perks are inert until the addresses
   are filled into `config.json`.

Both are one-time inputs from you; the code ships ready for them.

---

## Honesty note

Rather than fake on-chain minting or a stub leaderboard, this ships a **real,
degrade-gracefully architecture**: the client bridge, the config seam, and a
deploy-ready backend. The moment you provide a valid Mistral key, a deployed
backend URL, and real contract addresses, every Movie/Video-Game-Layer feature
activates with **no code changes** — just `config.json` + backend secrets.
