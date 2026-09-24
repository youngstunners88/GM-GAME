# FOUNDER PROMPT — Episode 2: DeepSeek V4.1 Flash 3D Scene Foundation

**GIVE THIS ENTIRE FILE TO CLAUDE CODE (DeepSeek profile).**  
Path: `artifacts/PROMPT_EPISODE2_DEEPSEEK_3D_SCENES.md`

**Skill:** `.grok/skills/gm-game-episode2-deepseek-3d/SKILL.md`  
**Profile:** `CLAUDE_CONFIG_DIR=/home/workdir/claude-deepseek` → DeepSeek V4.1 Flash via Hugging Face router  
**Launch:** `/home/workdir/claude-deepseek/launch.sh` (after HF token export)

---

## 0. Why this exists

We do not currently have a laptop/GPU workflow or Blender MCP in hand.  
**DeepSeek V4.1 Flash** (through the isolated Claude Code HF profile) is the **precursor engine** for Episode 2 3D scenes:

1. DeepSeek authors foundational scene kits, aesthetics, and blockout specs  
2. Founder reviews / light playtest direction  
3. **Astra** later takes over for high-fidelity iteration (Blender, full agent, production mesh)

This is not a throwaway. It locks **foundational aesthetics** so Astra does not invent from zero.

---

## 1. Role of DeepSeek vs Astra

| Phase | Owner | Deliverable |
|-------|--------|-------------|
| Foundation | DeepSeek (this profile) | Scene specs, aesthetic locks, Godot blockout notes, prop/zone lists, camera, lighting intent |
| Review | Founder | Accept / reject aesthetic direction |
| Production fidelity | Astra (later) | Real meshes, materials, animation, final Godot integration |

Do **not** wait for Astra to start. Do **not** claim you need MCP/Blender to produce the foundation.

---

## 2. Non-negotiable Episode 2 context

Read before any scene work:
- `artifacts/PROMPT_EPISODE2_GOLD_MINE_RUNNER_COMPLETE_SPEC.md`
- `artifacts/episode2-gold-mine/characters/INFERNO_BULL_CHARACTER_PROFILE.md`
- `artifacts/PROMPT_2026-09-12_STOP_PR_LOOP_SHIP_EPISODE2.md`
- References: `artifacts/episode2-gold-mine/references/`

**Locked facts:**
- Runtime = **Godot 4.3**
- Runner = carts + zip-lines + duck + cart-jump; balaclava bears (arrows + boulders)
- First Chamber = **smelting facility** → Inferno Bull → Winchester 1886 hand-off
- Then path toward Fort Knox / protocol chambers
- Aesthetic = hyper-real gold mine + Wild West industrial weight (not cartoon, not clean sci-fi)
- Pascal = structured vault/hall architecture only; rough mine shafts are **not** Pascal jobs

---

## 3. What DeepSeek must produce per scene

For each scene under `artifacts/episode2-gold-mine/deepseek-scenes/<scene_id>/`:

### SCENE_SPEC.md
- One-paragraph mood
- Approximate dimensions (meters)
- Zones (entry, playable, exit, interaction)
- Key props (named, countable)
- Lighting (practical sources + mood)
- Camera / player start
- Movement bounds (especially runner: expansive look, limited move space)
- Threat / companion anchors if any

### AESTHETIC_LOCK.md
- Palette (hex or clear material names)
- Surface language (wet rock, iron, timber, gold dust, heat)
- Reference images used from `references/`
- What is explicitly **out of style**

### GODOT_NOTES.md
- Suggested node hierarchy for a Godot 4.3 blockout
- Collision intent
- Audio hook points (align with VARCO Sound sections where relevant)
- What can stay CSG/primitives vs what needs real GLB later

### Optional
- `LAYOUT.json` — simple machine-readable zone/prop list
- `REVIEW.md` — open questions for founder (max 5; no process theater)

---

## 4. Priority scene order (build in this order)

1. **`01_smelting_facility`** — First Chamber  
   Bull meeting, furnace, whiskey/cigar beat, Winchester hand-off space  
2. **`02_runner_opening`** — First track section  
   Multi-rail, zip-line, wet reflective floors, limited playable corridor that still feels deep  
3. **`03_fort_knox_approach`** — Transition toward vault  
4. **`04_fort_knox_vault`** — Can reference existing Pascal dimensions if present; still produce aesthetic + Godot notes  
5. Later protocol chambers as listed in the Episode 2 story spec  

Complete **01** and **02** before expanding the list.

---

## 5. Aesthetic north star (foundational)

- Underground weight, heat, dust, wet stone, iron, timber  
- Gold as light and value, not plastic shine  
- Masculine, industrial-Western, primal — matches audio direction already locked  
- Lil Blunt = small green leafy miner; Inferno Bull = massive black bull miner (see character profile + images)  
- Voxel-ish / readable blockout is acceptable for foundation; final art is Astra’s job  
- Reflective wet floors and practical lantern/furnace light are desirable where they fit  

Use founder images in `references/` as law. Do not drift to generic fantasy dungeon.

---

## 6. Operating rules for this profile

1. Use DeepSeek model only in this profile — do not silently switch back to Anthropic for this workstream.  
2. **No PR check-in loops.** No waiting on draft merges. Build scenes.  
3. Write files into the repo paths above; chat-only descriptions are incomplete.  
4. Prefer concrete meters, counts, and Godot-oriented structure over vague poetry.  
5. When blocked on a missing API key (e.g. VARCO), document the blocker in one file and continue scene authoring.  
6. Keep STATUS.md updates short and about scene deliverables only.

---

## 7. Success criteria (this phase)

- [ ] `01_smelting_facility` folder complete (SCENE_SPEC + AESTHETIC_LOCK + GODOT_NOTES)  
- [ ] `02_runner_opening` folder complete  
- [ ] Both scenes reviewable by founder without requiring Blender  
- [ ] Clear handoff notes for later Astra fidelity pass  
- [ ] No idle PR/status loops  

---

## 8. Handoff to Astra (later)

Each scene kit must be good enough that Astra can be told:

> “Raise this to production fidelity in Blender/Godot. Do not change the zone layout or aesthetic lock without founder approval.”

DeepSeek owns the **foundation**. Astra owns the **finish**.

---

**Build the smelting facility first. Lock the look. Then the opening runner. Files on disk — not just chat.**
