---
name: ep2-seedance-film
description: Make, compose and wire an Episode 2 story film with Seedance 2 on Muapi - keyframes (nano-banana-pro-edit) -> i2v clips -> silent concat -> dialogue + foley (NO MUSIC) -> Ogg Theora -> Godot. TRIGGER on "film", "Seedance", "Muapi", "transition video", "cutscene video", edits to tools/ep2_film/, ep2_cliff_to_hideout.ogv, ep2_video_film.gd.
---
# What exists (founder 2026-10-03, "no music, I will add the music later")
`src/assets/video/cutscenes/ep2_cliff_to_hideout.ogv` (30.3 s, 960x540, Theora q2, 4.4 MB): cart leaves the mine -> flies the gap -> knocked out on a stump -> Inferno Bull patches him with whiskey -> introductions, Winchester 1886 + helmet for one Bitcoin -> target practice. The doc: https://docs.google.com/document/d/1m65rGpAMAJsf4moMXvvCQ2MDMdXSI-WZQJwJiaGc-Jk
# Pipeline (all in `tools/ep2_film/`)
1. Keyframes: founder PNGs (Drive, `uc?export=download&id=..&confirm=t` with curl; the Drive MCP fails over 10 MB). A missing beat -> `muapi_film.py edit out.png "prompt" <kf url> <ref url>` (nano-banana-pro-edit, $0.12). View it before using it.
2. `film.json` = `style` (always ends "no music, no score") + shots `{id, prompt, images[], duration 5|10}`. `python3 tools/ep2_film/muapi_film.py shot A_cliff` (needs `MUAPI_API_KEY` in the env; never inline it). Shots can run in parallel (separate processes). Cost seen: $1.50 per 10 s 720p basic clip, 4 clips = $4.50; `balance` before/after. Renders take ~8-15 min.
3. REVIEW frames (`ffmpeg -vf fps=1,scale=400:-1,tile=5x2`) before accepting; re-run a shot, never hand-fix.
4. `compose_film.py` + `timeline.json`: concat video only (`-an`: the Seedance audio is thrown away, it can carry music), then cues at timestamps: ElevenLabs lines `film_*` (manifest ids in `assets/audio-manifest.json`, generate with `scripts/generate_audio.py`) and foley `ep2_film_*.mp3`. **Never add a music cue.** Output Theora q2 + Vorbis q2 at 960x540 (looks fine, 4.4 MB). **The pck gate is 190 MB and the first ship (q4, 8.3 MB) hit 193 MB and failed CI**, so every MB counts; film_* voice lines live in `tools/ep2_film/voice/` (NOT src/), move them there after `generate_audio.py` writes them to src/assets/sounds/voice/.
5. Wiring: `Ep2VideoFilm` (src/episode2/cinematic) + `SmeltingFacilityChamber._start_video_film`. Missing .ogv -> falls back to the in-engine `CliffJumpCinematic`. Change `FILM_SECONDS` when the film length changes.
# Rules
- Godot 4.3 web plays only Ogg Theora. The Music bus is muted while the film plays (restored on finish/exit).
- Hold SPACE 0.9 s to skip. After the film the game state = Winchester + helmet + 1 BTC, beat VERB_TEACH, first person.
- Proof: `xvfb-run ... res://tools/ep2_shots/video_film_shot.tscn` (real render, frames at real seconds + after skip), then a board of the shots.
