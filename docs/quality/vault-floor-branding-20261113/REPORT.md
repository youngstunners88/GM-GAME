# Episode 1 vault floor protocol branding

One world-space strip per separate vault room, built after the attendant positions are known in `src/level/vault_realm.gd`. Original `diamonds.png` / `goldmine.png` textures flank the exact `diamonds1111.win` / `mine4gold.app` URL. Logos are 88px high, text is 48px with the existing protocol palette and black outline. The strip sits at `FLOOR_Y + 60`, above the deck and behind characters, without collision or input nodes. The diamond fallback path is retained.

Mira's persistent holdings hint now sits at canvas y672, below the branding, instead of masking its URL at y596. Copy, stepped dialogue, stake/crush math, return paths, music, Episode 2, Smoke Lounge signage and title assets are unchanged. No panel branding footer was needed.

## Verified locally

- Pinned Godot 4.3 non-threaded web export, from a newly imported checkout. Main pack **199,089,088 bytes** (190 MiB gate: 199,229,440), zero script/parse errors. Extras pack **196,213,792 bytes**, also below its gate.
- All 112 suites in `scripts/ci-gates-local.sh` completed successfully under its documented tolerance for three existing pause-menu geometry differences. Summary: `local-ci-summary.log`.
- Final vault architecture, stake/crush utility, touch dialogue, exclusive music and whole-project script compilation suites passed. Logs retained here.
- Front-page lock, background art, harness hooks and security sentinel passed. Texture-reference probe: 71 models, zero excluded-but-used textures.
- Chromium 154 at 1280x720, keyboard input: browser cache disabled, page reloaded, Stage 2 / Stage 3 approach using existing stage/spawn probes, actual vault doors entered, Mira/Gideon dialogue opened and advanced. Both exact URLs and both logos remain visible below the characters and panels. Zero browser script errors. Retained before/after gameplay-camera captures and `local-browser.json`.
- Final room code is commit `31f2c31f`; packaging-only commit `bc16354a` excludes an unused review image. The room script is identical across both commits.

The first fresh pack was 2,400 bytes over the gate. The export filter now excludes `src/assets/logos/founder/ref_fud_reject.png`, a founder review screenshot mentioned only in a comment with no runtime resource reference. The source image is preserved. No gameplay art was removed.

Game Development Studio CLI and its packaged preflight script were unavailable; verification used the repository's existing Godot/Playwright tools. These browser checks do not claim physical-phone testing.

## Release

Validated locally; publication and public BUILD verification pending.
