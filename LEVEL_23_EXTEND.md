# LEVEL 2 & 3 DEPTH EXTENSION — task #23 completed across all levels

Extends the L1 depth mechanics (`LEVEL_DEPTH.md`) to Crystal Caverns and
Gold Rush, themed per level. All global systems (adaptive difficulty,
snapshot moments, secret-wall payloads, analytics) apply automatically —
they live in `LevelBase`/`checkpoint.gd`/`secret_wall.gd`, so L2/L3 only
needed PLACEMENT, not re-implementation.

## Level 2 — Crystal Caverns (DIAMONDS-themed) 🎬/🎮

| Element | Placement | Theme tie |
|---|---|---|
| **Speedrunner route** | 5 crystal-cyan one-way platforms in a mirrored rise-and-fall arc (x 1050→1850) + coin trail | Mirror symmetry = the DIAMONDS reflection motif |
| **Vertical shafts** | 2 full-height ladders (350px @ x≈1420, 400px @ x≈3060) at the two deadliest drops | Cave verticality; escape routes per the heatmap pattern |
| **Explorer route** | 3 secret walls at pit edges (x 468 / 1968 / 3468) | Wallet holders: 20% Diamond Shards — extra on-theme here |
| **Casual route** | The authored floor route — untouched | — |
| Token spectacle | Distributor boss + shard payloads (existing DIAMONDS wiring) | — |

## Level 3 — Gold Rush (GoldMine-themed) 🎬/🎮

| Element | Placement | Theme tie |
|---|---|---|
| **Speedrunner route: the TIMED-GATE RUN** | Pressure plate (x 1180) starts a 4s clock on the GoldGate (x 1520, reuses `timed_door`); through it, a golden one-way lane (x 1700→2300) with a double coin trail | Gold rush = racing the clock for the richest seam |
| **Ladder** | 300px @ x≈1465 up to the gate approach | Escape from the cart run |
| **Explorer route** | 3 secret walls in the old diggings (x 868 / 2468 / 3068) | Referral codes read as claim stakes |
| **FORT KNOX VAULT** | Token-gated community room (x 3550, before the Claim Jumper arena) — `hall_of_blaze` pattern with `room_title = "— THE FORT KNOX VAULT —"` | GoldMine's Fort Knox staking, made a place |
| **Casual route** | Authored floor + mine carts — untouched | — |

## What carries over automatically (verify, don't rebuild)

- **Adaptive difficulty**: `LevelBase._ready()` → `DifficultyManager.refresh()`
  runs in every level; tax-scaling/boulder warnings/extra checkpoint/hint
  leaf all fire from the same per-player heatmap.
- **Snapshot moments**: every checkpoint in every level (`checkpoint.gd`).
- **Secret-wall payloads**: lore rotation, tips, referral codes, shard rolls —
  identical engine, new coordinates.
- **Analytics**: deaths/retries/completions attribute per level exactly as L1.

## Review trail

`gdparse` clean on all changed scripts; `scripts/kimi-review.sh` ran on both
level scripts — its one candidate finding (Node-typed member access after
`instantiate()`) was checked against reality and dismissed: the identical
pattern ships in L1 and was verified compiled + running in the exported build
(gameplay screenshot shows the placed ladder/one-ways). Browser verification
covers L1 boot-to-PLAYING; L2/L3 use the same LevelBase path and identical
scene-building calls.

Also in this batch: `MISTRAL_API_KEY2` failover tier added to the backend LLM
chain (both client keys validated live) — order is now Mistral #1 → Mistral #2
→ Kimi K3 → Grok.
