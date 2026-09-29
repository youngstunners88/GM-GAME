# 008 — What a GLB really costs in the web pack (VERIFIED 2026-09-29)
Godot imports GLB textures lossless with mipmaps (`.godot/imported/*.ctex`). Measured per model:
leaf_cart 0.7 MB GLB -> 9.0 MB textures (3 maps @1024); lil_blunt_hero 1.9 -> 7.2; mine_bear_archer 2.1 -> 6.1;
mine_tunnel_shell 1.3 -> 5.3; golden_revolver 0.7 -> 3.8. Adding the hero + bear took the pck 186.1 -> 198.4 MB
(gate 199.2). Levers, in order: retire replaced assets; shrink normal/metal-rough maps (`--aux-max 256`);
base colour to 1024 only for heroes. Check with `scripts/ep2-local-export.sh` after EVERY model.
