# Art Direction — Client Reference (2026-07-08)

Source: five key-art images from Rich (chat, 2026-07-08). This doc encodes
what's IN those images so every future art/code session hits the same target.
The images themselves live in the chat/client folder — this is the canonical
written spec derived from them.

## Lil Blunt — character anatomy (all stages)

- **Body**: round, shaggy GREEN weed-nugget; spiky serrated leaf fringe all
  around the silhouette (like a leaf mane). Muscular little arms/legs, 3-digit
  hands, mischievous confident posture.
- **Face**: HUGE googly eyes — white balls, small dark pupils, **cream/tan rims
  dotted with red** (signature trait). Wide open grin with a full row of teeth.
  Green skin, darker green outline.
- **Blunt**: lit blunt at the mouth corner, orange ember, purple-white smoke
  curls. Always present; smoke is friendly/curly, never gross.
- **Stage outfits** (world-themed skins):
  - *GM Forest (L1)*: brown **cowboy hat** with green leaf badge on the band,
    **red bandana**, **tan fringe vest** with gold star studs, brown pants,
    cowboy boots with stars, leaf belt buckle.
  - *Crystal Caves (L2)*: **miner helmet with lamp**, brown overalls/workwear,
    pickaxe; crystal-armor variant (translucent blue crystal plates + crystal
    staff) for the boss/power state.
  - *Gold Rush (L3)*: same cowboy kit as L1, doubled-down western context.

## Per-realm palettes & environment language

- **GM Forest (Level 1 / Smoke Realm)**: deep purple night sky, neon greens,
  giant glowing mushrooms (green/purple/orange/pink caps with spots),
  pine silhouettes, curling purple smoke wisps, drippy green goo on clouds.
  Platforms: puffy PURPLE clouds. Collectibles: **ETH crystals inside glowing
  green rings**. Wooden signs with mossy frames, neon-green text ("GM FOREST").
- **Crystal Caves (Level 2)**: near-black blue cavern walls dense with faceted
  crystals; biomes color-shift **blue → cyan → purple/orange** (Frostvault
  Depths / Lumina Falls / Prismabyss Core). Glowing crystal platforms,
  luminous waterfalls. Boss: **Crystalline Bureaucrat** — three-headed crystal
  suit (purple/blue/orange heads), "ETH BUREAUCRAT" name tag, ETH price
  pedestals (0.69 / 4.20 / 6.90).
- **Gold Rush (Level 3)**: orange sunset canyon, wooden western town (BLUNT
  SALOON neon, BANK, SHERIFF, GM MINE), rope bridges, mine carts on rails
  loaded with gold, **FORT KNOX castle** on the hill with GM flag, WANTED
  poster of Lil Blunt, gold nuggets everywhere in crates ("GM GOLD").
- **Boss arenas**: dark + dramatic rim-light. Tax Collector boss = fat IRS
  suit, top hat with IRS band, monocle, gold chains, "TAX SEASON" badge,
  clipboard "TAX FORM 420" (income/weed/blunt/existence/FOMO tax — TOTAL DUE:
  EVERYTHING!), money bags labeled FOMO TAX, GOV VAULT chest. Blaze-mode
  Lil Blunt gets a **golden fire aura** and shoots flaming ₿ projectiles;
  purple smoke spells "FOMO" overhead.

## HUD language (from key art)

- Top-left: rounded-square Lil Blunt portrait + name, green heart pips,
  leaf icon × count.
- Top-right: ETH-in-ring icon × count, "BLOCK 420" line beneath.
- Boss bar: top-center, name plate above a red bar in a dark frame, "BOSS" tag.
- Chunky bevel/outline pixel-style typography, warm gold accents.

## Style rules

- Bold dark outlines, saturated neon-on-dark palette, chunky readable shapes,
  16-bit-plus rendering with painterly glow. Everything friendly and round —
  no gross-out drug imagery; smoke is decorative and cute.
- Numbers gag: 420 / 69 recur (block count, prices, form names).

## Implementation status

- `src/player/lil_blunt_visual.gd` draws the GM-Forest cowboy Lil Blunt
  procedurally (hat+badge, bandana, vest, leaf mane, dotted-rim googly eyes,
  grin, blunt+smoke). Placeholder until sprite sheets are produced.
- Next asset steps (in order of impact): Lil Blunt run/jump/idle sprite
  sheets → L1 mushroom/cloud tileset → ETH-ring collectible sprite →
  Tax Collector boss sprite → HUD portrait frame.
