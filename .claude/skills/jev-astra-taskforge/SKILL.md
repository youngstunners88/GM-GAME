---
name: jev-astra-taskforge
description: Turn a founder request into a verified, executable task spec using GPT-6 Astra on OpenRouter as the planning head, and Jev (TypeSafe's decisions model, also on OpenRouter) as the numeric ship/block gate. Use when a request needs a structured task built before any code is written, or when a task's verification step requires actually driving a real browser (checking the live itch.io build, a store page, a dashboard) rather than reading files.
user-invocable: true
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
---

# Jev × Astra Taskforge

Two heads, one task spec. **Astra plans. Jev clicks. Claude owns the repo.**

Neither model may land a change unreviewed. They produce a *spec* and an
*observation*; every commit, gate and STATUS.md line stays Claude's.

---

## ✅ Jev IS on OpenRouter — on the DECISIONS endpoint, not chat

**Correction (2026-09-23).** An earlier version of this skill said Jev was not
on OpenRouter, because `GET /v1/models` never lists it and
`/v1/chat/completions` rejects every Jev ID. Both observations were true and the
conclusion was wrong: Jev is a *decisions* model, served at a different endpoint
that `/v1/models` does not catalogue. The founder said it was on OpenRouter and
that he had used it; he was right. Verified live:

```bash
curl -s -X POST https://openrouter.ai/api/alpha/decisions \
  -H "Authorization: Bearer $OPENROUTER_API_KEY" -H "Content-Type: application/json" \
  -d '{"model":"~typesafe/jev-latest",
       "state":"<the facts / numbers to judge>",
       "questions":{"ready":{"type":"noul","instructions":"Is this ready to ship?"}}}'
# -> {"model":"typesafe/jev-1.13-20260917","answers":{"ready":{"type":"noul","noul":0.51}},
#     "usage":{...,"cost":0.000012096},"provider":"TypeSafe"}   (HTTP 200)
```

| | |
|---|---|
| Model | `~typesafe/jev-latest` (pins to `typesafe/jev-1.13`) |
| Endpoint | `POST https://openrouter.ai/api/alpha/decisions` — **not** `/v1/chat/completions` |
| Question types | `noul` (0-1 likelihood), `choice` (+ `criteria`), `score` — every question needs `instructions` |
| Cost | ~$0.00001-0.00002 per call |
| Key | `OPENROUTER_API_KEY` |

**Rules learned the hard way (see CLAUDE.md → MODEL ROLE SPLIT):**
- The model catalogue is **not proof of absence**. Only a real call to the right
  endpoint is. A `400` from `/api/alpha/decisions` is a schema error that names
  the missing field — never "model does not exist".
- **Jev is text-only.** It does not see images; a screenshot's number tracks the
  base64 string length, not the picture. Feed it numeric metrics (e.g. from
  `scripts/seam-smudge-gate.py`), never a screenshot, or the verdict is fake.
- For the full ship/block workflow use the **`jev-decision-gate`** skill.

Separately, `browser-use/jev-ultrafast` is a *browser agent* built on TypeSafe's
policy; it is a different product and not what this skill routes to.

### The planning head

| Head | Endpoint | Verified |
|---|---|---|
| **GPT-6 Astra** | OpenRouter, `openai/gpt-6-astra` | ✅ live-tested 2026-09-22 — replied, `finish_reason: stop`, $0.00056 |

Live facts: $10/1M in, $50/1M out, 1,050,000-token context. Cheaper and
stronger siblings exist: `openai/gpt-6-astra:batch` (half price),
`openai/gpt-6-astra-pro`, `openai/gpt-6-astra-pro:batch`.

## When to use this skill

**Use it when:**
- a founder request is big or vague enough that implementing straight from
  chat would mean guessing at scope (a new mode, a systems change, a
  multi-file feature)
- the verification step is *"does it actually work in the live build"* —
  that needs a browser, which is Jev's job, not a chat model's
- you want a second opinion on sequencing before spending a long session

**Do not use it for:** copy edits, config tweaks, single-file changes, or
anything where writing the brief costs more than doing the work. Astra is
$50/1M out — a brief that could have been a two-line thought is waste.

---

## Division of labour

```
founder request
      │
      ▼
 ┌─────────────────────────────────────────┐
 │ ASTRA  (openai/gpt-6-astra, OpenRouter) │  plans
 │  scope · sequence · risks · gates       │
 └───────────────────┬─────────────────────┘
                     │  task spec (markdown)
                     ▼
 ┌─────────────────────────────────────────┐
 │ CLAUDE                                  │  owns
 │  verifies spec against the REAL repo,   │
 │  implements, runs gates, commits        │
 └───────────────────┬─────────────────────┘
                     │  "is it true in a browser?"
                     ▼
 ┌─────────────────────────────────────────┐
 │ JEV  (TypeSafe policy, jev-ultrafast)   │  observes
 │  drives the live page, reports what it  │
 │  actually saw                           │
 └─────────────────────────────────────────┘
```

**Astra never sees the repo.** Like Grok and Kimi in
`multi-model-orchestrator`, it has zero project context. Anything it must
reason about has to be inlined — see `@include` below.

**Jev never decides whether something is correct.** It reports observations.
Claude decides. A `DONE` from Jev means "the goal's stop condition was
observed", not "the feature is good."

---

## Step 1 — Astra: build the task spec

Reuse `scripts/or-call.mjs`. Do **not** hand-roll curl against OpenRouter:
that wrapper exists because the naive version was actively harmful, and every
reason still applies here.

```bash
node scripts/or-call.mjs openai/gpt-6-astra prompts/astra-<topic>.md \
  prompts/out/astra-<topic>.md --dry-run     # ALWAYS dry-run first
node scripts/or-call.mjs openai/gpt-6-astra prompts/astra-<topic>.md \
  prompts/out/astra-<topic>.md
```

What the wrapper gives you that matters here:

1. **`@include <path>` inlines real files.** Astra cannot open this repo. A
   brief saying "review `src/ui/main_menu.gd`" reaches a model that will
   either say FILE NOT FOUND (paid, useless) or **invent the contents**
   (paid, worse than useless).
2. **Missing `@include` paths abort before spending** (exit 2). A stale path
   is a bug to fix, not a question to pay for.
3. **Live pricing and `--dry-run`.** Report the estimate before spending.
4. **`OR_MAX_TOKENS` defaults to 24000 and that is not always enough.**
   Reasoning burn happens before a single visible character. The wrapper
   detects `finish_reason: length` with empty content and refuses to write a
   fake spec rather than saving an empty one.

### Known environment trap: the proxy + gzip bug

This container routes egress through an agent proxy. `scripts/or-call.mjs`
handles that by installing an `undici` `ProxyAgent` — and **with `undici`
present the model-list fetch currently fails** with
`Unexpected token '', "\x1f\x8b..." is not valid JSON`: a gzipped body being
parsed as text. Without `undici` it warns and may 403.

Until that is fixed, verify reachability with a direct call, which works:

```bash
curl -s https://openrouter.ai/api/v1/chat/completions \
  -H "Authorization: Bearer $OPENROUTER_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"openai/gpt-6-astra","max_tokens":2000,
       "messages":[{"role":"user","content":"Reply with exactly: ASTRA_ONLINE"}]}'
```

Verified 2026-09-22: returns `ASTRA_ONLINE`, `finish_reason: stop`, cost
$0.00056. **Do not report Astra as unreachable without running that curl** —
a wrapper bug is not an outage, and that distinction is exactly the kind of
misdiagnosis this repo's manifests exist to stop.

### The brief that produces a usable spec

Astra has no project context. Include all of:

- **What the game is** — one paragraph, every time
- **What exists right now**, honestly, flaws included
- **Engine facts it must not "correct"** — Godot 4.3 specifics, this
  project's collision layers, which base class owns which member
- **The actual question**, specific and answerable
- **Hard constraints** — non-threaded web export, no new frameworks, no
  weed-themed enemies, no hardcoded wallet/contract addresses
- **The exact output format** you want back

Ask for the spec in this shape, because it is what `/create-stories` and
`dev-story` can consume without a rewrite:

```markdown
## Goal            — one sentence, player-visible
## Out of scope    — explicit, the anti-creep line
## Steps           — ordered, each independently verifiable
## Files           — likely touched, with why
## Risks           — what silently breaks, and the early warning sign
## Gates           — the commands that prove it, incl. one that FAILS today
## Browser check   — what a human/Jev must SEE for this to be true
```

That last section is what Step 2 consumes.

---

## Step 2 — Jev: verify it in a real browser

Jev answers the only question headless gates structurally cannot: *can a
person actually see this happen.* This repo has already shipped a feature
that was logically perfect, fully gated, and completely unreachable — see
the Episode 2 write-up in `STATUS.md`. That is the failure class Jev covers.

### Prerequisites (only for the TypeSafe path — skip if discovery found a model ID)

```bash
git clone https://github.com/browser-use/jev-ultrafast.git
cd jev-ultrafast && uv sync
```

`.env` needs:

```
TYPESAFE_API_KEY=<this container exposes it as TYPESAFE_API — copy it across>
TEXT_MODEL_API_KEY=<your OPENROUTER_API_KEY>
```

> **Name mismatch, on purpose:** upstream reads `TYPESAFE_API_KEY`; this
> container sets **`TYPESAFE_API`**. Copy the value across explicitly. A
> session that greps for `TYPESAFE_API_KEY`, finds nothing, and reports "no
> TypeSafe key available" is wrong — the key is there under the other name.
> Never print either value.

Chrome connects through [Browser Harness](https://github.com/browser-use/browser-harness)
(installed by `uv sync`). Chromium is already present in this container at
`/opt/pw-browsers/chromium`; `PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1` is set, so
**do not run `playwright install`**. If the harness cannot attach, run
`uv run browser-harness --doctor`.

### Driving it

```python
from jev_ultrafast import Agent

with Agent(
    "https://youngstunners88.itch.io/lil-blunt-adventure",
    "Start the game and stop once the title screen is fully visible.",
) as agent:
    for state in agent.run():
        print(state["elapsed_ms"], state["status"])
```

```bash
uv run --env-file .env python your_script.py
```

### Rules that keep Jev honest

- **One goal, one stop condition.** "Check the menu looks good" is not a
  goal Jev can terminate on. "Stop when the PLAY LEVEL 1 button is visible"
  is.
- **`BLOCKED` is information, not failure.** It means the policy found no
  legal operation — usually a real UI problem worth reporting to the founder.
- **`DONE` is not a pass.** It means the stop condition was observed. Whether
  what was observed is *correct* is Claude's call, from the screenshot.
- **Never let Jev perform a destructive or outward-facing action** — no
  publishing, no purchases, no form submissions with real founder data, no
  account changes. Observation and navigation only. Anything that writes to
  the outside world goes back to the founder for an explicit yes.
- **Prefer the existing tool when it already fits.** For the standard
  boot-and-play check this repo already has `browser-verify-game` and
  `scripts/verify-game.mjs` (Playwright, deterministic, free). Reach for Jev
  when the check is exploratory, or when the page is one no fixture covers.

---

## Step 3 — Claude closes the loop

1. **Verify the spec against the real repo.** Astra cannot see it; assume at
   least one cited path is wrong. When this repo's kit was installed, *five
   of six* cited paths were stale.
2. Implement. Run the gates the spec names, plus
   `bash scripts/security-sentinel.sh` **after `git add`** — it scans
   `git ls-files`, so running it on unstaged new files scans nothing.
3. Record the browser observation with its screenshot. "Jev said DONE" is
   not evidence; the screenshot is.
4. Update `STATUS.md`, commit, push — the ALWAYS-SHIP rule.

---

## Cost discipline

Astra is $10/1M in, $50/1M out — **roughly 3× Kimi K3 on output.** Before
every call:

- `--dry-run` and report the worst-case number
- consider `openai/gpt-6-astra:batch` (half price) when latency is fine
- consider whether `x-ai/grok-4.5` (~$2/$6) via `multi-model-orchestrator`
  would answer the same question for a twentieth of the cost

Reach for Astra specifically when the task needs its 1.05M context (inlining
many large files at once) or genuinely hard multi-system sequencing. For a
single-system design question, Grok is the better buy.

---

## Relationship to the other orchestration skills

| Skill | Models | Use when |
|---|---|---|
| `multi-model-orchestrator` | Grok 4.5, Kimi K3 | Routine: design brief before, code audit after |
| **`jev-astra-taskforge`** | **GPT-6 Astra, Jev** | **Task needs a structured spec first, or browser-truth verification** |
| `browser-verify-game` | — (Playwright) | The standard boot + gameplay check. Free, deterministic. Try first. |

These compose. A good large-feature session: Astra writes the spec → Grok
pressure-tests the feel → Claude implements → Kimi audits the diff → Jev or
`browser-verify-game` confirms it in a browser.
