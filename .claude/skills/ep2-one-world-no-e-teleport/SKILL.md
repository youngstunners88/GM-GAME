---
name: ep2-one-world-no-e-teleport
description: Episode 2 is ONE continuous world. A path that leads somewhere must be walkable to the end - no "press E to enter the shoot stage", no chamber cut, no body teleport between sections. Use for the Day-88 ridge path to the shooting ledge, the road to the auction, lake-to-ridge handoff, and any new area link. TRIGGER on "one world", "integrated", "teleport", "press E to activate", "sections", "continue into the ledge", "on the way to the auction".
argument-hint: "audit | trace | fix"
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
---

# One world, not sections

Founder 2026-11-15: "This path to the shootout is supposed to just continue into the ledge up the shooting path!! It mustn't be something someone presses E to activate. I told you that this environment needs to be one world that is integrated!!! Not sections that are activated by teleporting there. The same goes for on the way to the auction."
The file header of `chamber/river_cover.gd` already forbids "invert after E". It still happened. Treat the header as a test to pass, not a comment.

## What counts as a violation
- Any interact prompt (E) whose effect moves the player's position more than a step, swaps the scene or chamber, or fades to hide a move.
- A fade, cut, flip or "invert" between the ridge path and the ledge, or between the road and the auction approach.
- An area that exists only after an arming marker fires, so walking there by hand shows nothing.
- Coordinates that were hand-offset per section instead of one shared origin (`LAKE_OFFSET` is the single source; `adopt_lake` is the design).

E is allowed for **doing** something (talk, trade, pick up). Never for **arriving** somewhere.

## Method
1. Find the seams: grep the two files for `global_position =`, `teleport`, `_enter_`, `start_rig`, marker arming, `ARRIVE_S`/`PORCH_S`, `fade`, `change_scene`. List every place the player's transform is assigned.
2. For each seam, decide: delete it, or make it a physical continuation (path geometry that connects, collision that lets the player walk through, trigger by **position** not by key).
3. Triggers that start the shoot beat arm on walking into the ledge zone (an Area3D / distance check), never on a key. The player may keep walking; the beat starts around them.
4. Mount and dismount on the road (`ARRIVE_S`, `PORCH_S`) are movement states, not cuts: the camera and player stay continuous, the horse is where the player left it.
5. Stream, do not section: if something must load, prewarm it ahead of the walker (`ep2-seamless-transition`); never load in front of the player.
6. Keep one coordinate frame. Chambers adopted into the world take the world offset; do not add a second offset.

## Proof (required, a repeat complaint)
- Headless test: walk a scripted player from the lake along the ridge to the ledge, then from the town along the road to the porch, sampling position each physics frame. Assert the largest frame-to-frame jump stays under walking speed x dt x 2, and no input action `interact` is sent.
- Prove the test fails with a teleport re-added.
- Real renderer capture: one continuous take, same camera, no black or wipe frame (`browser-verify-game`, `ep2-no-blackouts`).
- Report which seams you removed, by file and function.
