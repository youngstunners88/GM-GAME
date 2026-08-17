---
name: model-bai-parallel-capacity
description: Explicit B.AI skill for parallel draft capacity on boss chase retunes, Stage 3 clutter lists, and Assay panel layout variants. Use when primary OpenRouter lanes are rate-limited or when founder demands every available model.
---


# B.AI — Parallel Capacity

## Role

Extra Claude-compatible capacity. Prefer the usable non-premium lane available in the environment (historically `kimi-k2.5` when premium models require deposit). Never override the orchestrator's own model routing by changing `ANTHROPIC_BASE_URL` globally.

## Useful parallel tasks

1\. Draft a minimal chase retune patch for `claim_jumper.gd` / `distributor.gd` (state machine only, no new features).  
2\. Produce a Stage 3 clutter deletion list from `level_03_data.tres` \+ spawn tables.  
3\. Draft Assay panel layout hierarchy (Label names \+ suggested min heights / gaps).  
4\. Short "what would still look shitty after this patch" self-critique.

## Rules

- Key presence checked by name only; never print secrets.  
- If the account cannot run the requested model, return a one-line blocker instead of inventing output.  
- Claude remains the only committer; B.AI drafts are advisory until integrated and gated.
