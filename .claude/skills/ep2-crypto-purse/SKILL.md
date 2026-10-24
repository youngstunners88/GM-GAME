---
name: ep2-crypto-purse
description: Lil Blunt's crypto purse - ETH, BTC, WBTC, SOL and TitanX collected through the game, shown in the weapon tab, spent per token at Rich's or anywhere (founder 2026-10-24). GameManager purse API, pickups, migration of old saves, shop tender, the PURSE strip, gate. TRIGGER on "purse", "wallet in the game", "coins and tokens", "pay with ETH/BTC/SOL/WBTC/TitanX", tender at a shop/stable, or the weapon tab's balances.
---

# The crypto purse

- API (`src/autoload/game_manager.gd`): `PURSE_TOKENS`, `PURSE_NAMES`, `purse_balance(t)`, `purse_add(t, n)`, `purse_spend(t, n)` (false + no debit when short/zero/unknown), signal `purse_changed`. eth/btc/sol live in `token_purse` (saved); wbtc = `GoldMineSystem.wbtc_balance`, titanx = `titanx_collected` (same counters, never copies).
- Credit: coin_eth/btc/sol.tscn `purse_token` -> `crypto_coin.gd` collect; `add_ethereum_ring` = +1 ETH.
- Holding, not run currency: a boss touch does not empty it; only a new game resets it.
- Old saves (`_load_purse`): no `token_purse` key -> the coin pool Rich used to take moves in ONCE, split evenly ETH/BTC/SOL (remainder BTC) - no face created or lost. Founder may change this rule.
- Spend: `GoldTownChamber.buy` -> `_spend(cost, tender)` / `_refund`; shop `TENDERS` = all five, left/right cycles and re-reads `purse_of`. `Ep2ArmoryState.ARMORY_TENDER` = all five.
- Tab: `Ep2WeaponSelector._draw_purse` (coin art per token; phone = count over name). Capture `tools/ep2_shots/purse_tab_shot.tscn`. Gate `tests/ep2_purse_test.tscn` (in CI).
- Economy rules (goldmine-economy-invariants): never mint, never negative, refund on refusal, no soft currency.
