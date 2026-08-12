# FOUNDER PROMPT — No pixelation + L1 ghost death + S2 chase/crystals + final boss scale

**Baseline:** master `eb628d5`. Hard-refresh before FIXED.  
**Do not reopen** claim-reset / TAP OUT / BLAZE DIAMONDS label unless founder shows them broken again.

---

## MULTI-MODEL — MANDATORY EVERY SESSION (non-negotiable)

Founder: **all models on deck every session.** Do not solo. Do not skip because of prior spend errors.

| Model | Role | Required |
|-------|------|----------|
| **Fable-5** (OpenRouter) | Lead implementer | YES |
| **Grok 4.5** | Pixelation / jitter visual audit | YES |
| **Kimi K3** | L1 death path + S2 chase numbers in **real** arena | YES |
| **DeepSeek** | Compliance matrix | YES |
| **Qwen** (vision if screenshots attached) | Confirm sharp vs pixelated / chase still idle | If screenshots present |
| **Claude** | Orchestrate, wire, gates, STATUS | YES — not sole designer |

Dispatch **Fable + Grok + Kimi before** large code changes. Log each model’s findings in STATUS (or `docs/model-responses/`). If a model ID fails, list live catalogue, retry alternate ID, record error — **do not** silently drop the role.

---

## FOUNDER DECISIONS (Claude asked — answers, do not re-ask)

1. **Naming:** HUD **"BLAZE DIAMONDS"** stays. Protocol row **$DIAMONDS** / **$TITANX** / **$GOLD**. Do not rename founder words to “fix collision.”
2. **Stage 1 TitanX on boss death:** **Keep** token progress across boss death (same as GOLD/DIAMONDS).
3. **Stage 2 Phase 2 chase:** **Yes — push further.** Still not chasing live. Close distance in the **shipped** arena. Prefer stronger pursuit over leaving him outrunnable.

---

## NEW LIVE DEFECTS

Founder will attach screenshots in Claude session (pixelated TAP OUT face, jittery art).

### T1 — **Never pixelate art**
- TAP OUT Lil Blunt icon is **pixelated / unreadable**.  
- **Standing rule:** no founder artwork may ship pixelated. High-res source, correct filter (linear + mipmaps for UI downscale — not nearest that destroys faces), adequate draw size.  
- Fix TAP OUT face and any other blocky UI/logo.

### T2 — Jittery artwork
- Art is **jittery / hard to see**.  
- Stabilize: kill sub-pixel swimming, snap if needed, reduce camera/shake coupling on logos. Readable while moving.

### T3 — Level 1 boss: death without contact
- Lil Blunt **dies without touching** the Stage 1 boss.  
- Root-cause (oversized hurtbox, residual DoT, hazard, wrong layer, one-frame overlap, etc.).  
- Gate: no contact → no death; contact → normal rules only.

### T4 — Stage 2 boss still not chasing + **crystal attacks**
- Chase still broken live — **open**. Fix until real Stage 2 arena kiting shows continuous pursuit across phases.  
- **New behavior:** fire **crystals / crystal shards** at times (ranged pressure). Distinct from gnome arrows and from soft melee-only patterns.

### T5 — Final boss too small / ineffective
- **Scale up** final boss (clear threat).  
- Raise effectiveness (damage / chase / pressure) so fight is not trivial.  
- Keep arena clamps — scale must not reintroduce ledge falls.

---

## OUT OF SCOPE

Legal rewrite, DeFi enable, video, Episode 2, undoing working HUD/claim without evidence.

---

## Definition of done

- Sharp TAP OUT face + logos (no pixelation).  
- Band art stable (not jittery).  
- L1: no ghost death.  
- S2: chases in real arena + crystal/shard volleys.  
- Final boss larger and effective.  
- Multi-model log present for this session.  
- Gates green; deploy; build id.

**Start:** Fetch → **dispatch Fable + Grok + Kimi first** → T1–T5 → gates → deploy → STATUS with model sections.
