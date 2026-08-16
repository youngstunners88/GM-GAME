---
name: smoke-lounge-video-replace
description: Replace the Smoke Lounge brand video asset while preserving full-screen COVER mute loop playback. Use when founder supplies a new $SMOKE LOUNGE clip, $SL.MOV, smoke_lounge.ogv, or asks to swap the lounge intro or brand video without redesigning secret_realm playback.
---

# Smoke Lounge video replace

## Non-negotiables (do not redesign)

Playback in `src/level/secret_realm.gd` is already correct:

- Path constant `LOUNGE_VIDEO` = `res://src/assets/video/smoke_lounge.ogv`
- COVER fit (fills viewport; crop overflow)
- `loop = true`
- `volume_db <= -40` (prefer -80)
- Source encode uses `-an` (no audio stream)
- Lounge ambient continues underneath
- Stop on `_exit_tree`
- Gate `tests/s11_lounge_video_test.gd`

**Only replace the file at `src/assets/video/smoke_lounge.ogv`.** Do not invent a second path or switch to mp4/webm for HTML5.

## Encode recipe

Founder source is often HEVC/MOV/MP4. Godot 4.3 HTML5 needs **Ogg Theora**:

```bash
ffmpeg -y -i SOURCE \
  -an \
  -c:v libtheora -q:v 7 \
  -vf "scale=1280:720:force_original_aspect_ratio=increase,crop=1280:720" \
  -r 24 \
  src/assets/video/smoke_lounge.ogv
```

Verify:

```bash
ffprobe -show_entries stream=codec_name,width,height -show_entries format=duration \
  -of default=noprint_wrappers=1 src/assets/video/smoke_lounge.ogv
```

Expect: `theora`, 1280, 720, no audio stream.

If CI/build size blows up, retry with `-q:v 5` or `6`. Do not regress the export pipeline (comment-free preset, untracked pck, exclude_filter).

## Gates before FIXED

1. `tests/s11_lounge_video_test.gd` — asset exists, VideoStreamTheora, COVER, muted, layer
2. Security Sentinel
3. Butler reports **fresh** data (not 0 B)
4. STATUS notes hard-refresh required on itch Smoke Lounge

## Out of scope

- Stake CONFIRM / Assay Scale (PR #36 domain) unless this branch must rebase
- Boss chase
- Changing loop vs one-shot unless founder explicitly orders it
