<!-- dispatched: deepseek/deepseek-v4-pro
     prompt: prompts/s3-deepseek-compliance-matrix.md
     files inlined: 2
     tokens: 3787 in / 2444 out
     cost: $0.0101
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
# COMPLIANCE MATRIX — PRE-FLIGHT CHECKLIST

All items: **NOT STARTED**. This matrix defines required PROOF, not current status.

---

## VAULT INTERIORS (T1: Diamond Vault, T2: Fort Knox)

| Item | Requirement | Proof Required (Falsifiable) | Status |
|------|-------------|------------------------------|--------|
| **T1-MULTI** | Multiple platforms/chambers, not single pit floor | ≥2 distinct `StaticBody2D` platform tiers with different Y coordinates exist in the vault scene, AND at least one is not the entry/exit floor. Count them. | NOT STARTED |
| **T1-HAZARD** | Protocol-appropriate hazards/guards | Diamond Vault: ≥1 entity type that can damage or obstruct the player (crystal sentry, energy field, spike) spawns inside vault bounds. Fort Knox: ≥1 entity type that can damage/obstruct (forge flame, security turret, pressure plate trap). Count distinct hazard types per vault. | NOT STARTED |
| **T1-INTERACT** | ≥2 interactable types beyond coin pile | Enumerate every `Area2D`/`StaticBody2D` with an interaction signal or `_on_body_entered` handler that isn't the coin scene. Diamond Vault must have ≥2 distinct types (e.g., `diamond_deposit_pillar` altar + breakable crystal cache). Fort Knox must have ≥2 distinct types (e.g., `goldmine_melt_forge` + lever or vault door interaction). List them. | NOT STARTED |
| **T1-LOOP** | Enter → explore/fight/collect → reward → exit | A gate script measures: (a) player can reach every platform tier from the entry point without void-death, (b) reward pickup triggers a visible/audible feedback before exit is used, (c) ladder climb-out succeeds without soft-lock. All three must pass. | NOT STARTED |
| **T1-EXIT** | Downward entry + upward exit, no soft-lock | Ladder `destructible = false` confirmed in vault scene. `top_exit_offset` lands on solid ground east of entry pit (not over void). Test: climb ladder 5× consecutively without `pit_death()` or stuck state. | NOT STARTED |
| **T1-IDENTITY** | Diamond Vault ≠ Fort Knox (not reskins) | Asset diff: Diamond Vault backdrop texture ≠ Fort Knox backdrop texture. Entity-type diff: at least ONE hazard type or interactable type is unique to each vault (not shared). List the unique-per-vault types. | NOT STARTED |
| **T1-KILLZONE** | No void death from vault interior geometry | Vault platforms at Y ≤ 825 (above kill zone band 825-1225). If any platform is at Y > 825, kill zone exclusion by x-range MUST be documented with explicit `kill_zone.gd` change proof. Without that change, any content at Y > 825 is an automatic gate FAIL. | NOT STARTED |
| **T1-BACKDROP** | Founder art backdrops used | `diamond_vault_backdrop.png` referenced in vault scene (ParallaxBackground or equivalent). `fort_knox_backdrop.png` referenced in Fort Knox vault scene. Check for texture resource path in .tscn. | NOT STARTED |
| **T1-DIAMOND-PROP** | `diamond_deposit_pillar.png` used as interactable | Sprite node referencing `res://assets/art/vaults/diamond_deposit_pillar.png` exists AND has an interaction handler (not just decoration). | NOT STARTED |
| **T1-FORT-PROPS** | `goldmine_melt_forge.png` + `fort_knox_vault_door.png` used | Both sprites appear in Fort Knox vault scene. Melt forge: either reused `melt_forge` entity type or new interactable. Vault door: visually anchors the scene (backdrop centerpiece or foreground anchor — decoration acceptable per prompt, but must be present). | NOT STARTED |

**KEEP list confirmation (no gate items):**
- Larger final boss scale: unchanged, not in scope.
- Downward entrance: stays, not redesigning entry method.
- Distinct from Blaze/Lounge: architecture not touched.

---

## STAGE 2 BOSS CHASE + CRYSTALS (T3)

| Item | Requirement | Proof Required (Falsifiable) | Status |
|------|-------------|------------------------------|--------|
| **T3-CHASE** | Boss closes distance while player kites in REAL arena | Automated test: spawn player at x=3800, boss at x=3700, player runs to x=4300 (max arena bound). Measure distance(player, boss) every frame for 10 seconds. Gate passes ONLY if distance decreases to <200px at least once (boss actually catches up). Arena bounds: 3700-4400, single floor y=650, NO floating platforms. Test must use `level_02_crystal_caverns` scene, not a minimal testbed. | NOT STARTED |
| **T3-PROJECTILES** | Crystal/shard projectiles spawn AND threaten player | Automated test: trigger boss fight, record every spawned projectile node (check for diamond/crystal/shards scene types). Gate passes if ≥1 projectile of type "crystal_shard" or equivalent spawns within 15 seconds AND at least one projectile trajectory intersects the player's position ±50px (actually aimed, not random noise). | NOT STARTED |
| **T3-ARENA-REAL** | Test in REAL Stage 2 arena, not idealized | Gate script MUST load `level_02_crystal_caverns.tscn` with its actual `BossTrigger` at x=3700, `BossSpawn` at (4050, 550), `boss_arena start_x=3700 end_x=4400`, and single ground segment `Vector4(3700, 650, 700, 70)`. If the test file substitutes a flat open plane, gate is INVALID regardless of pass/fail. | NOT STARTED |
| **T3-HONEST-GATE** | Gate is trustworthy (founder sees what gate proves) | Flag: headless gate cannot detect browser-only or cache-related failures. The prior "FIXED" claim passed its gate but failed founder's live test. THIS gate must include a MANUAL verification step: (1) run gate, (2) export, (3) hard-refresh browser, (4) confirm behavior matches gate result. Any discrepancy = gate untrustworthy, re-root-cause. | NOT STARTED |

**Why the last gate failed** (per founder prompt's own framing): prior fix raised `MIN_PURSUE_SPEED` and added crystal shards, then tested in a bounded arena without the real level's geometry, trigger zones, or arena bounds. A gate that tests in the real `level_02_crystal_caverns` scene is structurally more trustworthy — but gated headless tests still can't prove browser runtime behavior. The manual verification step is the only defense against that gap.

---

## STAGE 3 BOSS PRESSURE (T4)

| Item | Requirement | Proof Required (Falsifiable) | Status |
|------|-------------|------------------------------|--------|
| **T4-DPS-WINDOW** | Not always vulnerable; damage requires timing/positioning | Claim Jumper `take_damage()` MUST gain a state gate (e.g., only accepts damage during a VULNERABLE window or after a telegraphed attack miss, matching `auditor.gd`/`distributor.gd` pattern). If `take_damage()` still accepts damage in PATROL or THROW states with no condition, gate FAILS immediately. | NOT STARTED |
| **T4-TTK-FLOOR** | Fight not trivial under normal play | Automated simulation: perfectly optimal player (2.5 DPS axe, always hits when vulnerable, never dies) kills Claim Jumper (18 HP) in ≥15 seconds (i.e., vulnerability windows create forced downtime). If optimal TTK <10 seconds, gate FAILS (fight trivially short). Formula: 18 HP / 2.5 DPS = 7.2s of DPS uptime. Required downtime ≥7.8s spread across fight. | NOT STARTED |
| **T4-HIT-RATE** | Boss lands meaningful damage under normal play | Simulated "average" player (moves, occasionally hit) takes ≥1 hit during the fight. Gate: run 10 simulated fights with randomized player dodge patterns (70% dodge success rate). If 0 of 10 runs result in any player damage, fight is too easy — FAIL. | NOT STARTED |
| **T4-DYNAMITE** | Dynamite remains dodgeable but threatens | Existing fuse floor (1.3s) and visible warning ring must remain (already telegraphed, don't undo). Gate: confirm warning ring is drawn for full fuse duration AND explosion_radius=100 reaches positions a "kiting" player might occupy near the boss. If player can stand >150px from boss and never be in blast radius, FAIL (no pressure to reposition). | NOT STARTED |
| **T4-NO-LEDGE** | Pressure increase without reintroducing ledge suicide | Verify no `set_gravity_scale` or velocity spike sends boss off platform edges. Boss must stay within arena bounds (x-range check every frame during test). | NOT STARTED |

---

## PROCESS REQUIREMENTS

| Item | Requirement | Proof | Status |
|------|-------------|-------|--------|
| **MULTI-MODEL** | Fable + Grok + Kimi dispatched BEFORE large edits | `docs/model-responses/` contains ≥3 files dated this session: one each from Fable-5 (vault layout), Grok 4.5 (protocol identity), Kimi K3 (S2/S3 numbers). File timestamps precede T1-T4 commit. | NOT STARTED |
| **BUILD-ID** | Live build id published at end | `STATUS.md` or deploy log contains export build id. | NOT STARTED |
| **GATES-GREEN** | All T1-T4 automated gates pass + manual S2 verification done | Gate runner output shows all passes. Manual verification log for T3 signed. | NOT STARTED |

---

## SUMMARY: What "DONE" Actually Means Here

- **T1/T2**: Not "ladder+coins with a backdrop." Multiple tiers you can stand on, things that can hurt you, things you can interact with that aren't coins, and a reward you collect before climbing out. All above the kill zone.
- **T3**: Boss catches you in the real arena walls, shoots crystals that can hit you, and the gate tests that — PLUS a manual browser check because headless can't catch runtime bugs.
- **T4**: You can't just stand anywhere and spam axe. The boss has vulnerability windows, you take hits unless you're perfect, and the fight lasts long enough to feel like a fight.
- **Process**: Multi-model first. No soloing. Build id published.

All items currently **NOT STARTED**. No code has been written. Proceed to multi-model dispatch, then T1→T4 in order.