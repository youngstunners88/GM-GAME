# Smoke Lounge background video

`docs/directives/FOUNDER_SMOKE_LOUNGE_VIDEO.md` is a binding founder directive:
the official **$SMOKE LOUNGE** brand video is the Smoke Lounge's atmospheric
background.

**The asset is not in this repository.** The directive refers to a video
"supplied by the founder" that was never committed — nothing matching it exists
under any tracked path. The wire-up is shipped and waiting for the file.

## To make it live

Drop the encode here:

    src/assets/video/smoke_lounge.ogv

Then run `godot --headless --import` once (Godot will not load a media file it
has never imported) and the lounge picks it up on the next load — full-bleed,
looping, behind the gameplay plane, muted so the lounge's own music crossfade
still owns the audio. No code change is needed.

## Why `.ogv` and not `.mp4`

**Ogg Theora is the only format Godot 4.3's `VideoStreamPlayer` decodes without
a plugin**, and the only one that survives the HTML5 export the game ships on.
An `.mp4` or `.webm` dropped here will not play.

Convert with:

    ffmpeg -i smoke_lounge.mp4 -c:v libtheora -q:v 7 -an src/assets/video/smoke_lounge.ogv

`-an` strips the audio track (the video is played muted regardless, and
dropping it keeps the file smaller).

## Keep it small

Theora is CPU-decoded in the browser. The lounge is a short detour, so a loop
of roughly 10–20 seconds at 1280x720 is the target; a multi-minute 1080p encode
will cost frame rate on mid-range machines and add weight to every page load.

## Fallback

If the file is absent, or fails to decode on a given browser, the existing
parallax room art remains — the lounge never falls back to a black screen.
