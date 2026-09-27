---
name: ep2-runner-level-grammar
description: Layer 2 (wire spec) of the Episode 2 runner — the hazard verbs, speed ramp, cart ATTRITION rules (boulders smash carts, rails end, carts respawn on sidings, hops only to adjacent live carts), pacing numbers and the autopilot solvability gate. TRIGGER when designing or editing a runner leg, adding a hazard, changing speed/jump/hop numbers, or when the founder says the runner is slow, simple, cheap or not strategic.
---

# The rules (sim: `src/episode2/runner/runner_graybox.gd`)
- **Speed** ramps from the leg's `speed.base` to `speed.max` over 900 m (defaults 20 → 30 m/s;
  was 12 m/s flat — "way too slow", founder 2026-09-27). Hop ≈ 0.11 s/rail, jump airtime ≈ 0.67 s.
- **Verbs**: box = JUMP · arrow = DUCK (or SHOOT the archer first) · boulder = HOP ·
  boarder = SWIPE (pickaxe) · zipline = JUMP to hook, JUMP near the end to swing to the next cable.
- **Cart attrition** (founder: "if a boulder smashes a cart that cart needs to be smashed … not
  available until another cart on that same rail"):
  - a boulder destroys the cart on its rail **whether the rider is in it or not**;
  - hops reach only an **adjacent live** cart → a dead centre splits the convoy;
  - `rail_events`: `{"z","lane","type":"spawn"}` rolls a fresh cart in (siding for outer rails,
    ore chute for the centre); `"end"` is a buffer stop that destroys that rail's cart;
  - own cart destroyed → one hit and thrown to the nearest live cart; none left → DERAILED (run fails);
  - zipline dismount lands on the centre, or the nearest live cart if the centre is dead.
- **Gold** (`"type":"gold"`): pickups collected by passing through — use them as **bait** toward
  risk (a rail about to die, a lane you can't reach).
- Leg options: `carts_start` ([bool×3]), `start_lane`, `speed`, `rail_events`.

# Pacing numbers (at 20–30 m/s)
- Telegraph → punishment ≥ 40 m (~1.5 s). A spawn that "saves" you must land ≥ 25 m before the
  hazard that needs it (the siding preview shows 26 m ahead).
- A zipline landing is a decision point: put the first post-zip choice 25–35 m after `end_z`.
- Budget per leg: ~40 s (960–1200 m). Teach one idea alone, then combine two, then twist.

# Design grammar (the strategic patterns)
1. **Witness** — a boulder smashes an EMPTY rail first, so the rule is seen before it costs you.
2. **Split** — kill the centre: the convoy is now two islands; the side you pick decides what you face next.
3. **Only cart** — two rails dead, one live: every hazard on it must be answered in place (jump/duck/shoot).
4. **Bait** — gold on a rail that is about to end or that you can't cross to.
5. **Race the siding** — a rail ends; its neighbour's replacement arrives just in time.
6. **Compound** — boarder inside a volley; boulder right after a zip landing.

# Gate — `tests/ep2_runner_carts_test.gd`
- rule units (smash, blocked hop, split, bail, spawn, rail end, derail, speed ramp, gold, zip dismount);
- **autopilot** (`src/episode2/runner/runner_autopilot.gd`, shared with `?ep2bot=1`) must finish
  every leg with **zero hits**; a **do-nothing** run must **fail**; each leg must wreck ≥ 4 carts.
- On a bot hit the test prints `bot hit at d=… lane=…` — that line is the design bug to fix
  (or a bot timing issue: the bot jumps boxes 0.2 s ahead).

# When editing a leg
1. Write the beat list first (comment above each obstacle group, as in `episode2_tracks.gd`).
2. Hand-check every "only one live cart" moment: which carts are alive at that z?
3. Run the carts test; then `ep2-browser-playtest` with `?ep2bot=1` to see it.
