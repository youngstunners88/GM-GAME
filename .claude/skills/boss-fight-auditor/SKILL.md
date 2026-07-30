---
name: boss-fight-auditor
description: Static audit of a boss fight for stuck/unreachable states, missing vulnerability gates, invisible hazards, wrong collision masks, and phase-parity gaps against the other bosses. Run after ANY edit to a boss script, before a release gate, or when a boss "feels too easy" / "feels unfair".
user-invocable: true
allowed-tools: Read, Glob, Grep, Bash
---

# Boss Fight Auditor

Every defect this checks for **actually shipped in this project** and survived
gdparse, a real export, and the full gate battery. None of them are
hypothetical, and none of them are caught by any existing gate — a boss with
a dead state machine compiles perfectly.

**This is a static audit.** It reads code and reports; it does not fix and it
does not run the game. Where a check genuinely needs runtime proof, say so
rather than guessing.

## The five defects that shipped (why each check exists)

| # | What shipped | How it hid |
|---|---|---|
| 1 | `claim_jumper.gd` declared `CHARGE`/`THROW`/`VULNERABLE` and **never transitioned into any of them** — ran `PATROL` forever | Enum + `match` block look complete; nothing errors |
| 2 | Same boss's `take_damage()` had **no vulnerability gate**, so it took damage in every state — the intended final boss had zero risk/reward | Fight is "playable", just trivially easy |
| 3 | `dynamite.gd` blast `Area2D` kept the default `collision_mask = 1` (World) while the player is on layer 2 → `get_overlapping_bodies()` always empty, **zero damage** | Explosion animation + SFX still play, so it looks real |
| 4 | Same hazard had **no visual at all** — an invisible Area2D detonating after 2s with no telegraph | Nothing to see means nothing looks broken |
| 5 | `auditor.gd` had **two damage paths**; the second skipped the health-bar update and silently desynced displayed HP by 2 | Only visible if you count pips during a reflect |

## Check 1 — State reachability (catches #1)

For the target boss script:

1. Find the state enum (`enum State {...}` or `enum Phase {...}`).
2. For EVERY enum value, grep for an assignment that enters it:
   `<state_var> = <Enum>.<VALUE>` — including inside helper functions like
   `_begin_charge()`, not just inside `_physics_process`.
3. Report per state: **entered by** (file:line) or **UNREACHABLE**.
4. Also report per state: **exits to** — any state with no outbound
   transition is a soft-lock.

```bash
# adjust the enum/var names to the boss being audited
grep -n "enum \(State\|Phase\)" src/boss/<boss>.gd
grep -n "current_state = \|current_phase_state = " src/boss/<boss>.gd
```

A state that appears ONLY in the `match` block and never on the left of an
assignment is defect #1. Fail the audit.

## Check 2 — Vulnerability gate on damage (catches #2)

Every boss in this project deals damage only during a telegraphed window.
Confirm the boss's `take_damage()` opens with a guard of the shape:

```gdscript
if is_dead or current_state != State.VULNERABLE:
    return
```

Report FAIL if `take_damage()` can run in any state. **Exception:** a
deliberate second path (the Auditor's reflect-shard, the Distributor's
redirected orb) is allowed to bypass the window — but it must be an
explicitly named separate function, not an ungated `take_damage`.

## Check 3 — Every damage path updates the health bar (catches #5)

List every function that mutates `health`. For each, confirm it reaches
`_update_health_bar()` / `_health_bar.set_health()` **and** the phase check.
The safest shape — and what the Distributor now uses — is a single private
`_damage()` that every path funnels through.

```bash
grep -n "health -= \|health = \|_update_health_bar\|set_health" src/boss/<boss>.gd
```

Two paths mutating `health` with only one touching the bar is defect #5.

## Check 4 — Hazards are visible and correctly masked (catches #3, #4)

For every hazard/projectile scene the boss spawns:

- **Visual**: does the scene have a `Sprite2D`/`ColorRect`/`CPUParticles2D`,
  or does the script `_draw()`? A bare `Area2D` + `CollisionShape2D` is
  invisible — defect #4.
- **Telegraph**: is there a warning the player can act on *before* damage
  lands (warning ring, wind-up flash, tell state)? Note the lead time.
- **Collision mask**: any `Area2D.new()` created in code **defaults to
  layer 1 / mask 1**. Project layers: `1 = World`, `2 = Player`,
  `64 = projectiles (player attacks AND boss projectiles both)`.
  A hazard meant to hit the player needs `collision_mask` including 2.
- **Same-frame overlap**: `get_overlapping_bodies()` called in the same frame
  an `Area2D` is added returns empty — the physics server has not registered
  it yet. Require an `await get_tree().physics_frame` first.

```bash
grep -n "Area2D.new()\|collision_mask\|collision_layer\|get_overlapping_bodies" src/boss/*.gd
```

Because layer 64 is shared by player AND boss projectiles, anything masking 64
must ALSO guard on group (`is_in_group("projectile")` vs
`is_in_group("boss_projectile")`) or it will detect its own side's shots.

## Check 5 — Phases actually change behaviour

`phase_thresholds` existing is not the same as phases mattering. For each
phase, list what concretely differs: attack count, cadence, speed, new
mechanic, vulnerable-window length. A phase that only changes a taunt is a
cosmetic phase — report it.

Best practice already established here: the vulnerable window should
**shrink** per phase (Claim Jumper, Distributor), so escalation isn't purely
"more projectiles".

## Check 6 — Thin-reskin comparison

Build this table across all bosses and flag any boss missing a column the
others have. This is the check that caught the Distributor gap.

| Boss | Movement threat | Ranged attack | Damage window | Skill-expression moment | Token spectacle |
|---|---|---|---|---|---|
| Auditor | CHARGE dash | clipboards 1→2→3 | post-charge, flat | reflect-shard | 3 perks |
| Distributor | HOARD_GRAVITY pull | orbs 3→5→5 | shrinks per phase | orb redirect / POOL DRAIN | 3 perks |
| Claim Jumper | TELL→CHARGE | dynamite 1→2→3 | shrinks per phase | — | — |

A boss with an empty cell is not automatically broken — but it IS the
"mechanically thinner reskin" risk, and the report must name it.

## Output format

```
BOSS FIGHT AUDIT — <boss>.gd

Check 1 State reachability ...... PASS / FAIL  [per-state entered-by table]
Check 2 Vulnerability gate ...... PASS / FAIL
Check 3 Health-bar on all paths . PASS / FAIL  [N damage paths found]
Check 4 Hazard visibility/masks .. PASS / FAIL  [per-hazard]
Check 5 Phases change behaviour .. PASS / WEAK  [per-phase deltas]
Check 6 Thin-reskin comparison ... [table + named gaps]

VERDICT: SHIP / DO NOT SHIP
Blocking: <the specific defects>
```

Any FAIL in checks 1–4 is blocking: each corresponds to a defect that already
reached players once. Checks 5–6 are advisory — they describe design thinness,
not breakage, and closing them is a scoping decision for the owner.

## Relationship to the other gates

`gate-battery-runner` proves the game *compiles and boots*. It cannot detect
a boss that compiles perfectly and does nothing. Run this skill in addition,
not instead — and prefer running it BEFORE the battery, since a dead state
machine is cheaper to find by reading than by playing.

For a second opinion on a complex rewrite, the multi-model path
(`scripts/or-call.mjs` + a `prompts/kimi-*.md` brief) is worth the ~$0.30 —
Kimi K3 found the health-bar desync (#5) that a human review missed.
