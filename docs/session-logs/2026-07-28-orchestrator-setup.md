# Session Log — 2026-07-28 · Multi-model orchestrator setup

## Pre-Session State
- Branch: `claude/setup-game-dev-environment-itWJv`
- HEAD: `941ae2f` (boss script fix + facing + onboarding readability)
- Open PR: #11 (draft)
- Working tree: clean
- OpenRouter: key present. `limit_remaining` is **null** — no spending cap is
  configured on this key, so there is no balance to read. Usage to date $1.26.
  The checklist item "check credit balance" cannot be satisfied as written;
  usage is the only available signal.

## Turn Scope
Install the multi-model orchestrator kit and make it actually dispatchable.
No model was dispatched this turn — see "Blocked on owner".

## Findings before dispatching (all verified, none assumed)

### 1. The wrapper could not have worked as shipped
`or-call.mjs` sent prompt text only. Kimi and Grok have no access to this
repository, so `kimi-icp-audit.md` — which says "FILES TO REVIEW:
lil-blunt-icp/price_feed.mo" — would have reached a model that cannot open
that file. The two possible outcomes were `FILE NOT FOUND` for everything
(paid, useless) or invented file contents (paid, actively harmful).

**Fix:** prompts now use `@include <path>`; the wrapper inlines the real file
before sending, and **aborts without calling the API** if any path is missing.

### 2. Five of six file paths in the prompt pack were wrong
| Cited | Reality |
|---|---|
| `lil-blunt-icp/price_feed.mo` | `lil-blunt-icp/src/price_feed.mo` |
| `lil-blunt-icp/player_registry.mo` | `lil-blunt-icp/src/player_registry.mo` |
| `autoload/web3_bridge.gd` | `src/autoload/web3_bridge.gd` |
| `autoload/progression_state.gd` | **does not exist** — a Dictionary in `game_manager.gd` |
| `autoload/crypto_state.gd` | **does not exist** — a Dictionary in `game_manager.gd` |

The prompts instructing Kimi "do not invent file paths" contained invented file
paths. All corrected; a path-validation sweep now runs over `prompts/*.md`.

### 3. A factual error in the Kimi brief
`kimi-icp-audit.md` stated as verified fact that "player_registry.mo handles
score submission". It does not — `leaderboard.mo` owns score submission;
`player_registry.mo` owns identity and roles. Feeding that in as ground truth
would have produced a confidently wrong audit. Corrected.

### 4. Grok cost table was off by ~1000x
The kit lists Grok at ~$0.001/1M input. Live pricing:

| Model | Input /1M | Output /1M | Context |
|---|---|---|---|
| `moonshotai/kimi-k3` | $3.00 | $15.00 | 1,048,576 |
| `x-ai/grok-4.5` | $2.00 | $6.00 | 500,000 |
| `x-ai/grok-4.3` | $1.25 | $2.50 | 1,000,000 |
| `x-ai/grok-4.20` | $1.25 | $2.50 | 2,000,000 |

Both model IDs named in the kit exist. `x-ai/grok-4.5` is the newest numbered
Grok, so "latest `x-ai/grok-*`" resolves to it. The wrapper now reads pricing
live from `/models` instead of a hardcoded table that was already stale.

### 5. My own error, caught by the dry-run
The first `getRates()` swallowed every exception and returned null, which the
caller reported as "model not found". One transient fetch blip therefore sent
me hunting for a model ID that was correct all along. Now retries once and
reports the true cause.

## Verification of the tooling
- `--dry-run` on both planned dispatches: succeeds, spends nothing.
- Negative control — unknown model → `not in OpenRouter's catalogue`, exit 3.
- Negative control — missing `@include` → refuses to dispatch, exit 2.
- Path sweep across all six prompts: every cited path resolves.

## Integration
- Files added: `scripts/or-call.mjs`, `prompts/*.md` (6), `docs/session-logs/`
- No game code touched, so the gameplay gates are unchanged from `941ae2f`.
- Gates re-run this turn: security-sentinel 18/18, script-compile 106/71.

## Blocked on owner
Dispatching is not just a spend decision — `@include` means **real repository
source leaves this machine** and reaches Moonshot and xAI. That is a
data-sharing choice the owner should make explicitly, so nothing has been sent.

Planned first dispatch, worst case **$0.21 total**:
| Model | Prompt | Inlines | Est. in | Worst case |
|---|---|---|---|---|
| `moonshotai/kimi-k3` | `prompts/kimi-icp-audit.md` | 5 files (3 canisters + bridge + test) | ~11.9k tok | $0.1558 |
| `x-ai/grok-4.5` | `prompts/grok-identity-strategy.md` | 0 files (strategy only) | ~0.7k tok | $0.0494 |

Note the asymmetry: the Grok brief inlines **no source at all**, so approving it
carries no code-disclosure risk. They can be approved independently.

## Post-Session State
- Branch: `claude/setup-game-dev-environment-itWJv`
- Blockers: owner approval to send source to third-party providers; identity
  strategy decision still open; Devvit still blocked on Reddit OAuth.
- Next: on approval, dispatch both, validate every claim against real files,
  integrate only what survives, re-run the full battery.
