<!-- dispatched: x-ai/grok-4.6
     prompt: artifacts/dispatch_2026-08-25_boss1_phases_block/02_GROK.md
     files inlined: 1
     tokens: 3133 in / 28051 out
     cost: $0.1746
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
**Resolution: (a) level-geometry nudges. Everything stays solid. No phasing, no one-way, no collision-shape toggle.**

Reject global one-way (player fall-through + boss walk-through — already measured).  
Reject permanent / broad platform exceptions (current live bug).  
Reject (b): a mid-vault width change is the same class as a collision toggle (tunneling, one-frame overlap, “sealed in a deck”). A 220px sprite with a thinner hitbox also lets the player occupy the visual body during the vault.  
Reject (c) as the primary fix: standing on `(1100,450)` puts head at **230**; `(1400,350)` is still inside the torso. Climbing does not avoid the clip without the same nudges, and it adds ascent/sky-float/wedge states.  
Do not raise LEAP.

---

## 1. Geometry (exact)

Boss grounded AABB: **220×220**, feet **650**, head **430**. A cyan rect is a **WALL** if it intersects y∈[430,650]. It is **OVERHEAD** if `y+h ≤ 430`.  
Rule used: every WALL cluster vs every y-overlapping OVERHEAD has **gap ≥ 220**, and sequential WALL clusters are also ≥ 220 apart so a 220 body can stand on ground between them (this is the unlisted W3–W4 squeeze: 950–982 vs 1100–1200 is only 118px today).

**Keep every overhead at the same Y** so player jump heights do not change. Move WALLS into three corridors. Slide only the two overheads that sit <220px from an immovable wall (`W4` stays — checkpoint `(1100,500)`, trap `(1160,480)`).

```
platforms = [
  Vector4(80, 500, 100, 20),    # was (300,500,100,20)  early WALL
  Vector4(500, 400, 100, 20),   # unchanged
  Vector4(750, 350, 120, 20),   # unchanged
  Vector4(1100, 450, 100, 20),  # unchanged  mid WALL
  Vector4(1440, 350, 100, 20),  # was (1400,350,100,20)  gap W4→P3 = 240
  Vector4(1700, 400, 100, 20),  # was width 150; right edge 1800
  Vector4(2280, 300, 100, 20),  # was (2100,300,100,20)  over pit 2200–2300
  Vector4(2600, 350, 100, 20),  # unchanged
]
breakable_blocks = [
  Vector2(200, 500),   # was 850   early cluster, right=232
  Vector2(240, 500),   # was 950   early cluster, right=272
  Vector2(1136, 500),  # was 1350  mid cluster on W4
  Vector2(1168, 500),  # was 1750  mid cluster, right=1200
  Vector2(2020, 500),  # was 1850  late WALL 2020–2052
]
```

**Pickup x/y that must follow decks** (same resource; otherwise coins float or sit inside a deck):

| Spawn | Old | New |
|---|---|---|
| coin on W1 | (320, 450) | (100, 450) |
| coin_eth / ring over P1 | (520, 350), (500, 250) | unchanged (P1 did not move) |
| torch / ring / coin on P3 | (1400, 300), (1400, 250), (1420, 300) | (1460, 300), (1460, 250), (1460, 300) |
| coin_eth on P4 | (1720, 350) | unchanged (still on 1700–1800) |
| coin / shard on P5 | (2120, 250), (2100, 200) | (2300, 250), (2300, 200) |

`weed_leaf (400,550)`, checkpoints, traps, enemies, arena `(3100,500)` stay.

**Companion code change (required, not an exception):** delete the shipped overhead collision exception / mask special-case so boss vs every cyan rect is solid. That file was not in this prompt — do not invent the symbol; grep the exception and remove it.

### Clip pairs — resolved

| Vault (WALL) | Neighbour | Old gap / problem | New |
|---|---|---|---|
| (300,500) → now early 80–272 | (500,400) | 100px + pit; body reaches it | gap **228** (272→500) |
| (1100,450) 1100–1200 | (1400,350) | 200 < 220 | P3 at 1440; gap **240** |
| cubes 850/950 vs (750,350) | x-overlap underside | cubes moved off that deck | P2 has **no** nearby WALL |
| 1350 vs (1400,350) | gap 18 | cube → mid cluster | gone |
| 1750/1850 vs (1700,400) | x-overlap | late cube at 2020; P4 right=1800 | gap **220** |
| 1850 vs (2100,300) | gap 218 | P5 at 2280; cube right=2052 | gap **228** |
| 950–982 vs 1100–1200 | ground gap 118 (cannot stand) | no WALL in 272–1100 | ground gap **828** |

Grounded head is 430; all remaining decks are at y≤400. Boss **walks under** them. Spacing is the three WALL clusters (constraint 3): early ~x80–272, mid 1100–1200, late 2020–2052. Player takes the high road and pulls distance while he vaults.

### Player platforming

- No deck Y changed → same jump heights as shipped.
- 100px pits (400–500, 1300–1400, …) are still ground-jumpable; `(300,500)` was never the only pit cross (ground exists on both sides).
- P4 still 100px wide (matches most decks). P5 now sits on pit 2200–2300 — better bridge, not worse.
- First-island WALL moved left; ground `0–400` still carries the player. Verify the `(100,450)` coin is still reachable from ground / new W1.

If a designer refuses to move W1 off `(300,500)`, the only other solid option is **raise** `(500,400)` to `y≤250` (stand-on-W1 head=280). That needs a player jump of **250px from W1 / ~400px from ground**. Jump height is **not in the provided files** — do not ship a raise without measuring it. Prefer the W1 x-move above.

---

## 2. Gauntlet (pass/fail)

Measure the **live 220×220 body** vs live platform/breakable rects. No raycast-as-proxy, no “gap looks open,” no exception list.

| Gate | PASS | FAIL |
|---|---|---|
| **Player-solid-land** | On each of the 8 decks + 5 cubes, player `is_on_floor()` with feet on `platform.y`, no pop-through, can walk the full top | Any deck the player drops through or cannot stand on |
| **Player-no-fallthrough** | Same, plus run/jump onto every deck from both sides and from below (head-bonk then land). One-way off. | Any downward pass through a 20px deck |
| **Stage-1 return path** | From arena `start_x=2800` back through mid and early clusters, player can re-traverse pits + decks to x=0 without new softlocks | Return blocked by moved WALL/P5 or missing step |
| **Auditor grounded (sky~0)** | After spawn-to-arena chase: time with feet > 40px above any support ≈ 0 except during vaults; no hover at y≪430 | Sky-float, ceiling pin, or climb that does not land |
| **Every cyan solid-to-boss (BODY)** | For each of 8+5 rects: drive the real body so it *would* intersect that rect if collision were off. Body never contains the rect centroid; far-side x is unreachable unless feet reach that rect’s top or the AABB fully clears it. Intersection area while penetrating (not standing on top) = 0 after the solver step. | Any rect the AABB center crosses; any exception/mask still on |
| **Auditor hunt (closes, no pin)** | From player at arena and from player mid-stage: boss x-gap to player falls to melee range in the existing hunt timeout; not stuck 46s on a WALL; no pin at a 220 flush corridor | Timeout with wall overlap, or x frozen while player is reachable on ground |
| **Boss 3 regression** | Boss 3 suite unchanged: no shared one-way, no shared width hack, no shared LEAP bump | Any Boss 3 collision/hunt/sky fail |
| **Full suite + security** | Existing unit/integration/security suite green after the `.tres` nudge + exception deletion only | New fail, or leftover debug invuln / mask cheat |

Also assert **zero** boss-vs-platform exception entries at runtime (the thing that made the current build look fine).

---

## 3. Eight fails hidden by “hunt closes gap”

1. **Exception / mask off on overheads** — x-gap closes because he walks through decks (today).  
2. **Sky-float** — x closes above the course; grounded auditor never ran.  
3. **Wedge inside a neighbour** — vx still creeps toward the player; vy runaway; hunt “closing.”  
4. **46s WALL pin** — timeout longer than the pin, or hunt only sampled in the arena.  
5. **Global one-way** — boss hunt green, player falls through every thick deck.  
6. **Target-only phase** — scripted wall is solid; neighbour overhead is not; founder circles that one.  
7. **Width shrink during vault** — hunt closes; player walks through the sprite on the same deck.  
8. **Raycast / nav-gap gate** — reports a 220 hole while the live body is still intersecting (the exact cheat that blessed prior vault-phase fixes).

---

## 4. The ungameable measurement

**Per physics frame, on the real boss `CollisionShape` AABB vs every cyan rect: `intersection.area == 0` unless the contact is a floor (feet on `rect.y`, `vy ≥ 0`, penetration ≤ skin).**  

Fail the build if, for any rect, the AABB **sweeps across that rect’s interior** (centroid x enters the body, or integral of `|vx|` while intersecting a non-floor contact > ~4px).

That single predicate fails the current live state (permanent overhead exception ⇒ large interior overlap while walking). It does not care that hunt closed. It cannot be satisfied by a raycast, a disabled mask, or a one-way.