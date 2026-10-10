---
name: ep2-personal-armory
description: Make Lil Blunt's Winchester 1886 and golden Remington 1875 ownership readable, add fast first-person weapon switching, conserve limited rounds across rooms and retries, and prepare bear-arrow storage without granting a bow. Use for personal inventory, ammo HUD, quick slots, weapon acquisition or loot integration.
---

# Personal armory

Read design/ep2/LIVING_WOODS_CONTRACT.md, then only relevant current acquisition/save, Ep2Winchester, Ep2Viewmodel, Ep2FpsHud and session-root code. Read .claude/skills/ep2-fps-shooter-feel/SKILL.md for rifle handling and .claude/skills/ep2-encounter-checkpoints/SKILL.md for resource restoration.

## Implementation

- Register stable IDs winchester_1886 and remington_1875_gold, full player-facing names, earned ownership and a selected weapon. Inspect golden-revolver acquisition in src/player/combat_handler.gd and its existing Stage 3 gate; preserve Episode 1 behavior.
- A shared session inventory owns weapon/ammo/arrow counts; camera attachment cannot assign fresh MAG/RESERVE_START. Carry actual loaded and reserve values from the hideout across chambers.
- Show equipped firearm name/icon, loaded/reserve and two named quick slots. Default proposed controls are 1, 2, Q previous, Tab inventory; inspect collisions and expose rebinding plus touch/controller equivalents. Use brief pickup feedback so both weapons are known possessions.
- An expandable panel supports future items; two slots stay fast without a mandatory wheel. Empty firearms remain selectable. Reload/dry fire/switch feedback is explicit.
- Preserve cycle/reload clocks through swaps. Declare what interrupts reload, when the ammo transaction commits and when firing is allowed. Every real shot consumes once; an aborted switch/reload cannot grant rounds or fire two guns.
- Provide a real first-person Remington viewmodel, hand poses, ADS/recoil/report/reload/HUD integration using founder assets. Reuse equivalent concurrent work if it exists. Do not call the old runner revolver a finished FPS implementation.
- Ammo pools rifle_round, revolver_round and bear_arrow remain distinct. Future arrow storage does not unlock a bow or spend firearm rounds. Do not guess caliber compatibility.
- Respect tutorial/acquisition locks and access controls, the Winchester model/logo contract, and the existing 3-heart health cap. New armory UI does not change the founder-locked title page.

## Required evidence for implementation

Proposed future gate ep2_personal_armory_test: old-save ownership migration; selection of both acquired guns; unowned slot rejection; loaded/reserve conservation through transitions; no refill on repeated attach; empty feedback; mid-reload/same-frame switching; independent ammo pools; arrow storage without a bow; checkpoint round trip. Name the final test files when created.

Capture both named slots, each equipped firearm in the player's hands, selection on keyboard/touch/controller where available, low/empty ammunition, interrupted reload and panel arrow count. Measure switching latency and errors rather than assert a universal UX winner. Consult both decision models through ep2-living-woods with those facts. Existing range/lesson, save compatibility, runner revolver and Stage 3 golden-revolver tests remain applicable.
