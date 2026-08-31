<!-- dispatched: moonshotai/kimi-k3
     prompt: prompts/partb-kimi-collision-paths.md
     files inlined: 3
     tokens: 5359 in / 20884 out
     cost: $0.3293
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
# AUDIT — Diamond Vault (L2 gap 2400–2500) + Fort Knox (L3 gap 2620–2760)

**Verdict up front:** the proposed placement is geometrically sound **only if** (1) `top_exit_offset` is NOT the default `(0,-20)` — that reproduces the exact Stage-2-blocking bug, and (2) the vault ladder is made **non-destructible** — `ladder.gd` as provided has no opt-out, and a destroyed vault ladder is a true soft-lock. Details below.

---

## 1. Drop-in survivability

**(a) Fall math.** Feet start at 650, land at 800 → fall d = 150px.
- Impact velocity: v = √(2·g·d) = √(2·1000·150) = √300000 ≈ **547.7 px/s** — under the 720 cap, so no clamping.
- Fall time: t = √(2d/g) = √0.3 ≈ **0.548 s**.
- Per-frame motion at impact: 547.7/60 ≈ **9.1 px/frame**.
- Resting state: feet 800, centre 784, collision box y ∈ [768, 800].
- Kill band (from `_setup_kill_zone`: centre 850+175 = 1025, half-height 200) = y ∈ [825, 1225]. Clearance: 825 − 800 = **25px**. Player's lowest point is 800 — no overlap, `body_entered` never fires. Even an unclamped single frame can't reach it (9.1px max approach < 25px). No fall-damage mechanic appears in any provided file — assumed none exists (flagged below).

**(b) Tunneling.** Max per-frame motion = 720/60 = **12px**. To phase through a 40px floor the feet would need to move >40px in one step (surface 800 → below 840); full pass-through needs 40+32 = 72px. 12 < 40 < 72 — **3.3× margin, cannot tunnel**. Same reasoning as the kill zone's own 400px comment.

**(c) Minimum wall extents.** Player body on the chamber floor spans y ∈ [768, 800]. A 32px-tall body can only pass a gap ≥32px:
- **Wall bottom must be > 768** (else 800 − bottom ≥ 32 = squeeze-under into the void → kill band). Spec: **840** (flush with floor body bottom).
- **Wall top must be < 752** (else gap under the segment body bottom at 720 ≥ 32). Spec: **700** (20px overlap into the segment-body band 650–720).
- Place walls **outside the mouth, under the segment ends** (not inside the mouth). Then the segment body (650–720) caps the wall: jump-over is impossible (would require passing through the solid segment), and the mouth stays a clean 100/140px drop channel with nothing to land on. If walls are instead placed inside the mouth, their tops are exposed and must run to y=650 (150px above the floor > 92.45px single-jump apex) — and even then a double-jump clears them (see §2).

## 2. Upward exit — ladder arithmetic

**Ladder is required:** rise 800 → 650 = **150px**. Single-jump apex = 430²/(2·1000) = **92.45px < 150** ✓ cannot jump out.
⚠️ **Double-jump flag:** 370²/2000 = 68.45px; fired at first-jump apex, total = 92.45 + 68.45 = **160.9px > 150px** — a double-jump owner can escape without the ladder (~11px margin + drift). Not a soft-lock (only adds an exit), but the founder should know the ladder is not strictly the *only* exit if double jump is unlocked in S2/S3. Deepening the chamber to block this is NOT recommended (floor 815 → only 10px kill-band clearance).

**Ladder spec (origin = top, zone = 44 × height, extends downward):**
- `global_position = (pit_right_edge − 22, 650)`, `height = 170` → zone y ∈ [650, 820]. Standing player (768–800) is fully inside vertically. (Minimum viable height: zone bottom must pass the player's top at 768 → height > 118; 150 works, 170 gives margin.)
- Climbing player box x ∈ [centre−16, centre+16] = right edge at pit_right_edge − 6 → **6px clear of the segment wall** during the whole climb ✓.

**Top-out (the critical number):** teleport to `global_position + top_exit_offset`.

| Vault | Ladder pos | `top_exit_offset` | Top-out point | Player box | Check |
|---|---|---|---|---|---|
| Diamond | (2478, 650) | **(62, −16)** | (2540, 634) | x[2524–2556], y[618–650] | On seg 2500–3000, left edge **24px past** the pit edge; right wall (2500–2516 × 700–840) is y-disjoint ✓ |
| Fort Knox | (2738, 650) | **(62, −16)** | (2800, 634) | x[2784–2816], y[618–650] | On seg 2760–3220, 24px margin; wall y-disjoint ✓ |

Feet at 650 = segment surface; the `move_and_collide` nudge seats them. Minimum viable offset.x is +38 (centre ≥ segment_start + 16) — knife-edge; **+62 gives 24px margin. Use +62.**

**Default offset reproduces the old bug:** `(0,−20)` → top-out at (2478, 630) / (2738, 630) — directly over the pit. Player falls back into the chamber, climbs, repeats forever; single-jump player never escapes = **soft-lock**. Ship-blocking if left default.

## 3. Failure modes

1. **Lands missing the ladder zone → trapped?** No. Floor is flat, full-width of the mouth; landing centre range 2416–2484 (Diamond) / 2636–2744 (Fort Knox); walk right ≤68px/≤100px at 200px/s into the zone. Reachable from every landing point, assuming coin clusters/decor are non-blocking (flagged below).
2. **Top-out over air:** only with the default offset — see above. +62 lands 24px onto solid segment.
3. **Shoulder catch on entry:** running entry at 200px/s: crossing the mouth takes 68px (to far wall plane) = 0.34s; fallen ½·1000·0.34² = 57.8px → feet at 707.8, **below** the 650 lip, inside the segment-body band (650–720) → hits the wall face and slides down into the chamber. Never catches the lip. Mouth slack: 100 − 32 = 68px. With outside-mouth walls there is nothing else in the mouth to land on. ✓
4. **Floor/kill-band overlap:** floor body 800–840 ∩ band 825–1225 = 825–840 — harmless: floor is StaticBody (layer 1), kill zone mask = 2 (player only). Standing player (768–800) never touches 825. ✓
5. **🔴 Destroyed ladder = TRUE SOFT-LOCK (the catch of this audit).** `ladder.gd::_ready()` calls `_setup_destructible()` **unconditionally** — 3 big-axe hits frees the ladder. `_on_wrecked` correctly releases mid-climb players, but nothing restores the ladder afterward. A single-jump player who then drops in (or is inside) has: no ladder, 92.45 < 150 jump, and a floor that guards the kill band so **they can't even die to reset**. Unrecoverable. `ladder.gd` as provided has **no opt-out** — this needs a code change (e.g., an exported destructible flag set false for vault ladders) or a guaranteed ladder respawn.

## 4. Concrete numbers I'd use

```
DIAMOND VAULT (L2 gap 2400–2500):
  floor:  StaticBody2D rect x[2400–2500] y[800–840]   (collision_layer = 1, like _create_platform)
  walls:  left  x[2384–2400] y[700–840]   (under left segment end)
          right x[2500–2516] y[700–840]   (under right segment end)
  ladder: pos (2478, 650), height 170, top_exit_offset (62, -16)
  mouth frame/hatch decor: NO collision inside x[2400–2500] × y[650–800]

FORT KNOX (L3 gap 2620–2760):
  floor:  x[2620–2760] y[800–840]
  walls:  left  x[2604–2620] y[700–840]
          right x[2760–2776] y[700–840]
  ladder: pos (2738, 650), height 170, top_exit_offset (62, -16)
  + rename the existing hall_of_blaze "— THE FORT KNOX VAULT —" alcove at x=3420 (seg 3380–3480) — name collision confirmed, different location.
```

I agree with the proposed gap choices, floor height (800), and exit-onto-right-segment design. My corrections are: walls outside the mouth, ladder hugging the right wall, height 170, offset (+62, −16), and non-destructible vault ladders.

## Missing facts (needed, not provided)

1. **`destructible.gd`** — does the 28px-wide destructible overlay add a *solid* body? If solid, it sits at x[2464–2492] in the mouth; remaining drop channel 2400–2464 = 64px ≥ 32px, still enterable — but I can't verify.
2. **Big-axe availability in S2/S3** — determines whether failure mode 5 is reachable in practice. The opt-out should ship regardless.
3. **Player climb/top-out code** (`player.gd`) — top-out trigger condition and whether player x snaps to ladder x during CLIMB; I relied on the shared facts' teleport formula.
4. **Fall damage** — none appears in provided files; if a system exists elsewhere, 150px / 547.7 px·s⁻¹ impact must be checked against it.
5. **EntitySpawner coin/decor solidity** in the chamber — assumed non-blocking pickups.
6. **Existing entities/hazards near the top-out tiles** (2540, 650) and (2800, 650) — not verifiable from these files.
7. **Per-level `kill_zone_y`** — facts state 850 for these stages; the code reads it from `level_data`, so a different per-level value would move the band.