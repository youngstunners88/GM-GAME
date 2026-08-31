---
name: stage3-gold-rush-layout-aesthetics
description: Improve Stage 3 (Gold Rush / GoldMine Rush) platform layout rhythm, gap fairness, visual density, and protocol aesthetics so the stage stops reading as generic or "shitty." Use on any Session focused on Stage 3 design, platform polish, camera readability, or Gold Rush identity. Pairs with level-distinctness-checker and game-aesthetics-forge.
user-invocable: true
allowed-tools: Read, Glob, Grep, Bash, Edit, Write
---

# Stage 3 Gold Rush — Layout & Aesthetics

Founder has repeatedly rejected Stage 3 as unfinished / "shitty" on **basic platform layout and overall design**, not just boss AI. This skill exists so Claude does not ship another number tweak and call the stage fixed.

## Load first

1. `STATUS.md`
2. `src/resources/level_03_data.tres`
3. `src/level/level_03_gold_rush.gd`
4. `src/level/level_base.gd` (platform rendering + camera limits)
5. This skill + `level-distinctness-checker` + `game-aesthetics-forge`
6. Any founder screenshots of Stage 3 (T4 walk-block, T5 circled layout)

## What "shitty" has meant in this project

Recurring founder signals (do not invent new ones):

| Signal | Typical cause in this codebase |
|--------|--------------------------------|
| Platforms feel random / same as other stages | `ground_segments` + `platforms` rhythm is still a mild reskin of L2 spacing |
| Forced to jump when walking should work | Invisible collider, overhanging prop, or 1px ledge block on main path |
| Clutter / orange rectangles / unclear props | Functionless or dual-purpose sprites that read as decoration |
| Stage does not feel like GOLD / Fort Knox | Cyan/purple leftovers, weak gold lip, missing dust/steel language |
| Camera clips set-pieces or UI | Camera limits not extended near vault door / timed gate / reserve |

## Hard rules (non-negotiable)

1. **Do not claim FIXED without a hard-refreshable live build** (or an honest "local only" STATUS line).
2. **Do not invent art.** Use existing founder goldmine / Fort Knox references under `founder-art/` and already-wired vault art. Muapi only via `game-aesthetics-forge` when the prompt explicitly authorises new generation.
3. **Gap widths must stay jump-legal.** Measure against the real single-jump apex (~92px) and sprint speed (240). Distinctness must not make the stage unfinishable.
4. **Main path must be walkable.** After any layout edit, a grounded player holding Right on flat `ground_segments` must not be blocked. Invisible blockers are a hard fail (T4 class).
5. **Run `level-distinctness-checker` after geometry edits.** Geometry that is >70% coordinate-shared with L2 is a FAIL.

## Platform layout checklist

Work in this order:

### 1. Rhythm audit (read-only first)

```bash
# Ground spans (x, width) and platforms
sed -n '/^ground_segments/,/^])/p;/^platforms/,/^])/p' src/resources/level_03_data.tres
# Compare to L2
diff <(sed -n '/^ground_segments/,/^])/p' src/resources/level_02_data.tres) \
     <(sed -n '/^ground_segments/,/^])/p' src/resources/level_03_data.tres) || true
```

Target feel for Gold Rush:

- Longer continuous runs between pits (mine road / claim trail), not L2's frequent crystal-stepping.
- Height variance that serves a purpose (timed-gate approach, vault door approach, cart lane), not decorative hops.
- At least one **wide safe runway** into the boss arena so chase reads clearly.

### 2. Fairness bounds

| Constraint | Value |
|------------|-------|
| Max pit width on main path | Must be clearable at full run + single jump from the lip |
| Platform thickness | Keep ≥20px playable surface (existing convention) |
| Ladder top-exit | Must land centre of a real platform (see `ladder-top-exit-guard`) |
| Prop / door x | Must sit on a solid `ground_segments` span, never in a gap |

### 3. Density / clutter pass

- Every spawn in `enemy_spawns`, `collectible_spawns`, `powerup_spawns`, `melt_forges`, carts must have a **gameplay function**.
- If two power-ups share art, fix art (already burned us once with big_axe / pickaxe).
- Prefer removing or relocating unclear props over adding more "atmosphere" objects.
- GoldMine tokens and wBTC stay; random orange rectangles that are not protocol coins go.

### 4. Palette & identity (aesthetics)

Stage 3 language (locked by prior sessions):

- Body: dark brown / rust (`platform_body_color` already ~0.18, 0.09, 0.04)
- Lip: gold (`platform_lip_color` ~0.95, 0.75, 0.2)
- Accents: Bitcoin orange (247,147,26) only on real BTC / wBTC surfaces
- Atmosphere: existing gold-dust particles; do not add cyan crystal language
- Fort Knox door + Assay Hall: steel + gold, never diamond-cyan

When editing `level_base` rendering paths, confirm L1/L2 still use their own colours (identity fields on the resource, not hardcoded defaults).

### 5. Camera / readability (T5 class)

If a set-piece or nameplate is clipped:

- Prefer extending camera limits when the player approaches the region
- Or move the prop fully onto solid ground inside the current camera box
- Do not add a permanent full-screen zoom that hurts the rest of the stage

## Set-piece anchors (do not break)

These are Stage 3's identity; layout work must keep them reachable and readable:

| Set-piece | Approx x | Role |
|-----------|----------|------|
| Timed Gold Gate + pressure plate | ~1180 plate / ~1520 gate | Headline "Gold Rush" race |
| Fort Knox vault door | ~2690 | Full separate realm entrance |
| Gold Rush Reserve (Hall of Blaze skin) | ~3420 | Pre-boss community room |
| Boss arena | 3700–4400 | Claim Jumper |

After moving any of these, re-verify pathing and `boss_arena_reachable` / vault gates.

## Verification (minimum)

1. `level-distinctness-checker` → DISTINCT (not RESKIN RISK)
2. Geometry walk probe: grounded Right-hold across each main `ground_segments` span with no invisible stop
3. Existing gates that must stay green: `stage3_defence`, `boss_arena_reachable`, `script_compile`, Security Sentinel
4. If founder screenshots exist for T4/T5: fix the circled region specifically, not a global "should be fine" claim
5. STATUS honesty: layout FIXED only after live build + hard-refresh path is available

## Anti-patterns

- Shipping a colour-only pass and calling layout fixed
- Raising boss speed instead of fixing platform readability
- Copying L2 platform array with ±50px nudges
- Claiming T4/T5 fixed when founder screenshots were never attached
- Expanding into Episode 2, new economies, or S2 vault work under a Stage 3 layout prompt

## Output for STATUS

```
Stage 3 layout: <CHANGED | UNCHANGED>
Geometry vs L2: <DISTINCT | RESKIN RISK | DUPLICATE>
Walk-path blockers: <none | list>
Clutter removed/relocated: <list>
Palette/camera: <what changed>
Gates: <results>
Still needs founder eyes: <list>
```
