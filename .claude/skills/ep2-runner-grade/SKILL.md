---
name: ep2-runner-grade
description: The runner stretch into the cart-end and the second zipline must read warm mine colour - lantern light, brown timber, dark iron, wet rail - never grey rock or default materials. TRIGGER on "too grey", edits to the runner environment/ambient/fog, the cliff mouth, the zipline stretch, or tunnel/rock materials.
---
# Gate
`bash tools/ep2_shots/shoot.sh .farm/rn 0 785,1655,1735,1780` and read the PNGs: mean saturation/warmth (R > G > B), no unlit grey surfaces. Same palette family as the hideout so the cut into Bull's room is not grey to orange. Fix in `RunnerView._apply_art` / the rock and tunnel materials.
