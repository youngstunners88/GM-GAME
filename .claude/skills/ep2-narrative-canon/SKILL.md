---
name: ep2-narrative-canon
description: The MEMORY LAYER that stops the game re-telling the player something a cutscene already showed. A JSON of facts the film establishes + the dialogue lines that would repeat them; the dialogue sequencer drops those lines once the film has played. TRIGGER on "don't let him repeat X, it's already in the video", "build a memory layer", any logical/narrative-continuity nuance, a new cutscene that establishes facts, or edits to src/data/ep2_narrative_canon.json, src/episode2/ep2_canon.gd, or FacilityShow.steps_for.
---
# Why (founder 2026-10-04)
"Don't let Inferno repeat that now's the best time to go bear hunt. It's already in the video. You should have had the intuition to figure that out. I want you to build a memory layer that helps with these kinds of logical nuances."
A cutscene and the in-game dialogue were written separately, so Inferno re-told, in the hideout, the exact beat the founder's film closes on (the bears took the Gold Mine; let's go hunting). That is a continuity bug, and the fix must be a reusable MEMORY, not a one-off line deletion.
# The memory
`src/data/ep2_narrative_canon.json` is the single source of truth for "the game already told the player this":
- `film_establishes`: the facts the cliff-to-hideout film shows/says (revive, the 1-BTC gear deal, bears-took-the-Gold-Mine + the hunt invite).
- `redundant_after_film`: line-id -> fact-id for every dialogue line that only restates one of those facts.
`src/episode2/ep2_canon.gd` (`Ep2Canon`, static) reads it and answers `is_redundant_after_film(line_id)`.
# How it is enforced
`FacilityShow.steps_for` filters out any `say` step whose id is redundant, but ONLY when `f.film_played()` is true (no film -> nothing is redundant, a straight beat-sheet run keeps every line). An emptied dialogue beat gets a tiny `wait` so it still advances. `SmeltingFacilityChamber._film_played` is set in `_on_video_film_finished`.
# Rules
- To stop a line repeating a cutscene: add it to `redundant_after_film`, do NOT delete the audio (it may still be used where the film did not play).
- Keep FORWARD-looking lines (the Fort Knox plan, the partnership, the player's buy-in). Only cut pure restatement of an established fact.
- Extend the JSON as the story grows; never hardcode line ids in GDScript.
# Gate
`tests/ep2_narrative_canon_test.tscn`: the bear line is flagged, dropped after the film, kept without a film; TERMS still advances; the Fort Knox partnership line survives.
