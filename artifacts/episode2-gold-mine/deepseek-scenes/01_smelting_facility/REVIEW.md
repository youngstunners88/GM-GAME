<!-- dispatched: deepseek/deepseek-v4-flash-vision-exp
     prompt: prompts/deepseek-ep2-scene-01-smelting.md
     files inlined: 3
     images attached: 4 (artifacts/episode2-gold-mine/references/inferno_bull_smelting.jpeg, artifacts/episode2-gold-mine/references/inferno_bull_armed.jpeg, artifacts/episode2-gold-mine/references/inferno_bull_whiskey.jpeg, artifacts/founder-art/references/ep2_runner_ref_3_minecart_ride.jpg)
     tokens: 16038 in / 11622 out
     cost: $0.0112
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->

> **UNVALIDATED MODEL OUTPUT until checked.** Authored by DeepSeek via
> OpenRouter from the founder reference images and the shipped Godot
> implementation. Claude's verification notes are in `_VERIFICATION.md` in this
> folder — read that before treating any number here as fact.

1. **Bull hide colour.** The smelting reference (`inferno_bull_smelting.jpeg`) clearly shows green skin, while the armed/whiskey references and the character profile describe a "massive black bull." Which is canonical for the game? This affects the GLB pass fundamentally.

2. **Bandana in the smelting scene.** The red bandana appears only in `inferno_bull_armed.jpeg`. The exact staging reference (`inferno_bull_smelting.jpeg`) shows the Bull in overalls and aviators, no bandana. Does the bandana exist during the Chamber 0 meeting, or is it a combat-only accessory?

3. **Player lateral movement.** The implementation restricts the player to x = 0 (a linear rail). The room is 22 m wide, but the player can never leave the centre line. Is this intentional for the story chamber, or should the player be able to walk laterally to inspect the crucibles, ingot racks, etc.?

4. **Camera wide shot placement.** `CAM_WIDE` is at `(0, 4.2, -14)`, which is outside the room's floor footprint (z = -11.5). The camera would hang in the runner tunnel. Should the wide shot be pulled inside the room, or is there tunnel geometry there to support the camera position?

5. **Crucible pouring animation.** The reference shows molten gold pouring from crucibles, but the built scene has static cylinders with glow lights. Should the GLB pass include a looping pour animation, and if so, is it a visual-only effect or does it affect gameplay (e.g., the verb teach target)? The design doc mentions a "swinging crucible" as a possible target, but the implemented target is a mold rack. Which is canonical?
