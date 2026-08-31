<!-- dispatched: anthropic/claude-fable-5
     prompt: prompts/partb-fable-implementation.md
     files inlined: 5
     tokens: 14229 in / 11619 out
     cost: $0.7232
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
# Part B implementation plan — Diamond Vault (L2) + Fort Knox (L3)

## 1. One parametric scene — agreed, with three exports

One `src/level/protocol_vault.tscn` + `protocol_vault.gd` (new files). The two vaults are structurally identical (floor + walls + ladder + coin cluster); only palette, mouth dressing, and coin id differ. This matches existing precedent: `hall_of_blaze` is already reused parametrically via `room_title`, and `ladder.gd` via exports. Exports:

```gdscript
@export var protocol: String = "diamonds"   # "diamonds" | "gold"
@export var mouth_width: float = 100.0      # L2 pit=100, L3 pit=140
```

Everything else derives. Only reason to split into two scenes would be heavy bespoke art per vault — we have none (procedural ColorRects, same as ladder rungs / `_create_platform`). Stay parametric.

## 2. Procedural StaticBody2D children in `_ready()` — yes

Match `_create_platform`'s pattern exactly: StaticBody2D, `collision_layer = 1`, RectangleShape2D with `col.position = size/2`. Vault origin = **mouth centre at the surface line**.

**Diamond Vault, absolute coords (origin (2450, 650), L2 gap 2400–2500):**

| Node | Rect (x, y, w, h) absolute | Local position |
|---|---|---|
| `Floor` StaticBody2D | 2340, 800, **220**, 40 | (-110, 150) |
| `WallL` StaticBody2D | 2340, 700, **40**, 100 | (-110, 50) |
| `WallR` StaticBody2D | 2520, 700, **40**, 100 | (70, 50) |

Interior: x 2380–2520 (140 wide, 40px wider than the mouth), y 720–800.

**Why the player cannot reach the y≈825 kill band:**
- **Walls overlap the segment undersides by 20px vertically** (walls span y 700–800; segments span 650–720) and sit fully under solid ground horizontally (2340–2380 under seg 2000–2400; 2520–2560 under seg 2500–3000). No diagonal seam exists at any corner.
- **The floor spans the full outer width (2340–2560), so both walls stand ON the floor** — zero seam at the wall/floor junction. Even a hypothetical corner clip lands on floor, not kill band.
- Tunneling is impossible: max fall = 12px/frame vs 40px floor; max walk ≈ 3.3px/frame vs 40px walls.
- Player feet on the floor = y 800, centre 784 → 25px above the 825 kill-band top. Floor body extends to 840, into the band — irrelevant: kill zone `collision_mask = 2` (player only), StaticBody is never detected. **No kill-zone edits needed.**

Fort Knox (origin (2690, 650), pit 2620–2760): Floor 2560,800,260,40; WallL 2560,700,40,100; WallR 2780,700,40,100; interior 2600–2780.

## 3. Mouth: no widening, no guide walls needed

Player is 32 wide; mouth is 100 (L2) / 140 (L3) → 68/108px of slack. A drop through requires centre ∈ [2416, 2484] on L2 — trivially achievable. Critically, **the interior (2380–2520) is wider than the mouth (2400–2500)**, so a player hugging a mouth edge on the way down falls into open air, never onto a wall shoulder — the mouth is the narrowest point and they've already cleared it. Segments (y 650–720) present only flat tops and vertical faces; a player overlapping the lip lands on top at 650, never snags mid-face. The "frame" (crystal facets vs steel hatch) should be **non-colliding decor children** (ColorRect/Polygon2D, same technique as `_draw_rungs`) at the mouth lip — identity signalling only.

## 4. Ladder exit arithmetic

**Diamond Vault** — exit onto seg (2500, 650, 500, 70):
- `global_position = Vector2(2450, 630)` (top, mouth centre; 44px zone = 2428–2472, inside mouth 2400–2500 ✓)
- `height = 180.0` → bottom_y = 810, overlapping the standing player (centre 784, feet 800) so the grab works from the floor ✓
- Landing target: 60px in from the pit edge, 20px above surface (project convention): **(2560, 630)**. Player ±16 → 2544–2576, fully on seg 2500–3000, 44px clear of the pit. NOT over air.
- `top_exit_offset = (2560, 630) − (2450, 630) =` **`Vector2(110, 0)`**

**Fort Knox** — exit onto seg (2760, 650, 460, 70):
- `global_position = Vector2(2690, 630)`, `height = 180.0` (zone 2668–2712 inside mouth 2620–2760 ✓)
- Target **(2820, 630)** → player spans 2804–2836 on seg 2760–3220, 44px clear of the pit.
- `top_exit_offset = Vector2(130, 0)`

Note both offsets = `Vector2(mouth_width / 2.0 + 60.0, 0)` — derive it in `protocol_vault.gd` so the offset can never drift out of sync with placement (this is the exact class of bug that broke Stage 2).

## 5. Reward hook: 5 protocol coins per vault

```gdscript
var coin_id := "coin_diamonds" if protocol == "diamonds" else "coin_goldmine"
```
- **2 shaft coins** collected during the fall (juicy entrance): local y = 50 and 90 below origin (abs y 700/740), x = origin ± 25 → 50px apart ✓ (44px triggers need ~48px separation, per L2's own comment).
- **3 floor coins** at 34px above the floor (abs y 766, matching the existing `+Vector2(0,-34)` convention): L2 x = 2402, 2450, 2498 (interior faces 2380/2520, coin half-trigger 22 clears both). L3 x = 2630, 2690, 2750.

5 tokens ≈ parity with each level's route trail (L2's one-way chain gives 5 `coin_diamonds`) — a meaningful detour reward without doubling protocol income. One caveat: I don't have the coin persistence/respawn behaviour in the provided files — I'm assuming vault coins behave like the route coins (one-time pickups). If they respawn per level entry, say so and I'll cut to 3.

## 6. Wiring — exact edits

**`level_02_crystal_caverns.gd`**, end of `_setup_depth_routes()`:
```gdscript
	# DIAMOND VAULT — downward set-piece under the 2400-2500 pit (Part B).
	var diamond_vault := preload("res://src/level/protocol_vault.tscn").instantiate()
	diamond_vault.protocol = "diamonds"
	diamond_vault.mouth_width = 100.0
	diamond_vault.global_position = Vector2(2450, 650)
	add_child(diamond_vault)
```
Conflict check (x 2340–2560): one-ways end at x=1850 (coins to 1902), ladders at 1420/3060, secret walls at 468/1968/3468, blaze portal at (2100, 280). **Clear.**

**`level_03_gold_rush.gd`**, end of `_setup_depth_routes()`:
```gdscript
	# FORT KNOX — downward vault under the 2620-2760 pit (Part B).
	var fort_knox := preload("res://src/level/protocol_vault.tscn").instantiate()
	fort_knox.protocol = "gold"
	fort_knox.mouth_width = 140.0
	fort_knox.global_position = Vector2(2690, 650)
	add_child(fort_knox)
```
⚠️ **Do not name the local `vault`** — `_setup_depth_routes()` already declares `var vault` for the hall_of_blaze instance; a redeclaration is a GDScript parse error. Conflict check (x 2560–2820): secret wall at 2468 (clear by ~70px + its own extent — it sits at y 586 over the 2400s, west of our floor edge 2560), gold lane ends at 2300, hall_of_blaze at 3420, blaze portal at (2600, **300**) — horizontally overlapping our left wall but 300+px above anything we build (our highest element is the ladder top at y 630). **Clear.**

## 7. Fort Knox name collision — rename the alcove, keep the founder's identity

Founder locked **"Fort Knox = downward vault"**, so the new drop-in owns the name. One-line edit in `level_03_gold_rush.gd`:

```gdscript
	vault.room_title = "— THE MOTHERLODE CLUB —"   # was "— THE FORT KNOX VAULT —"
```

The alcove is the wallet-gated *spectacle lounge* (Hall-of-Blaze pattern) — "Motherlode Club" keeps the gold-rush flavour and the exclusivity read, while "FORT KNOX" appears exactly once in the level, on the playable downward vault where the founder put it. Re-titling the new one instead would ship two things called Fort Knox for a transition period and contradict the locked design table.

**Missing facts flagged:** coin respawn/persistence behaviour (assumed one-time); no dedicated mouth-frame sprite assets exist in what I was given (plan uses procedural decor); `EntitySpawner.spawn` signature confirmed by existing usage only — I've matched it exactly.