# Verification — 02_runner_opening scene kit

Author: **DeepSeek** (`deepseek/deepseek-v4-flash-vision-exp`) via OpenRouter,
from the three founder runner references plus the shipped
`src/episode2/runner/runner_graybox.gd` and `ep2_palette.gd`
(brief: `prompts/deepseek-ep2-scene-02-runner.md`).
Cost: **$0.0184** — 15,527 in / 22,652 out.

Verified by Claude on 2026-09-12 against the real code.

## Claims CHECKED AND TRUE

| Claim | Code |
|---|---|
| 20 m wall segments, every 4th opening into a wide bay | `const SEG := 20.0`; `pocket = (i % 4) == 2` |
| Bays are 16.8 m wide vs 11.2 m normal | `half_w = 8.4 if pocket else 5.6+` → ×2 |
| Track is ~240 m | `track_len = _chamber_z + 60.0`, `chamber_z = 180` |
| Cart runs 12 m/s | `RUN_SPEED := 12.0` |
| Three rails at 2.5 m spacing, descending order | `LANE_X := [2.5, 0.0, -2.5]` |
| Zip height 2.5 m, above jump-clear | `ZIP_HEIGHT := 2.5` |
| Sleepers every 3 m | `tie_z += 3.0` |

## One error, and it is MINE not DeepSeek's

The kit says the tunnel is "12 m wide". It is **11.2 m** at normal segments
(`half_w = 5.6` per side). DeepSeek took 12 m from my brief, which stated it
wrongly. Corrected here rather than in the kit, so the kit stays a faithful
record of what was actually returned.

## The findings worth acting on

DeepSeek was given the Astra fidelity review's five ranked findings as evidence
and built the aesthetic lock around them, which is what the brief asked for. Its
own additions on top are the useful part:

- **Hanging baskets and distant walkways are in the references and absent from
  the build** (REVIEW Q1). This is the concrete answer to Astra's finding #4,
  "a rectangular shaft, not a cavern" — the references get their layered depth
  from objects *beyond* the tunnel wall, not from the wall shape. The current
  bays widen the box; they do not add a second depth plane. This is the single
  highest-value note in the kit.
- **The green chamber gate is an invented marker** (REVIEW Q5). True, and worth
  saying out loud: no reference shows a gate. It was added so the goal is
  visible from the track. A founder call.

## What was NOT verified

Palette hex values attributed to the references are DeepSeek's reading of the
art, not sampled measurements — same status as the Astra extraction before it
was tuned against real captures. The audio hook mapping is a proposal; no VARCO
stems exist yet (no API key — see `../../audio/SETUP.md`).

No code was changed off the back of this kit. Unlike scene 01, which contained
a verifiable camera bug, nothing here is wrong today — the notes are direction
for the next visual pass.
