# FOUNDER PROMPT — PlayCanvas Engine Takeaways (Episode 2)

**GIVE THIS ENTIRE FILE TO CLAUDE CODE.**  
Path: `artifacts/PROMPT_EPISODE2_PLAYCANVAS_TAKEAWAYS.md`  
Source: https://github.com/playcanvas/engine  
Skill: `.grok/skills/gm-game-episode2-playcanvas-preview/SKILL.md`

---

## 0. Verdict

PlayCanvas is a **mature MIT web game engine** (WebGL2 + WebGPU, glTF, physics, audio, Gaussian splats).  
It is **not** the Episode 2 runtime.

**Locked runtime remains Godot 4.3.**  
PlayCanvas is an optional **browser preview / splat / itch teaser** layer — same class as Pascal Editor and Three.js demos, not a second game.

Do not migrate the runner or chambers to PlayCanvas.

---

## 1. What PlayCanvas actually is

- Open-source engine: `npm install playcanvas` / `npm create playcanvas@latest`
- Entity-component, TypeScript/JS
- WebGL2 production + WebGPU path (splats are where WebGPU is strongest)
- First-class **3D Gaussian Splatting** (SuperSplat stack)
- glTF 2.0 + Draco + Basis streaming
- ammo.js physics, Web Audio, WebXR
- Browser editor + React / web-components wrappers

This is closer to “Unity-for-the-browser” than raw Three.js.

---

## 2. Fit vs Episode 2 stack

| Need | PlayCanvas | Our lock |
|------|------------|----------|
| Playable Episode 2 | Possible in theory | **Godot 4.3 only** |
| Mine cart runner + zip-line | You would rebuild everything | Already specified in Godot |
| Chamber shooter | Same | Godot |
| Review a GLB / chamber in browser | **Yes — good** | Preview only |
| WorldSplat / Gaussian capture of a mine interior | **Yes — best web splat engine** | Feeds TRELLIS / Tripo, not the game |
| itch teaser / “walk the smelting hall” | **Yes** | Marketing / founder review |
| ICP NFTs spinning Meshy GLBs | Possible | Already on smokegame.win path |

---

## 3. Allowed uses (only these)

1. **Splat preview** — if we capture or generate a Gaussian of the smelting facility / Fort Knox, PlayCanvas/SuperSplat is the viewer.
2. **GLB lookdev** — drop a Tripo/Meshy GLB into a tiny PlayCanvas page so founder can orbit it without Godot.
3. **itch teaser** — short browser walk, not the full runner.

Forbidden:
- Replacing Godot
- Reopening Three.js vs Godot
- Building cart physics in PlayCanvas
- Letting Claude Code “just start a PlayCanvas project” as Episode 2

---

## 4. What Claude Code should do if asked to use it

1. Keep Godot as ship target.
2. If building a preview: one small folder `artifacts/episode2-gold-mine/playcanvas-preview/` with a single scene (smelting or one GLB).
3. Load existing refs/GLBs. Do not invent a new art pipeline.
4. No PR idle loops. No engine-debate STATUS essays.

---

## 5. Success

- [ ] Runtime statement unchanged: Godot 4.3
- [ ] PlayCanvas mentioned only as preview/splat/teaser
- [ ] No parallel Episode 2 codebase in PlayCanvas
