# Reference art audit — v2

Founder said the doc has "more than 4 images." Re-checked twice, by two
independent export paths:
1. Doc → `.docx` export → unzipped `word/media/` → **4 distinct images**.
2. Doc → PDF export → `pdfimages -all` → **4 distinct images + 1 alpha-mask
   duplicate of image 3** (not a 5th real image).
3. Re-fetched the doc's `modifiedTime` after the founder's message — unchanged
   since first read. The doc genuinely contains 4 unique embedded images as of
   this session.

**If there are more references** (on your phone, a different doc, a folder),
send them directly and I'll fold them into the reference set — I don't want to
keep guessing at what I'm missing.

## The 4 confirmed references (now in `../assets/`)
- `ref-01-fomo-rocket.jpg` — core brand mark: muscular build, leaf-mohawk,
  cigar, flexing, riding the "Lil Blunt" rocket, FOMO wordmark, Solana-style
  interlocking-S mark glowing behind him.
- `ref-02-wild-west.png` — GoldMine-era cowboy variant (pixel art). Different
  wardrobe, same head/eye design.
- `ref-03-smoke-solana.png` — **the flagship $SMOKE look**: mirrored
  sunglasses, red bandana, black leather jacket w/ gold leaf embroidery, gold
  chains with a Solana "S" pendant, purple double-chamber bong, Solana
  logomark on jewelry/background. This is the on-model anchor for v2.
- `ref-04-gummies-pack.jpg` — product photography: real human hand holding
  packaging. Shows the brand composited into real-world/human scenes.

## Quality bar reference
Founder linked https://x.com/defisparco/status/2083931401599217875 — a
74.7s promo video for the ecosystem. Pulled via `api.fxtwitter.com` (X itself
returned HTTP 402 to a plain fetch) and sampled frames. Style: bold
anime/comic-book illustration, thick linework, cel-shading, saturated neon
color, dramatic comic-panel angles, an anime-style woman character seated with
Lil Blunt on a lowrider, clean graphic-design typography for badges (never
AI-rendered in-scene text). This became the v2 art direction target.
