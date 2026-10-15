# Founder delivery 2026-10-10 (b): "Ep2 Design Elements" + "setup" docs

Docs: `Ep2 Design Elements` (1pE7u0NY...), `setup` (1JEYh3Un...). Images saved to
`artifacts/episode2-gold-mine/references/founder_2026-10-10b/`.

| item (Drive id) | what it is | what was done |
|---|---|---|
| `Recreate_rifle_scene_logo_2K` (1xZHe...) -> `gun_rifle_scene_logo.jpg` | target: the rifle in Lil Blunt's green-armed hands, GM logo (chain + green GM) on the receiver | the logo target for the fix below |
| `rifle 3d.glb` (1X09DLG2...) | **Lil Blunt's rifle** (founder: "you can see that his arm is green"), Tripo, glove + green arm + leaf bracer baked in; its GM logo was a smeared gold blob in a recessed dish | logo fixed texture-only + dish flattened (no face deleted, logo 0.95x the old size), built to the viewmodel frame, now `winchester_1886_founder.glb` - the first-person rifle everywhere. Report: `lil-blunt-rifle-logo-2026-10-10/` |
| `Improving_bull_character_and_rifle_2K` (1btoU...) -> `exiting_chamber_bull_rifle.jpg` | target: Inferno by the furnace with his rifle, first person | reference for the hideout exit (next increment) |
| `Recreating_mine_scene_with_bull_2K` (1aSiv...) -> `exiting_outside_mine_bull.jpg` | target: looking out of a timbered adit onto a rope-railed plank bridge into the pines, Inferno waiting | built: the woods now start inside a timbered adit with knee braces, plank bridge with posts, rails and rope (mine-lift kit); start-shot closeness 0.78 |
| 3 bear stills (1DOsd, 1hk1N, 1twJa) -> `bear_realism_1.jpg`, `bear_scene_2.jpg`, `bear_scene_3.jpg` | target: the Tripo miner bear / archer in golden-hour pines | woods light grade: golden hour chosen by Jev 0.54 / microsoft-decision-1 0.58 (closeness to the bear stills 0.67-0.78 vs 0.42-0.69 daylight) |
| Tripo studio link c323cd98 | the bear model page | Studio links are not API tasks (Tripo API "task not found"; Monid has no Tripo endpoint; a scripted browser fetch was refused) - the Drive "Bear warrior" export is used (shipped earlier today) |
| `Inferno Bull.glb` (1KkTyJGw...) | Tripo Inferno Bull, mixamo rig | measured: the SAME body as the shipped Bull (retarget core fit 0.1 cm) plus the rifle fused to his left hand; its rig export is broken like the bear's (identity joint nodes). Not swapped - nothing to gain; the shipped Bull already carries a separate rifle prop |
| `Inferno Bull with rifle.jpg` (125Ypi...) | character sheet: sunglasses, cigar, bandana, bandoliers, lamp helmet, rifle | reference for the Bull pass (next increment) |

## Setup doc
Tool list -> `gm-game-tool-roster` (installed here: `muapi` via pip, `monid` + key from env, `elevenlabs`; `tripo`, `firecrawl` were
present). Coach's MD method (Drive folder 1sPirhj..., "The Lesson 3.1") -> `assets/CONTEXT.md`, `src/CONTEXT.md`, `docs/CONTEXT.md`
(design/ had one) + skill `context-md-upkeep`.
