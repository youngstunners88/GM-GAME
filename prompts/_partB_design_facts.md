## PART B — Diamond Vault (S2) + Fort Knox (S3) downward set-pieces — SHARED FACTS

Locked founder design (do not renegotiate):
| Stage | Protocol | Set-piece | Entrance |
|-------|----------|-----------|----------|
| 2 Crystal Caverns | DIAMONDS | **Diamond Vault** | **Downward** crystal shaft / floor opening |
| 3 Gold Rush | GOLD MINE | **Fort Knox** | **Downward** fortified hatch / vault shaft |

Rules: set-pieces / strong hubs, NOT full stage wipes. Player jumps or drops
DOWN in. **Exit upward required (no soft-lock).** Distinct from Blaze Rush
entry and Smoke Lounge entry (silhouette, VFX, interaction). Readable protocol
identity. Min-viable: enter -> readable interior -> at least one protocol-
flavored interactable/reward -> exit back to stage route. Gates: can enter,
can exit, no soft-lock; optional collectible/score hook.

### Real engine facts (measured from the repo, trust these numbers)

- Player: CharacterBody2D, main collision **RectangleShape2D 32x32** (±16 from
  centre). `walk_speed=200`, `gravity=1000`, `max_fall_speed=720` (~12px/
  physics frame @60Hz), `jump_force=-430` (single-jump apex ≈ **92px**),
  `double_jump_force=-370`, `climb_speed=150`.
- **A single jump only clears ~92px**, so a >100px upward exit MUST use a
  ladder (or one-way step platforms spaced ≤90px). Ladders are the proven
  exit mechanic here.
- Ladder (`src/level/ladder.tscn`): Area2D 44px wide × `height` tall. Player
  enters CLIMB by pressing up/down inside the zone; `climb_speed=150`; on
  top-out the player is teleported to `global_position + top_exit_offset`.
  `top_exit_offset` MUST land on a solid floor segment or the player falls
  straight back down (this exact bug blocked Stage 2 progression before).
- Ground is built from `level_data.ground_segments` = `Array[Vector4](x, y,
  w, h)`; walk surface at **y=650**, segment body extends to y=720.
- **Kill zone** (`level_base.gd::_setup_kill_zone`): ONE full-width Area2D,
  `RectangleShape2D(bounds.x, 400)` centred at `kill_zone_y+175` = 850+175 =
  1025 → occupies **y≈825..1225 across the whole level width**. Falling below
  ~825 triggers `pit_death()` (costs a LIFE). **A solid chamber floor with its
  surface at y≈800 sits ABOVE the kill band and physically stops the player at
  ~784 (centre) / 800 (feet), 25px clear of the 825 trigger — so a recessed
  chamber needs NO kill-zone edits; the solid floor is the guard.**

### L2 ground segments (Vector4 x,y,w,h), surface y=650:
(0,650,400,70)(500,650,300,70)(900,650,500,70)(1500,650,400,70)
(2000,650,400,70)(2500,650,500,70)(3100,650,400,70)(3700,650,700,70=boss arena)
Gaps (pits): 400-500, 800-900, 1400-1500 (ladder1 here), 1900-2000, **2400-2500**,
3000-3100 (ladder2 here), 3500-3700. Boss arena starts x=3700.

### L3 ground segments, surface y=650:
(0,650,400,70)(520,650,320,70)(1020,650,480,70)(1600,650,380,70)
(2200,650,420,70)(2760,650,460,70)(3380,650,100,70)(3700,650,700,70=boss arena)
Gaps: 400-520, 840-1020, 1500-1600, 1980-2200, **2620-2760**, 3220-3380, 3480-3700.
NOTE: an EXISTING token-gated "— THE FORT KNOX VAULT —" alcove
(`hall_of_blaze.tscn`, horizontal spectacle room, wallet-gated) is already
placed at x=3420 on the narrow seg6. The NEW downward Fort Knox is a DIFFERENT,
playable, ungated drop-in — flag the name collision.

### Existing entrances the new set-pieces must be DISTINCT from
- **Blaze Portal** (`blaze_portal.gd`): horizontal Area2D, score-gated, loads a
  SEPARATE scene (Geometry-Dash run) via `SceneRouter.load_scene`. Smoke-ring
  torus silhouette.
- **Smoke Lounge / Hall of Blaze** (`hall_of_blaze.gd`): horizontal wallet-
  gated alcove, golden shimmer, spectacle room, no reward/exit-puzzle.
- **Secret Realm** (`secret_door.gd`): Area2D → loads a SEPARATE realm scene.
All three are horizontal + scene-loading. The new vaults are **in-level,
physical downward drops with an upward ladder exit — no scene load.**

### Claude's proposed implementation (validate or correct this)
- ONE reusable `protocol_vault.tscn` + `protocol_vault.gd`, parametric by
  protocol ("diamonds" | "gold"): builds its own chamber StaticBody floor
  (surface y≈800) + two side walls under an existing pit mouth, a distinct
  identity frame at the mouth (crystal facets vs fortified steel hatch),
  interior decor, a protocol-coin reward cluster (`coin_diamonds` /
  `coin_goldmine` via EntitySpawner), and a ladder exit whose `top_exit_offset`
  lands on the adjacent floor segment.
- Diamond Vault: placed over L2 gap **2400-2500**, exit ladder onto seg 2500-3000.
- Fort Knox: placed over L3 gap **2620-2760**, exit ladder onto seg 2760-3220;
  rename the existing hall_of_blaze reuse to avoid two "Fort Knox" labels.
