# FOUNDER DIRECTIVE — New subscription handoff: finish Smoke Lounge video (PR #37)

**Status**: Binding  
**Date**: 2026-08-16  
**Source**: Founder (Rich / youngstunners88)  
**For**: Claude Code on the **NEW subscription** (old subscription hit rate limits mid-task)

This file is the full context handoff. Read it end to end. Do not ask the founder to re-explain.

---

## How to start

```bash
git fetch origin
git checkout master && git pull
# Then inspect the video branch / PR #37
git fetch origin claude/smoke-lounge-video-replace
gh pr view 37
gh pr checks 37
```

**Repo:** `youngstunners88/GM-GAME`  
**Live:** https://youngstunners88.itch.io/lil-blunt-adventure  
**Engine:** Godot 4.3 · non-threaded HTML5 · butler → itch

---

## Why you are here (dual-subscription)

| Session | Role | State |
|---------|------|--------|
| **Old subscription** | Built PR #36 (stake/Assay) and **PR #37** (video replace) | Rate-limited — stopped before merge/deploy confirmation |
| **New subscription (you)** | Finish the in-flight video ship | **Driving now** |

Do not re-encode the video from scratch unless the asset is missing or corrupt on the branch. Prefer: verify CI → undraft → merge → butler fresh → stop.

---

## What is already done (do not redo)

### Vault music (shipped on master)
- `diamonds_are_forever.mp3` / `goldmine.mp3` exclusive tracks
- PR #35 era merged; parent stage themes removed from vaults

### Deploy pipeline (shipped on master)
- Was frozen for many sessions (`#` comments in preset → no pck → butler 0 B fresh)
- Fixed: comment-free preset, pipefail, untracked `index.pck`
- **Do not regress**

### Smoke Lounge **playback architecture** (correct — never redesign)
- Path: `res://src/assets/video/smoke_lounge.ogv`
- Full-screen **COVER**, `loop = true`, `volume_db = -80`, ambient continues
- Gate: `tests/s11_lounge_video_test.gd`
- Founder explicitly praised this integration

### PR #37 work (old sub — claimed complete on branch, not necessarily merged)
- Branch: `claude/smoke-lounge-video-replace`
- Replaced `src/assets/video/smoke_lounge.ogv` with founder cinematic
- Encode: Theora · 1280×720 · muted · ~44.6s · ~28 MB
- Content: neon $SMOKE LOUNGE entrance, green smoke doors, interior, diamond centerpiece, protocol logos, coin rain
- `secret_realm.gd` **unchanged** (new picture only)
- Claimed: s11 5/5 PASS, Security Sentinel 18/18
- Multi-model (Kimi + Grok) claimed run
- Skill `smoke-lounge-video-replace` claimed added
- **Draft PR #37** opened against master
- **Not live on itch until merged + butler fresh + founder hard-refresh**

### PR #36 (separate draft — not your merge target unless founder says)
- Branch: `claude/live-residuals-stake-assay`
- Gideon terminal E → real Fort Knox stake (25%) + float
- Assay Scale layout rebuilt (no overlap, larger)
- Founder has **not** playtested yet
- **Leave alone** this session unless CI on #37 requires a trivial rebase

### Bosses
- Still open historically (chase / Claim Jumper difficulty)
- **Out of scope** this prompt

---

## Your job (this session only)

1. **Fetch and verify** branch `claude/smoke-lounge-video-replace` / PR #37  
   - Confirm `smoke_lounge.ogv` is Theora 1280×720, no audio  
   - Re-run `tests/s11_lounge_video_test.gd` if unsure  
2. **CI** — wait for Export / deploy checks green on the **latest** head commit  
3. **Undraft + merge PR #37 → master** when green and mergeable  
4. **Confirm butler** shipped **fresh** data (not 0 B) on the post-merge master run  
5. **STATUS.md** — honest: video merged; founder must hard-refresh Smoke Lounge (`Ctrl/Cmd+Shift+R`)  
6. **Stop** — do not start bosses or rework PR #36

If PR #37 is already merged when you start: only verify live deploy path and STATUS; do not re-encode.

If CI failed on size: re-encode with `-q:v 5` or `6` (same recipe otherwise), push, re-gate — do not touch playback code.

### Encode recipe (only if re-encode required)

```bash
ffmpeg -y -i SOURCE \
  -an \
  -c:v libtheora -q:v 7 \
  -vf "scale=1280:720:force_original_aspect_ratio=increase,crop=1280:720" \
  -r 24 \
  src/assets/video/smoke_lounge.ogv
```

Source was founder `$SL.MOV` / Drive clip (HEVC 1920×1080 ~44.6s). Prefer the file already on the PR branch.

---

## OpenRouter multi-model (mandatory every session)

| Model | Role |
|-------|------|
| Claude Code | Lead — CI, merge, butler, STATUS |
| Kimi K3 | Verify ogv / s11 / no playback regression |
| Grok 4.5 | Only if COVER/mute/feel regresses |

Log under `docs/model-responses/`.

---

## Definition of Done

- [ ] PR #37 merged to master (or already merged and verified)
- [ ] Post-merge CI green; butler **fresh** data includes new video
- [ ] s11 gate still PASS on merged tree
- [ ] Playback architecture unchanged
- [ ] PR #36 not clobbered; bosses not touched
- [ ] STATUS tells founder to hard-refresh Smoke Lounge
- [ ] OpenRouter multi-model evidenced

---

## Prompt Claude must fulfill

```
FOUNDER DIRECTIVE ACTIVE — PROMPT_NEW_SUB_FINISH_VIDEO_PR37.md

You are the NEW Claude subscription. Old sub rate-limited after building draft PR #37 (Smoke Lounge video replace).

ACKNOWLEDGE — do not redo:
- Vault music + pipeline unfreeze (master)
- Lounge playback architecture (COVER/mute/loop/path) — founder loves it
- PR #36 stake/Assay draft — leave unless forced by rebase
- Bosses — out of scope

YOUR JOB:
1. Take over claude/smoke-lounge-video-replace / PR #37
2. Verify asset + s11 if needed; wait CI green
3. Undraft + merge #37 → master
4. Confirm butler fresh data
5. STATUS: founder hard-refreshes Smoke Lounge
6. Stop

OpenRouter multi-model required. No FIXED without merge + fresh butler.
```

End of directive.
