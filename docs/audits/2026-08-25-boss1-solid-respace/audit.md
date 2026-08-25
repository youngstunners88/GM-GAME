# Boss 1 (Auditor) — "still phases the circled cyan block": everything solid via a re-spaced Level 1

**Date:** 2026-08-25
**Founder (live hard-refresh):** "The 1st boss STILL goes through the circled cyan block." Player must land on thick solids; spacing must work; boss must still chase.

## Why it was still phasing

The prior fix (removing runtime phasing) kept the boss solid against the **walls** but gave a **permanent collision exception to every OVERHEAD platform** (those above his grounded head). Floating platforms and breakable blocks share the same **cyan `tile_block-chain`** texture, so the boss visibly walked through the overhead cyan platforms — the founder circled one. Excepting anything cyan is therefore off the table: **all cyan must be solid.**

## The real constraint (measured + solver-proven)

Boss body 220×220, ground y=650 → grounded feet 650 / head 430. A platform is a WALL if its band reaches [430,650]; else OVERHEAD. To vault a wall the boss must rise to the wall top (450-500), so his body sweeps the 300-420 band — i.e. **through overhead-platform height**. With overhead solid, any overhead platform in a wall's swept column (`[wall.x, wall.x+w+220]`) is clipped, stalling the vault; and overhead pairs 1-219px apart wedge his 220px body.

A constraint solver over the real geometry confirmed the shipped level (8 platforms + 5 breakable blocks) **cannot** host a full-width solid boss — with the platforms fixed, only ~1 of 5 blocks fits clear. Multi-model input: **Grok 4.6** independently reached the same verdict — reject global one-way, reject permanent platform exceptions, resolve by **geometry** with a body-truth gate (its specific coordinates were invented/self-inconsistent and were NOT used). **Kimi K3** was dispatched twice but exhausted its output budget on reasoning without a visible answer; its role (geometry inventory) was covered by our own verified inventory + the solver.

## The fix — everything solid, minimal re-space (no collision tricks)

- **Removed the overhead exception** — the boss is now SOLID against every cyan rect. Measured ground-inside-a-wall: **0.0%** (no walk-through of anything).
- **Re-spaced Level 1** (solver-derived, keeps every Y so player jump heights are unchanged): P2 500→620, P5 1400→1420, P6 1700→1852; breakable blocks reduced/spaced to (1600,500),(2250,500),(2700,500). Every wall now has a ≥220 clear vault column and no wedge-gap overhead pair.
- The boss clears every wall with the existing SOLID sized jump; no phasing, no width toggle, no exception.

## Verification (headless real-physics)

| Gate | Result |
|---|---|
| `auditor_solid_wall_traverse` (body vs real walls) | PASS — ground-inside-wall **0.0%**, 76 blocked beats, gap 82 |
| `auditor_full_stage_hunt` | PASS — gap 85, no permanent pin |
| `auditor_no_sky_float` | PASS — max frozen 1.97s, sky 3.1% (<5% budget) |
| `auditor_no_runaway_climb` | PASS — 0 frames above screen |
| `player_solid_platform_land` (new coords) | PASS — lands on all 8 |
| `level1_return_path` | PASS |
| Boss 3 (claim_jumper) regression | (full suite) |

## Honest limits

- Breakable blocks reduced from 5 to 3 and 3 platforms nudged (≤152px, same heights). Player platforming preserved (land + return gates green); the level reads the same but a few cyan props moved. If the founder wants the exact old block layout back, it would require shrinking the boss or a larger redesign — flagged, not silently done.
- The boss spends ~3% of the fight briefly airborne above the top platform during vaults (within the 5% gate). Not a hover — it's the jump arc.
