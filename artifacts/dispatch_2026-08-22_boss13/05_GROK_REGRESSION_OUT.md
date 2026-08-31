<!-- dispatched: x-ai/grok-4.6
     prompt: artifacts/dispatch_2026-08-22_boss13/05_GROK_REGRESSION.md
     files inlined: 0
     tokens: 1249 in / 8809 out
     cost: $0.0554
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
**Your analysis is half right.** `is_on_wall()` was load-bearing spectacle, not a real hop trigger. MATCH-inside-the-whole-bubble is why glue went to 97%. You are wrong that a flat floor plus “no retreat” plus “hold 200 vs 240 either way” can all be true. They cannot.

---

### A. Hop trigger

**On open flat floor he should not hop.** “When geometry needs it” on a flat slab is a contradiction. The 11 / 8 hop gates were counting the wall-pogo, not pursuit. If the founder wants a visible double jump, give him geometry (ledge, gap, raised platform) and point the gates at that. Do not fake hops in the middle of the floor to please a counter.

The arena is **not** geometrically open. You removed the *sensor* (`is_on_wall()` on solid walls) and left the *barrier* (`_clamp_to_arena()` still clamps centre to [3724, 4376] and zeros `velocity.x`). That clamp is the wall now.

Replace `is_on_wall()` with **clamp-blocked**, not with player-as-wall (that is ride-on-top):

- `want_hop` if `_clamp_to_arena()` actually clamped this frame, **and** hop cooldown is cold, **and** player is on the outward side of the bound (or `abs(dx)` still closing).
- Keep `(at_ledge and _gap_crossable(direction))`.
- Keep “player >80px above”. **Drop the `_higher_ground_ahead()` AND** for that case — on a flat floor it is why a jumping player never gets chased vertically. Player height *is* the geometry.

Cooldown must cover land + a beat. Every-frame clamp → hop is pogo without a collider. A ~1.5–2s cooldown reproduces the old 8 hops / 16s pin *without* solid walls. That is not the rejected `abs(dx)/delta` vault; it is the direct successor to `is_on_wall()` now that walls are player-only.

In the open (not clamped, not ledged, player not above): **0 hops is correct.** If the 40s kite gate still demands 11, the gate is wrong. Change the gate, not the boss.

At the east lip the clamp still zeros `velocity.x`, so a hop cannot carry him through the pin. You will get a **vertical** double jump, not a vault off the bound, unless clamp is changed. Do not change clamp in the same pass.

---

### B. Standoff vs moving player

Current rule is broken at the root: `target_vx = clamp(player_vx, …)` whenever `abs(dx) < 200` makes the **setpoint whatever distance you arrived at**. The `0.25 * speed` bias only inside `0.6 * min_sep` cannot win against 170–240. Stationary ~122px was luck.

**The formula you asked for, with all three bans, does not exist on a 1D line.**  
Hold 200 vs a player walking *at* you at 240 ⇒ you must move away at ≥240. That is backpedal. Ban backpedal ⇒ they walk into contact ⇒ run reset. MATCH to avoid retreat is what glued you to 97%.

Use a **setpoint regulator**, same symbols you already have (`dx` = player − boss, `speed`, `player_vx`):

```
err = abs(dx) - 200
s   = sign(dx)          // keep existing facing/sign if dx == 0
target_vx = clamp(player_vx + speed * clamp(err / 80, -1, 1) * s, -speed, speed)
```

| state | what it does |
|---|---|
| `abs(dx) > 200` | extra term toward player → closes, does not camp, does not lose a fleer (you run *faster* than them until the cap) |
| `abs(dx) = 200` | `target_vx = player_vx` → formation **at 200**, not at 80 |
| `abs(dx) < 200` | extra term **away** → backpedal-while-facing to reopen |

**What it breaks:** founder ban (ii). Inside 200, `target_vx` opposes `dx`. If he calls facing-held backpedal “retreat / standoff-as-chase,” this dies.

If you then forbid opposing `dx`:

```
raw = player_vx + speed * clamp(err / 80, -1, 1) * s
target_vx = raw if raw * s >= 0 else 0
```

**What that breaks:** (i) and the 200-vs-incoming requirement. Incoming 240 + `target_vx = 0` → contact → reset. Glue returns as deaths instead of a 97% stat.

If `speed <= 240`, even the first formula **cannot reopen** a too-tight gap against a full-speed approach (relative vx = 0 at the cap). It only stops getting tighter. Reopen requires `speed > 240` or a one-shot away impulse. Speed-only is banned; do not “fix chase” by bumping `speed`. The impulse still dies if `_clamp_to_arena()` zeros `velocity.x` that frame — at the lip, horizontal separation **cannot** work. That is hop territory (A), not chase.

Do not MATCH inside the whole bubble. Do not use the 0.25 bias. Those are the glue.

---

### C. Hold vs ship

**Yes, hold.** 97% inside 110px with contact = instant run reset is worse than a 13s freeze. Freeze is a statue at one parking spot: cheese, or a free window, or a boring pin. Glue is a landmine on every kite — the run ends when the player moves like a player. Unplayable everywhere beats broken at the east wall. The layer move is still the right wall fix; it just cannot ship without B (and A if you care about hop gates). Reverting walls to boss-solid to get hops and 12% glue back is paying 13s freeze for a pogo.

---

### D. Order for someone who has rejected ~50 attempts

1. **Say the contradiction out loud once.** 1D arena + contact-reset + no backpedal + hold 200 vs 240 incoming cannot be solved. He picks: allow facing-held backpedal, or drop contact-reset, or accept contact when they walk into him. No more packets that pretend all three bans hold.

2. **Do not revert the wall layer.** That freeze is real. Keep walls player-only.

3. **Rewrite the hop gates** onto real geometry (ledge / gap / player >80px / clamp-blocked with cooldown). Stop gating “double jump when geometry needs it” on a flat kite. Tell him the 11 and 8 were pogo.

4. **Chase only: kill MATCH-in-bubble.** Ship the setpoint formula. One change. No speed buff, no 2s vault, no new hop.

5. **If he rejects the away term:** hop-over (land *past* the player, never on him) when `abs(dx) < 200` **and** player is closing (`player_vx * dx < 0`). That is the only remaining legal evade, and it is the only honest flat-floor use of the double jump. High chance he calls a bad landing ride-on-top. Do not also trigger this on clamp (lip hop cannot get horizontal vx).

6. **Clamp last, alone.** Position clamp may stay; killing `velocity.x` every clamped frame makes any lip impulse dead. Do not fold this into 4 or 5.

7. **Nothing else.** No more coupled “fix the wall, the hop, and the chase.” Fifty rejects is what that coupling costs.