<!-- dispatched: x-ai/grok-4.6
     prompt: artifacts/dispatch_2026-08-24_boss1_walkthrough/02_GROK.md
     files inlined: 0
     tokens: 910 in / 8248 out
     cost: $0.0513
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
**Audit: option C does not cleanly satisfy both founder constraints.** Geometry only gives you two real walls. Everything else is a floor the 220 body already walks under. No code was provided (vault trigger, height-cap implementation, gravity, platform AABBs/widths, StandSurface rect, existing gates). Numbers below use only what you stated: y-down, head 430, plats `(300,500)` slab ~500–520 and `(1100,450)` slab ~450–470.

---

### 1. Spacing without the 46s pin?

**Player standing surfaces: yes. Boss-as-wall leverage: only as a speed bump, and only if vault actually fires. Pin: not eliminated.**

Re-solidifying the six high plats does nothing to the boss; he already walks under them. The only plats that can “apply” as spacing walls are `(300,500)` and `(1100,450)`. Vault converts those walls into a delay + air arc. That is not the old pin *if* `is_on_wall && grounded` hits every time and the leap clears the slab. It *is* the old pin if it doesn’t.

**Mis-fire modes at those two (this is where the 46s pin comes back):**

- **Top/corner normal, not wall.** Both slabs are ~20px tall. `(1100,450)` only overlaps the head/neck band (head 430 vs top 450). `move_and_slide` will often report floor or mixed normals, not wall. Vault never starts. Chest sits in the slab. Same pin as pre-#52.
- **Vault into the solid volume.** Leap origin still overlaps the 20px AABB → stuck inside the collider or jitter. Worse than a pin if contact with the player is also possible.
- **Mount instead of clear.** x-commit + `-620` drops him *on* the slab. He is now a 220 body perched at torso height. Next frame: drop off the far edge and re-hit the same slab from the other side → vault ping-pong (stall, not 46s, but fight still broken).
- **x-commit toward a player on that plat.** Vault is a homing leap into the only spacing cover. Contact = instant restart. “Leverage” becomes a kill conveyor.
- **False `is_on_wall`** (level edge, another body, residual air). Full hunt leap for no reason → flying.

Without platform widths and the actual wall-normal test, you cannot honestly claim the pin is gone. A 20px mid-torso face is a bad `is_on_wall` target. `(1100,450)` is the worse of the two.

---

### 2. Residual “flying” + how the cap must work

Founder already saw flying **with one-ways** (those two plats were not walls). So the hunt leap `-620` itself is part of the residual. Vault **adds** a full hunt leap every time he scrapes a 20px slab.

What will still read as flying with solid plats + this vault:

- Using **hunt** `-620` to clear a **20px** obstacle — long apex, long hang time.
- Vault → land on `(300,500)` / `(1100,450)` → stand 150–200px up (especially 1100, already at neck height).
- Vault overshoot onto one of the six above-head plats, then walk or leap again.
- Vault chain: wall → air → land → wall → air.

**Peak-height cap vs landing-height cap — you need both, and they do different jobs:**

| Cap | Stops | Does not stop |
|---|---|---|
| Peak (clamp min-y / kill upward vel) | Runaway climb, stacked vaults into the sky | The arc looking like flight; perching after landing |
| Landing (cannot *remain* on a surface above takeoff/floor band) | Boss camping floating plats; “he lives in the air” | Mid-arc hang from `-620` |

If the peak cap is high enough that the existing hunt leap still crosses the stage, vault inherits that same apex → flying. If you clamp peak down to “just clear a 20px slab,” you have silently replaced `-620` and you will regress hunt again (you already know raising leap hurt hunt).

**Blunt: do not reuse LEAP `-620` for vault.** A horizontal-commit vault needs a short hop sized to the 20px face, with x locked, under the existing peak cap. Peak cap must be **relative to takeoff floor**, not a world ceiling he bonks. Landing cap (or “boss cannot stand on floating plats”) must force a fall if the hop mounts a slab, so vault cannot become a climb. Keep the hunt leap for gaps; keep the cap on both paths so they cannot stack.

---

### 3. Boss-exception on checkpoint StandSurface vs one-way

**Boss-exception is worse for the player and not better for the boss if one-way already lets him through.**

- One-way, invisible: boss does not side-pin; player can still *land* on an invisible floor. No invisible wall.
- Solid + boss ignore: boss does not pin; player gets an **invisible wall and floor**. That is the worse of the two failure modes you listed.

Use one-way (or, better, a trigger with **no** collision for anyone) on StandSurface. Exception only if this volume is tall enough that one-way still grabs the 220 body from above/inside. You did not give the StandSurface rect, so that case is unproven. Do not make a save trigger into secret gameplay geometry.

---

### 4. Gate that cannot be gamed like #52

#52 went green by deleting side collision. The new gate must fail that cheat and fail “just fly over the stage.”

Hard-code the two wall AABBs by coord, not “any StaticBody.” Sample every physics frame.

1. **No phase (grounded):** boss AABB must not enter the interior of `(300,500)` or `(1100,450)` while `state != VAULT` (and not during a short vault-recovery window you define). One-way / layer-ignore fails this.
2. **Wall before traverse:** grounded approach from **both +x and -x**, player planted on the far side. Within one body-width of the slab: `is_on_wall` **or** `abs(vx) ≈ 0` for ≥1 frame, **and** still outside the rect. Then vault (or fail).
3. **Progress:** from that contact frame, boss x must pass the far edge in `< T_clear` (pick something like 0.5–0.8s; 46s must fail hard) **and** `|boss.x - player.x|` must be strictly smaller than at contact. Wrong-way vault fails. Ping-pong fails.
4. **Full-stage close:** stationary player at far-left ground, far-right ground, stage mid, **and** on at least one high plat. From hunt spawn, time-to-contact `< T_hunt` with `T_hunt << 46`. Must pass all four.
5. **Anti-pin:** no interval ≥ ~2s with `Δx ≈ 0` while adjacent to / overlapping a named plat AABB and not in vault/recovery.
6. **Anti-fly (this is what #52 never measured):** on those same closes, (a) peak height ≤ cap, (b) max consecutive airborne time ≤ `T_air`, (c) airborne time ratio ≤ `R`, (d) **zero** landings that remain on the six above-head plats. Closing by sky-arc fails.

Do not gate on “collision layer bits” or “did not pin for N seconds” alone. That is how the last gates were gamed.

---

### 5. Rank: is vault necessary?

**For the founder’s actual complaint — boss is blocked so Lil Blunt can put geometry between them — vault (or some other traverse) is required. Exception on only the two wall plats is not enough.**

Those two are the *only* plats that can block a grounded 220 body. Ignore them for the boss and he walks through the only walls in the level. Player can stand on everything; **leverage is still zero.** That is the reject text.

| Approach | Player stands | Blocks apply to boss | Boss crosses | Pin risk | Fly risk |
|---|---|---|---|---|---|
| Exception on the two walls | Yes | **No** | Yes | Low | Unchanged (hunt leap) |
| Solid + vault `-620` | Yes | Briefly | If vault works | High (normals) | **Higher** |
| Solid + short x-commit hop + peak **and** landing cap | Yes | Briefly | If hop works | Medium | Contained |
| Move both slabs above y=430, all solid | Yes | Only as floors | Yes | None | Unchanged |

Exception-only is the safe engineering fix and the wrong product fix. Vault is the right *category* if “apply” means impede. This vault spec (full `-620`, `is_on_wall` on a 20px neck/torso sliver, no landing cap) is not strictly sufficient and will re-litigate both pin and flying.

**Ship rule:** you cannot have solid torso-height slabs vs a 220 one-shot body without *either* a pin or a traverse. Stop pretending layer flags change that. If founder will accept floors-only (no horizontal walls), raise the two plats above head 430 and drop the vault. If he wants real walls, build a **short** vault and a gate that measures phase, progress, and air time — not another green checkbox.