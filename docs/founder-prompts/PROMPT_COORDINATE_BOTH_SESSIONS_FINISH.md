# FOUNDER DIRECTIVE — Coordinate both sessions and finish remaining work

**Status**: Binding  
**Date**: 2026-08-16  
**Source**: Founder (Rich / youngstunners88)  
**Priority**: Immediate. Old subscription hit rate limit. New subscription is driving.

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
- **Honest blocker they hit**: the two MP3 **files** were not in the repo, git history, uploads, or Drive at the time. Wrong parent-theme music is **gone**; vaults will be **silent** until the files are placed.
- **Do not re-implement the wiring.** It is already in PR #35. Only place the files and finish the ship.

### Session B (new subscription — still active) — bosses, dialogue, pipeline

- **Branch**: `claude/critical-live-fails` (CI #185 green, butler shipped **17.18 MiB fresh data**)
- **What landed and is live on itch** (after hard-refresh):
  - Claim Jumper VULNERABLE freeze fixed (was motionless ~65% of cycle) — drifts toward player
  - Gideon dialogue hint honest per line (`[E] close` on final line)
  - Assay Scale shifted fully inside camera bounds
  - `GameManager.refill_run()` added (respawn crash)
  - **Deploy pipeline unfrozen**: CI export no longer masks failures; `#` comments stripped from generated preset; oversized `index.pck` untracked so butler ships fresh bytes
- **Do not re-open boss chase / E / scale / pipeline** unless a hard-refresh playtest still fails. Prove with capture if claiming FIXED again.

### Dual-session rule

- Fetch master first. Named branches only. No force-push.
- Prefer sequential merges via PR.
- If both touch the same file, STATUS-note and coordinate — do not clobber.

---

## What is still open (this session’s job)

### 1. Place the exclusive vault MP3s (top remaining priority)

Founder has the files. They must land at:

| File | Target path |
|------|-------------|
| `Diamondsareforever.mp3` | `res://src/assets/music/diamonds_are_forever.mp3` |
| `Goldmine.mp3` | `res://src/assets/music/goldmine.mp3` |

**How to get them**: Founder will attach them in this Claude session (or drop them in Drive). Once present:

1. Copy into `src/assets/music/` with the exact names above.
2. Confirm PR #35 wiring still points at those paths (or rebase PR #35 onto current work).
3. Gate that the files exist and load (ResourceLoader / AudioStream).
4. Deploy via butler so vaults are no longer silent.

Wrong parent-theme music is already removed by PR #35. Do not put level02/level03 themes back.

### 2. Confirm / finish Smoke Lounge video

After hard-refresh: if the video aspect is still wrong or it loops, replace with the founder Drive clip:

https://drive.google.com/file/d/1H-Ob6SJQxgj2TvMLFPMQA3S48fIwZaBp/view?usp=sharing  

One-shot, full-screen cover, muted, lounge ambient continues.

### 3. Merge order (when green)

Suggested order once MP3s are in and video is confirmed:

1. Land vault-music files + finish PR #35 (or equivalent commit on a named branch).
2. Merge / rebase `claude/critical-live-fails` gameplay + pipeline fixes to master if not already reflected on the live itch build you care about.
3. STATUS honest: what is live, what still needs founder hard-refresh confirmation.

### 4. Optional but preferred

Live browser capture of Distributor + Claim Jumper on the **current** itch build (post-pipeline-fix). Headless alone has already failed this founder many times.

---

## Definition of Done

- [ ] OpenRouter multi-model used (Claude + Kimi + Grok) — evidence in STATUS
- [ ] `diamonds_are_forever.mp3` and `goldmine.mp3` present under `src/assets/music/`
- [ ] Vaults play exclusive tracks (not parent themes, not silence)
- [ ] PR #35 (or equivalent) merged / shipped; no duplicate rewiring
- [ ] Session B boss/dialogue/scale/pipeline work not re-broken
- [ ] Smoke Lounge video correct after hard-refresh (or fixed)
- [ ] Gates green; butler ships **fresh** data (not 0 B)
- [ ] STATUS.md updated with dual-session acknowledgment
- [ ] Founder can hard-refresh itch and hear correct vault music

---

## Prompt Claude must fulfill

```
FOUNDER DIRECTIVE ACTIVE — docs/founder-prompts/PROMPT_COORDINATE_BOTH_SESSIONS_FINISH.md

You are the driving session (new subscription). Old sub hit rate limit.

ACKNOWLEDGE — do not redo:
- PR #35 / claude/vault-music-critical-fixes: exclusive track WIRING already done; parent themes removed. Only the MP3 FILES were missing.
- claude/critical-live-fails: Claim Jumper VULNERABLE freeze, Gideon E hint, Assay Scale, refill_run, deploy pipeline unfrozen — already fixed and shipped with fresh butler data. Do not reopen unless hard-refresh still fails.

YOUR JOB:
1. OpenRouter multi-model required (Claude + Kimi K3 + Grok 4.5).
2. Place Diamondsareforever.mp3 → res://src/assets/music/diamonds_are_forever.mp3 and Goldmine.mp3 → res://src/assets/music/goldmine.mp3 (founder will attach or provide). Gate that they load.
3. Finish ship of vault music (PR #35 or rebase) so vaults are not silent.
4. Confirm Smoke Lounge video after hard-refresh; fix only if still wrong (Drive link in prompt).
5. Merge order careful — no clobber of the other session’s work.
6. Optional: browser capture of bosses on current live build.

Gates + STATUS + butler with fresh bytes. No FIXED claims without proof.
```

End of directive.
