Role: "COMPLETE SECTION" READABILITY + PROTOCOL IDENTITY audit for a Godot
4.3 2D platformer. Read the shared facts below.

The founder rejected the shipped Diamond Vault / Fort Knox as "not just a hole
in the ground with a ladder and tokens" — he wants each to read as a real,
finished place with its own identity, not a proof-of-concept box. Real
founder-supplied art now exists (described in the facts) and is being wired
in this session.

Answer, concretely:

1. **Does the interior read as DIAMONDS vs GOLD MINE at a glance**, using the
   actual described art (diamond_vault_backdrop.png's crystal-cavern-with-
   staggered-platforms-and-a-sigil-door vs fort_knox_backdrop.png's mine-
   forge-with-cart-tracks-and-Bitcoin-roundels)? What's the minimum additional
   procedural dressing (colors, particle accents) needed to bridge the gap
   between "backdrop art in the distance" and "the platforms and props the
   player actually stands on" so the whole space feels like ONE built
   environment, not painted wallpaper behind generic gray platforms?

2. **Interactable readability.** The founder wants 2+ interactable types
   beyond a coin pile. Using `diamond_deposit_pillar.png` and
   `goldmine_melt_forge.png` as the visual anchors, how should each read as
   "this does something" at a glance (glow states, idle vs active vs
   triggered visual feedback) — a player dropping in blind should be able to
   tell what's decoration and what's interactive within a second or two.

3. **Hazard readability appropriate to identity.** The founder wants "crystal
   threats / security vibe" for Diamond Vault and "fortified / gold-security
   vibe" for Fort Knox. Propose the READ (not the code) for one hazard per
   vault that fits each identity and doesn't look borrowed from the other.

4. **Does bringing in this much more visual density risk burying the
   gameplay-critical elements** (the ladder exit, the reward, the hazard) in
   background noise? What's the layering/contrast rule (z-index, saturation,
   outline) that keeps interactive elements legible against these much busier
   backdrops than the previous flat-color vault had?

5. **Fort Knox vault door placement.** `fort_knox_vault_door.png` (380x380) is
   a striking centerpiece. Where should it sit for maximum "you are inside
   something important" impact without crowding the ~175px vertical play
   space or occluding the player?

Concrete and concise — colors, placement, layering rules. Not vibes.

@include prompts/_session3_facts.md
