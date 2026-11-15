---
name: ep2-hands-free-reveal
description: Staged, physically believable reveal of a held object - Rich puts the gold in his hand down, hands are free, he turns to the case, lifts the rifle, turns back and shows it. No body flip, no pop, no teleport of props. Use for the Sharps case hand-off and any "he pulls X out" beat. TRIGGER on "body just inverting into position", "put down his gold", "hands are free", "turn around and reveal the weapon", "pulls the gun out of the case".
argument-hint: "audit | storyboard | fix"
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
---

# Hands-free reveal

Founder 2026-11-15: "When he grabs the gun out of the case let him put down his gold that is in his hand so that his hands are free and then let him turn around and reveal the weapon as opposed to his body just inverting into position."

Files: `src/episode2/actors/ep2_armory_intro.gd` (stage enum, `SHARPS_REACH`, `SHARPS_TALK`, `IN_HAND_AT`, `FACE_CASE_OUT`, case-lid clock), `ep2_armory_pose.gd` (pose/IK), `ep2_armory_brain.gd`. Related: `ep2-prop-contact-animation`, `ep2-handoff-props`.

## Beat order (storyboard first, one frame per line)
1. Rich holds the gold. Player is at the counter, speech running (it never pauses: `ep2-npc-conversation-flow`).
2. **Set down the gold**: arm lowers to the counter, the gold leaves the hand **at contact**, resting on the counter, hand opens. The prop is parented to the counter at the moment of release, with no pop.
3. **Hands free**: both hands empty and visible for at least a beat.
4. **Turn to the case**: yaw rotation about the vertical axis through the hips, a short walk-turn or pivot with feet planted/stepping, not a pose snap. Shoulders lead, head leads the shoulders.
5. Lid opens (lid clock), hands reach, grip on the rifle at its real grip points, **lift** out of the case.
6. **Turn back** with the rifle held, then present it (`IN_HAND_AT`): this is the reveal.
7. The gold stays on the counter, or is picked back up only if the story needs it.

## What "body inverting" means and how to find it
A single frame where root yaw jumps ~180 degrees, or a skeleton goes through a pose that flips a bone (twist/roll flip, quaternion double-cover, IK pole swap). Cause: assigning `rotation = ` or `look_at` once instead of tweening a yaw; a pose set that is swapped between two states in one frame (`FACE_CASE_OUT` timing).
Fix by: interpolating yaw with `lerp_angle`/shortest-arc over 0.5-0.9 s; blending pose layers (don't swap); fixing IK pole targets; checking the rest pose rotation order (`ep2-rest-aware-retargeting`).

## Proof
- Frame strip (every 3rd frame across the whole hand-off) in the real renderer, plus root yaw per frame: max yaw delta per frame under ~12 degrees, no sign flip in any bone.
- Assert: gold prop has a valid parent and non-teleporting transform across release; hands empty at the case-open frame.
- Confirm the check fails on the old code. Report timing (seconds) of each beat.
- Do not change Rich's look, the case art or the rifle model (`feedback-no-unrequested-visual-changes`).
