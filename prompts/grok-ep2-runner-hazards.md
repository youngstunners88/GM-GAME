# Design brief — Episode 2 Gold Mine Runner: duck / zipline / bear hazards

## What the game is
Lil Blunt Adventure. Episode 1 is a 2D pixel-art Godot 4.3 platformer
(shipped, live on itch.io). Episode 2 is a NEW 3D over-the-shoulder minecart
runner in Godot 4.3's 3D renderer, currently in graybox (box meshes, no art)
proving the gameplay loop before any art is produced. This brief is about
extending the graybox runner's mechanics only — no art, no shaders, no new
engine, no new frameworks.

## What exists right now (the whole runner script, verbatim)

@include src/episode2/runner/runner_graybox.gd

The headless test (7/7 passing) exercises: auto-run distance, lane switch,
un-jumped obstacle costs 1 health, jumping clears an obstacle, chamber
entrance signal + halt. There is exactly ONE hazard type today: a generic
box obstacle you clear by jumping or take a hit from if you don't.

## Engine facts you must not "correct"
- Godot 4.3, GDScript, this is a `Node3D`-based auto-runner (forward is +Z).
- Three rails at `LANE_X = [-2.5, 0.0, 2.5]`.
- The whole simulation is driven by a single `_advance(delta)` called every
  physics frame (or manually via `step(delta)` from tests) — there is no
  separate "input system" yet, input-facing methods (`jump()`,
  `switch_lane_left/right()`) are called directly and tests call them
  directly too, headless, with no real window/input device.
- `_obstacles` is a plain untyped `Array` of Dictionaries
  (`{"z":, "lane":, "hit":}`) — deliberately loose typing, per the file's own
  comment, to stay forgiving in a graybox.
- Do not invent player abilities, vehicles, or level geometry beyond what's
  described below and in the code above.

## The new founder spec (verbatim excerpt, already approved direction)
Enemies: large bears in balaclavas, stationed on elevated platforms/ledges
alongside the track. They (a) fire arrows down the track lanes at Lil Blunt,
(b) push boulders onto the rails to crush him.

Player responses:
- **Duck** — drop low *inside the current mine cart* so the cart walls block
  incoming arrows. Only meaningful while riding in a cart (not while
  zip-lining).
- **Jump cart-to-cart** — the existing jump, reframed as leaping between
  carts on the same or adjacent rail.
- **Zip-line** — grab an overhead cable to cross a gap or avoid a
  boulder-heavy section. A zipline segment is a distinct traversal state from
  normal cart-riding.

## The actual questions

1. **Hazard asymmetry.** Should arrow and boulder hazards be mechanically
   opposite (arrow: duck defeats it, jump does NOT — it's a flying
   projectile that would still hit a jumping player; boulder: duck does NOT
   defeat it — it crushes low — only jump or lane-switch clears it)? Or is
   there a better asymmetry that reads more clearly to a player at 12
   units/sec forward speed with ~0.7s of jump airtime? Give me the exact
   clear/fail rule for each hazard type.

2. **Duck timing.** Should duck be a simple boolean flag toggled the instant
   the input is held (checked once per hazard-collision-window, same pattern
   as the existing jump height check), or does it need a minimum duck
   duration / a startup delay to stop one-frame "duck-cheese" at the exact
   hazard z? Give a concrete number of frames/seconds if you recommend a
   window, calibrated to this runner's existing `OBSTACLE_HIT_Z := 1.0` /
   12 units-per-second pacing.

3. **Zipline data model.** Should zip-lining be modeled as a boolean mode
   (`_ziplining: bool`) that suspends the normal lane/duck/jump logic for a
   scripted stretch, or as an extra "virtual lane" at a different height
   using the existing `LANE_X` indexing? Which keeps the current obstacle
   dictionary format (`{z, lane, hit}`) usable without a rewrite, and which
   is more honest about zipline being a *different plane of movement*
   (overhead cable, not a rail)?

4. **Any obvious design trap** in bolting duck + zipline + two hazard types
   onto the current single flat `_obstacles` array, before I write the code?

## Hard constraints
- No new art, no shaders, no new engine/framework, no new input system beyond
  more `Callable`-style methods like the existing `jump()`.
- Must not break the existing 7 passing headless assertions' *intent* (auto-
  run, lane-switch, obstacle-hit, obstacle-clear-by-jump, chamber signal) —
  extending the data model is fine, removing those behaviors is not.
- Keep it graybox-appropriate: focus on the state machine and collision
  rules, not visual feel/juice (that's a separate pass later).

## Output format
Answer questions 1-4 in order, each in 3-6 sentences, ending each with a
one-line concrete recommendation I can hand straight to an implementer
(e.g. "duck window: 0.15s minimum hold, checked against hazard z ± 0.5").
