---
name: gm-game-varco-ep2
description: VARCO REST for Episode 2 SFX/ambience and optional 3D blockouts. TRIGGER on varco, SFX, foley, mine ambience, cart rails, bear growl, text2sound. Read VARCO_API_KEY from env. Never print it.
---

# What VARCO is
NCSOFT VARCO. REST only in this repo (no Godot plugin).
Docs: https://api.varco.ai/en/docs/introduction
Sound: https://api.varco.ai/en/docs/sound-texttosound
Auth header: OPENAPI_KEY
Env we use: VARCO_API_KEY  (also accept OPENAPI_KEY if that is what is set)
Presence-check only. If missing, STOP and name the var.

# Routing — do not mix vendors
VARCO
  Foley, ambience, loops, hazard one-shots, bear animal convert.
  text2sound, variation, loop, enhance.
ELEVENLABS
  Spoken human VO (Winchester, Bull, Claim clerk).
MESHY
  Hero / revolver / bear / cart MESH.
  Varco 3D is optional prop blockout ONLY if Meshy is down.
  Never two hero pipelines in one session.
FILMERA
  Cutscene picture. Not SFX.

Varco music-generation is plugin-only / not the text2sound contract.
Do not call Varco for a theme song. Score drone in runner.json is a TEXT2SOUND bed, not a track.

# Call
POST https://openapi.ai.nc.com/sound/varco/v1/api/text2sound
Header OPENAPI_KEY: $VARCO_API_KEY
Body { "prompt": "<≤400 bytes>", "num_sample": 3 }
Output: 10s, 44.1kHz 16-bit WAV, base64 in the JSON.
Pick the best sample. For loops, run Varco loop/variation on that take,
then trim in Godot (AudioStreamWAV.loop_mode) if the API loop is absent.

Do not invent extra endpoints. If a loop/variation URL 404s, keep the raw 10s
and loop in Godot. Log the 404 in artifacts/episode2-gold-mine/audio/LOG.md.

# Separation of concerns
Catalog (prompts, ids, layer, loop flag)
  artifacts/episode2-gold-mine/audio/prompts/
    runner.json          ← already exists, REUSE
    smelting.json
    winchester.json
  Re-version the JSON. Do not silently edit prompts after a good take.

Takes (raw API bytes)
  artifacts/episode2-gold-mine/audio/takes/<stem_id>/vN.wav

Promoted game assets (only after a listen)
  src/episode2/assets/audio/<stem_id>.wav

Godot wiring
  src/episode2/runner/   plays runner stems
  src/episode2/chamber/  plays chamber stems
  src/episode2/session/  does NOT own files; it only knows
    which bed is current (runner | chamber_id)
Buses: Master / Music / SFX / Voice. Cart rails = SFX. Score drone = Music.
VO = Voice. Never put a bear growl on Voice.

# First generate list (runner.json, do not rewrite the copy)
  ep2_runner_bed_mine_loop_01
  ep2_runner_cart_rails_loop_01
  ep2_runner_zipline_rush_01
  ep2_runner_duck_01
  ep2_runner_jump_land_01
  ep2_runner_arrow_flyby_01
  ep2_runner_arrow_flyby_02
  ep2_runner_boulder_roll_01
  ep2_runner_bear_distant_01
  ep2_runner_score_drone_loop_01

Then add gun layer (new ids, new json file
  artifacts/episode2-gold-mine/audio/prompts/revolver.json):
  ep2_revolver_fire_01
  ep2_revolver_dry_01
  ep2_revolver_reload_open_01
  ep2_revolver_reload_close_01
  ep2_bear_hit_01
  ep2_bear_board_cart_01

# State
Audio generation is NOT session state.
ep2_session_root only stores: leg index, armed flag, health, last chamber.
A missing WAV is a content hole, not a run-state bug.
Do not block a gameplay commit on a Varco 429.

# Script (optional, keep HTTP here, not an SDK)
  scripts/varco-text2sound.mjs
  reads VARCO_API_KEY, writes takes/, never logs the key.

# How it is wired in this repo (added 2026-09-26)
  node scripts/varco-text2sound.mjs --section runner [--only id,id] [--dry-run]
  node scripts/varco-text2sound.mjs --promote ep2_runner_duck_01=v1_s2
  src/episode2/runner/runner_audio.gd plays whatever is promoted:
    beds loop (Music: score drone; SFX: mine bed, cart rails), one-shots fire off
    sim state/signals. Missing WAV = silent slot, never an error.
    Gun-layer stems (revolver.json) are generated + promoted but NOT wired yet: runner_view.gd
    still plays the ElevenLabs placeholders. Swapping them is a gun-code change — founder's call.
  scripts/varco-sound.mjs is the OLDER helper with a guessed endpoint — do not use it.

# Banned
  Printing the key.
  Installing Unity/Unreal Varco plugins into this Godot repo.
  Replacing Meshy heroes with Varco 3D.
  Using Varco Translation/SyncFace this sprint.
  Touching Episode 1 buses or Protocol Portal scenes.
