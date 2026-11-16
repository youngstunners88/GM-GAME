# Episode 2 — Auction cast: remaining work (Tripo-first) — 2026-11-16

**Give this file to Claude Code. Do not replay the old Meshy-only brief; most of it is already shipped.**
Branch: `claude/ep2-auction-cast-20261116`
Worktree: `/home/kofibeatz/.cache/gm-auction-cast-20261116`
Base: `origin/master` `cdc8a7a9` (live build `2026-11-16-71f10a8`)
Latest work: `3899f577`

---

## 0. State in one paragraph

Commit `3899f577` already contains the Renegade arm fix, the two tied-horse coats, a CAD + Blender interior pass, all the
checker/band wiring, the period instrument props, and the expanded auction gate (61 checks). **No new character has been
generated yet.** The earlier “Meshy key is a placeholder / 401” report was a false alarm: a placeholder `MESHY_API_KEY` in
`~/.bashrc` was shadowing the real key. That is fixed. Meshy now answers with **86 credits**. The **Tripo API key works and has
505 credits**, and the founder has the **Tripo web app open in Brave with a separate balance**. Use Tripo for the seven people.
The streamed extras pack is at `199,161,984 / 199,229,440 B` — **67 KB free** — so pack room is now the hard blocker, not the key.

---

## 1. The auction environment: CAD + Blender already improved it

This is done in `3899f577`; do not redo it unless the founder asks for a second, bolder pass.

- Source: `tools/ep2_cad/auction_house_cad.py`
- Baked to the kit: `tools/ep2_blender/build_town_interior_kit.py --prefix Auc_`
- In the hall: dark dado panelling with cap rail and skirting on both side walls, inside window sills and jambs, floor-board
  seams, iron knee brackets on the roof trusses, a brass bead + skirting + pilasters on the stage front, seven wall lanterns.
- On the porch: a license-check desk (the only new solid; off every walk path).
- No layout or collision change inside the hall. `W, D, DOOR_W, STAGE_*, RAIL_Z, BLEACH_*, SIDE_DOOR_*` are untouched.
- Captures: `docs/episode2-quality/auction-cast-20261116/` (`hall_before.jpg`, `hall_after.jpg`,
  `interior_matched_before_after.jpg`).

The captured lift is **modest**: the walls and roofline read richer, the lanterns help, but the hall is still dim. If the founder
wants a visibly different room, that is a separate lighting/material/set-dressing pass, not a reason to rebuild the hall.

---

## 2. Already done — do not redo

- **Renegade’s arms fixed.** `src/episode2/chamber/ep2_auction_house.gd:408` installs
  `Ep2ArmoryPose.install(renegade)` on the auction instance only. The shared model and Utah/Rich are untouched. Before/after:
  `docs/episode2-quality/auction-cast-20261116/renegade_arms_before_after.jpg`.
- **Tied auction horses recolored** white + black via `Ep2HorseCoat.apply()` at `ep2_auction_house.gd:345`. The player’s road
  horse (`auction_road.gd:_build_horse()`) is untouched.
- **Band and checkers are wired with fallbacks.**
  - Checker constants and game paths: `src/episode2/ep2_extras.gd:67-73`.
  - Claim clerk: `auction_road.gd:46` (`CLERK_MODEL`), `:265` (`clerk_model_path()`), `:271` (clip list), `:452` (`Talk`).
  - Hall doorman: `ep2_auction_house.gd:451-453` (`doorman_model()`), `:427`, `:596` (`Talk`).
  - Band: `ep2_auction_house.gd:67-76` (positions + instruments), `:456-478` (`band_ready()` / `_build_band()`).
    The band appears only when all five GLBs exist; a part-band or stand-in is never shown.
  - Instrument props are already in the kit: `Auc_Fiddle`, `Auc_FiddleBow`, `Auc_Banjo`, `Auc_Bass`, `Auc_Harmonica`.
    Attach offsets/rotations are in `BAND`.
- **Auction test** is 61 checks; the CI pin was updated at `.github/workflows/export-game.yml`.
- **Pack** is `199,161,984 B`; the extras gate is `199,229,440 B`.
- **STATUS.md** has the entry.
- **Adjacent bug, out of scope:** the player’s road horse never applies the coat chosen at Dude’s (`auction_road.gd` has no
  `Ep2HorseCoat` call). Leave it unless the founder asks; it is a separate item.

If a change would touch any of the above, prove why with a failing test or a capture first.

---

## 3. Credentials and provider routing

### Current state (verified 2026-11-16)

| Provider | Key location | Balance | Use |
|---|---|---|
| **Tripo web app** | Open and signed in in **Brave** | Founder says more credits than the API | **First choice for the seven meshes** |
| **Tripo API** | `~/GM-GAME/.env` (`TRIPO_API_KEY`) | **505 credits** | Rig + retarget, and mesh fallback |
| **Meshy** | `~/Documents/GitHub/GM-GAME/.env` (`MESHY_API_KEY`) | **86 credits** | Only Meshy-only clips, or if Tripo fails |

`~/.bashrc` now loads both keys. Do not print, copy, commit or paste any key.

### Validate before planning work

```bash
# If this is a non-login shell and the keys are absent, load them for this shell only:
set -a; . "$HOME/GM-GAME/.env"; . "$HOME/Documents/GitHub/GM-GAME/.env"; set +a

python3 -c 'import os;k=os.environ.get("TRIPO_API_KEY","");print("TRIPO len",len(k),k[:4])'
python3 -c 'import os;k=os.environ.get("MESHY_API_KEY","");print("MESHY len",len(k),k[:4])'
cd /home/kofibeatz/.cache/gm-auction-cast-20261116
python3 tools/ep2_forge/tripo_gen.py balance          # must print a number, not 401
meshy balance --format json --no-update-check         # must print a balance, not 401
```

If a key is missing, stop and report the exact command; do not substitute another provider silently.

### Routing rules

1. **Use the Tripo web app in Brave first for the character meshes.** The founder opened it for this task and it has its own
   credit pool.
2. **Use the Tripo API for rigging and animation**, and as the mesh fallback. Rig is 25 credits; retarget is 10 per call.
   The API’s 505 credits are enough for all seven rigs + idle/act clips even if every mesh comes from the web app.
3. **Use Meshy only when Tripo cannot produce a needed clip** (Meshy’s library has a true conversational `Talk` and `Greet`) or
   if Tripo fails after a clean retry. Meshy’s 86 credits are not enough for seven full characters; never spend them on the
   whole cast.

### Tripo web app instructions (only if you can actually drive Brave)

- Check whether this session has a browser/computer-use tool that can see the already-open Brave window. If it does, use that
  signed-in tab. Do **not** ask for the password, do not read cookies, and do not sign in again.
- In Tripo Studio, use **Image to 3D** on the exact sheet in `design/ep2/auction/cast-references-20261116/`. One sheet → one
  person. No restyle, no “enhance face”, no invented description.
- Settings: T-pose/subject as shown, textured + PBR, roughly 9k faces, GLB. Download the **GLB** to
  `design/ep2/auction/cast-references-20261116/web/<id>.glb`. A Studio share link is not a usable file; do not stop at a link.
- Then upload that GLB to the Tripo API (`POST /v3/files`) and run rig-check → rig → retarget below.

If no browser tool is available, say so plainly and use the Tripo API for the meshes. Do not claim the web app was used.

---

## 4. Pack budget — do this before spending credits

Seven people at the old ~500 KB target need ~3.5 MB. The pack has **67 KB**. Even the two checkers do not fit yet.

```bash
cd /home/kofibeatz/.cache/gm-auction-cast-20261116
GODOT_BIN="${GODOT_BIN:-.godot-cache/Godot_v4.3-stable_linux.x86_64}"

# Rebuild the streamed pack (the gate is on this file, not index.pck).
"$GODOT_BIN" --headless --path . --import
"$GODOT_BIN" --headless --path . --script tools/ep2_extras/pack_extras.gd -- /tmp/ep2_extras.pck
stat -c%s /tmp/ep2_extras.pck
python3 tools/ep2_forge/pck_report.py /tmp/ep2_extras.pck --top 25
```

Rules:

- Gate: `ep2_extras.pck < 199,229,440` B. Do not add art to `index.pck`.
- Measure **one real Tripo GLB first**. Target `<= 350 KB` with 9k tris, 512 px base colour, 512 px aux maps.
- Free room **before** generating the rest. Name every proposed removal in STATUS; never delete founder art silently.
- If you cannot free at least ~1 MB, ship **two checkers first**, then the band in a later pass.
- Do not raise the gate or move assets between packs without the founder’s explicit approval.

---

## 5. Cast and clip map

Sheets are already filed and match these files. Heights are body height in metres (hat included).

| id | Game file (`src/episode2/extras/people/`) | Sheet | Height | Required clips |
|---|---|---|---|---|
| `checker_a` | `auction_checker_a.glb` | `checker_a.jpg` | 1.82 | Idle, Talk, Greet |
| `checker_b` | `auction_checker_b.glb` | `checker_b.jpg` | 1.78 | Idle, Talk, Greet |
| `band_lead` | `auction_band_lead.glb` | `band_lead.jpg` | 1.66 | Idle, Play |
| `band_fiddle` | `auction_band_fiddle.glb` | `band_fiddle.jpg` | 1.76 | Idle, Play (optional) |
| `band_guitar` | `auction_band_guitar.glb` | `band_guitar.jpg` | 1.80 | Idle, Play (optional) |
| `band_bass` | `auction_band_bass.glb` | `band_bass.jpg` | 1.84 | Idle, Play (optional) |
| `band_harmonica` | `auction_band_harmonica.glb` | `band_harmonica.jpg` | 1.77 | Idle, Play (optional) |

Tripo v1.0 has the richer preset library; use it for this cast so `greet` and `sing` exist:

| Game slot | Tripo preset | Notes |
|---|---|---|
| `Idle` | `preset:biped:idle` | Required for all seven |
| `Greet` | `preset:biped:greet_01` | Checkers |
| `Talk` | `preset:biped:complain_01` | Checkers; screen it. If it reads as complaining, use `preset:biped:agree` or fall back to Meshy’s `Talk`. Never use the phone-call preset. |
| `Play` | `preset:biped:sing_01` | Band lead; musicians may use `standing_relax` or keep `Idle` |

Tripo’s v3.0 rig only exposes idle/walk/run/dive/climb/jump/slash/shoot/hurt/fall/turn — no greet/sing. That is why this cast
uses the v1.0 rig. If v1.0 rigging fails on a sheet, use v3.0 and drop the optional clips rather than inventing a pose.

---

## 6. Tripo pipeline

### A. Generate one mesh (API fallback, or after the web app download)

```bash
cd /home/kofibeatz/.cache/gm-auction-cast-20261116
python3 tools/ep2_forge/tripo_gen.py balance
python3 tools/ep2_forge/tripo_gen.py image \
  design/ep2/auction/cast-references-20261116/checker_a.jpg \
  --out .farm/tripo/checker_a \
  --set face_limit=12000 --set texture=true --set pbr=true
```

`receipt.json` in `.farm/tripo/checker_a/` carries the `task_id`, credits before/after and the downloaded `raw.glb`.
Use `--set model='"v3.1-20260211"'` only if the default is not that version. Do not use image enhancement; the sheets are
already T-pose references.

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
                                 "animate_in_place": true}                   # 10 credits per call, max 5 clips
  -> poll /v3/tasks/{id}; download output.model_url as animated.glb
```

Write a resumable helper (`tools/tripo/auction_cast_batch.py`) modelled on `tools/meshy/townfolk_batch.py`:
`plan` must spend nothing; `run` must save task ids to
`design/ep2/auction/cast-references-20261116/manifest.json`; `finish` must rebuild from saved tasks. Do not re-generate a task
that already succeeded.

### C. Blender post-process

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

- Generate at 12k and let `gltfpack_safe 0.75` land near 9k. If the mesh is already 9k, pass `1.0` (no simplification) —
  never `0.3` on a 9k mesh.
- `--tris 200000` means “do not let Blender’s collapse decimate shred the Tripo UV islands”. `gltfpack_safe` does the real
  simplification with attribute seams intact.
- Rename the clips to the game slots (`Idle`, `Talk`, `Greet`, `Play`) before export, or with a small GLB JSON pass. Tripo names
  them after the preset; `Ep2TownFolk` looks up the slot names.
- Scale to the exact height above, feet at z = 0, centred, facing -Y. `prep_folk.py` does this; verify 1.0 armature scale after
  export.
- Face close-up check (front, ~85 mm) before shipping: Tripo meshes can shred around UV seams; glasses/hat brims must survive.
- Target `<= 350 KB`; if over, lower base texture to 512 and retry before dropping triangles below ~8k.

### D. Wire and prove

The wiring is already in place. Verify, do not rewrite:

```bash
grep -n 'CHECKER_A\|CHECKER_B\|BAND_LEAD\|BAND_FIDDLE\|BAND_GUITAR\|BAND_BASS\|BAND_HARMONICA' \
  src/episode2/ep2_extras.gd
grep -n 'band_ready\|_build_band\|doorman_model\|clerk_model_path' \
  src/episode2/chamber/ep2_auction_house.gd src/episode2/chamber/auction_road.gd
```

Commit each `.glb` **and** its generated `.import`. An uncommitted GLB does not count for the presence gate
(`scripts/check-ep2-extras-pack.sh` checks tracked files under `src/episode2/extras/`).

---

## 7. Gates and captures

```bash
GODOT_BIN="${GODOT_BIN:-.godot-cache/Godot_v4.3-stable_linux.x86_64}"
"$GODOT_BIN" --headless --path . res://tests/ep2_lake_auction_road_test.tscn
"$GODOT_BIN" --headless --path . res://tests/ep2_fix_pack_1115_test.tscn
"$GODOT_BIN" --headless --path . res://tests/ep2_horse_and_logan_test.tscn
"$GODOT_BIN" --headless --path . res://tests/ep2_armory_two_story_test.tscn
"$GODOT_BIN" --headless --path . res://tests/ep2_character_motion_test.tscn
```

- Auction test must still print `61 checks, 0 FAIL` unless you add checks; if you add, update the CI pin at
  `.github/workflows/export-game.yml`.
- Captures: `godot --path . --rendering-method gl_compatibility res://tools/ep2_shots/auction_house_shot.tscn -- out=<dir>`
  (plus `probe` / `close` variants). Show the desk clerk and doorman in the real renderer, and the band with instruments.
- Pack: `stat -c%s /tmp/ep2_extras.pck` and `bash scripts/check-ep2-extras-pack.sh web/game`.

---

## 8. STATUS correction (use this wording)

Replace the old “Meshy key is a placeholder (401)” sentence with the truth:

```markdown
- **Checkers and band: NOT in the game yet — models not generated.** Both credentials are valid; no credits have been spent.
  The Meshy 401 was a false alarm: a placeholder `MESHY_API_KEY` in `~/.bashrc` shadowed the real key. That loader is fixed.
  Meshy balance 86 credits; **Tripo API 505 credits**, plus the founder’s Tripo web app in Brave with a separate balance.
  Tripo is the primary path (web app for meshes, API for rig/retarget); Meshy is the fallback for Meshy-only clips.
```

Keep the existing lines about Renegade, horses, the CAD/Blender interior, tests and the road-horse item. Do not claim founder
verification. Do not claim a character is in the game until its GLB is committed, packed and visible in a capture.

---

## 9. Done means

- [ ] One real GLB measured: bytes, tris, clips, texture sizes, face close-up.
- [ ] Pack room named and freed, or the two checkers shipped first.
- [ ] Checker A in the road claim scene, Checker B at the hall door, both with `Idle` + `Talk` and a natural stance.
- [ ] All five band models in the pack; five on stage-left; instruments attached; centre aisle clear.
- [ ] `61 checks, 0 FAIL` (or updated pin); neighbouring gates pass.
- [ ] Real-renderer captures for clerk, doorman and band.
- [ ] STATUS corrected with real bytes and credits spent.
- [ ] Commit + push + deploy, then verify the public BUILD.

---

## 10. Hard rules

- Do not rebuild the hall; do not change `W, D, DOOR_W, STAGE_*, RAIL_Z, BLEACH_*, SIDE_DOOR_*`.
- Do not touch Utah/Rich, Dude’s stable horses, or Logan’s stock.
- Do not recolor the player’s road horse in this task.
- Do not add art to `index.pck`.
- Do not print, commit or paste either API key, and do not read Brave cookies.
- Do not spend credits without first printing `tripo_gen.py balance` / `meshy balance` and a `plan`.
- Do not delete founder art to make room without naming it in STATUS.
- Do not use a Tripo Studio share link as an asset; download the GLB.
- Do not claim the web app was used if no browser tool could drive it.
