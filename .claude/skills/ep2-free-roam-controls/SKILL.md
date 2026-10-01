---
name: ep2-free-roam-controls
description: The LOCKED Episode 2 on-foot control scheme (founder, repeated many times - "the keys are fucked", "how many times must I tell you to set the code") - Up/W forward, Down/S back, Left/A + Right/D strafe, Space jump (double), Shift run, mouse look with a click-to-lock pointer, E talk, LMB fire. TRIGGER on any complaint about keys/controls/"the code" in Episode 2, any new on-foot chamber or room, any change to ep2_session_root input routing, the facility camera, or the HUD hint.
---

# The rule
"The keys" / "the code" from the founder means KEYBOARD AND MOUSE CONTROLS, never an API key. Asking him which
key he means already cost a round trip (2026-10-01). The map is fixed; do not invent a new one:

| Input | Action (on foot: the Smelting Facility hideout and every future walkable room) |
|---|---|
| Up arrow / W | forward (where the camera looks) |
| Down arrow / S | backward |
| Left arrow / A, Right arrow / D | strafe left / right |
| Space | jump; Space again in the air = double jump |
| Shift | run |
| Mouse move | look (yaw + pitch); first left click locks the pointer, ESC releases it |
| E | talk / take; LMB fire |

Runner (cart) keeps its own verbs: Left/Right hop rails, Space jump/grab zipline, S duck, mouse aim, X/RMB axe.

# Why it broke before
- In the chamber, Left/Right walked along the room's length (`chamber_walk(+-1)`) and Up did nothing, so "up
  doesn't go forward" was literally true. W is bound to BOTH `jump` and `move_up` in project.godot (Episode 1), so a
  chamber must read Space by physical key and treat W as movement only.
- The session root forced `MOUSE_MODE_VISIBLE` every frame in CHAMBER mode, which would cancel any pointer lock.

# How it is wired (keep it this way)
- `ep2_session_root.gd`: `_poll_free_roam()` (in `_process`) sends `Vector2(get_axis(move_left, move_right),
  get_axis(move_down, move_up))` to `set_move_input()` ONLY WHEN IT CHANGES (so tests driving `walk()` are never
  overwritten). `_route_free_roam()` handles mouse motion -> `look()`, Space -> `jump()`, first LMB -> pointer lock +
  fire, and swallows W/S/arrows so the Miner-Shaft bindings (cover, walk) cannot fire on top.
  `_sync_mouse_mode()` leaves the pointer alone while the chamber `wants_mouse_capture()`.
- A walkable chamber implements `set_move_input(v, run)`, `look(relative)`, `jump()`, `has_player_control()`,
  `wants_mouse_capture()`. Movement is camera-relative: fwd = (sin yaw, 0, cos yaw), screen-right = (-fwd.z, 0, fwd.x).
- Scripted beats may own the camera (waking up, the two hand-overs) - `has_player_control()` is false, look and
  movement are ignored, and control returns the moment the scripted part ends. Never leave the cinematic camera on
  after a beat; that is "the mouse doesn't let me look around".
- Collision is cheap and explicit: room bounds, circle blockers for every big prop, the molten channel crossable only
  on the bridge.

# Gates
`tests/ep2_smelting_facility_test.tscn` section 12 proves every row of the table, including through the session root
with `Input.action_press("move_up")` and a real Space `InputEventKey`. Update the HUD hint in `ep2_entry.gd` with any
change. In the browser: click once in the hideout and check mouse look before calling it done.
