#!/usr/bin/env python3
"""Ecosystem reality check for SMOKE / DIAMONDS / GOLD (+ the BLAZE base) — stdlib only.

Three tests, each answering one question the captain's plan depends on:
  1. SCALE      How big is the whole ecosystem, and what can fees possibly pay?
  2. PROMISES   Can fee-backed NFT yields (Claims Office tiers) actually be funded?
  3. BUYERS     How many NEW buyers per month does an NFT-led plan need, and how fast
                does the existing community run out?

Sources / trust:
  * MARKET rows: DexScreener pulls read through a page summariser on 2026-10-05.
    Several returned oddities (a "Robinhood" chain for SMOKE, "SMOKE LOUNGE" as a quote
    token, a pair creation date in the future). TREAT AS LEADS; re-pull before quoting.
  * FEE_RATE assumed 0.3% (Uniswap v3 default tier). ETH_USD and the community figures
    are ASSUMPTIONS, marked below. Replace them with Rich's real numbers.

Run: python3 tools/goldmine-model/ecosystem_check.py
"""
from __future__ import annotations

# --- 1. Observed market scale (USD) -------------------------------------------
# token: (fdv, [pool liquidity ...], [24h volume ...])
MARKET = {
    "BLAZE":    (123_492, [10_392], [162]),
    "DIAMONDS": (72_646, [19_519, 6_571], [8.39, 8.29]),
    "GOLD":     (25_379, [8_326], [0.79]),
    "SMOKE":    (41_086, [6_993, 10_495, 3_051, 7_156, 2_418, 2_548, 2_055],
                 [69.19, 82.65, 15.21, 22.99, 122.58, 52.64, 81.75, 66.54]),
}
FEE_RATE = 0.003            # ASSUMPTION: 0.3% pool fee
ETH_USD = 3_000.0           # ASSUMPTION: set to spot before using any ETH-priced line

# --- 3. Community / funnel assumptions ------------------------------------------
ACTIVE_WALLETS = 300        # ASSUMPTION: engaged wallets across the 3 protocols (ask Rich)
EVER_BUY_SHARE = 0.30       # ASSUMPTION: share of them who would buy another NFT
GOLD_PANNER_ETH = 0.15      # GitBook, Claims Office
CERT_ETH = 0.028            # GitBook, Diamond Mine Certificate (permanent price)


def scale() -> None:
    print("=== 1. SCALE: the whole ecosystem, in dollars (leads, not facts) ===")
    tot_fdv = tot_liq = tot_vol = 0.0
    print(f"{'token':<10}{'FDV':>10}{'liquidity':>12}{'24h volume':>12}")
    for name, (fdv, liq, vol) in MARKET.items():
        print(f"{name:<10}{fdv:>10,.0f}{sum(liq):>12,.0f}{sum(vol):>12,.0f}")
        tot_fdv += fdv
        tot_liq += sum(liq)
        tot_vol += sum(vol)
    print(f"{'TOTAL':<10}{tot_fdv:>10,.0f}{tot_liq:>12,.0f}{tot_vol:>12,.0f}")
    fees_day = tot_vol * FEE_RATE
    print(f"\nLP fees across ALL of it at {FEE_RATE:.1%}: ${fees_day:.2f}/day = ${fees_day * 365:,.0f}/year")
    print(f"Daily volume as a share of liquidity: {tot_vol / tot_liq:.2%}  (healthy pools run 10%+)")
    print()


def promises() -> None:
    print("=== 2. PROMISES: can a fee-backed NFT yield be funded? ===")
    _, _, vols = zip(*MARKET.values())
    eco_vol_year = sum(sum(v) for v in vols) * 365
    sales = 50_000.0   # Claims Office presale target (GitBook)
    for y in (0.05, 0.10, 0.20):
        need_fees = sales * y
        need_vol = need_fees / FEE_RATE
        print(f"  {y:.0%} yield on ${sales:,.0f} sales = ${need_fees:>7,.0f}/yr of fees -> needs ${need_vol / 365:>10,.0f}/day of volume "
              f"= {need_vol / eco_vol_year:>5.1f}x the WHOLE ecosystem's current volume")
    gold_vol = sum(MARKET["GOLD"][2])
    print(f"  GOLD's own pool trades ${gold_vol:.2f}/day. A 10% yield needs ${sales * 0.10 / FEE_RATE / 365:,.0f}/day "
          f"= {sales * 0.10 / FEE_RATE / 365 / gold_vol:,.0f}x that.")
    print("  => Any NFT sold on a fee-share yield will under-pay, exactly like the Diamond Certificates.")
    print()


def buyers() -> None:
    print("=== 3. BUYERS: new wallets needed, and how fast the existing community runs out ===")
    price_panner = GOLD_PANNER_ETH * ETH_USD
    price_cert = CERT_ETH * ETH_USD
    print(f"Prices at ETH=${ETH_USD:,.0f} (ASSUMPTION): Gold Panner ${price_panner:,.0f}, Diamond Certificate ${price_cert:,.0f}")
    print("NFT sales needed per month to cover a monthly run-rate (ASSUMPTION: Rich supplies the real one):")
    for rr in (2_000, 5_000, 10_000):
        n_p = rr / price_panner
        n_c = rr / price_cert
        for conv in (0.01, 0.02):
            print(f"  run-rate ${rr:>6,}: {n_p:>5.1f} Gold Panners or {n_c:>5.0f} Certificates per month "
                  f"-> {n_p / conv:>7,.0f} qualified visitors/mo at {conv:.0%} conversion (Panner)")
    capacity = ACTIVE_WALLETS * EVER_BUY_SHARE * price_panner
    print(f"\nExisting community capacity: {ACTIVE_WALLETS} wallets x {EVER_BUY_SHARE:.0%} x ${price_panner:,.0f} = ${capacity:,.0f} ONCE.")
    for rr in (2_000, 5_000, 10_000):
        print(f"  at a ${rr:,}/mo run-rate that lasts {capacity / rr:.1f} months, then every sale must be a NEW wallet")
    print("=> NFT sales to the existing community fund a launch, not a business. The game's job is new wallets.")


if __name__ == "__main__":
    scale()
    promises()
    buyers()
