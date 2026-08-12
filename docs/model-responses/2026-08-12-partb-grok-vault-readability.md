<!-- dispatched: x-ai/grok-4.5
     prompt: prompts/partb-grok-readability.md
     files inlined: 3
     tokens: 4287 in / 2172 out
     cost: $0.0216
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
## 1. Distinct silhouette per protocol

### Diamond Vault (S2) — DROP-IN MOUTH
- **Frame:** 4–6 `Polygon2D` facets as a jagged crystal collar around the pit (gap 2400–2500). Facets point *inward/down*, not up — reads as a cut gem mouth, not stalactites.
- **Colors:** facet faces `Color(0.45, 0.95, 1.0, 0.85)` / edge chips `Color(0.75, 0.55, 1.0, 0.7)` / deep core `Color(0.15, 0.35, 0.55, 0.9)`.
- **Lip:** thin prismatic rim `ColorRect` strip ~8px tall, full mouth width, `Color(0.6, 1.0, 0.95, 0.55)`.
- **Signature VFX:** `CPUParticles2D` — slow-falling sparkle motes (small rects), cyan→white, drift *down into* the shaft (not up). Count ~12, lifetime ~1.8s.

### Diamond Vault — INTERIOR (~300×150)
- Walls: faceted `Polygon2D` panels, alternating `Color(0.2, 0.45, 0.55)` / `Color(0.35, 0.25, 0.5)`.
- Floor surface y≈800: cool stone `Color(0.18, 0.28, 0.38)`.
- Reward: `coin_diamonds` cluster, centered, under a single large diamond `Polygon2D` (rhombus) ceiling gem `Color(0.55, 0.95, 1.0, 0.7)`.
- Ladder: cyan rung tint `Color(0.4, 0.85, 0.95)` so exit reads as crystal lattice, not wood/steel.

### Fort Knox (S3) — DROP-IN MOUTH
- **Frame:** rectangular steel hatch — two `ColorRect` door leaves parted left/right (or a single open hatch flap as a thick L-bracket on one side). Rivet dots = small 4×4 `ColorRect`s.
- **Colors:** plate `Color(0.45, 0.42, 0.38)` / brass trim `Color(0.85, 0.65, 0.25)` / shadow gap `Color(0.12, 0.1, 0.08, 0.95)`.
- **Lip:** brass threshold bar full width, ~6–10px, `Color(0.9, 0.7, 0.3, 0.9)`.
- **Signature VFX:** `CPUParticles2D` — sparse amber dust / coin-glint motes, slow horizontal shimmer across the mouth (not falling like diamonds). Warm, heavy, metallic.

### Fort Knox — INTERIOR
- Walls: flat steel panels `Color(0.32, 0.30, 0.28)` + vertical brass strips every ~40px `Color(0.75, 0.55, 0.2)`.
- Floor: dark bank-stone `Color(0.25, 0.22, 0.15)`.
- One vault-door silhouette on the back wall (circle + bar `Polygon2D`/`ColorRect`) — pure decor, non-interactive.
- Reward: `coin_goldmine` cluster under a brass bar lintel.
- Ladder: steel/brass rung tint `Color(0.7, 0.55, 0.25)`.

**Anti-confusion vs existing entrances**
| Entrance | Axis | Silhouette | VFX |
|---|---|---|---|
| Blaze Portal | horizontal | smoke-ring torus (rounded rect hole) | green/magenta pulse |
| Smoke Lounge | horizontal alcove | soft golden shimmer rect | faint alpha pulse 0.05–0.14 |
| Diamond Vault | **down** | jagged cyan crystal collar | downward prismatic motes |
| Fort Knox | **down** | rect steel hatch + brass lip | amber horizontal glints |

No torus. No soft full-alcove shimmer. Downward axis alone already separates them; crystal facets vs riveted hatch seals protocol ID.

---

## 2. “Go down here” vs lethal pit

Pits in this game are bare gaps in `ground_segments` with no frame. Vault mouths need **built architecture sitting on the pit rim**:

1. **Collar / hatch frame on the walk surface (y=650)** — crystal facets or steel+brass hatch visibly *built around* the hole. Pits have zero trim.
2. **Inward light well** — a vertical `ColorRect` shaft glow below the mouth (diamonds: cyan `Color(0.3, 0.8, 0.9, 0.12)`; gold: amber `Color(0.9, 0.7, 0.25, 0.1)`), ~80–120px tall. Pits are dark void into the kill band; vaults glow *with a floor visible* at y≈800.
3. **Readable floor at the bottom** — even from above, a lit chamber floor strip must be visible through the mouth (parallax-free, same 2D plane). If the player sees ground + reward sparkle below, it is not a death pit.
4. **Beckon chevron** — one small downward chevron/`Polygon2D` arrow above or on the lip, protocol-colored, slow bob (~4px, 0.8s loop). No text.
5. **Lip treatment** — raised brass/crystal threshold (item 1) breaks the “floor just ends” pit silhouette. Optional: 1–2 short safety teeth / posts at left and right rim so the mouth reads as a doorway, not a collapse.

Do **not** rely on particles alone — bare pits can have dust. The frame + visible interior floor + downward chevron is the triad.

---

## 3. Interior legibility @ ~300×150

Minimum decor (anything more crowds 32×32 player + ladder):

| Element | Budget | Role |
|---|---|---|
| Back-wall identity panel | 1 shape (diamond rhombus **or** vault-wheel) | “designed room” |
| Side wall tint | 2 `ColorRect`s or flat wall color | enclosure vs open pit |
| Floor surface | solid segment y≈800 | stops fall; reads as ground |
| Reward cluster | 1 centered coin group | goal, pulls eye down-center |
| Ladder | full height, protocol-tinted, against one wall | exit — must clear silhouette from mouth view |
| Optional: 2 corner rivets / 2 crystal chips | tiny | vault language without clutter |

**Layout (top-down read when player is at mouth):**
- Ladder flush to **one** side (prefer exit-side toward the landing segment — L2 right onto 2500+, L3 right onto 2760+).
- Reward **center-floor**, not under ladder.
- Identity panel on back wall, upper third — visible from mouth before drop.
- No floating labels required for min-viable; title float on first enter is optional and should not block the 150px height.

Player feet stop ~800; kill band starts ~825 — floor is the guard (per shared facts). Ladder `top_exit_offset` must land on solid segment surface y=650 or player soft-locks back down.

---

## 4. “Fort Knox” name collision

**Problem:** L3 already places `hall_of_blaze.tscn` with `room_title` usable as `"— THE FORT KNOX VAULT —"` (horizontal, wallet-gated, spectacle-only, no playable reward/exit). New set-piece is also founder-locked as **Fort Knox** (downward, playable, ungated).

**Clean split:**

| Thing | Label | Role |
|---|---|---|
| New downward drop-in | **FORT KNOX** (or `— FORT KNOX —`) | Playable GOLD MINE protocol vault. Owns the name. |
| Existing `hall_of_blaze` on L3 | **— GOLD RUSH RESERVE —** or **— THE BULLION GALLERY —** | Spectacle / wallet-gated community alcove. Keep script, change `room_title` export only. |

Rationale:
- Founder locked the *playable* downward piece as Fort Knox — that name stays on the interactive vault.
- The alcove is already a themed *reuse* of Hall of Blaze (`room_title` is an `@export`; L1 keeps `"— THE HALL OF BLAZE —"`). L3 title was always a skin, not a separate system.
- Avoid “Fort Knox” substring on the alcove entirely so UI floats / metrics / player callouts never collide.
- Do not rename the playable vault to “Gold Vault” — that weakens GOLD MINE identity next to Diamond Vault’s parallel naming; fix the spectacle label instead.

**Claude’s implementation sketch:** reusable `protocol_vault.tscn` parametric on `"diamonds" | "gold"`, placements over L2 2400–2500 and L3 2620–2760, ladder onto the right-hand segment — consistent with shared facts. Only mandatory extra: rename L3 hall_of_blaze `room_title` away from Fort Knox.

---

**Missing (if you want pixel-exact node recipes next):** no `protocol_vault.tscn` / art pass file was provided — above is buildable from ColorRect/Polygon2D/CPUParticles2D only, per your constraint. I did not invent engine APIs beyond what appears in the facts and the two entrance scripts.