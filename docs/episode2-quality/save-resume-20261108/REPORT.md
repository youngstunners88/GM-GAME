# Save confirmation and checkpoint resume — 2026-11-08

## Repairs

- Godot 4.3 converts the JavaScript boolean result from `JavaScriptBridge.eval()` to an integer Variant: its BOOL case returns `uint32_t js_data.b`. The old `confirmed == true` comparison therefore rejected the successful result `1`. Chromium reproduced a real localStorage write followed by the pause button saying **Save not confirmed — retry** ([baseline screenshot](baseline-false-failure.png)). Accept only boolean `true` or integer `1`; `false`, `0`, null, strings, other numbers and unexpected types still fail.
- The Episode 2 scene registry includes `lake_trail`, but the checkpoint allowlist omitted it. Saving on that ride failed before writing, and previously stored ride records were discarded on load. Add that existing room to the bounded allowlist.

Official version-specific implementation: [Godot 4.3 JavaScriptBridge BOOL return](https://github.com/godotengine/godot/blob/4.3/platform/web/javascript_bridge_singleton.cpp#L352) and [JS boolean conversion](https://github.com/godotengine/godot/blob/4.3/platform/web/js/libs/library_godot_javascript_singleton.js#L330).

The explicit key remains `smokerealm_manual_checkpoint_v1`, schema version remains 1, and native saves still use the flushed temporary file and rename. Rolling autosaves cannot replace the explicit browser record. Episode 2 access, SaveSafe coercion, inventory/reward checkpoint rules, and the five locked title files are preserved.

## Verification

Pinned Godot 4.3 editor and export templates were downloaded from the official release and SHA-512 checked.

- Baseline native manual suite: 36 checks passed, demonstrating the missing regression coverage.
- Expanded native manual suite: **67 checks, 0 failed**. Includes strict bridge-result conversion; Save + disk reload for every registered chamber; actual lake-trail restore; pending record retained at the real access gate; coherent lake entry; immutable purse/armory/rewards; legacy saves; malformed records; and forced filesystem-write failure preserving the old file.
- Full workflow headless regression block passed via `scripts/ci-gates-local.sh`; only its three documented pause tap-target machine differences were tolerated. The same run executed all 67 checkpoint checks successfully. Logs: `/tmp/tmp.hNSr59K3fy/` and `/workspace/work/save-resume/full-gates.log`.
- CI pins the expanded count so a coroutine stopping early cannot claim a passing suite.
- Save compatibility suite: **ALL PASS**, including hostile/wrong-shape save clamping.
- Security sentinel: 18 checks, 0 high/critical blockers. Its existing medium `INJ-004` flags `write_session`’s temporary file path. Reviewed: production uses the constant `SAVE_PATH`; the optional path is used by the forced-failure test, not player-controlled input. No scanner suppression or write-path change was introduced. Front-page lock and harness-hook checks pass.
- Pause suite has the three exact pre-existing tap-target/lives/fullscreen overlaps documented in `scripts/ci-gates-local.sh`; this repair does not alter layout.
- Baseline Chromium: actual Episode 1 Save wrote a durable localStorage checkpoint but incorrectly showed failure. Hard reload + real Continue restored gameplay, and forced blocked storage preserved the previous key. The corrected export visibly shows **Saved checkpoint** ([screenshot](ep1-save-confirmed.png)); hard reload and the actual Continue button restore Stage 1. Forced `QuotaExceededError` shows failure, preserves the previous record, and retry succeeds after unblocking. No browser script errors.

- Final Godot 4.3 web export: 198,993,312 B, no script/parse errors. Clean-checkout export of `c8cc11d86be8ed2a7e2d0ce41dd899cfd5825bb4`: **198,960,128 B**, margin **269,312 B** below 190 MiB; extras **194,574,240 B**. Texture exclusion probe: **71 models, 0 excluded-but-used textures**.

- Episode 2 exact-export browser check: a fresh browser seeded only with the checkpoint reaches the real access gate. A disposable authorized-device file fixture then permits normal Continue. The real ride renders, its Save performs a new localStorage write (replacing the fixture), and visible text confirms **Saved: Episode 2 — Lake Trail** ([screenshot](ep2-save-confirmed.png)). Forced `SecurityError` displays **Save failed** and preserves the old checkpoint. Hard reload + actual Continue restores the ride and can save again. No browser script errors. The test waits for the existing debug beacon’s idle transition state and reads visible feedback; it does not infer success from a pre-existing key or a loading screen.

## Concurrent master and CI repair

Master advanced to `4bb5e45e910883fa07f2cde21f35c9432e758683` during verification. Preserved its Inferno/quad town changes and both STATUS entries. Integration checks pass: common-sense **40/40**, gold-town **ALL PASS**, manual checkpoints **67/67**. Unchanged components retain the earlier full-suite evidence.

That master’s [run 42458747648](https://github.com/youngstunners88/GM-GAME/actions/runs/42458747648) failed before release: `--editor --quit` aborted its scan, then the next import aborted with a core dump; `|| true` hid the failure and 36 portal checks ran without imported textures. The workflow now waits for a full first `--import` (1200 s bound, pipefail) and requires a successful second pass, retaining a failure tail. Test gates remain intact. Source integration/import repair: `dd5755152b9d05a1ffa1bc26d798fd3bcffd6598`; combined common-sense/town/manual checks pass. Clean combined export: **198,967,888 B**, margin **261,552 B**, extras **194,574,144 B**, zero script errors. The formerly failing portal gameplay/art suite passes after those complete clean imports. Both actual workflow import blocks were exercised with a forced failing importer and stopped before tests. The combined fresh export also passed the full browser gate/Save/blocked-write/reload/Continue/re-save sequence, with exact checkpoint bytes retained across reload and no script errors ([resumed ride](ep2-resume-confirmed.png)). The test permits the normal access prompt again if the temporary device fixture is not retained; a save never grants access.

## Audit runtime download retry

Production run `42461767823` for `bbe61f3d` passed gameplay, rendered captures and web export, but its audit setup failed when Bun’s GitHub download returned HTTP 504. The audit never ran and deployment was skipped; this was not a reported security finding. The whole installer now has three bounded attempts, with pipefail and a hard stop if all fail. Tests of the actual workflow block cover transient success, permanent installer failure and an outer curl failure. No audit check is bypassed.

Installed Bun **1.4.4** under the task workspace and ran the broad checklist locally: **47 total; 13 pass, 0 fail, 0 warn, 2 manual, 32 skip**. Existing manual/skip classifications are unchanged. Runtime source and exported game data remain identical to the verified `dd575515` revision; only audit setup changed. A new production run must still pass the audit and upload before release is claimed.

## Pinned, early audit setup

Run `42464978907` attempt 1 stopped on Godot’s download returning HTTP 504; after the URL recovered to HTTP 200, attempt 2 passed the game suite, captures and export but all three Bun `/latest/download` attempts still returned 504. The game and its export remain verified; neither attempt deployed.

The final workflow installs **Bun 1.4.4 before the long build**, from its fixed official release asset URL. The downloaded archive was checked against the release API’s published SHA-256 digest, then its SHA-512 was pinned in CI. CI verifies that hash before executing Bun. It uses bounded curl retries and fails before game import if setup is unavailable. The actual post-export security audit and its blocking exit code are unchanged. Actual-workflow bootstrap checks pass for the verified archive and reject both a corrupt archive and failed download before PATH registration. The pinned runtime ran the 47-check audit again with the same **13 pass / 0 fail / 2 manual / 32 skip** result.

## Official npm distribution, identical verified binary

The early fixed GitHub-release download also returned HTTP 504 on every attempt in run `42469074733`. Switched only the audit-runtime transport to Bun’s official **`@oven/bun-linux-x64@1.4.4`** npm package. Its metadata points to `oven-sh/bun`; the downloaded tarball matches npm’s published SHA-512 integrity, and the extracted executable is **byte-identical** to the independently verified GitHub release binary. CI pins and checks both archive and executable SHA-512 hashes before execution, extracting only `package/bin/bun` without running package-install scripts. The post-export audit remains mandatory and unchanged.

Actual-bootstrap tests pass for the verified package and reject a corrupt archive, failed download, and tampered extracted binary before PATH registration. The identical runtime’s broad audit again reports **13 pass / 0 fail / 2 manual / 32 skip**. This changes no game code or game package dependency.

## Verified official Godot asset API

Bun’s official npm bootstrap passed both hashes and its version check in production run `42469701893`. That run then hit the same HTTP 504 problem on Godot’s legacy browser-download URL. The alternate official `godotengine/godot-builds` release-asset API delivered the full editor (**50,276,070 B**) and templates (**1,073,228,327 B**); both match the original 4.3 release SHA-512 sums already used for local verification.

The workflow now uses those fixed official API asset IDs, requests binary content, and pins both SHA-512 hashes directly. A missing checksum-manifest download can no longer skip verification. An engine-version change fails until IDs/hashes are deliberately updated. Actual helper tests accept the verified original editor and reject corruption, download failure and an unpinned version. The broad audit again has zero failures. Game source and tested game artifacts remain unchanged.

## Release

Core save source `c8cc11d86be8ed2a7e2d0ce41dd899cfd5825bb4` passed [full branch CI 42458746840](https://github.com/youngstunners88/GM-GAME/actions/runs/42458746840). Combined runtime source `dd5755152b9d05a1ffa1bc26d798fd3bcffd6598` passed local release gates; later merge `748cfe3c` adds only CI export bookkeeping. Publishing through `scripts/ship-to-master.sh`; production CI/upload/public BUILD evidence pending. No physical-phone test or literal multi-day wait has been performed.
