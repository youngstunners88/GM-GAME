---
name: jev-decision-gate
description: Get a ship/block verdict from the Jev decisions model on NUMBERS, not vibes. Use before writing FIXED for any defect the founder has rejected before, before a release gate, and any time a judgement call would otherwise rest on eyeballing a screenshot.
---

# Jev Decision Gate

Jev (TypeSafe) is a **decisions** model: you hand it a state and typed questions,
it returns calibrated probabilities and a choice. It exists to stop a judgement
call resting on "it looks fine to me" — which is precisely how this project
shipped "FIXED" four times on a defect the founder could still plainly see.

## The one rule that matters

**Jev cannot see images.** Control-tested 2026-09-20 on this account: an image
*with* a black bar scored `0.22`, an identical image *without* one scored
`0.19`, and the input token count tracked the base64 **string length**, not the
picture. Handing Jev a screenshot and quoting the number back is fake
verification dressed up as rigour.

> Numbers to Jev. Pictures to DeepSeek V4.1 Flash (vision verified working the
> same day). Final call to Claude.

## Call it

```bash
# Normal path: judge a run of the deterministic image gate
python3 scripts/seam-smudge-gate.py --json /path/to/frames/ > gate.json
node scripts/jev.mjs --from-gate gate.json
#   exit 0 = SHIP, 1 = BLOCK, 2 = UNCERTAIN, 3 = error

# Generic path
node scripts/jev.mjs --state "<facts, as text>" \
  --bool "is_regression=Do these numbers indicate a regression?" \
  --choice "verdict=ship:all clear|block:any defect remains"
```

Uses the existing `OPENROUTER_API_KEY`. No new credential.

## Verdict bands (borrowed from better-call-jev)

A probability is not a decision until you state what each band means:

| probability | meaning |
|---|---|
| `>= JEV_THRESHOLD_HIGH` (default **0.8**) | yes |
| `<= JEV_THRESHOLD_LOW` (default **0.2**) | no |
| between | **UNCERTAIN — surface it, never round it to ship** |

The middle band is the whole point. Silently rounding 0.55 to "ship" is the
failure mode this gate exists to prevent.

## Question contract

Portable across both transports. Every question needs `instructions`.

```js
{ type: 'boolean', instructions, criteria?: { true, false } }  // -> probability
{ type: 'choice',  instructions, criteria: { name: description } }
{ type: 'score',   instructions, criteria: [ 'lowest', ..., 'highest' ] }
```

## Why we did NOT vendor jukkatupamaki/better-call-jev

The upstream plugin is good work and `scripts/jev.mjs` borrows its threshold
model directly. It is not installed because its only implemented transport is
the **Vercel AI Gateway** (`https://ai-gateway.vercel.sh/v1/evaluate`) behind a
**new `JEV_API_KEY` from a Vercel account** — a second credential and a second
bill for a model this project already reaches on the OpenRouter key it has.

Schema mapping, verified live, so code reads the same either way:

| upstream (Vercel) | OpenRouter `/api/alpha/decisions` |
|---|---|
| `type: 'boolean'` → `probability` | `type: 'noul'` → `noul` |
| `type: 'choice'` + `criteria` | identical |
| `type: 'score'` + `criteria[]` | identical |

`scripts/jev.mjs` sends `boolean` as `noul` and normalises `noul` back to
`probability`, so callers only ever see the portable shape.

**Revisit this decision if** we want zero-data-retention (`retain: false` →
`providerOptions.gateway.zeroDataRetention`, which upstream supports and the
OpenRouter path does not), or if OpenRouter drops the alpha endpoint. Adding a
provider entry is a small change — keep the question contract identical so
nothing above the transport moves.

## Endpoint gotcha that already cost a session

Jev is **not** in `GET /v1/models`, because decisions models are not chat
models. A catalog grep therefore "proves" it does not exist — and that wrong
conclusion got committed to CLAUDE.md and cost the founder real time.

- Correct endpoint: `POST https://openrouter.ai/api/alpha/decisions`
- `/v1/chat/completions` will 400. That is **not** "model does not exist".
- A 400 from the decisions endpoint is a **schema error** and it names the
  missing field. Read it and fix the body.

**The catalog is not proof of absence. Only a real HTTP call is.**

## When to use it

- Before writing FIXED for anything the founder has rejected before.
- Before a release gate, alongside `gate-battery-runner`.
- Any time the honest answer is "I think it looks OK" — convert to numbers and
  let Jev rule instead.

## When NOT to use it

- As a substitute for live-build proof. Jev ruling SHIP on clean numbers is not
  evidence the live build is clean; capture the live frames first.
- On screenshots (see the rule at the top).
- For open-ended design questions. It decides; it does not ideate.

## Standing rules (founder, 2026-09-25)
- Route stays OpenRouter: `POST https://openrouter.ai/api/alpha/decisions`, model
  `~typesafe/jev-latest` (or pin `typesafe/jev-1.13`). Never `/chat/completions`, never
  generation work, never a direct TypeSafe endpoint.
- A `noul` score is a signal, not authorization.
- HTTP 401 / 422 / 429 / 529 / timeout = stop. No auto-continue.
- At most 2 continues on a gate, then ping the founder.
- A founder "ship anyway" is not a recorded Jev ship.
