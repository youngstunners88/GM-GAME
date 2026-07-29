ROLE: Art director for a Geometry-Dash-style auto-runner secret bonus mode
in a 2D platformer.

CONTEXT — the real current implementation, so you design for what exists,
not a generic auto-runner:

- File: `src/dashmode/blaze_rush.gd`. Internal name "Blaze Rush" (player-
  facing framing: Lil Blunt compresses into a smoke cube and auto-runs a
  corridor; one tap to jump; instant restart on crash). Reached via a
  hidden `BlazePortal` once the player's score crosses a threshold.
- Current visuals are placeholder-flat: solid-color `ColorRect`s for
  everything. Background is one flat dark-purple rect
  (`Color(0.05, 0.01, 0.12)`). Floor segments are flat purple
  (`Color(0.25, 0.1, 0.45)`) with a thin mint-green top edge. The player is
  a green square with two black rectangle "eyes." Three obstacle/pickup
  types, currently all flat rects too:
  - **candle** — a thin red "market-dip candle" (wick + body), a hazard,
    kills on touch.
  - **fud_wall** — a purple wall labeled "FUD" in text, safe to land on top
    of, a crash if hit from the side.
  - **smoke** — a small pale square token, the collectible ($SMOKE), gives
    score and a coin chime on pickup.
  - Gaps in the floor (pits) are the fourth "obstacle" — just missing floor.
- This is the literal thing the client called "dry as fuck" — not the main
  platforming levels (those already have painted parallax backgrounds,
  particle effects, etc.), just this specific bonus mode, which never got a
  visual pass beyond programmer-art rectangles.
- Run speed 320px/s, gravity 2200px/s², one-tap jump. Course length varies
  by level (~3400px typical). No music/beat-sync currently exists in code.

DELIVERABLE:
1. Visual direction — make it feel "trippy"/"high" without breaking
   readability of hazards vs. safe ground vs. collectibles at 320px/s:
   - Color palette distinct from the Smoke Realm (forest green), Crystal
     Caverns (cave cyan), and the Smoke Lounge (purple-grey, chill/slow) —
     this mode is FAST and should feel more electric/urgent than any of
     those, while staying in the game's neon/420-friendly identity.
   - Background layers: how many, what content, what parallax speed
     (state feasibility for CPUParticles2D-driven elements vs. anything
     needing new art files — no new sprite sheets exist for this pass).
   - How the three obstacle/pickup types should read at a glance while
     auto-running — silhouette/color rules so a player never mistimes a
     jump because a hazard and a safe wall look similar at speed.
2. Motion-linked effects (no music exists yet, so not strictly "beat-sync" —
   effects tied to RUN SPEED/proximity instead):
   - What could pulse or streak with forward motion (background, obstacle
     edges, a player trail)?
   - How to telegraph an upcoming hazard/gap a beat before it's on screen,
     given the auto-run leaves no room for a slow reaction.
3. Consistency: does this mode need any visual thread back to the main
   Smoke Realm identity, or is "this is the wild secret mode, it's allowed
   to look different" the right call? Your recommendation either way.
4. Asset list: what's achievable with CPUParticles2D + primitives only
   (this pass has no new sprite budget) vs. what would need a real sprite
   sheet (name it, don't design around it).

CONSTRAINTS:
- Godot 4.3 CPUParticles2D + ColorRect/Panel primitives + procedurally
  generated textures only (a runtime radial-gradient texture is an
  established pattern in this codebase — assume it's available). No
  GPUParticles2D (HTML5 target), no external shaders beyond CanvasItem.
- HTML5 + Android performance: this mode auto-scrolls fast, so keep total
  particle counts conservative — state a rough ceiling.
- Do not write GDScript.
- If unsure whether something is feasible in Godot 4.3, say so rather than
  asserting it.
