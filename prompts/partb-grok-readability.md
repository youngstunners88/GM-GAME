Role: VISUAL / READABILITY + PROTOCOL-IDENTITY audit for two new downward
set-pieces in a Godot 4.3 2D platformer. Read the shared facts below.

The two set-pieces are in-level recessed chambers the player drops DOWN into:
- **Diamond Vault** (Stage 2, Crystal Caverns) — DIAMONDS protocol identity.
- **Fort Knox** (Stage 3, Gold Rush) — GOLD MINE protocol identity.

Your job is purely readability/identity, not code. Answer:

1. **Distinct silhouette per protocol.** The art is procedural (ColorRect /
   Polygon2D / CPUParticles2D — no sprite sheets for this). Give a concrete,
   buildable recipe for each vault's DROP-IN MOUTH and INTERIOR so a player
   instantly reads "DIAMONDS strongroom" vs "GOLD vault" and neither is
   confusable with the existing entrances (smoke-ring torus Blaze Portal;
   golden-shimmer Smoke Lounge alcove). Specify colors (RGB), shapes, and
   one signature VFX each. DIAMONDS palette skews cyan/prismatic; GOLD skews
   brass/amber/steel.

2. **Readability of the entrance as "go down here".** A downward mouth in the
   floor can read as just a lethal pit (this game HAS lethal pits). What
   visual cues (framing, glow, an arrow/beckon, a lip treatment) make THIS
   opening read as a safe, rewarding vault to drop into rather than a death
   pit — without a text tutorial?

3. **Interior legibility in a ~300px-wide × ~150px-tall room.** It's a
   compact recessed chamber. What's the minimum decor that makes it feel like
   a designed vault interior (not an accidental hole) and clearly shows the
   reward + the exit ladder, at that size?

4. **The "Fort Knox" name collision.** Stage 3 already has a wallet-gated
   spectacle alcove titled "— THE FORT KNOX VAULT —". The new playable
   downward vault is also Fort Knox (founder's locked naming). Two things
   labelled Fort Knox in one level is a readability problem. Recommend the
   cleaner split of identities/labels.

Concrete and concise. RGB values and shapes, not vibes. If you need a fact
not provided, say so.

@include prompts/_partB_design_facts.md
@include src/level/hall_of_blaze.gd
@include /tmp/claude-0/-home-user-GM-GAME/a77cc0d7-ba64-5875-85a6-fe6f7aa41b68/scratchpad/partb/blaze_portal_head.gd
