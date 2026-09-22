---
name: tool-farm
description: The vetted toolchain and task router for this repo. Read BEFORE evaluating, installing, or adopting any external tool, skill, MCP server or library — the verdict may already exist. Also read at the START of a non-trivial task to route it to the right model tier and context manifest instead of loading the whole repo. Use when asked about token burn, tool selection, routing, "should we use X", or when a new repo/link is proposed.
---

# Tool Farm — vetted tooling + task routing

Two jobs: stop us re-researching tools we already judged, and stop us loading context
a task does not need. Both are token-burn problems.

## Before adopting ANY external tool

Check the registry first — 31 tools are already evaluated:

```bash
node scripts/farm/farm.mjs why <id>        # why it was adopted/mined/rejected
node scripts/farm/farm.mjs list ADOPT      # or STEAL-IDEAS-ONLY / IGNORE
```

Three verdicts, and they are binding:

| Verdict | Meaning |
|---|---|
| **ADOPT** | Wired in. Requires `verified.method = "ran-it-here"` — we ran it in this container. |
| **STEAL-IDEAS-ONLY** | The pattern was copied; we took **no dependency**. Must record `pattern_taken`. |
| **IGNORE** | Not used. The reason is recorded so it is not re-litigated. |

**You may not mark something ADOPT because it is popular.** The validator rejects it:
star counts cannot be verified from this container (the GitHub API is scoped to our own
repos), so `popularity_claim` is explicitly untrusted and must never be cited as fact.
Adoption requires having run the thing.

Adding a tool means editing `tools/farm/registry.json`, then:

```bash
node scripts/farm/farm.mjs validate        # fails closed
```

## Routing a task (do this first on anything non-trivial)

```bash
python3 scripts/farm/route.py "the boss stops chasing after phase 2"
python3 scripts/farm/route.py --json "…"   # for scripts
```

Returns the model tier, the context manifest to load, the skills to pull, and the gates
to pass. The manifest line is the actual saving: `trivial-edit` loads **nothing**, so a
typo fix does not drag in the full architecture set.

Engine is **Jev** (`pijev`, TypeLLM) — a calibrated option-picker that returns a
probability per class rather than prose, averaged over several option orderings so the
answer does not depend on the order the classes happen to be listed in. Needs
`TYPESAFE_API` in the environment.

**It fails soft, toward safety.** No key, no network, or an unrecognised answer routes to
`unknown` → opus + full manifest. A broken router never silently downgrades work to a
cheaper tier.

Routing policy lives in `tools/farm/routes.json`. Change classes there; you should not
need to touch `route.py`.

## Or call the tools directly (cheapest path)

The `gm-toolkit` MCP server fronts the same things as typed calls, which avoids reading a
skill file to recall an incantation:

- `route_task` — classify a task
- `security_gate` — the 18-check sentinel (**`git add` first** — it scans `git ls-files`)
- `farm_validate` — validate registry + routes
- `tool_verdict`, `list_tools_by_verdict` — registry lookups

It adapts the existing scripts; it never reimplements a check. If a gate changes, it
changes in the script, and CI and the agent stay in step automatically.

## Separation of concerns

| Layer | Lives in | Committed? |
|---|---|---|
| Policy (what the classes/verdicts are) | `tools/farm/*.json` | yes — reviewed in PRs |
| Mechanism (how it is applied) | `scripts/farm/` | yes |
| Adapter (typed tool surface) | `tools/mcp/gm_toolkit.py` | yes |
| Runtime state | `.farm/` | **no** — gitignored |

Config is data, not code. You can retune routing or reject a tool without touching logic.

## Rejections worth remembering

- **OmniRoute** — security blocker (reported npm block over obfuscated code, a conceded
  credential-overwrite path, plaintext credentials by default, guardrails that fail open).
  Incompatible with the SECURITY-GATE RULE regardless of popularity.
- **freebuff** — unattributed ad-funded tool wanting codebase access. Supply-chain risk.
- **deep-research skill** — deliberately token-*expensive*; opposite of the goal.
- **n8n / huginn** — a server to do what a GitHub Actions YAML already does here.
- **IMSI-catcher, turboquant_plus, starknet, kapso, Crucix** — no game-dev connection.

Full reasons: `node scripts/farm/farm.mjs why <id>`.
