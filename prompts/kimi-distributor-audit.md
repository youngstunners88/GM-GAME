# Kimi K3 — Code Audit: The Distributor boss rebuild (Godot 4.3 / GDScript)

**BUDGET DISCIPLINE — READ FIRST.** A previous run of this exact brief spent
its entire output budget on internal deliberation and emitted zero visible
text. Do not do that. Start writing findings immediately. Do not re-derive the
whole control-flow graph before answering; go question by question, answer in
2–4 sentences each, and stop. Terse and correct beats exhaustive and
truncated. If you are running long, emit what you have rather than continuing
to think.

You are auditing a just-rewritten boss for a Godot 4.3 2D platformer. Be
adversarial and concrete. I want real defects, not style notes.

## Why this audit exists — the exact bug class to hunt

Last session a sibling boss (`claim_jumper.gd`) shipped with this defect and
nobody caught it for weeks:

> Its state machine declared `CHARGE`, `THROW`, and `VULNERABLE` states, but
> **no code path ever transitioned into them**. The boss ran `PATROL` forever.
> Separately, its `take_damage()` had **no vulnerability gate**, so it was
> damageable in every state — the intended final boss had zero risk/reward
> structure and was the easiest fight in the game.

A second bug in the same family, found in `dynamite.gd`: an `Area2D` created
at runtime kept the default `collision_mask = 1` (World). The player is on
layer 2, so `get_overlapping_bodies()` returned empty every time and the
attack dealt **zero damage** while looking and sounding completely real.

A third, from an earlier audit of `auditor.gd`: it had **two** damage paths
(normal hits and reflected shards) and the second one skipped the health-bar
update, silently desyncing the displayed HP by 2.

**Your job is to find anything in this class, plus anything else genuinely
broken.**

## Engine facts you must assume (do not "correct" these)

- Godot **4.3**, GDScript. Tabs for indentation.
- `BossBase` (inlined) owns `health`, `max_health`, `phase_thresholds`,
  `current_phase`, the health bar, and calls `_on_phase_changed()` when the
  phase steps. `BossBase.take_damage()` is OVERRIDDEN by this boss.
- `EnemyBase` (parent of BossBase) owns `sprite`, `is_dead`, `health`.
  **Redeclaring `sprite` in a subclass is a hard parse error** that silently
  leaves the whole script unattached — that is why this boss assigns
  `boss_sprite` instead.
- Collision layers in this project: layer 1 = World, layer 2 = Player,
  layer 64 = projectiles (BOTH player attacks and boss projectiles share 64).
- Player attack projectiles are `Area2D` in group `"projectile"`.
  Boss projectiles are `Area2D` in group `"boss_projectile"` (and are NOT in
  group `"projectile"`).
- The player is a `CharacterBody2D` in group `"player"`. Its
  `_physics_process` sets `velocity.x` via `move_toward(...)` toward an
  input-derived target every frame.
- Autoloads that exist and work: `GameManager`, `AudioManager`, `ScreenShake`,
  `EffectSpawner` (`.burst(name,pos)`, `.float_text(pos,text,color)`),
  `BossVoiceSystem` (`.say(node, id, category, force=false)`),
  `Web3Bridge` (`.holds(token) -> bool`, `.report_metric(...)`),
  `StateMachine`, `SceneRouter`.
- The boss arena floor is SOLID from x=3700 to x=4400 — **there are no pits
  in the arena**.

## Design intent (so you can judge "does the code do what it claims")

- `HOARD_GRAVITY`: a telegraphed radial **pull** that drags the player toward
  the boss. Deliberately NOT a dash (both other bosses already dash). It must
  be resistible by holding away, and must have a real reaction window.
- `FORCED DISTRIBUTION`: each thrown orb has a short "unstable window"; a
  player attack touching it in that window flips the orb back at the boss for
  damage **outside** the vulnerable state. Flipping every orb in one volley
  triggers `POOL DRAIN` (bonus damage + extended vulnerable window).
- Token perks must be **player-favourable only**. A non-holder must fight
  exactly the base fight — never harder, never gated content.
- Boss has 7 HP. Redirect damage is intentionally capped per volley so a
  single good volley cannot end the fight.

## Specific questions — answer each explicitly

1. **State reachability.** Enumerate every `Phase` enum value. For each, name
   the exact line/function that transitions INTO it. Flag any unreachable
   state, and any state with no exit (a dead end / soft-lock).
2. **Timer correctness.** `throw_timer` and `state_timer` both decrement every
   frame in every state. Trace whether either can go stale, be missed, or
   cause an instant/skipped transition. Is `throw_timer` always reset before
   `PATROL` relies on it again?
3. **Damage paths.** There are two (`take_damage` for the vulnerable window,
   `take_redirected_orb` for flipped orbs). Confirm BOTH route through the
   health bar and phase check, and that neither can fire after death. Can the
   per-volley damage cap be bypassed?
4. **POOL DRAIN correctness.** Can it double-fire? Can orbs from an older
   volley trigger it? Is `_volley_id` matching airtight on both the flip path
   and the arrival path?
5. **The pull field.** Does writing `body.velocity.x/y +=` from the BOSS's
   `_physics_process` actually work given the player's own `_physics_process`
   also writes `velocity.x` the same frame? Any risk of the player being
   flung, stuck, pulled through geometry, or pulled while dead/respawning?
6. **Projectile redirect wiring.** In `boss_projectile.gd`, the orb masks
   layer 64 to see player attacks — but boss orbs are ALSO on 64. Is the
   group-based guard sufficient to stop orbs redirecting off each other?
   Can an orb redirect twice? Can a redirected orb still damage the player?
7. **Signal/lifetime safety.** `redirected.connect(_on_orb_redirected.bind(...))`
   binds the boss into an orb that outlives... what exactly? If the boss dies
   or the scene changes while orbs are in flight, what happens on the next
   emit or on the arrival distance-check? Any dangling reference or
   call-on-freed-instance?
8. **Anything else genuinely broken.** Null derefs, wrong operator precedence,
   `is_instance_valid` gaps, off-by-one in the `[0,3,5,5][current_phase]`
   indexing, `_draw()` not being refreshed, etc.

## Output format

For each finding:

```
SEVERITY: CRITICAL | HIGH | MEDIUM | LOW
FILE: <path>
SYMBOL: <function or line>
CLAIM: <one sentence — what is wrong>
WHY: <the mechanism — what actually happens at runtime>
FIX: <the minimal concrete change>
```

Then a final section `VERDICT:` with either `SHIP` or `DO NOT SHIP` plus the
one or two things that most need fixing.

Do NOT invent file contents. Everything you need is inlined below. If you
need a file that is not here, say so explicitly rather than guessing.

---

## FILES

@include src/boss/distributor.gd
@include src/boss/boss_projectile.gd
@include src/boss/boss_base.gd
@include src/enemies/enemy_base.gd
@include src/boss/distributor.tscn
@include src/boss/boss_projectile.tscn
