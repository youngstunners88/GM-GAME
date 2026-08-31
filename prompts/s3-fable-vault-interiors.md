You are the LEAD IMPLEMENTER on a Godot 4.3 2D platformer (GM-GAME). Last
session's Diamond Vault / Fort Knox shipped as a single-tier pit: drop through
a mouth, land on one floor, grab coins, climb a ladder out. The founder has
now rejected that as too thin: "needs to be complete sections of their own;
not just a hole in the ground with a ladder and tokens." Real founder-supplied
art now exists for both vaults (described in the shared facts below) and must
be used, not invented.

Design and specify, concretely:

1. **Multi-tier interior layout within the ~175px vertical budget** (walk
   surface y=650 down to the kill band at y=825 — going deeper needs kill-zone
   surgery, which you should argue for explicitly if you think it's worth it,
   not assume). Propose 2-3 staggered platform tiers the player can traverse
   (not one flat floor), with exact StaticBody2D rects (x,y,w,h in the vault's
   LOCAL space, matching `protocol_vault.gd`'s existing `_add_solid()`
   pattern) for both the Diamond Vault (mouth_width=100) and Fort Knox
   (mouth_width=140). State how the player actually gets between tiers (short
   hops? a single-jump apex is ~92px — check your tier height deltas against
   that) and where the exit ladder attaches now that the interior is wider.

2. **Where the real art goes.** `diamond_vault_backdrop.png` (1024x576) and
   `fort_knox_backdrop.png` (1024x576) are wide painted scenes — propose how
   to seat them as the vault's backdrop (a ParallaxBackground child, sized/
   cropped/positioned how, at what z-index relative to your new solid
   platforms so gameplay reads clearly over the art). `diamond_deposit_pillar.
   png` (187x280) and `goldmine_melt_forge.png` (187x280) are candidate
   INTERACTABLE props — where do they sit in your layout, and what do they
   actually DO (the founder wants 2+ interactable types beyond a coin pile —
   propose concrete mechanics: e.g. the deposit pillar as a lever/trigger, the
   melt forge as a timed bonus, a breakable crystal wall, a guard patrol —
   pick real, buildable mechanics, not vague "interactivity"). `fort_knox_
   vault_door.png` (380x380) — propose its role (backdrop centerpiece? an
   openable door gating the reward tier?).

3. **Hazards/guards appropriate to protocol identity**, per the founder:
   "crystal threats / security vibe for Diamond Vault; fortified / gold-
   security vibe for Fort Knox." Propose ONE concrete hazard type per vault
   that's buildable with this project's existing patterns (procedural
   ColorRect/Polygon2D/CPUParticles2D, or reusing an existing enemy/hazard
   scene if one fits — check what's available before inventing a new enemy
   class from scratch).

4. **The progress loop**: enter -> explore/fight/collect -> meaningful reward
   -> climb out. What's the reward now (more than 5 coins to match the bigger
   space)? Does reaching it require doing something (not just walking over
   it)?

5. **Exact code changes** to `protocol_vault.gd` (or a clean refactor of it)
   and the two level scripts' `_setup_depth_routes()` calls. Keep the
   parametric `protocol` + `mouth_width` structure if it still fits; say so
   explicitly if it doesn't.

Concrete numbers and node types, not vibes. If a needed fact isn't in the
shared facts, say what's missing.

@include prompts/_session3_facts.md

--- Current vault implementation, full file (last session's shipped version) ---
@include src/level/protocol_vault.gd
