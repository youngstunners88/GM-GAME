# Inferno Bull: whiskey removal, 2026-10-10

Founder requested removal of whiskey from Bull’s hand. The glass remains a room prop on the whiskey table from construction onwards. Handover cleanup no longer reparents it to LeftHand, and bone updates no longer move it. Both arms retain their imported resting pose at standing idle; either hand’s active IK disables that correction.

`comparison.jpg` pairs the supplied Bull reference with actual Godot 4.3 OpenGL Compatibility gameplay-camera captures before and after. The glass is absent from the hand in the candidate. The capture windows used different actual viewport sizes, so this board is a visual comparison rather than a pixel-difference measurement. This focused glass/idle change does not resolve Bull’s sculpt or full reference fidelity. The supplied original GLB was inspected in a separate headless Blender process; its mesh renders intact after removing its source skin binding for diagnosis. No new character asset is admitted by this change.

Regression checks cover seated table placement, post-handover cleanup, fixed table transform during movement/turning, film resume and existing rifle/lesson behavior. Headless dummy-renderer material warnings and shutdown resource leaks also occur on baseline; they are not visual verification. Native captures confirm no alpha surfaces remain among Bull’s attached props (3 surfaces, alpha=0).

Still open: full Bull sculpt fidelity, archer bear, premium gun displays/bullion, and flowing molten river with slight steam. No paid generation was used.

Validation: six native suites pass (hideout corrections, smelting facility, range lesson, script compile, save compatibility and backdrop/VFX). Godot 4.3 nonthreaded Web export completed without script errors: 197,313,584-byte PCK, below the 199,229,440-byte gate. Founder front-page lock passes.
