You are DeepSeek (`model-deepseek-compliance`). Build a compliance matrix.

DoD:
| H1 | SCORE/HUD solid black plate removed/translucent, stage art visible |
| H2 | Stage 3 figures visibly smaller on hard-refresh |
| H3 | Former "floating boxers" replaced with clear mine props, readable |
| H4 | big_axe pickup+throw larger AND more effective than normal axe |
| H5 | Former random load box is a mining interactable, visible reward+HUD impact |
| H6 | Path-blocking box removed; main path walkable |
| H7 | BTC logo on Stage 3 clear, not salt |
| M1 | Multi-model logs present (Kimi/Grok/Qwen/DeepSeek/B.AI or honest 403) |
| D1 | Gates + Security Sentinel green |

PLANNED WORK (root-caused from the founder's actual screenshots, extracted and
viewed directly this session):
- H1: HUDMask ColorRect (Color(0,0,0,1), 400x120) in all 3 level .tscn files
  removed. Rest of the stat list already has zero backing and reads fine.
- H2: TWO separate oversized elements found: (a) HUD stat-list font sizes
  (26-30px x ~10 lines, ~half the viewport) shrunk to 18-22px — confirmed via
  a cropped/enlarged look at the founder's circle, which traces the TEXT BLOCK
  not a sprite; (b) background art bg_l3_goldrush.jpg bakes a ~250px Bitcoin
  coin as the sun — shrinking in-place to ~55%.
- H3+H5 (same object): mine_cart.gd's `_setup_visual()` draws a bare untextured
  ColorRect ("Wood color" / "Gold armor") for the cart — confirmed root cause
  of "floating boxers". ALSO: `board_player()`/`unboard_player()` are defined
  but NEVER CALLED anywhere in the codebase (grepped, zero call sites) — the
  cart's wBTC reward is dead code. Fix: real generated art (gpt-5.4-image-2 via
  scripts/or-image.mjs) + wire an Area2D trigger to actually call board_player.
- H4: big_axe already scaled up in a prior session (throw 1.95x = ~78px vs
  normal ~9px, pickup 1.45x; damage 5 vs 1, boss damage 3 vs 1) and IS wired
  correctly (combat_handler.gd sets axe.big from GameManager.has_power_up).
  Founder says it's "still not making a difference" post that fix — plan is to
  push scale further AND add stronger hit feedback (bigger screenshake/impact
  flash) since the raw numbers already look large on paper.
- H6: timed_door.tscn has a leftover static ColorRect (0.8,0.3,0.1, 60x120)
  baked directly in the scene file that predates and duplicates the door
  script's own proper runtime-built visual — the confusing "box" is this
  orphaned dead node. Removing it.
- H7: wbtc.gd/coin_btc collision radii (15/22px) modestly enlarged for
  visibility; both sprites individually verified clean/legible at native res
  when viewed directly, so this is a scale, not an art-quality, issue.

Mark each PASS/PLANNED/RISK with the specific gate or evidence needed to close
it, and name the single highest-risk item (which one is most likely to still
read as "not fixed" after a hard refresh, and why).
