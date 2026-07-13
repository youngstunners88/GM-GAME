---
name: release-game
description: End-to-end game release orchestration. Push branch → poll CI export → browser verify → update STATUS.md. One command, fully hands-off pipeline. Use when ready to ship to production.
---

# Release Game — Push → Export → Verify → Document

Complete release automation: from local commit to verified live game on Vercel/itch.io.

## One-liner
```bash
/release-game
```

Outputs: `release-{timestamp}.json` (structured result) + `game-verify.png` (screenshot)

## What it does (fully automated)

1. **Security Sentinel** — runs `scripts/security-sentinel.sh` (18 checks
   across secrets, dynamic-execution/injection, deploy integrity, wallet-UI
   trust, and CI hygiene — the automated implementation of
   `docs/security/GAME_SECURITY_CHECKLIST.md`, also documented as the
   `game-security-sentinel` skill). Blocks the release on any critical/high
   finding — this is the "runs autonomously, never needs to be asked for"
   gate from CLAUDE.md's SECURITY-GATE RULE. `--log` appends the run to
   `docs/security/audit-log.md` automatically.
2. **Push branch** — `git push -u origin <branch>` with 4x retry (2s, 4s, 8s, 16s backoff)
3. **Poll CI** — GitHub Actions API every 10s until `export-game` workflow completes (5 min max)
4. **Verify export** — downloads artifact, checks for index.html / index.wasm / index.pck
5. **Browser test** — runs `scripts/verify-game.mjs` on Vercel build (screenshot + console check)
6. **Update STATUS.md** — adds changelog entry with commit, verification timestamp, screenshot reference
7. **Commit docs** — commits STATUS.md back to branch (ensures docs are always current)
8. **Report** — JSON summary: pass/fail, screenshot path, console errors (if any), next steps

## Exit codes
- **0**: release succeeded, game verified live, docs updated
- **1**: push failed (GitHub auth or network)
- **2**: CI failed (export errored, see workflow log)
- **3**: browser verification failed (game won't boot or threading error)
- **4**: fatal error (missing files, git config broken)
- **5**: Security Sentinel found a blocker — see console output for which
  check, fix it, then re-run (do not bypass; see
  `docs/security/GAME_SECURITY_CHECKLIST.md` and `scripts/security-sentinel.sh`)

## Usage

**Manual (local)**:
```bash
./scripts/release-game.sh
```

**In CI (scheduled or on-demand)**:
```yaml
name: Release Pipeline
on:
  schedule:
    - cron: '0 2 * * 0'  # Weekly Sunday 2 AM
  workflow_dispatch:

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: ./scripts/release-game.sh
      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: release-result
          path: release-*.json
```

## Result JSON

```json
{
  "status": "SUCCESS",
  "branch": "claude/setup-game-dev-environment-itWJv",
  "commit": "eca521b",
  "timestamp": "2026-07-10T03:45:22Z",
  "steps": {
    "push": { "status": "PASS", "commit": "eca521b" },
    "ci_export": { "status": "PASS", "workflow_id": "12345", "artifact": "godot-web-export" },
    "browser_verify": { "status": "PASS", "screenshot": "game-verify.png", "tests": { "boot": "PASS", "level_1": "PASS", "thread_support": "PASS" } },
    "docs_update": { "status": "PASS", "files_updated": 1 }
  },
  "vercel_url": "https://lil-blunt-game.vercel.app",
  "itch_url": "https://youngstunners88.itch.io/lil-blunt-adventure (requires BUTLER_API_KEY secret)",
  "next_steps": "Owner: create itch.io page + add BUTLER_API_KEY secret; re-run to auto-deploy"
}
```

## Diagnostics

If the script fails:
1. Check `.github/workflows/export-game.yml` for export errors
2. Verify `git push` has auth (test with a dummy branch)
3. Look at `game-verify-*.json` for console errors
4. Check STATUS.md was updated (may be ahead of remote)

## Gotchas

- **Git push retry**: if GitHub auth is revoked, all 4 attempts fail; you'll need to reconnect GitHub in Claude Code settings
- **CI polling**: if the workflow takes >5 min, the script times out (adjust timeout in script if needed)
- **File URLs**: script uses Vercel URL by default; swap to `file://` for local exports if needed
- **STATUS.md commit**: if STATUS.md update fails, the release is still complete (game is live), but docs aren't current — manual push of STATUS.md needed
- **Playwright**: requires Node.js + `npm install -D @playwright/test`; handled automatically if missing
