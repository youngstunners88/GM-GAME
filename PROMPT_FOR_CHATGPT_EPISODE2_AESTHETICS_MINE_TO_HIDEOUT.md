# TASK FOR CHATGPT — Episode 2 aesthetics pass: the mine, all the way to Inferno Bull's hideout

You are cleaning up after Claude Code in a Godot 4.3 project. The founder (Rich) wants the **look and design** of Episode 2 improved from the first frame of the mine runner to the last frame in Inferno Bull's hideout. You have the repository; every path below is relative to the repo root. **Read first, change second.**

Repo: `youngstunners88/GM-GAME`. Branch to work on: `claude/sleepy-sagan-edqti4` (it equals master at `96701a5`; only `master` deploys to itch). Live game: https://youngstunners88.itch.io/smokerealm

---

## 0. Read these first (in this order, before touching anything)

1. `CLAUDE.md` (project rules; the ALWAYS-SHIP, FRONT-PAGE-LOCK, BLOTCH, SECURITY rules apply to you too)
2. `STATUS.md` (top ~60 lines: what changed most recently and what is known-unverified)
3. `design/ep2/INFERNO_BULL_HIDEOUT_design.md` and the target picture `design/ep2/inferno_bull_hideout_target.jpg` (the founder's target for the hideout)
4. `design/episode2_runner_wirespec_design.md`, `design/world/WORLD_BIBLE.md` (look, factions, tone)
5. `.claude/skills/ep2-layered-production/SKILL.md` (five layers, each gated), `.claude/skills/ep2-reference-match-loop/SKILL.md` (prove a visual change against the founder reference), `.claude/skills/ep2-hideout-set-dressing/SKILL.md`, `.claude/skills/ep2-hideout-player-view/SKILL.md`, `.claude/skills/ep2-runner-grade/SKILL.md`, `.claude/skills/ep2-runner-camera-light/SKILL.md`, `.claude/skills/ep2-bull-rest-pose/SKILL.md`, `.claude/skills/ep2-bull-debug-mesh/SKILL.md`, `.claude/skills/ep2-handoff-props/SKILL.md`, `.claude/skills/ep2-hud-title-card/SKILL.md`

## 1. The journey you are improving (in play order) and the files that make it

### A. The mine runner (the cart ride, "The Descent", about 1800 m)
| What | File |
|---|---|
| Everything you SEE in the runner: tunnel, track, lanterns, rock/gold-vein detail, carts, hazards, pits, bears, ziplines, coins, hearts, fog, lights, camera | `src/episode2/runner/runner_view.gd` (3271 lines). Builders to start from: `_apply_art` (803), `_build_track` (836), `_build_tunnel` (917), `_build_tunnel_shell` (1024), `_build_lanterns` (1048), `_build_dressing` (1076), `_build_carts` (1098), `_build_rider` (1144), `_build_archers` (1366), `_build_hazards` (1459), `_build_pit` (1501), `_build_shovel_bears` (1571), `_build_ziplines` (1661), `_build_gold` (1703), `_build_mine_detail` (1845), `_build_rail_events` (1958), `_build_portal` (2087), `_build_cliff_mouth` (2113), `_build_camera` (2244), `_build_fx` (2252) |
| Colours / materials / palette tokens | `src/episode2/art/ep2_palette.gd`, `src/episode2/art/crystal_glow.gdshader`, `src/episode2/art/molten_flow.gdshader`, `src/episode2/art/shell_crystals.gd` |
| Textures | `src/episode2/assets/textures/` (`tex_rock_wall.jpg`, `tex_gold_vein.jpg`, `tex_timber.jpg`, `tex_gravel.jpg`, `tex_cowhide.png`, `tex_pinup_poster.jpg`, `tex_btc_coin.png`) |
| Models | `src/episode2/assets/*.glb`: `mine_tunnel_shell.glb`, `minecart.glb`, `leaf_cart*.glb`, `rail_segment.glb`, `wood_beam.glb`, `lantern.glb`, `rock_chunk.glb`, `boulder_rock.glb`, `gold_nugget.glb`, `gold_pile.glb`, `ingot_rack.glb`, `mine_bear_archer.glb`, `bear_rigged.glb`, `lil_blunt_hero.glb` (founder's Lil Blunt: DO NOT redesign him) |
| Track layout, hazards, hearts, zip segments | `src/episode2/runner/tracks/episode2_tracks.gd` (`LEG_DESCENT`) |
| Sim (read only for aesthetics; do not change rules) | `src/episode2/runner/runner_graybox.gd`, `runner_graybox.tscn` |
| Character poses / camera feel | `src/episode2/runner/runner_motion.gd`, `runner_arm_rest.gd`, `runner_aim_modifier.gd` |
| Runner sound | `src/episode2/runner/runner_audio.gd`, `runner_voice.gd`, `voice_bank.gd` |

### B. The cliff mouth and the transition film
| What | File |
|---|---|
| The visible track end, warning boards, glowing gorge (still in the runner) | `runner_view.gd` `_build_cliff_mouth` |
| The Seedance 2 film that plays at the handoff (30 s, **NO MUSIC**, dialogue + effects baked in) | `src/assets/video/cutscenes/ep2_cliff_to_hideout.ogv` |
| Film player (letterbox, skip by holding Space, ends on black) | `src/episode2/cinematic/ep2_video_film.gd` |
| Film pipeline (keyframes -> Seedance clips -> compose) | `tools/ep2_film/muapi_film.py`, `film.json`, `timeline.json`, `compose_film.py`, `tools/ep2_film/voice/`; skill `.claude/skills/ep2-seedance-film/SKILL.md` |
| Fallback in-engine film (only if the .ogv is missing) | `src/episode2/cinematic/cliff_jump_cinematic.gd`, `film_post.gdshader` |
| Style reference for any new film shot: the three boss-defeat cuts | `src/assets/video/cutscenes/stage1_boss_defeat.ogv`, `stage2_boss_defeat.ogv`, `stage3_boss_defeat.ogv` |

### C. Inferno Bull's hideout (Smelting Facility), where target practice starts
| What | File |
|---|---|
| The whole room, its lighting, Bull, props, beats | `src/episode2/chamber/smelting_facility.gd` (1830 lines), `smelting_facility.tscn` |
| Prop placement / dressing (rack, gatling, bears, trophies, poster, whiskey, gold) | `src/episode2/chamber/hideout_dressing.gd` |
| Bull's choreography | `src/episode2/chamber/facility_show.gd`, `src/episode2/actors/ep2_actor.gd`, `src/episode2/actors/ep2_arm_ik.gd` |
| Hideout props | `src/episode2/assets/hideout/` (`gatling.glb`, `cauldron.glb`, `ore_cart.glb`, `bear_head.glb`, `bear_standing.glb`, `sources.json`) and in `src/episode2/assets/`: `ingot_rack.glb`, `crucible.glb`, `whiskey_glass.glb`, `btc_coin.glb`, `winchester_1886.glb`, `miner_helmet.glb`, `inferno_bull_rigged.glb`, `inferno_bull_sit_clips.glb`, `inferno_bull_walking_clip.glb`, `inferno_bull_running_clip.glb` |
| HUD, title card ("THE SMELTING FACILITY"), K key list | `src/episode2/ep2_entry.gd`, `ep2_entry.tscn` |
| First-person mode (what the player sees after the film) | `smelting_facility.gd` `_enter_fps`, skill `.claude/skills/ep2-fps-exit/SKILL.md` |

## 2. How to SEE it (do this, then do it again after every change)

The founder rejects work that was only described. Capture the real thing:
- Runner: `bash tools/ep2_shots/shoot.sh <outdir> <leg> <metres,comma> [aimx,aimy]` (uses the cached engine `.godot-cache/Godot_v4.3-stable_linux.x86_64`, xvfb, `gl_compatibility`). Rig: `tools/ep2_shots/shot_runner.gd`.
- Hideout, from Lil Blunt's own eyes via the real follow camera: `tools/ep2_shots/player_view_shot.tscn`; cinematic boards: `facility_shot.tscn`, `show_shot.tscn`.
- The film in the real engine: `tools/ep2_shots/video_film_shot.tscn` (frame 0, mid-film, after skip).
- Put each capture beside `design/ep2/inferno_bull_hideout_target.jpg` (hideout) or the boss-cut frames (film) on one board and grade it (skill `ep2-reference-match-loop`). Optional second opinion on a REAL screenshot: skill `art-direction-fidelity-check`.
- Playwright against the real web export: skills `ep2-browser-playtest`, `browser-verify-game`.

## 3. What "better aesthetics" means here (the brief)

Style: **painterly cinematic 3D adventure, Western gold-rush mine**, warm saturated amber / copper / molten-gold light, dark rock with glowing gold veins, rim light on characters. It must read as the same world as the three boss-defeat cuts and the hideout target image.
Concrete goals, in priority order:
1. **Continuity of look from the first runner frame to the hideout**: one colour grade and light logic through the mine, the cliff mouth, the film and the hideout (the film ends in the woods at golden hour, then the hideout is firelit; make the hand-offs feel designed, not stitched).
2. **The mine**: richer rock and timber (silhouettes, supports, ore veins that glow, hanging chains, lantern pools of light with falloff, dust and ember particles, depth fog), readable lane/hazard colour language, hearts/coins/hazards visible from 90 m, no flat grey boxes, no z-fighting, no seams.
3. **The cliff mouth**: the track visibly runs out; a dramatic frame, readable warning boards, the light at the end of the tunnel.
4. **The hideout**: match `inferno_bull_hideout_target.jpg`: molten channel behind Bull, crucible pours with steam and embers, ingot racks and gold, gun wall with the Winchester, Gatling, bear trophies, the pin-up poster, cowhide rug, whiskey table, chains and beams. Capture it from the player's eyes; a bare corner is a defect.
5. HUD and text: clean (see skill `ep2-hud-title-card`).

## 4. HARD RULES (breaking any of these gets the work rejected)

- **Do not redesign Lil Blunt.** The founder's model `src/episode2/assets/lil_blunt_hero.glb` stays as is. The rifle is the founder's Meshy Winchester (`winchester_1886.glb`), the helmet, whiskey glass and Bitcoin are his Meshy props too (skill `ep2-founder-asset-swap`); Inferno Bull is the founder's Tripo-rigged minotaur (`inferno_bull_rigged.glb`). Do not replace founder models with generated stand-ins.
- **Do NOT touch the founder-locked title screen**: `src/ui/main_menu.gd`, `main_menu.tscn`, `src/assets/backgrounds/bg_menu_gm_keyart.jpg`, `src/assets/music/menu_mist_theme.mp3`, `src/assets/shaders/title_smoke_flow.gdshader` (CI fails the build if they change; `scripts/front-page-lock.sh check`).
- **No music in the film.** The founder scores it later. Never add a music cue.
- **Pack size gate: `index.pck` must stay under 190 MB; it is currently about 187-189 MB.** Every texture, GLB and video counts. Use compressed JPG/WebP-sized textures, decimate meshes, and DELETE what you replace. CI fails the build over 190 MB and a failed master build never deploys. Check sizes before you add anything (`du -sh`, `find src -size +1M`).
- **Web export must stay non-threaded** (`variant/thread_support=false`).
- **Web renderer is Compatibility (GL)**: no features that only exist in Forward+ (SDFGI, volumetric fog, SSR). Metallic surfaces with no reflection probe render BLACK; use albedo + emission.
- **Do not change gameplay rules, controls or tests' meaning**: the zipline never costs health, the three hearts, Up/Space jump in the cart, the on-foot scheme (Up/W forward in the hideout) are all locked. Allowed: visuals, lighting, materials, props, particles, camera framing that does not change the sim.
- **Gameplay values must stay in data, code must be commented, Godot 4.3 syntax only** (GDScript typed; `:=` from a Variant is a hard error in 4.3; no tabs/spaces mixing).
- **Enemies are never weed-themed**; weed content stays positive and chill (CLAUDE.md global rules). Never hardcode wallet or contract addresses.
- **BLOTCH rule**: if you touch a full-screen overlay, plate or VFX, read the BLOTCH RULE in `CLAUDE.md` first and run `bash scripts/blotch-hunt.sh`. Measure before changing; never soften something the founder asked to remove.
- **Security gate**: run `bash scripts/security-sentinel.sh` after `git add` (it scans `git ls-files`). No secrets in files; keys come from the environment.

## 5. Verification gates (all must pass before you say anything is done)

```bash
G=.godot-cache/Godot_v4.3-stable_linux.x86_64
$G --headless --import                      # new/changed assets must import cleanly
for t in tests/ep2_*_test.tscn; do $G --headless $t 2>&1 | grep -E "ALL PASS|FAIL|SCRIPT ERROR"; done
# (ep2_stress_soak_test is a very long soak; it was not completed in the last session, not a regression)
bash scripts/security-sentinel.sh
python3 scripts/check-green-vfx.py          # also scans .tscn (see BLOTCH rule)
```
Key tests for your area: `tests/ep2_art_direction_test.gd`, `ep2_camera_framing_test.gd`, `ep2_glb_pipeline_test.gd`, `ep2_runner_graybox_test.gd`, `ep2_runner_carts_test.gd`, `ep2_reachability_test.gd`, `ep2_smelting_facility_test.gd`, `ep2_session_root_test.gd`, `ep2_runner_audio_test.gd`. Add a test for any new rule you introduce.

## 6. Shipping (mandatory, from CLAUDE.md)

1. Update `STATUS.md` (top of file; plain words for the founder: what changed, what was and was NOT checked).
2. Commit, push to `claude/sleepy-sagan-edqti4`.
3. `bash scripts/ship-to-master.sh` (merges master in, runs gates, fast-forwards master; never force-push).
4. Prove master's CI run `Export Godot Game to Web` succeeded: the step "Verify export output" prints `index.pck = N MB` (gate 190) and "Deploy to itch.io via butler" must succeed. Only then say "live". Before that say "pushed / deploying".
5. The founder accepts on a hard refresh of https://youngstunners88.itch.io/smokerealm only. Say honestly what you did not check in a browser.

## 7. Deliverable format

A short report to the founder: (a) before/after captures on one board per area (mine runner, cliff mouth, hideout from the player's eyes), (b) the list of files changed and files deleted, (c) the pck size from CI, (d) what is still not at target. Keep replies short; the founder is on a token budget.
