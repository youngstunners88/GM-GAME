#!/usr/bin/env python3
"""GoldMine revenue model — stdlib only, deterministic, no network.

Purpose: turn the qualitative Phase 2 discussion into numbers a founder can argue
with. Every input is a named constant or a scenario field; change them and re-run.

NOTHING here is a forecast. Sources, and how much to trust them:
  * ALLOCATION   - docs/whitepapers/GoldMine.md (snapshot 2026-05-07). The live
                   GitBook's Stockpile page says 10% to liquidity vs 5% here, so the
                   snapshot is stale or the pages disagree. Verify on-chain.
  * POOL_*       - DexScreener pair for GOLD/WBTC, read through a summariser on
                   2026-10-05. Treat as a lead, re-pull before quoting.
  * SCENARIOS    - the author's assumptions. They are the thing to challenge.

Run:  python3 tools/goldmine-model/revenue_model.py
"""
from __future__ import annotations

from dataclasses import dataclass

# --- Whitepaper allocation of 100% of mining proceeds ------------------------
ALLOCATION = {
    "fort_knox_wbtc_rewards": 0.35,
    "gold_rush_auction_xaut": 0.25,
    "treasury_swf": 0.15,
    "diamond_burn": 0.10,
    "stockpile_lp": 0.05,
    "marketing": 0.03,
    "founder": 0.03,
    "build_cost": 0.03,
    "maintenance": 0.01,
}
PAID_TO_PARTICIPANTS = ALLOCATION["fort_knox_wbtc_rewards"] + ALLOCATION["gold_rush_auction_xaut"]
OPS_SHARE = sum(ALLOCATION[k] for k in ("marketing", "founder", "build_cost", "maintenance"))

# --- Observed market state (verify before quoting) ---------------------------
POOL_LIQUIDITY_USD = 8_325.0   # whole GOLD/WBTC pool, both sides
POOL_VOLUME_24H_USD = 0.79
GOLD_FDV_USD = 25_379.0


def impact(buy_usd: float, pool_total_usd: float) -> float:
    """Constant-product price move for a one-sided buy. Each side holds half."""
    side = pool_total_usd / 2.0
    return (1.0 + buy_usd / side) ** 2 - 1.0


@dataclass
class Scenario:
    name: str
    # Game: monthly active players, share who pay, average revenue per payer per month
    mau: int
    pay_conv: float
    arppu_usd: float
    game_share_to_swf: float          # published, fixed share of NET game revenue
    # Fee-earning liquidity (wBTC/PAXG, wBTC/XAUT, wBTC/ETH trio)
    fee_pool_tvl_usd: float
    daily_turnover: float             # volume / TVL per day
    fee_rate: float
    # Monthly mint inflow in USD (the number everything currently depends on)
    mint_inflow_usd_month: float
    # One-off Claims Office NFT sales (CAPITAL, not income)
    nft_sales_usd: float


SCENARIOS = [
    Scenario("Conservative", 1_500, 0.02, 6.0, 0.40, 20_000, 0.05, 0.003, 2_000, 15_000),
    Scenario("Base", 10_000, 0.03, 8.0, 0.40, 100_000, 0.10, 0.003, 10_000, 50_000),
    Scenario("Stretch", 50_000, 0.04, 10.0, 0.40, 500_000, 0.20, 0.003, 60_000, 150_000),
]

PLATFORM_FEE = 0.15   # app-store / payment-processor haircut on game revenue


def run(s: Scenario) -> dict:
    game_gross_m = s.mau * s.pay_conv * s.arppu_usd
    game_net_m = game_gross_m * (1 - PLATFORM_FEE)
    game_to_swf_m = game_net_m * s.game_share_to_swf
    fee_income_y = s.fee_pool_tvl_usd * s.daily_turnover * s.fee_rate * 365
    # Phase 2 gives 100% of PAXG/XAUT LP fees to NFT holders: it is the NFT buyer's
    # yield, so it is NOT protocol income. Reported separately.
    nft_holder_yield = fee_income_y / s.nft_sales_usd if s.nft_sales_usd else 0.0
    ops_m = s.mint_inflow_usd_month * OPS_SHARE
    paid_m = s.mint_inflow_usd_month * PAID_TO_PARTICIPANTS
    # External money available to top up participant pools each month.
    ext_m = game_to_swf_m
    payback_no_ext = PAID_TO_PARTICIPANTS
    payback_with_ext = (paid_m + ext_m) / s.mint_inflow_usd_month
    return {
        "game_gross_m": game_gross_m,
        "game_to_swf_m": game_to_swf_m,
        "fee_income_y": fee_income_y,
        "nft_holder_yield": nft_holder_yield,
        "ops_m": ops_m,
        "paid_m": paid_m,
        "ext_m": ext_m,
        "payback_no_ext": payback_no_ext,
        "payback_with_ext": payback_with_ext,
    }


def main() -> None:
    print("=== 1. Is mining +EV for the average miner? (whitepaper allocation) ===")
    print(f"Paid back to participants (35% Fort Knox + 25% auction): {PAID_TO_PARTICIPANTS:.0%}")
    print(f"Ops/marketing/founder/build/maintenance:                 {OPS_SHARE:.0%}")
    print(f"Treasury/SWF 15% + stockpile 5% + diamond burn 10% = 30% (not paid to miners)")
    print(f"Average miner gets back {PAID_TO_PARTICIPANTS:.0%} of ETH in pool value, BEFORE any GOLD price.")
    print("=> mining is a negative-sum purchase for the average miner. Winners: max-term + Melt")
    print("   stakers (they take share from everyone else). That is a tontine, not a yield product.")
    print()
    print("External top-up needed each month, as % of mint inflow, to reach a target payback:")
    for target in (0.70, 0.80, 0.90, 1.00):
        need = max(0.0, target - PAID_TO_PARTICIPANTS)
        print(f"  payback {target:.0%}: top-up = {need:.0%} of inflow")
    print()

    print("=== 2. Market state: can anyone exit? ===")
    print(f"GOLD FDV ${GOLD_FDV_USD:,.0f}; pool ${POOL_LIQUIDITY_USD:,.0f}; 24h volume ${POOL_VOLUME_24H_USD}")
    for buy in (100, 500, 1_000, 5_000):
        print(f"  ${buy:>5,} buy moves price {impact(buy, POOL_LIQUIDITY_USD):>7.0%}")
    print("Depth needed so that a $1,000 buy moves price <= 2%:")
    for tol in (0.02, 0.05):
        # (1+b/side)^2-1 = tol  ->  side = b/(sqrt(1+tol)-1); pool = 2*side
        side = 1000 / ((1 + tol) ** 0.5 - 1)
        print(f"  <= {tol:.0%}: pool depth ~ ${2 * side:,.0f}")
    print()

    print("=== 3. Scenarios: what could outside money look like? (ASSUMPTIONS, not forecasts) ===")
    hdr = f"{'':<13}{'game gross/mo':>14}{'->SWF/mo':>10}{'fees/yr':>10}{'NFT yield':>10}{'ops/mo':>9}{'payback':>9}{'w/ ext':>8}"
    print(hdr)
    for s in SCENARIOS:
        r = run(s)
        print(
            f"{s.name:<13}{r['game_gross_m']:>14,.0f}{r['game_to_swf_m']:>10,.0f}"
            f"{r['fee_income_y']:>10,.0f}{r['nft_holder_yield']:>10.0%}"
            f"{r['ops_m']:>9,.0f}{r['payback_no_ext']:>9.0%}{r['payback_with_ext']:>8.0%}"
        )
    print()
    print("Reading it: 'ops/mo' is the founder/ops cut of mint inflow (10%). 'payback' is the share of")
    print("mint ETH that returns to miners; 'w/ ext' adds the game's SWF share as a monthly top-up.")
    print("NFT yield = fee-trio fees / NFT presale (100% of PAXG/XAUT fees go to NFT holders).")
    print()

    print("=== 4. Revenue needed for a target ===")
    for monthly_ext in (1_000, 5_000, 20_000):
        for share in (0.40,):
            gross = monthly_ext / ((1 - PLATFORM_FEE) * share)
            players = gross / (0.03 * 8.0)
            print(f"  ${monthly_ext:>6,}/mo to SWF at {share:.0%} share needs ${gross:>8,.0f}/mo gross "
                  f"= ~{players:>7,.0f} MAU at 3% paying x $8")


if __name__ == "__main__":
    main()
