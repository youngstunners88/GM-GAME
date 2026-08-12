# FOUNDER PROMPT — Verify PR #22 live, then Diamond Vault + Fort Knox

**Baseline:** draft PR #22 / commit `aec2f82` (T1–T5: pixelation, jitter, L1 hitbox, S2 chase+crystals, final boss scale).  
**Always-ship:** merge to master **only after CI export/deploy is green**. Hard-refresh itch before any FIXED claims.

---

## MULTI-MODEL — MANDATORY EVERY SESSION

| Model | Role | Required |
|-------|------|----------|
| **Fable-5** | Lead implementer (set-pieces if Part B) | YES |
| **Grok 4.5** | Visual / layout audit | YES |
| **Kimi K3** | Collision / chase / entrance path numbers | YES |
| **DeepSeek** | Compliance matrix | YES |
| **Qwen** | Vision on founder screenshots if attached | If screenshots |
| **Claude** | Orchestrate, gates, STATUS, merge when CI green | YES — not sole designer |

Dispatch Fable + Grok + Kimi **before** large Part B edits. Log under `docs/model-responses/`.

---

## PART A — Close the loop on PR #22 (do first)

1. Confirm CI green on PR #22 (export + itch deploy). If red, fix CI only — do not start Part B.
2. Merge to master when green (always-ship).
3. **Hard-refresh** live build. STATUS: build id / export commit.
4. **Verification matrix** (code/gates + honest note if no human screenshot yet):

| Item | Expected |
|------|----------|
| T1 TAP OUT face | Sharp, not pixelated |
| T2 band art | Not jittery |
| T3 L1 boss | No death without contact |
| T4 S2 boss | Chases in real arena + crystal/shard attacks |
| T5 final boss | Larger + effective pressure |

5. If founder attaches **fail** screenshots after refresh → fix those only (narrow).  
   If founder is silent / confirms OK → Part A closed; proceed Part B.

**Do not reopen** claim-reset, TAP OUT label, BLAZE DIAMONDS naming, or TitanX-on-boss-death without new evidence.

---

## PART B — Diamond Vault (S2) + Fort Knox (S3) downward set-pieces

**Only after Part A is green (or founder explicitly prioritizes set-pieces).**

Load:
- `docs/founder-prompts/PROMPT_DIAMOND_VAULT_FORT_KNOX_DOWNWARD.md` (if present) **or** design docs for vault/knox
- Skill `gm-game-protocol-setpieces` if installed
- Current level 02 / level 03 scripts

### Locked design

| Stage | Protocol | Set-piece | Entrance |
|-------|----------|-----------|----------|
| **2 Crystal Caverns** | DIAMONDS | **Diamond Vault** | **Downward** crystal shaft / floor opening |
| **3 Gold Rush** | GOLD MINE | **Fort Knox** | **Downward** fortified hatch / vault shaft |

Rules:
- Set-pieces / strong hubs — **not** full stage wipes.
- Player **jumps or drops down** into the section. **Exit upward required** (no soft-lock).
- **Distinct** from Blaze Rush entry and Smoke Lounge entry (silhouette, VFX, interaction).
- Readable protocol identity: vault feels like DIAMONDS; Fort Knox feels like GOLD MINE.
- Min-viable: enter → readable interior → at least one protocol-flavored interactable/reward → exit back to stage route.
- Gates: can enter, can exit, no soft-lock; optional collectible/score hook if economy already supports it.

Prefer founder art if present; do not invent off-brand logos. Multi-model: Grok on readability, Kimi on entrance/exit collision paths, Fable on implementation.

---

## OUT OF SCOPE

Video, B.AI, Episode 2 full chapter, legal pages, DeFi category enable, undoing PR #22 without fail evidence.

---

## Definition of done

- PR #22 merged after green CI; live build id recorded.  
- Part A verification noted in STATUS.  
- If Part B run: both downward set-pieces enterable/exitable, distinct from Blaze/Lounge, gated.  
- Multi-model log present.  
- Deploy when code changes land.

**Start:** Check CI → merge if green → hard-refresh note → Part A matrix → Part B only if clear.
