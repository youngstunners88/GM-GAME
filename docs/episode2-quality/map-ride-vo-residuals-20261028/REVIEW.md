# Episode 2 residuals — release verification

Owner-authorized instructions: [Google Doc](https://docs.google.com/document/d/1LWnTJqddjwHW3BdbjW3ECcpo79VqFkqKtCP094nxDE4/edit), archived in FOUNDER.txt. Source base: `9248f21be8bb6d0af0c99b6419774386d55bac20`. No prior changes were replayed. The owner subsequently explicitly instructed commit, push and ship. The prior draft-only instruction is superseded; release verification is in progress.

## Player changes

- Correct Jail/Rich & Utah placement on the chart. Small desktop M and G hints; G invokes the same confirmed manual save as the disk button, with echo suppression. Touch remains icon based.
- Ranch and town keep their surveyed geographic positions in the mounted world. Ride freely through the gate back to Main Street, stop, or take the northeastern trail to the lake. Trail has12 ambushers plus a chasing rider, with existing tells/damage/retry/horse-loss behavior.
- Remove the110-degree aiming cone. Mouse capture also follows keyboard shooting, drawing, movement and right-button aim, preventing a visible cursor's screen edge from restricting turns.
- Restore the previous founder Sheriff model/textures from `1383df16^` into streamed extras, retaining narrative/voice. Jail escort follows street and explicit outside/inside doorway waypoints.
- Mike Dean leaves immediately after the draw victory, before loot; the bell still exclusively opens the firing window. Enter draws, then normal firing applies. On touch the first fire press draws. The viewmodel remains fully hidden until drawn.
- Promote32 deferred dialogue lines into the production bank and record the minister's introduction. All142 manifest lines now have verified recordings. Use the latest document's `Pe1gOSDKAuczOZqgCiEm` for both Mike Dean and Dude; the original Sheriff voice is retained.
- Generated and wired crowd whoops/whistles/cheers and a clear steam-train loop. No double train run/passby; all train players stop once it disappears. Stable horses whinny/snort nearby.
- Shared red unlit stains/pools stay red as they dry; shot fallen townsfolk, opponent, bandits and bear bodies produce blood without awarding another kill.

## Verification

- Pinned Godot4.3 native residual158/158, complete town walkthrough, trail telegraphs/combat/unhorse/retry/arrival, voice timing, law, town feel/train stop, bear attacks,98 stable checks, blood and founder cast: pass. Compact logs are alongside this file.
- Manual checkpoints36/36 and legacy save compatibility: pass. Region map10/10: pass.
- Real Compatibility gameplay cameras: holstered draw/raised weapon, ranch saddle, town behind, mounted Main Street, reverse ambush aim and restored Sheriff. `cameras/` contains inspected images. The earlier diagnostic muzzle-visible capture was discarded after repair.
- Nonthreaded Web export compiled without script/parse errors. Main197455024B; extras124837152B, below199229440B per-pack cap. Extras presence gate:18 named+170 shipped extras. Raw ElevenLabs MP3 production takes are excluded by a generated `.gdignore`, leaving only Ogg takes in streamed extras.
- Actual local Chromium WebGL boot and Stage1 gameplay pass, no Godot errors: `browser-verification.json`. Browser BUILD is `dev-local`. This is distinct from an authenticated Episode2 browser walkthrough or public-origin verification.
- Front-page lock5/5 and harness gates pass. Security Sentinel:17/18 pass,0 blockers; the unchanged manual-save temporary-path heuristic is a medium finding. Full result: `security.txt`.

## Audio provenance and usage

Existing takes were preserved. New dialogue was generated only on verified intended accounts: ELE holds the requested Mike Dean/Dude ID; ELEVEN holds Sheriff GM. Before/after character counters: ELE1976→3945 (+1969), ELEVEN1291→2028 (+737), both free tier. These are provider-reported usage counters, not a monetary charge.33 new takes total; crowd/train effects regenerated. Receipt source hashes and Ogg SHA256 values match; engine durations match encoded granules. Keys remain outside game resources. Raw local takes remain under ignored `work/town-voices/`.

## Limits

No deployment, public BUILD check, authenticated public Episode2 walkthrough, real phone test, or subjective listening on physical speakers is claimed. Mounted return preserves town geography and background crowd, while conversations/story beats are not replayed after departure. Existing pause-menu target geometry reports the same3 failures recorded in the startup checkpoint; this draft does not change that layout. Game Development Studio CLI and repository `scripts/preflight.py` are unavailable; verification uses installed Godot/Chromium/project tools.
