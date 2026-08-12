<!-- dispatched: moonshotai/kimi-k3
     prompt: prompts/kimi-l1-death-s2-chase.md
     files inlined: 4
     tokens: 20021 in / 21506 out
     cost: $0.3827
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
# Question 1 — Auditor: the "no-touch" death

## The established "fact" is wrong at runtime: the hitbox is NOT aligned with the body

The tscn offsets the hitbox shape **twice**:

- `auditor.tscn`: `Hitbox/CollisionShape2D position = (84,84)`, `Hitbox` itself at default `(0,0)` → box spans `0..168`, matching the body. ✓
- `auditor.gd:_ready()`: `hitbox.position = Vector2(BODY/2, BODY/2)` → moves the Area2D to `(84,84)` **on top of** the child shape's `(84,84)` → shape centre lands at `(168,168)`, box spans **`84..252` on both axes**.

The `_ready` comment ("keep the collision/hitbox offsets at BODY/2") treats the two cases as identical, but for the body the offset lives on the shape node itself; for the hitbox there's an extra node in between. `collision.position = (84,84)` is a no-op (tscn already has it); `hitbox.position = (84,84)` is a +84,+84 shift. Resulting geometry vs. visible art (opaque ≈ x 18.5–152.9, y 0–160.2, from the given bbox × 168/150 = 1.12):

| Side | Kill edge | Visible art edge | Gap |
|---|---|---|---|
| Right | x=252 | x≈153 | **~99px of lethal daylight** |
| Left | x=84 | x≈18.5 | player can stand ~65px **inside the sprite**, no death |
| Bottom | y=252 | y≈160 | ~92px lethal skirt below feet |
| Top | y=84 | y=0 | head/shoulders are safe to land on |

`set_facing()` only flips `flip_h` on the inner Sprite2D — the hitbox never mirrors, so the kill zone is always +x regardless of facing. When he faces left, the lethal side is **behind him**.

## Frame-walk (the compounder)

Charge right at 430 px/s = 7.17 px/frame at 60 fps. Player standing still, 32px wide, left edge at x=244: contact fires when boss origin reaches x = −8, i.e. when the art's right edge is at ~145 — **~99px of visible air on the killing frame** (previous frame ~106px). No tunneling/discrete-catch artifact is involved (7 px/frame ≪ 168px box; overlap is continuous) — the pad-plus-speed story (~17px pad → ~24-28px final-frame daylight at charge speed) is real but secondary. The dominant mechanism is the double offset: ~99px, asymmetric, facing-independent. It also explains the *inconsistency* ("for some reason"): approaching his left half you can overlap the art and live; his right side kills from three-quarters of a character-width away.

**Root cause:** double-applied hitbox offset, not the 15-20px pad and not the stale `charge_target` (a stale target only aims the sweep; it can't create overlap where none exists).

## Fix (exactly one of these, not both — doing both re-mirrors the bug)

1. **Delete** `hitbox.position = Vector2(BODY / 2.0, BODY / 2.0)` in `_ready()` (tscn child already carries the offset), **or** set the tscn `Hitbox/CollisionShape2D` position to `(0,0)` and keep the script line.
2. **Break the shape sharing** — delete `hitbox_shape.shape = collision.shape` (it makes hitbox and body the same resource, so resizing one resizes world collision).
3. In tscn, set `RectangleShape2D_hitbox.size = Vector2(136, 160)` and the shape child position to `Vector2(84, 80)` → box x 16..152, y 0..160, matching the opaque art within ~3px in either facing. Body stays 168×168.

**Also check (file missing):** `distributor.gd:_ready()` has the identical `hitbox.position = BODY/2` line. If `distributor.tscn` (not provided) also pre-positions its child shape, the Distributor's kill box is shifted **+120,+120**. Need `distributor.tscn` to confirm.

---

# Question 2 — Distributor chase, full cycle re-derived

Speeds (floors bind everywhere): PATROL 330, TELL/HOARD/THROW `max(330×scale, 315)` = **315**, VULNERABLE `max(0, 120)` = **120**. Durations from the file:

| Phase | Super-cycle | Boss px | Player px (240/s) | Net |
|---|---|---|---|---|
| P1 | 1.5P+0.65T+1.4H \| 1.5P+0.45S+1.6V = 7.1s | 1969.5 | 1704 | **+265.5 (+37/s)** |
| P2 | 1.2P+0.6T+1.8H+0.45S+1.25V \| 1.2P+0.45S+1.25V = 8.2s | 2131.5 | 1968 | **+163.5 (+20/s)** ← worst |
| P3 | 1.2P+0.5T+2.2H+0.45S+0.9V \| 1.2P+0.45S+0.9V = 7.8s | 2142 | 1872 | **+270 (+35/s)** |

(Accel ramps roughly cancel: −52px per PATROL ramp-up, +51 per VULNERABLE ramp-down.) My P2 numbers reproduce the file's own ± figures (−1.5px at floor 265, +164 at 315), so the model is consistent.

**1. Climb lock re-triggering — yes, and HOARD_GRAVITY manufactures it.** Lock condition: `clear_air < CLIMB_CLEAR_MARGIN (60)` while `|Δx| < 240`. Ride height leaves 130px clear, so it's stable on flat ground — which is all the open-ground gate models. But `_apply_pull` may winch the player up to `clear_air = PULL_FLOOR_MARGIN = 48` — **inside the lock band (48 < 60)**. Every pull can re-arm the lock mid-fight; jumps and terrace drops also re-arm it. Cost per event: 0 horizontal while the player gains 240/s, then recovery at only +75/s (315−240) → ≈4.2× the lock duration of zero net closing. A locked HOARD costs up to 1.8s × 315 = 567px of closing. Two ~0.4s events per 8.2s cycle erase the entire +164 surplus. That is the gate-vs-live gap.

**2. Dominant drag:** open-ground, VULNERABLE is −300 of +516 gross surplus (58%) — biggest single term. Live, the lock dominates. **Do not shorten TELL or SHARD_THROW** — at 315 they are +75/s *surplus* states; cutting TELL 0.6→0.4 *costs* 15px/cycle. That suggestion points the wrong way.

**Recommended changes (fair window untouched):**

- **Primary: `PULL_FLOOR_MARGIN` 48 → 72** (= CLIMB_CLEAR_MARGIN + 12 buffer). The pull physically cannot push the player into the lock band; pull still lifts, still threatens, keeps its no-contact-kill guarantee with more margin. Live closing converges to the proven open-ground +20/+35 px/s instead of ~0.
- **Kicker: `MIN_PURSUE_SPEED` 315 → 345.** P2: 3.3s × +30 = **+163.5 → +262.5/super-cycle (+32 px/s)**; P3: +270 → +378; P1: +265.5 → +340.5. VULNERABLE duration/drift, TELL readability, and CLIMB_SPEED (520 already regressed the bounded gate) all untouched. Rejected for comparison: shortening `vulnerable_time` 1.6→1.2 gives +247.5 — similar magnitude, but spends the fairness budget the founder explicitly wants kept.

**Missing for full confidence:** the player scene (origin convention, collision size, jump velocity — jump height directly sets lock re-trigger rate) and level_02's `arena_min/arena_max`. One hazard I cannot rule out without them: the y-clamp pins `centre.y ≥ arena_min.y`; if any terrace leaves `< 180px` between player head and that clamp, the lock **never releases** within 240px horizontally and chase drops to literal zero there — exactly "still not chasing live" while both gates pass.