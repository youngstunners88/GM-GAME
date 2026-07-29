ROLE: You are a game designer writing a Stage 2 differentiation brief for a 2D platformer.

PROJECT CONTEXT:
- Stage 1: Smoke Realm — weed/leaf theme, chill vibes, basic platforming
  - Enemies: Tax Collector (patrol), Fly Swarm (sine flight), Hostile Vine (extend/retract), Rolling Boulder
  - Boss: The Auditor (5 HP, 3-phase)
  - Power-ups: Blaze (speed), Big (size), Diamond (invincible)
- Stage 2: Crystal Caverns — DIAMONDS protocol, ice/snow/crystal theme
- Known issue: "Stage 2 feels like a boring reskin"
- Boss 2 and Boss 3 were previously inert (script shadowing bug — now fixed)
- Platform: Godot 4.3, 2D, HTML5 + Android export

DELIVERABLE:

1. THREE NEW STAGE 2 ENEMIES
   - Name + visual concept
   - Behavior (how they differ mechanically from Stage 1 enemies)
   - Attack pattern
   - Health / difficulty tuning note
   - Why this enemy is fun, not just different

2. ICE PHYSICS FEEL NOTES
   - How ice surfaces change player movement
   - Momentum rules
   - Jump arc modifications
   - One "surprise" ice mechanic that rewards mastery

3. TILESET + LIGHTING DIRECTION
   - Color temperature for the cavern
   - Parallax layer recommendations (how many, what moves at what speed)
   - Particle effects (crystals, snow, breath vapor)
   - Lighting approach (Godot 2D lights vs. baked textures)

4. LIL BLUNT STAGE 2 REDESIGN OPTIONS
   - Option A: Pixel art direction (what changes visually)
   - Option B: Shader-based direction (what effects are applied)
   - Option C: Minimal direction (keep sprite, change environment only)
   - Recommendation with justification

5. FUN TEST CHECKLIST
   - 5 objective criteria that prove Stage 2 is fun (not just different)
   - How to measure each in a 10-minute playtest

CONSTRAINTS:
- Must be implementable in Godot 4.3 2D.
- No 3D or complex shader requirements.
- Consider mobile performance (HTML5 target).
- Do not write GDScript. Design brief only.
