---
name: ep2-gunplay-feel
description: Make Episode 2's weapons feel right and be fair - an AUDIBLE revolver blast (measure loudness, shuffle variants), shooting every blocker that can be shot (shovel bears die and the rider keeps going), shooting while ziplining, keys that don't fight the browser (X for the axe, never F), right-click strike, and zipline timing that humans can actually hit. TRIGGER when the founder says the gun is silent / has no fire sound, a bear "blocks the way", he can't shoot somewhere, a key changes the screen/does something odd, a zipline or hazard "kills" him, or when adding any new shootable hazard or weapon input.
---

# Why this exists
Founder 2026-10-01: "I want the gun to have a revolver fire sound; if Lil Blunt shoots the bear blocking the way he
should be able to keep going and it should die even if he doesn't catch the zipline; he should be able to shoot while
ziplining too; pressing F changes the screen size, make it X, and right-click strikes with the axe"; and "why does the
2nd zipline kill Lil Blunt". Every one of these was a gap between what the tests proved and what a human felt.

# Rules (each one cost real time)
1. **A sound you never measured may be silent.** `ep2_revolver_shot.mp3` shipped for weeks with a peak of -39 dB
   (mean -54 dB) next to a pickaxe swing at -0.1 dB. Tests only checked the file existed. Always run
   `ffmpeg -i f.mp3 -af volumedetect -f null -` on a new weapon sound: peak must be about -1 dB, mean above -25 dB.
   Generate (`assets/audio-manifest.json` + `scripts/generate_audio.py`), then `loudnorm=I=-10:TP=-0.5:LRA=7`.
   Ship 3 variants and shuffle with +-6 % pitch (runner_view `_on_shot`) so a volley is not one repeated sample.
2. **Every blocker has a verb, and shooting is a verb for anything bear-shaped.** The shovel row used to answer only
   to the zipline. Now each bear is an obstacle with `bear_dead`; a bullet (mouse ray `fire_ray`, keyboard
   `shoot()` auto-aim on the rider's own rail) kills it, `shovel_bear_down(obstacle_index)` tells the view to topple
   it, and `_check_obstacles` skips a dead bear. Only the rail you shoot opens: bears on other rails still smack.
3. **Shooting is legal on the zipline.** The sim never forbade it; the VIEW did (`busy` included `zipping`, so the
   gun arm was switched off). He hangs from the pickaxe with one hand and fires with the other.
4. **Never bind a gameplay key the browser owns.** F toggled fullscreen on itch (the canvas resized). Axe = `X`
   (physical key) or right mouse button. Also avoid F11, Esc-as-action, Ctrl/Cmd combos, Tab, and the
   function row. Update the HUD hint (`ep2_entry.gd`) and the bindings comment (`ep2_session_root.gd`) together.
5. **A timing window must be human-sized.** The chained-zipline swing used to count only in the last 6 m of a cable
   (~0.25 s at speed); almost every human dropped, lost a health, and then met a box 24 m on and an arrow volley
   20 m after it - dead. Press-anywhere-on-the-cable arms the swing, and a chain landing is followed by 50 m of
   quiet track. Rule of thumb: **a required input window >= 0.4 s, and no two hazards inside 1.2 s of a recovery**.
6. **Death accounting beats per-hazard fairness.** A bot with perfect timing proves solvable, not survivable.
   When a founder says "X kills me", count the hits a human takes through the whole stretch (miss + next two
   hazards), not just X.

# Checklist for any new shootable hazard or weapon input
- Sim: target sphere (centre y, radius), range check, `*_down` signal, `bear_dead`-style flag reset in `setup()`.
- Both aim paths: `fire_ray` (mouse) and `shoot()` (keyboard), plus `ray_hits_archer` so the reticle turns red.
- View: death animation, `_play("bear_hit")`, aim point for the reticle; verify with a real capture (see-it-yourself).
- Tests (`tests/ep2_runner_graybox_test.gd` section 25-27): kill -> keep going with no hit; other rails still hit;
  works while ziplining; sound files exist. Then the track solvability bot (`ep2_session_root_test`).
- Sound: measured loudness, variants, bus = SFX. Never add runtime bus effects (web silence trap).
- Input: only keys safe in a browser embed; hint text updated.

# Update 2026-10-03 (founder: "the revolver has no sound... it's a fucking REVOLVER")
The gun layer now ALSO lives in `runner_audio.gd`: `shot_fired` -> hammer click + a report from a 6-player pool (volleys overlap), samples `ep2_revolver_blast_1..3.mp3` (ElevenLabs, peak-normalised to -1 dB: one take came out at -16 dB peak, ALWAYS measure with `ffmpeg -af volumedetect`) at +4 dB. The zipline has a looping `ep2_zipline_rush_loud.mp3` at +5 dB while hooked (rails loop is -8 dB and is off then). Test: tests/ep2_runner_audio_test.gd. `generate_audio.py` regenerates missing files; film_* voice lines belong in tools/ep2_film/voice/, delete the copies it writes to src/.
