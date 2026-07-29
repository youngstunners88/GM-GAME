# Claude's validation of Grok's identity-strategy paper

Source: `docs/model-responses/2026-07-28-grok-identity-strategy.md`
(x-ai/grok-4.5, 941 in / 1997 out, $0.0139)

Per the orchestrator rule, model output is an INPUT, not a decision. Every
load-bearing claim is checked below before any of it informs code.

## Claims checked

| Claim | Verdict | Evidence |
|---|---|---|
| "Motoko has **no built-in ecrecover**" | **CONFIRMED** | `mops` base 0.16.0 ships 48 modules; grep for `secp256k1`/`ecrecover`/`keccak` across `.mops/base@0.16.0/src/` returns nothing. |
| Community Motoko crypto libs exist but need maturity checks (flagged VERIFY) | **CONFIRMED, and the caution was warranted** | `mops search` finds `ecdsa` v8.0.1 (updated 2026-06-25) and `sha3` v0.1.1 (updated **2023-03-07**). The ECDSA package is current; the hashing package is three years stale. |
| Attribution can come from the signed payload rather than the IC principal | **Architecturally sound, but see "Consequence" below** | Matches how the anonymous-principal problem is normally worked around. |

### The trap Grok flagged and was right to flag
Ethereum uses **keccak256**, which is *not* standardised SHA3-256 — they differ
in padding. A package named `sha3` may expose one, the other, or both. Picking
wrong produces signatures that verify against nothing, and the failure looks
like "the wallet is broken" rather than "we hashed with the wrong function".
This must be settled with an actual test vector before any code is written.

## Consequence Grok did not draw out (Claude's addition)

Its recommendation **contradicts the leaderboard canister as currently built**.

`lil-blunt-icp/src/leaderboard.mo` today:
- rejects `Principal.isAnonymous(caller)`,
- keys every entry on `player : Principal`,
- and its whole trust argument rests on `caller` being unforgeable.

Grok's path deliberately accepts the anonymous principal and derives identity
from an EVM signature in the *arguments*. Those are incompatible designs. Going
Rabby-only means reworking `Entry`, `submit`, `withoutPriorRun`, and the
dedup/ranking logic to key on a checksummed EVM address — plus adding nonce and
clock-skew replay protection that the current design gets free from `caller`.

That is a real cost the paper does not price, and it should be on the table
before the decision is made — not discovered during implementation.

## What was rejected
Nothing. The paper invented no APIs, cited no fake file paths, and marked its
own uncertainties. It is unusually well-calibrated for an unvalidated dispatch.

## Status
**Presented to the owner. No code written.** The identity decision remains open
and is still the blocker on the ICP write path.
