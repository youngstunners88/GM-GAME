#!/usr/bin/env python3
"""GoldMine stock-and-flow simulation — stdlib only, deterministic.

Question it answers: which levers actually move GoldMine's income, and does a
rule-based policy beat the status quo? It is NOT a forecast. Every behavioural
number below is an assumption, marked ASSUMPTION, and exists to be challenged.

Structure (monthly):
  audience  = game players who visit the mining app + ecosystem/organic visitors
  attract   = exit_factor(depth) * value_factor(payback)        (0..1)
  mints     = audience * conversion * attract * ticket
  external  = game net revenue * share + LP fees on depth + yield on reserve
  policy    = how the treasury splits money between depth, staker top-ups, reserve

Run: python3 tools/goldmine-model/system_sim.py
"""
from __future__ import annotations

from copy import deepcopy
from dataclasses import dataclass, field

MONTHS = 24

# Whitepaper allocation of mint proceeds (snapshot; verify on-chain).
PAID_BACK = 0.60        # 35% Fort Knox + 25% auctions
OPS_CUT = 0.10          # marketing + founder + build + maintenance
TREASURY_CUT = 0.15
LP_CUT = 0.10           # live Stockpile page says 10%, whitepaper says 5%


@dataclass
class P:
    # --- audience (ASSUMPTION: no real player numbers are published) ---
    game_mau0: float = 2_000
    game_growth: float = 0.08        # monthly MAU growth
    funnel: float = 0.03             # share of game players who visit the mining app per month
    organic: float = 500             # ecosystem/organic visitors per month
    # --- conversion (ASSUMPTION) ---
    base_conv: float = 0.04          # visitor -> minter at perfect exit + value
    ticket: float = 400.0            # USD per mint
    depth_half: float = 80_000       # depth at which exit_factor = 0.5
    # --- game monetisation (ASSUMPTION) ---
    storefront: bool = True
    pay_conv: float = 0.03
    arppu: float = 8.0
    platform_fee: float = 0.15
    game_share: float = 0.40
    # --- assets ---
    depth0: float = 8_300            # observed GOLD/WBTC pool (re-pull before quoting)
    fee_rate: float = 0.003
    turnover: float = 0.05           # daily volume / depth (ASSUMPTION)
    asset_yield: float = 0.03        # annual yield on reserve (ASSUMPTION)
    # --- policy ---
    presale_to_depth: float = 0.0    # share of a $50k presale put into depth (month 2)
    ops_share_ext: float = 0.30      # share of external income funding operations
    top_up: bool = False
    depth_first: bool = False
    depth_target: float = 200_000
    run_rate: float = 10_000         # ASSUMPTION: monthly cost to run the whole effort
    # Track record: share of past payout promises that were kept. The Diamond
    # Certificates under-paid (captain, 2026-10-05), so buyers discount every new
    # product. ASSUMPTION: starts at 0.5; recovers only when a published funding
    # ledger shows promises being met.
    trust0: float = 0.5
    trust_recovery: float = 0.0      # per month, added while the ledger policy is on


def run(p: P) -> list[dict]:
    depth, reserve = p.depth0, 0.0
    topup_hist: list[float] = []
    mint_hist: list[float] = []
    rows = []
    for t in range(1, MONTHS + 1):
        mau = p.game_mau0 * (1 + p.game_growth) ** t
        audience = mau * p.funnel + p.organic
        # Payback seen by miners: mint-funded 60% plus recent externally funded top-ups.
        recent_t = sum(topup_hist[-3:]) / max(1, len(topup_hist[-3:]))
        recent_m = sum(mint_hist[-3:]) / max(1, len(mint_hist[-3:])) if mint_hist else 1.0
        payback = min(1.0, PAID_BACK + (recent_t / recent_m if recent_m > 1 else 0.0))
        exit_f = depth / (depth + p.depth_half)
        value_f = min(1.0, payback / 0.90) ** 2
        trust = min(1.0, p.trust0 + p.trust_recovery * t)
        mints = audience * p.base_conv * exit_f * value_f * trust * p.ticket

        game_net = (mau * p.pay_conv * p.arppu * (1 - p.platform_fee)) if p.storefront else 0.0
        game_to_pool = game_net * p.game_share
        lp_fees = depth * p.turnover * p.fee_rate * 30
        reserve_yield = reserve * p.asset_yield / 12
        external = game_to_pool + lp_fees + reserve_yield

        ops_income = OPS_CUT * mints + p.ops_share_ext * external
        treasury_in = (1 - p.ops_share_ext) * external + TREASURY_CUT * mints
        depth += LP_CUT * mints
        if t == 2:
            depth += 50_000 * p.presale_to_depth

        # Waterfall governor: depth first until target, then top-ups and reserve.
        if p.depth_first and depth < p.depth_target:
            to_depth, to_top, to_res = 0.60, 0.20, 0.20
        elif p.depth_first:
            to_depth, to_top, to_res = 0.10, 0.50, 0.40
        else:
            to_depth, to_top, to_res = 0.0, 0.0, 1.0
        depth += treasury_in * to_depth
        topup = treasury_in * to_top if p.top_up else 0.0
        reserve += treasury_in * to_res + (treasury_in * to_top - topup)
        topup_hist.append(topup)
        mint_hist.append(mints)

        payouts = PAID_BACK * mints + topup
        rows.append({
            "t": t, "mints": mints, "external": external, "ops_income": ops_income,
            "depth": depth, "payback": payback, "payouts": payouts,
            "erc": external / payouts if payouts > 1 else float("nan"),
            "mau": mau,
        })
    return rows


STATUS_QUO = P(storefront=False, funnel=0.01, depth_first=False, top_up=False, presale_to_depth=0.0)
# My reading of the captain's stated plan: sweeper bots (they move ETH between pots, they do
# not create it) then 100% focus on NFT sales. Storefront on, nothing else changes.
CAPTAIN_PLAN = P(storefront=True, funnel=0.01, depth_first=False, top_up=False, presale_to_depth=0.0)
SYSTEM = P(storefront=True, funnel=0.03, depth_first=True, top_up=True, presale_to_depth=0.6,
           trust_recovery=0.03)


def first_month(rows: list[dict], threshold: float) -> str:
    for r in rows:
        if r["ops_income"] >= threshold:
            return f"month {r['t']}"
    return "not in 24 mo"


def report(name: str, p: P) -> None:
    r = run(p)
    last = r[-1]
    print(f"  {name:<12} mints/mo ${last['mints']:>8,.0f} | external/mo ${last['external']:>7,.0f} | "
          f"operating income/mo ${last['ops_income']:>7,.0f} | depth ${last['depth']:>9,.0f} | "
          f"covers run-rate: {first_month(r, p.run_rate)}")


def main() -> None:
    print("=== Policy vs status quo, by how fast the game audience grows ===")
    for label, g in (("slow 3%/mo", 0.03), ("base 8%/mo", 0.08), ("fast 15%/mo", 0.15)):
        print(f"Game audience growth {label} (start {STATUS_QUO.game_mau0:,.0f} MAU):")
        a, c, b = deepcopy(STATUS_QUO), deepcopy(CAPTAIN_PLAN), deepcopy(SYSTEM)
        a.game_growth = c.game_growth = b.game_growth = g
        report("status quo", a)
        report("captain plan", c)
        report("system", b)
    print()

    print("=== Sensitivity: base case, month-24 operating income, each input +/-50% ===")
    base = run(SYSTEM)[-1]["ops_income"]
    print(f"Baseline operating income/mo: ${base:,.0f}")
    knobs = ["game_mau0", "game_growth", "funnel", "organic", "base_conv", "ticket",
             "depth_half", "pay_conv", "arppu", "game_share", "turnover", "trust0"]
    rows = []
    for k in knobs:
        out = []
        for mult in (0.5, 1.5):
            q = deepcopy(SYSTEM)
            setattr(q, k, getattr(q, k) * mult)
            out.append(run(q)[-1]["ops_income"])
        rows.append((k, out[0], out[1], abs(out[1] - out[0])))
    for k, lo, hi, swing in sorted(rows, key=lambda x: -x[3]):
        print(f"  {k:<12} -50% -> ${lo:>7,.0f}   +50% -> ${hi:>7,.0f}   swing ${swing:>7,.0f}")
    print()

    print("=== What audience is needed? Starting game MAU that covers the run-rate by month 24 ===")
    print("(run-rate = monthly cost of the whole effort; ASSUMPTION, Rich must supply the real figure)")
    for run_rate in (2_000, 5_000, 10_000):
        for g in (0.03, 0.08, 0.15):
            lo, hi = 100.0, 5_000_000.0
            for _ in range(60):
                mid = (lo + hi) / 2
                q = deepcopy(SYSTEM)
                q.game_growth, q.game_mau0 = g, mid
                if run(q)[-1]["ops_income"] >= run_rate:
                    hi = mid
                else:
                    lo = mid
            print(f"  run-rate ${run_rate:>6,}/mo, growth {g:.0%}/mo: need ~{hi:>8,.0f} starting MAU "
                  f"(=> {hi * (1 + g) ** MONTHS:>9,.0f} by month 24)")
    print()

    print("=== Track record: cumulative 24-month operating income, base growth ===")
    print("(trust starts at 0.5 after the Diamond Certificate shortfall; recovers only with a published funding ledger)")
    for label, rec, t0 in (("no recovery", 0.0, 0.5), ("ledger, +0.03/mo", 0.03, 0.5), ("never burned", 0.0, 1.0)):
        q = deepcopy(SYSTEM)
        q.trust_recovery, q.trust0 = rec, t0
        r = run(q)
        print(f"  {label:<18} cumulative ${sum(x['ops_income'] for x in r):>8,.0f}   cumulative mints ${sum(x['mints'] for x in r):>9,.0f}")
    print()

    print("=== Exit first? Same system, depth program on vs off (base growth) ===")
    for label, flag in (("depth-first ON", True), ("depth-first OFF", False)):
        q = deepcopy(SYSTEM)
        q.depth_first = flag
        q.presale_to_depth = 0.6 if flag else 0.0
        r = run(q)[-1]
        print(f"  {label:<16} mints/mo ${r['mints']:>7,.0f}  depth ${r['depth']:>9,.0f}  operating income/mo ${r['ops_income']:>7,.0f}")


if __name__ == "__main__":
    main()
