---
name: gm-game-ecosystem-funding-audit
description: Answer funding questions about Rich's SMOKE / DIAMONDS / GOLD / BLAZE ecosystem from the chain itself - which contracts exist, what ETH they hold and receive, who holds X28, who can change the rules - and have Jev judge the NUMBERS. TRIGGER when the captain or founder asks "how much ETH did X take in / pay out", "are the certificate payouts funded", "who owns the contract", "is it verified", "where does the mint ETH go", when a funding or NFT-yield promise is about to be made, or before updating docs/goldmine_ecosystem_system_doc.md section 9.
user-invocable: true
allowed-tools: Bash, Read, Grep, Write, Edit
---

# Ecosystem Funding Audit (chain facts + Jev on the numbers)

The ecosystem's income problem is a **promised-versus-funded** problem (Diamond Certificates under-paid because the
BLAZE-stake ETH feeding them was too small). This skill answers "was it funded?" with chain data instead of opinion.

## Who does what (the rule that keeps this honest)

| Role | Does | Never does |
|---|---|---|
| **Claude** | Runs the script, reads the raw facts, re-derives every number, writes the finding | Quote a Jev number as a fact |
| **Blockscout / public RPC** | Supply balances, transactions, verified source, holders, `owner()` | Sign, send, approve or write anything |
| **Jev** (`~typesafe/jev-latest`) | Gives a calibrated yes / no / uncertain on **numbers Claude hands it** | See pages, images or prose; run Etherscan; be the final word |

Jev is text-only and cannot call Etherscan, so Claude fetches the data and Jev only judges it. Jev's output is a lead.
`scripts/jev.mjs` already holds the transport, thresholds (>=0.8 yes, <=0.2 no, between = UNCERTAIN) and cost (~$0.00002).

## Run it

```bash
# 1. Discover contracts from the live dApps (their JS bundles carry the address maps; names come from Blockscout)
node scripts/ecosystem-onchain.mjs discover https://app.titanblaze.win/auction https://diamonds1111.win/ https://mine4gold.app/
#    -> tools/ecosystem-audit/registry.json

# 2. Standard audit over the registry (balances, 10-day ETH/day, owner(), source red flags, recent flows)
node scripts/ecosystem-onchain.mjs audit            # -> tools/ecosystem-audit/facts.json   (~2-4 min, rate-limited)

# 3. Jev judges the numbers
node scripts/ecosystem-onchain.mjs jev

# Targeted questions
node scripts/ecosystem-onchain.mjs inspect <addr>                 # name, verified, proxy, ETH, owner(), setters
node scripts/ecosystem-onchain.mjs flows <addr> --pages 8         # ETH in/out per month (says PARTIAL / TRUNCATED)
node scripts/ecosystem-onchain.mjs methods <addr>                 # what an UNVERIFIED contract does: methods called, ETH sent, distinct callers
node scripts/ecosystem-onchain.mjs tokenflows <addr> --pages 14   # ERC-20 sent out, by token and destination = the real split
node scripts/ecosystem-onchain.mjs destinations <addr>            # ETH sent out, by recipient (often just WETH; use tokenflows after)
node scripts/ecosystem-onchain.mjs balance <addr>                 # daily ETH balance history
node scripts/ecosystem-onchain.mjs holders <token> --top 10       # e.g. who holds the ~800B X28
node scripts/ecosystem-onchain.mjs source <addr> --grep "percent|BPS|10000|constant"   # the splits, from code
```

Measured results are recorded by hand in `tools/ecosystem-audit/findings.json` (one line each, naming the command that
reproduces it). `jev` appends those lines to the facts it judges. Update that file whenever a number changes.

## Which captain question this answers

| Question (docs/goldmine_ecosystem_system_doc.md section 9) | Command | On-chain answer? |
|---|---|---|
| ETH held / received by the certificate and BLAZE pots | `inspect`, `flows`, `balance` | **Yes** |
| BLAZE-stake ETH inflow history | `flows` on BlazeStaking, `balance` on DiamondHand | **Yes** |
| How many certificates sold, ETH raised | `holders` / `inspect` on the certificate contract | Yes (if the NFT is a standard token) |
| Who can change the rules / is it verified | `inspect` (owner, setters, upgradeable, verified) | **Yes** |
| Mint split (GOLD liquidity 5% or 10%, DIAMONDS missing 8%) | `tokenflows <miner>` (works without source); `source --grep` if verified | **Yes, empirically.** The documented split and the observed split can differ: record both. |
| Who holds the ~800B X28 | `holders 0x5c47902c8C80779CB99235E42C354E53F38C3B0d` | **Yes** |
| Sweeper-bot rules, Smoke Lounge / Bong Party product, run-rate, wallet counts of buyers | - | **No.** Ask the captain. Do not guess. |

## Rules

1. **Read-only.** Nothing in this skill signs, sends, approves or writes on-chain. No private keys, no `eth_sendTransaction`.
2. **Two-source rule for any number that reaches a doc:** re-check it a second way (a `balance` series against a `flows`
   sum, or the same call a day later). A number from one call is a lead.
3. **Always state "as of" date and mark TRUNCATED flows.** `flows` only reads the newest `--pages x 50` items.
4. **An unverified contract is a finding, not a gap to fill.** Record it. Do not infer the code's behaviour from its name.
5. **A balance is not a promise.** Compare it with what was promised before saying "funded" or "underfunded".
6. **Jev gets numbers only.** Never hand it a screenshot or a page. State the threshold inside the question (as the
   script does) so the answer is checkable.
7. **Use Etherscan if a key exists.** Etherscan V2 needs `ETHERSCAN_API_KEY` (not set in this environment; check by name
   with `env-secrets-and-apis`). The script is Blockscout-only today; with a key, cross-check headline numbers at
   `https://api.etherscan.io/v2/api?chainid=1&module=account&action=balance&address=<a>&apikey=$ETHERSCAN_API_KEY`.
   Never print or commit the key.
8. **Addresses stay out of game code** (CLAUDE.md). The registry lives in `tools/ecosystem-audit/` as analysis data only.

## Reading unverified contracts (most of Rich's money contracts are)

When source is not published you cannot read the rules, but you can fingerprint the contract:
1. `methods <addr>` shows which functions people call. `mint`/`startMiner` with ETH attached is a sale; `claimRewards` /
   `batchClaimRewards` is a payout pot; one sender making ~10 calls a day is a keeper bot; `swapTitanX`/`swapEth` is a crusher.
2. `tokenflows <miner>` shows where a mint's output actually goes. **A miner that sends all its ETH to WETH9 has simply
   wrapped it**; the real split appears in the WBTC / XAUT / DIAMONDS transfers after that.
3. `holders <token>` shows which contracts hold the supply. Cross-check totals: GOLD supply x price matched DexScreener's
   FDV to within 0.01%, which is a good sanity test for both numbers.
4. **Label every such role "inferred".** Never write "the Fort Knox vault" about an unverified address without that word.

## Jev is a lead: the override rule (observed 2026-10-05)

Jev answered "is the paying base under 100 wallets?" with *uncertain* (0.31), although 42 + 25 + 19 = 86 is under 100 even
with zero overlap. Claude's arithmetic wins, and the reply says so. Conversely, Jev said *uncertain* (0.35) on "has mining
stalled?", which was the honest answer (DIAMONDS stalled, GOLD showed one spike week). **Report Jev's band, then state
whether Claude's own derivation agrees.** Never round an uncertain to yes, and never let Jev's number replace a sum you can do.

## Traps found while building this

- **`fetch` needs a timeout.** One stalled socket on a heavy contract hung a whole audit. Blockscout's
  `internal-transactions` endpoint times out on busy contracts (the certificate contract, DiamondHand beyond page 1); the
  script degrades to PARTIAL, keeps the normal-transaction data and says so. Do not "fix" it by retrying harder.
- **Never wrap a long command in `timeout` + `| tail`.** The output is hidden until the end and a kill loses everything.
  `audit` writes `facts.json` after every contract and prints progress; run it in the background.
- **`pkill -f` / `pgrep -f` with the script's name kills your own shell** (the pattern is in the command line). Use
  `ps aux | grep "[e]cosystem-onchain"` and kill by PID.

- `app.titanblaze.win` ships **two** address sets: chain `1` (mainnet) and `11155111` (Sepolia testnet). The testnet
  addresses appear on mainnet as empty "EOA" rows. Ignore them. Mainnet WETH is `0xC02a...`, Sepolia's is `0xfFf9...`.
- Bundles also contain noise (multicall, ENS, ERC-4337 EntryPoints, Uniswap pools). The script filters them as `infra`.
- `owner()` returning nothing does not mean "no admin": roles, proxy admins and setters exist. Read `setters` and `upgradeable`.
- Blockscout rate-limits (HTTP 429). The script spaces and retries calls. Do not raise the page count to chase old history
  without expecting a long run.
- ETH price is not read from chain here. Any dollar figure needs an explicit, dated ETH price.
- Public RPC is a convenience, not a source of truth for historical data. Use it for `eth_call` only.

## Output discipline

- Update `docs/goldmine_ecosystem_system_doc.md` section 9 with: **answered** (with the number, address and as-of date),
  **partly answered**, **cannot be answered from chain**.
- Commit `tools/ecosystem-audit/registry.json` and `facts.json` only after the sentinel passes (`git add`, then
  `bash scripts/security-sentinel.sh`).
- End the reply to the captain with the one-line model recommendation (CLAUDE.md MODEL-ADVICE RULE).
