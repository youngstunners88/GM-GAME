@include prompts/_s8_facts.md
# Fable-5 — lead implementer. Terse, code-shaped. Each with GATE: line.
T1 Mira: (a) anchor her sprite so her FEET are on the same floor y as the player
(give the anchor math for a 602x903-ish sprite scaled to ~190px). (b) face the
player: flip the Sprite2D horizontally based on player.x vs clerk.x each frame.
(c) farewell: fire a line when the player exits her Area2D. (d) STEPPED dialogue:
a paced panel where each E press advances ONE line (greet->stake prompt->crush
prompt->confirm), never dumping all at once, with large readable controls.
T5 Gideon: a second NPC in Fort Knox (gideon_vale.png) with a stepped dialogue
panel like Mira; place him near the assay scale on the mezzanine floor.
T4 pools: make the 2888-day "primary" pool visually larger/distinct from 288-day.
Emblems: place diamond_sentinel.png as the Diamond Vault centerpiece and
fortknox_sentinel.png as the Fort Knox centerpiece (behind gameplay, non-colliding).
Keep it all headlessly testable (logic callable without the UI).
