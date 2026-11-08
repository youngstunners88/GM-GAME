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

## Follow-up 2026-11-08 (founder: "Yes spend the credits. They also need to be conversing ... day 88, certificates, auctions, Jack Hammer")

| # | Founder said | Built | Proof |
|---|---|---|---|
| 7 | Spend the credits (dig motion) | Meshy has no dig action; 6 credits on the closest two: "Heavy Hammer Swing" on the bearded digger's own rig -> a two-handed pick swing into his heap; "Pull Radish" on the bald worker's rig. Clips pulled out of the 12 MB GLBs into 22 KB / 60 KB Animation resources (`tools/meshy/extract_clip.gd`) | test: pick head travels 0.8 m, both hands on the handle |
| 8 | (seen in capture) "Pull Radish" as a forking motion dragged the fork flat along the ground | The forkman stays on his fork (ref 2) and now and then stands it up, kneels and pulls a rock out of the heap | test + capture |
| 9 | Converse about the protocol as miners: day 88, certificates, auctions, Jack Hammer | 5 talks, 21 lines, each in the speaker's own town voice (ElevenLabs, `assets/town-audio.json` `miners_*`): left lot = day 88 / 100-day miner / Fort Knox, the day-88 river Shipment; right lot = Mike Dean's four licenses + bond, the Gold Rush Auction (rigs, 100 days), Jack Hammer's bill and XAUt bounty, the Sheriff's job | test: whole talk in order, every line heard from the speaker, speaker turns to whom he answers, silent when Lil Blunt is out of earshot or a story scene is on |

Honest gaps: the dig is a pick swing (no shovel dig exists in Meshy's library). The lines play once in turn per lot,
no captions (voiced lines draw nothing, per `ep2-speech-no-subtitles`); if the streamed voice pack fails they gesture silently.
Bodies are the same people seen on Main Street, tinted dirtier (the prompt's "reuse townfolk bodies + tint/scale").
Not checked: phone, the live itch build.
