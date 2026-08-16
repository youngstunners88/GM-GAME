# FOUNDER DIRECTIVE — Coordinate both sessions and finish remaining work

**Status**: Binding  
**Date**: 2026-08-16  
**Source**: Founder (Rich / youngstunners88)  
**Priority**: Immediate. Old subscription hit rate limit. New subscription is driving.

---

## VAULT MP3 FILES — AVAILABLE NOW (do not say they are missing)

| File | Size | MD5 |
|------|------|-----|
| `diamonds_are_forever.mp3` | 1,395,151 bytes | `175b1e7606c965be57614a815db822b8` |
| `goldmine.mp3` | 3,313,663 bytes | `5b4b92e9a3df88f54cf3783d35106be3` |

**Claude:** When the founder attaches these two files in this session, place them at:
- `src/assets/music/diamonds_are_forever.mp3`
- `src/assets/music/goldmine.mp3`

Then gate that they load, finish PR #35, deploy with butler **fresh** bytes.

Do **not** claim the files are missing from Drive/repo again without checking session attachments first.

---

## MANDATORY — Multi-model via OpenRouter (every session, no exceptions)

| Model | Via | Role |
|-------|-----|------|
| **Claude Code** | Lead | Owns commits, gates, STATUS, final code |
| **Kimi K3** (`moonshotai/kimi-k3`) | OpenRouter | Code verification, gates, residual sweeps |
| **Grok 4.5** | OpenRouter | Feel notes only if needed |

Solo Claude is not allowed. Evidence of dispatches in STATUS.

---

## Context both sessions must understand (do not redo finished work)

### Session A (old subscription — rate limited) — vault music code

- **Branch / PR**: `claude/vault-music-critical-fixes` → **Draft PR #35**
- **What landed in code**:
  - `vault_realm.gd` no longer plays parent stage themes (`level02_theme` / `level03_theme`)
  - Diamond Vault wired to `res://src/assets/music/diamonds_are_forever.mp3`
  - Fort Knox wired to `res://src/assets/music/goldmine.mp3`
  - Gate `crit_vault_music_test` asserts exclusive tracks and no parent themes
- **Do not re-implement the wiring.** Only place the MP3 files and finish the ship.

### Session B (new subscription — still active) — bosses, dialogue, pipeline

- **Branch**: `claude/critical-live-fails` (CI #185 green, butler shipped **17.18 MiB fresh data**)
- Claim Jumper VULNERABLE freeze fixed, Gideon E hint fixed, Assay Scale on-screen, `refill_run()` added, deploy pipeline unfrozen.
- **Do not re-open** unless hard-refresh still fails.

### Dual-session rule

Fetch master first. Named branches only. No force-push. Prefer sequential merges via PR.

---

## What is still open

### 1. Place the exclusive vault MP3s (top priority)

Founder attaches the two files this session. Place at:
- `src/assets/music/diamonds_are_forever.mp3`
- `src/assets/music/goldmine.mp3`

Gate load. Finish PR #35. Deploy with fresh butler bytes.

### 2. Confirm Smoke Lounge video after hard-refresh

Drive: https://drive.google.com/file/d/1H-Ob6SJQxgj2TvMLFPMQA3S48fIwZaBp/view?usp=sharing  
One-shot, full-screen cover, muted, lounge ambient continues.

### 3. Merge carefully — no clobber

### 4. Optional: browser capture of bosses on current live build

---

## Definition of Done

- [ ] OpenRouter multi-model used — evidence in STATUS
- [ ] Both MP3s under `src/assets/music/` with correct names
- [ ] Vaults play exclusive tracks (not parent themes, not silence)
- [ ] PR #35 finished / shipped
- [ ] Session B work not re-broken
- [ ] Video correct or fixed
- [ ] Butler ships **fresh** data (not 0 B)
- [ ] STATUS updated

---

## Prompt Claude must fulfill

```
FOUNDER DIRECTIVE ACTIVE — docs/founder-prompts/PROMPT_COORDINATE_BOTH_SESSIONS_FINISH.md

You are the driving session (new subscription). Old sub hit rate limit.

ACKNOWLEDGE — do not redo PR #35 wiring or critical-live-fails boss/pipeline work.

YOUR JOB:
1. OpenRouter multi-model required.
2. Founder is attaching diamonds_are_forever.mp3 and goldmine.mp3 — place them under src/assets/music/, gate load, finish PR #35, deploy fresh.
3. Confirm video after hard-refresh; fix only if still wrong.
4. Careful merge — no clobber.

Gates + STATUS + butler with fresh bytes.
```

End of directive.
