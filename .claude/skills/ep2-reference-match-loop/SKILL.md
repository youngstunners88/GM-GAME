---
name: ep2-reference-match-loop
description: Prove an Episode 2 change looks like the founder's reference — capture the same beat in the real web build, put it beside the reference on one board, grade it against the founder's checklist, iterate until every item passes. TRIGGER after any Episode 2 visual change and before saying it "looks better/matches"; also whenever the founder hands over a "this is what it should look like" image.
---

# The failure this prevents
2026-09-29: build fully green (9 runner suites, art-direction, GLB, audio), assets "loaded" — and the founder
found Lil Blunt deformed, the revolver and pickaxe missing, the coins behind a "stupid filter". The gates
proved files existed; nothing compared the screen to the picture he had given us.
`ep2-browser-playtest` shows THAT it runs; this skill shows that it MATCHES.

# Loop
1. **Pick the acceptance picture** — the founder's TARGET LOOK image (`references/founder_<date>/REF_target-look.jpg`).
   One per beat: in-cart (target look), on-zipline (`REF_zipline-look.jpg`), bear on ledge, boulder smash.
2. **Capture the same framing** in the real build: `bash scripts/ep2-local-export.sh`, then
   `node scripts/ep2-play.mjs <dir> '[{"leg":0,"d":N,"shot":"x"}]' "ep2bot=1"` (autopilot plays; d = track metres,
   fire 15–20 m early for capture latency).
3. **Board + grade**:
   `python3 scripts/ref_compare.py <REF.jpg> <capture.png> <out.jpg> --grade`
   → labelled side-by-side board and `<out>.grade.md` (DeepSeek V4.1 Flash vision, ~$0.001, the 9-item founder
   checklist: hero visible/not deformed, revolver, pickaxe, cart+rails, Bitcoin coins, bears, glowing-crystal
   tunnel, warm lighting, HUD not hiding the action). Use `--rubric-file` for a beat-specific list.
4. **Look at the board yourself** (Read the image). The grade is a lead (CLAUDE.md model role split); disagree
   with it in writing when it is wrong.
5. **Fix the top item, re-capture, repeat.** Stop only when every rubric row is PASS by your own reading.
6. **Freeze it**: any FAIL that a machine can check becomes a test (e.g. `ep2_runner_motion_test`:
   "the pickaxe head clears the cart rim", "revolver + pickaxe baked in", "no separate weapon meshes drawn on top").
7. **Report** with the board path. Never write "looks like the reference" without a board.

# Checklist of founder-flagged defects (keep growing this list)
| Date | Defect | Now guarded by |
|---|---|---|
| 09-27 | can't see Lil Blunt; "ridiculous" | hero visible check (rubric 1), hero scale/pitch test |
| 09-27 | shooting looks weird (hands) | baked revolver + procedural recoil, no clip swap |
| 09-29 | no golden revolver / pickaxe | motion test: hero mode, weapon meshes suppressed, pickaxe > rim +1 m |
| 09-29 | coins masked by a filter | coin = lit metallic cylinder, no halo/alpha (rubric 5) |
| 09-29 | only tracks + carts looked good | keep leaf cart + rail geometry untouched |
| 09-27 | grey / cheap environment | glowing crystals, warm light (rubric 7, 8) |
