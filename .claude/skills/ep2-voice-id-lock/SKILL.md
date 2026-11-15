---
name: ep2-voice-id-lock
description: Wire a founder-specified ElevenLabs voice ID into Episode 2's town voice bank so the character speaks the recorded clips in game - ID in assets/town-audio.json, clips generated offline, Ep2TownVoiceBank updated, the speaking code plays them. First use - auctioneer/Renegade is X0KF3ROqwE8cLCsWuhs6. TRIGGER on "voice ID", "must be ... voice", "ElevenLabs", "re-record", "new line needs a clip", "auctioneer voice".
argument-hint: "audit <speaker> | wire <speaker> <voice_id> | regen <speaker>"
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
---

# Lock a voice and prove you can hear it

Founder 2026-11-15: "The auctioneer's voice must be X0KF3ROqwE8cLCsWuhs6 voice ID."
Today: `chamber/ep2_auction_house.gd` (`RENEGADE`, `CALLS`, `_say()` ~L38-52, ~L482+) shows text and plays generic clips; no ElevenLabs ID is wired for Renegade.

## The pipeline (already exists)
- `assets/town-audio.json`: `voices.<speaker>.voice_id`, `name`, `source`, model `eleven_v4` (see the file's own `model_id`).
- `scripts/generate-town-audio.mjs`: `--plan` shows what would be generated; `--generate [--speakers a,b] [--sfx]` records. Writes `assets/town-audio-generated.json` (receipt) and the generated `class_name Ep2TownVoiceBank`.
- Game ships **recorded Ogg**; the key never ships. Key lives in the build environment `.env` (`env-secrets-and-apis`). Never print, log, or commit it.
- Utah, Sheriff and others already play recorded takes via the bank; `_say()` in the auction hall must do the same.

## Steps
1. `--plan` first. Add `renegade` (or the existing key for the auctioneer) with `voice_id: "X0KF3ROqwE8cLCsWuhs6"`. Confirm by reading the id back from the JSON: character-exact.
2. The auctioneer's lines are `CALLS`, `DOOR_LINE` is the doorman's (different speaker, keep his voice), `PRESSURE_LINE`, any `RENEGADE:` lines in `JACK_LINES`/`AFTER_LINES`. Each `RENEGADE:` line gets a clip; other speakers' lines stay with their voices. Prefix parsing in `_say()` decides who speaks: use it.
3. `--generate --speakers renegade`. Check the receipt shows the id used and every line has a file. Cost check first (credits are money): count characters x rate, show the number.
4. In `_say()`: map speaker prefix to bank key and play the clip with `AudioManager.play_voice` semantics (`ep2-voice-duck`); the text subtitle stays. A missing clip must fall back to text + a visible log in dev, not silence in production.
5. Ogg goes to the streamed extras path, not the main pack: run `scripts/pack-gate-fresh.sh`; memory says the extras pck can be tight on this branch (auction house 4.7 KB under gate). Trim first if needed.
6. **Listen.** Generated audio is nondeterministic. Play at least one line in the built game; transcribe or compare to confirm it is the new voice, not the old one.

## Proof
- JSON id equals `X0KF3ROqwE8cLCsWuhs6`; receipt lists the clips; the game's `_say` loads each clip (a test asserts non-null stream per `RENEGADE:` line).
- A real-renderer recording of the auction hall with audio, or at minimum a measured clip duration and a played-through log.
- State plainly if you could not listen.
