---
name: playtest-web
description: Serve the web launcher+game locally and run the smoke checklist. Use when asked to test the game, verify a change works in the browser, or before deploying.
---

# Playtest (Web) — Local Smoke Run

## The real gate: headless-browser boot test

```bash
node scripts/serve-web.mjs 8899 web &   # prod-faithful server (COOP/COEP + MIME)
CHROMIUM_BIN=/opt/pw-browsers/chromium-1194/chrome-linux/chrome \
  node scripts/verify-web.mjs http://localhost:8899/ /tmp/claude-0/shot.png
```

What it does: opens the launcher in Chromium, presses PLAY, captures EVERY
console/page error from launcher AND game iframe, probes crossOriginIsolated
+ WebGL2, clicks "PLAY LEVEL 1" in-canvas, screenshots menu and level.
**Exit 1 if the engine fails to boot OR any Godot script/parse/autoload error
appears.** Always Read the screenshots — verify with eyes, not just exit codes.

Caveat: web/game/*.pck comes from the last CI export. GDScript changes need a
push → CI export → pull cycle before they show up locally (/export-deploy).

## Endpoint checks (quick, no browser)

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8899/                    # 200
curl -s -o /dev/null -w "%{http_code} %{content_type}\n" http://localhost:8899/game/index.js
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
