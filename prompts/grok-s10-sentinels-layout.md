# Design brief — Lil Blunt Adventure, Session 10 vault set-pieces & camera

## What the game is
A Godot 4.3 HTML5 2D platformer marketing three crypto protocols (SMOKE /
DIAMONDS / GOLD). Hero: Lil Blunt, a chill weed-nugget. It has three campaign
stages plus two protocol "vaults" — the **Diamond Vault** (DIAMONDS staking)
and **Fort Knox** (GOLD staking). Both vaults are ONE parametric scene
(`vault_realm.gd`), switched by `protocol` = "diamonds" or "gold".

## The founder's live complaints (Session 10), verbatim intent
1. **A golden machine appears in the Diamond Vault and must NOT.** The Diamond
   Vault must be diamond/cyan-themed only; a gold-themed instrument does not
   belong there.
2. **DIAMOND VAULT SECURITY SENTINEL** — a threatening sentinel art asset
   already exists (`diamond_sentinel.png`). Right now it is placed as a giant
   ~300px-tall faint background emblem (z-index -6, behind gameplay), which
   reads as an oversized useless prop. The founder wants a *visible, smaller,
   threatening* Security Sentinel — and to replace a "useless triangle" that
   is currently in the scene. There is also a triangular hazard poly.
3. **FORT KNOX SECURITY SENTINEL** — same, using `fortknox_sentinel.png`,
   smaller than the current oversized emblem.
4. **Layout/camera**: a set-piece or label is still unreadable at the edge of
   the reachable area — either reposition it or extend camera/background so the
   stage stays coherent as Lil Blunt approaches.

## What exists right now (honest)
The relevant scene is inlined below. Key facts you must NOT "correct":
- Godot 4.3. Floor surface ~ y=600 (`SURFACE_Y`), floor collision ~648,
  realm width `BOUNDS`=2600. Player spawns at x=160.
- The camera limits are set in `_spawn_player()`: limit_left 0, limit_right
  BOUNDS, limit_bottom FLOOR_Y+160. There is NO top limit set, and the camera
  never widens — so tall/edge props can clip off-screen.
- `_setup_emblem(art, at, target_h)` draws the sentinel art as a background
  emblem with a bob tween, z-index -6, NO collision.
- Diamond Vault ALSO calls `_setup_diamond_scale(1250)` → `_build_gold_scale(
  node, true)` which draws `gold_scale.png` — **this is the golden machine that
  must be removed from the Diamond Vault.** Fort Knox legitimately keeps its
  gold scale (the Assay Scale).
- The hazard (`_setup_hazard`) is a moving Area2D that damages the player,
  drawn as a cyan **triangle** (diamonds) or orange rectangle (gold), sweeping
  x 1300→1480. Collision mask 2 (hits player), collision_layer 0 (does NOT
  block walking).
- Sentinel art files are square-ish PNGs ~1.7–2MB.

## The questions (answer each in 2–4 sentences, concrete numbers)
1. **Gold machine**: Confirm removing the `_setup_diamond_scale` call is the
   right move, and whether anything readable should replace it in the Diamond
   Vault so that spot isn't empty (or leave it to the sentinel). One line.
2. **Sentinel scale + placement**: Give a concrete target height (px) for the
   Security Sentinel sprite that reads as "threatening but not screen-eating"
   against a ~210px-tall clerk NPC and the ~200px player, and a world position
   that is on-camera and framed as a guardian of the vault (not hidden in a
   corner). Should it be the moving hazard itself (a patrolling guardian that
   deals contact damage) or a static menacing backdrop prop plus the existing
   hazard? Recommend ONE and say why.
3. **Triangle**: The founder calls a triangle "useless". Given the triangle is
   the damage hazard's *visual*, is replacing that visual with the sentinel
   sprite (keeping the damage) the cleanest read, or should the triangle just
   be redrawn as a small crystal shard and the sentinel be a separate static
   guardian? Recommend ONE.
4. **Camera/layout T5**: Give a concrete rule for keeping edge set-pieces
   readable — e.g. a top camera limit value, or repositioning props to a
   readable x-band, or widening limit_right. What's the smallest change that
   stops props clipping off the top/edge of the reachable frame?

## Hard constraints
- No new art, shaders, or frameworks. Reuse the existing PNGs and Polygon2D
  procedural drawing.
- Keep the Diamond Vault cyan and Fort Knox gold. Don't invent new systems.
- Don't break the stake/crush gameplay loop or the return portal.

## Output format
Numbered answers 1–4, each ≤4 sentences, with concrete px/coord numbers.
Then a 3-line "RISKS" section on what could look wrong on screen.

---

## The scene source (authoritative — do not assume anything not here)

@include src/level/vault_realm.gd
