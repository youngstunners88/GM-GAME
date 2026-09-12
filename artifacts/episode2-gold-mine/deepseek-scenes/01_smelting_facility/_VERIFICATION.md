# Verification — 01_smelting_facility scene kit

Author of the kit: **DeepSeek** (`deepseek/deepseek-v4-flash-vision-exp`) via
OpenRouter, from the four founder reference images plus the shipped
`src/episode2/chamber/smelting_facility.gd` and `ep2_palette.gd` inlined into
the brief (`prompts/deepseek-ep2-scene-01-smelting.md`).
Cost: **$0.0112** — 16,038 in / 11,622 out.

Verified by Claude on 2026-09-12, against the real code. Model output is advice
until checked; this file records what was actually checked and what was found.

## Claims CHECKED AND TRUE

| Claim | How it was checked |
|---|---|
| Room is 22 × 30 × 10 m, floor centred at z = 3.5 | `floor_mesh.size = Vector3(22.0, 0.4, 30.0)` at `Vector3(0, -0.2, 3.5)` |
| Playable z ∈ [-8, 15] | `ENTRY_POSITION.z = -8`, `EXIT_POSITION.z = 15`, `clampf` in `step()` |
| 8 timber posts, 4 cross-beams from z = -6, step 7.5 | loop `bz = -6.0; while bz < 17.0; bz += 7.5` → -6, 1.5, 9, 16.5 |
| Bull key light lands at world (-0.2, 2.4, 3.8) | `BULL_POSITION + Vector3(-1.8, 2.4, -2.2)` = (1.6-1.8, 2.4, 6-2.2) ✓ |
| Whiskey glass at (0.5, 0.55, 5.5) | `BULL_POSITION + Vector3(-1.1, 0.55, -0.5)` ✓ |
| Player is locked to x = 0 | only `_player_pos.z` is ever written |
| Resolve fires at z ≥ 14 | `_player_pos.z >= EXIT_POSITION.z - 1.0` ✓ |
| 3 crucibles, 2 ingot racks, 3 lanterns, 3 molds | counted in `_build_visuals()` ✓ |

DeepSeek read the implementation accurately. Nothing in the kit was invented
about the built scene.

## A REAL BUG IT FOUND — fixed 2026-09-12

> "`CAM_WIDE` is at `(0, 4.2, -14)`, which is outside the room's floor
> footprint (z = -11.5). The camera would hang in the runner tunnel."

**Confirmed by arithmetic**: the floor spans z = 3.5 ± 15 = **-11.5 to 18.5**, so
the establishing camera sat **2.5 m beyond the back edge of the floor** — and
outside the side walls, which share that span. That is why the arrival framing
showed the room floating in dark with nothing behind it.

`CAM_WIDE` moved to **z = -11.0**, inside the shell. This is a genuine catch: it
survived a real browser capture, because "the wide shot looks a bit empty" reads
as graybox rather than as a camera outside the room.

## OPEN QUESTIONS — one answered from the profile, three for the founder

**Q1, Bull hide colour — ANSWERED, no founder input needed.** DeepSeek flagged a
real contradiction: `inferno_bull_smelting.jpeg` shows a green, flaming-horned
bull while the profile says "massive black bull". The profile settles it
itself, in §3: black hide is the primary and secondary look; the green/demonic
variant is listed as an **"Optional cinematic variant: use sparingly for
high-drama moments."** So **black is canonical**; the smelting reference is that
cinematic variant and is authoritative for *staging*, not for hide colour. The
built placeholder already uses near-black `#1A1719`. No change.

**Q2 (bandana), Q3 (lateral movement), Q4 (camera) — Q4 is fixed above.**
Q2 and Q3 are genuine founder calls and are left open in `REVIEW.md`.

Q3 is the one worth a decision: the room is 22 m wide and the player can only
walk a centre line, so the crucibles and ingot racks can never be approached.
Cheap to add (`walk` already takes a direction; a second axis is a few lines),
but it changes the beat from "cinematic rail" to "small explorable room" and
that is a design choice, not a bug.

## What was NOT verified

The palette rows attributed to the references (hex values for Bull hide,
bandana, leather, Winchester wood/metal) were **not** independently sampled from
the images. They are plausible and consistent with the existing locked palette,
but they are DeepSeek's reading of the art, not measurements. Treat them as a
starting point for the fidelity pass, the same status Astra's extracted palette
had before it was tuned against real captures.
