# FOUNDER PROMPT — Episode 2: Gold Mine Runner + Protocol Chambers (SHOOTER/RPG MODE)

**GIVE THIS ENTIRE FILE TO CLAUDE CODE.**  
This is the single source of truth. Do not look elsewhere for the Episode 2 brief.

**Session type:** Architecture + planning + initial asset pipeline  
**Lead:** Claude Code via OpenRouter (prefer latest ChatGPT Astra / strongest planner available)  
**Graphics drivers (mandatory):**  
- Blender (https://www.blender.org/)  
- blender-mcp → `claude mcp add blender uvx blender-mcp`  
  Repo: https://github.com/ahujasid/blender-mcp.git  
- Three.js (https://threejs.org/docs/)  

**Aesthetic Law (NON-NEGOTIABLE):**  
Hyper-realistic 3D cinematic quality matching the founder reference images exactly (IMG_2478 rear cart view, IMG_2479 zip-line from behind, IMG_2480 action jump).  
Lil Blunt = green leafy cannabis character, copper miner hard-hat with glowing headlamp, leather work gear, pickaxe always present.  
Mine carts with cannabis-leaf gold emblems, multi-rail tracks, wooden beams, glowing gold veins, lantern light, sparks, volumetric lighting.  
Everything must be Blender-ready and export cleanly as GLB. Lower-quality or cartoonish outputs are rejected. Hyper-realism is required in both runner and chamber modes.

---

## 1. Core Vision

Episode 2 is the **Gold Mine Runner**.

The entire episode is built around a continuous underground gold-mine track system. Gameplay alternates between two distinct modes:

### Mode A — Runner (Track Sections)
- Lil Blunt rides mine carts on multi-rail tracks and uses overhead metal zip-lines.
- Jump between rails, dodge obstacles, collect GOLD / Diamonds / sparks.
- Camera is over-the-shoulder / from behind (exact match to references).
- Fast, cinematic, high-speed feel.

### Mode B — Chamber (3D Shooter / RPG Style)
- When the track leads into a chamber entrance, the game **switches into full 3D shooter / RPG mode**.
- Hyper-realistic 3D environment.
- Lil Blunt can freely move, aim, shoot, use pickaxe as melee/weapon, interact with protocol machines, fight enemies if present, and complete the chamber objective.
- This is not a menu or simple button press — it is a real 3D action/RPG encounter that still teaches and executes the real Gold Mine protocol mechanic.
- After the chamber objective is complete, Lil Blunt exits back onto the tracks and Mode A (Runner) resumes.

This runner ↔ chamber loop is the spine of the whole episode.

**Goal:** Make the Gold Mine protocol feel real, visitable, and exciting. Drive attention and on-chain activity.

---

## 2. Technical Stack (Forced)

1. **Blender** — source of truth for all high-fidelity assets and scenes.  
2. **blender-mcp** — Claude controls Blender directly.  
   Install command: `claude mcp add blender uvx blender-mcp`  
3. **Three.js** — runtime / web prototype / GLB loader path.  
4. Claude Code owns the repo, STATUS.md, commits, and final integration.  
5. Existing TRELLIS skill and multi-model orchestrator are available.

**Pipeline:** Reference images → Blender scene (via MCP) → clean GLB → Three.js or Godot 4.3 → polish.

---

## 3. Protocol Chamber Mapping (White Paper → Game)

Every chamber is a **3D hyper-realistic shooter/RPG space** that still maps exactly to the real Gold Mine white paper. No invented economics.

| # | Chamber | White Paper Element | Chamber Gameplay (Shooter/RPG) |
|---|---------|---------------------|--------------------------------|
| 1 | **Miner Shaft** | GOLD Mining (100-day vesting @ 1%/day, 20% permanent Diamond burn, early claim forfeits unvested) | 3D industrial chamber. Start miner, choose payment (ETH/Diamonds), defend or interact while vesting progresses, optional early claim. |
| 2 | **Fort Knox Vault** | Fort Knox Staking + Melt Bonus (locks up to 2,888 days, melt up to 3× for up to 1,000% share multiplier) | Massive fortified vault. Stake GOLD, choose lock length, feed GOLD into Melt furnace under possible combat pressure. |
| 3 | **Gold Rush Auction Hall** | Weekly 7-day auctions for XAUT | Grand hall. Deposit GOLD into the live auction pool while dealing with any threats or timers. |
| 4 | **Stockpile Depot** | Gold Stockpile / Liquidity | Warehouse. Match forfeited GOLD with wBTC, decide burn vs LP injection. |
| 5 | **Claim Certificate Office** | Gold Claim Certificates (0.5 XAUT + 22,000 Fort Knox shares) | Formal office. Claim non-transferable certificate if requirements met. |
| 6 | **Treasury / Sovereign Vault** | Protocol Treasury & concentrated liquidity (Phase 2) | Elegant treasury. View/interact with protocol-owned positions. |

Detailed design notes live in:  
`artifacts/episode2-gold-mine/spec/01_CHAMBER_*.md` … `06_CHAMBER_*.md`  
Claude Code must update those files so each one explicitly describes the 3D shooter/RPG encounter.

---

## 4. Asset Priorities (First Sessions)

1. Lil Blunt fully rigged (miner helmet + headlamp + pickaxe) with runner animations **and** shooter/RPG animations (aim, shoot, interact, melee).  
2. Mine cart (cannabis-leaf emblem) + zip-line trolley system.  
3. One complete Runner Segment (30–60 seconds).  
4. One complete Chamber in full 3D shooter/RPG form (start with Miner Shaft or Fort Knox).  
5. Environment kit: rock walls with gold veins, wooden beams, rails, lanterns, gold piles, hanging baskets.

All assets must be hyper-realistic and export as clean GLB.

---

## 5. Folder Structure (Already Created)

```
artifacts/episode2-gold-mine/
├── spec/               ← architecture + chamber docs
├── assets/
├── blender/
├── threejs/
├── chambers/
├── runner/
└── references/

.grok/skills/gm-game-episode2-gold-mine-runner/SKILL.md
```

---

## 6. Immediate Tasks for Claude Code (Execute in Order)

1. Confirm blender-mcp is registered and working (`claude mcp add blender uvx blender-mcp`).  
2. Create the first Blender scene: gold-mine tunnel + mine cart + Lil Blunt rear-view (match IMG_2478 lighting and composition as closely as possible).  
3. Update every chamber design doc so it clearly describes the **3D shooter/RPG encounter** that happens inside that room.  
4. Produce a minimal Three.js (or Godot 4.3) test that loads a GLB and supports basic third-person movement + shooting.  
5. Update STATUS.md with Episode 2 planning status only. Do **not** touch Episode 1 residuals.  
6. Use multi-model as needed (strong planner for architecture, Grok for aesthetic fidelity).

---

## 7. Hard Rules

- Lil Blunt is the only playable protagonist and the only companion voice.  
- Never invent protocol numbers or mechanics. Visualize only what the white paper states.  
- **Chambers = full 3D hyper-realistic shooter/RPG mode.** Runner = cart + zip-line track mode.  
- Aesthetic fidelity to the three founder reference images is law. Hyper-realism required throughout.  
- Prefer GLB assets that travel between Blender ↔ Three.js ↔ Godot.  
- Claude Code owns the repository and STATUS.md.

---

## 8. Success Criteria

- [x] This file is the single clear prompt Claude Code can be given.  
- [x] Skill and folder structure exist.  
- [x] Chambers are defined as 3D shooter/RPG experiences.  
- [ ] First Blender scene exists.  
- [ ] First chamber has a full shooter/RPG design brief.  
- [ ] Minimal Three.js/Godot GLB test with movement + shooting exists.

**The gold rush has begun. Build the mine that players will actually want to ride — and fight inside.**

---

*References:* Founder images IMG_2478 / 2479 / 2480, official Gold Mine white paper, blender-mcp, Three.js, existing Episode map.
