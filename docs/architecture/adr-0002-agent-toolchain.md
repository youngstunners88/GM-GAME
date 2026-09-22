# ADR-0002: Agent toolchain — vetted farm, Jev routing, typed MCP adapter

## Status

Accepted

## Date

2026-09-22

## Last Verified

2026-09-22

## Decision Makers

Founder (supplied the candidate list and the goals: cut token burn, be more productive,
and build a farm folder system, a routing system, state management with separation of
concerns, and an abstraction layer).

## Summary

31 candidate tools were evaluated. **2 adopted, 7 mined for patterns, 22 rejected.**
Rather than install a stack, we built four thin layers around what we already have:
a vetted registry, a Jev-backed task router, a typed MCP adapter over existing scripts,
and an explicit config/mechanism/state split.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.3 — unaffected. No tool here touches the runtime or the export. |
| **Domain** | Developer tooling / agent harness |
| **Knowledge Risk** | LOW for the layers we wrote (zero-dependency stdlib). MEDIUM for `pijev` — see Consequences. |
| **Verification Required** | None outstanding. Every adopted tool was executed in this container; the validator's fail-closed path was negative-tested. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None |
| **Enables** | Cheaper routine work; a standing answer to "should we use X" |
| **Blocks** | None |
| **Ordering Note** | Does not touch ADR-0001. Godot 4.3 remains the runtime. |

## Context

A list of ~28 repos and links arrived with four architectural asks and a standing goal of
reducing token burn. The repo already carries ~150 skills, a context-manifest rule, hooks,
and a security sentinel — so the risk was not "too few tools", it was the opposite:
bolting on more skills multiplies trigger collisions and *raises* burn.

Two facts shaped the outcome:

1. **Star counts could not be verified.** The GitHub API is proxy-scoped to our own repos,
   and the research agents disagreed with each other about their own method (one claimed
   API access; two reported it blocked). Several reported figures were implausible. So
   popularity was removed from the decision entirely and recorded as untrusted.
2. **Most of the list does not apply to a Godot game.** Cellular surveillance, quant/KV-cache
   internals, an L2 chain, a WhatsApp API, an OSINT dashboard, a travel planner behind a
   moved link, and a 404. Force-fitting these would have been the expensive mistake.

## Decision

1. **A tool needs a registry row to be used.** `tools/farm/registry.json`, schema-validated,
   three binding verdicts (ADOPT / STEAL-IDEAS-ONLY / IGNORE).
2. **ADOPT requires having run it here.** The validator rejects `ADOPT` unless
   `verified.method = "ran-it-here"`. Reputation is not evidence. STEAL-IDEAS-ONLY must
   name the `pattern_taken`, so it is a decision rather than a bookmark.
3. **Jev routes tasks.** `scripts/farm/route.py` classifies a task via `pijev` and returns
   tier + manifest + skills + gates. A calibrated option-picker is far cheaper than asking
   a frontier model to reason about its own tier. **It fails soft toward the safest class**
   (opus + full manifest), never the cheapest.
4. **Routing policy is data.** `tools/farm/routes.json`. Retune without touching code.
5. **One typed MCP adapter, zero dependencies.** `tools/mcp/gm_toolkit.py` fronts the
   existing scripts. It adapts; it never reimplements a check, so CI and the agent cannot
   drift apart.

**Adopted:** `pijev` (routing engine), `skill-creator` (measures skill-trigger accuracy —
with ~150 skills, mis-triggering is a direct token cost).

**Rejected, notably:** OmniRoute on security grounds (reported npm block over obfuscated
code, a conceded credential-overwrite path, plaintext credentials by default, guardrails
failing open) — incompatible with the SECURITY-GATE RULE regardless of popularity;
freebuff as an unattributed tool wanting codebase access; the deep-research skill for
being deliberately token-expensive; n8n/huginn for needing a server to do what a GitHub
Actions YAML already does here.

## Consequences

**Positive**
- A typo fix loads no context at all; a security change loads the security checklist. The
  manifest field is the actual saving.
- "Should we use X" has a recorded answer instead of a fresh research cycle.
- Zero new runtime dependencies in the game. Nothing ships to players.
- Both adopted items were executed here, not taken on trust.

**Negative / accepted trade-offs**
- `pijev` is young and thin (19 stars / 3 commits as rendered). Accepted because it is
  *verified working*, confined to routing, and the router degrades to a static table
  without it. If it breaks, work still routes — conservatively.
- Routing costs one extra API call per task. Worth it when it prevents loading a full
  manifest, roughly break-even on genuinely trivial work.
- `TYPESAFE_API` is now a soft dependency for optimal routing. Absent, everything routes
  to opus: correct, just not cheap.
- The registry is a maintenance surface. Mitigated by the validator failing closed.

**Neutral**
- Pattern debts (OpenViking's path-addressed context store, SocratiCode's query-don't-read,
  impeccable's deterministic pre-filter) are recorded as `pattern_taken`, not dependencies.

## GDD Requirements Addressed

None — developer tooling. Supports every system by lowering the cost of working on them.

## Notes

Unverifiable popularity data is deliberately preserved in the registry under
`popularity_claim`, flagged untrusted, rather than deleted — so a future session sees that
the numbers were considered and rejected as evidence, and does not go re-gather them.
