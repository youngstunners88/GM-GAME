# lil-blunt-icp — Layer 4 canisters

The Internet Computer half of Lil Blunt. Currently **one canister**: a
tamper-evident leaderboard.

Full reasoning, including why this canister and not the price feed, lives in
[`../docs/architecture/adr-icp-integration.md`](../docs/architecture/adr-icp-integration.md).

## Toolchain

```bash
npm install -g @icp-sdk/icp-cli   # DFINITY's CLI. NOT `@icp-cli/cli` (doesn't
                                  # exist) and NOT bare `icp-cli` (unaffiliated
                                  # author, different package).
npm install -g ic-mops            # Motoko package manager
cargo install ic-wasm             # required by the @dfinity/motoko recipe
```

## Build

```bash
mops install
icp build
```

Produces `.mops/.build/leaderboard.wasm` + `leaderboard.did`. This is verified
working in the CI sandbox.

## Deploy

```bash
icp network start --background
icp deploy --network local
icp canister call leaderboard claimAdmin   # one-time, first-come
```

`icp network start` downloads a launcher from `api.github.com`, which the CI
sandbox's egress policy blocks (403). Run it on a developer machine.

Put the resulting id into `config.json → icp.leaderboard_canister_id`. Until
you do, `IcpBackend` is inert and the game reads from the Cloudflare Worker
exactly as before.

## Interface

Reads over the HTTP gateway (`https://<canister-id>.icp0.io`):

| Route | Returns |
|---|---|
| `GET /health` | `{"ok":true,"canister":"leaderboard","entries":N}` |
| `GET /top?level=N&limit=M` | `{"source":"icp","count":N,"entries":[…]}` — `level=0` or omitted means all levels |

Writes are Candid update calls only — an HTTP POST would arrive as the
anonymous principal and could not be attributed to a player:

```
submit : (level : nat, score : nat, handle : text) -> (SubmitResult)
```

## What the anti-cheat actually claims

Authenticated caller, anonymous rejected, score/level ceilings, 10s
per-principal cooldown, one best run per player per level, and admin that can
only *remove* entries — never set a score.

It does **not** stop a modified client from reporting a score it didn't earn;
the game is client-authoritative and no backend fixes that. What it buys is
attribution and an auditable history. Please don't let anyone market it as
"cheat-proof."
