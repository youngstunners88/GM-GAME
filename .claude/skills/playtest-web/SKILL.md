---
name: playtest-web
description: Serve the web launcher+game locally and run the smoke checklist. Use when asked to test the game, verify a change works in the browser, or before deploying.
---

# Playtest (Web) — Local Smoke Run

## Serve

```bash
npx -y serve -l 8765 web   # from repo root; Ctrl-C to stop
```

Note: `serve` does not send COOP/COEP headers, so the threaded Godot build
may refuse to boot the engine locally. Launcher UI, asset presence, and
content-type checks still validate fine; full engine boot is verified on
Vercel (headers configured there).

## Endpoint checks

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8765/                    # 200
curl -s -o /dev/null -w "%{http_code} %{content_type}\n" http://localhost:8765/game/index.js
# 200 + application/javascript when the game is exported; 404 when not.
# The launcher treats a text/html response as "not exported" (SPA-fallback guard).
```

## Gameplay smoke checklist (run on the live URL or in Godot editor)

- [ ] Launcher renders; PLAY opens the game iframe (no black screen)
- [ ] Touch joystick + JUMP respond on mobile; keyboard A/D/Space on desktop
- [ ] HUD shows SCORE / hearts / 🪙 / 💍 / GOLD / wBTC / XAUT / 💎 / 💨 rows
- [ ] Collecting coins raises score; combo indicator reacts in launcher overlay
- [ ] Blaze Portal in Level 1 shows "??? 1500 PTS" and unlocks at threshold
- [ ] Entering unlocked portal → Blaze Rush loads; tap jumps; crash restarts instantly
- [ ] Finishing a run returns to the level at the portal; 💨 SMOKE banked
- [ ] Death forfeits 50% GOLD (toast) and respawns at checkpoint
- [ ] Pause menu resumes/restarts/quits without freezing
