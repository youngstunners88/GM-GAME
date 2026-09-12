# Episode 2 Audio — VARCO Sound setup

Source brief: `artifacts/PROMPT_EPISODE2_VARCO_SOUND_INTEGRATION.md` (founder).
Runtime stays **Godot 4.3**; every stem lands as an `AudioStream` on a Godot bus.

---

## Status, measured 2026-09-12 — one blocker, and it is not the network

| Check | Result |
|---|---|
| `api.varco.ai` reachable from this sandbox | **YES** — HTTP 307 on `/`. No network-policy change needed, nothing to allowlist. |
| `VARCO_API_KEY` in the session environment | **absent** |
| `OPENAPI_KEY` (the name the brief uses) | **absent** |
| `VARCO_KEY` | **absent** |
| `ELEVENLABS_API` / `ELEVENLABS_API_KEY` (Bull VO) | **PRESENT** — VO is unblocked and already done |

*(Checked by NAME only. This project never prints, logs or commits a key value —
see the `env-secrets-and-apis` skill for why that rule exists.)*

**So: generation is blocked on exactly one thing — a VARCO credential.**
Everything that does not require it is built and committed: the bus layout, the
folder tree, the prompt library, the credit log, and `scripts/varco-sound.mjs`,
which runs the moment a key exists.

## How the founder unblocks it

1. Sign up at <https://api.varco.ai> → create a workspace → issue an API key.
   New accounts receive starter credits; paid packs exist beyond that.
2. Put the key in the **environment's Environment Variables field** at
   claude.ai/code, named `VARCO_API_KEY` (the helper also accepts `OPENAPI_KEY`,
   the name the brief uses, so either works).
3. **Never inline it in a script, a committed file, or a log line.** This repo
   already lost a session to keys pasted into a setup script.

That is the whole unblock. Nothing else is waiting.

## Once the key is in

```bash
node scripts/varco-sound.mjs --list                       # what would be generated
node scripts/varco-sound.mjs --section runner --dry-run   # cost estimate, spends nothing
node scripts/varco-sound.mjs --section runner             # generate + log
```

Priority order is the brief's, and it is deliberate — highest reuse first:
**runner → smelting → winchester → fortknox → global.**

## Where things land

```
artifacts/episode2-gold-mine/audio/
  SETUP.md            this file
  CREDIT_LOG.md       every generation: prompt, credits, timestamp, path
  prompts/            versioned prompt library, one JSON per section
  stems/<section>/    generated WAVs
  vo/inferno_bull/    ElevenLabs VO (NOT VARCO — see below)
```

Naming, per the brief: `ep2_<section>_<layer>_<variant>.wav`, e.g.
`ep2_runner_cart_rails_loop_01.wav`, `ep2_smelt_furnace_roar_loop_01.wav`.

## Godot bus layout

`src/autoload/audio_manager.gd` creates the Episode 2 buses at boot, idempotently:

```
Master
├── Ambience     bed / room tone / furnace / rock stress
├── Mechanical   cart on rails, zip cable, footsteps, machinery
├── Threat       bear presence, arrow whistle, boulder rumble
├── Action       gunshots, impacts, landings
├── Score        low chant / hymn / Western drone
├── VO           Inferno Bull + Lil Blunt  (ElevenLabs)
├── Music        pre-existing Episode 1 bus, untouched
├── SFX          pre-existing Episode 1 bus, untouched
└── UI           interaction ticks
```

`Music` and `SFX` are left exactly as they were — Episode 1 routes through them
and this must not disturb a shipped episode.

## Inferno Bull VO is ElevenLabs, not VARCO — and it is DONE

Per the brief §6 and the character profile §5. Five lines are generated,
measured and committed under `src/assets/sounds/voice/`, played by the
Smelting Facility chamber at the right beats:

| Line id | Duration | Beat |
|---|---|---|
| `vo_bull_made_it` | 3.58s | the drink |
| `vo_bull_take_rifle` | 5.80s | the Winchester hand-off |
| `vo_bull_no_sidekicks` | 3.99s | the terms |
| `vo_bull_smoke_lounge` | 5.02s | the promise |
| `vo_bull_still_standing` | 7.76s | walking out |

Voice `uWE48TmsTuIjyh2ifoNL` — an **original voice designed and owned by this
project** via ElevenLabs Voice Design, ~78-89 Hz median pitch, `speed: 0.80`.
Do not route Bull dialogue through VARCO.
