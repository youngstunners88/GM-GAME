---
name: ep2-interlude-chain
description: Build, extend or debug the Episode 2 story chain AFTER the hideout - the lava river, the mine lift (two floors, hidden lever, "Inferno Bull 2"), the bear woods (stealth, camouflaged flame quad, ride to "Deep Mining 3", spyglass on the bear camp) - and the session-root chaining (next_chamber / end_session) that links them. TRIGGER when the founder talks about the lava river hurting / Inferno hopping, the elevator shaft, the lever, the woods, the quad bike, spying on bears, the next scene after the hideout, adding another story room, or music that should start in a specific chamber.
---

# Episode 2 interlude chain (founder 2026-10-09)

The founder is changing the episode: after the hideout the scene is NOT the cart runner. The chain is
**hideout -> lava river -> mine lift -> bear woods -> (next: Lil Blunt shoots the bears from the quad while Inferno rides)**.
"We're laying the ground work" - this is the transition layer plus the external environment. The slice ends with
TO BE CONTINUED after the spy beat.

## Where things live

| Thing | File |
|---|---|
| Shared base: session-root contract, free roam, **first-person eye camera**, `look_toward` for scripted beats, director shots (rare), Lil Blunt's body (director shots only), Inferno, the step() show runner | `src/episode2/chamber/interlude_base.gd` (`Ep2Interlude`) |
| **The Winchester in his hands** (viewmodel: hands, ADS, recoil, lever, reload, muzzle flash, report) | `src/episode2/chamber/ep2_viewmodel.gd` (`Ep2Viewmodel`) - the hideout's VM_* numbers lifted into a component |
| Chamber 1: the lift (ARRIVE, BOARD, LEVER, RISE, SURFACE) | `src/episode2/chamber/mine_lift.gd` (+ `.tscn`) |
| Chamber 2: the woods (SNEAK, REVEAL, MOUNT, RIDE, SPY) | `src/episode2/chamber/woods_quad.gd` (+ `.tscn`) |
| Lava river (EXIT beat of the hideout) | `smelting_facility.gd` (`_lava_*`, `LAVA_HALF`, `burned` signal), script in `facility_show.gd` (`B.EXIT`) |
| Bull's scripted jump | `Ep2Actor.hop_to()` + show step `hop`; waiting step `until` (nudge line every N s) |
| Chaining | `Ep2SessionRoot._on_chamber_cleared`: result key `next_chamber` loads that chamber in the same segment, `end_session` ends the slice (`session_complete`) |
| Lines + sfx | `assets/audio-manifest.json` (ids `vo_bull_lava*`, `vo_bull_lift*`, `vo_bull_plan*`, `vo_bull_woods*`, `vo_bull_quad*`, `vo_bull_spy*`, `vo_lb_plan_reply/quad_ok/spy_reply`; `ep2_lava_burn/lift_*/quad_*/leaves_pull`); generate with `scripts/generate_audio.py` (only missing ones) |
| Songs | `src/assets/music/ep2_inferno_bull2_lift.ogg` (lift), `ep2_deep_mining3_quad.ogg` (quad) - encoded Vorbis q0 to stay inside the 190 MiB pck |
| Gate | `tests/ep2_interlude_test.tscn`, `tests/ep2_smelting_facility_test.tscn` (lava), render rig `tools/ep2_shots/interlude_shot.tscn` |

## Founder rules that are locked

1. **The lava really hurts.** From the EXIT beat the channel is a hazard, not a wall: standing in it (feet < `LAVA_SAFE_Y`) burns a
   heart, kicks him back to the bank he came from, flashes the HUD and yelps. Inferno walks to the bank, warns, **hops across**,
   then tells Lil Blunt to hop over (and nags every 11 s). There is no bridge. Hearts only show once the lava is armed. No game over.
   The room's exit does not resolve until Inferno's whole EXIT show has finished. Inferno's hop lane is x = -2.4 (his body is a
   moving 1.5 m blocker: never let it sit on the landing).
2. **The lever is inconspicuous.** Inferno is a master of disguise: the lift lever is a stub of the wall's OWN rock material bedded in
   a boulder at knee height - no metal, no colour, no emission (the test checks the material identity). Inferno says "don't bother
   looking for it" and pulls it on camera (IK reach + lever swing + `ep2_lift_start`).
3. **Songs:** "Inferno Bull 2" starts when the shaft chamber is entered (`music_path`); "Deep Mining 3" starts ONLY when they mount the
   quad (`_mount()`), never earlier. The hideout keeps its own stage theme.
4. **The quad is hidden.** It sits under a hand-built pile of ~150 leaf clumps and branches inside a thicket of the same bushes;
   from the trail it is the biggest bush. Inferno throws the leaves off (`_reveal_quad`) - it is a flame-designer quad (red paint,
   layered flame tongues, chrome, headlight).
5. **Stealth = walking.** Default speed is a sneak; RUNNING inside `HEARING` (19 m) of a patrol bear is heard (a noise hit, Inferno
   shushes, the bear turns). Nothing fails; Inferno waits if Lil Blunt falls more than 6.5 m behind.
6. **Next scene is not the runner** - never route the hideout result back into a runner leg (`next_chamber` wins over `_advance_segment`).
7. **IT IS A FIRST-PERSON SHOOTER - THE RIFLE IS IN HIS HANDS** (founder 2026-10-09, furious: "Why would Lil Blunt not have the fucking rifle
   that Inferno Bull gave him"). Every story room is first person by default (`fps_mode = true`): the camera is his eye (1.55 m, FOV 78,
   ADS 58), the Winchester + Lil Blunt's leafy hands are a child of the CAMERA (`Ep2Viewmodel`), the HUD shows the ammo tube and
   crosshair, LMB fires / RMB aims / R reloads. **Never sling the rifle on his back again, never move the story to a third-person
   follow camera.** The body is only seen in a director shot (`set_camera_shot`), holding the rifle at the hip (`HELD_RIFLE_*`).
   - **Scripted beats stay in his eyes**: the hidden-lever reveal and the leaves coming off the quad use `look_toward(point)` (the view
     turns to the action while the controls are held) - not a cinema cut that makes the rifle vanish. Release with `release_look()`.
   - **A shot is a fact of the world.** In the woods (SNEAK) and at the spy point a shot is noise: bears within `SHOT_HEARING` (46 m)
     turn, a noise hit counts, Inferno hisses (`vo_bull_woods_shot` / `vo_bull_spy_shot`). On the quad ride the engine covers it.
   - **At the spy point RMB is the SPYGLASS** (rifle drops to low ready, view narrows to 16 deg), not the iron sights.
   - **Daylight chambers set `viewmodel_exposure` (~0.82)**: under a bright sky the rifle's metal read cream; the lamp-lit mine is 1.0.
   - The quad ride is a passenger view: the view yaw rides the quad's heading; he sits on the back seat (`SEAT_SIDE`), a black blink
     (`Ep2FpsHud.fade_to`) covers the climb on. The CLAIM RUN (shooting bears from the back seat) is NOT built: founder's foundation
     doc says the prep pass is closed until he opens it (`ep2-fort-knox-arc`).
   - Health: nothing in the story rooms hurts; `get_health()` is the hideout's 3-heart cap. Never add a second health system.

## Adding another chamber to the chain

1. `class_name FooChamber extends Ep2Interlude`; override `_build_room`, `_on_setup`, `_tick`, `_on_beat_entered`, `_show_finished`,
   `_collide`, `_chamber_id`, `_beat_label`; set `title_card`, `music_path`, `viewmodel_exposure` in `_init`. Optional hooks:
   `_on_player_shot()` (what a shot means here), `_viewmodel_lowered()` (rifle at low ready). Objectives go in `_hud.objective`.
2. Script dialogue as FacilityShow steps (`say`, `walk`, `face`, `reach`, `call`, `wait`, `hop`, `until`); never use real time.
3. Register the scene in `Ep2SessionRoot.CHAMBER_SCENES`; resolve with `_resolve({"next_chamber": "foo"})` or `{"end_session": true}`.
4. Add it to `tests/ep2_interlude_test.gd` and capture it with `tools/ep2_shots/interlude_shot.gd`; LOOK at the pngs.
5. Generate the lines with ElevenLabs (Inferno `uWE48TmsTuIjyh2ifoNL` speed 1.2; Lil Blunt `HMGfKwZCRujgXyRDUW0b`) - never print keys.

## Traps already paid for

- A GDScript lambda captures plain bools/floats **by value**: mutate a Dictionary/Array in `_until` predicates.
- `Parameter "m" is null ... mesh_get_surface_count` spam in headless runs is the dummy renderer, harmless.
- A cage / shaft camera sits OUTSIDE the cage: a solid roof or thick white bars hide the player. Use thin dark bars, dark steel (the
  palette `iron` is a white mirror with no reflections).
- Trees in front of the spy view blocked the bears: keep a sight lane (`|x| < 13`, z 140-175) and raise the spy eye above the ferns.
- **`generate_audio.py --force <id>` also generates every OTHER missing clip** (the six `film_*` ids have no mp3 on purpose - the founder's
  film carries them). After a `--force` run `git status` and delete any stray `film_*.mp3`.
- `Ep2ViewHands.attach` measures the forge rifle INCLUDING the muzzle-flash quad: build the flash BEFORE attaching the hands (as the
  hideout does) or the founder rifle sits at a different height.
- A new `class_name` is invisible to a headless run until `godot --headless --path . --import` has rewritten the class cache.
- Pack budget: songs and VO add MBs; the stage theme was re-encoded 128k -> 80k mp3 to pay for them. Check `index.pck` < 190 MiB.
