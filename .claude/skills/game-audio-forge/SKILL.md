---
name: game-audio-forge
description: Expert gameplay SFX + voiceover generation for Lil Blunt Adventure via the ElevenLabs API (key in env as ELEVENLABS_API_KEY). Use whenever a new sound-triggering action ships, a play_sfx() call references a missing file, VO is needed for a new stage/boss, or audio needs a quality pass. Sounds are defined data-driven in assets/audio-manifest.json.
---

# Game Audio Forge

Generates every gameplay sound and voiceover for Lil Blunt Adventure from
text prompts via ElevenLabs, with prompts engineered for a **retro 16-bit
platformer that stays chill** — the game's identity is "small, cute, chill,
friendly" (CLAUDE.md), and the audio has to carry that as much as the art.

## When to activate

- A new `play_sfx("name")` / `play_sfx_at("name", …)` call is added whose
  file doesn't exist in `src/assets/sounds/` — generate it in the same
  session, don't ship silent actions.
- A new stage, boss, or narrative moment ships that deserves a VO line.
- The user asks for sound/audio/voice work in any form.
- An audio quality pass is requested (regenerate weak sounds with tuned prompts).

## The pipeline (one command)

```bash
python3 scripts/generate_audio.py            # generates everything missing
python3 scripts/generate_audio.py --force jump coin   # regenerate specific ids
python3 scripts/generate_audio.py --dry-run  # list what would be generated
```

Reads `assets/audio-manifest.json` (the data-driven source of truth — per
src/CLAUDE.md, gameplay values live in config, not code), calls ElevenLabs,
writes MP3s into `src/assets/sounds/` (SFX) and `src/assets/sounds/voice/`
(VO). Godot 4.3 plays MP3 natively; `AudioManager.play_sfx` resolves
`.ogg` first then `.mp3`, so legacy ogg tracks and generated mp3s coexist.

## Prompt-engineering rules for game SFX (the "expert" part)

These come from what actually produces usable game sounds vs. mush:

1. **Name the era and medium first**: "Retro 16-bit videogame …" anchors the
   generator away from cinematic/realistic foley, which reads wrong at
   pixel-art scale.
2. **One event per sound.** "Coin pickup chime" — never "coins jingling as
   the player collects them while running" — narrative prompts produce
   ambience, not an SFX hit.
3. **Describe the envelope, not just the source**: "short, punchy attack,
   fast decay, no reverb tail" matters more than the object name. UI/game
   feedback needs < 1s decay or it smears under rapid retriggering
   (0.4s coin cooldown, 0.45s axe cooldown).
4. **Give a musical direction for pitch-critical sounds**: "single rising
   note" (jump), "two-note descending" (damage), "bright major arpeggio"
   (powerup) — this is what separates a *readable* sound from a *plausible* one.
5. **State the mood explicitly** — this game: "chill", "soft", "friendly",
   "bouncy". Never "aggressive", "harsh", "distorted" (Global Rules: Lil
   Blunt is NOT aggressive; damage sounds are "ouch", not violence).
6. **Duration discipline**: movement/pickup 0.5–0.8s, impacts 0.6–1.0s,
   powerups/fanfares 1.2–2.0s. Set `duration_seconds` explicitly; don't let
   the model pick.
7. **prompt_influence ~0.4** for SFX (creative but on-brief); **~0.7** when
   regenerating because a sound came out off-spec (obey the text harder).

## Voiceover rules

- One announcer voice for the whole game (consistency = production value).
  The manifest pins the voice ID; it was chosen as a warm, laid-back,
  slightly gravelly narrator — "chill Western storyteller", matching the
  GoldMine Wild-West and smoke-lounge vibes without stoner cliché.
- Lines are SHORT (3–10 words). Players skip long VO; short drops loop well.
- Model: `eleven_multilingual_v2`, default stability/similarity. Ellipses
  ("Level One… The Smoke Realm.") create natural dramatic pauses.
- Content rules apply to VO too: chill, positive, never aggressive-drug-y.
- Wiring: `AudioManager.play_voice("stage1_intro")` — ducks music by −8dB
  while the line plays, restores after. Stage intros fire in each level's
  `_ready()`, boss intros in the boss trigger, victory lines on LEVEL_COMPLETE.

## API reference (as used here)

- SFX: `POST https://api.elevenlabs.io/v1/sound-generation`
  `{"text": prompt, "duration_seconds": s, "prompt_influence": p}` → MP3 bytes.
- VO: `POST https://api.elevenlabs.io/v1/text-to-speech/{voice_id}`
  `{"text": line, "model_id": "eleven_multilingual_v2"}` → MP3 bytes.
- Auth: header `xi-api-key: $ELEVENLABS_API_KEY` — **env only, never
  hardcode, never commit** (security-sentinel SEC-001 will block it anyway).
- The key in this environment is generation-scoped (no `user_read`) — a 401
  `missing_permissions` on /v1/user is EXPECTED and not a broken key.

## Adding a sound

1. Add an entry to `assets/audio-manifest.json` (id, type, prompt/text,
   duration). Follow the prompt rules above.
2. Run `python3 scripts/generate_audio.py`.
3. Reference it: `AudioManager.play_sfx("your_id")` or `play_voice("your_id")`.
4. Listen-check in the browser build (`/browser-verify-game`) — generated
   audio is nondeterministic; regenerate with `--force` + a tuned prompt if
   a sound reads wrong. Do NOT ship without hearing it once.

## Files

- `assets/audio-manifest.json` — every sound/VO definition (data-driven)
- `scripts/generate_audio.py` — generator (stdlib only, no deps)
- `src/assets/sounds/` — SFX output; `src/assets/sounds/voice/` — VO output
- `src/autoload/audio_manager.gd` — playback (`play_sfx`, `play_sfx_at`,
  `play_voice`, music shuffle + ducking)
