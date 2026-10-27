# Kimi packet: the town has consequences - a civilian shot means jail with Bam Bankman Free and the guns taken; shot buildings and windows show damage and cost BTC

You are working in a Godot 4.3 GDScript project (Episode 2 of a first-person Western shooter, web export, **Compatibility
renderer**). Claude reviews every hunk, runs the gates and commits; write production code, not sketches.

## Founder's words (2026-10-27)
"I want to establish that if Lil Blunt shoots someone in the town he is taken to jail where the other prisoner is and loses his
rifle, bow, and Remington hand gun and is only given his pick axe afterwards. He has to stay there for [about two] minutes as he
has a conversation with the prisoner Bam Bankman Free who was involved in a scandal crypto that he is too ashamed to mention in
detail. The relationship with the townspeople and Minister Mike Dean and the Sheriff becomes cold if this happens. Also if Lil
Blunt shoots a building or window the damage should reflect and the sheriff should fine him in BTC."
Fix pack: "Civilian kill -> jail, Bam Bankman Free, weapon strip; building shot -> damage and BTC fine."

## What exists (verified by Claude - read the included files)
- **A shot in town counts only in the draw.** `GoldTownChamber._on_player_shot()` (`src/episode2/chamber/gold_town.gd`) returns
  unless `_beat == Beat.DRAW and _draw_state == "go"`; otherwise a shot only calls `_people.notify_danger()`. Nobody, no horse
  and no wall can be hit. The camera ray: `_camera.global_position`, `-_camera.global_transform.basis.z`.
  `aim_hits_opponent()` shows the ray-vs-body-axis test to reuse.
- **People**: `Ep2TownPeople` (`src/episode2/actors/ep2_town_people.gd`) - `people` (Person: `id`, `folk: Ep2TownFolk`, state,
  `notify_danger`, social memory); story cast in the chamber: `_sheriff`, `_minister` (Mike Dean), `_bartender`, `_bull`
  (Inferno Bull - NEVER killed, a story lock), `_opp` (the draw stranger), Rich and Utah (`_intro` / the Armory brains), the
  stable yard's Dude and assistant (`Ep2StableYard.actors`). `Ep2TownFolk.fall_dead()`.
- **Horses**: `Ep2TownLife` (`src/episode2/chamber/ep2_town_life.gd`) hitch-rail horses + the roaming one; the stable yard's horses.
- **Buildings**: `Ep2GoldTown` (`src/episode2/chamber/ep2_gold_town.gd`) - LAYOUT, FOOTPRINT, `building_xform`, `entry`,
  `local_to_world`; the street's walls for movement come from `Ep2TownNavigation` (2D segments). Windows are real openings in
  the Blender kit pieces (find how the built town names/places window panes or openings; read `ep2_gold_town.gd`).
- **The jail**: the town already has a jailhouse with a prisoner (Beat.JAIL / JAIL_LINES, the accomplice, speaker "prisoner",
  voice "Prison Sam"). The Sheriff leads Lil Blunt there in the story (`_bull_route`-style routes and `_start_show` scenes).
- **Weapons**: `Ep2ArmoryState` (`src/episode2/chamber/ep2_armory_state.gd`): `IDS` (Winchester, Remington, Bow), `owned`,
  `equipped`, `select()`, `snapshot()/restore()`. There is NO pickaxe in the first-person armory today (the runner's hero has
  one; the hideout has a pickaxe prop). Rich's shop (`SHOP`) does NOT sell replacement firearms.
- **Purse**: `GameManager.purse_balance/purse_spend` (src/autoload/game_manager.gd, 4-space indent).
- **Captions + voice**: `_caption_steps([[WHO, text], ...])` + `_start_show(steps, blocks_control)` show a caption and play the
  recording when `Ep2TownVoiceBank` has that speaker+text (`_town_speaker(who)` maps names). New lines go in
  `assets/town-audio.json` `lines` (`{"id", "speaker", "text"}`; read the existing entries); Claude generates the audio after
  your change. Add a speaker `bam` (Claude assigns a premade ElevenLabs voice; leave `voices.bam` with `"voice_id": ""` and a
  `"note"`). Never edit `src/episode2/audio/town_voice_bank.gd` (generated).
- **Blood**: `res://src/episode2/fx/ep2_blood_fx.gd` (`Ep2BloodFx`, written in a parallel packet) will provide static
  `spurt(parent, at, dir, size)`, `stain(body, at, normal, size)`, `pool(parent, at_ground, radius, grow_s)`. It may not exist in
  your checkout: load it dynamically (`ResourceLoader.exists(path)` then `load(path)` and call the static functions on the
  script) so your code compiles and runs without it.

## Build
1. **Shots hit the town** (outside the draw, and in the draw for anyone who is not the opponent): one ray per round from the
   camera, nearest first: townspeople (a capsule per person, feet to head), story cast, horses (a capsule along the body),
   then building faces and windows. A new module `src/episode2/chamber/ep2_town_law.gd` (`class_name Ep2TownLaw`) holds the
   ray tests, the damage marks and the ledger of offences; `gold_town.gd` builds it and calls it from `_on_player_shot()` with
   small hunks. The Gatling (mounted) counts too: its rounds use `Ep2GatlingPost._trace`; a Gatling round that leaves the
   yard toward the street is an offence like any other.
2. **A person is shot**:
   - a townsperson (roster) or the draw stranger outside the draw: blood (spurt + stain, pool when down), `fall_dead()`; the
     town panics (`notify_danger`).
   - story cast (Sheriff, Mike Dean, Rich, Utah, the bartender, Dude, the assistant, Logan if present): WOUNDED, never killed -
     blood spurt, a flinch/stagger, they stay alive (the story needs them). Inferno Bull: never hit (the shot misses him).
   - then the **arrest**: player control off; the Sheriff comes to Lil Blunt (walks; no teleport, no blackout), a caption
     line (e.g. SHERIFF: "Drop it, Blunt. You just shot a man in my town."), and walks him to the jail cell (the player is
     auto-walked behind/with him the way the story already moves people); the guns are taken there.
3. **The cell, about two minutes** (`CELL_SECONDS := 120.0`): Lil Blunt is locked in with **Bam Bankman Free** (a new folk in
   the cell: model path `res://src/episode2/extras/jail/bam_bankman_free.glb` - it does not exist yet; `Ep2TownFolk.setup()`
   falls back to a plain figure; Claude supplies the model later). He is a disgraced crypto man, too ashamed to say what he
   did: write 8-12 short spoken lines between BAM and LIL BLUNT spread over the two minutes - wry, a little sad, never
   detailed about any real scandal or real person, nothing defamatory; he dodges ("Let's just say the books didn't balance."),
   Lil Blunt stays chill and kind. The cell door stays shut until the time is up; the player can look around but not leave.
   The existing prisoner and JAIL_LINES are unchanged.
4. **Released with the pickaxe only**: the Sheriff opens the cell: SHERIFF line ("Your irons stay with me while you're in my
   town. Take your pick and walk soft."). `Ep2ArmoryState`: add a confiscation (`confiscate_firearms()`, `firearms_confiscated
   -> bool`, `return_firearms()`; saved in `snapshot()/restore()`); while confiscated the Winchester, Remington and Bow cannot be
   selected (the Tabs cards show them as "HELD BY THE SHERIFF"), and Lil Blunt holds a **pickaxe** in first person: add
   `PICK := "pickaxe"` as an equipped mode that is not one of the three slots, shown by the viewmodel
   (`src/episode2/chamber/ep2_viewmodel.gd`): load `res://src/episode2/assets/weapons/pickaxe_fp.glb` when it exists (Claude
   will supply a CAD model there later), else a clean procedural pickaxe (a hickory handle ~0.9 m and a curved iron pick
   head - not two primitives); a swing on click with `res://src/assets/sounds/ep2_pickaxe_swing.mp3`, no ammunition, no
   damage to people. `return_firearms()` is called when Lil Blunt leaves town (Claude wires the story moment;
   expose it and a signal `firearms_returned`). Nothing is lost forever and the run can never soft-lock.
5. **Cold relationships**: `GameManager.town_standing` ("warm"/"cold", saved with the purse) + a signal. Cold: townspeople keep
   2.5 m away, skip their friendly greetings, and some say one of 4-6 new cold lines (written into `assets/town-audio.json`
   under their own speakers); Mike Dean and the Sheriff each get 2 cold lines used at their next interaction. Never change
   their existing story lines.
6. **Buildings and windows**:
   - a round that hits a facade leaves a bullet hole (a small dark irregular mark on the face, 3-5 mm off it, procedural
     texture cached once - no Decals, no new image files) + a few wood splinters (CPUParticles3D) + `wood_splinter.ogg`;
   - a round through a window shatters it: `window_shatter.ogg`, glass shards particles, and the pane shows broken (hide or swap
     the pane mesh if it is separate; else a cracked overlay quad);
   - **the fine**: after the shooting stops (3 s without an offending shot) the Sheriff fines him in BTC: 1 BTC per window, plus
     1 BTC per 4 facade holes (rounded up), as a caption line + toast ("SHERIFF'S FINE: 2 BTC"), `GameManager.purse_spend("btc",
     n)`; if the purse is short, take what there is and record the rest in `GameManager.town_debt_btc` (saved); never negative.
   - all audio files are streamed (`res://src/episode2/extras/audio/town/`): load only when `ResourceLoader.exists`.
7. **Gate** `tests/ep2_town_law_test.gd` + `.tscn` (root Node, script attached; print `EP2_TOWN_LAW: ALL PASS` or
   `EP2_TOWN_LAW: N FAILURE(S)`; `get_tree().quit(failures)`). Build the real town chamber as `tests/ep2_gold_town_test.gd` does.
   Aim with the real camera (`look()`), fire with `shoot()` + the chamber's shot path, step the chamber:
   - a shot on a townsperson kills them (fall_dead), starts the arrest, the Sheriff walks to Lil Blunt (distance shrinks every
     second), Lil Blunt ends in the cell; the cell holds for 120 s (he cannot leave before) with Bam's conversation (all lines
     captioned, in order, spread over the time); then the guns are confiscated, the pickaxe is equipped, the Tabs shows the
     three as held, and `town_standing == "cold"`;
   - a shot on the Sheriff or Mike Dean wounds (alive) and still arrests; a shot at Inferno Bull never hits him;
   - a shot on a horse bleeds (when Ep2BloodFx exists) and costs a fine, no arrest;
   - a facade hit leaves a mark; a window shatters; after 3 s quiet the fine is debited exactly once (purse before/after);
     a short purse records the debt; the purse never goes negative;
   - `return_firearms()` gives all three back; save/load round-trips confiscation, standing and debt;
   - a draw still plays exactly as before (the stranger is the only target that counts in the draw; win and loss unchanged).
8. Keep `tests/ep2_gold_town_test.gd`, `tests/ep2_personal_armory_test.gd`, `tests/ep2_purse_test.gd`,
   `tests/ep2_town_people_test.gd`, `tests/ep2_armory_guns_test.gd` and `tests/ep2_tabs_ledger_test.gd` passing unchanged.

## Rules
GDScript for Godot 4.3: typed variables, `##` doc comments on public functions, no new autoloads, no project.godot edits,
nothing that needs Forward+ (no Decals). No blackout or hard cut for the arrest. Restrained blood. No real person named or
depicted; Bam Bankman Free is fictional and stays vague about his past. Never change existing dialogue text, line ids or voice
ids. Keep every existing public signature; keep each file's indentation (game_manager.gd uses 4 spaces, the Episode 2 files
tabs). Change existing files only with exact SEARCH/REPLACE edits; new files as whole files. Then a short NOTES line: what
changed per file and what the gate covers.

@include src/episode2/chamber/gold_town.gd
@include src/episode2/chamber/interlude_base.gd
@include src/episode2/chamber/ep2_armory_state.gd
@include src/episode2/chamber/ep2_weapon_selector.gd
@include src/episode2/chamber/ep2_viewmodel.gd
@include src/episode2/chamber/ep2_gold_town.gd
@include src/episode2/chamber/ep2_town_life.gd
@include src/episode2/actors/ep2_town_folk.gd
@include src/episode2/actors/ep2_town_people.gd
@include src/episode2/actors/ep2_gatling_post.gd
@include src/autoload/game_manager.gd
@include assets/town-audio.json
@include tests/ep2_gold_town_test.gd
