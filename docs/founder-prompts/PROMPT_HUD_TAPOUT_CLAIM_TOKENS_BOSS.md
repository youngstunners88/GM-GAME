# FOUNDER PROMPT — HUD labels + claim-reset + TAP OUT + tokens + boss chase

**Baseline:** PR #21 / security checklist work. Merge when CI green. Hard-refresh after deploy before FIXED claims.  
**Security decisions (founder answers — do not re-ask):**

1. **Legal pages (`terms.md` / `privacy.md`):** Keep in repo for now as **drafts**. Do **not** invent new legal text. Mark them clearly as drafts in STATUS. Founder will review later. Do **not** delete unless founder says pull.
2. **DeFi checks:** Keep **SKIP** for now (no `.sol` in-tree; web3 is client-facing). Record skip reason. Do **not** fail the ship on DeFi category this session. Founder may flip later.

**Security backlog:** Do **not** broaden `*.js` globs this session if it creates known false-criticals — leave tuning in `docs/security/sentinel-hardening-backlog.md` unless founder says ship the 11→25 change.

---

## GAMEPLAY (founder Fixes.md — do these)

Refs: founder screenshots attached in Claude session (PUFFS HUD, TAP OUT face, TOKENS HUD).  
TAP OUT face Drive (if not attached as file): https://drive.google.com/file/d/13itLt1lEzF5RkmBdNH0joqyGfD4j5iF7  
Drop face art at `src/assets/ui/lil_blunt_tapout.png` (or project UI path).

### T1 — HUD text
- Change **"PUFFS"** → **"BLAZE DIAMONDS"**.

### T2 — Diamond claim survives attempt (AGAIN)
- Founder: first diamond already claimed on a fresh attempt without collecting it this run.  
- Reset **all** Blaze diamond claim state on: Blaze enter, Blaze retry/restart, death-in-Blaze that resets the run, exit/TAP OUT return.  
- Gate: start Blaze → claim one → restart Blaze → that diamond must be unclaimed.

### T3 — EXIT → TAP OUT + Lil Blunt face
- Label **"EXIT"** → **"TAP OUT"**.  
- Place founder face art **next to** the control so it reads “this is hard / I’m out.”  
- Same behavior as current exit (return to level); only UX/label/art change unless exit path still broken.

### T4 — TOKENS vs COINS
- Add **"TOKENS"** allocation/row for protocol pickups: **$TITANX**, **$DIAMONDS**, **$GOLD** (tokens).  
- **Coins** remain chain currency: Stage 1 **Ethereum**, Stage 2 **Solana**, Stage 3 **Bitcoin**.  
- HUD must not call protocol tokens “coins.”

### T5 — Stage 2 boss still not chasing
- Founder reports **still** no chase after prior “pin/speed” fixes.  
- Re-prove with kiting gate **inside real arena walls**. If frozen on west edge or idle, fix until boss closes distance in live export. Multi-model (Kimi numbers + Fable) if stuck.

### T6 — Stage 3
- Founder: “None of the issues I mentioned for stage 3 has been addressed.”  
- Re-read prior Stage 3 list (orange clutter, BTC clarity, big-axe if still wrong, boss chase, design coherence). Fix what is still true after hard-refresh; do not claim FIXED without evidence.

Art placement founder praised — **do not** undo correct logo placement.

---

## MULTI-MODEL

| Model | Role |
|-------|------|
| Fable-5 / Claude | Implement HUD + claim-reset + TAP OUT |
| Kimi | Claim-reset path + Stage 2 chase numbers |
| Grok | HUD copy / TOKENS vs COINS clarity |
| DeepSeek | Compliance matrix |

---

## OUT OF SCOPE

New legal essays, DeFi category enable, video, Episode 2, security glob broaden that fails CI on false positives.

---

## Definition of done

- PUFFS→BLAZE DIAMONDS; TAP OUT + face; TOKENS vs coins clear.  
- Diamond claim does **not** survive Blaze restart.  
- Stage 2 boss chases in real arena (gated).  
- Stage 3 remaining defects fixed or honestly listed with evidence.  
- Founder security answers applied in STATUS.  
- Gates green; deploy; build id.

**Start:** Fetch → apply founder security answers in STATUS → T1–T6 → gates → deploy.
