# FOUNDER DIRECTIVE — Replace Smoke Lounge brand video + acknowledge PR #36

**Status**: Binding  
**Date**: 2026-08-16  
**Source**: Founder (Rich / youngstunners88)  
**For**: Claude Code (original subscription) — self-contained handoff

---

## How to use

1. `git fetch origin && git checkout master && git pull`
2. Read this entire file
3. Named branch (e.g. `claude/smoke-lounge-video-replace`)
4. OpenRouter multi-model required
5. Founder will attach **`$SL.MOV`** (or use the pre-encoded OGV if provided in session)
6. Ship via butler; hard-refresh itch before FIXED claims

**Repo:** `youngstunners88/GM-GAME`  
**Live:** https://youngstunners88.itch.io/lil-blunt-adventure  
**Engine:** Godot 4.3 · non-threaded HTML5

---

## Acknowledge what Claude did well (do not rewrite)

### Smoke Lounge video system — keep this fashion

The current Smoke Lounge brand-video wiring is **correct and must stay**:

- Full-screen **COVER** fit (fills viewport, crops overflow — not letterbox)
- **Muted** at source (`ffmpeg -an`) **and** `volume_db = -80` belt-and-suspenders
- Lounge ambient (`smoke_lounge.mp3`) keeps playing underneath
- Asset path: `res://src/assets/video/smoke_lounge.ogv` (Ogg Theora only — Godot 4.3 HTML5)
- `VideoStreamPlayer` on a CanvasLayer between room plates and gameplay
- Looping brand atmosphere (`loop = true`) as currently shipped
- Stop on `_exit_tree` when leaving the lounge
- Gate: `tests/s11_lounge_video_test.gd` (asset loads, COVER, muted, layer)

**Founder:** the way the video was created/integrated in the Smoke Lounge is really great. Do not change the playback architecture. **Only replace the media file** with the new founder clip, encoded the same way.

### PR #36 (draft) — Stake CONFIRM + Assay Scale

Claude on the original sub shipped draft **PR #36** (`claude/live-residuals-stake-assay`):

| Item | Claimed fix | Founder status |
|------|-------------|----------------|
| #1 Stake CONFIRM | Gideon terminal E now calls `GoldMineSystem.stake_in_fort_knox` (25%), float + SFX; copy honest | **Not playtested yet** — leave code; do not reopen unless CI red |
| #2 Assay Scale design | Rebuilt `_build_gold_scale` with backing panel, ~100px bands, larger scale, zero label overlap | **Not playtested yet** — leave code |
| #3 Bosses | Left untouched per founder | Still open later — **out of scope this prompt** |

**This session:** do not rework PR #36. If #36 is not merged, rebase/merge carefully so the video replace does not clobber vault residuals.

---

## This session’s job — replace the brand video only

### Source media

- **Founder file:** `$SL.MOV` (attached in session)
- **Probe:** HEVC · 1920×1080 · ~44.6s · AAC · ~63 MB
- **Content:** $SMOKE LOUNGE cinematic — neon entrance, green smoke doors, twin hosts, interior lounge, diamond $SMOKE centerpiece, floating protocol coins, energy beams, coin rain

### Required encode (same fashion as current live)

```bash
ffmpeg -y -i "$SL.MOV" \
  -an \
  -c:v libtheora -q:v 7 \
  -vf "scale=1280:720:force_original_aspect_ratio=increase,crop=1280:720" \
  -r 24 \
  src/assets/video/smoke_lounge.ogv
```

Hard rules:
1. **Replace** `src/assets/video/smoke_lounge.ogv`
2. **Strip audio** (`-an`)
3. **1280×720** landscape
4. **Theora `.ogv` only**
5. **Do not change** playback logic unless a gate fails
6. Run `tests/s11_lounge_video_test.gd`
7. Watch build size — do not regress pipeline unfreeze

---

## Skills

Load `smoke-lounge-video-replace`, `gm-game-founder-executor`, deploy/live-proof skills. Encode recipe and gates in this prompt are binding.

---

## OpenRouter multi-model (mandatory)

Claude lead + Kimi K3 verify ogv/gates/size + Grok only if COVER/mute regresses.

---

## Definition of Done

- [ ] New clip at `src/assets/video/smoke_lounge.ogv` (Theora, muted, ~1280×720)
- [ ] `s11_lounge_video_test` PASS
- [ ] Playback fashion unchanged
- [ ] PR #36 not clobbered; bosses not touched
- [ ] Butler **fresh** data; STATUS honest

---

## Prompt Claude must fulfill

```
FOUNDER DIRECTIVE ACTIVE — PROMPT_SMOKE_LOUNGE_VIDEO_REPLACE.md

ACKNOWLEDGE: Smoke Lounge video system is great — keep COVER, mute, ambient, loop. PR #36 leave unless CI forces. No bosses.

YOUR JOB: Replace smoke_lounge.ogv with founder $SL.MOV as muted Theora 1280x720. Gate s11. Butler fresh. Same fashion — new picture only.
```

End of directive.
