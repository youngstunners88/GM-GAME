# FOUNDER PROMPT — No pixelation + L1 ghost death + S2 chase/crystals + final boss scale

**Baseline:** master `eb628d5` (HUD TAP OUT / claim-reset / tokens claimed). Hard-refresh before FIXED.  
**Do not reopen** claim-reset or TAP OUT unless founder shows them broken again.

---

## FOUNDER DECISIONS (Claude asked — answers, do not re-ask)

1. **Naming:** HUD label **"BLAZE DIAMONDS"** stays for the Blaze counter. Protocol token row stays **$DIAMONDS** / **$TITANX** / **$GOLD**. No collision “fix” that renames founder’s chosen words.
2. **Stage 1 TitanX on boss death:** **Keep** TitanX (and token progress) across boss death — same as GOLD/DIAMONDS. Do not wipe on boss death.
3. **Stage 2 Phase 2 chase:** **Yes — push further.** Founder still sees no chase. Make Phase 2 (and overall) reliably close distance in the **shipped** arena, not only a test arena. Prefer slightly faster / longer pursuit window over leaving him outrunnable.

---

## NEW LIVE DEFECTS (this session)

Refs: founder screenshots attached in Claude session (pixelated TAP OUT face; jittery band art).

### T1 — **Never pixelate art**
- TAP OUT Lil Blunt icon is **pixelated / unreadable**.  
- **Rule:** founder artworks must **never** use nearest-neighbor downscale that destroys faces/logos. Use high-res source, correct filter (linear/mipmaps where appropriate for UI), sufficient draw size.  
- Apply to TAP OUT face and any other UI/logo that still looks blocky.

### T2 — Jittery artwork
- Band/logo art is **jittery / hard to see**.  
- Stabilize: stop sub-pixel swimming, snap to pixel grid if needed, or reduce shake/scroll coupling that makes logos vibrate. Must be readable while moving.

### T3 — Level 1 boss: death without contact
- Lil Blunt **dies completely without touching** the Stage 1 boss.  
- Find real cause (hurtbox too large, residual damage, arena hazard, wrong collision layer, one-frame overlap, etc.). Gate: stand still / no contact → no death; contact → normal damage rules only.

### T4 — Stage 2 boss **still not chasing** + crystal attacks
- Chase still broken live after prior fixes — treat as **open**. Fix until kiting in **real** Stage 2 arena shows continuous pursuit (all relevant phases).  
- **New:** boss fires **crystals / crystal shards** at times (ranged pressure), not only melee/orb patterns if those were soft. Distinct from gnome arrows.

### T5 — Final boss too small / ineffective
- Scale up final boss (readable threat).  
- Increase effectiveness: damage, chase or pressure, so the fight is not trivial. Keep arena clamps so scale-up does not reintroduce ledge suicide.

---

## MULTI-MODEL

| Model | Role |
|-------|------|
| Fable-5 / Claude | Implement art filters + L1 death + S2 chase/crystals + final scale |
| Kimi | L1 death path + S2 chase numbers in real arena |
| Grok | Pixelation/jitter visual rules |
| DeepSeek | Compliance matrix |

---

## OUT OF SCOPE

Legal pages rewrite, DeFi enable, video, Episode 2, undoing TAP OUT/claim fixes without evidence.

---

## Definition of done

- TAP OUT face and logos sharp (no pixelation).  
- Band art not jittery.  
- L1: no death without boss contact.  
- S2: chases in real arena + crystal/shard attacks.  
- Final boss larger and effective.  
- Founder decisions applied in STATUS.  
- Gates green; deploy; build id.

**Start:** Fetch → T1–T5 → gates → deploy.
