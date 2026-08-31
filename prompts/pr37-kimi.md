Kimi K3 — quick verification gate for a brand-asset swap PR (concise, defects only).
PR #37 replaces src/assets/video/smoke_lounge.ogv (7.6MB -> 27.7MB) with a new cinematic. Verified facts:
- ffprobe: codec theora, 1280x720, NO audio stream.
- tests/s11_lounge_video_test.gd: 5/5 PASS (loads as VideoStreamTheora, looping BrandVideo, COVERS viewport both axes, muted volume_db<=-40, CanvasLayer in front of -20 room and behind gameplay).
- secret_realm.gd playback code UNCHANGED (git diff shows only the .ogv binary, STATUS, skill, model logs, web/game/index.html).
- Deploy pipeline fix present on branch (pipefail + index.pck gitignored), so the 27.7MB ogv rides in the CI-built pck to itch via butler, not committed to git.
Question: any correctness/ship risk in merging this? Specifically: does a 27.7MB ogv inside the pck threaten the itch deploy (itch has no 100MB single-file cap; GitHub cap only applies to committed files, and index.pck is untracked)? Any reason s11 passing headless would not reflect the browser? One-line verdict + any blocker.
