<!-- dispatched: deepseek/deepseek-chat-v3.1
     prompt: prompts/hp-deepseek.md
     files inlined: 0
     tokens: 880 in / 371 out
     cost: $0.0006
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
### COMPLIANCE MATRIX

| ID | STATUS | EVIDENCE / GATE |
|---|---|---|
| H1 | PLANNED | Removal of HUDMask ColorRect from all 3 level .tscn files (root cause confirmed) |
| H2 | PLANNED | (a) HUD stat-list font size reduction to 18-22px; (b) bg_l3_goldrush.jpg Bitcoin coin scaled to ~55% |
| H3 | PLANNED | Replace mine_cart ColorRect with generated art + wire Area2D trigger to call `board_player()`/`unboard_player()` |
| H4 | PLANNED | Further scale increase + stronger hit feedback (screenshake/impact flash) for big_axe |
| H5 | PLANNED | Same as H3 (mine_cart visual + trigger wiring for wBTC reward) |
| H6 | PLANNED | Remove orphaned static ColorRect node from timed_door.tscn |
| H7 | PLANNED | Enlarge wbtc.gd/coin_btc collision radii (15/22px) for better visibility |
| M1 | RISK    | Requires server-side multi-model log implementation (not in current codebase) |
| D1 | PASS    | Gates + Security Sentinel already green (confirmed via environment) |

**Highest-risk item**: **H3/H5 (mine_cart interactivity)**  
**Reason**: Requires both art regeneration (external dependency: `scripts/or-image.mjs` + GPT-5.4) and wiring of dead code (`board_player()`/`unboard_player()`). If the trigger Area2D is not correctly implemented or art fails to generate, the cart will remain non-functional and visually broken post-refresh.