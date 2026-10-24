---
name: ep2-town-voices
description: Finish or maintain the offline ElevenLabs town cast, Rich identity, prisoner speech, ambience and bell-only duel signal.
---
Read `assets/town-audio.json`, `assets/town-audio-generated.json` and the latest town-voice handoff first. Preserve all verified recordings and Rich's Episode 1 identity `LNV6ahDtkAOqwn1X3R7a`. The high Western tenor belongs to the prisoner behind bars. Utah and the sheriff each require their own original design. No voice deletion is authorized.

Discover credential binding names without printing values. Default to `ELEVENLABS_API_KEY`; another binding requires explicit `ELEVENLABS_KEY_BINDING`. Verify the intended account and capacity using real provider responses; do not fall back to a legacy account. Missing `user_read` prevents account verification. Credit balance and custom-voice slots are separate.

Production: `scripts/generate-town-audio.mjs --plan`, then `--generate --speakers <only pending roles>`. Source hashes and processing receipts must match. Keep audio in the streamed extras; never put a credential or a runtime ElevenLabs dependency in the game. Preserve raw takes when available.

Speech must finish before progression. `Ep2TownVoiceBank.seconds()` uses engine stream length plus a 0.25-second gap. Godot 4.3 OggPacketSequence uses final granule/sample rate, while ffprobe subtracts a positive start timestamp. Receipts preserve both `seconds` and `start_seconds`; their sum must match the engine to sample precision. Inspect start PTS, hashes and final granules; do not relax tolerance for alleged padding.

The town bell alone opens the draw window, once per round/retry. Sheriff speech tells both men to listen. Missing bell must keep firing locked. Suppress ambient greetings for story/duel, preserve music ducking and a single story voice lane. Keep the bell out of ambience.

Required checks: pinned 4.3 import/compile; `ep2_town_audio_test`, `ep2_gold_town_test`, `ep2_armory_guns_test`; receipt/hash/decoded peak checks; actual audible output; full normal release gates and exact public BUILD. The audio gate must block while any of 67 recordings is missing. Never publish an incomplete cast. Use `smokerealm-ship` after all checks; preserve concurrent master, gameplay, title and access locks.
