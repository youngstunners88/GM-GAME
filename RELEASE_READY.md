# Release Ready — Next Session Handoff

**Status**: Commit `eca521b` is ready locally. GitHub auth is temporarily blocked (403). This document guides the next session to restore access and ship.

## What's Ready

✅ **Non-threaded web export** — `variant/thread_support=false` in `.github/workflows/export-game.yml`  
✅ **CI pipeline complete** — exports → packages itch-ready zip → auto-deploys via butler (when secret is set)  
✅ **Butler deploy script** — `scripts/deploy_itch.sh` for manual itch.io pushes  
✅ **itch.io skill** — `/itch-deploy` with full pipeline docs  
✅ **Browser verify skill** — `/browser-verify-game` (Playwright) + `scripts/verify-game.mjs`  
✅ **Release orchestration** — `/release-game` skill + `scripts/release-game.sh` (push → export → verify → document)  
✅ **STATUS.md** — updated with owner action items  
✅ **CLAUDE.md** — deployment section + skill routing  
✅ **Commit ready** — `eca521b` with all changes, signed with correct identity  

## What's Blocked

🚫 **GitHub write access** — returns 403 on push (auth token/app permission issue)

## For Next Session (15 minutes)

### 1. Fix GitHub Access (2 min)
```bash
# Option A: Verify GitHub app
# Go to https://github.com/settings/installations → Claude app → verify GM-GAME in repo list + "Read and write" permission

# Option B: Reconnect GitHub in Claude Code
# Claude Code settings (claude.ai/code) → GitHub → disconnect → reconnect

# Test:
git push -u origin claude/setup-game-dev-environment-itWJv
# Should succeed; if 403 persists, GitHub app still doesn't have write access
```

### 2. Run Full Release Pipeline (10 min)
Once push succeeds, CI export runs automatically (5 min). Then:

```bash
/release-game
# Outputs: release-{timestamp}.json + game-verify.png
# Updates STATUS.md, commits docs
# Result: game verified live at https://lil-blunt-game.vercel.app
```

### 3. Owner Setup (parallel, can do while CI runs)
```
A. Create itch.io page:
   https://itch.io/game/new → Kind: HTML → slug: "lil-blunt-adventure" → save as Draft

B. Get deploy key:
   https://itch.io/user/settings/api-keys → generate new → copy

C. Add to GitHub:
   Repo → Settings → Secrets and variables → Actions → New repository secret
   Name: BUTLER_API_KEY
   Value: (paste from itch.io)

D. Create the page HTML:
   On itch.io edit page, set "This file will be played in the browser" + configure sizing
```

### 4. Auto-Deploy (next push)
Once BUTLER_API_KEY is set, push again (or just let CI re-run):

```bash
git push origin claude/setup-game-dev-environment-itWJv
# CI auto-exports and auto-deploys to itch.io via butler
# Game live at https://youngstunners88.itch.io/lil-blunt-adventure
```

## Timeline

| Step | Time | Status |
|------|------|--------|
| Fix GitHub auth | 2 min | Blocker |
| Push commit | 1 min | Once auth fixed |
| CI export | 5 min | Automatic |
| Browser verify | 1 min | Automatic (/release-game) |
| Update docs | 1 min | Automatic |
| Owner itch.io setup | 5 min | Parallel |
| Auto-deploy to itch.io | 2 min | Automatic (after secret is set) |
| **Total** | **~20 min** | **🎮 Game live** |

## Files Changed This Session

```
✨ NEW:
  .claude/skills/browser-verify-game/SKILL.md
  .claude/skills/release-game/SKILL.md
  scripts/verify-game.mjs (Playwright verification)
  scripts/release-game.sh (full orchestration)
  RELEASE_READY.md (this file)

📝 UPDATED:
  .github/workflows/export-game.yml (non-threaded + butler deploy)
  .claude/skills/itch-deploy/SKILL.md
  scripts/deploy_itch.sh
  STATUS.md
  CLAUDE.md
```

## How `/release-game` Works

**One command. No prompts.**

```bash
./scripts/release-game.sh
```

**What it does**:
1. Push branch (with 4x retry if network glitches)
2. Poll GitHub Actions until export completes
3. Verify export files (index.html, index.wasm, index.pck)
4. Run Playwright verification (boot test, screenshot, console check)
5. Update STATUS.md with verification entry
6. Commit + push docs back to branch
7. Output: `release-{timestamp}.json` + `game-verify.png`

**Exit code**:
- `0`: success, game verified live
- `1`: push failed (GitHub auth)
- `2`: CI export failed
- `3`: browser verify failed (game won't boot or threading error)

## To Ship from Next Session

**In order**:

```bash
1. Fix GitHub auth (verify Settings → GitHub or wait for env fix)

2. ./scripts/release-game.sh
   # Outputs: release-*.json + game-verify.png
   # Game now live at https://lil-blunt-game.vercel.app

3. Owner: create itch.io page + add BUTLER_API_KEY secret
   # (while step 2 is running, or right after)

4. git push origin claude/setup-game-dev-environment-itWJv
   # CI auto-exports and auto-deploys to itch.io
   # Game now live at https://youngstunners88.itch.io/lil-blunt-adventure

5. Merge to master (after owner confirms the itch.io build works)
   # Keeps repo homepage current with full project
```

## Key Decisions Made

**Thread support = false**: Godot threaded web export needs SharedArrayBuffer, which silently fails on itch.io default sandbox + iframes + some mobile browsers. Non-threaded build runs everywhere. This was the root cause of "game sometimes doesn't play".

**Autonomous skills**: `/browser-verify-game` and `/release-game` run fully hands-off (after next session's GitHub fix). No prompts, no human decision gates. Screenshot + JSON result are the artifacts.

**itch.io first**: Vercel is a mirror only. itch.io is the primary platform (game discovery, no cold starts, native CDN).

## Questions?

- **"What if GitHub auth is still 403?"** → Reconnect GitHub in Claude Code settings, or check the Claude GitHub App's permissions at github.com/settings/installations
- **"What if CI export fails?"** → Check `.github/workflows/export-game.yml` run logs. Most likely: project.godot syntax error, or missing export templates.
- **"What if browser verify fails?"** → Check `game-verify-*.json` for console errors. If "SharedArrayBuffer" appears, thread_support got flipped back to true.
- **"Can I run /release-game before owner creates the itch.io page?"** → Yes. The game will be verified on Vercel. Itch.io deploy happens on the *next* push (after BUTLER_API_KEY is set).

## Success Checklist (for next session)

- [ ] GitHub auth fixed and push succeeds
- [ ] `/release-game` runs successfully
- [ ] `game-verify.png` shows cowboy Lil Blunt on first platform
- [ ] `game-verify-*.json` shows all tests PASS, zero errors
- [ ] STATUS.md updated with verification entry + screenshot reference
- [ ] Owner creates itch.io page + adds BUTLER_API_KEY secret
- [ ] Next push auto-deploys to itch.io
- [ ] Game playable at https://youngstunners88.itch.io/lil-blunt-adventure

---

**Owner next action**: Fix GitHub auth, then tell the agent "push" — everything else is automatic.
