You are Kimi K3 (`model-kimi-chase-geometry`). Two Stage 3 questions, be concise.

CONTEXT: timed_door.tscn has a LEAK: a static ColorRect child baked directly in
the .tscn (color 0.8,0.3,0.1, size 60x120, centered at the door's position) that
predates the door script's own runtime-built visual (_build_visual() in
timed_door.gd, which layers a proper dark-body+block-texture+gold-lip look and
was clearly meant to REPLACE the old flat ColorRect per its own comment: "Now
built the same way every real platform is... reads as a built object"). The old
node was never deleted from the scene file, so BOTH render simultaneously,
which the founder screenshot shows as a confusing dark rectangle blocking a
platform near a ladder. I'm removing the dead .tscn-baked ColorRect child.

1. The door gates a SPEEDRUNNER shortcut lane at x=1520 (elevated, y~470-590);
   the ground-level path has a genuine pit there too (ground segments end at
   1520, resume at 1660), so the CASUAL ground route never touches this door.
   Given that, does removing the leftover ColorRect fully resolve "box blocks
   the path", or is there a second collider I should check? What's the fastest
   real-arena/gate check to confirm the main ground corridor is unaffected?

2. wbtc.gd and coin_btc.tscn's collectible collision radii are 15px and 22px
   respectively (native art 40x40 / 48x48). Founder: "too small to see" /
   "salt and unclear". Is modestly enlarging these (radius->20, sprite scale
   ~1.3x) a reasonable fix, or is there a more likely root cause I'm missing
   for "salt" specifically (as opposed to "too small")?

Answer both directly, no long derivation.
