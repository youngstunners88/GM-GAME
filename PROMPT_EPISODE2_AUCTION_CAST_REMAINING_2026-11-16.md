# Episode 2 — Auction: cast, band, hall light, score, crowd — 2026-11-16

**Give this file to Claude Code.** Most of the auction is already shipped; do not replay the old Meshy-only brief.
This pass covers five things, in this order of importance:

1. **Characters** — the seven people (2 checkers, 5 band) as real game models, Tripo first, Meshy as fallback.
2. **Band** — five musicians in the hall, playing their instruments. Today they are not placed at all.
3. **Hall light** — the hall is still too dim after the CAD pass. A lighting/material pass, not a rebuild.
4. **Score** — one 1880s-style instrumental background track from Muapi (Suno), playing in the hall.
5. **Crowd** — room ambience and reactions at the auction's moments, including Hammer running.

Branch: `claude/ep2-auction-cast-20261116` · Worktree: `/home/kofibeatz/.cache/gm-auction-cast-20261116`
Base: `origin/master` `cdc8a7a9` (live build `2026-11-16-71f10a8`) · Latest work on branch: `3899f577`

---

## 0. State, verified 2026-11-16

| Item | Fact | Where |
|---|---|---|
| Characters | **No new character GLB exists.** None of the seven is generated. | `src/episode2/extras/people/` has no `auction_checker_*` or `auction_band_*` |
| Band | `band_ready()` is false (all five band GLBs missing), so `_build_band()` returns before placing anyone. | `ep2_auction_house.gd:457-465` |
| Band layout | Positions, instrument pieces and hand bones are already written. | `ep2_auction_house.gd:69-76`, `BAND_FACE` at `:76` |
| Instruments | Kit props exist: `Auc_Fiddle`, `Auc_FiddleBow`, `Auc_Banjo`, `Auc_Bass`, `Auc_Harmonica`. Nothing attaches them yet. | `ep2_auction_house.gd:475-476`, `tools/ep2_blender/build_town_interior_kit.py --prefix Auc_` |
| Hall crowd audio wired | `crowd_cheer.ogg` (4 s), `town_draw_bell.ogg`, `town_saloon.ogg` (14 s night bed), `horse_whinny.ogg`. | `ep2_auction_house.gd:278-280`, `:448` |
| Crowd audio on disk, **not** in the hall | `town_people_loop.ogg` (16 s loop), `miners_auction_1..4.ogg` (~4 s murmurs), `saloon_laughter.ogg`, `man_laugh_a/b.ogg`, `woman_laugh.ogg`, `auction_renegade_1..6.ogg` (lines, not crowd). | `src/episode2/extras/audio/town/` (used by town/back-lot code, not the auction hall) |
| Hammer runs | `_flee()` plays **no sound**. The crowd reacts only through the generic cheer/clap picker. | `ep2_auction_house.gd:567` (`_flee`), `:654-679` (reaction picker) |
| Score | No authored auction score. The road song `ep2_gm_og_smoke.ogg` ends at the porch; the hall has only the night bed. | `auction_road.gd:33` (`ROAD_SONG`), `:614-619` |
| Hall light | Still dim after the CAD pass. The captured lift is modest. | Lights at `ep2_auction_house.gd:248`, `:261-263`; lanterns `:318-328` |
| CAD + Blender interior | Done in `3899f577`. Do not redo. | `tools/ep2_cad/auction_house_cad.py`, `tools/ep2_blender/build_town_interior_kit.py` |
| Renegade arms, tied horse coats, 61-check auction gate | Done. Do not redo. | `ep2_auction_house.gd:345`, `:408`; `tests/ep2_lake_auction_road_test.gd` |
| Pack | `ep2_extras.pck` = **199,161,984 B** against gate **199,229,440 B** → **67 KB free**. | `scripts/check-ep2-extras-pack.sh`, `src/episode2/ep2_extras.gd:67-73` |

**Pack room is the hard blocker for every item above.** Characters, band, score and crowd audio all go into the
streamed extras pack. Section 4 has the budget and the decision.

### Keys and balances (checked 2026-11-16, not re-spent)

| Provider | Key location (never print it) | Balance | Use |
|---|---|---|---|
| Tripo web app | Open and signed in in **Brave** | Separate pool, more than the API | **First choice for the seven meshes** |
| Tripo API | `~/GM-GAME/.env` → `TRIPO_API_KEY` | **505 credits** | Rig + retarget; mesh fallback |
| Meshy | `~/Documents/GitHub/GM-GAME/.env` → `MESHY_API_KEY` | **86 credits** | Meshy-only clips; fallback only |
| Muapi | `~/Documents/GitHub/GM-GAME/.env` → `MUAPI_API_KEY` | Last read **$22.20**; re-read with `python3 tools/ep2_film/muapi_film.py balance` | Score and crowd sounds |

The old "Meshy key is a placeholder / 401" line was false. A placeholder `MESHY_API_KEY` in `~/.bashrc` shadowed the real
key. `~/.bashrc` now loads the real keys; verify in a fresh shell. Do not print, copy, commit or paste any key.

---

## 1. Already done — do not redo

- **Renegade's arms** — `ep2_auction_house.gd:408` installs `Ep2ArmoryPose.install(renegade)` on the auction instance only.
- **Tied auction horses** recoloured white + black via `Ep2HorseCoat.apply()` at `ep2_auction_house.gd:345`.
- **Claim clerk and hall doorman wiring** with fallbacks: `auction_road.gd:46` (`CLERK_MODEL`), `:265` (`clerk_model_path()`),
  `ep2_auction_house.gd:451-453` (`doorman_model()`).
- **Checker and band constants** in `src/episode2/ep2_extras.gd:67-73`.
- **CAD + Blender interior pass** (`3899f577`): dado panelling, cap rails, skirting, sills and jambs, floor seams, truss
  brackets, stage trim, seven wall lanterns, porch licence-check desk. No layout or collision change.
- **Auction gate** is 61 checks; CI pin at `.github/workflows/export-game.yml`.

**Out of scope, known:** the player's road horse never applies the coat chosen at Dude's stable (`auction_road.gd` has no
`Ep2HorseCoat` call). Separate item; leave it.

If a change would touch any of the above, prove why with a failing test or a capture first.

---

## 2. Cast and clip map

Sheets live in `design/ep2/auction/cast-references-20261116/` (one sheet → one person). Heights are body height in metres, hat included.

| id | Game file (`src/episode2/extras/people/`) | Sheet | Height | Clips required |
|---|---|---|---|---|
| `checker_a` | `auction_checker_a.glb` | `checker_a.jpg` | 1.82 | Idle, Talk, Greet |
| `checker_b` | `auction_checker_b.glb` | `checker_b.jpg` | 1.78 | Idle, Talk, Greet |
| `band_lead` | `auction_band_lead.glb` | `band_lead.jpg` | 1.66 | Idle, Play (sings) |
| `band_fiddle` | `auction_band_fiddle.glb` | `band_fiddle.jpg` | 1.76 | Idle, Play |
| `band_guitar` | `auction_band_guitar.glb` | `band_guitar.jpg` | 1.80 | Idle, Play (plays the banjo, per `ep2_extras.gd:71`) |
| `band_bass` | `auction_band_bass.glb` | `band_bass.jpg` | 1.84 | Idle, Play |
| `band_harmonica` | `auction_band_harmonica.glb` | `band_harmonica.jpg` | 1.77 | Idle, Play |

Tripo **v1.0** has the preset library with `greet` and `sing`; v3.0 does not. Use v1.0 for this cast:

| Game slot | Tripo preset | Notes |
|---|---|---|
| `Idle` | `preset:biped:idle` | All seven |
| `Greet` | `preset:biped:greet_01` | Checkers |
| `Talk` | `preset:biped:complain_01` | Checkers. Screen it: if it reads as complaining, try `preset:biped:agree`, else Meshy's `Talk`. Never the phone-call preset. |
| `Play` | `preset:biped:sing_01` | Band lead. Other musicians may use `preset:biped:standing_relax`, or keep `Idle`. |

If v1.0 rigging fails on a sheet, use v3.0 and drop the optional clips. Do not invent a pose.

---

## 3. Characters: routing and the Tripo pipeline

### Routing

1. **Tripo web app in Brave, for the seven meshes**, only if this session can actually drive the open Brave window. Use the
   signed-in tab. Do not ask for a password, do not read cookies, do not sign in again.
   - Image to 3D on the exact sheet. No restyle, no "enhance face", no invented description.
   - Textured + PBR, about 9k faces, GLB. Download the **GLB** to `design/ep2/auction/cast-references-20261116/web/<id>.glb`.
     A Studio share link is not an asset; download the file.
   - If no browser tool can drive Brave, say so plainly and use the Tripo API for the meshes. Never claim the web app was used.
2. **Tripo API** for rig, retarget, and the mesh fallback. Rig 25 credits; retarget 10 per call (up to 5 clips). Seven rigs +
   seven retargets = 245 credits, inside the 505.
3. **Meshy** only for a clip Tripo cannot supply, or after a clean Tripo retry fails. Its 86 credits do not fund seven full characters.

### A. Mesh generation (API path, or after a web download)

```bash
cd /home/kofibeatz/.cache/gm-auction-cast-20261116
python3 tools/ep2_forge/tripo_gen.py balance                     # must print a number, not 401
python3 tools/ep2_forge/tripo_gen.py image \
  design/ep2/auction/cast-references-20261116/checker_a.jpg \
  --out .farm/tripo/checker_a \
  --set face_limit=12000 --set texture=true --set pbr=true
```

`.farm/tripo/checker_a/receipt.json` holds the `task_id`, credits before and after, and `raw.glb`. Do not use image
enhancement; the sheets are already T-pose references.

### B. Rig-check, rig, retarget (API)

```text
POST /v3/animations/rig-check   {"input": "<generation task_id>"}          # free
  -> poll /v3/tasks/{id}; require output.riggable == true and output.rig_type == "biped"

POST /v3/animations/rig         {"input": "<generation task_id>",
                                 "model": "v1.0-20240301",
                                 "rig_type": "biped",
                                 "spec": "mixamo",
                                 "out_format": "glb"}                       # 25 credits
  -> poll /v3/tasks/{id}; download output.model_url as rigged.glb

POST /v3/animations/retarget    {"input": "<rig task_id>",
                                 "animations": ["preset:biped:idle",
                                                "preset:biped:greet_01",
                                                "preset:biped:complain_01"],
                                 "out_format": "glb",
                                 "animate_in_place": true}                   # 10 credits per call
  -> poll /v3/tasks/{id}; download output.model_url as animated.glb
```

Write a resumable helper, `tools/tripo/auction_cast_batch.py`, modelled on `tools/meshy/townfolk_batch.py`:
`plan` spends nothing; `run` saves task ids to `design/ep2/auction/cast-references-20261116/manifest.json`; `finish` rebuilds
from saved tasks. Never re-generate a task that already succeeded.

### C. Blender post-process: headless only

Use the headless `blender -b` path below. Do not drive the live Blender MCP for this; it froze and crashed Blender on a
similar job (`blender-headless-render-safety`).

```bash
blender -b --factory-startup -P tools/ep2_motion/prep_folk.py -- \
  --src .farm/tripo/checker_a/animated.glb --height 1.82 --tris 200000 --tex 1024 \
  --out .farm/tripo/checker_a/prep.blend

blender -b .farm/tripo/checker_a/prep.blend --factory-startup -P tools/ep2_motion/export_folk.py -- \
  --out .farm/tripo/checker_a/export.glb

tools/ep2_forge/gltfpack_safe.sh .farm/tripo/checker_a/export.glb .farm/tripo/checker_a/small.glb 0.75
python3 tools/meshy/shrink_glb.py .farm/tripo/checker_a/small.glb \
  src/episode2/extras/people/auction_checker_a.glb --max 512 --aux-max 512 --quality 80
```

- Generate at 12k; `gltfpack_safe 0.75` lands near 9k. If a mesh is already about 9k, pass `1.0`. Never `0.3` on a 9k mesh.
- `--tris 200000` stops Blender's collapse decimate from shredding Tripo UV islands; `gltfpack_safe` does the real reduction.
- Rename clips to the game slots (`Idle`, `Talk`, `Greet`, `Play`) before export. `Ep2TownFolk` looks up those names.
- Scale to the height in section 2, feet at z = 0, centred, facing -Y. Confirm armature scale is 1.0 after export.
- **Check bone names** in the exported GLB before any instrument is attached. The band rows use `LeftHand` / `RightHand`
  (`ep2_auction_house.gd:71-74`). A mixamo export may prefix bones (`mixamorig:`). If the names differ, map them in prep, not in the hall script.
- Face close-up check (front, about 85 mm) before shipping. Glasses and hat brims must survive UV seams.
- Target **≤ 350 KB** per person. If over, drop the base texture to 512 and retry before dropping below ~8k tris.

### D. Measure one GLB before spending more

Generate **one** character end to end (checker A is the best test: it needs Idle + Talk + Greet). Record bytes, triangles,
clip names, texture sizes and the close-up. Only then decide how many more to generate.

---

## 4. Pack budget and the decision it forces

This is the blocker, and it is bigger than the characters alone.

| Item | Rough budget (streamed) | Notes |
|---|---|---|
| 7 people | ~2.5 MB (≈350 KB each) | Measure one first (section 3D) |
| Band instruments | 0 (kit props are already in `index.pck`) | Do not move them |
| Score | ~0.4–1.0 MB | One ogg, mono, 48–64 kbps, 60–90 s loop |
| Crowd extras | ~0.1–0.3 MB | Only generated sounds not already on disk |
| **Free today** | **67 KB** | |

Rules:

- Gate: `ep2_extras.pck < 199,229,440 B`. Do not add art to `index.pck`.
- Free room **before** you generate: name every proposed removal in STATUS. Never delete founder art silently.
- Do not raise the gate, and do not create a new pack, without the founder's explicit approval.
- Order of shipping if room is short: **checker A + checker B first** (the road and the door), then **score + crowd** (cheap
  in bytes, big in feel), then the **band**.
- If the founder must choose what to free, ask him one question with the byte table above. That is the one decision you
  cannot make for him.

---

## 5. Band: wire and prove

The wiring exists. `band_ready()` makes it all-or-nothing, so no part-band is ever shown.

- Five rows in `BAND` (`ep2_auction_house.gd:69-76`): model, x, z, instrument piece, hand bone, prop offset, prop rotation.
- `_build_band()` (`:464`) places them, then attaches instruments, then faces `BAND_FACE` (2.0, 0, 12.0): they play to the room, not the block.
- Band lead plays `Play` (sings). Fiddle, guitar (banjo), bass and harmonica play `Play` on their hands.
- Stage-left, off the centre aisle; the centre aisle must stay clear (test it).
- After the five GLBs exist, verify the instrument attach with a real capture: each instrument sits in a hand, not floating.

Verify, do not rewrite:

```bash
grep -n 'CHECKER_A\|CHECKER_B\|BAND_LEAD\|BAND_FIDDLE\|BAND_GUITAR\|BAND_BASS\|BAND_HARMONICA' src/episode2/ep2_extras.gd
grep -n 'band_ready\|_build_band\|doorman_model\|clerk_model_path' \
  src/episode2/chamber/ep2_auction_house.gd src/episode2/chamber/auction_road.gd
```

Commit each `.glb` **and** its generated `.import`. An uncommitted GLB does not count for the presence gate
(`scripts/check-ep2-extras-pack.sh` checks tracked files under `src/episode2/extras/`).

---

## 6. Hall light: a lighting and material pass, not a rebuild

The CAD pass made the walls and roofline richer, but the hall still reads dim. Fix the light, not the room.

- Work inside existing `_light()` calls and the lantern row (`ep2_auction_house.gd:248`, `:261-263`, `:318-328`). Adjust energy,
  range, colour temperature. Do not move a light across a wall or change a solid.
- Keep the warm, dusk-to-night mood; the aim is a room you can read, not a daytime one.
- Do not touch `W, D, DOOR_W, STAGE_*, RAIL_Z, BLEACH_*, SIDE_DOOR_*`.
- Prove it with `ship-visual-proof`: before/after captures of the same camera positions, and a texture probe for any material
  change. A founder who sees a changed colour asks "why did you change my X", so the proof is required.
- Grade the capture against the founder's references with `ep2-reference-match-loop` (one board, screen beside target).
  Target image for the town look: `artifacts/episode2-gold-mine/references/founder_2026-10-13_town/goldmine_town_target.jpg`.
- If the founder wants a visibly different room, that is a separate set-dressing pass. Say so; do not rebuild the hall.

Capture command: `godot --path . --rendering-method gl_compatibility res://tools/ep2_shots/auction_house_shot.tscn -- out=<dir>`
(plus the `probe` and `close` variants). Existing before/after captures: `docs/episode2-quality/auction-cast-20261116/`.

---

## 7. Score: one 1880s background track from Muapi (Suno)

The hall needs a score. Today there is only the road song (which ends at the porch) and the night bed.

### Generate

Muapi endpoint **`suno-create-music`** (text → full song, $0.09 per call, `instrumental` option). Base URL
`https://api.muapi.ai/api/v1`, header `x-api-key` from the env. Do not put the key in a file or a log.

Settings:

- `instrumental: true` — no vocals; this is background music, not a song.
- `custom_mode: true`, `title: "Auction Hall - Old Time"`.
- `style`: old-time Western parlour and saloon, 1880s; fiddle lead, banjo, harmonica, upright bass, light hand-clap; slow
  waltz or a relaxed two-step; warm, dusty, unobtrusive. No drum kit, no electric instruments, no modern production.
- `negative_tags`: "drum kit, electric guitar, synth, modern, vocals, epic, orchestral".
- `duration`: 60–90 s. Generate **two or three** candidates (about $0.27) and pick the one that loops cleanly and stays quiet.

Then:

1. Listen to the candidate. Reject anything that is busy, loud or fights speech. The score sits under the auctioneer.
2. Make it a **seamless loop**: trim to a bar boundary and cross-fade the ends with `ffmpeg`. A loop with a click is a fail.
3. Encode mono ogg at 48–64 kbps and measure bytes (section 4).
4. Save as `src/episode2/extras/music/ep2_auction_hall.ogg` with its `.import`, and add it to the streamed pack list in `src/episode2/ep2_extras.gd` (same pattern as `ep2_gm_og_smoke.ogg`).

### Wire

- Start the score when the player enters the hall, and fade it out when they leave through the porch. Use `AudioManager.crossfade_music()`
  and `fade_out_music()` (the road song does the same at `auction_road.gd:614-619`).
- Use the `Ep2Extras.has(path)` check first. If the pack is absent, the hall plays the night bed only and nothing breaks.
- Duck under speech with the existing music duck (`AudioManager` `DUCK_DOWN_DB_PER_S` / `DUCK_UP_DB_PER_S`, `audio_manager.gd:682-683`).
  Hold the duck for the **whole** speech, not per line (the existing rule in `audio_manager.gd` for this).
- Keep the score quiet enough that the auctioneer and the crowd sit on top of it.

### Prove

- Listen to a 3-minute playback in the hall with speech on. The score must not drown any line.
- Test: the score starts in the hall, ducks under a spoken line, and fades out at the porch.

---

## 8. Crowd: ambience and reactions

The room has a crowd on paper and almost none in the sound. Fix the bed first, then the reactions.

### Ambience bed (always on in the hall)

- Use **`town_people_loop.ogg`** (16 s loop, already on disk) as the room's bed, under the night bed, low. It is already in the
  extras pack, so this costs no bytes. Check its loop point is clean.
- Scatter **`miners_auction_1..4.ogg`** as random murmur one-shots among the bidders (about every 6–12 s, random pitch,
  positional, small `unit_size`). The bidders, not the walls, should make them.
- Do not use `auction_renegade_*.ogg` for crowd sound. Those are Renegade's lines.

### Reactions at the auction's moments

Map each moment to a crowd response. The existing reaction picker (`ep2_auction_house.gd:654-679`, `REACT_WEIGHTS`) already
handles "cheer / clap / agree / look on". Add the missing sounds where it does not:

| Moment | Crowd response |
|---|---|
| Arrival at the hall | Murmur swells, then settles. |
| Bidding climbs | Murmur rises; a few claps. |
| A bid is taken | Clap or cheer (existing picker). |
| Sold / a bidder wins | Cheer (`crowd_cheer.ogg`, cooldown `CHEER_COOLDOWN`). |
| **Hammer runs** | **Gasp, then a scatter of shouts, then the murmur returns.** `_flee()` (`ep2_auction_house.gd:567`) plays no sound today. Add the shock there. |
| Renegade's line | Quiet, then a laugh from the watchers (`man_laugh_*`, `woman_laugh`, `saloon_laughter`). |

Missing sounds: a **crowd gasp**, **shouts / scatter**, and **calls of disbelief**. Generate them with Muapi
**`suno-generate-sounds`** ($0.02 each, "chirp-crow" sound-effect model). Generate four to six candidates (about $0.12),
listen, keep the best. Name them clearly under `src/episode2/extras/audio/town/` (e.g. `crowd_gasp.ogg`, `crowd_scatter.ogg`).

Rules:

- The shock on Hammer's flee is short: 2–4 s, then the room carries on. It must not be a jump scare.
- Respect `CHEER_COOLDOWN` so one whoop does not stack on another.
- Every crowd sound sits under the speech duck (section 7).
- Count the bytes of each new sound against section 4.

### Prove

- A test (or a logged run) that the flee path plays the shock, and that the bed starts when the hall starts.
- A short capture or audio clip of one full auction run: arrival → bidding → a sale → Hammer runs.

---

## 9. Gates, captures, and what to report

```bash
GODOT_BIN="${GODOT_BIN:-.godot-cache/Godot_v4.3-stable_linux.x86_64}"
"$GODOT_BIN" --headless --path . res://tests/ep2_lake_auction_road_test.tscn    # must print 61 checks, 0 FAIL (or updated pin)
"$GODOT_BIN" --headless --path . res://tests/ep2_fix_pack_1115_test.tscn
"$GODOT_BIN" --headless --path . res://tests/ep2_horse_and_logan_test.tscn
"$GODOT_BIN" --headless --path . res://tests/ep2_armory_two_story_test.tscn
"$GODOT_BIN" --headless --path . res://tests/ep2_character_motion_test.tscn
bash scripts/check-ep2-extras-pack.sh web/game
```

- If you add checks (band placed, score wired, flee shock), update the CI pin at `.github/workflows/export-game.yml`.
- Pack bytes: `stat -c%s` on the built `ep2_extras.pck`, and `python3 tools/ep2_forge/pck_report.py <pck> --top 25`.
- Real-renderer captures for the clerk, the doorman, the band with instruments, and the lit hall.

---

## 10. STATUS and ship

Replace the old "Meshy key is a placeholder (401)" sentence with:

```markdown
- **Checkers, band, score and crowd: NOT in the game yet — not generated / not shipped.** Both credentials are valid. The Meshy
  401 was a false alarm: a placeholder `MESHY_API_KEY` in `~/.bashrc` shadowed the real key; that loader is fixed. Tripo API
  505 credits, Meshy 86 credits, Muapi balance as read. Tripo is primary (web app for meshes, API for rig/retarget); Meshy is
  the fallback. The hall's light, score and crowd are their own items, each with real bytes.
```

Keep the lines about Renegade, horses, CAD/Blender, the gate and the road-horse item. Do not claim founder verification. Do not
claim a character is in the game until its GLB is committed, packed and seen in a capture.

Ship (`CLAUDE.md`, always-ship): commit each change with a clear message, run `scripts/ship-to-master.sh`, then **prove**
master's CI deployed (run success, "Deploy to itch.io via butler" success, the BUILD tag matches). Say "live" only after that
proof. Before it, say "pushed / deploying".

Log the work in the Obsidian vault `GM Game/Work Log/<date>.md` and link it from `GM Game/Work Log.md` (vault-log rule).

---

## 11. Done means

- [ ] Checker A measured: bytes, triangles, clips, texture sizes, close-up. Then the rest generated.
- [ ] Pack room named and freed (or the founder's choice recorded), or checkers shipped first.
- [ ] Checker A in the road claim scene; checker B at the hall door; both with `Idle` + `Talk` and a natural stance.
- [ ] All five band models in the pack; five on stage-left; instruments in hands; centre aisle clear.
- [ ] Hall light: before/after captures, reference-match graded, `ship-visual-proof` done.
- [ ] Score: a seamless loop in the hall, ducked under speech, fades out at the porch.
- [ ] Crowd: bed on; murmurs; reactions at the moments in section 8; Hammer's flee shock.
- [ ] Gates pass (auction gate printed `0 FAIL`, or pin updated); extras pack under gate.
- [ ] STATUS corrected with real bytes and credits spent. Muapi, Tripo and Meshy spend listed.
- [ ] Committed, shipped to master, CI + butler proven, BUILD tag verified.

---

## 12. Hard rules

- Do not rebuild the hall. Do not change `W, D, DOOR_W, STAGE_*, RAIL_Z, BLEACH_*, SIDE_DOOR_*`.
- Do not touch Utah/Rich, Dude's stable horses, or Logan's stock.
- Do not recolour the player's road horse in this task.
- Do not add art to `index.pck`. Do not raise the pack gate without the founder's approval.
- Do not print, commit or paste any API key. Do not read Brave cookies.
- Print a balance and a `plan` before spending any credit (`tripo_gen.py balance`, `meshy balance`, Muapi `balance`).
- Do not delete founder art to make room without naming it in STATUS.
- Do not use a Tripo Studio share link as an asset. Download the GLB.
- Do not claim the Tripo web app was used unless a browser tool actually drove it.
- Do not commit while `scripts/ship-to-master.sh` is still running in this worktree.
