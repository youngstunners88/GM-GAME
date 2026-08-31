<!-- dispatched: x-ai/grok-4.5
     prompt: prompts/s3-grok-vault-readability.md
     files inlined: 1
     tokens: 2943 in / 1483 out
     cost: $0.0148
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
## Vault Interior READ Audit

### 1. DIAMONDS vs GOLD MINE at a glance

**Yes, the backdrops already split identity hard:**
- Diamond: cyan/violet crystal cavern, staggered platforms, sigil door
- Fort Knox: amber/brass mine-forge, cart tracks, Bitcoin roundels

**Gap:** backdrop is wallpaper; player stands on whatever solid geometry you spawn. Without matching foreground dress, it reads as “generic platforms in front of a painting.”

**Minimum procedural dressing (bridge backdrop → walkables):**

| Element | Diamond Vault | Fort Knox |
|---|---|---|
| Platform fill | `#3a4a6a` stone + cyan edge `#5ef0ff` @ 40% | `#4a3520` timber/iron + brass edge `#d4a020` @ 40% |
| Platform top strip | 2–3px crystal sheen (cyan/violet pulse, 0.5Hz, low amp) | 2–3px rivet/metal line (static brass) |
| Ground decal tint | Cool desat blue-violet multiply | Warm amber multiply |
| Particle accents (sparse) | Slow-fall crystal motes, cyan, ~8–12 on screen | Ember sparks + dust, amber, near forge only |
| Ambient modulate on props | +15% saturation toward cyan | +15% toward amber |

Do **not** repaint the full backdrop onto platforms — edge color + 1 decal layer + sparse particles is enough to lock “one built space.”

---

### 2. Interactable readability (2+ types)

**Diamond — `diamond_deposit_pillar.png` (deposit altar)**
- **Idle:** soft cyan rim glow, 1.5s breathe (scale 1.0→1.03 on glow only, not sprite)
- **In range:** brighter core + upward motes; optional thin vertical beam to mark “use zone”
- **Triggered:** hard flash white→violet, crystal burst particles, glow collapses to dim “spent” state (desat 50%, no pulse)
- **Reads as interactive because:** pedestal silhouette + continuous pulse; dead props don’t breathe

**Fort Knox — `goldmine_melt_forge.png` (reuse `melt_forge` if it already has use/reward hooks)**
- **Idle:** orange hearth flicker on the pour spout only (not full sprite)
- **In range:** gauge needle ticks / glow ring on Bitcoin gauge; heat haze (subtle)
- **Triggered:** pour brightens, ingot clink particles, then “cooled” state (hearth dim, no flicker)
- **Reads as interactive because:** moving light on a machine + gauge focus; static gold piles nearby stay unlit

**Rule:** decoration = no pulse, no state change. Interactives = always-on idle motion + clear spent state so you can’t re-use by accident.

---

### 3. One hazard READ per vault (identity-locked)

**Diamond — Crystal security pylon / shard lane**
- Tall thin crystal stake or ceiling shard cluster
- Telegraph: violet line on floor 0.4s, then shard drops/fires along that lane
- Color: pure cyan→violet, faceted glints — **no** fire, smoke, or metal
- Feel: museum laser / vault security, not combat turret

**Fort Knox — Pressure steam vent / riveted floor grate**
- Brass grate in floor or wall pipe with Bitcoin-stamped valve
- Telegraph: gauge spikes + white-amber steam puff build, then vertical steam column
- Color: amber/white steam, iron grate — **no** crystals or cool hues
- Feel: industrial failsafe, not magic

Do not share VFX palettes between them.

---

### 4. Density vs gameplay-critical legibility

Yes, risk is real — backdrops are busy full-bleed paintings.

**Layering / contrast rule:**

| Layer | z / treatment | Saturation |
|---|---|---|
| Backdrop | Parallax far, slight darken (~20% black overlay) or desat 15% | Lower than playables |
| Static dress (tracks, chains, non-solid art) | Mid, no outline | Mid |
| Walkable platforms | Above dress; **1px dark outline** `#0a0a12` | Full, protocol edge tint |
| Hazards | Same band as platforms; **warm or cool warning flash** on telegraph only | Full during active |
| Interactives | Above platforms; idle glow + outline | Full |
| Ladder exit + reward pickup | Top of prop stack; **stable bright silhouette** (ladder: high-contrast rails; reward: gold/cyan pulse stronger than any ambient mote) | Highest |

**Hard rules:**
- No ambient particle crosses the ladder AABB at full opacity
- Interactives/hazards get outline; backdrop motifs (sigil, roundels) do not
- Critical objects: value contrast ≥ 2× local backdrop average (bright on darkened midground)
- Keep play-space vertical band (y 650–825) clearer than the painted depth cues in the art

---

### 5. Fort Knox vault door placement (`fort_knox_vault_door.png` 380×380)

**Constraint:** ~175px play height (y 650–825). A 380px sprite **cannot** sit in the play band without crushing vertical space or covering the player.

**Placement:**
- **Role:** backdrop centerpiece only (non-solid, non-interactive), parallel to Diamond sigil
- **Scale:** ~0.45–0.55 → ~170–210px tall (reads as heavy door, fits depth)
- **Position:** rear wall, horizontally centered on the vault chamber’s main bay (or slightly behind the deepest platform tier)
- **Vertical:** center of door ≈ y 700–740 so the **upper half** sits in the painted wall above the walk strip and the **lower rim** kisses or sits just behind the floor line — not a collider
- **Z:** behind platforms and player; slight desat vs interactives so it anchors “inside a vault” without competing with forge/ladder
- **Do not:** place at full 380px, on the walkable floor, or as a blocking wall inside the 175px band

---

**Soft-lock reminder:** ladder `destructible = false`; `top_exit_offset` must land on real ground east of the pit; keep all solid vault geometry and standable floors at y ≤ 825 unless kill-zone x-exclusion is explicitly approved.