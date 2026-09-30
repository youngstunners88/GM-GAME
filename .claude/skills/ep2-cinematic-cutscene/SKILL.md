---
name: ep2-cinematic-cutscene
description: Build an action-packed IN-ENGINE cinematic ("the film") for Episode 2 - shot list as data, two clocks (bullet time: camera at real speed, action slowed), speed ramps that SNAP back on impact, trauma camera shake, letterbox, web-safe CPU particles, an audio ramp (low-pass + heartbeat, snap on impact), skippable, never leaking slow-mo into gameplay. TRIGGER when the founder asks for a cutscene, "film", "clip", slow-mo, a story transition, a set-piece moment (cliff jump, crash, reveal), or says a transition needs to be "action packed" / "with awesome effects".
---

# Why it exists
Founder 2026-09-30: the runner must end at a cliff; "the clip will cut and we will see the film of Lil Blunt in
the cart flying over the cliff as he jumps out the cart in the nick of time ... lands ... rolling and tumbling and
hitting his head on a rock ... passes out". "Action packed with a slow mo section as he flies over the gap, with
awesome effects." First implementation: `src/episode2/cinematic/cliff_jump_cinematic.gd`.

# Research that sets the rules (Firecrawl, 2026-09-30)
| Finding | Source | Rule |
|---|---|---|
| Bullet time = the CAMERA keeps moving at normal speed while the ACTION slows (Max Payne, The Matrix). | Wikipedia "Bullet time" | Two clocks. Camera, UI, shake and audio run on REAL time; subjects run on `action_dt = dt * speed(t)`. Never `Engine.time_scale` (it slows the camera too, kills the effect, and leaks into gameplay if a skip/early-exit forgets to restore it). |
| Camera shake from a 0..1 **trauma** value; shake = trauma^3 (0.3 -> 3 %, 0.9 -> 73 %); linear decay; smooth (Perlin) noise, which also behaves in slow-mo; in 3D translational shake is "super lame" - use **rotational** (yaw/pitch/roll). | Eiserloh, GDC 2016 "Juicing Your Cameras With Math" | `CinematicShake`: trauma += hit; rot = max_deg * trauma^3 * noise(t*freq); decays on the real clock. |
| GPUParticles do not render in Godot 4.3 web exports on some AMD Vega iGPUs / Windows ANGLE (regression since 4.3.dev6, godotengine/godot#95797). | GitHub issue | Every cutscene effect is `CPUParticles3D`. |
| Speed ramps read best eased IN and SNAPPED OUT: the snap back to 100 % on contact is what sells the impact. | editing practice (speed-ramp guides) | `speed(t)`: 1.0 -> 0.15 over ~0.35 s (smoothstep), hold, hard cut to 1.0 on the impact frame + trauma spike + sound. |

# Shape of a cinematic
1. **Shot list is DATA** (`const SHOTS := [{t0, t1, name, rig, ...}]`). Every shot: start/end on the REAL clock,
   a camera rig (`static`, `track` = follow subject with offset, `orbit` = circle subject at real speed, `pov`), FOV,
   and events (`sfx`, `voice`, `vfx`, `trauma`, `flash`, `speed`). Cuts are hard (`current = true` on a new pose),
   and cut ON action. Keep screen direction consistent across the gap (180-degree rule): the leap travels the same
   way on screen in every shot until the landing.
2. **Build the set in code from real assets** (the hero GLB, the leaf cart, the tunnel shell, rocks) so the film
   uses the same models the player just drove. No pre-rendered video: Godot 4.3 plays only Ogg Theora, the web pack
   has a budget, and a video cannot match the player's current resolution or the hero's current look.
3. **The subject's motion is procedural and deterministic** (ballistic arcs, roll = rotation proportional to
   distance, bounces as damped arcs) and is a function of ACTION time, so a test can scrub to any moment
   (`scrub(t)`) and a board can be captured at any timestamp.
4. **Frame dressing**: letterbox bars (2.39:1) ease in over 0.3 s; slow-mo = vignette + slight desaturation; head
   impact = 2-frame white flash + trauma 1.0; blackout = vignette closing + double-vision offset + fade.
5. **Audio ramp - WITHOUT touching the bus graph.** This repo's web build once went totally silent from ONE
   runtime bus-graph call (`set_bus_send`, 2026-09-16, see audio_manager.gd). So no `add_bus_effect` low-pass in a
   cutscene. Slow-mo audio = the classic trick: action sounds play at `pitch_scale` ~0.6 (deeper, stretched), the
   rumble ducks, a heartbeat + wind whoosh play; on the impact frame everything snaps back to pitch 1.0 WITH the hit.
   Head hit: clonk + tinnitus ring, other sounds ducked, fade out. Loudness-normalise new SFX first
   (`ffmpeg -af loudnorm=I=-15`): ElevenLabs SFX came back anywhere from -5 to -37 dB mean.
6. **Skippable**: hold SPACE/ESC ~0.6 s skips (a hold, so a mashed jump key from the runner does not skip it).
   Skipping jumps to the end state and emits `finished` exactly once.
7. **Hand-back contract**: `finished` once; the previous current camera is restored; no bus effect, time scale or
   input grab survives. The owning scene (here the Smelting Facility) continues with the next story beat.

# What the capture boards taught (2026-09-30, keep adding)
- Giant box faces read as grey-box instantly. Break every silhouette the camera sees with boulders (lip rows,
  rubble down faces, rocks around the tunnel mouth) - and then re-check that no camera ended up INSIDE one.
- A camera on top of a ledge cannot see anything below the lip: the ledge surface occludes it.
- A profile shot of a 16 m gap makes the hero a speck. Keep the hero big; tell far events with SOUND and the
  speed snap instead of cutting away to them.
- Additive "light beam" cones look like a solid slab from the side. Use the SpotLight alone.
- Hide a character until the shot that reveals him (the Bull stood in plain view during the tumble).
- Frame faces from the SKELETON (head bone), not from a guessed offset.
- A parse error in the film script makes a capture tool wait forever: fail fast (film_shot.gd checks can_instantiate).

# Budget
10-15 s total; the slow-mo hero shot 3-4 s; other shots 0.8-2.5 s. <= 300 live particles. It must run in the
Compatibility renderer at 60 fps on the web build - no SSR/SSAO/volumetrics; glow is fine.

# Proof (do not call it done without these)
- `tests/ep2_cinematic_test.gd`: runs the film headless to the end; asserts shot order, the hero leaves the cart
  before the cart passes the lip, lands on the far side, the head-hit event fires, `finished` once, bus effects
  removed, camera restored; `skip()` mid-film also ends clean.
- Capture boards with the see-it-yourself rig at key moments (`tools/ep2_shots/film_shot.gd`): launch, mid-air
  slow-mo, landing, head hit, blackout. Look at them; fix the worst shot; repeat.
