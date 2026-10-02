---
name: ep2-founder-asset-swap
description: The founder's own 3D models (Drive doc "3D Assets": Meshy share links, Rodin, Tripo) replace every forged/primitive stand-in. TRIGGER on the founder sending meshy.ai/s/ links, a hyper3d or tripo3d URL, "swap in my assets", or any prop that looks forged/primitive.
---
# Pipeline
1. `python3 tools/meshy/pull_share.py <code> --remesh 0 --tex 1024 --aux 256 --name f_<slot>` (free download; never remesh with a 0 balance).
2. `python3 tools/ep2_forge/install_founder_props.py` bakes each to the code's conventions (rifle 1.2 m muzzle +Z; helmet base y=0 lamp +Z; whiskey unit height; bitcoin unit diameter) and shrinks textures for the pck budget (pck gate 190 MiB; ~180 MiB used).
3. `godot --headless --import`, then the facility test and `tools/ep2_shots/show_shot.tscn`.
# Slots
Rifle wUN2J2, Helmet tVC8jD, Whiskey LKhotS, Bitcoin oLKt9Y (done). Lil Blunt (Rodin 4d80d61e...) needs a hyper3d login; Inferno Bull (Tripo 17c80337...) needs a working Tripo key (`tripo doctor` reported "Invalid API key" - re-run `tripo login`). Never paste a key anywhere.
