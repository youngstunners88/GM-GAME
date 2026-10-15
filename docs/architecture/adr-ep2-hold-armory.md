# ADR: Episode 2 hold-to-select armory

## Status

Accepted — implements the founder's 2026-10-15 hold/icon/pause instruction.

## Date

2026-10-15

## Last Verified

2026-10-15 against pinned Godot 4.3.

## Decision Makers

Founder: interaction and western/reference art direction. Codex: implementation and measured verification.

## Summary

Replace the rejected text inventory with actual weapon renders and a western selector. Hold opens and pauses, preview stays local, release equips once and resumes.

## Context

The previous panel blocked player movement while bears, projectiles and resource clocks could advance. It also presented guns as text despite the founder's distinctive Winchester and gold/walnut Remington.

## Decision

`Ep2FpsHud` owns a SceneTree pause only while its selector is held; its input remains PROCESS_MODE_ALWAYS. `Ep2WeaponSelector` draws the actual weapon textures and previews selection, without resource transactions. The host's existing acquisition/tutorial guards decide whether opening/selection is allowed. Release emits the existing selection signal once. Escape/focus loss cancels; scene exit/rebind releases the owned pause. Existing pauses cannot be stolen or resumed. Canvas layer 40 sits above touch controls; portrait uses a scaled 390-unit canvas and MSDF type. The actual session inventory, gun clocks, corpse claims and checkpoints retain ownership.

## Consequences

World and gun timers stop together; mouse/controller/second-thumb input still works. Pause cleanup is mandatory on every exit path. The Remington has editable Blender source and a compact baked game tier; its static contact hand does not add articulated reload animation. The founder Winchester and concurrent world choreography are preserved.

## ADR Dependencies

Depends on `adr-mobile-touch-controls.md` for existing touch ownership; inventory/corpse transactions follow `design/ep2/armory/CONVENTION.md`. Enables two acquired weapons in existing Episode 2 FPS rooms. No new gameplay input injection path or production backdoor.

## Engine Compatibility

Godot 4.3, nonthreaded Compatibility web export. Consulted `docs/engine-reference/godot/current-best-practices.md` and `gdscript-gotchas.md`; no post-4.3 APIs. Verified real key/controller/raw-finger events, paused physics/reload clocks, resource handoffs/retries, portrait layout and native renders. Strict local browser boot/play passes; broader existing pause-button layout failures reproduce on the unchanged baseline and remain outside this correction.

## GDD Requirements Addressed

Founder instruction dated 2026-10-15: weapon icons, hold a command to choose, gameplay paused behind the selection, 1800s western presentation, and reference-based gold Remington graphics improved using Blender.
