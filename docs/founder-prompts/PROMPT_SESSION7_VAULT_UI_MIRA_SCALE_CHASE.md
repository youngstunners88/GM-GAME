# FOUNDER PROMPT — Session 7: Readable vault UI + Mira Voss + Gold Scale + long-range crystals + S2 chase + Blunt scale

**Baseline:** master after Session 6 lineage. Hard-refresh before FIXED.  
**Founder live:** text unreadable; diamond token options unclear/missing; S2 projectiles too short + **still no chase**; scale UI incomprehensible; Lil Blunt too small; large distractors.

---

## MULTI-MODEL + B.AI + QWEN — MAXIMUM LOAD (mandatory)

Rate limits tight. **Do not solo.** Every model works.

| Lane | Role | Required |
|------|------|----------|
| **Fable-5** (OpenRouter) | Lead implementer | YES |
| **Grok 4.5** | UI hierarchy, Mira dialogue copy, scale readability | YES |
| **Kimi K3** | Projectile range math, S2 chase in real arena, font/min-size gates | YES |
| **DeepSeek** | Compliance | YES |
| **Qwen** (latest available on OpenRouter — prefer strongest Qwen3 / Qwen2.5-VL if vision) | Vision on founder screenshots + alternate heavy coding/analysis | **YES — always this session** |
| **B.AI** (`BAI_API_KEY`) | Extra Claude-compatible capacity | YES — use if configured |
| **Claude** | Orchestrate only — not sole designer | YES |

**Qwen rule:** Use the **latest Qwen model ID that OpenRouter lists for this account** (catalogue lookup if unsure). If vision screenshots exist, prefer a Qwen VL variant for UI fail confirmation; otherwise use strongest text Qwen for parallel design/spec. **Do not leave Qwen idle.**

Dispatch **Fable + Grok + Kimi + Qwen** before large edits. Log all. Retry failures.

---

## FOUNDER ART (wire these)

| Asset | Source | Use |
|-------|--------|-----|
| **Mira Voss** | Founder crystal clerk art (glasses, ledger, blue gems) | Diamond Vault **character** Lil Blunt speaks to |
| **Gold Scale** | Founder steampunk BTC/gold balance machine art | Fort Knox + vault **scale instrument** (clear, readable) |

Founder will attach screenshots and art in session. Drop into `src/assets/` with stable names; do not invent a different clerk or scale.

Drive refs (if needed):
- Gold Scale: https://drive.google.com/file/d/1r8IOQTPuc--LWTU86tkRvV0dft56xbZQ
- Mira Voss: https://drive.google.com/file/d/1Nwv9-9dQdjC7Vy5BZk-h9E9M_-MXF7_t

---

## T1 — Text readability (critical)

- All vault / stake / crush / scale labels: **much larger**.  
- Add **outline or strong contrast** so text is readable on busy art.  
- Minimum readable size on mobile web viewport.  
- Founder: “way too small” repeated — ship-blocker.

## T2 — Diamond token utility must be usable

- Player **must clearly see and use** diamond tokens collected.  
- Mira Voss dialogue:
  1. Show holdings (diamond tokens + Blaze Diamonds).  
  2. **Store/stake** diamond tokens (0..owned).  
  3. **Crush** Blaze Diamonds within stack limit.  
  4. Confirm → economy updates.  
- Options = **obvious large buttons**, not tiny undecodable icons.

## T3 — Stage 2 boss: range + chase

- Diamond bomb / shards **must travel far** — reach Lil Blunt across the arena.  
- **Still not chasing** — horizontal pursuit in **real Stage 2 arena**.  
- Projectiles = **diamonds/shards only** (no circle orbs).

## T4 — Lil Blunt slightly larger

- Modest visual scale-up so he is not miniature.  
- Keep collision playable; document scale delta in STATUS.

## T5 — Reduce distractors

- Oversized distracting element (screenshot): shrink/reposition so it does not dominate.

## T6 — Scale instrument clarity

- Install founder **Gold Scale** art; left/right values **large + outlined**.  
- Motion must be understandable in Diamond Vault and Fort Knox.

---

## TASK ORDER

1. Fetch master; live build id.  
2. **Dispatch Fable + Grok + Kimi + Qwen (+ B.AI)** first.  
3. Wire Mira Voss + Gold Scale.  
4. T1–T2 readable utility UI.  
5. T3 long-range crystals + S2 chase.  
6. T4–T6 scale/Blunt/distractor.  
7. Gates → deploy → STATUS with full multi-model + Qwen sections.

---

## OUT OF SCOPE

Episode 2 chapter, video, legal, DeFi on-chain, inventing non-founder clerk/scale when founder art exists.

---

## Definition of done

- Vault text readable with outline.  
- Mira: stake + crush usable.  
- S2: long-range diamond/shard + real chase.  
- Blunt larger; distractor reduced; Gold Scale clear.  
- Qwen + Fable + Grok + Kimi logged; B.AI used or blocker noted.  
- Gates green; build id live.

**Start:** Fetch → **Fable + Grok + Kimi + Qwen first** → tasks → gates → deploy.
