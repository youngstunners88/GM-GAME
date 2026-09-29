---
name: gm-game-smoke-420-lounge
description: The Smoke education room ("The Reading Ring") as a 420 lounge courtyard true to $SMOKE culture - Pauly the Smokest new-school with a bong, haze, open plaza, one whitepaper. TRIGGER when the founder says the Smoke room feels like Hogwarts, claustrophobic, off-brand, the whitepaper is unreachable / duplicated, or wants more player autonomy.
---

# Smoke room = 420 lounge courtyard (founder 2026-09-29)

Founder feedback: whitepaper unreachable and "looks like 2 whitepapers"; setting doesn't fit $SMOKE's
420 / getting-high culture; "looks like Hogwarts"; Pauly the Smokest is new-school and holds a bong;
haze should blow in the house or wherever; space everything out, less claustrophobic, more autonomy.
Source facts: https://richs-crypto-projects.gitbook.io/smokering (quiz facts stay as locked in `data/quiz_smoke.json`).

## What ships
- Map: the founder-approved courtyard concept (brick lounge, green "420" neon, leaf/Saturn mural,
  "GOOD PEOPLE GOOD PLANTS" sign, string-lit lounges, one big open paver plaza) at
  `src/assets/portals/maps/map_smoke.jpg` (2800x1200). Reference: `docs/founder_briefs/2026-09-29/`.
- Props: photoreal 4x2 atlas `fixtures/smoke.png` (fire pit, weed-bag crate, copper fountain, notice board /
  retro TV, leather chair + coffee table, arrow sign, plant) built with `scripts/build_prop_atlas.py`.
- Layout: 7 stops spread over one open plaza, every stop reachable on foot, no corridors, the exam at the
  lounge door, the whitepaper as ONE clearly readable notice-board stop reachable on the plaza.
- Atmosphere: lounge-door haze + rising wisps + drifting fog (`gm-game-portal-atmosphere`), neutral lilac/warm only.

## Guardrails
- Culture is chill and positive: no aggressive/stereotyped drug imagery (CLAUDE.md global rule). Pauly's bong is
  a relaxed lounge prop, not the focus of a shot.
- Never reintroduce "Ember"/Hogwarts-style gothic architecture; one whitepaper stop only.
- Prop and shadow integration rules: `gm-game-portal-prop-integration`.
