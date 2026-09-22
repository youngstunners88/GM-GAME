# FOUNDER PROMPT — Episode 2 Takeaways from 3D AI Roundup Doc

**GIVE THIS ENTIRE FILE TO CLAUDE CODE.**  
Path: `artifacts/PROMPT_EPISODE2_3D_AI_ROUNDUP_TAKEAWAYS.md`  
Source doc: https://docs.google.com/document/d/1BD7dQV-xs_3SRI0KWUxYSXfUo8tmD2w3xpnLw2l_4wk/edit  
Skill: `.grok/skills/gm-game-episode2-tripo-meshy-pipeline/SKILL.md`

This is a **pipeline lock**, not a research rabbit hole.

---

## 0. What the doc actually is

A 3D-AI news roundup (Philipp / community): Meshy 7.1, Tripo Smart UV + P2, WorldSplat, Astra animation, Kai Ninja, Miura 3D, Snap3D, HKTex.

We extract only what helps **Episode 2 Gold Mine** ship in Godot 4.3.

---

## 1. Locked takeaways

### A. Game-ready mesh default = Tripo
- **Tripo Smart UV** is the first AI unwrap that works on organic *and* hard surface.
- Fast, cheap (~20 credits, up to 4 UV variants).
- **Tripo P2** is public (out of beta). Low-poly quality improved. Roundup verdict: Tripo is now the top tool **for game development**.
- Hunyuan Studio UV is slower and unstable — do not use it as primary.

**Action:** All Episode 2 props (carts, rails, lanterns, pickaxe, crates, furnace pieces) default through Tripo P2 + Smart UV → GLB.

### B. Meshy 7.1 Ultra 4K = hero only
- 4K / extreme poly (claims up to huge counts before simplify).
- Better detail without as much upscale noise.
- Useful for 3D-print-level or displacement source, not runtime.

**Action:** Use Meshy 4K only for Inferno Bull hero sculpt / Fort Knox ornamental plates. Decimate before Godot. Never drop raw Ultra 4K into the runner.

### C. Astra = animation, not the whole pipeline
- GPT-6 Astra can animate multi-limb creatures and humanoids when used with the right APIs/libraries.
- Gap vs Fable 5.1 on animation is large (Astra wins that job).

**Action:** Mesh first (Tripo). Then Astra for Bull idle / cigar / Winchester hand-off / Lil Blunt walk. Do not wait on Astra to invent the chamber.

### D. TRELLIS 2 ecosystem is how we split props
- **WorldSplat**: Gaussian splat → watertight per-object meshes (interiors / on-set capture). Built on TRELLIS 2 + DINOv3.
- **Kai Ninja**: one image → separate part meshes (not one fused blob). Model not fully public yet; license unclear.
- **Snap3D**: same family — assemble scene + split parts; even print connectors.

**Action:** Mine cart, furnace doors, Winchester lever must be **part meshes**, not one welded blob. When Kai Ninja / Snap3D are usable, prefer them over a single TRELLIS merge. Until then, author parts separately in Tripo.

### E. Skip / park
- **Miura 3D** (Tencent): no quality leap vs Tripo / Meshy. Ignore.
- **HKTex** (heat-kernel textures, no UVs): research. Watch. Stay on Smart UV for game engines today.

---

## 2. Recommended Episode 2 asset flow

```
Founder ref image
    → Tripo P2 (game LOD)
    → Tripo Smart UV
    → GLB
    → Godot 4.3

Hero only:
Founder ref
    → Meshy 7.1 Ultra 4K
    → remesh / decimate
    → Smart UV if needed
    → GLB
    → Godot

Animation:
GLB + rig notes
    → GPT-6 Astra (APIs + libs)
    → Godot AnimationPlayer
```

First targets: Inferno Bull (hero Meshy optional + Tripo LOD), Winchester, mine cart (split parts), smelting furnace pieces.

---

## 3. What Claude Code must do next

1. Do **not** stand up six new integrations this session.
2. Document Tripo as default in STATUS / Episode 2 asset notes.
3. When generating or commissioning a mesh, write the tool choice into the scene kit (`GODOT_NOTES.md`).
4. Keep TRELLIS skill for lounge/collectibles; use this skill for **playable mine props**.
5. No PR check-in loops. No waiting on Kai Ninja public weights.

---

## 4. Success

- [ ] Episode 2 props have a named generator (Tripo vs Meshy) in their notes
- [ ] UVs come from Smart UV unless a human unwrap is justified
- [ ] Cart / furnace / gun are planned as parts, not one mesh
- [ ] Astra is queued for animation only after a GLB exists

**Tripo for the game. Meshy for the statue. Astra for the motion. Everything else is optional.**
