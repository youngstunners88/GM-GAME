---
name: browser-verify-game
description: Playwright-based boot + gameplay verification for Godot 4.3 web exports. Proves the engine boots past the splash, Level 1 actually runs, and the console is clean. Captures menu + gameplay screenshots as evidence. Use after every export, before telling the client anything is live.
---

# Browser Verify Game — Godot Web Export QA (tested & proven)

Drives the real game in headless Chromium and fails unless actual gameplay is
reached. A splash screen or main menu alone is NOT a pass — early versions of
this check passed on the Godot loading bar; the current gates can't.

## Run

```bash
# 1. Serve the export with production-faithful headers (COOP/COEP + MIME):
node scripts/serve-web.mjs 8899 web &

# 2. Verify (defaults shown):
node scripts/verify-game.mjs "http://localhost:8899/game/index.html"
# Artifacts: game-verify.json, game-verify.png (menu), game-verify-level.png (gameplay)
# Exit 0 = verified; non-zero = failed (details in game-verify.json)
```

For the Vercel **launcher page** (PLAY button + iframe) use the older
`scripts/verify-web.mjs` instead — it knows the launcher DOM.

## The five gates (all must pass)

1. **canvas_attached** — page loads, Godot canvas element appears
2. **engine_booted** — the `#status` loading overlay hides AND the canvas
   leaves its default size (polled up to 45s). This is what separates "real
   boot" from "pretty splash screen".
3. **no_godot_errors** — no `USER SCRIPT ERROR`, `Parse Error`, autoload or
   InputMap failures in console
4. **thread_support** — no SharedArrayBuffer errors (would mean
   `thread_support=true` regressed; that breaks itch.io/mobile)
5. **level_1_runs** — clicks PLAY LEVEL 1 mid-canvas (x 0.5, y 0.60 of the
   viewport — re-measured 2026-07-19 after the menu grew a subtitle; 0.553
   now misses high), presses Escape ~2.5s later (skips the one-time email
   signup panel via its keyboard path; harmless otherwise), then REQUIRES the
   game's own `PLAYING` state beacon within 20s. The StateMachine posts
   `{type:"state", value:<STATE>}` via same-origin postMessage on every
   transition — a missed click or a level that fails to load now FAILS this
   gate instead of false-passing on "no new errors" (which once shipped a
   menu screenshot as "gameplay evidence").

## Known-benign console patterns (do NOT fail the run)

- `USER WARNING` / `at: push_warning` — Godot warnings routed via console.error
- `No loader found for resource: res://src/assets/(sounds|music)/...` —
  placeholder audio missing from older packs (fixed in audio_manager.gd with
  `ResourceLoader.exists()` guards)
- `Blocking on the main thread...` — emscripten notice, threaded builds only

If you see a NEW noisy-but-benign pattern, add it to the `benign` regex in
`scripts/verify-game.mjs` with a comment saying why.

## Environment gotchas (each cost real debugging time)

- **Chromium path**: `/opt/pw-browsers/chromium` is a symlink to the real
  binary — use it directly as `executablePath`.
- **WebGL**: headless Chromium has no GPU; without the SwiftShader flags
  (`--enable-unsafe-swiftshader --use-gl=angle --use-angle=swiftshader`)
  Godot's renderer fails even though the page loads.
- **Remote-sandbox egress**: the session proxy BLOCKS all external HTTPS from
  Chromium (ERR_CONNECTION_RESET, even for example.com). Verify against
  `localhost` via serve-web.mjs — `web/game/` is byte-identical to the deploy,
  so this is authoritative. Live-URL verification belongs in CI.
- **Click target**: PLAY LEVEL 1 button center is y≈0.553 of the viewport.
  0.517 misses high and re-triggers the menu ("MENU → MENU" warning).

## CI integration

```yaml
- name: Browser verify export
  if: success()
  run: |
    npm install --no-save @playwright/test
    npx playwright install chromium --with-deps
    node scripts/serve-web.mjs 8899 web &
    sleep 2
    CHROMIUM_BIN="" node scripts/verify-game.mjs "http://localhost:8899/game/index.html"
- name: Upload verification evidence
  if: always()
  uses: actions/upload-artifact@v4
  with:
    name: game-verification
    path: |
      game-verify.json
      game-verify*.png
    retention-days: 7
```
(In CI, unset/adjust `CHROMIUM_BIN` — the `/opt/pw-browsers` path is specific
to the Claude remote sandbox.)

## Evidence contract

A verification is only citable to the client if `game-verify-level.png` shows
Lil Blunt in a level with the HUD rendering. Attach that screenshot; the menu
shot alone proves nothing about gameplay.
