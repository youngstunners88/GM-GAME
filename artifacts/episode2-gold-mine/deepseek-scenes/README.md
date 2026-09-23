# Episode 2 — DeepSeek scene foundation kits

Brief: `artifacts/PROMPT_EPISODE2_DEEPSEEK_3D_SCENES.md` (founder).

DeepSeek authors the **foundation** — scene spec, aesthetic lock, Godot blockout
notes — so a later high-fidelity pass has law to follow instead of taste.

## How these are produced (differs from the brief, deliberately)

The brief assumed a separate Claude Code profile talking to DeepSeek through a
Hugging Face router (`CLAUDE_CONFIG_DIR=/home/workdir/claude-deepseek`,
`launch.sh`, `.grok/skills/gm-game-episode2-deepseek-3d/SKILL.md`). **None of
that exists in this repo or this sandbox, and none of it is needed** — the
project already has an OpenRouter key and a hardened dispatch wrapper, so
DeepSeek is one command away:

```bash
OR_MAX_TOKENS=40000 node scripts/or-call.mjs deepseek/deepseek-v4-flash-vision-exp \
  prompts/deepseek-ep2-scene-0N-<name>.md /tmp/out.md \
  --image artifacts/.../ref1.jpg --image artifacts/.../ref2.jpg

node scripts/split-scene-kit.mjs /tmp/out.md \
  artifacts/episode2-gold-mine/deepseek-scenes/0N_<name>
```

### Two things that cost time, so they are written down

1. **Use `deepseek/deepseek-v4-flash-vision-exp`, not `deepseek/deepseek-v4.1-flash`.**
   OpenRouter's catalogue lists `v4.1-flash` as accepting image input. In
   practice it returned **empty content with four images and hung for 10+
   minutes with one**, while the same prompt text-only answered instantly. The
   `-vision-exp` variant works correctly and read the references accurately.
   ($0.22/$0.66 per M vs $0.15/$0.60 — the difference is fractions of a cent.)
2. **Budget ~40k output tokens.** These kits are long and the model spends
   heavily on hidden reasoning first: scene 02 at `OR_MAX_TOKENS=16000` came
   back empty with `finish_reason: length`, which reads as "the model had
   nothing to say" and actually means "you did not pay for enough tokens to
   reach the answer".

## Reading these kits

Every file carries an UNVALIDATED banner, and every scene folder has a
`_VERIFICATION.md` recording what Claude actually checked against the code —
what was true, what was wrong, and what was not checked at all. **Read the
verification file first.** A scene kit is advice until someone confirms it.

The 01 pass earned its cost immediately: it found a real camera bug (the
establishing shot sat 2.5 m outside the room's geometry) that had survived a
browser capture, because a wide shot with nothing behind it reads as graybox
rather than as a camera outside the room.

## Status

| Scene | Kit | Verified | Notes |
|---|---|---|---|
| `01_smelting_facility` | ✅ | ✅ | Found + fixed the `CAM_WIDE` bug. 2 open founder questions. |
| `02_runner_opening` | ✅ | ✅ | No code changes needed. Key note: the references get depth from hanging baskets and walkways *beyond* the wall, which the build has none of. |
| `03_fort_knox_approach` | — | — | next |
| `04_fort_knox_vault` | — | — | after 03 |

Total spend on both kits: **$0.0296.**
