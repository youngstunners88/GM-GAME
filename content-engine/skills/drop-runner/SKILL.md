---
name: drop-runner
description: Scaffold a new drop from a format and drive it through the lifecycle. Use to start a new piece of content — creates the drop folder, its control file, and a calendar board row, then routes to astra-lead / seedance-pipeline / distribution-smoke.
---

# Drop Runner

Instantiates one drop. This is the repeatable action of the engine — the reason
the next drop is cheap.

## When
The calendar (`content-calendar`) has picked the next item + format, and you're
starting to actually make it.

## How
1. Pick the next number `NNN` (zero-padded, one above the highest existing drop
   in `calendar/drops/`).
2. Create `calendar/drops/NNN_slug/` with the lifecycle files (see the layout in
   `calendar/drops/README.md`):
   - `drop.md` — control file (below)
   - empty `brief.md`, `script_final.md`, `script_shots.md`
   - `prompts/`, `builds/`, `output/`, `posts/`
3. Copy the chosen format's beat structure + must/must-not into `drop.md` so the
   drop carries its recipe.
4. Add a row to the drop board in `calendar/calendar.md` at state `briefed`.
5. Route:
   - creative → `astra-lead` (fills brief, locks hook → `scripted`, `shots`)
   - render → `seedance-pipeline` (`rendering` → `assembled`)
   - publish → `distribution-smoke` (`scheduled` → `live` → `analyzed`)
6. On `analyzed`, move the folder to `archive/NNN_slug/` and mark `archived`.
7. Update STATUS.md at every state change.

## `drop.md` control file
```
# Drop NNN — <title>
Format: <format-name>
State: briefed
Target date:
Hook (locked): WAITING ON FOUNDER
Hero window:
Masters:
Links (posts):

## Recipe (from formats/<format>.md)
<beats + must/must-not pasted here>

## Log
- <date> scaffolded
```

## Rules
- Never hand-create a drop folder outside this skill — every drop gets the same
  files and a board row, or the calendar drifts.
- Respect all `CLAUDE.md` hard rules (no protocol invention, prompt fidelity,
  one Seedance 2.5 clip, no fake numbers).
- A drop with an unlocked hook stays `briefed`/`scripted`; do not render on an
  unconfirmed claim.
