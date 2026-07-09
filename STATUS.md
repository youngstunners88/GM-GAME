# 🌿 Lil Blunt: The Smoke Realm — Live Status Report

**Play it:** https://lil-blunt-game.vercel.app
**Branch:** `claude/setup-game-dev-environment-itWJv` · **PR #2**

> This report is updated, committed, and pushed on every change so you always
> have something current to look at. Last updated: **2026-07-09**.

---

## ▶️ What works right now

| System | State |
|---|---|
| Boots & plays on mobile/desktop | ✅ Live |
| Controls (run / jump / double-jump / sprint / dash) | ✅ In build |
| 3 levels + boss arenas | ✅ Load & spawn |
| Painted key-art backdrops (your art) | ✅ **NEW** — GM Forest, Crystal Caves, Gold Rush |
| Boss backdrop swap (Tax Collector / Crystalline Bureaucrat / Bandit) | ✅ **NEW** |
| Collectibles: coins, ETH rings, GOLD, wBTC, Diamonds | ✅ |
| Combo system + score multiplier | ✅ |
| Blaze Rush secret runs (Geometry-Dash) | ✅ unlock at score thresholds |
| GoldMine economy (GOLD/wBTC/XAUT/Diamond, whitepaper split) | ✅ |
| Browser auto-verification gate (catches crashes pre-deploy) | ✅ |

## 🎨 Art status

- **Backgrounds:** purpose-made client environments — GM Forest, Crystal
  Caves, Gold Mine interior, FOMO boss arena. DONE.
- **Lil Blunt:** REAL pixel-art sprites in-game — cowboy (L1/L3), miner &
  crystal outfits (L2), auto-swapped per level. DONE this update.
- **Bosses:** real sprites — IRS Tax Collector, Crystalline Bureaucrat,
  Bandit mine-cart. DONE this update.
- **Enemies / collectibles:** still simple shapes; next art pass (need
  transparent PNGs for Tax Collector minion, fly, boulder, vine, ring, coin).

## 🔧 Known gaps → next up (priority order)

1. **Enemy + collectible sprites** (minions, fly, boulder, vine, ETH ring,
   coin, GOLD nugget, Diamond) — the last placeholder shapes.
2. **Walk/jump animation frames** for Lil Blunt (currently single pose + flip).
3. **Gameplay feel pass** — tune jump/gravity/coyote-time, camera, enemy pacing.
4. **Level design depth** — more platforming, secrets, reasons to explore.
5. **Audio** — real music/SFX (currently silent placeholders).

## 🌐 Hosting note

Vercel is correct for this game. A Godot web export is a **static** bundle
(HTML/JS/WASM/PCK); static hosting is exactly right. The earlier "needs a
special non-Vercel deploy" advice was mistaken — poor feel was placeholder
art + bugs (all fixed), not hosting.

## 🗓 Changelog (newest first)

- **2026-07-09 (verified+live)** — Sprite build browser-verified (cowboy Lil
  Blunt standing on GM Forest platforms, 0 errors), deployed to production,
  and **merged to master** — the repo homepage now shows the full project.
- **2026-07-09 (later)** — REAL CHARACTER ART IN-GAME: client sprites wired
  for Lil Blunt (cowboy/miner/crystal outfits, per-level swap, feet-aligned)
  and all bosses (Tax Collector, Crystalline Bureaucrat, Bandit cart).
  Purpose-made environments replace cropped backdrops. New /sprite-pipeline
  skill. Rules added: keep master current + model advice each response.

- **2026-07-09** — Real painted backdrops from client key art wired into all 3
  levels + boss arenas; platforms restyled to read over art; key art archived
  in `assets/keyart/`. Living STATUS report + always-push rule added.
  **Browser-verified (GM Forest renders, 0 errors) + deployed to production.**
  Remaining eyesore now = enemies/coins/character are still small shapes over
  the art — that's the next sprite pass (needs image-gen key or supplied PNGs).
- **2026-07-08** — Fixed 5 layered defects that made the game unplayable
  (boot, 8 parse errors, missing input map, black-screen scene load, empty
  level data). Added browser verification harness + `/game-graphics`,
  `/playtest-web`, `/export-deploy` skills.
