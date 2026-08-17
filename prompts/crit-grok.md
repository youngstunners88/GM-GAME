You are Grok 4.5 with the skill `model-grok-stage3-aesthetics`. Founder,
verbatim and furious: "The stage 3 is still looking shit and you havent done
anything!!!" and, about the Fort Knox Assay panel, "Remove this background and
improve the words as they are still fucked!!!"

STAGE 3 CURRENT DATA (already cleaned once: melt forges thinned 5->3 and
grounded; a bare brown ColorRect "bridge" box replaced with real terrain;
big_axe throw scale raised 1.55->1.95 and pickup 1.15->1.45):

@include src/resources/level_03_data.tres

Palette in that file: parallax browns (0.15,0.1,0.08) and (0.25,0.18,0.12);
platform body (0.18,0.09,0.04) + gold lip (0.95,0.75,0.2); floating platforms
gold lip (1.0,0.82,0.3). Script also adds: 6 gold-dust CPUParticles2D emitters,
a timed gold gate + pressure plate, 4 gold one-way platforms with coins, a
ladder, 3 secret walls in pits, a "GOLD RUSH RESERVE" alcove, a Fort Knox vault
door. Enemies: 4 tax collectors, 4 fly swarms, 3 hostile vines, 3 rolling
boulders. Collectibles: 16 gold tokens, 8 wBTC, 2 ETH rings, 3 BTC coins.

ASSAY PANEL (Fort Knox interior, right side of screen). Current construction:
a dark ColorRect backing panel 380x680 at alpha ~0.92, a gold edge bar, title
"ASSAY SCALE" (34px), a 230px scale sprite with a translucent halo ring behind
it, a needle, then STAKED / RETURN labels (26px) with live value numbers (30px)
below them, then "[E] WEIGH GOLD" (26px). All labels are gold-on-dark with a
black outline. The founder's screenshot still shows the panel sitting on top of
an extremely busy gold-and-machinery painted backdrop, and he says the words
are still unreadable.

ANSWER:
1. Stage 3: given the counts above, what is ACTUALLY making it read as "shit /
   random" — be specific and blunt. Rank the top 3 changes. Strongly prefer
   REMOVAL and hierarchy over adding anything. Give concrete numbers (e.g.
   "cut gold tokens from 16 to N", "kill the dust emitters", etc).
2. Assay panel: the founder says REMOVE the background. Should the fix be
   (a) a fully opaque panel, (b) a blur/darken of the art behind it, or
   (c) something else? What single change most improves legibility? What should
   be the dominant element, and what should shrink?
3. Blunt verdict on each: what would STILL look shitty after the changes above?
No code. Prioritised and specific.
