ROLE: You are a verification engineer auditing a single enemy AI script in a
Godot 4.3 2D platformer. This is a NARROW re-audit — a previous audit request
covering this same file truncated at an output cap before reaching this
material. Scope is this file only.

CONSTRAINT (non-negotiable): Do not invent methods, file paths, node types, or
Godot APIs that do not appear in the inlined files. If you need something that
was not provided, name exactly what is missing instead of guessing.

## Current state (for your context, not to be taken on faith — verify against
the inlined source)

- Tax Collector previously had 44 lines of pure patrol AI.
- Now has a PATROL -> ALERT -> PURSUE state machine with jumping.
- Alert: 0.5s frozen telegraph when the player enters detection radius.
- Pursue: moves toward the player, jumps toward higher platforms (gated on a
  150px max gap check against horizontal distance TO THE PLAYER, not the gap
  in front of the enemy).
- Lose interest: returns to PATROL after 3s outside detection radius,
  re-anchoring patrol to wherever the chase ended.
- Detection: 200px horizontal, 100px vertical.
- Re-targets the player reference on a 0.2s timer, not every frame.

## Files

@include src/enemies/tax_collector.gd
@include src/enemies/enemy_base.gd

## Tasks (narrow scope — these two files only)

1. **Null-reference audit.** Every node reference, timer, and signal
   connection. `_player` is looked up via `get_tree().get_first_node_in_group`
   on a timer — what happens between retarget ticks if the player node is
   freed (death, scene change) mid-window?

2. **State machine audit.** Can PATROL/ALERT/PURSUE deadlock? Can it oscillate
   between states at the detection boundary? Is `lose_interest_time` hysteresis
   actually sufficient, or is there a path that resets `_out_of_range_timer`
   in a way that never lets PURSUE time out? Trace the ALERT -> PATROL exit
   path (`_player_in_range()` goes false mid-telegraph) — does it correctly
   reset everything ALERT had set (velocity, timers)?

3. **Jump-gap logic.** `max_jump_gap` is checked against `absf(dx)` — the
   horizontal distance to the PLAYER — not the width of any gap or platform
   edge in front of the enemy. Construct the concrete scenario where this
   guard passes (player is close enough) but the enemy is standing at the edge
   of a platform with a pit wider than it can clear, and state whether the
   code has any protection against that case (it does not appear to check
   `is_on_floor()` distance to floor edge, or raycast forward). Is this a real
   bug or does something else in the file prevent it?

4. **Performance.** Runs in `_physics_process` for potentially several
   Tax Collectors at once. Flag per-frame allocation, per-frame scene-tree
   searches outside the 0.2s throttle, or unbounded tween/timer creation.

5. **Edge cases**, answered against the actual code, not general platformer
   assumptions:
   - Player dies while being pursued — does `_do_pursue` handle
     `_player` becoming invalid mid-frame (it checks `is_instance_valid` at
     entry, but does anything read `_player` again later in the same call)?
   - Tax Collector itself falls into a pit — is there any self-preservation,
     or does it fall like a normal physics body with no death handling?
     (Compare against how other enemies handle pit falls, if visible in the
     inlined files; otherwise state what you'd need to check.)
   - Detection radius overlaps a ladder zone — nothing in this file
     references ladders. Confirm that's simply out of scope for this AI
     (no interaction coded) rather than a bug.

6. **Gate compatibility.** Does anything in this file's syntax or structure
   look like it would fail `gdparse` or Godot's `can_instantiate()`? (Member
   shadowing, indentation mixing, etc. — name the specific hazard if you spot
   one, don't just assert it's fine.)

7. **One-paragraph verdict**: is this safe to ship as-is?

## Output format

Markdown. For every finding: `severity (high/med/low) — file:line-ish — claim
— why it matters`. No preamble.
