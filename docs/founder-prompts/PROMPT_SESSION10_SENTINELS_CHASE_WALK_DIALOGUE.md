# FOUNDER PROMPT — Session 10: Sentinels + no gold machine in Diamond Vault + E-dialogue + walk block + S2/S3 chase

**Baseline:** master `8404b98` · source `fc1a82e` · export `2b9243b` (Session 9).  
**Hard-refresh before FIXED.** https://youngstunners88.itch.io/lil-blunt-adventure

**Founder live fails (screenshots attached):**
1. **Golden machine must NOT appear in Diamond Vault**
2. **DIAMOND VAULT SECURITY SENTINEL** replaces useless triangle — threatening design, **smaller** than current oversized prop
3. **Stage 2 boss still does not chase**
4. **E again does nothing** (dialogue / interaction glitch)
5. **FORT KNOX SECURITY SENTINEL** replaces useless triangle — threatening, **smaller**
6. **Walk blocked** — Lil Blunt cannot walk forward; forced to jump
7. **Layout / visibility** — element still unreadable; move it or **extend camera/background** when approaching so the stage reads coherent
8. **Final boss frozen** — no jump, remains still (regression; must chase / move, not statue)

**Rate limit ~100%:** Claude must **not** solo. **Double-load OpenRouter + B.AI.** Long session allowed; API credits available. Other models do design, math, vision, and parallel drafts.

---

## MULTI-MODEL — MAXIMUM / DOUBLE LOAD (mandatory)

| Lane | Role | Required |
|------|------|----------|
| **Fable-5** | Lead implementer | YES |
| **Grok 4.5** | Layout / sentinel scale / camera extend | YES |
| **Kimi K3** | S2/S3 chase + hysteresis verification; walk-block collision | YES |
| **DeepSeek** | Compliance | YES |
| **Qwen** (latest; VL on screenshots) | Confirm each fail from images; parallel analysis | **YES — never idle** |
| **B.AI** | Extra capacity under Claude rate pressure | YES if present |
| **Second pass** | After first model results: **re-dispatch Kimi + Qwen** on chase + walk-block before ship | YES |
| **Claude** | Orchestrate, Playwright/warp, gates — **not** sole designer | YES |

Dispatch **Fable + Grok + Kimi + Qwen** before large edits. **Double-up:** second Kimi/Qwen pass on chase and walk-block. Log all. Retry failures.

---

## ELEVENLABS

- Working secret env names to try (presence-only, **never print**): `ELEVENLABS_API_KEY2`, `ELEVENLABS_api_KEY2`, `ELEVENLABS_API_KEY`, `ELEVENLABS_2`.
- If a real `sk_` works: regenerate Gideon toward **thick western/cowboy** if still generic.
- Do not block the session on voices if keys still fail — log which env names were present (names only) and continue gameplay fixes.

---

## T1 — Diamond Vault props (critical)

- **Remove golden machine** from Diamond Vault entirely (belongs to gold/Fort Knox theme only).
- Replace useless **triangle** with **DIAMOND VAULT SECURITY SENTINEL** (founder threatening sentinel art).
- Sentinel must be **visibly smaller** than the current oversized prop — readable threat, not screen-eating.
- Gate: no gold-machine texture/node in Diamond Vault scene; sentinel present at correct scale.

## T2 — Fort Knox props

- Replace useless **triangle** with **FORT KNOX SECURITY SENTINEL** (founder art).
- **Smaller** than current oversized version.
- Gate: sentinel in Fort Knox; triangle gone.

## T3 — E dialogue glitch

- Pressing **E again does nothing** — fix interaction state machine so second E continues/closes/advances correctly (no dead input).
- Keep stepped slow dialogue from S8/S9; do not reintroduce instant dump.

## T4 — Walk block

- Founder cannot walk forward; forced to jump — find invisible collider / ledge / prop blocking the path in the screenshot region.
- Fix so flat ground is walkable. Gate or probe proves clear path.

## T5 — Layout visibility / camera

- Element still unreadable where founder circled.
- **Either** reposition so it is coherent **or** extend camera limits / background when Lil Blunt approaches so the stage does not clip the UI/set-piece.
- Prefer readable hierarchy over another overlay.

## T6 — Stage 2 chase (still broken live)

- Hysteresis from S9 is not enough for founder eyes.
- Add **test-only** `?boss=2` (or equivalent debug warp) so Playwright can enter Distributor arena without dying on L1.
- **Browser capture** of the fight with player kite + jumps.
- Further chase fix if capture shows idle/hover.
- **FIXED only if capture or founder confirms.** Honest STATUS otherwise.

## T7 — Stage 3 final boss not statue

- Must move / chase — not still, not jump-only-only.
- Horizontal pursuit in real arena; keep damage/facing; no ledge death.
- Warp `?boss=3` if useful for capture.

---

## TASK ORDER

1. Fetch master; live build id.  
2. **Fable + Grok + Kimi + Qwen (+ B.AI) first**; plan double-pass on T4/T6.  
3. T1–T2 sentinels + remove gold machine from Diamond Vault.  
4. T3 E-glitch; T4 walk block; T5 layout/camera.  
5. T6 boss=2 warp + browser capture + chase; T7 S3 chase.  
6. Second model pass on chase/walk-block → gates → deploy → STATUS.

---

## OUT OF SCOPE

Episode 2, video, legal, DeFi, printing keys, claiming chase FIXED without capture or founder OK, reopening unrelated green systems.

---

## Definition of done

- No gold machine in Diamond Vault; both Security Sentinels in place and **smaller**.  
- E works on second press; walk path clear; layout/camera readable.  
- S2: warp + browser capture + honest chase verdict; further fix if needed.  
- S3: not a statue — chases/moves.  
- Full + double model load logged; gates green; build id live.

**Start:** Fetch → **full multi-model dispatch first** → T1–T7 → double-pass → gates → deploy.
