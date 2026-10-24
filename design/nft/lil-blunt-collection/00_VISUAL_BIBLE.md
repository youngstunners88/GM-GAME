# Lil Blunt NFT Collection - Visual Bible (2026-10-19)

Authority for look and prompts. Prompt files: `01_GAME_IMPLICIT_PROMPTS.md` (lb_nft_01-08), `02_COMMUNITY_PROMPTS.md` (lb_nft_09-16, numbered on so ids stay unique for the later ICRC-7 mapping).
Generation model: Nano Banana 2.1 in Google Flow, 1:1, always with reference images attached. Every finished piece is stamped with the neon-green ring by `tools/nft/ring_frame.py`, so: subject centred, detail inside a circle with ~12% margin, corners may fall to dark vignette.

What was actually studied: the 6 medallions, the 4 founder refs, 7 key-art stills, 5 game backgrounds, the Ep2 key art and stills, the 3 boss-defeat films frame by frame (fps 1), the 60 s Ep2 film, the 45 s $SMOKE LOUNGE loop, the Ep2 style-gate skills and `tools/ep2_film/film.json`. Not seen: the founder's Drive mp4s (same films as the repo .ogv files, which were used), his Flow outputs (bong party, golf cart, speedboat, beach), and any Drive images.

---

## FOUNDER CORRECTIONS 2026-10-19 (override anything below that disagrees)
1. **Style = the six medallions.** "This is the current collection we already have for the game." Game pieces are built on the dramatic hyper-detailed 3D-illustration finish of those plates (attach 2 plates as the style reference). Flat pixel art / key-art pieces are OUT; attempt `lb_nft_01` pixel version was rejected as generic. The recipe that worked (founder: "much better"): plates + lb refs attached, "exact finish of the attached neon medallion plates", a BRUTAL camera angle (worm's-eye), a hero lit like the plates, foreground props crowding the lens, background in layers, subject filling the circle. The model draws the circular vignette itself; the ring tool still crops and frames.
2. **He is SOMETIMES high, not always.** HIGH state = red droopy half-lidded bloodshot eyes, lazy grin, smoke curling (use for lounge, aftermath, chill pieces). ALERT state = wide googly eyes with cream rims (action, boss, blaze). Mix them across the set (about half each). The older line below that calls red eyes "off-model" is WRONG for the HIGH state.
3. **He is NOT always a cowboy.** Vary the outfit per piece: cowboy kit (L1/L3), miner helmet + overalls (L2), goggles hat, $SMOKE purple/teal velvet tracksuit with bling like the grandpas, emerald velvet smoking jacket, black bomber with gold chains, tailored three-piece in Solana purple/teal with a top hat, denim vest with patches, hard hat and work vest, sequin vest and bling. Face, green muscular body, leaf crest, googly eyes and the cigar stay constant.
4. **The founder's own prompt voice (from his Flow workspace) is the taste bar for community pieces**: absurd, funny, specific characters with personality (three grandpas in the $SMOKE LOUNGE: one all blinged out in a hip-hop outfit, one in a tailored three-piece suit with Solana colour-coding and a top hat, one a punk rocker with a mohawk and jewellery like a young rapper), crowds of women cheering, everybody holding branded bongs with "red droopy eyes", "hyper realism, photo realistic"; a private jet shaped like a smoking bong; a luxury car shaped like a bong; the SmokeRing cast (leaf character in shades, Pepe frog, gorilla with a cigar, pit bull in a $SMOKE jersey) racing a golf cart away from police; a weed-wrapped speedboat party; women smoking on a beach. Energy: rowdy, proud, funny, status-flexing, crypto-culture. Not tasteful stock photography.

## 1. Lil Blunt, exactly

He exists in four on-model renderings. They are one character; pick by piece, never mix their faces inside one image.

| Rendering | Where | Face | Use for |
|---|---|---|---|
| A. Logo / medallion | `lb_ref_01`, `lb_ref_02`, `badge_lilblunt.png`, the three Blaze Rush plates | muscular, huge googly white eyes with cream rims dotted red, wide toothy grin with a red tongue | anything action or hype; the founder's brand face |
| B. Boss-cut 3D "chunky chibi" (the STYLE AUTHORITY for 3D) | `stage1/2/3_boss_defeat.ogv`, `IMG_2480`, `KEYART_zipline` | same big round eyes, stubbier proportions (head about 40% of height), painterly 3D, glossy skin, soft rim light | all 3D game pieces |
| C. Chill smirk (Ep2 A-pose) | `STILL_lil-blunt_apose_v2.png`, stage2 film 24-32 s | heavy lids, small closed smirk, leaf ruff around the face like a beard, leaf-covered arms, leather vest, blue jeans, brown gloves | quiet, intimate, community moments (he is "chill" here) |
| D. Pixel | `lb_ref_03`, `src/assets/sprites/sprite_lil-blunt_*.png` (tiny), the game itself | same as A in chunky pixels, black outline | pixel pieces |

Constant anatomy (every rendering):
- Skin: smooth, glossy green, frog-like face, NO nose, no visible ears, thin or no brows. Cream-ish rims around the eyes with red speckles (the signature; present in A, B, D; softened in C).
- Hair: a spiky serrated cannabis-leaf crest and a leaf ruff around the jaw and shoulders. Never a human hairstyle, never dreads.
- Eyes: large, round, slightly wall-eyed googly. Pupils small and dark; they carry the acting (side-eye, wide, half-lid).
- Mouth: huge grin full of white teeth with a red tongue (A/B/D) or a lopsided closed smirk (C). A lit cigar/blunt always sits in the corner, orange ember, smoke grey-white, curly, friendly.
- Body: stocky, muscular little arms, short legs, brown gloves, big brown boots with brass spur and strap. Small: about one metre tall when placed among real adults; chest-height to a standing adult.
- Costume core: brown cowboy hat with a green cannabis-leaf badge on the band, red bandana, tan/brown fringed leather vest with gold star studs, belt with a round gold leaf buckle, belt pouches, chain, spurred boots.
- Realm variants (art_direction_reference.md): L1 Smoke Realm / L3 Gold Rush = cowboy kit; L2 Crystal Caverns = brown miner helmet with a glowing headlamp, grey-blue work shirt/overalls, pickaxe, leaf buckle (crystal-armour variant for the boss state); L3 boss cut = goggles on the hat brim; Ep2 = cowboy kit or miner helmet, golden Remington 1875 (grip engraved with a bitcoin B), Winchester 1886.

On-model poses and expressions seen in the founder's own films: smug side-eye with cigar; delighted wide grin; deadpan squint exhaling a cloud of smoke (stage2, 9 s); kicking a vault chest open with one boot (stage1, 8 s); resting a pickaxe on the shoulder (stage2, stage3); sitting on a cart rim, relaxed (stage3, 12 s); hand-spread "ta-da" with cigar (stage3, 10 s); wincing/groaning (ep2 film).

OFF-MODEL (reject and regenerate): a human or human-faced rapper (the name "Lil Blunt" does this, never write it); a muppet / fuzzy felt creature (the Seedance films were rejected for exactly this); anime or kawaii big-smile sticker faces; a pot-leaf-shaped head; leaf-skinned (textured like foliage) body; a face with a nose or lips; a gun pointed at a person; any aggressive snarl; dreadlocks or Rasta colour-coding; a joint instead of the cigar-blunt; stoner-cliche red-eyed zombie staring (his eyes are googly, not bloodshot).

## 2. The worlds

2D side-scroller (Levels 1-3): painterly 16-bit-plus pixel art, bold dark outlines, saturated neon on dark, glow baked in, parallax layers, platform tiles with drip and glow.
- Smoke Realm / GM Forest (L1): deep purple-indigo night, neon green, giant mushrooms with glowing gills (magenta, orange, green caps), pine silhouettes, curling purple smoke, puffy PURPLE cloud platforms with green goo, an Ethereum diamond hung in the pink moon (`bg_l1_forest.jpg`), ETH crystals in green rings, wooden "GM FOREST" sign.
- Crystal Caverns (L2): near-black blue walls, faceted crystals blue to cyan to violet, luminous waterfalls, crystal-slab platforms (`IMG_9540`).
- Gold Rush (L3): orange sunset canyon, rail track vanishing to a giant bitcoin sun (`bg_l3_goldrush.jpg`), western town with a BLUNT SALOON neon, bank, sheriff, rope bridges, mine carts of gold, Fort Knox castle on the hill, WANTED poster, "GM" crates (`IMG_9542`).
- Bosses: Auditor/IRS in the GOV VAULT, black-green with lava and FOMO smoke letters (`IMG_9543`, `bg_boss_tax.jpg`); Crystalline Bureaucrat, three crystal heads blue/violet/amber (`IMG_9571`); Claim Jumper in a skull-plated minecart with TNT and bitcoin (`IMG_9572`).
- Blaze Mode: golden fire aura around him; Blaze Rush: he rides a flaming diamond; dash corridor.
- Smoke Lounge: emerald and amber luxury lounge, leaf-logo ashtrays, hookah, whiskey, gold bars, bulldog statue, neon sign with a leaf and a dollar-S.

Episode 2 (3D first-person shooter): photoreal-painterly 3D, warm amber vs cold blue, hard shafts of light with floating dust, lanterns, rails, molten gold hearths, gold nuggets embedded in rock, pine forest at golden hour, fog on distant Fort Knox walls, the gold-rush town target image (`goldmine_town_target.jpg`: timber facades, Fort Knox with towers, stockpile, treasury, certificates office, horses, a crowd). Characters: Inferno Bull (black muscular bull in horned miner hat, aviators, red bandana, Winchester), balaclava bear archers, Rich and Utah at the armory, the founder's Sheriff (grey beard, pipe) and Minister Mike Dean (robot-head minister), Logan at the lake. The founder's own Ep2 key art (`IMG_2480`, `KEYART_zipline...jpg`) already shows the rule for Mode C: a small stylised Lil Blunt, correctly lit and with sparks, inside a fully photoreal scene.

Which style fits which piece:
- MODE G-PIXEL (modern high-res 16-bit): moments that are literally platformer moments - double jump (01) and secret alcove (08).
- MODE G-3D (boss-cut cinematic 3D / medallion look): boss, Blaze, minecart, Smoke Lounge pieces (02-06).
- MODE G-KEYART (painterly 2.5D side view like `IMG_954x`): protocol portal room (07).
- MODE C (photoreal film still, stylised 3D Lil Blunt among real people): all community pieces (09-16).

## 3. Why the six medallions look cool (checklist every prompt satisfies)

Looked at at full size (`design/nft/drive/*.png`):
1. Camera is CLOSE and slightly LOW. The subject fills 60-75% of the circle; a boot sole or a table is shoved toward the lens (boss 3). Blaze Rush plates use a dynamic diagonal, not a vertical pose.
2. Three depth planes every time: foreground props cropped by the circle (ashtray of buds, whiskey, TNT, gold bars, tax notices), the character in the midground, an out-of-focus brand wall behind (neon sign, framed leaf, lamp, bulldog statue, plants).
3. Rim light plus key light, different temperatures: warm key on the face (whiskey amber), neon-green rim from behind. One accent colour per plate (purple smoke, gold, red) so the palette stays disciplined: black-green and gold (boss 1), violet-cobalt-gold (boss 2), brown-red-gold (boss 3), fire-orange against a cool saturated background (Blaze Rush).
4. Smoke is a lit object: two colours, curling, backlit, bending around props; it separates layers rather than filling the frame.
5. In-world branding as set dressing (leaf-logo ashtray, leaf frames, neon sign, "TAX SEASON" bottle, TNT, GM carts) - nothing is a floating logo. Props do the world-building.
6. Character ACTING is the joke: heavy-lidded boredom, cigar in the grin, drink in hand, boots up. Villains are lounging in the Smoke Lounge, which is funnier than fighting.
7. Texture detail rewards zoom: pinstripes, leather grain, glass refraction and ice, trichomes, crystal facets, brass specular, embroidery.
8. Glossy 3D-illustration finish, micro-contrast, bloom only where light sources are; dark value structure so the bright subject pops.
9. Circle-aware composition: leading lines curve with the ring, corners fall to dark.
10. Each plate is a single moment with a cause and an emotion (smug, drunk-calm, mid-jump delight), not a poster pose.

## 4. THE CHEESE LIST (what attempt 2 did wrong, and the fix)

| Cheese | Why it fails | Do instead |
|---|---|---|
| Flat children's-book outlines, uniform line weight | reads as clip art; kills depth | rendered 3D-illustration or true pixel art; light defines form |
| Centred, symmetrical, smiling mascot-pose | poster, no story | caught mid-action or mid-thought, off-axis body, camera angle with tilt, a cause for the expression |
| Generic glowing-mushroom forest with rainbow smoke clouds | every AI fantasy stock image | one specific place from the game (ETH-moon, the GOV VAULT lava ledge, the crystal vault door) with 3 depth planes |
| Smiling puffy clouds, sparkle confetti, floating stars | noise with no light source | smoke only as lit ribbons; sparks only from a physical cause (fire, pickaxe, coin) |
| Rainbow palette | no colour hierarchy | one dominant hue family + gold + one accent |
| Text banners, "BLAZE RUSH" lettering, UI | models garble it; collectors read it as a poster | no lettering. If a sign is needed, show only a glowing leaf plus dollar-S glyph |
| Lil Blunt as a lone cute sticker on a background | no relationship to the world | he is lit by the scene, casts a contact shadow, touches props or people |
| Even, flat lighting | no mood | motivated light: lava, lamp, neon, sun; deep shadows |
| Stock-photo "diverse friends smiling at camera" | cheesy | candid, mid-laugh, no one looks at the lens, one thing is a bit chaotic |
| Real-person plastic skin, airbrushed | uncanny | pores, flyaways, film grain, imperfect clothing |
| Pot-leaf wallpaper, drug paraphernalia piled up | stereotype; breaks the brand rule | one or two characterful props (hookah, glass piece, ashtray), warm and relaxed |

## 5. Two style modes and how to prompt each

MODE G (game-faithful).
- G-PIXEL: "modern high-resolution 16-bit pixel art, like a hand-painted frame from a premium 2D platformer", clean dark outline on the character, 3-4 parallax layers, dithered fog, limited palette named in the prompt, one warm accent. Attach `lb_ref_03` (pixel body) and a game background or key art for the world.
- G-3D: "cinematic 3D-animation film still, painterly, chunky chibi proportions", name a real lens and camera height, name the key light and rim light, the one accent colour, set dressing, the emotion. Attach a medallion plate (finish and lighting) plus `lb_ref_01/02` (face).
- G-KEYART: bold outlines with painterly glow, side view, game-HUD-free (explicitly say no HUD). Attach `IMG_954x`.
MODE C (community). Photoreal cinematic film still on a real lens (35/50/85 mm, anamorphic bokeh, grain, halation). Lil Blunt is a stylised 3D character composited into the plate: say "a stylised 3D animated creature about a metre tall, not a human, not a costume", demand matched light, contact shadow and smoke interaction. Real adults of mixed ages, body types, skin tones, in specific non-logo clothing; candid acting; in-world props only. Attach `lb_ref_02` (face and costume), `STILL_lil-blunt_apose_v2.png` (3D skin and material) and `IMG_2480_action_jump.jpg` (how the founder's own pipeline composites him into a photoreal frame).

Prompt rules that follow from the above: never the bare name; describe him as "the green muscular cannabis-bud mascot from the attached references"; describe every reference by what it shows; say "keep his face, body and cowboy costume exactly as in the references"; 1:1, centred, nothing in corners; no text, no logos on clothing, no UI.

## 6. Moments in the videos and game worth turning into NFTs

(All paths under `src/assets/video/` unless noted; times in seconds; boss films are the founder-approved style.)
- Stage 1, `cutscenes/stage1_boss_defeat.ogv` 0 s: Lil Blunt on a basalt ledge, cigar, green smoke ETH glyph, lava behind (the best single 3D face + costume frame). 1-2 s: he exhales a green energy stream that blasts the Tax Form 420 clipboard. 8-9 s: he kicks open the GOV VAULT chest and chops it with a pickaxe, gold coins spilling, TAX sack. 11-12 s: crystal-armour variant. -> piece 02.
- Stage 2, `cutscenes/stage2_boss_defeat.ogv` 0-10 s: crystal titan fight (3-headed crystal bureaucrat, lightning, shard burst at 4-8 s). 9 s: deadpan miner exhaling a smoke cloud in light shafts. 12-15 s: the huge brass vault door cracks, gold light floods, he walks into it as a silhouette. 16-24 s: GM-emblem chest opens. 24-32 s: golden revolver with bitcoin grip, side-eye smirk. -> pieces 04, 07.
- Stage 3, `cutscenes/stage3_boss_defeat.ogv` 0-3 s: Claim Jumper skull minecart, dynamite, bitcoins. 4 s: spinning bitcoins vs a hand (macro shot). 7 s: cart explodes. 9-10 s: Lil Blunt in the dust and smoke, goggles hat, pickaxe, hand-spread grin (best joyful face frame). 11-13 s: he rides a cart rim. -> piece 05.
- Ep2 film, `cutscenes/ep2_cliff_to_hideout.ogv` 0 s: silhouetted cart leaps the gorge at sunset (great NFT for an Ep2 bonus). 10 s: Inferno Bull in the forest light. 15-20 s: Bull kneels over the knocked-out Lil Blunt in the molten-gold smelter with FORT KNOX sign. 55-60 s: armory racks, Lil Blunt in sunglasses holding a gold bitcoin and pickaxe beside a miner helmet.
- Lounge loop, `smoke_lounge.ogv` 0-4 s: dark corridor, neon "$SMOKE LOUNGE" between bitcoin, solana and ethereum wall art. 4-8 s: two glamorous women walk out of green fog. 12-16 s: long lounge of real people on purple sofas, hanging cannabis plants, green strip light. 20 s: glass vaults of coins. 28 s: a diamond with lightning and a ring of gold coins on the floor (crowd lounging around it). Real-people look to match in Mode C.
- Game stills: `IMG_9541` (L1 run with ETH rings), `IMG_9542` (Gold Rush town), `artifacts/episode2-gold-mine/references/KEYART_zipline-revolver-pickaxe_bears.jpg` (zipline), `IMG_2492...cart-jump` (cart jump past boulders and bears).
- Bonus candidates if the founder wants more: gorge cart-leap silhouette (ep2 film 0 s); the golden revolver chest (stage2 24-32 s); the Bull and Lil Blunt on the woods bridge (`founder_2026-10-10b/exiting_outside_mine_bull.jpg`); the founder's golf-cart-of-cast escape, the Miami weed-wrapped speedboat party and the beach pieces he already has in Flow (re-shoot in Mode C).

## 7. Prompt vocabulary mined from the founder-approved films

`tools/ep2_film/film.json` style line: "Painterly cinematic 3D-animated adventure film ... chunky chibi ... dynamic trailer-style camera, warm saturated golden light, rich amber colour grade". Useful phrases to reuse: slow-motion arc, steam and embers drifting, molten gold glowing behind, cigar smoke curls, bright muzzle flash, god rays with floating dust, rack focus on a prop, extreme macro on coins or a revolver, silhouette walking into a blinding door, low hero angle, heavy chains hanging in dust. Palette habits: warm amber against cold cobalt/violet; black-green with lava orange; gold light as the reward.

## REFERENCE FRAMES

Scratch folder (local, NOT in the repo): `/tmp/claude-1000/-home-kofibeatz-Documents-GitHub-GM-GAME/3532b4df-2afa-4a9d-8cbf-df1d2f464ea5/scratchpad/ref_frames/` (1280x720 JPEGs, extracted with ffmpeg from the .ogv files). None of the extracted JPEGs are on origin/master (checked with `git ls-tree -r origin/master --name-only | grep <name>`: 0 hits each). Their SOURCE videos are on master, so Flow can only get them if the coordinator commits the frames or hosts them.

| File | Shows | On origin/master? | Use |
|---|---|---|---|
| `lbframe_s1_cowboy_cigar_0s.jpg` | boss-cut Lil Blunt, cowboy kit, cigar, grin, green ETH smoke, lava (best face+costume 3D reference) | no (source `src/assets/video/cutscenes/stage1_boss_defeat.ogv` yes) | pieces 02, 06, community 09-16 as a 3D look ref |
| `lbframe_s3_goggles_grin_10s.jpg` | joyful hand-spread grin, goggles hat, pickaxe, dynamite dust | no (source stage3 ogv yes) | piece 05 |
| `lbframe_s2_miner_smoke_9s.jpg` | miner helmet, deadpan squint, big smoke cloud, crystal light | no (source stage2 ogv yes) | pieces 03, 04 |
| `lbframe_s2_revolver_smirk_28s.jpg` | chill smirk close-up with the golden revolver | no | quiet pieces 06, 10 |
| `lbframe_s1_pickaxe_vault_9s.jpg` | kick/pickaxe on the vault chest, gold coins | no | piece 02 |
| `lbframe_lounge_diamond_28s.jpg` | real people on lounge sofas around a diamond and gold coins, neon sign | no (source `smoke_lounge.ogv` yes) | light/mood ref for Mode C |
| `lbframe_lounge_crowd_12s.jpg` | long lounge, green strips, purple sofas, crowd | no | Mode C set ref |
| `lbframe_ep2_bull_kneel_15s.jpg` | Inferno Bull in the molten-gold smelter | no | optional |

Files that ARE on origin/master (confirmed) and usable by raw URL `https://raw.githubusercontent.com/youngstunners88/GM-GAME/master/<path>`: all six `design/nft/drive/*.png`; `artifacts/episode2-gold-mine/references/STILL_lil-blunt_apose_v2.png`; `IMG_2480_action_jump.jpg`, `IMG_2492_cart-jump_bears-arrows-boulders.jpg`, `KEYART_zipline-revolver-pickaxe_bears.jpg`, `inferno_bull_armed.jpeg`, `goldmine_town_target.jpg`, `fort_knox_prep/saloon/hero.jpg` (same folder `artifacts/episode2-gold-mine/references/`); `assets/keyart/IMG_9540-9543.jpg`, `IMG_9571.jpg`, `IMG_9572.jpg`; `src/assets/art/badge_lilblunt.png`, `smoke_lounge_banner.png`.
NOT on master (git-ignored `references/`): `lb_ref_01..04`; they must come from the Drive ids in the skill `gm-game-nft-lil-blunt-collection`.
