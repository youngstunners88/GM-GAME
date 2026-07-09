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

- **Backgrounds:** real painted scenes from your key art — DONE this update.
- **Lil Blunt character:** still a procedurally-drawn placeholder (cowboy shape).
  Needs a real transparent sprite to match the art. *Blocked on:* AI image-gen
  quota is disabled on the Gemini key — enable image billing OR provide a
  transparent character PNG and I'll wire it in immediately.
- **Enemies / collectibles / platforms:** still simple shapes; next art pass.

## 🔧 Known gaps → next up (priority order)

1. **Real Lil Blunt sprite** (transparent PNG) + walk/jump frames.
2. **Enemy sprites** (Tax Collector, fly, boulder, vine) from key art.
3. **Collectible sprites** (ETH ring, GOLD nugget, Diamond) — small, high impact.
4. **Gameplay feel pass** — tune jump/gravity/coyote-time, camera, enemy pacing.
5. **Level design depth** — more platforming, secrets, reasons to explore.
6. **Audio** — real music/SFX (currently silent placeholders).

## 🌐 Hosting note

Vercel is correct for this game. A Godot web export is a **static** bundle
(HTML/JS/WASM/PCK); static hosting is exactly right. The earlier "needs a
special non-Vercel deploy" advice was mistaken — poor feel was placeholder
art + bugs (all fixed), not hosting.

## 🗓 Changelog (newest first)

- **2026-07-09** — Real painted backdrops from client key art wired into all 3
  levels + boss arenas; platforms restyled to read over art; key art archived
  in `assets/keyart/`. Living STATUS report + always-push rule added.
- **2026-07-08** — Fixed 5 layered defects that made the game unplayable
  (boot, 8 parse errors, missing input map, black-screen scene load, empty
  level data). Added browser verification harness + `/game-graphics`,
  `/playtest-web`, `/export-deploy` skills.
