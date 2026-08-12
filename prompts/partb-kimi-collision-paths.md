Role: COLLISION / ENTRANCE-EXIT PATH + SOFT-LOCK auditor for two new in-level
downward set-pieces in a Godot 4.3 2D platformer. This is the role that has
previously caught real geometry bugs by deriving numbers from the actual
files — do that here, don't hand-wave. Read the shared facts below.

The founder's hard gates: **can enter (drop down), can exit (climb up), NO
soft-lock.** Your job is to prove the entrance and exit paths are geometrically
sound and find where they'd break.

Derive and answer, with arithmetic shown:

1. **Drop-in is survivable and lands in the chamber, not the kill zone.**
   Player is 32x32 (feet at centre+16), gravity 1000, max_fall_speed 720
   (~12px/frame). The kill band is a full-width Area2D occupying y≈825..1225.
   Proposed chamber floor surface y≈800. Prove: (a) a player dropping from the
   main floor (y=650) through a 100px-wide mouth lands on the y≈800 floor and
   rests with feet at ~800 / centre ~784, never triggering the 825 kill band;
   (b) they cannot tunnel THROUGH a 40px-thick floor StaticBody at 12px/frame;
   (c) the side walls must be tall/solid enough that a player running into a
   wall at walk_speed 200 can't be squeezed under it into the kill band. State
   the minimum wall extents.

2. **The upward exit cannot soft-lock.** Exit is a `ladder.tscn`: player enters
   CLIMB inside a 44px-wide Area2D, climbs at 150px/s, and on top-out is
   teleported to `global_position + top_exit_offset`. Prove the proposed
   ladder (chamber floor ~800 up to main floor 650 = ~150px climb) with its
   `top_exit_offset` lands the player CENTRED on a solid ground segment (not
   over the adjacent pit, not clipped into a wall). Do the arithmetic for the
   Diamond Vault (L2 gap 2400-2500, exit onto segment 2500-3000) and the Fort
   Knox (L3 gap 2620-2760, exit onto segment 2760-3220). A single jump only
   clears ~92px, so confirm the ladder — not a jump — is the required exit and
   that there's no scenario where the player is stuck below with the ladder
   unreachable.

3. **Failure modes to rule out explicitly:** player drops in, misses the
   ladder zone, and is trapped on the chamber floor with no way up (is the
   ladder reachable from wherever they land?); player enters the ladder zone
   but the top-out point is over air; the mouth is narrow enough that the
   player catches the shoulder of an adjacent floor segment (y=650..720) on the
   way down and never actually enters; the chamber floor overlaps/omits the
   kill band such that standing in the chamber still kills.

4. Give the concrete numbers you'd USE (chamber floor rect, wall rects, ladder
   position/height/top_exit_offset) for both vaults if you disagree with the
   proposed placement.

Show the arithmetic. If a needed fact isn't below, name it.

@include prompts/_partB_design_facts.md
@include /tmp/claude-0/-home-user-GM-GAME/a77cc0d7-ba64-5875-85a6-fe6f7aa41b68/scratchpad/partb/ladder.gd
@include /tmp/claude-0/-home-user-GM-GAME/a77cc0d7-ba64-5875-85a6-fe6f7aa41b68/scratchpad/partb/level_base_geometry_killzone.gd
