---
name: founder-video-intake
description: Turn a founder-supplied video (Drive link, often 1080p HEVC from a phone) into a shipped in-game film within the 190 MB pack gate. TRIGGER when the founder sends a drive.google.com video/mp3 link or a Google Doc listing a video and a song, says "replace the video with this", or calls a generated film trash.
---
# Steps
1. **Read the doc** (`mcp__Google_Drive__read_file_content`) for what the video is and any song/timing notes.
2. **Download** (the MCP caps at 10 MB and the link must be public): `curl -sSL -o x.mp4 "https://drive.google.com/uc?export=download&id=<ID>&confirm=t"`; if the file is HTML the link is private - ask the founder to set "Anyone with the link: Viewer".
3. **Probe and look**: `ffprobe` (codec, size, duration), contact sheet `ffmpeg -vf fps=1/5,scale=400:-1,tile=4x3`. Do not edit his content; use it as delivered.
4. **Encode** Godot-web video: Ogg Theora + Vorbis only, `scale=1024:576:flags=lanczos,fps=24`, `-q:v 2` (60 s = 8.5 MB; q3 = 11 MB), `-c:a libvorbis -q:a 3`. Dimensions must be multiples of 16.
5. **Budget the pack** BEFORE adding: CI gate is 190 MB (`index.pck`). Remove what the new file replaces and anything provably unused: a file with no reference by name anywhere in src/tests/scripts (check for dynamic names), e.g. `fresh_boost*.ogg` and the six `br_*`/`*_scroll` art PNGs went in 2026-10-04 (-8 MB). GLB-embedded textures are referenced by the GLB, not by name: check `ResourceLoader.get_dependencies`.
6. **Song**: see `ep2-theme-song-handoff` (measure the offset, never guess).
7. **Prove**: real render via `tools/ep2_shots/video_film_shot.tscn`, tests green, ship, verify CI + the itch page timestamp.
