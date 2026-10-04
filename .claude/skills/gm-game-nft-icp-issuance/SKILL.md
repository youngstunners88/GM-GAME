---
name: gm-game-nft-icp-issuance
description: "Record every NFT issuance - with its date and time - on the Internet Computer, and keep the game and the Caffeine-built nft_ledger canister (smokegame.win) in concord. TRIGGER on ICP, canister, on-chain, 'issued at', claim, Internet Identity, Caffeine, nft_ledger, config.json icp.nft_canister_id, or any change to NftIssuer's network code."
---

# The rule that matters
The issuance **date and time are the canister's own `Time.now()`**, never the player's clock. The game may show an on-chain time
ONLY after the canister has replied with it. Until then it says "Saved. Recording on ICP soon." Never display a fabricated chain time,
never say "on-chain" for something that is not.

# Flow
1. Real event -> `NftIssuer.issue(id)` issues locally (card + jingle + voice, offline-safe).
2. `POST https://<nft_canister_id>.icp0.io/issue` (`IcpBackend.endpoint`, id from `config.json -> icp.nft_canister_id`, empty = inert).
   Canister `http_request` returns upgrade=true so the write runs in `http_request_update` and stamps `Time.now()`.
3. Reply is UNTRUSTED: must be `ok`, name the same nft_id, and carry `issued_at_iso` matching `YYYY-MM-DDTHH:MM:SSZ`. Stored in `user://nft_issued.json`.
4. Unconfirmed issuances retry on launch and on the next issuance; idempotent on both sides (canister returns the original token_index/time).
5. Ownership: the game's anonymous `player_key` is claimed on smokegame.win with Internet Identity (`claim(player_key)`); the card shows "C = copy claim key".

# Working WITH Caffeine (the concord procedure)
- The canister and the claim gallery are built by Caffeine AI inside the existing project "Lil Blunt Smoke Realm" (smokegame.win).
  Tools: `mcp__Caffeine__caffeine_chat_start_session / chat_tail / chat_list` (project id via `caffeine_list_projects`).
- Always send the contract from `docs/nft/NFT_CONTRACT.md` verbatim, ask for a DRAFT ("do NOT go live; the founder publishes"), and ask for the
  list of changed files and what it could not verify. Never publish for him. Never print or reuse the admin tokens that appear in chat history.
- When Caffeine returns the canister id + Candid, diff them against the contract. Any mismatch is fixed in the contract first, then both sides.
- Put the deployed canister id in `config.json` (`icp.nft_canister_id`) only after `GET /health` answers from the real canister.
- `icp network start` cannot run in this sandbox (see `.claude/context-manifests/icp.md`); local code can prove the client half
  (request body, reply validation, retry) but NOT the canister. Say so; do not claim end-to-end until a real draft canister has accepted a POST.

# Honest limits (say them, do not hide them)
Phase 1 issuance is client-reported (cosmetic, soulbound, no value). Before any NFT carries value, add server-verifiable proof (signed run events).
The canister must rate-limit per player_key and globally. CORS `Access-Control-Allow-Origin: *` is required for browser calls from itch.io.
