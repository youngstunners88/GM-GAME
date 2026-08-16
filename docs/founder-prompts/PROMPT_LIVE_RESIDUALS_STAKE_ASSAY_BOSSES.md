# FOUNDER DIRECTIVE — Live residuals after PR #35 merge

**Status**: Binding  
**Date**: 2026-08-16  
**Source**: Founder (Rich / youngstunners88)  
**Priority**: Immediate. Hard-refresh playtest after the “everything is live” claim.

---

## MANDATORY — OpenRouter multi-model every session

| Model | Via | Role |
|-------|-----|------|
| **Claude Code** | Lead | Commits, gates, STATUS |
| **Kimi K3** | OpenRouter | Stake/input flow, boss chase physics |
| **Grok 4.5** | OpenRouter | Assay/scale layout feel, UX copy |

Solo Claude banned. Evidence in STATUS.

Do **not** reopen vault music wiring or the deploy-pipeline fix unless butler is shipping 0 B again. Those were claimed shipped. This prompt is only the live fails below.

---

## Founder evidence (screenshots + text)

### 1. Staking never completes — nowhere to CONFIRM

Founder: “The process of staking never occurs! There’s nowhere to confirm!!!!”

**Screenshot (Fort Knox / Gideon):**
- Dialogue: “Hit CONFIRM and we’ll lock her down tight.”
- Visible controls: only `[E] close` and `[ESC] leave`
- **No CONFIRM button. No stake amount UI. No commit action.**

Gideon’s copy promises CONFIRM; the panel does not provide it. Altars say “press E to STAKE 25%” but the founder cannot complete a stake flow that feels confirmed.

**Required:**
- Diamond Vault (Mira): stake / crush / **CONFIRM** must be visible, tappable, and actually call `GoldMineSystem` primitives so balances change. If dialogue is still stepping, CONFIRM only after the last line — but CONFIRM must exist and work.
- Fort Knox (Gideon + altars + Assay): either give Gideon a real confirm/stake path **or** stop promising CONFIRM in dialogue and make the altar / Assay Scale path unmistakable (clear prompt, clear result float, shares update on HUD).
- End-to-end: player can enter vault → choose amount or use 25% altar/assay → **confirm** → see shares/balance change. Headless gate that proves a stake mutates `GoldMineSystem` state.

### 2. Assay Scale design — text masking, scale too small

Founder: “Why do you do such a cheap job with design! The text is masking each other! The scale is not that visibly clear so we need to make it distinct and larger in size.”

**Screenshot (Assay Hall):**
- `ASSAY SCALE` / `[E] WEIGH GOLD` / `STAKED` / `RETURN` / numbers all overlap
- Scale instrument is small and hard to read against the busy backdrop
- Labels fight the environment art

**Required:**
- Rebuild Assay Scale UI layout: no overlapping labels; clear hierarchy (title → instrument → STAKED/RETURN values → interact hint)
- **Larger** scale art and value labels (mobile-readable, outlined)
- Distinct visual separation from the mezzanine / EXIT / pool plates
- Use **PIXELLAB_SECRET** and/or **MUAPI_API_KEY** (in environment) if new art is needed for a clearer scale instrument — do not invent a muddy reskin; improve clarity
- Same readability standard as vault labels (min ~24px + black outline)

### 3. 2nd boss (Distributor) and 3rd boss (Claim Jumper) still do not chase

Founder: “The 2nd and third bosses still dont fucking chase!!!!!!!”  
Also: “The third boss is now way too easy to defeat. We addressed this is you resolved it and now its back!”

Claimed fixed with VULNERABLE drift + real-level gates. Live playtest rejects it again.

**Required:**
- Distributor closes distance and pressures in a **real browser** capture on the **current** itch build (not headless-only)
- Claim Jumper moves/chases in a real browser capture on the current itch build
- Claim Jumper difficulty: restore real pressure (not a trivial kill). If VULNERABLE drift made him a punching bag, retune so chase + damage + timing still threaten — founder said he is **too easy** now
- Hard rule: no FIXED without browser capture (or founder confirmation). Headless gates have already failed this founder.

---

## Do not redo (already claimed shipped)

- Exclusive vault MP3s (`diamonds_are_forever.mp3` / `goldmine.mp3`)
- Deploy pipeline (pipefail, comment-free preset, untracked pck)
- Gideon “E closes on last line” hint text alone (insufficient — CONFIRM path is the real gap)
- Assay Scale only shifted left (position fixed; **design** still fails)

---

## Definition of Done

- [ ] OpenRouter multi-model used — evidence in STATUS
- [ ] Stake flow has a real CONFIRM (or clear altar/assay commit) and mutates balances — gated
- [ ] Gideon/Mira copy never promises a control that is not on screen
- [ ] Assay Scale: no overlapping text; larger, distinct instrument + values
- [ ] PixelLab / MuAPI used if new scale art is required
- [ ] Distributor chase proven in browser capture on live build
- [ ] Claim Jumper chase proven in browser capture; not trivially easy
- [ ] Gates + Security Sentinel green
- [ ] Butler ships **fresh** data
- [ ] STATUS honest (no FIXED without captures)

---

## Prompt Claude must fulfill

```
FOUNDER DIRECTIVE ACTIVE — docs/founder-prompts/PROMPT_LIVE_RESIDUALS_STAKE_ASSAY_BOSSES.md

After the “everything live” claim, founder hard-refresh still fails:

1. STAKING: process never occurs — nowhere to CONFIRM. Gideon says “Hit CONFIRM” but only [E] close / [ESC] leave show. Fix so stake can be confirmed and balances change. Gate it.

2. ASSAY SCALE DESIGN: text masks itself; scale too small. Larger, distinct layout; no overlap. Use PIXELLAB_SECRET / MUAPI_API_KEY if new art needed.

3. BOSSES: Distributor + Claim Jumper still do not chase live. Claim Jumper now too easy. Fix + browser captures on current itch build. Headless-only is not enough.

OpenRouter multi-model required. Do not reopen music/pipeline. Gates + STATUS + fresh butler deploy.
```

End of directive.
