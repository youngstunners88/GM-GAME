---
name: browser-verify-game
description: Playwright-based boot verification for Godot 4.3 web exports. Tests that the game loads, level 1 boots, sprites render, and console is clean. Captures screenshot as proof. Use after every export to gate release readiness.
---

# Browser Verify Game — Godot Web Export QA

Automated end-to-end test that the game actually boots and plays in a real browser.
Runs locally or in CI. Returns JSON result + screenshot.

## Prerequisites
- Chromium at `/opt/pw-browsers/chromium` (pre-installed)
- Node.js + Playwright: `npm install -D @playwright/test`

## Run (one-liner)
```bash
node scripts/verify-game.mjs https://lil-blunt-game.vercel.app
# Output: game-verify-{timestamp}.json (structured result) + game-verify.png (screenshot)
```

## What it tests

1. **Boot** (10s timeout): Godot splash screen loads, canvas appears
2. **Level 1 interactive** (3s wait): game input responsive, sprites visible
3. **Console clean**: no errors logged (except expected Godot warnings)
4. **Critical check**: NO "SharedArrayBuffer is not defined" (thread_support=false required)
5. **Screenshot**: proof of running game state

## Script (scripts/verify-game.mjs)

See implementation in git history or copied below.

### Installation
```bash
npm install -D @playwright/test
```

### Usage in CI

Add to `.github/workflows/export-game.yml` after export step:
```yaml
- name: Verify game boots (Playwright)
  if: success()
  run: |
    npm install -D @playwright/test
    node scripts/verify-game.mjs "file://$(pwd)/web/game/index.html" || exit 1
    
- name: Upload verification screenshot
  if: always()
  uses: actions/upload-artifact@v4
  with:
    name: game-verification
    path: |
      game-verify-*.json
      game-verify.png
    retention-days: 7
```

## Gotchas

- **Timeout tuning**: 10s for boot is generous for Vercel; local exports may need less
- **File URLs**: use `file://$PWD/web/game/index.html` for local exports
- **SharedArrayBuffer critical**: if this error appears, thread_support=true; must flip back to false and re-export
- **Screenshot timing**: taken immediately after Level 1 loads; if you want longer gameplay proof, add `await page.waitForTimeout(5000)` before screenshot

## Exit codes
- **0**: all tests passed, screenshot captured
- **1**: boot failed or critical error found
