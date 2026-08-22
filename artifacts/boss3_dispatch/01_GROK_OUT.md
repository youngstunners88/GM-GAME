<!-- dispatched: x-ai/grok-4.6
     prompt: artifacts/boss3_dispatch/01_GROK.md
     files inlined: 0
     tokens: 1336 in / 3380 out
     cost: $0.0230
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
**Verdict: do not ship this as “boss3 moves.”** The wall-layer bug is real and the old gate was blind on X. The new evidence still fails the founder’s list, and the layer-2 swap is a shared-semantics landmine.

---

### 1. Layer 2 is not safe

`_create_wall(..., player_only)` lives in `level_base.gd`. This is not a Claim Jumper patch. Every `player_only` seal in every level is now a body on **"Player"**.

Boss mask `13` no longer hits it. That part is correct. Everything that **does** mask bit 2 will.

**Concrete breakages (hurtbox mask `70 = 2|4|64`):**
- Any `Area2D` hurtbox/projectile that does `body_entered` / `area_entered` and treats “layer 2 hit” as a player hit will **proc on the invisible west seal**. Group checks save you only where they exist. First collider that does `get_collider()` / `collision_layer` / “hit something on player layer → apply damage / queue_free / play impact” will lie.
- On stream that looks like: swings/shots **die at the doorway**, hit sparks on empty air at ~x=3700, or a contact-damage enemy “bites” the door and plays the player-hit react with Lil Blunt nowhere near it.
- Homing, shape-casts, and “find player” queries that ray/shape against layer 2 can lock onto the **wall AABB** instead of the player. Camera, aim, or aggro can hitch toward the entrance.
- If any enemy **CharacterBody** also masks layer 2, they physically **stick or slide on the seal** — a new “stuck at the door” clip, just not on the boss.

`is_in_group("player")` is a hope, not a guarantee. You did not audit every mask-2 listener. Until that list is in the PR, this is an unscoped collision-identity change.

Safer (and still uninvented): keep the seal off the Player layer. Use a layer the player masks and bosses do not — if no such spare bit exists, say so and add one; do not impersonate the player.

---

### 2. 526px will not read as chase

Founder rejected altitude-only. He will also reject **westward unstick**.

| | px |
|---|---:|
| Spawn | 4050 |
| After max X | 4110 (**+60** past spawn) |
| After min X | 3584 (**116 west of arena start 3700**) |
| Claimed arena | ~700 |

Almost all of the 526px is **out the entrance**, not across the room toward minecart/TNT. Before he was glued to 3710; now he is mostly running the corridor you just opened. A non-technical viewer watching 20s of follow-cam kite **west** sees the same guy near the cart, then maybe a door dash. That is “still stuck.”

Other holes vs his list:
- No shot_1 overrun.
- No Playwright frames.
- No butler / 18/18.
- Glue 13.9% → 12.1% is noise.
- 0.85s freeze is still a visible hitch.
- `is_on_wall() == false` and `velocity.x` ±191/−286 are **headless**. He already told you that is not acceptance.

Weakest sentence in the writeup: “never got east of spawn 4050” → “max 4110.” That is the clip he will point at.

---

### 3. Criterion 2 is not met. Shipping it as met is dishonest.

He asked for a **visible** double jump when a **single jump cannot clear a ledge**. One air-hop on flat floor is not that. Do not claim #2.

To satisfy it: kite path must include a ledge the hop cannot clear, fire the double, and show it on **camera frames** (Playwright or recorded follow-cam), not a counter.

---

### 4. Scope / Stage 2 risk

- **Shared `level_base.gd` wall layer** — Distributor, other arenas, any `player_only` seal. That is scope creep and it **can** touch Stage 2 identity without editing those scenes.
- **Boss x=3584** — he is outside the sealed arena. Clamp-only west bound can put him on minecart/TNT/previous-room geometry, re-trigger walk-in, or fight in the wrong camera volume. You said you would not touch that identity; letting him leave the box does.
- `_clamp_to_arena()` becoming the real wall is a behavior change for every boss using it, not just CJ.

Untouched scene files ≠ untouched identity.

---

### vs his six items

| # | Status |
|---|---|
| 1 Past shot_1 while kiting | **Fail** — not measured |
| 2 Visible double jump over a ledge | **Fail** — 1 flat air-hop |
| 3 Visible chase under follow cam | **Fail** — no frames; X span is door-ward |
| 4 Playwright vs shot_1 | **Fail** — not done |
| 5 12s+ X past stuck point, DJ count, % glued | **Partial / weak** — X past 3710 is mostly west; east of spawn is 60px |
| 6 Gates + 18/18 + butler fresh bytes | **Fail** — 11 local gates only, no butler |

Fix the layer without putting a wall on Player. Prove **east of spawn / past shot_1** on follow-cam frames. Do not call this chased.