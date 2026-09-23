---
name: laya-typed-decisions
description: Run fast local typed decisions (choice / rubric score / true-probability) with laya-mlx on Apple Silicon, instead of paying an LLM to classify. Use for bug triage, QA severity scoring, sprint routing, security-finding triage, asset-manifest routing, and pre-routing work before dispatching a paid model. Also the reference for the typed-decision pattern when designing enemy or boss AI. NOT usable inside the shipped web build — read the hard constraint first.
user-invocable: true
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
---

# Laya Typed Decisions (laya-mlx)

`laya-mlx` answers **constrained questions** — pick one of these options, score
against this rubric, is this proposition true — in a single bidirectional
forward pass. No token-by-token decoding, no generated JSON to parse, **zero
output tokens**, fully local.

Repo: <https://github.com/mizorewww/laya-mlx> · package `laya-mlx` 0.2.0 ·
weights on Hugging Face under `aac6fef/`.

---

## ⚠️ The hard constraint — read this before proposing it for anything

**This cannot run inside Lil Blunt Adventure.** Not "probably not" — the
dependency is:

```toml
requires-python = ">=3.11"
"mlx>=0.32.2,<0.33; sys_platform == 'darwin' and platform_machine == 'arm64'"
```

Python 3.11+, macOS, **Apple Silicon only**, via Apple's MLX framework. The
game ships as a Godot 4.3 **WebAssembly** export to itch.io. There is no
Python, no MLX and no Metal in that runtime. Anyone proposing "Laya for live
enemy AI" in the shipped build is proposing something that cannot be built.

It also does not run on **this** container (Linux x86_64). Every command in
this skill is for the founder's Mac, or for a macOS CI runner. From here you
can write the harness and the question sets; you cannot execute them.

**Where it is genuinely usable:**

| Use | Viable? |
|---|---|
| Dev-time tooling on the founder's Mac | ✅ the real win |
| macOS CI runner step | ✅ |
| Shipped itch.io web build | ❌ impossible — no Python/MLX in WASM |
| Native macOS export of the game | ⚠️ theoretically, but the project has no native export today |
| This Linux sandbox | ❌ |

---

## Why it's worth having anyway

The project currently pays a frontier model to do work that is **classification,
not reasoning**. `multi-model-orchestrator` dispatches to Grok 4.5 (~$2/$6 per
1M) and Kimi K3 (~$3/$15), and `jev-astra-taskforge` to GPT-6 Astra
($10/$50). A large share of those calls end in a label: *which system does this
touch, how severe is this, is this a blocker, which model should handle this.*

Laya answers that shape of question in **7.4–13.4 ms** (P50, M3 Max), locally,
for nothing after the one-time weight download. Its own `router_questions()`
preset exists precisely to decide **which model to send work to** — so the
cheapest correct architecture is: Laya routes and triages for free, and a paid
model is only woken for work that actually needs generation.

---

## The three question types

```python
import laya_mlx as laya
agent = laya.load("aac6fef/laya-mlx")

result = agent.predict(
    "Boss 3 freezes when the player dashes into the arena wall during phase 2.",
    {
        "system": {
            "type": "choice",
            "instructions": "Which system owns this bug?",
            "criteria": {
                "boss": "boss FSM, phases, arena",
                "player": "movement, dash, combat",
                "level": "geometry, hazards, checkpoints",
                "economy": "GOLD, vesting, rewards",
                "ui": "HUD, menus, panels",
            },
        },
        "severity": {
            "type": "score",
            "instructions": "How severe is this for a player?",
            "criteria": ["cosmetic", "annoying", "blocks progress", "unplayable"],
        },
        "is_softlock": {
            "type": "noul",
            "instructions": "Does this describe a freeze or soft-lock?",
        },
    },
)
print(result["answers"])
```

- **`choice`** → probabilities over named options. `criteria` takes a list of
  unique labels or a dict of label → description.
- **`score`** → probabilities over ordered rubric levels, plus the expected
  zero-based level.
- **`noul`** → P(true) for a proposition. (Spelled `noul`, not `bool`.)

State can be a string, a JSON dict, or a conversation list. `system_one` is an
alias for `predict`. Questions are batched independently (`batch_size=16` by
default).

---

## Fits in this repo, ranked by payoff

**1. Bug triage (`bug-triage`, `production/qa/bugs/`).** The skill re-evaluates
priority vs severity across every open bug. That is exactly choice + score, and
today it costs either agent time or a paid call per bug. Laya does the whole
backlog in well under a second.

**2. Pre-routing for `multi-model-orchestrator`.** Before spending on Grok or
Kimi, ask Laya: is this a design question or a code-correctness question, and
is it substantial enough to dispatch at all? The preset `router_questions()`
is built for this.

**3. Security-finding triage.** `scripts/security-sentinel.sh` emits 18 checks;
`guard_questions()` and `moderation_questions()` presets already model
severity scoring. Useful for ranking *new* findings, never for deciding
whether a blocker blocks — the sentinel's own fail-on logic stays
authoritative, because a probabilistic model must not gate a release.

**4. Asset-manifest routing** (`assets/art-manifest.json`,
`assets/audio-manifest.json`) — classify which entity/category a new asset
belongs to.

**5. Enemy/boss AI, as a PATTERN not a runtime.** The repo's `laya_mlx/snake/`
demo drives a real game loop: every move is a typed decision, wrapped in an
explicit **deterministic safety shield** that can override an unsafe proposal.
That shield is the transferable idea — `boss-chase-ai-auditor` and
`gm-game-boss-fsm-trace` already demand telegraphing and live-position reads.
Model the boss decision as a typed choice with a deterministic guard, then
**implement it in GDScript**. Do not attempt to call Laya from the game.

---

## Getting it running (on the founder's Mac)

```bash
pip install laya-mlx
python -c "import laya_mlx as laya; print(laya.load('aac6fef/laya-mlx'))"
```

Terminal demo, which is the fastest way to see whether it's worth adopting:

```bash
pip install 'laya-mlx[demo]'
hf download aac6fef/laya-multilingual-mlx
laya-snake            # needs a terminal ≥ 104 x 35
```

CLI for scripted use:

```bash
laya-mlx predict --model aac6fef/laya-mlx \
  --state-file state.json --questions questions.json
```

Checkpoints: `aac6fef/laya-mlx` (421M, English, 512-token context),
`aac6fef/laya-multilingual-mlx` (322M, 1024, fastest at 7.4 ms),
`aac6fef/laya-typed-decisions-mlx` (421M, 1024).

---

## Traps worth knowing before you trust an answer

- **Context is 512 tokens on the English checkpoint**, and instructions,
  options and state all share it. Long bug reports will silently truncate.
  Use the 1024-context checkpoints, or summarise first.
- **Choice options share one `head_max_len` budget.** A question with many
  labels leaves a few tokens per label and degrades. Over ~20 labels, use
  `predict_shortlist(...)` — it embeds state and labels, keeps the top `k` by
  cosine similarity, then predicts on the reduced set. Note that the returned
  probabilities are then over the kept labels only.
- **Calibration temperatures are clamped to [0.5, 5.0].** The shipped
  `choice:11+` bucket is 0.1006, which would sharpen logits ~10x and report a
  coin flip as near-certainty. The port clamps it and raises a
  `RuntimeWarning` naming every clamped bucket at load. Do not silence it.
- **Confidence is not accuracy.** The port's own docs say so. Never let a
  probability gate a release, a security blocker, or an economy commit —
  those have deterministic gates in this repo already, and they stay
  authoritative.
- **FP16 is the default**; `dtype="float32"` for closer numerical agreement.
  Port fidelity was 63/63 validation questions matched in both FP32 and FP16.
- **Not an official release.** Independent MLX port of Convai Innovations'
  Laya. Upstream keeps RLCD training and fine-tuning.

---

## How this relates to the other orchestration skills

| Skill | Cost | Use for |
|---|---|---|
| **`laya-typed-decisions`** | **free, local, ~10ms** | **Classify, score, route, triage** |
| `multi-model-orchestrator` | ~$2–15 / 1M | Design briefs (Grok), code audits (Kimi) |
| `jev-astra-taskforge` | $10/$50 per 1M | Structured task specs, browser-truth checks |

Right order for a large task: **Laya triages and routes → the paid model does
the work that needs generation → the deterministic gates decide what ships.**
