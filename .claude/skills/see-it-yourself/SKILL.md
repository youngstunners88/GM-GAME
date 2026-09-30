---
name: see-it-yourself
description: Give Claude working EYES on the game - capture the real renderer, crop onto the subject, orbit it from six sides in the same frozen frame, mask it pixel-exact, A/B variants live, measure it, and only then judge. TRIGGER the moment the founder says a character/prop/screen "looks trash / wrong / weird / dark / deformed", says "check for yourself", or sends a "this is what it should look like" image; and before ANY claim that a visual change looks better. Never ask the founder for a screenshot you can take yourself.
---

# Why this exists
2026-09-30. The founder: "LIL BLUNT IS STILL LOOKING TRASH!!!" - and the reply asked HIM for a screenshot. Every test
was green. The founder then had to say "CHECK FOR YOURSELF. DEVELOP A SKILL THAT LETS YOU HAVE EYES". One capture +
one zoom showed in a minute what a week of green gates had not: the revolver pointed at the ceiling, the pickaxe was
held up like a club, he crouched with his belt over the rim, and a clump of leaves rode over his hat. Green tests
prove the code does what the code says. Only eyes prove it looks like the picture.

# What the research says (Firecrawl, 2026-09-30) - the rules come from here
| Finding | Source | Rule it gives us |
|---|---|---|
| Vision-language models are weakest at exactly our defects: unnatural **body configuration**, **slight clipping**, a **missing/odd-held weapon**, **object orientation**. Visual-regression accuracy tops out at **45 %** (glitch detection 82.8 %). | VideoGameQA-Bench, arXiv 2505.15952 | A model's verdict on a POSE is never proof. Pose is proved by bone geometry + orbit views + your own look. |
| MLLM accuracy collapses as the subject gets **small in the frame**; cropping/zooming onto it recovers it, training-free. | "MLLMs Know Where to Look", ICLR 2025 (arXiv 2502.17422) | Always look at (and grade) the **subject crop**, never only the 1280x720 frame - the hero is ~3 % of it. |
| Artists judge readability with the **silhouette**, **value (greyscale)** and **thumbnail** tests. | 80.lv "Silhouette and Contrast"; character-design readability notes | The board carries a greyscale tile, a 25 % thumbnail and the hero mask. |

# The loop
1. **Capture the real renderer** (Mesa GL Compatibility = the web renderer, ~80 s):
   ```bash
   G=.godot-cache/Godot_v4.3-stable_linux.x86_64
   xvfb-run -a -s "-screen 0 1280x720x24" $G --rendering-driver opengl3 --rendering-method gl_compatibility \
     --resolution 1280x720 res://tools/ep2_shots/shot_runner.tscn -- out=<dir> leg=0 at=40,150,262 eyes=1
   ```
   `eyes=1` writes per mark: `d####.png` (game camera), `d####_{back,front,left,right,q_front,top}.png` (six orbit
   views of the SAME frozen frame, own camera), `d####_nohero.png` (same frame, hero hidden) and prints `EYES box`
   (the posed skeleton projected to the screen).
2. **Board + numbers**: `python3 scripts/eyes-board.py <dir> 40 --box <EYES box> --ref <REF.jpg> --ref-box x0,y0,x1,y1`
   -> `d0040_board.png` (game | subject crop | reference crop | VALUE | THUMBNAIL | MASK), `d0040_orbit.png`,
   `d0040_metrics.json` (area %, hero lum, value separation from the background ring, RMS contrast, p95 highlight,
   gold-revolver px, green/brown %). The mask is the with/without-hero difference, limited to the skeleton box and its
   largest blob (embers keep moving between renders).
3. **Look yourself** - Read the crop and the orbit. Write each defect as a concrete sentence: WHAT, WHERE, WHICH VIEW
   ("revolver points straight up, beside his face, FRONT view"). The orbit catches what the chase camera hides.
4. **Find the carrier before fixing** - it is one of: pose code, the model itself (`node scripts/glb-shot.mjs <glb>
   <out.png>` = bind-pose six-view sheet), **skin weights** (see traps), material, lights, camera.
5. **A/B live, one variable per variant** - `vary=` applies overrides 6 m before each mark (so per-step state such as
   body yaw settles), marks separated by `;`, props by `|`:
   `arm.<prop>` RunnerArmRest - `aim.<prop>` RunnerAimModifier - `view.<var>` RunnerView (hero_yaw_base, cam_height,
   cam_back) - `node.<Name>.<prop>` any named node (HeroKey, HeroFill, HeroRim) - `mat.<prop>` every hero material.
   Then `eyes-board.py <dir> 40 --compare 55,70,85 --views game,back,right,front --labels "A;B;C;D"` -> one grid.
   Always include a baseline row.
6. **Decide on numbers.** Compare `metrics.json` against the OLD build on the same frames (a `git worktree` of HEAD
   with the new capture tool copied in - see traps). For a choice between measured candidates ask Jev with the numbers
   (text only, ~$0.00003): `node scripts/jev.mjs --state "<metrics + founder complaints>" --choice "pick=A:..|B:.."`.
   For a second pair of eyes: `python3 scripts/ref_compare.py <ref_crop> <game_crop> <out.jpg> --grade --rubric-file
   .claude/skills/see-it-yourself/hero-rubric.md` (DeepSeek V4.1 Flash, ~$0.002) - a LEAD; where it contradicts
   measured geometry, say so in writing and trust the geometry.
7. **Freeze** every defect a machine can check as a test (`tests/ep2_runner_motion_test.gd`: barrel points at the aim
   target and not up; hips at/below the rim; feet in the cart; hands in front).
8. **Report with the board path.** Never "looks like the reference" without a board; say what still does not match.

# Traps (each one cost time on 2026-09-30)
- **Moving the runner's camera does nothing** - it re-seats every frame. The orbit uses its own `Camera3D`.
- **`vary` Color with 3 components** (`Color(1.3,1.3,1.25)`) does not parse -> null -> a black, see-through hero that
  looks like a lighting result. Now a hard `VARY-BAD` error; always write `Color(r,g,b,1)`.
- **Moving the key light in front of the hero blacks him out** - the tunnel has ~no ambient; the camera-side light
  (HeroKey) must stay. Brightness from albedo/self-glow flattens him; brightness from lights keeps the shading.
- **Meshy auto-rig binds hair/leaves to ARM bones.** Invisible in the bind pose; the moment the arm is posed it drags
  a clump of leaves. Check: `python3 tools/meshy/reweight_mane.py <glb> --dry-run` (re-skins leaf-green verts farther
  than the arm's own skin radius onto neck/Spine; idempotent; bind pose unchanged). Re-import after: `$G --headless --import`.
- **Hair/mane taller than the hat** is geometry, not pose: `python3 tools/meshy/tuck_mane_under_hat.py <glb>`
  squashes head-mane leaves above the head joint (spreading through connected triangles, never into the brown hat
  or the hands; folding by a per-direction BRIM estimate failed because the hat is tilted and its "outer ring" is
  partly crown). Order: original GLB -> reweight_mane.py -> tuck_mane_under_hat.py -> `$G --headless --import`.
  Always look at the IN-GAME orbit after a bind-pose sheet: the bind sheet still looked bushy from behind while the
  posed game view (head tilted back) read hat-on-top.
- **A clip-free skeleton modifier cannot turn a held prop** unless it rotates the HAND: `_chain` aims a bone by the
  shortest arc and leaves the roll free, so the baked revolver pointed wherever the wrist faced. `_aim_hand` aligns
  the measured barrel/handle axis (hand-local, from skin-weight PCA) to a world direction.
- **"Before" in a worktree** needs the untracked `*.import` files copied in, or every texture fails to load.
- **Pose from behind**: a forward-pointing gun is foreshortened to a stub for a chase camera; body yaw a little away
  from the gun side swings the arm out where the camera sees it.
- **Firecrawl**: the key in the environment's `FIRECRAWL_API_KEY` returns 401; the founder's new key returns 200
  (verified 2026-09-30). The environment variable must be updated by the founder (Environment Variables field) - never
  commit a key. **TinyFish** Browser API (`POST https://api.browser.tinyfish.ai`, header `X-API-Key`, body `{url}` ->
  `cdp_url` for Playwright `connect_over_cdp`) is the route to see the LIVE itch page from outside this sandbox; the
  key answers (400 on an empty body), not yet exercised end to end.

# What this found on Lil Blunt (2026-09-30), for the next session
Fixed and measured: seated (hips 8 cm under the rim), barrel on the aim target (dot 1.00), pickaxe leaning at his side,
closer camera (+27-40 % screen area, framing gate green), glossier material + side key (RMS contrast 0.53-0.63 vs old
0.41-0.55, highlights p95 188 vs 157-166, brightness equal to the old build), 3,603 mane-leaf verts re-skinned off the
arms. Later the same day (founder: "correct Lil Blunt's hat with his hair"): 780 head-mane verts squashed under the hat
crown, no Meshy credits spent; from the chase camera the hat now reads on top with the leaves around/under it.
