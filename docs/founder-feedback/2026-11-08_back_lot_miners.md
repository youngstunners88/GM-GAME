# Back-of-town local miners — founder prompt 2026-11-08

Source: Drive `PROMPT_BACK_MINERS_2026-11-08.md` (id `1KgInpJ6nC0tgL7xfSjtSnz3eP8AT0zQj`) + four reference images in chat
(long-beard digger, muscular man with pitchfork, two miners talking, old man seated on a crate beside a man with pick and shovel).

| # | Founder said | Built | Proof |
|---|---|---|---|
| 1 | Ambient local gold miners at the back of town, not Main Street | `Ep2BackLotMiners` (`src/episode2/actors/ep2_back_lot_miners.gd`), built as its own town prebuild step | `tests/ep2_back_lot_miners_test` (behind fronts, not in a building, >4 m from any door, clear of horses) |
| 2 | Long beards on some, strong/muscular on some, dirty work clothes | Reused Meshy townsfolk bodies (oldtimer + grandfather bearded, bald worker broadened x1.12), every material multiplied toward dust | capture `tools/ep2_shots/back_lot_miners_shot.tscn` |
| 3 | Pitchfork / shovel / pick as props only | Primitive tools; held tools laid from the right hand bone to their rest point each frame | test: hand on the handle line (<6 mm), tool end on the ground |
| 4 | Clusters of 2–4, small radius | Left lot: digger + pitchfork man (2). Right lot: two talking gold by an ore pile + old man on a crate with pick and shovel (3) | test |
| 5 | Don't block doors / duel lane / Main Street; no new buildings, no quests, no new GLBs | Nothing on Main Street; zero new GLBs; no story NPC touched | test + `from_street_gap` capture |
| 6 | (common sense) | Solid to Lil Blunt (town collision props), seated man on a crate sized from his own seated hips, gunfire -> stop, turn, Alert, then back to work | test |

Not done / honest gaps: the Meshy clip library has **no dig clip**, so the digger stands at his heap with the shovel blade in it
(a breather) rather than digging. A dig loop needs a new clip (Meshy animate, 3 credits) — not spent without the founder's yes.
Bodies are the same people seen on Main Street, tinted dirtier (the prompt's "reuse townfolk bodies + tint/scale").
Not checked: phone, the live itch build.
