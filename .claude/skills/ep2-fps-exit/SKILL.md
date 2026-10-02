---
name: ep2-fps-exit
description: Leaving the hideout flips Episode 2 into a first-person shooter/RPG with Inferno Bull as companion. TRIGGER on any change to Episode2Mode, _enter_fps, the FPS camera/viewmodel/crosshair, the HUD hint in ep2_entry.gd, or "it should be clear the game becomes a first-person shooter".
---
# One mode, no second input map
`Episode2Mode.Mode { RUNNER, HIDEOUT, FPS }` (src/episode2/episode2_mode.gd). Damage (`has_cart_damage`), input
(`mouse_looks`) and camera (`camera_style`) read it; `SmeltingFacility.get_episode_mode()` and
`Ep2SessionRoot.get_episode_mode()` report it. The key map is the locked one in `ep2-free-roam-controls`.
# On `_enter_fps`
Camera = Lil Blunt's eye (own body + helmet hidden), Winchester reparented to the camera as a viewmodel, crosshair
HUD, muzzle flash light, Bull walks to `companion_spot()` (front-right) and leaves WITH you. Never leave the rifle
in the third-person hands once FPS starts.
# Gate
Facility test; `show_shot` frames 12-14 (fps, terms, companion).
