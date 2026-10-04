# Lil Blunt NFT collection — the one contract (game <-> ICP canister <-> smokegame.win)

Founder (2026-10-04): every stage issues TWO NFTs - one for defeating the stage boss, one for passing the stage
test (the protocol exam). 3 stages x 2 = **6 NFTs**. Each issuance, with its **date and time, is recorded on the
Internet Computer** (the canister's own `Time.now()`, not the player's clock).
This file is the single source of truth. The Godot game (`src/data/nft_collection.json`), the Caffeine-built canister
on smokegame.win and the claim gallery MUST all agree with it. Change it here first, then both sides.

## The six
| nft_id | Name | Stage | Trigger (real game event) | Art |
|---|---|---|---|---|
| `boss_auditor` | Tax Evader | 1 Smoke Realm | Defeat the Auditor | `src/assets/nft/nft_boss_auditor.webp` |
| `boss_distributor` | Crystal Miner | 2 Crystal Caverns | Defeat the Distributor | `nft_boss_distributor.webp` |
| `boss_claimjumper` | Claim Jumper Slayer | 3 Gold Rush | Defeat the Claim Jumper | `nft_boss_claimjumper.webp` |
| `test_smoke` | SMOKE Scholar | 1 / SMOKE protocol room | PASS the SMOKE exam (>= 7 of 11) | `nft_test_smoke.webp` |
| `test_diamonds` | DIAMONDS Scholar | 2 / DIAMONDS protocol room | PASS the DIAMONDS exam | `nft_test_diamonds.webp` |
| `test_gold` | GOLD Scholar | 3 / GOLD MINE protocol room | PASS the GOLD exam | `nft_test_gold.webp` |

Source art: founder's Drive folder "NFTs" (copies in `design/nft/drive/`). The three test-pass plates currently use the
founder's Blaze Rush artwork (only stage-matched art in the folder) - swap in `nft_collection.json` if he supplies others.

Rules: soulbound (non-transferable), one per player per nft_id, proof-of-play only, no gameplay multipliers, never gated
on token holdings. A FAILED exam issues nothing. Names/ids are final; do not invent more NFTs.

## Identity
No wallet, no login at issue time. The game makes a random `player_key` (32 lowercase hex) on first run and keeps it in
`user://`. The player later proves ownership on smokegame.win with Internet Identity and the canister binds
`player_key -> principal` (claim). Until claimed, an issuance is "issued, unclaimed".

## Canister: `nft_ledger` (Motoko) - HTTP interface the game calls (anonymous caller)
Base URL `https://<canister-id>.icp0.io` (id comes from `config.json -> icp.nft_canister_id`, never hard-coded).

### POST /issue   (Content-Type: application/json, body <= 2 KB)
Request:
```json
{"nft_id":"boss_auditor","player_key":"<32 lowercase hex characters>",
 "meta":{"stage":1,"score":null,"total":null,"passed":null,"build":"2026-10-04-abc1234"}}
```
`http_request` must return `upgrade = true` for POST so the write runs in `http_request_update`.
Response 200 (always JSON):
```json
{"ok":true,"duplicate":false,"nft_id":"boss_auditor","token_index":12,
 "issued_at_ns":1790000000000000000,"issued_at_iso":"2026-10-04T12:34:56Z"}
```
- `issued_at_ns` = `Time.now()` inside the canister at the moment of the update call (nanoseconds since epoch).
- Idempotent: the same (player_key, nft_id) again returns `duplicate:true` with the ORIGINAL token_index and time.
- Errors: 400 `{"ok":false,"error":"bad_nft_id|bad_player_key|bad_body|too_large"}`, 429 `{"ok":false,"error":"rate_limited"}`.

### GET /player/<player_key>  ->  `{"player_key":"...","claimed":false,"nfts":[{"nft_id","token_index","issued_at_ns","issued_at_iso"}]}`
### GET /collection  ->  `{"nfts":[{"nft_id","name","stage","kind","issued_count"}], "total_issued":n}`
### GET /health  ->  `{"ok":true,"canister":"nft_ledger","version":1}`

### Candid (for smokegame.win, Internet Identity)
```
claim : (player_key : text) -> async variant { ok : nat; err : text }   // binds caller principal; idempotent
myNfts : () -> async vec NftRecord                                         // by caller principal
type NftRecord = record { nft_id : text; token_index : nat; issued_at : int; player_key : text; claimed_by : opt principal };
```
Standard note: keep the record ICRC-7-shaped so a transferable tier can be added later; Phase 1 is soulbound.

## Game side (Godot) - what must stay true
- `NftIssuer` autoload issues locally FIRST (instant congrats + jingle + voice), then POSTs `/issue`.
- The congrats card shows the ON-CHAIN date/time only after the canister confirms it. Never show a fake chain time.
- Unconfirmed issuances are queued in `user://nft_issued.json` and retried; offline never blocks play.
- With `icp.nft_canister_id` empty the game still issues locally and shows "Saved - recording on ICP soon".

## Anti-cheat (honest limits)
Phase 1 issuance is client-reported (cosmetic, soulbound, no value). The canister must rate-limit per player_key and per
call volume. Before any NFT carries value, add server-verifiable proof (signed run events). Do not claim otherwise.
