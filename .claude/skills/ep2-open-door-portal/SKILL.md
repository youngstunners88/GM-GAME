---
name: ep2-open-door-portal
description: Show the NEXT room through an open doorway and walk straight through with no cut you can see (founder 2026-10-24 - the hideout's elevator door, "i dont want a transition at that point ... we should be able to see the elevator from within the smelting facility"). Portal render of the prebuilt chamber, fixed offset, cut on crossing the doorway plane, companion mirrored, position handoff. TRIGGER on "door to the elevator", "see the lift/next room through the door", "walk straight through", "no transition at the door", or adding the same to another chamber pair.
---

# Open doorway into the next chamber

## How it works
- The next chamber is already built behind the current one (ep2-no-blackouts: `Ep2SessionRoot._on_prebuild_requested`, own-world SubViewport).
- Current chamber answers `portal_view_wanted()` -> {"xf": its camera transform + OFFSET, "fov", "bull"/"bull_facing" once the companion has crossed} or {} (not built / facing away -> the second world is not drawn).
- `Ep2SessionRoot._drive_portal()` (each `_process`): raises the prebuild viewport to screen size, `next.portal_begin()` (hides what stands between its camera and the room - lift: black tunnel plug + back wall), `current.portal_attach(viewport_texture)`, then `next.portal_view(want)` every frame. `portal_detach()` + UPDATE_DISABLED when not wanted.
- Doorway: a quad in the arch with `src/episode2/art/ep2_portal.gdshader` (unshaded, fog-free, samples the viewport at SCREEN_UV). Anything behind the quad is hidden by its depth - that is how the companion "goes through".
- Cut: resolve the instant the eye crosses the doorway plane (`_player_pos.z >= PORTAL_Z`), handoff `lift_player`/`lift_bull`(+facing) = position + OFFSET; next chamber's setup places them there (not its START_POS) and lowers its floor clamp to the mouth (`MOUTH_MIN_Z`); it closes the mouth again once he is 1.6 m in.
- **The door opens the frame Inferno starts "made it"** (`SmeltingFacilityChamber._exit_open()`: across the lava + that line begun), not when his show ends
  (that was a 4.7 s invisible wall at the open door - founder 2026-10-25). `get_handoff().voice_left` = the line still playing; the lift's first line waits for it.
- **The room in the doorway holds no Lil Blunt**: a prebuilt chamber hides its third-person body when its build/warm-up ends (`_hide_unentered_body`) and in
  `portal_begin()` (founder 2026-10-25 screenshot: him standing in the cage while he held the rifle in the hideout). Proof: `door_portal_shot` before/after.
- Hideout <-> lift numbers: hideout `PORTAL_Z` 16.4, lift `PORTAL_Z` = CAVE_Z0 + 0.4 = -13.6, `LIFT_OFFSET` (0,0,-30). Both eyes 1.55 m.

## Rules / traps
- Leaves must open INTO the room: swung into the passage they sit behind the portal quad and vanish.
- The cut must happen at the plane, not before (the arch around the camera vanishes) and not after (the hideout passage behind the quad shows).
- Compatibility applies the CURRENT room's grading to unshaded materials too: compare `cut_a`/`cut_b` luminance in `tools/ep2_shots/door_portal_shot.tscn` and correct with the shader's `gain`.
- Gate: `tests/ep2_interlude_test.tscn` "THE OPEN DOOR" block (portal live, mouth open, companion mirrored, no early cut, handoff position, same instance).
