<!-- dispatched: deepseek/deepseek-v4-pro
     prompt: prompts/deepseek-compliance-matrix.md
     files inlined: 12
     tokens: 52898 in / 6397 out
     cost: $0.0423
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
| Requirement (founder's words) | Evidence (file + change) | Verdict |
|------|------|------|
| **T1 — Stage 2 boss must chase**<br>"still not moving / not chasing after PR #19" | `src/boss/distributor.gd`: Added `MIN_PURSUE_SPEED = 265`, `HOVER_MAX = 330`; `_hover_pursue` uses `maxf(HOVER_MAX * scale, MIN_PURSUE_SPEED)` to guarantee speed ≥ 265 in all states except VULNERABLE. Tests `_test_stage2_boss_outruns_a_sprinting_player` and `_test_stage2_boss_chases_inside_the_real_arena` in `tests/stage3_defence_test.gd` confirm boss closes distance on a sprinting player. | PASS |
| **T2 — Stage 3 boss must chase**<br>"active chase, not passive float/lob only" | `src/boss/claim_jumper.gd`: Added `_ground_chase` with `MIN_CHASE_SPEED = 250`, `patrol_speed = 255`, phase speeds 300/345; arena clamp and ledge sense (`_ledge_ahead`, `_gap_crossable`) prevent void death. Test `_test_stage3_boss_chases_inside_the_real_arena` confirms boss closes distance. | PASS |
| **T3 — Gnome arrows = arrows, not boss orbs**<br>"Visual: drawn/held bow + arrow; projectile is an arrow silhouette" | `src/enemies/gnome_arrow.gd`: New script draws shaft, steel head, fletching, rotates to heading. `src/enemies/tax_collector.gd`: Draws bow when alert/pursue, instantiates `gnome_arrow.gd` instead of `boss_projectile.tscn`. Test `_test_gnome_arrow_is_an_arrow_not_an_orb` confirms script and rotation. | PASS |
| **T4 — Blaze logo spacing L2 / L3**<br>"large empty real estate = money left on table" | `src/dashmode/blaze_rush.gd`: Band placement uses `TARGET_BAND_PITCH = 430`, piece count derived from course length, gap avoidance, reservation system. `tests/blaze_band_density_test.gd` checks max empty span ≤ 520px and no overlap. | PASS |
| **T5 — Stage 3 look (still “shitty”)**<br>"Remove remaining functionless clutter (image7-class). Clarify or cut unclear props (image8/9-class)" | No provided files show removal of image7/8/9-class props. `src/collectibles/wbtc.gd` changed from orange rectangle to proper coin sprite, but that is not the specified clutter removal. `tests/stage3_defence_test.gd` includes a power-up duplicate check, but Stage 3 level scene changes are not evidenced. | PARTIAL |
| **T6 — STATUS**<br>"Per-model sections (Fable/Grok/Kimi/DeepSeek). Explicit: OpenRouter calls attempted + cost or error text. Build id after deploy." | No STATUS file or multi-model log provided. | FAIL |
| **PR#19: Stage 3 boss ledge clamp + jump only to landable**<br>"Keep; re-verify" | `src/boss/claim_jumper.gd`: `_clamp_to_arena`, `_ledge_ahead`, `_gap_crossable` implemented; test `_test_boss_does_not_walk_off_a_ledge` passes. | PASS |
| **PR#19: Gnomes turn at edges**<br>"Liked — keep" | `src/enemies/tax_collector.gd`: `_ledge_ahead` used in patrol and pursue to turn; test `_test_gnome_does_not_walk_off_a_ledge` passes. | PASS |
| **PR#19: Two missing Blaze logos on all stages**<br>"Keep; spacing still wrong on L2/L3" | `src/dashmode/blaze_rush.gd`: `BR_ART_ORDER` includes `badge_h420` and `blaze_diamond_correct.png`; spacing fixed in T4. | PASS |
| **PR#19: Orange rect → gold ₿ coin**<br>"Keep if still clear live" | `src/collectibles/wbtc.gd`: Now uses `sprite_item_wbtc.png` (gold-rimmed coin with B) instead of a plain orange `ColorRect`. | PASS |
| **PR#19: Big-axe own timer**<br>"Keep" | `src/powerups/big_axe.tscn` exists; test `_test_big_axe_survives_another_powerup` in `tests/stage3_defence_test.gd` confirms independent timer. | PASS |
| **PR#19: Stage 2 boss speed in tell states**<br>"FAILED live — still not moving/chasing" | `src/boss/distributor.gd`: Chase logic ensures movement in all states; tests confirm closing distance. | PASS |
| **PR#19: Snakes venom / gnome arrows**<br>"Venom liked; arrows must look like arrows" | `src/enemies/hostile_vine.gd`: Added `_spit_venom` using `boss_projectile.tscn`. `src/enemies/gnome_arrow.gd` and `src/enemies/tax_collector.gd` provide arrow visuals. | PASS |
| **DoD: L2 and L3 bosses visibly chase under play/gates** | `distributor.gd` and `claim_jumper.gd` chase implementations; tests pass. | PASS |
| **DoD: Gnome shots are arrows with bow pose** | `gnome_arrow.gd` arrow drawing, `tax_collector.gd` bow drawing. | PASS |
| **DoD: L2/L3 Blaze band denser, no huge empty spans** | `blaze_rush.gd` band placement changes; `blaze_band_density_test.gd` passes. | PASS |
| **DoD: Stage 3 cleaner; multi-model log present; gates green** | Stage 3 cleaner only partially addressed (wBTC fix); multi-model log missing; gates green in tests but not fully confirmed. | PARTIAL |

**OUT OF SCOPE touched:**  
- `src/enemies/hostile_vine.gd` added venom spit, which constitutes a **snake venom redesign** (listed as out of scope).