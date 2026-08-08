---
name: multi-model-orchestrator
description: Dispatch design briefs to Grok 4.5 and code audits to Kimi K3 via OpenRouter. Use on ANY substantial design decision (new mechanic, boss, level, system) or after ANY substantial code change to a gameplay system. Not optional on those turns — working solo on them is the drift this exists to stop.
user-invocable: true
allowed-tools: Read, Write, Bash, Grep, Glob
---

# Multi-Model Orchestrator

Two co-worker models, one job each. Claude remains sole owner of the repo,
STATUS.md, commits, and the gates — the other two produce **advice that must
be verified**, never changes that land unreviewed.

| Model | OpenRouter ID | Role | Rates (verify live) |
|---|---|---|---|
| **Grok 4.5** | `x-ai/grok-4.5` | Creative/design partner: mechanics, feel, readability, theming | ~$2/1M in, $6/1M out |
| **Kimi K3** | `moonshotai/kimi-k3` | Code & verification: state machines, damage paths, collision, lifetimes | ~$3/1M in, $15/1M out |

## When this is NOT optional

Dispatch **before implementing**, to Grok:
- a new mechanic, boss behaviour, level, or set piece
- a redesign where "what should this feel like" is the hard part

Dispatch **after implementing**, to Kimi:
- any boss/enemy/player state machine change
- anything touching collision layers, damage, or object lifetime
- any system where a silent failure would still compile and boot

Skip both only for: docs, copy edits, config, and mechanical refactors with
no behavioural surface.

## The tool

`scripts/or-call.mjs` — do not hand-roll `curl` against OpenRouter, this
wrapper exists because the naive version was actively harmful.

```bash
node scripts/or-call.mjs <model-id> <prompt-file> [output-file] [--dry-run]
```

Requires `OPENROUTER_API_KEY` in env.

### What the wrapper does that matters

1. **`@include <path>` inlines real files.** The co-worker models have **no
   access to this repository.** A brief saying "review `src/boss/foo.gd`"
   reaches a model that cannot open it, and it will either answer
   FILE NOT FOUND (paid, useless) or **invent the file contents** (paid,
   worse than useless). Always inline what you want reviewed.
2. **Missing `@include` paths abort before spending.** Exit 2. A brief citing
   a stale path is a bug to fix, not a question to pay for. When this kit was
   installed, **five of six** cited paths were wrong.
3. **Live pricing + `--dry-run`.** Rates are fetched from `/models` at call
   time. Always dry-run first and report the estimate.
4. **`max_tokens` defaults to 24000, and that is not always enough.**
   Reasoning models spend budget on hidden thinking before emitting a visible
   character. The kit's original 8000 returned an *empty* answer from kimi-k3
   while still billing — and **24000 also failed** on a Distributor audit that
   asked 8 multi-part questions over 6 inlined files (92,645 reasoning chars,
   zero visible output, ~$0.36 burned). The wrapper detects this
   (`finish_reason: length` + empty content), reports it, and refuses to write
   an empty file rather than saving a fake audit.

   **Brief breadth drives hidden token burn as much as file size does.** Before
   raising `OR_MAX_TOKENS`, consider splitting the brief — two narrow audits
   usually cost less than one broad one that truncates. When you do raise it,
   also add a budget-discipline preamble telling the model to answer
   question-by-question, keep each answer to a few sentences, and emit partial
   results rather than keep deliberating.

   ```bash
   OR_MAX_TOKENS=60000 node scripts/or-call.mjs moonshotai/kimi-k3 ...
   ```

## Protocol

### 1. Write the brief to `prompts/`

Naming: `grok-<topic>.md` / `kimi-<topic>-audit.md`.

A brief that produces useful output has all of:
- **What the game is** — these models have no project context whatsoever
- **What exists right now**, honestly, including the flaws
- **Engine facts they must not "correct"** (Godot 4.3 specifics, this
  project's collision layers, which base classes own which members)
- **The actual question**, specific and answerable
- **Hard constraints** — no new shaders/art/frameworks, keep existing
  identity, difficulty targets
- **An exact output format**

For Kimi audits, additionally: **describe the bug class you're hunting, with
real examples from this project's history.** The Distributor audit that found
real defects opened with the three shipped bugs (dead state machine, ungated
`take_damage`, wrong `collision_mask`) and told Kimi to hunt that family.
Generic "review this code" produces generic output.

### 2. Dry-run, then dispatch

```bash
node scripts/or-call.mjs x-ai/grok-4.5 prompts/grok-<topic>.md \
  docs/model-responses/<date>-grok-<topic>.md --dry-run
# check cost + "Files inlined" is what you expect, then drop --dry-run
```

Kimi audits inline real source and can take **several minutes** — run them in
the background and do other work while waiting.

### 3. Verify before believing

Model output lands in `docs/model-responses/` with a header stamping it
**unvalidated**. Treat every claim as a hypothesis:

- Grok does not know this codebase. It will confidently assume level features
  that don't exist. *(Real example: it designed the Distributor's pull around
  "dragging the player into arena pits" — the boss arena floor is solid, there
  are no pits.)*
- Grok will reuse another boss's mechanic even when told not to. *(Real
  example: its GOLD perk was one-way gold platforms, which is exactly what the
  Auditor already does.)*
- Kimi sees only what you inlined. A finding about un-inlined code is a guess.

Check every claim against the real file before it informs code. Record what
you **rejected and why**, not just what you took.

### 4. Log the hand-off

In the session log (`docs/session-logs/<date>-<topic>.md`):
- which models, which briefs, actual cost
- what you took, what you rejected **and why**
- which findings were real vs. wrong on inspection

## Cost discipline

Real spend is small — a design brief with no files inlined is ~$0.02; a
6-file code audit is ~$0.20–0.40. The failure mode is not cost, it is
**paying for confident nonsense** by dispatching a vague brief or one whose
`@include` paths don't cover what you're asking about.

## Data-sharing note

`@include` means **real repository source leaves this machine** and reaches
Moonshot and xAI. Design briefs with zero files inlined carry no code
disclosure; code audits do. Both were authorised by the owner for this
project — but the asymmetry is worth stating when reporting a dispatch, since
a design-only brief can be approved on different grounds than a source audit.

## What "used the models" does NOT mean

- Pasting their output into the repo unverified
- Letting them own a decision — Claude owns every decision and every commit
- Dispatching a brief so vague the answer couldn't be wrong
- Claiming collaboration happened when only a dry-run was executed
