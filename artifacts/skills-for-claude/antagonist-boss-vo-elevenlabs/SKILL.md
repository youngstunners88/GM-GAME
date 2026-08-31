---
name: antagonist-boss-vo-elevenlabs
description: Generate, tune, and verify the THREE antagonist boss voices (tax / crystal / bandit) for Lil Blunt Adventure via ElevenLabs. Use whenever a founder reports a boss "went silent," lines "don't vary / repeat," a boss voice needs regenerating, or new taunt lines are added. Codifies the exact traps that made the bosses inaudible.
---

# Antagonist Boss VO (ElevenLabs)

The three bosses speak through **their own** playback path, separate from Lil
Blunt's barks and the announcer. When a founder says "the bosses went silent"
or "they keep saying the same thing," the cause is almost always one of the
four traps below — check them in order before touching anything else.

## The system (one map, read first)
- **Text source of truth:** `assets/boss-voices.json` — per-boss `voice_id`,
  `voice_note`, and `lines` grouped by category
  (intro / taunt / mock / hurt / phase50 / phase25 / death).
- **Generator:** `scripts/gen_boss_voices.py` → writes
  `src/assets/sounds/voice/boss/<boss>_<category>_<i>.mp3`. `--force` regenerates
  everything (required after any `voice_id` change).
- **Runtime player:** `src/boss/boss_voice_system.gd` (autoload `BossVoiceSystem`)
  — one `AudioStreamPlayer2D` on the `SFX` bus; picks a random line, avoids the
  immediate repeat, enforces a cooldown, auto-fires ambient taunts.
- **Count mirror:** `src/boss/boss_voice_data.gd` `COUNTS` — the runtime picks
  `randi() % COUNTS[boss][cat]`, so **COUNTS must exactly equal the line counts
  in boss-voices.json** or the picker either skips real lines or asks for a file
  that doesn't exist (silent).
- **Boss → id:** `auditor.gd`=`tax`, `distributor.gd`=`crystal`,
  `claim_jumper.gd`=`bandit` (each `const BOSS_ID`).

## Trap 1 — the player sits at 0 dB (this is why they "went silent")
`boss_voice_system.gd`'s `AudioStreamPlayer2D` defaults to **0 dB**, but
`AudioManager.play_bark`/`play_voice` (hero + announcer) run at **+6 dB** on the
same SFX bus. So the three bosses are a full 6 dB under everything and vanish
under gameplay noise even though they're technically "playing."
**Fix:** set `_player.volume_db = PLAYER_VOLUME_DB` with `PLAYER_VOLUME_DB >= 8`
(shipped at **+10**, i.e. 4 dB HOTTER than the hero — correct for a menacing
boss). Never let this regress to 0.

## Trap 2 — the wrong ElevenLabs workspace can't see the voices
The custom antagonist voices (IRS Auditor / Crystal Distributor / Bandit) and
the custom "Lil Blunt" voice live in the **`ELEVENLABS_API`** workspace. The
legacy **`ELEVENLABS_API_KEY`** workspace returns `voice_not_found` for them.
The generator must try `ELEVENLABS_API` **first**
(`KEY_ENV_NAMES = ("ELEVENLABS_API", "ELEVENLABS_API_KEY")`, matching
`scripts/generate_audio.py`). Read the key from env only — never print it.

## Trap 3 — truncated voice IDs
ElevenLabs voice IDs are **20 chars**. A founder-supplied id shorter than that
(e.g. `VtsQlMLXxJPBwTtP`, 16 chars) is truncated and will fail or hit the wrong
voice. **Confirm every id against the live library before generating:**
`GET https://api.elevenlabs.io/v1/voices` (xi-api-key = `ELEVENLABS_API`), match
by prefix, use the full id. Confirmed full ids:
| boss | voice_id | name |
|------|----------|------|
| tax | `jcg9W9tUWJjBuX5zV0dL` | IRS Auditor |
| crystal | `VtsQlMLXxJPBwTtPTtoc` | Crystal Distributor |
| bandit | `LEQxdWqt02nZ8lXoPL0Y` | Bandit |

## Trap 4 — same-line spam
Founders read repetition as "broken." Two halves: (1) the picker already avoids
the immediate repeat — keep that; (2) the real fix is **more lines per pool**.
Keep the three bosses at parity (bandit historically starved at 3 taunts). Bump
`boss-voices.json` **and** `COUNTS` together, then `--force` regenerate.

## Loudness
`gen_boss_voices.py` normalizes each clip (ffmpeg `loudnorm`, best-effort — ships
raw if ffmpeg absent) so no boss is quieter than another. This is polish on top
of the +10 dB gain, not a substitute for it.

## Verify — do ALL of these, never claim FIXED on a data scan alone
1. `tests/boss_voice_sync_test.tscn` — voice ids full-length, COUNTS==json,
   every clip present & loadable, gain >= +8 dB.
2. `tests/boss_voice_playback_test.tscn` (run with `--audio-driver Dummy`) —
   drives the real `BossVoiceSystem.say()` for every boss/category and asserts
   the live player is `.playing` with a stream at +10 dB, and that 20
   consecutive taunts never repeat back-to-back. This is the runtime proof
   against the four founder failure modes.
3. Fresh web export + `scripts/playtest-boss-warp.mjs` (Playwright/Chromium) —
   `?boss=N` warps into the arena; confirm booted + reachedFight + zero console
   errors on the build that carries the change (a STALE `web/game/index.pck`
   will "pass" while testing old audio — always re-export first).
4. Gates: full-project `tests/script_compile_test.tscn`, Security Sentinel 18/18.
5. STATUS.md + commit + push (CI butler deploy). Founder only hard-refreshes.

## Multi-model (mandate)
Creative line expansion is a design task — dispatch a brief through
`scripts/or-call.mjs` (Grok for creative, Kimi for audit) and fold the useful
suggestions in. Grok has repeatedly caught gore-adjacent lines that breach the
PG-mascot bar ("your blood", "diamond bones") — act on those.
