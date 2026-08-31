<!-- dispatched: openai/gpt-5.3-codex
     prompt: prompts/2026-08-19-boss-shared-rootcause.md
     files inlined: 4
     tokens: 36842 in / 3239 out
     cost: $0.1098
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
I can’t provide numeric `file:line` because the paste has no line numbers. I’ll cite exact file + symbol/block.

## 1) Shared root cause hypothesis: **mostly true for Stage 2/3, not sufficient for Stage 1**

**Supported (Stage 2/3):**
- `distributor.gd` and `claim_jumper.gd` both hard-clamp boss position to arena bounds:
  - `src/boss/distributor.gd` → `arena_min/arena_max`, `_clamp_to_arena()`
  - `src/boss/claim_jumper.gd` → `arena_min/arena_max`, `_clamp_to_arena()`
- If player is west of arena start while fight is still “live,” boss hits west clamp and cannot reduce distance further. That exactly matches your screenshot analysis and the “pinned at wall” behavior.

**Not sufficient (Stage 1):**
- `src/boss/auditor.gd` has **no arena clamp system at all** (no `arena_min/arena_max`, no `_clamp_to_arena()`).
- So “boss frozen by arena clamp” cannot be the Stage 1 primary explanation.
- Your own evidence also says Level 1 didn’t provide arena bounds (`(0,0)`), reinforcing that Stage 1 is a different failure mode.

## 2) Why Stage 1 gets negative tracking

Two concrete contributors in `src/boss/auditor.gd`:

1) **Charge target is stale**
- In PATROL→CHARGE transition, `charge_target` is captured once.
- In `State.CHARGE`, movement is toward that fixed point:
  - `var dir := global_position.direction_to(charge_target)`
  - `velocity.x = dir.x * charge_speed`
- Against a kiting/reversing player, this regularly sends the boss the wrong way (or overshoots), which can produce negative tracking.

2) **VULNERABLE decel is frame-based, not time-based**
- `State.VULNERABLE` uses:
  - `velocity.x = move_toward(velocity.x, 0.0, 200.0)`
- No `* delta`, so decel strength depends on physics tick rate and can create overly strong braking/freeze-like windows, worsening tracking score.

## 3) Minimal **shared** fix (one policy, not 3 AI hacks)

Best shared fix is **encounter boundary ownership**, not more speed tuning:

- While boss alive and fight active, player must not be able to retreat west out of encounter space.
- If player exits the arena boundary anyway, treat as fight fail and restart via existing API:
  - `GameManager.boss_contact_restart()` (already used by all 3 bosses).

Why this is minimal and shared:
- Uses existing behavior/API (no teleport, no fake chase).
- Eliminates the wall-pin perception cause in Stages 2/3.
- Avoids “seal dropped => boss pinned => ‘doesn’t move’” loop.

About respawn soft-lock:
- You’ll need level/respawn scripts to implement this safely. Those files were **not provided** (you referenced `level_01_smoke_realm.gd`, seal-wall logic, checkpoint placement). I can’t give exact patch lines without them.

## 4) Faster-than-player + instant run wipe: survivability

As configured, this is only fair if bosses have **reliable counter-play windows**:
- Telegraphs (throws/charges),
- Non-contact spacing rules,
- Short punish bursts rather than permanent overlap pursuit.

Right now:
- Stage 3 already has explicit spacing controls (`CHASE_SEPARATION`, `VULNERABLE_SEPARATION`) in `claim_jumper.gd` to avoid unavoidable touch-wipes.
- Stage 2 has hover clearance/climb-lock logic in `distributor.gd` for similar fairness.

So the model can be fair, but only if encounter containment is fixed. Otherwise player can force degenerate states (retreat outside arena) and difficulty becomes binary/unreadable.

## 5) “Stage 3 too easy” vs “does not move” are compatible

Yes—likely same emergent exploit:
- Player retreats outside/edge of arena.
- Boss remains clamped/contained.
- Player damages from relative safety while boss cannot meaningfully close.

That reads as both:
- “boss doesn’t move/chase” (from founder perspective),
- and “boss too easy” (because wall-pinned target).

---

If you want, send the level scripts that own:
- arena activation/deactivation,
- seal wall raise/drop,
- checkpoint/respawn flow.

Then I can give exact file-level patch steps for one shared encounter-boundary fix.