You are DeepSeek building a COMPLIANCE MATRIX for a Stage 3 cleanup against this
Definition of Done. For each item output: PASS / PARTIAL / FAIL / N-A + one line.

Planned changes:
- Reduce 5 floating melt forges (y=450-500, floating ~150px above y=650 ground,
  unreachable) to 2 forges placed ON the ground (origin.y~=608) near GOLD.
- Keep timed GoldGate+plate, Fort Knox vault door, Gold Rush Reserve, boss
  arena, secret walls (in pits), mine carts, all collectibles/enemies.
- Hammer/big_axe: pickup uses distinct art (sprite_item_bigaxe.png 40x44 @1.15);
  thrown big axe uses same art @ BIG_SCALE, currently 1.55 (~62px wide) vs the
  base thrown axe ~9px. Bump BIG_SCALE to ~1.9 for a more substantial throw,
  keep piercing + non-lethal-to-boss (BIG_BOSS_DAMAGE=3, boss HP 6-7).
- Palette already gold/orange/brown, no cyan on stage 3.

DoD:
1. Functionless/random blocks removed or given purpose; STATUS lists changes
2. Hammer pickup + throw both read substantial and distinct from pickaxe
3. Stage 3 palette reads Gold Rush (gold/steel/orange), not crystal
4. Main path walkable; gaps jump-legal; set-piece anchors intact
5. level-distinctness-checker does not FAIL
6. Multi-model evidenced
7. Gates + Security Sentinel green
8. Butler fresh data; founder hard-refresh
9. STATUS honest before/after
Output the matrix, then the single biggest risk in this plan.
