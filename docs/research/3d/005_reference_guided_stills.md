# 005 — Reference-guided character stills (VERIFIED)

Same prompt, three generators, the founder key art as reference where supported (2026-09-27):
- MuAPI Flux (text-only): generic mascot, loses the key-art identity.
- **Nano Banana Pro** (`google/gemini-3-pro-image` on OpenRouter, $0.14): chunky, chill, the leaf-badge
  cowboy hat, vest and buckle from the key art — chosen for Lil Blunt; the bear was near-identical to the key art.
- GPT image (`openai/gpt-5.4-image-2`, $0.24): most surface detail, lankier proportions — kept as alt.
Direct Gemini API (`nano-banana-pro-preview`) returned 429 quota; OpenRouter worked.
Meshy image-to-3D from the NBP stills produced clean A-pose models that rigged without a 422.
