# ICP CONTEXT MANIFEST (Layer 4)

Load `default.md` first, then this.

## Always load

| Path | Why |
|---|---|
| `docs/architecture/adr-icp-integration.md` | The decision, the corrections, the blocker |
| `lil-blunt-icp/README.md` | Toolchain + deploy commands that actually work |

## Load on demand

| Task | Load |
|---|---|
| Canister logic | `lil-blunt-icp/src/leaderboard.mo` |
| Godot bridge | `src/autoload/icp_backend.gd` |
| Fallback backend | `src/autoload/web3_bridge.gd` |
| Wiring | `config.json` (`icp` block) |

## Toolchain — the docs circulating internally are wrong here

Verified 2026-07-27 against npm and the CLI itself:

| Circulating instruction | Reality |
|---|---|
| `npm i -g @icp-cli/cli` | **404, does not exist.** Use `@icp-sdk/icp-cli`. An unrelated bare `icp-cli` from a third-party author DOES exist — installing it is a supply-chain mistake. |
| `icp init --template fullstack` | No `init` subcommand and no `fullstack` template. It is `icp new`; templates are `motoko`, `rust`, `hello-world`, `static-website`, `bitcoin-starter`, `proxy`. |
| (unmentioned) | `icp build` also needs `ic-mops` (`npm i -g ic-mops`) and `ic-wasm` (`cargo install ic-wasm`). |

```bash
npm install -g @icp-sdk/icp-cli ic-mops
cargo install ic-wasm
cd lil-blunt-icp && mops install && icp build     # verified working in CI
```

## Known environment blocker

`icp network start` **cannot run in the CI sandbox.** The launcher is fetched
from `api.github.com/repos/dfinity/icp-cli-network-launcher/releases/latest`,
which returns **403 from the egress policy** (bare `api.github.com` returns 200,
so it is that path specifically). Docker fallback is unavailable — installed,
no daemon.

Per the sandbox proxy guidance, a policy 403 is reported, not routed around.
Local replica deploy is a developer-machine step. Everything before it —
scaffold, `mops install`, Motoko compile, wasm + Candid emission — is verifiable
in CI, so do not skip those and call the whole thing blocked.

## Domain rules

- **`icp/` never references `src/` directly** — HTTP API only (§2.3).
- **Reads over HTTP, writes over Candid.** An HTTP POST to a canister arrives as
  the *anonymous principal*, so it cannot be attributed to a player and would
  make the on-chain board no more trustworthy than the Cloudflare Worker.
- **ICP is additive.** Every call falls back to the Worker, which falls back to
  the offline cache. A dead canister must never cost a player a run.
- **Canister IDs live in `config.json`**, charset-validated before being
  interpolated into a URL. Empty ID = the autoload is inert.
- **Never persist prices or balances.** They are a live cache
  (`GameManager.crypto_state`); a saved balance is a stale balance that could
  claim a player holds tokens they have sold.
- **No wallet gate on gameplay.** Token perks are cosmetic. "Prove a stake →
  unlock content" was proposed and rejected — it contradicts the no-pay-to-win
  posture in the v1.2 GDD.

## The honest anti-cheat claim

The leaderboard canister gives **attribution and an auditable history**. It does
not stop a modified client reporting a score it didn't earn — the game is
client-authoritative and no backend fixes that. Do not let this be marketed as
"cheat-proof."

## Security

`mops.lock` is full of 64-hex SHA256 integrity hashes and trips SEC-005 unless
excluded — it already is, narrowly, in `scripts/security-sentinel.sh`. Do not
gitignore it to silence the check: committing it is what makes canister builds
reproducible, so removing it would reduce supply-chain integrity while
appearing to improve it.
