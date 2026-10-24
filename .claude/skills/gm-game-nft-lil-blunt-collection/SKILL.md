---
name: gm-game-nft-lil-blunt-collection
description: "The Lil Blunt NFT Collection for the Captain (founder brief 2026-10-19): 12-16 earned/community pieces, ~50/50 Game-Implicit moments and Community/Cultural-Reflection scenes, every piece a circular medallion with the neon green ring, art made in Google Flow (Nano Banana 2.1) from the founder's real Lil Blunt reference images. TRIGGER on: Lil Blunt collection, NFT art for the Captain, 'cook some NFTs', community NFTs, stoner community art, generating NFT art, presentation board. NOT the six soulbound achievement NFTs (those are gm-game-nft-collection - never add ids there)."
---

# What it is (Google doc "NFTS", founder 2026-10-19, id 1AzDsDVvyl8LA0hX6HABz3KIqzTW2xrBhA_z6Ek3BBjY)
A second, broader collection around the six founder achievement cards. Earned / community-gated, separate from the 888 Season Game Passes, later eligible for Bong Party stake payouts. Out of scope here: pass floor math, burn rules, canister/ICRC-7 code, Meshy 3D spin versions. Success = the Captain reacts to real art instead of economics theory.
- **Game Implicit (6-8):** a moment that only exists because a player lived it (Smoke Realm double jump; Auditor defeated in the GOV VAULT with the pickaxe; Blaze Mode through Crystal Caverns; crystal titan smash; skull minecart after Claim Jumper; alone in the Smoke Lounge with a floating ETH ring / Diamond Shard; protocol portal / whitepaper room; a hidden-alcove secret).
- **Community / Cultural Reflection (6-8):** real men AND women, all ages and body types, in the Smoke Lounge / Bong Party world with Lil Blunt as an EQUAL (never a mascot on a leash). Subtle $SMOKE/$DIAMONDS/$GOLD iconography in the environment, never logos on clothing.
- Hard rules: Lil Blunt never aggressive; weed content positive and chill; enemies never weed-themed; no minors; no real wallet/contract addresses; no text, UI or watermark inside the art.

# THE QUALITY BAR (founder, same day, angry: "cool as fuck, not cheesy, not generic trash")
1. Lil Blunt is NEVER invented from words. Always attach his real reference images (below) and say "keep his face, body and cowboy costume exactly as in the references". Writing the bare name "Lil Blunt" makes Nano Banana draw a human rapper (it happened).
2. Target = the six existing medallions in `design/nft/drive/*.png`: dramatic rim light, close hero camera, heavy atmosphere, in-world brand set dressing, glossy 3D-illustration finish. NOT flat children's-book cartoon, NOT a centred smiling mascot in a generic glowing-mushroom forest (that was attempt 2).
3. Some pieces are IN THE GAME'S OWN STYLE (16-bit pixel scene, 2.5D key-art look, the 3D medallion look); the community pieces read as film stills with real people. The research agent's `design/nft/lil-blunt-collection/00_VISUAL_BIBLE.md` + `01_/02_*_PROMPTS.md` are the authority on look and prompts: read them before generating.
4. Square 1:1, subject centred in a circular safe zone (the ring crops the corners), no text.

# The founder's real Lil Blunt references (public share links, fetch with `https://lh3.googleusercontent.com/d/<id>=w1500`)
| file (local, git-ignored) | Drive id | what it shows |
|---|---|---|
| lb_ref_01_fomo_rocket.png | 16fLBDUZ59Wxq8_oNw0PFpk2WqILsnCQA | muscular green bud, leaf crest, dark eye-mask patch, googly eyes, cigar, riding a rocket, teal ring |
| lb_ref_02_smoke_rocket_cowboy.png | 1rexOZX1Dpi4SgJwAtYzUtHetviLdhpaN | cowboy version on a $Smoke rocket, copper ring |
| lb_ref_03_pixel_gun.png | 1q4JtMNsJp-f-VVkpfzfNTLisal1YlVKM | pixel-art cowboy with the gold revolver |
| lb_ref_04_smoke_lounge_banner.jpg | 1IoMzM87byflE6-9roDmE2zG7cDTwEVsk | Smoke Lounge banner: him at a lowrider's open hood full of buds |
Also public on master (fetchable from a Flow page via raw.githubusercontent.com): the six plates `design/nft/drive/*.png`, `artifacts/episode2-gold-mine/references/STILL_lil-blunt_apose_v2.png`, `assets/keyart/IMG_95*.jpg`.

# Pipeline (each step is its own skill)
brief + bible -> `gm-game-nft-flow-generation` (make raw art) -> `gm-game-nft-green-ring` (stamp the ring, check) -> `gm-game-nft-drive-delivery` (board + Drive folder). Log in the vault `GM Game/Projects/Lil Blunt NFT Collection.md` (VAULT-LOG RULE).

# Folder + names (repo, `design/nft/lil-blunt-collection/`)
`00_VISUAL_BIBLE.md`, `01_GAME_IMPLICIT_PROMPTS.md`, `02_COMMUNITY_PROMPTS.md`, `03_GENERATION_LOG.md` (prompt -> image, model, notes, updated after EVERY batch), `references/` (git-ignored), `raw/` (Flow output), `outputs/game|community/` (ring-framed finals), `board/`. File names `lb_nft_NN_game_<slug>_v1.png` / `lb_nft_NN_community_<slug>_v1.png`. Keep file hygiene clean: ids must later map to ICRC-7 token ids.

# FOUNDER CORRECTIONS 2026-10-19 (later the same day; they override anything above that disagrees)
- Style = the six medallions ("the current collection we already have for the game"). Game pieces: hyper-detailed rim-lit 3D-illustration finish, attach 2 plates. Pixel art and flat key-art pieces are OUT. The winning recipe (founder: "much better"): plates + refs, a brutal camera (worm's-eye), foreground props at the lens, layered background, subject fills the circle.
- Lil Blunt is SOMETIMES high (red droopy bloodshot half-lidded eyes) and sometimes alert (wide googly eyes); mix about half/half. He is NOT always a cowboy: vary outfits (miner, $SMOKE tracksuit, velvet jacket, bomber with chains, tailored 3-piece...). Face/body/leaf crest/cigar constant.
- Taste bar for community pieces = the founder's own Flow prompts (grandpas in the $SMOKE LOUNGE, bong jet, golf-cart chase): absurd, funny, specific, rowdy, status-flexing, "hyper realism". Revised prompt table: `design/nft/lil-blunt-collection/04_PROMPTS_V2_FOUNDER_VOICE.md`.
- Before showing the founder ANY output, judge it against the plates yourself; he watches the Flow pane live.

# FOUNDER RULE 2026-10-19 (after 4-reference run produced off-model armour, fire buckle, burning hat)
- ONE reference image per generation: `lb_ref_03_pixel_gun.png` (Drive 1q4JtMNsJp-f-VVkpfzfNTLisal1YlVKM), the canonical Lil Blunt: leaf crest, googly eyes, toothy grin, cigar, brown hat with a green leaf badge, red bandana, tan fringed vest with gold stars, leaf belt buckle, spurs. "Normally it is better to use one reference image, especially this one. The generator gets confused." Style goes in words ("translate to a hyper-detailed glossy 3D illustration, NOT pixel art, medallion-grade, neon rim light"), not in extra plate references (extra plates also make the model draw its own ring).
- He is muscular and sexy women love him: women in the community pieces are into him (flirty, admiring, equals), never a joke at his expense.
- $SMOKE lives on BSC, ETH, SOLANA and BASE: use the chain colours as scene language (BSC gold-yellow, ETH violet/silver diamond, Solana purple-teal gradient, Base blue) in neon signs, drinks, lights, tracksuits; never real contract addresses.

# THE FOUNDER'S PROMPT UNIVERSE (read from his Flow workspace 2026-10-19: golf cart, bong jet, bong Rolls-Royce, speedboat, grandpas)
Read his prompts through Flow: open a tile IN A SECOND TAB, click the info (i) icon, `get_page_text` (the prompt is in the page text). Helper pattern in tab-2: scroll the one scroller, click the `img[alt*=Tile]` whose name matches, then click (233,57) and read.
What he makes: (1) the SmokeRing CAST in absurd status scenes: "the green leafy character racing a Ferrari in a Solana color-coded golf cart on the highway with Pepe in a weed-designed outfit and the Bonk character in a $SMOKE Solana hip-hop outfit and a gorilla with a joint in his mouth, Solana-branded bongs, the situation is intense, they all have red droopy eyes"; (2) "an amazing party on the speedboat with many beautiful women, everybody smoking a Solana-branded bong, the speedboat designed in a weed-eccentric theme, smoke completely full, hyper realism photorealistic" (4 reference images attached); (3) three grandpas in the $SMOKE LOUNGE (bling hip-hop grandpa, tailored three-piece Solana-coded top-hat gentleman, punk mohawk rapper) doing a hip-hop step for cheering women, bongs everywhere, red droopy eyes, hyper realism; (4) luxury vehicles reimagined as bongs: a Gulfstream-inspired private jet / a Rolls-Royce Phantom whose body is smoked glass, chrome and neon crystal, percolator under the wing root, bubbles, violet/teal/electric-green smoke from the engines, huge dimensional "$SMOKE" graffiti lettering, Solana-inspired teal-purple-green gradients as light only (never an altered Solana logo), "luxurious weed-meets-Web3 visual language"; (5) a woman smoking on a beach.
Voice: long, structured, specific, brand-coded, funny, status-flexing; explicit "no X" lists; "hyper realism, photorealistic" for people; red droopy eyes on EVERYONE who is high; beautiful women enjoying it; Solana-branded bongs; his models: Nano Banana 2.1 and Nano Banana Pro (use Pro for hero pieces).
=> Community pieces belong in THIS universe with Lil Blunt as the star (Ferrari race, speedboat, bong-jet cockpit, bong Rolls-Royce, lounge), not tasteful stock-photo scenes. Game pieces keep the medallion finish.

PROMPT RULES (founder 2026-10-24): refer to him only as "the character from the attached image" (never "green character", no face/costume description); never write "Square 1:1" (set in Flow settings); no "translate".

# SERIES 2 "DARING CRYPTO-MEME ADVENTURES" (founder 2026-10-24; ids lb_nft_17-32)
Prompt structure source: Google doc "An example of good prompts" (id 1MRhk9Yr5a53wH0pZJfQV-TqkdmTkaZ8KAhOv290UHnw): one dense paragraph, impossible environment built from strange materials (molten gold, obsidian, liquid mercury), concrete action beats, camera + lens (anamorphic, 35mm, low angle), then "Style: ..." tags (epic cinematic, volumetric lighting, chiaroscuro, 8K, motion blur). Subject = "the character from the attached image". Themes: red and green candles, bull/bear, HODL/diamond hands, rockets, whales, rug pulls, liquidations, cross-chain bridges (BSC/ETH/SOL/BASE).

REFERENCE SWITCH 2026-10-24: founder supplied a NEW single reference (lounge, green velvet robe, red droopy eyes, blonde woman in $SMOKE dress): local references/lb_ref_05_founder_lounge_robe.png; use it as the ONLY reference from now on (in Flow it is the tile named image.png).

# SERIES 3 "CANDID PHONE SNAPSHOT" PACK (founder 2026-10-24, doc "New Image Prompts" id 1MK-ZDsqW-f2aGUzmZn06Pc18w8gFcSQwdvRkjJwgcaE)
Prompt = one scene paragraph (specific real place, real tourists/people with named clothing, tiny distant action) then blocks: COMPOSITION (shot type, angle, placement, look-room, foreground occlusion, crop "handheld, slightly imperfect") / CAMERA PACK (body e.g. mid-range Android phone, lens/zoom, focus, sensor texture) / LIGHT (source, quality, colour temperature, shadows) / PHOTOGRAPHIC CHARACTER (fabric weave, grain, candid stance "catalog-unaware", hot highlights, phone sharpening halos, compression, slight softness, ordinary snapshot by a friend). Other formats in the doc: flat geometric editorial poster ("Six-color palette ... No text, logos"), visual worldbuilding set, iPhone 16 Pro reel look. Use the founder's reference via the "+" picker.

TIP (founder 2026-10-24): easiest way to keep the reference: right-click a generated image in Flow > "Reuse prompt" (brings the prompt AND its reference attachment), clear the prompt text, type the new one.
