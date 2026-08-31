# FOUNDER DIRECTIVE — Live residuals: Stake CONFIRM + Assay Scale design + Boss chase

**Status**: Binding  
**Date**: 2026-08-16  
**Source**: Founder (Rich / youngstunners88)  
**For**: Claude Code on the **original / old subscription** (rate limits hit on the other sub — this file is the full handoff)

---

## How to use this file

1. `git fetch origin && git checkout master && git pull`
2. Read this entire document before editing anything
3. Work on a **named branch** (e.g. `claude/live-residuals-stake-assay-bosses`)
4. OpenRouter multi-model required (see below)
5. Deploy via butler when CI is green; hard-refresh itch before FIXED claims

**Repo:** `youngstunners88/GM-GAME`  
**Live:** https://youngstunners88.itch.io/lil-blunt-adventure  
**Engine:** Godot 4.3 · non-threaded HTML5 · $SMOKE / $DIAMONDS / $GOLD  
**Master after recent merges:** PR #35 (vault exclusive music + pipeline unfreeze) merged; live build has been shipping fresh butler data again

---

## MANDATORY — OpenRouter multi-model (every session, no exceptions)

| Model | Via | Role |
|-------|-----|------|
| **Claude Code** | Lead | Owns commits, gates, STATUS, final code |
| **Kimi K3** (`moonshotai/kimi-k3`) | OpenRouter | Stake/input flow, boss chase physics, gates |
| **Grok 4.5** (latest Grok on OpenRouter) | OpenRouter | Assay Scale layout, UX copy, pressure feel |

Solo Claude is not allowed. Log dispatches under `docs/model-responses/` and note them in STATUS.

---

## Full context (what already shipped — do not redo)

### Vault music (done)
- Diamond Vault → `res://src/assets/music/diamonds_are_forever.mp3` exclusively
- Fort Knox → `res://src/assets/music/goldmine.mp3` exclusively
- Parent stage themes removed from vaults
- Files placed; PR #35 merged; butler shipped fresh (~21 MiB)

### Deploy pipeline (done — critical)
- Root cause of “every fix still broken live” was a **frozen export**: CI preset had `#` comments Godot rejects → no pck → butler pushed 0 B fresh for many sessions
- Fixed: comment-free preset, pipefail + freshness gate, `index.pck` untracked so butler ships from disk
- **Do not regress this.** If butler reports 0 B fresh when you changed source, stop and fix export before claiming FIXED

### Claimed boss/dialogue/scale position work (partial — founder rejects live)
- Claim Jumper VULNERABLE freeze (vx=0 for ~0.9s) was patched to drift toward player
- Gideon hint text made honest per line (`[E] close` on last line)
- Assay Scale hall shifted left into camera bounds
- `GameManager.refill_run()` added for respawn crash

**Founder hard-refresh still fails on stake UX, Assay design, and boss chase/difficulty.** Treat those claims as incomplete until proven with browser captures / founder confirmation.

---

## Live fails (this session’s only job)

### 1. Staking never completes — nowhere to CONFIRM

**Founder (verbatim):**  
“I told you to fix this!!!! The process of staking never occurs! There’s nowhere to confirm!!!!”

**Screenshot evidence (Fort Knox / Gideon panel):**
- Dialogue line: “Hit CONFIRM and we’ll lock her down tight.”
- On-screen controls: **only** `[E] close` and `[ESC] leave`
- No CONFIRM button, no amount controls, no commit action

Gideon’s copy **promises CONFIRM**; the panel does not provide it. HUD says “Walk to an altar, press E to STAKE 25%” but the founder cannot complete a stake that feels confirmed.

**Required fix:**
1. **Diamond Vault (Mira):** Stake / Crush / **CONFIRM** controls must appear (after stepped dialogue if still used), be readable, and call real `GoldMineSystem` primitives so balances/shares change.
2. **Fort Knox (Gideon + altars + Assay):**
   - Either give Gideon a real stake/confirm path, **or**
   - Stop promising CONFIRM in dialogue and make the altar / Assay Scale path unmistakable (clear on-screen prompt, success float, HUD shares update).
3. **End-to-end gate:** enter vault → stake path → confirm → `GoldMineSystem` state mutates (shares or balances). Headless gate required.
4. Copy must never advertise a control that is not on screen.

Key files: `src/level/vault_realm.gd` (Mira clerk panel, Gideon panel, altars, assay), `GoldMineSystem` autoload.

---

### 2. Assay Scale design — text masking, scale too small

**Founder (verbatim):**  
“Why do you do such a cheap job with design! The text is masking each other! The scale is not that visibly clear so we need to make it distinct and larger in size. Improve the design as you have access to PIXELLAB_SECRET api key and MUAPI_API_KEY in environments”

**Screenshot evidence (Assay Hall, founder circled):**
- `ASSAY SCALE` / `[E] WEIGH GOLD` / `STAKED` / `RETURN` / numbers **overlap each other**
- Scale instrument is small and hard to read on the busy gold backdrop
- Labels fight environment art and EXIT / pool plates

**Required fix:**
1. Rebuild layout: **no overlapping labels**
2. Clear hierarchy: title → larger instrument → STAKED / RETURN values → interact hint
3. **Larger** scale art and value text (mobile-readable, black outline, min ~24px)
4. Distinct from mezzanine / EXIT / pool signage
5. Use **PIXELLAB_SECRET** and/or **MUAPI_API_KEY** from the environment if new scale art is needed — clarity over decoration
6. Position was already shifted on-screen; this is a **design** residual, not a camera residual

Key code: `_build_gold_scale`, Assay Scale setup in `vault_realm.gd` Fort Knox depth section.

---

### 3. Distributor + Claim Jumper still do not chase; Claim Jumper too easy

**Founder (verbatim):**  
“The 2nd and third bosses still dont fucking chase!!!!!!! … The third boss is now way too easy to defeat. We addressed this is you resolved it and now its back!”

**Required fix:**
1. **Distributor (Stage 2):** closes distance and pressures — prove with **real browser capture** on the **current** itch build
2. **Claim Jumper (Stage 3):** moves and chases — same browser capture requirement
3. **Difficulty:** Claim Jumper must not be a trivial kill. If VULNERABLE drift made him a punching bag, retune (chase speed, vulnerable window, damage, throw timing) so the fight still threatens
4. **Hard rule:** Headless-only gates have already failed this founder. No FIXED without browser capture or founder confirmation

Key files: distributor / claim_jumper boss scripts, level arena bounds, any warp `?boss=N` path.

---

## Definition of Done

- [ ] OpenRouter multi-model used (Claude + Kimi K3 + Grok 4.5) — evidence in STATUS
- [ ] Stake flow has real CONFIRM (or clear altar/assay commit) and mutates balances — gated
- [ ] Gideon/Mira copy never promises a control that is not on screen
- [ ] Assay Scale: no overlapping text; larger, distinct instrument + values
- [ ] PixelLab / MuAPI used if new scale art is required
- [ ] Distributor chase: browser capture on live itch build
- [ ] Claim Jumper chase: browser capture; fight not trivially easy
- [ ] Gates + Security Sentinel green
- [ ] Butler ships **fresh** data (not 0 B when source changed)
- [ ] STATUS.md honest — no FIXED without captures / founder confirmation

---

## Prompt Claude must fulfill (copy block)

```
FOUNDER DIRECTIVE ACTIVE — PROMPT_LIVE_RESIDUALS_STAKE_ASSAY_BOSSES.md

You are on the original Claude subscription. Full context is in this file — read it end to end.

Already shipped (do not redo): exclusive vault MP3s, deploy pipeline unfreeze (PR #35 era).

Live fails after hard-refresh:

1. STAKING — process never occurs; nowhere to CONFIRM. Gideon says “Hit CONFIRM” but UI only shows [E] close / [ESC] leave. Fix so stake can be confirmed and GoldMineSystem balances change. Gate it. Never promise a control that is not on screen.

2. ASSAY SCALE DESIGN — text masks itself; scale too small. Larger, distinct layout; zero overlap. Use PIXELLAB_SECRET / MUAPI_API_KEY if new art is needed.

3. BOSSES — Distributor + Claim Jumper still do not chase live. Claim Jumper now too easy. Fix + browser captures on current itch build. Headless-only is not enough.

OpenRouter multi-model required (Claude + Kimi K3 + Grok 4.5). Named branch. Gates + STATUS + butler with fresh bytes. No FIXED without captures.
```

End of directive.
