<!-- dispatched: anthropic/claude-fable-5
     prompt: prompts/s3-fable-vault-interiors.md
     files inlined: 2
     tokens: 10007 in / 22290 out
     cost: $1.2146
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
# Vault Interiors v2 — Multi-Tier Spec

## 0. The threshold decision first: I'm arguing FOR kill-zone surgery

The 175px band (y 650→825) cannot honestly deliver "complete sections of their own":

- The level ground segments are solid from world y 650→720, so everything outside the mouth column has a **hard ceiling at y 720**. That leaves 720→800 = **80px of interior height** for all non-shaft space.
- In 80px, a second tier means a ledge at ~y 762 with **42px of headroom** over a 32px player, and jumping under that ceiling head-bonks after a **48px rise** (head 768→720), so the ~92px jump apex is unusable. You get shelves in a slot, not chambers.
- The founder's backdrops are 1024x576 painted *rooms*. A 150px letterbox crop wastes them.

**Proposed surgery is narrowly scoped and default-inert:** `level_base.gd::_setup_kill_zone()` gains a member `kill_zone_gaps: Array[Vector2]` (default `[]`, each entry = an x-range to skip). Instead of one full-width strip, it builds N Area2D strips with the **identical y band (kill_zone_y+175 ± 200) and identical mask/callback**, skipping the gap ranges. Zero gaps → one strip → byte-identical behavior for every level that doesn't opt in. Only L2/L3 register one gap each, exactly the vault's outer footprint. Safety inside the gap is provided by the vault itself: full-outer-width solid floor + walls sealed into the segment underside — the same "the floor is the guard" proof as last session, just deeper. No other level's pit logic changes.

This buys world y 650→~1000, i.e. **~305px of usable interior** → 3 real tiers with jump-legal deltas.

*(Fallback if the founder vetoes: a shallow 2-tier version fits the old band — floor top local y=150, ledges local y=112 (38px hops, legal under the 48px bonk limit), interior x ±240. I can produce those rects, but I don't recommend it.)*

---

## 1. Layouts (local space; origin = mouth centre on the surface line, +y down; world y = 650 + local y)

Tier surfaces: **155 / 230 / 305** (world 805 / 880 / 955). Deltas = **75px**, under the ~92px single-jump apex with margin. Chamber ceiling = the level segment underside at local y=70 (mouth column excepted). Floor bottom at local 345 (world 995) — inside the old kill band, hence the gap.

### Diamond Vault (protocol="diamonds", mouth_width=100, half=50) — interior x −240..+240

`_add_solid(center, size)` calls:

| Piece | center (local) | size | rect (x, y, w, h) |
|---|---|---|---|
| Floor (full outer width) | (0, 325) | (512, 40) | (−256, 305, 512, 40) |
| West wall | (−248, 202.5) | (16, 285) | (−256, 60, 16, 285) |
| East wall | (248, 202.5) | (16, 285) | (240, 60, 16, 285) |
| T1 landing shelf | (−40, 163) | (80, 16) | (−80, 155, 80, 16) |
| T2 west ledge (hoard) | (−160, 238) | (120, 16) | (−220, 230, 120, 16) |
| Crystal barrier (retractable — keep the returned body) | (−94, 150) | (12, 160) | (−100, 70, 12, 160) |

Walls top at local 60, overlapping the segment body (0..70) by 10px — same no-seam trick as today.

**Traversal:** drop through the mouth's west/centre → land T1 (155). East half of the mouth (x > ~16) is a clean "fast lane" straight to the floor beside the ladder (shelf ends at x=0; player at ladder x=28 spans 12..44 — clear). Floor → T2 west: 75px hop. T2 → T1: 75px up over a 20px horizontal gap (−100 → −80). Barrier seals T2-west vertically ceiling-to-ledge, so no airborne path from T1 sneaks in (any leftward arc from T1 sits inside y 70..230).

**Ladder:** unchanged x formula: `half − LADDER_INSET` = **x=28**, `height = 325` (floor 305 + 20), `top_exit_offset = (62, −16)` — still the constant `LADDER_LAND_PAST + LADDER_INSET`, still mouth-width-independent, `destructible = false`. Ladder column (≈x 18..38) is verified clear of all solids from 0..305.

### Fort Knox (protocol="gold", mouth_width=140, half=70) — interior x −280..+280

| Piece | center | size | rect |
|---|---|---|---|
| Floor | (0, 325) | (592, 40) | (−296, 305, 592, 40) |
| West wall | (−288, 202.5) | (16, 285) | (−296, 60, 16, 285) |
| East wall | (288, 202.5) | (16, 285) | (280, 60, 16, 285) |
| T1 landing shelf | (−55, 167) | (110, 24) | (−110, 155, 110, 24) |
| T2 west ledge (forge platform) | (−200, 242) | (130, 24) | (−265, 230, 130, 24) |
| T2 east ledge (alcove roof) | (185, 242) | (130, 24) | (120, 230, 130, 24) |
| Vault-door slab (openable) | (114, 279.5) | (12, 51) | (108, 254, 12, 51) |

The door slab seals the **reward alcove** under the east ledge (interior x 120..280, y 254..305 → 51px tall, fits the 32px player). Thicker 24px platforms = fortified identity vs Diamond's 16px crystal shelves.

**Ladder:** x = 70−22 = **48** (player span 32..64, clear of shelf ending at 0 and ledge starting at 120), `height = 325`, same offset constant.

---

## 2. Real art placement

**Backdrops — NOT ParallaxBackground.** `set_boss_background()`'s ParallaxBackground technique is a CanvasLayer: it fills the screen relative to the camera and would be visible across the whole level, not just inside the vault. Instead:

- Parent: a **ColorRect** sized to the interior (Diamond: pos (−240, 60), size (480, 285); Fort Knox: (−280, 60), (560, 285)), `color = Color(0.02,0.03,0.05)`, **`clip_children = CanvasItem.CLIP_CHILDREN_ONLY`**, `z_index = −10`.
- Child: **Sprite2D**, `diamond_vault_backdrop.png` at **scale 0.5** (512x288 covers 480x285) centered on the interior; `fort_knox_backdrop.png` at **scale 0.56** (573x323 covers 560x285). Clipped, spatially anchored, visible through the mouth before you drop, no bleed, healthy oversample per the facts.
- Readability: keep platform ColorRect bases fully opaque and add a 3px light "lip" strip along each platform top (cyan 0.9α / brass 0.9α). Solids at default z=0, props z −2..−1, backdrop −10 → gameplay geometry always reads over the painting.

**`diamond_deposit_pillar.png` (187x280):** Sprite2D at scale 0.5 (94x140), base on the Diamond floor east side — center **(150, 235)** (sprite spans y 165..305), z=−1. It's the **objective interactable** (mechanic in §4).

**`goldmine_melt_forge.png` (187x280):** Sprite2D at scale 0.5, base on Fort Knox's T2 west ledge — center **(−200, 160)** (spans y 90..230, fits under the y=70 ceiling), z=−1. The facts flag an existing `melt_forge` entity in `EntitySpawner` — **preferred: spawn that entity at (−200, 230) local and seat this sprite behind it as dressing**, reusing its proven interaction; its actual behavior isn't in the shared facts (see §6), so if it doesn't fit, the bespoke hold-to-activate below replaces it.

**`fort_knox_vault_door.png` (380x380):** the **openable gate** on the alcove — Sprite2D scale 0.28 (~106px), center **(114, 270)**, z=1, drawn over the slab (door reads bigger than the opening = fortified). On open: tween `rotation` +90° over 0.6s (wheel spin), then `position.x += 60` (slides along the alcove interior), and `slab_collision.set_deferred("disabled", true)`.

---

## 3. Hazards (one per vault, existing patterns only)

**Diamond — ceiling shard droppers (crystal security).** Two Polygon2D crystal clusters on the segment underside at local **(−160, 70)** and **(+160, 70)**. Every 2.5s: 0.6s glow telegraph (modulate tween), then drop a shard — Area2D + Polygon2D spike + constant downward velocity, `player.take_damage(1)` on overlap, freed on floor contact (same 1-damage contract dynamite uses). The +160 dropper sits directly over the deposit pillar, so activating it is a timing dance. If `distributor.gd`'s crystal-shard projectile is a standalone scene, reuse it; I don't have that file here to confirm the path (§6).

**Fort Knox — patrolling gear guard (gold security).** A rolling gear: Polygon2D toothed disc (r≈22) + constant `rotation` spin + Area2D (take_damage(1)), tweened back and forth along the floor between local **x −100 and +100** at ~110 px/s — it guards the lane between the ladder and the door alcove. Pure Node2D/Tween/Area2D, no new enemy class.

---

## 4. Progress loop & reward

Both vaults: **11 coins** (was 5), and the biggest chunk is gated behind an action.

**Diamond:** drop (2 shaft coins) → T1 → floor, dodging shards → 3 floor coins → **deposit pillar**: Area2D pad; stand on it 1.0s (Timer + a filling ColorRect progress bar; leaving resets it) → crystal barrier **shatters** (CPUParticles2D burst, collision disabled, Polygon2D fade) *and shard cadence tightens 2.5s → 1.6s* → climb floor → T2-west, collect the **6-coin diamond hoard** → ladder out. Interactable types beyond coins: pillar trigger + retractable barrier = 2. ✔

**Fort Knox:** drop (2 shaft) → floor past the gear → 3 floor coins → hop to T2-west, **activate the forge** (melt_forge entity, or 1.0s hold): forge "pours" (amber CPUParticles2D stream) and the **vault door opens** → cross the gear lane again, enter the alcove, **6-coin gold cache** → ladder. Interactables: forge + openable door = 2. ✔

No soft-lock: floor → ladder is always open regardless of objective state; ladder `destructible=false`; top-out math unchanged.

---

## 5. Exact code changes

**`protocol_vault.gd` — keep the parametric `protocol` + `mouth_width` structure; it still fits.** Additions:

- New exports: `chamber_half_width: float = 240.0` (L3 passes 280), `floor_depth: float = 305.0`. Delete `CHAMBER_FLOOR_TOP`; ladder height becomes `floor_depth + 20.0` (computed, not const).
- `_add_solid()` → returns the `StaticBody2D` (so the barrier/door bodies can be stored and disabled).
- `_ready()` split into: `_build_shell()` (floor/walls tables above), `_build_tiers()` (per-protocol array of {center, size}), `_build_backdrop()` (clip ColorRect + Sprite2D, §2), `_build_props()` (pillar/forge/door), `_build_hazards()` (§3), `_spawn_coins()` (shaft 2 + floor 3 + gated 6, still spawned under `get_parent()`), `_build_exit_ladder()` (unchanged formula, new height).
- Internal signal `objective_completed` from the hold-pad → barrier shatter / door open. The hold-pad Area2D must use the same player-only mask bit the kill zone uses (copy it from `_setup_kill_zone`).

**`level_base.gd` (the one surgical change):** new member `var kill_zone_gaps: Array[Vector2] = []`; `_setup_kill_zone()` sorts gaps and emits one Area2D strip per remaining x-interval, same y band/mask/handler. Empty array ⇒ exactly today's single strip.

**Level scripts, `_setup_depth_routes()`:** each sets on its vault instance `chamber_half_width` (240 / 280) and `floor_depth = 305.0`, and registers `kill_zone_gaps.append(Vector2(vault_x − 256, vault_x + 256))` (L2) / `± 296` (L3) **before** `_setup_kill_zone()` runs — ordering must be verified against `level_base.gd`'s `_ready()` sequence.

---

## 6. Missing facts I need before this is committable

1. **`level_base.gd` source** — exact `_setup_kill_zone()` body/signature and `_ready()` ordering for the gap registration.
2. **`level_02` / `level_03` scripts** — current `_setup_depth_routes()` bodies and the **vault instances' world x positions** (needed for the literal gap ranges).
3. **`ladder.gd`** — climb-area width (I assumed ~20px for the lane-clearance proofs) and confirmation `height` extends downward from `position`.
4. **`melt_forge` entity behavior** — what `EntitySpawner.spawn("melt_forge", …)` actually does; determines reuse vs. bespoke hold-pad.
5. **Distributor's crystal-shard projectile** — standalone scene path, if reusable for the Diamond dropper.
6. Whether fall damage or multi-value coins exist (I assumed no to both; the 305px drop lane and 6-coin hoards depend on that).