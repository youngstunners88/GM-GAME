# STAGE 1 WEAPON SWAP — SMOKE BOMBS, NOT AXES (EPISODE 1 ONLY)

**Date**: 2026-09-14  
**Scope**: Episode 1 only. Do not touch Episode 2.

## Design rule (founder lock)

Lil Blunt does **not** throw axes in Stage 1.

Reason: he only **finds the pickaxe / mining gear after defeating the Stage 1 Tax Collector** (GOV VAULT loot → Crystal Caverns). Axes / pickaxe as a throw weapon do not exist yet.

**Stage 1 attack = smoke bombs.**  
Small thrown / shot smoke bombs that deal damage, match the marijuana-smoke identity, and replace every axe throw in Stage 1.

---

## What to change

### Stage 1 (Tax / Auditor biome)
- Replace thrown **axes** with **smoke bombs** (small, readable, green-white smoke burst on impact).
- Attack button in Stage 1 fires / throws a smoke bomb, not an axe sprite.
- Projectile art, SFX, and hit VFX must read as smoke / bomb, not metal.
- Enemy + Auditor damage still works from these bombs (plus existing stomp if that remains).
- HUD / tutorial / How-To-Play copy that says “throw axe” in Stage 1 must say **smoke bomb**.

### Stage 2 (Crystal Caverns)
- **Keep the axe as it currently works.** Do not replace Stage 2 throws with smoke bombs.
- Pickaxe / mining gear from the Stage 1 Tax Collector win is still the story unlock into Crystal Caverns.
- Stage 2 attack = existing axe behaviour. No smoke-bomb-only restriction here.

### Stage 3 (Gold Rush)
- Leave Stage 3 weapons as they currently are (big axe / hammer / Bitcoin leverage as already specified). Do not regress them while doing this swap.

---

## Implementation notes for Claude Code

1. Find every Stage 1 player projectile / throw path (`weapon_*`, `axe`, `projectile`, player attack in level 1 / Auditor stage).
2. Gate by **stage / episode / biome**, not a global delete of axes:
   - `stage == 1` → smoke bomb projectile
   - later stages keep their own weapons
3. Reuse existing weapon-host pattern if present (`weapon_base` + swap node) so this is a Stage 1 weapon node, not a player rewrite.
4. Smoke bomb must:
   - travel on the same throw / shoot input
   - explode or puff on hit
   - damage enemies and the Auditor
   - not require a jump to use
5. Do **not** give Lil Blunt a pickaxe in Stage 1 gameplay.

---

## Definition of Done

- Hard-refresh Stage 1: attack button throws / shoots **smoke bombs only**. No axe sprite.
- Auditor and Stage 1 enemies take damage from smoke bombs.
- Stage 2 still grants / uses pickaxe after the Stage 1 win path.
- Stage 3 weapons unchanged.
- Gates green. Auto-deploy per `PROMPT_AUTO_DEPLOY_EVERY_UPDATE.md`.
- STATUS.md notes: “Stage 1 attack = smoke bombs; axes/pickaxe start at Stage 2.”

**Do not** “fix” this by hiding the axe poorly. Replace the Stage 1 projectile for real.
