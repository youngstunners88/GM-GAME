# DeFi Review — manual gate for on-chain interactions

The secure-build-checklist's DeFi category (DEFI001–008) activates on `.sol`/
contract artifacts. **This repo ships no Solidity** — but the game INTERACTS
with external contracts (SMOKE/DIAMONDS/GoldMine ERC-20s, Survivor-badge
ERC-721, all on Base). So the 8 upstream checks stay MANUAL, and two
GM-GAME-specific manual checks are added. **None of these can be automated
away; a human signs off before contract addresses land in `config.json`.**

## GM-GAME manual checks (added per integration task #3)

### M-DEFI-1 · Contract addresses are correct and audited — ◐ verified on-chain 2026-07-19; audit attestation still pending client
- [x] Addresses supplied by the founder directly (project owner = official
      channel) and **cross-checked on-chain via direct RPC** (stronger than an
      explorer page): `eth_getCode` (real bytecode) + `symbol()`:
      | Token | Address | Chain | Bytecode | symbol() |
      |---|---|---|---|---|
      | SMOKE | `0x6FBa5157f650DE083Bf8ca1B19Cb172dc511843d` | **Base** | ✅ 13 KB | `SMOKE` |
      | DIAMONDS | `0xd645250EdbE9d57c12fbbB24DEf3153E5F19Df08` | **Ethereum** | ✅ 8 KB | `DIAMONDS` |
      | GoldMine | `0xfF5FAB9b60955dA5726A5787b9cbf2B4B298A197` | **Ethereum** | ✅ 12 KB | `GOLD` |
      ⚠️ **Cross-chain finding:** DIAMONDS + GOLD have NO code on Base — reads
      must be chain-aware. Resolved via the stateless backend `/balances`
      endpoint (fixed RPC map, one chain per token). Only these on-chain-
      verified addresses are baked into that endpoint's server-side map.
- [ ] Badge ERC-721 `mint()` (selector `0x1249c58b`) confirmed: mints to
      `msg.sender`, no payment beyond gas, no owner-only revert for players.
      (No badge contract deployed yet — still empty in config.)
- [ ] Audit status of each contract recorded here with a link — and per the
      skill's rule: **an audit badge is evidence, not proof**; unverified or
      unaudited contracts get a written risk acceptance from the client.
      **Client action:** reply with audit links (or "accepted unaudited") for
      the three tokens above; balances are read-only so the game's exposure is
      cosmetic-perk gating, not fund risk.

### M-DEFI-2 · Wallet connect requests no dangerous permissions — ✅ holds by construction (re-verify each change to web3.js)
- [x] `web/web3.js` uses ONLY `eth_requestAccounts` (connect), `eth_call`
      (read-only balanceOf), `eth_sendTransaction` for `mint()` — reviewed
      2026-07-19, no other methods present.
- [x] **Zero `approve`/`increaseAllowance` calls** — the game NEVER requests
      token approvals, so "unlimited approval" phishing is structurally
      impossible from our code.
- [x] No `eth_sign`/`personal_sign` of opaque blobs; no `wallet_addEthereumChain`
      / `wallet_switchEthereumChain` pressure.
- [ ] Re-tick this section in any PR that touches `web/web3.js` or
      `web3_bridge.gd` (sentinel TRUST-001 enforces the key-handling half).

## Upstream DEFI001–008, answered for our architecture

| Check | Status for GM-GAME |
|---|---|
| Privileged state changes | N/A in-repo (no contracts of ours); M-DEFI-1 covers the external badge contract's owner powers |
| Economic invariants | Game scores are OFF-chain (KV); no in-game action moves value |
| Oracle manipulation | No price oracles consumed; `balanceOf > 0` is the only chain read |
| Reentrancy / callbacks | We never receive callbacks; reads are `eth_call`, the one write is user-signed mint |
| Flash-loan / same-tx attacks | Perks read balances at level start for cosmetics/spectacle only — a flash-loaned balance buys a golden skin, not value |
| Token-standard edge cases | Any `balanceOf > 0` (raw units) unlocks perks — fee-on-transfer/decimals quirks can't break anything |
| Upgrade/admin controls | External contracts: recorded under M-DEFI-1 audit notes |
| Testing + monitoring | Client-side: rate-limited backend + funnel analytics; on-chain monitoring N/A until we deploy our own contract |

**Trigger to re-open this file as a FULL review:** the day this repo gains a
`.sol` file, deploys its own contract, or adds ANY `approve` flow.
