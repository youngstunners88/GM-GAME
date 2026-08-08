Design a PROGRESSIVE STRUCTURAL DAMAGE system for a Godot 4.3 GDScript 2D
platformer. Answer with GDScript code, not prose.

REQUIREMENT (from the game's owner, verbatim):
"This hammer axe needs to be his extra powerful attacking tool so when the
player presses attack the size of the axe thrown must increase and it should
do heavier damage even to the extent where the ladder breaks and the platforms
etc. They mustn't break completely as in disappear, but there needs to be
structural damage and if the player persists then we see that the damage
increases until the object is completely wrecked so the novelty of the tool
is worthwhile."

So: objects must show 3-4 VISIBLE damage stages before being destroyed. Not a
binary alive/dead.

CONSTRAINTS YOU MUST RESPECT (this is a real codebase, not a greenfield):
- Godot 4.3. Static typing required. `:=` inferring from a Variant is a HARD
  parse error, so write `var x: float = dict.get(...)` not `var x := dict.get(...)`.
- Damageable props are already-existing nodes: ladders (StaticBody2D +
  ColorRect visuals drawn in code), one-way platforms, and crates. They are
  built procedurally in GDScript — there are no authored .tscn variants per
  damage stage and you must NOT propose an art pipeline that needs 4 hand-drawn
  sprites per prop.
- The damage must therefore be rendered PROCEDURALLY: cracks, missing chunks,
  tilt, colour desaturation, debris particles.
- The axe projectile already exists (src/combat/axe.gd, an Area2D that flies and
  calls _impact()). A `big` bool flag on it marks the heavy version.
- No new autoloads. Prefer one reusable component script that any prop can add.

DELIVER:
1. A `Destructible` component (extends Node2D, added as a child of the prop)
   with `max_integrity`, `take_structural_damage(amount)`, a `damage_stage`
   0..3, and a `wrecked` signal.
2. Procedural crack rendering — how to draw progressive cracks over an
   arbitrary-sized rect prop WITHOUT per-prop art. Give the actual _draw() code.
3. The stage thresholds and what changes visually at each stage.
4. How a wrecked LADDER should behave (it is a climbable — it must stop being
   climbable in a way that cannot soft-lock a player mid-climb; think about the
   player already on it when it breaks).
5. How a wrecked ONE-WAY PLATFORM should behave (players may be standing on it).
6. The exact call site change needed in an axe `_impact()` to drive this.

Think hard about the soft-lock cases in 4 and 5 — that is the part most likely
to ship a game-breaking bug.
