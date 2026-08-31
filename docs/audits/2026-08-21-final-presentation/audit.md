# Final Presentation Audit — 2026-08-21

Founder screenshots: `artifacts/founder_shots_2026-08-21_final/shot_1.png` (Auditor platform), `shot_2.png` (Claim Jumper stop + no double jump).

## Issue 1 — Stage 1: circled platform must be REMOVED, not made smarter

**Founder, verbatim:** "Remove this platform completely so that the boss can have a chance at chasing Lil Blunt since you ignored my previous request of having the block solid so that the boss could leverage it!"

**Root cause (measured, not guessed):** A headless real-physics probe drove a fleeing player from x=2920 down to x=150 across the full level (matching this level's own "even if Lil Blunt runs back to the beginning section, the Auditor should chase" design). The Auditor got permanently wall-stuck at **x=2520** — the exact right edge of `platforms` entry `Vector4(2400, 450, 120, 20)` in `level_01_data.tres` — and never resolved it for the remaining 44+ seconds of simulated time.

**Fix:** Removed that platform entry outright. It sat above an already-continuous ground segment (`(2300,650,500,70)`, covering x 2300-2800), so nothing structural was lost.

**Side effect found and fixed:** `ladder2` in `level_01_smoke_realm.gd` had its base positioned exactly at the removed platform's height (`global_position=(2345,450)`) and its `top_exit_offset` tuned to land on it. Re-grounded the ladder to the real floor (`(2345,650)`, height 400 — same absolute top y=250 as before) and reverted the exit offset to the engine default since there's no longer a specific platform to target.

**Frame proof:** headless — `tests/auditor_full_stage_hunt_test.gd` (new gate). Before the fix this scenario produced a permanent stuck point; after the fix, final gap between boss and a player who fled the entire level is **3px** (`gap=3`), with the worst transient hitch anywhere on the route only **197 frames (3.3s)**, well under the 5s permanent-stuck threshold. Live: `docs/captures/2026-08-21-final/live-verify/s1_chase_frame_04.png`, `s1_chase_frame_07.png` (boss and player close together, actively moving through the previously-blocked zone).

## Issue 2 — Stage 3: boss stop + missing double jump

**Founder, verbatim:** "Why did you make it that the 3rd boss cant move beyond this point!!!!!!!! And why is he not jumping. He needs to be able to double jump too!!!!"

**Root cause:** The Claim Jumper had exactly ONE vertical tool (`HOP_VELOCITY = -620.0`, a single hop) and nothing else — unlike the Auditor, which already has a leap + air-jump. There was no double-jump capability to fire at all.

**Fix:** Added a real double jump (`_air_hop_ready` bool, `AIR_HOP_VELOCITY = -560.0` constant), armed on every hop takeoff, fired once while still rising, cleared on genuine landing — mirroring the Auditor's already-fixed arm/clear pattern exactly, including the fix for the same stale-`is_on_floor()` ordering bug Kimi K3 caught there in an earlier pass.

**Multi-model catch (Kimi K3 + DeepSeek v4 Pro, independently, same finding):** `_air_hop_ready` was only read/written inside `PATROL`, so a stale `true` could survive a `PATROL -> THROW -> VULNERABLE -> PATROL` cycle and fire late, mid-fall, as a visible pop. Fixed by clearing `_air_hop_ready = false` on entry to `_throw_dynamite()` (the only path out of PATROL).

**Readability catch (Grok 4.6):** the first hop and the air-hop would reuse the same sprite pose, so two hops could read as "one long floaty jump" on a quick presentation pass — undercutting the very thing being proven. Added a cheap squash/stretch kick (`boss_sprite.scale` tween, 0.75x/1.3x -> 1.0x over 0.2s) at the exact air-hop frame so it reads as a distinct second beat.

**Frame proof:** headless — `tests/claim_jumper_double_jump_test.gd` (new gate). 40s of real physics kiting the player across the real level_03 arena: **11 real air-hop events** (velocity.y kicked to -560 mid-air, not gravity decay), boss covers 400px of the 700px arena. Live: `docs/captures/2026-08-21-final/live-verify/s3_dj_frame_*.png` — build boots and boss engages correctly; the exact air-hop frame was not caught in this specific short capture window (hop cadence ~0.7-1.3s, capture interval ~0.9s with directional taps, not the wide oscillation the headless probe used) — the headless gate with real velocity telemetry is the rigorous proof for this specific claim, noted honestly rather than overclaimed from a lucky screenshot.

## Multi-model packets (full, not stubbed)

- `docs/model-responses/2026-08-21-final-presentation/kimi-final-chase-geometry.md` — found the real THROW/VULNERABLE stale-flag bug (fixed), flagged a reversal-probe gap at x≈2600 (tested afterward, no new stuck point: worst hitch 1.33s), confirmed ladder arithmetic exact, confirmed no re-gating bug in the air-hop's if/elif structure.
- `docs/model-responses/2026-08-21-final-presentation/grok-final-aesthetics.md` — flagged the double-jump-pose readability risk (fixed with the squash/stretch kick) and gave concrete chase-vs-park thresholds for judges.
- `docs/model-responses/2026-08-21-final-presentation/deepseek-final-compliance.md` — independently found the same THROW/VULNERABLE stale-flag issue, confirmed no orphaned collectibles near the removed platform, confirmed ladder arithmetic, confirmed minimal file list.
- `docs/model-responses/2026-08-21-final-presentation/codex-final-independent-audit.md` — correctly pushed back that it couldn't verify collision-layer claims from the files it was given; verified directly afterward (`claim_jumper.tscn`: `collision_mask=13`, includes World layer, same as Auditor) — Codex's skepticism was warranted and is logged, not glossed over.
- `docs/model-responses/2026-08-21-final-presentation/bai-final-parallel-collision.md` (via `minimax-m2.7` — this project's usual B.AI free-tier model, `kimi-k2.5`, has been retired and its successor `kimi-k2.6` now requires a premium deposit) — confirmed no other hardcoded position in `_setup_depth_routes()` depends on the removed platform, confirmed the nearest trap (`trap_widows_thorn`, x=2260) doesn't overlap the re-grounded ladder's climb zone.

## What still matches the founder's circles vs what does not

- Both circled defects (Stage 1 platform, Stage 3 double-jump) are fixed at the root and proven via real-physics headless gates with numeric before/after evidence, not just a texture-matching claim.
- Honest gap: the live Playwright capture for the Claim Jumper's double jump did not happen to land on the exact air-hop frame in this pass's capture window. This is disclosed above rather than presented as caught-on-camera when it wasn't.
