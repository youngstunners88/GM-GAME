<!-- Founder brief, copied from Google Drive 15T7bTvoX0K2REwQ45sfMKnrvAjhNI35z on 2026-11-05 (markdown escapes removed). Skills: ep2-jackhammer-wall-boss -> ep2-official-wanted-rebalance, ep2-gatling-wanted-billboard. -->
# PROMPT_EPISODE2_JACKHAMMER_POSTERS_GATLING_BILLBOARD_2026-11-05.md
# Episode 2 — Environment-wide Jackhammer Wanted posters + Gatling target billboard
**Date:** 2026-11-05 (revised same day — environment-wide, not Armory-only)
**Status:** Active — give this entire file to Claude Code
**Repo:** youngstunners88/GM-GAME · Godot 4.3 · Hard-refresh only acceptance

**Founder asset (OFFICIAL Jackhammer Wanted — source of truth):**
Google Drive: `https://drive.google.com/file/d/1GCG24Wf3uzR6GX_xVstsOFWnt596UEAM/view?usp=drivesdk`
File title: **Jackhammer Wanted**
Pull this image into the project. **Do not invent** a different Jack Hammer likeness. If the session cannot access Drive, use the founder-provided local drop of the same file — no random wanted poster substitutes.

**Related locks (do not contradict):**
- `PROMPT_EPISODE2_JACK_HAMMER_BOUNTY_HORSE_AUCTION.md` — antagonist **Jackson McCree / Jack Hammer**; bounty in gold XAUt — **he is the main antagonist face**
- `PROMPT_EPISODE2_RICH_ARMORY_UTAH_RIVER.md` — Rich runs the Armory; he is **not** the antagonist
- `PROMPT_EPISODE2_FOUNDER_FIX_PACK_2026-10-27.md` — Gatling must **hit targets** and sound intense
- `PROMPT_EPISODE2_GUNS_AIM_HORIZON_2026-11-01.md` — armory combat paths stay intact

---

## 0. Why this pass exists

Right now the world is overloaded with **RH (Rich) posters**, so Rich reads like the main antagonist. He is not. **Jack Hammer** is the antagonist. The environment must show **more Jackhammer** and **fewer RH** — not zero RH, but a clear slide reduction so the bounty face dominates wanted space.

---

## 1. Scope (environment-wide — not Armory only)

| # | Job | Priority |
|---|-----|----------|
| 1 | **All** current Jackhammer posters that are blank, placeholder, low-res, or poorly defined → replace with the **OFFICIAL** Jackhammer Wanted art | P0 |
| 2 | **Some** RH posters across the **whole environment** → replace with official Jackhammer Wanted (reduce RH count; keep a smaller set of RH) | P0 |
| 3 | Large **shootable** Jackhammer target banner / mini-billboard by the **Gatling gun** | P0 |

### Where this applies
- **Entire playable Episode 2 environment** where wanted/character posters already exist: town streets, Armory, Gatling range, saloon walls, side alleys, stables approaches, jail approaches, any interior that already hangs RH or weak Jackhammer sheets.
- Not limited to the Armory interior.

### Balance rule
- **Keep some RH posters** — Rich still exists as Armory / education face; just **not** the dominant wall presence.
- **Net result:** Jackhammer Wanted is the **majority** antagonist poster the player sees while moving through town and the range.
- Do **not** delete every RH instance; do a **slide reduction** (founder: “we’re still gonna have RH, just fewer”).

---

## 2. Official Jackhammer Wanted — poster replacement rules

### Required
1. Import Drive asset as the **canonical** Jackhammer Wanted texture (single source of truth).
2. **Scan all poster instances** in the environment:
   - Any poster already meant to be Jackhammer but **missing a proper image**, blurry, generic silhouette, or wrong face → **must** use the official art.
   - A **portion** of RH posters → retarget to official Jackhammer Wanted (especially high-traffic walls where RH currently clusters).
3. Framing: correct UVs on existing poster meshes/quads; paper/print look preserved; face + name readable at walk-up distance.
4. Materials: no pure black void, no stretched mush, no neon blowout.

### Do not
- Invent a second Jack Hammer face.
- Leave “Jackhammer” posters that still show empty/placeholder art.
- Wipe **all** RH posters (keep a reduced set so Rich is still present as shopkeeper identity, not antagonist).
- Touch protocol chamber signage (Treasury, Certificates, Stockpile) unless those props are literally the same RH/Jackhammer poster meshes.

---

## 3. Gatling range — large target banner / billboard

### Required
- **Large** target-practice piece **by the Gatling gun** — bigger than a normal wall poster:
  - Miniature billboard or range banner; primary target from the Gatling firing position.
  - Uses the **same official Jackhammer Wanted art** (or a range crop of it).
- **Shootable:**
  - Gatling rounds register hits (decals / shred / score — match existing Gatling target feedback).
  - Counts toward founder fix pack: Gatling must hit targets and feel intense.
- Visible when the player steps up to the gun; does not block the firing lane or trap the player.
- Scale: billboard-class, not another small flyer.

### Optional polish
- Damage states (clean → holed → shredded).
- Light canvas sway only if hit registration stays solid.

### Do not
- Decoration-only non-hittable board.
- Remove working small targets — **add** the big banner as a primary target.
- Replace the Gatling mesh itself.

---

## 4. Antagonist hierarchy (visual)

| Face on walls | Role | Poster density after this pass |
|---------------|------|--------------------------------|
| **Jack Hammer** | Main antagonist / bounty | **Majority** of wanted-style posters + Gatling billboard |
| **Rich (RH)** | Armory operator, not antagonist | **Reduced** minority; still present |
| Utah / others | Supporting | Unchanged unless they were mis-tagged as RH/Jackhammer sheets |

---

## 5. Definition of Done

- [ ] Official Jackhammer Wanted (Drive `1GCG24Wf3uzR6GX_xVstsOFWnt596UEAM`) imported and used as the only Jackhammer poster face
- [ ] **Every** weak/placeholder Jackhammer poster in the environment now uses the official art
- [ ] **RH poster count reduced** environment-wide; some RH remain; Jackhammer is the dominant wanted face
- [ ] Pass is **not** Armory-only — town + range + other poster locations included
- [ ] Large Jackhammer banner by Gatling is **shootable** and registers hits
- [ ] Firing lane clear; Gatling test still completable
- [ ] STATUS.md notes environment-wide poster rebalance + billboard
- [ ] FIXED only after founder hard-refresh walk of town + Armory Gatling section

---

## 6. Pointers

- Global search: poster meshes, RH materials, “wanted”, Jackhammer / Jack_Hammer decals across Episode 2 town and interiors
- Armory / Gatling hit-target system
- Narrative antagonist: `PROMPT_EPISODE2_JACK_HAMMER_BOUNTY_HORSE_AUCTION.md`
- Rich identity only: `PROMPT_EPISODE2_RICH_ARMORY_UTAH_RIVER.md`

**Jackhammer is the wall boss. RH stays, but fewer. Every bad Jackhammer sheet becomes the official Wanted. Big board eats Gatling rounds.**
