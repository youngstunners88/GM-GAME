---
name: ep2-design-verify
description: Turn a founder design request (a river, a train, a scene, a feel) into a checked requirement that is proven in the shipped build, not just in code or an asset. TRIGGER on "the river", "the train", "still water", "nothing changed", "I don't see it", "where is X", any founder request that asks for something to be visible in the game, and before reporting a design item as done or shipped.
---
# Why

The founder kept getting "shipped" while the thing they asked for was not visible. Code,
assets and docs were produced, but no step checked the requirement against the build the
founder plays. This skill closes that gap. Adapted from the "motion director" pipeline in the
founder's Google Doc (2026-10-17): lock facts, study the reference, measure, have a fresh
critic judge, and never let the builder grade its own work.

# Step 1: Requirement ledger (before any building)

Write one row per founder ask in `docs/founder-feedback/<date>_<topic>.md` (same format as
`2026-09-29_ep2-rails.md`): `# | Founder said | Where it must appear | Status | Proof`.
Quote the founder's words. Do not paraphrase them into a weaker requirement.

Status is one of:
- `IN CODE`: the scene or script exists in a tracked file.
- `WIRED`: the scene is instantiated on the path the player actually reaches (name the file and line).
- `SEEN`: a capture from the **shipped** build (or the same export) shows it, with its path.
- `SHIPPED`: master contains it, CI is green, and the itch build is updated (state the time).

Only `SEEN` or `SHIPPED` may be reported as done. Anything less is reported with its status.

# Step 2: Check the wiring path, not just the file

For each row, answer these in the ledger:
1. Which scene file instantiates it, and from which level or flow? (`grep -rn <name> src/`)
2. Does the player reach that level in the shipped flow? (check the level list and any gate)
3. Is it on a layer that can be seen? (ParallaxBackground layer, z-order, visibility, camera bounds, a tile or backdrop covering it)
4. Is the branch it lives on the one that ships? (`git log origin/master -- <file>`)

If any answer is no, the item is `IN CODE`, whatever the file says.

# Step 3: Measure the visible result

- Capture the requirement in the shipped export or a Godot run of the level, through a
  SubViewport if the window is tiled (Hyprland). Save the image next to the ledger row.
- Compare it to the founder's reference. Describe the difference in numbers or a named
  element (position, size, colour, whether it moves), not "looks better".
- A fresh critic (a subagent that did not build the item) looks only at the capture and the
  ledger row, and returns a ranked list ending in "ship" or "one more pass". The builder does
  not judge its own capture.

# Step 4: Report

Report the ledger status of every row. For any row not `SEEN`, say what is missing and what
will settle it. Do not write "shipped" until `SHIPPED` is verified (CI green on the master commit
and the itch update time). Log each step in the GM Game vault `Work Log/<date>.md`.

# Known state (2026-10-17, from the repo and the vault)

- **Train**: `src/level/distant_train.gd` + `.tscn`, instantiated by `level_03_gold_rush.gd`
  `_setup_distant_train()`. It is on master (`bcb8751c`). It is a parallax backdrop at
  layer -15 (0.18x), track at `track_y` 430. The refined train asset (15,300 tris, `design/train-revolver-pass/`)
  is a candidate and its release is blocked by the CI portal visibility gate
  (STATUS.md, 2026-10-15). Status: `WIRED` in code, `SEEN` not verified.
- **River**: the only river in the game is the Ep2 lava river in
  `src/episode2/chamber/smelting_facility.gd`. The Still Water lake and river card
  (`design/world/regions/11_still-water-lake.md`) is an OUTLINE proposal; the lake backdrop
  `distant_lake.gd` is decoration only. No playable river exists for Still Water. Status: `IN CODE` (backdrop) / not built (region).
- **Vault gap**: `GM Game/Work Log/2026-10-16.md` records horse, bull, bear, lake, and shipping, but has no river or train entry. The vault's Projects notes name `~/GM-GAME` and `~/Documents/GitHub/GM-GAME` branches, but the checkout is on `ship-bear-bull`, so those notes are stale.

# Gotchas

- Shipping gates (pack size, CI portal visibility) can block a visible change while the code is correct. Check the gate result before blaming the art.
- CRLF in `smelting_facility.gd`: keep newlines.
- Godot 4.7 import dirties `.import` and `.uid` files; revert them before committing.
