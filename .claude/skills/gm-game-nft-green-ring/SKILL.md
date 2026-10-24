---
name: gm-game-nft-green-ring
description: "Stamp the founder's neon-green ring on NFT art: crop square art to a circle and draw the two-tube neon ring + glow on a transparent canvas, identical on every piece, matching his six existing medallions. TRIGGER on: green circle around the NFT, medallion, ring frame, circular NFT, make it match the existing collection, check that an NFT has the ring. Tool: tools/nft/ring_frame.py."
---

# Founder rule (2026-10-19): "the style we are going for must have the green circle around them."
Image models cannot draw a clean circle, so the ring is NEVER prompted. Flow makes a square, centred scene (ask for "subject centred inside a circular safe zone"); `tools/nft/ring_frame.py` then does the rest:
```
python3 tools/nft/ring_frame.py raw/<art>.jpg outputs/<layer>/lb_nft_NN_<layer>_<slug>_v1.png --preview-webp 1024
python3 tools/nft/ring_frame.py --check outputs/<layer>/<file>.png      # RING OK / NO RING, exit 1 on NO RING
```
- Output 1254x1254 RGBA (same as the founder's plates), transparent corners; the circle fills the canvas, ~7 px headroom for the outer halo.
- Profile measured from `design/nft/drive/*.png` along a horizontal line (d = px inward at 1254): outer glow, outer neon tube (white-hot core at d=8), dark-green gap (d 15-21), inner tube (white core at d=28), inner green glow fading into the art by d~57. Edit the `PROFILE` table to change it, never the geometry.
- The ring covers the outer ~4.5% of the radius: keep faces and key props inside ~85% of the radius.
- Needs numpy + ImageMagick `magick` (no PIL on this machine). Verified by rendering one of the founder's plates' art through it and comparing side by side: the profiles match (the founder's glow is a touch fatter).
- The $Smoke cowboy reference has a COPPER ring and the FOMO logo a TEAL ring; those are logos, not the collection style. The collection ring is the GREEN one of the six plates.
- Run `--check` on every final before delivery; a final without the ring does not ship.
