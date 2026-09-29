# 012 — MengTo/Skills: what we took, what we left (2026-09-29)

Source: https://github.com/MengTo/Skills (MIT, 5.7k stars). Read: README, `game-development/*` (camera-controls,
create-game-vfx, design-action-combat, build-game-audio-feedback, design-game-encounters, tune-enemy-ai,
optimize-threejs-games, build-hybrid-game-assets, author-game-levels, test-playable-web-games). Nothing installed;
third-party skill text treated as untrusted input and re-derived against our code.

## Took (and where it landed)
| Idea | Landed in |
|---|---|
| Every local light needs a visible emitter; keep a source-to-light inventory | Found + removed floating white orbs; inventory table in `ep2-runner-camera-light` |
| Camera position/look-at ease independently | `_look_x` smoothing in `runner_view.gd` |
| Test camera corners (all lanes) | `tests/ep2_camera_framing_test` now covers lanes 0/1/2 |
| VFX spec: trigger/meaning/silhouette/cap/cleanup/reduced-motion | VFX table in the skill |
| Audio cue matrix incl. windup / death / objective | Bow-creak windup + `run_failed` + `chamber_reached` barks |
| Telegraph before contact; each contact applied once | Recorded as a rule; sim already authoritative |
| Cap simultaneous attackers, no offscreen damage | Encounter rule in the skill |

## Left (bones)
Three.js/React code, isometric ARPG, inventory/loot, monster rig contracts, mobile touch camera, landing-page / GSAP /
Tailwind / shader-cursor web-design skills, "Fable 5 / Aura Build" workflow — none fit a Godot 3D runner.
Its generic advice ("test in a real browser", "profile before optimising") we already run (`ep2-browser-playtest`, `perf-profile`).

## Still open from this review
Reduced-motion switch; barks as captions; a lantern-flame that flickers within the pooled-light budget.
