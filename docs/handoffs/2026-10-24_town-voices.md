# Town voices / ElevenLabs — session handoff, 2026-10-24

## User request and authorization

Run `npx -y @elevenlabs/cli@latest onboard init` and add ElevenLabs to GM-GAME. Give the townspeople voices; create a NEW thick Western Utah voice, a NEW higher-pitched Western voice for the man behind bars (user explicitly clarified prisoner, not a jail guard), and a NEW distinct/unused sheriff voice. Reuse Rich's Episode1 voice so he converses with Lil Blunt. Add town sounds. The town bell is the sole draw signal, and the sheriff tells both men to listen for the bell.

The user added new ElevenLabs keys in environment variables and explicitly requested a fresh Codex session because this one still reached the old account/limit. **No voice deletion was approved. Do not delete Builder Chick, Moa, Irish Spartan or any other voice.** No voices have been deleted.

Standing authorization in AGENTS.md permits ordinary GM-GAME commit/push/nonforced master release. Preserve concurrent work. Do not deploy this incomplete draft.

## Checkout / source

Repository `/workspace/GM-GAME`; feature branch `codex/town-voices-20261024`, based on freshly fetched master `b56d87900ea61658a3f9713749f06e2966b2990e` (includes Claude's mobile/transition and pack-headroom work). Previous Transition2 work remains shipped. Read AGENTS.md, CLAUDE.md, default context manifest and resume/ship skills. Refresh remote before subsequent work.

## Credentials / ElevenLabs state

- CLI onboarding executed. Installed `@elevenlabs/elevenlabs-js`; package + lock changed. Latest onboarding check confirms SDK declared/imported and credential works. No key is stored in source. `.env.local` is absent; do not ask for a key in chat or print credential values.
- Active environment status advanced from spec21 to spec22, observations current. It exposed only `ELEVENLABS_API_KEY`. Calls still returned `voice_limit_reached`, maximum custom voices10/10, even after the update. New session must discover the NEW available bindings by name only and use the intended new account/workspace; verify with actual API responses. API credit and saved custom-voice-slot limits are different. Do not rely on placeholder/fingerprint comparisons to establish freshness.
- `scripts/elevenlabs-client.mjs` currently aliases `ELEVENLABS_API` over `_API_KEY` if present, following the old project convention. With fresh keys, deliberately select the intended binding and avoid silently overriding a new key with a legacy one.
- Old account contains Rich voice `LNV6ahDtkAOqwn1X3R7a` and Lil Blunt `HMGfKwZCRujgXyRDUW0b`. Rich must keep that identity. Already recorded Rich takes can be reused even if the new account cannot generate them.
- Designed3 auditions per new character successfully (9 previews), but saving ALL3 failed from the10/10 limit. No persistent new voices were created. Original generic prompts/seeds and selected indices are preserved in `assets/town-voice-designs.json`. In this workspace, raw responses/auditions and acoustic metrics are under ignored `work/town-voices/design/`.
- Selected auditions: Utah2 (~102Hz median F0, slow leathery drawl), prisoner1 (~229Hz, higher adult tenor), sheriff2 (~126Hz coppery baritone). Metrics are algorithmic estimates, not claims of a subjective listening verdict. Fresh-account preview IDs may need regeneration.
- CLI design uses `--json -` for request body and `--output-format mp3_44100_128` as a separate flag; output_format is a QUERY parameter and fails schema validation in body JSON. Save via `text-to-voice create` with generated_voice_id, voice_name and voice_description. Capture responses to files; do not print base64 audio.
- An initial automatic approval rejection concerned sending alleged private story dialogue. Read-only GitHub metadata verified this repo PUBLIC (`private:false`), and auditions were replaced with newly written generic text. Subsequent design/TTS/SFX calls were accepted. No remaining automatic-approval block; the outstanding error is the provider voice-slot limit.

## Work completed in draft

- `assets/town-audio.json`: cast +67 story/greeting lines, all13 public figures (2 greetings each), Rich/LilBlunt exchange, existing armory introduction verbatim, jail exchange, new sheriff bell instructions;4SFX prompts.
- `scripts/elevenlabs-client.mjs`, `scripts/generate-town-audio.mjs`: official SDK, environment-only credentials, bounded generation with source-hash receipts, raw-audio cache, normalized/limited monoOgg, generated runtime bank. No API key or live ElevenLabs request is needed by the shipped browser game.
- **43 spoken clips +4SFX generated** (47 Ogg files) in `src/episode2/extras/audio/town/` so the main pack stays small. Rich reuses his Episode1 voice. Other13 townspeople use available suitable character voices. Metadata/hashes/lengths: `assets/town-audio-generated.json`. Raw originals are in ignored `work/town-voices/recordings/` (may not persist between machines).
- Utah, prisoner and sheriff voice_id fields remain NULL; **24 takes pending**. Set only after actual successful voice creation. Regenerate only those roles; keep existing Rich identity/takes.
-4effects: looping town breeze, looping saloon murmur, boardwalk boots, single town draw bell. No bell in ordinary ambience. Effects processed locally after quiet-loop/trimming issue; source audio reused without extra generation. Current decoded maximum sample peak across47files ~0.794, avoiding clipping. Bell onset measured at0ms; loop durations preserved16/14sec, boots~0.62sec, bell~4sec.
- `src/episode2/audio/town_voice_bank.gd` generated67entries with ready flags, text, speaker, path, ffprobe seconds.
- `town_soundscape.gd`: silent until activation, spatial saloon/boots/greetings, one greeting slot and cooldown, story/duel suppress chatter and lower ambience, sole bell player/counter, queued purchase remarks.
- `Ep2TownPeople.greeted` signal connects the existing greeting animation to actual voice. No AI/save/economy changes.
- `AudioManager.play_voice(name, recorded_stream=null)` optional stream supports extra-pack audio while retaining existing single voice slot/music duck. Other callers unchanged.
- GoldTown uses new cast for sheriff, real jail speech holds, voiced Rich/LilBlunt entrance, recorded armory lines, queued purchase responses, voiced departure. New sheriff says listen for bell. GO changes only after successful bell play; no `vo_sheriff_draw` speech signal. Missing bell never silently opens firing window.
- ArmoryIntro gets optional recorded-duration callback; current sentence completes before yielding the bought/geared exit. Prices/currency/acquisitions unchanged.

## Verification / unfinished issues

- Pinned Godot4.3 import and SCRIPT_COMPILE passed before final test additions; rerun compile after edits.
- New `tests/ep2_town_audio_test.{gd,tscn}` exercises all13 actual greetings, priority/suppression, bell tick/one per round/retry/missing-bell guard, all6 jail speech holds, actual Rich playback/long-line timing, packaged-file timing/readiness.
- Latest new test result: **3 runtime audit failures +24 pending takes**. Failures are timing comparisons for oldtimer0/lady0/grandfather1: Godot4.3 `AudioStreamOggVorbis.get_length()` reports~0.084–0.089s more than ffprobe, while threshold is0.08. Investigate/use engine playback duration for sequencing and make the audit accurately distinguish Ogg padding; do not blindly claim pass or relax unexplained failures. All other exercised cue/greeting/Rich checks passed.
- Existing gold-town test has one assertion updated from spoken Draw to bell count; remaining old spoken-signal labels/list and fixed timing bounds need review. Existing armory-guns test now waits the recorded entrance duration before intro; not fully rerun yet.
- Added CI town-audio gate beside gold-town gate. It MUST fail until all67 takes are present/ready. Do not publish this partial cast.
- Full CI, asset presence/pack gates, native/audio/player-camera and web audible-output checks, new exact-source export, master release/butler/public BUILD still required.
- Current main pack at baseline198094432B; threshold199229440B. New recordings intentionally stream in extras. Preserve nonthreaded4.3, title/access locks, recent mobile controls and concurrent work.
- Listen/audition the actual voices/effects where supported; don't claim an ear verdict solely from pitch/peak measurements. The current local Browser plugin's js control wasn't exposed, so CLI/API were used. Follow Browser skill if new session has connected browser control.

## Next actions

1. Fresh environment/key discovery; use user's NEW keys and actual provider capacity. No voice deletion.
2. Save/create3 original voices, readback IDs, populate cast; generate24 pending takes via SDK; rerun generator bank. Preserve Rich ID.
3. Fix engine-duration audit and finish story/bell tests and dialogue arbitration. Add reusable town voice/bell skill + routing and update old UNVOICED docs/quickdraw convention.
4. Complete appropriate native/audio/web/pack/security/fullCI checks. Update source/capture receipts and Obsidian work log.
5. Commit/push/nonforced master with existing ship workflow, verify actual upload and publicly served BUILD. Report actual tested scope; don't claim a protected public playthrough without performing it.


## Fresh-session continuation (2026-10-24; supersedes the padding hypothesis)

Checked out exact `15ed3fc6` and merged observed master `434109bb` (merge `a3fe4cec`), preserving the concurrent wanted posters and jail privy. Available credential binding names include only `ELEVENLABS_API_KEY` for ElevenLabs. Used that binding directly, never the legacy alias. Actual `/v1/voices` succeeds and lists the same historical custom cast plus Rich. `/v1/user` and `/v1/user/subscription` both return HTTP401 `missing_permissions` / `user_read`. This is NOT account verification or proof of current slot capacity. Asked the owner to enable `user_read` on the intended key and identify the intended account/workspace. No response yet; no new audition, saved voice, TTS, or deletion was attempted in this session.

`elevenlabs-client.mjs` now explicitly selects `ELEVENLABS_API_KEY`; alternate bindings require `ELEVENLABS_KEY_BINDING`. No silent alias override. Offline `--plan` and bank generation do not require credentials.

Timing cause measured: nine Ogg files have a positive initial timestamp, up to 0.088958 seconds. Godot 4.3 `AudioStreamOggVorbis.get_length()` delegates to `OggPacketSequence.get_length()` = final page granule / sampling rate. ffprobe reports that value MINUS the positive stream start timestamp. This reproduces with direct `load_from_file` and clean imports; it is NOT stale import padding. Earlier exploratory cache diagnosis was incorrect. Receipts and generated bank now retain `start_seconds`; tests require engine length = receipt seconds + start_seconds within 0.00005 seconds. Sequencing uses actual engine stream length plus the existing 0.25-second gap. No recordings were changed.

All47 SHA256 hashes match the handoff source. All47 decode, maximum decoded sample peak0.883928 (<1); this is numeric verification, not a listening verdict. Corrected stale effect duration metadata only: boardwalk0.619932s, bell3.999002s. The43 dialogue receipts are unchanged except for added initial timestamps. Raw granule/offset evidence: `docs/episode2-quality/town-voices-2026-10-24/audio-audit.json`.

Pinned Godot4.3 checksum verified, clean imported after replacing incompatible inherited cache. SCRIPT_COMPILE passes. Town audio runtime test passes all exercised assertions and remains correctly BLOCKED with24 pending recordings; no timing assertion failures. Armory-guns test ALL PASS. Gold-town gate now checks the replacement bank instead of accepting retired sheriff clips, omits spoken Draw from the required list, and budgets retry/jail/purchase speech from actual stream durations. Final gold-town/fullCI results are recorded in the verification receipt alongside this handoff.

New reusable skill `.agents/skills/ep2-town-voices/SKILL.md` and default-manifest route added. Quickdraw/sheriff guidance now names the town bell as the sole signal. Completed takes, Rich identity, gameplay/access controls and title lock preserved. Credential verification, three custom voices,24 recordings, subjective/audio-output review, final export/pack/release gates and master/publicBUILD remain outstanding. Do not deploy this incomplete cast.

Owner clarified new bindings are named `ELEVEN`, `ELEV`, and others. Rechecked ALL process variable NAMES (not values), then fresh process plus environment-status spec3/current/enforced/ready: none of those shorter names are exposed; only ELEVENLABS_API_KEY remains. Fresh `/v1/user` again HTTP401 missing user_read. The additional keys need applying to this attached environment. Credential selector accepts explicitly chosen short binding names too; no legacy fallback.

Final native results: gold-town has only the expected missing new sheriff recordings failure; full headless block has cast gates plus local Blaze top-left touch failures (two reproduced on unchanged434109bb; one did not reproduce), and documented pause geometry differences. Security18/18 and title5/5 pass. Details: `docs/episode2-quality/town-voices-2026-10-24/VERIFICATION.md`. Effect receipt generator now writes actual measured duration AFTER spreading requested source fields, so requested effect seconds cannot overwrite decoded duration again.

## Founder-created cast and recording continuation

Fresh attached runtime exposes `ELEVEN`, `ELEV`, and `ELEVENLABS_API_KEY` (all process binding names inspected, no values printed). After owner updated permissions, account/subscription reads succeed for the two short bindings. ELEVEN: user `user_6901kdy3h0xzefmbps5kymw14ccq`, free tier, three slots, initially zero custom voices. ELEV: user `hqKufwP44OPvXY6127Q3HZpyjXY2`, free tier, three slots. Voice design through API returned403 feature_unavailable because it requires a paid plan. Owner created originals in the UI and supplied IDs; owner explicitly approved all three preview voices in chat.

Verified each voice with read-only API: Utah `LeIvuXkiWRYkY1ThkAdG` is accessible under ELEV; Sheriff GM `zskPkJFpKt6Fq5Aouk0g` and Prison Sam `D7R0fmiEU45c9y4irVok` under ELEVEN. Both accounts have enough characters. Explicit ELEVENLABS_KEY_BINDING selection per recording run; no legacy fallback and no deletions. Recorded12Utah lines (759characters) under ELEV,12sheriff/prisoner lines (941characters) under ELEVEN. Node24 requires NODE_USE_ENV_PROXY=1; first direct SDK fetch failed before any recording, retry via inherited proxy succeeded. Raw originals/source receipts kept locally under ignored work/town-voices/.

All67dialogue +4effects now exist. All47preserved files AND receipt objects remain unchanged semantically; only JSON number formatting differs.71files match SHA256 receipts and decode; max decoded peak0.88392829895. Chromium independently plays all71Ogg assets through an analyser connected to AudioContext.destination; all show nonzero output. This is browser asset-output evidence, NOT subjective listening to final takes or a Godot web/public town playthrough. Founder approved design previews; no invented listening verdict. Evidence: completed-cast-audit.json and browser-asset-audio-output.json in town quality directory.

Checksum-verified4.3editor/templates downloaded; discarded inherited incompatible4.6cache and clean imported with writable XDG paths. Pinned SCRIPT_COMPILE passes; EP2_TOWN_AUDIO ALL PASS with0pending recordings. Front-page lock5/5 and Security Sentinel18/18 pass. Remaining gold-town/armory/full regression, exact export/pack and release results must be recorded after completion; no deployment yet.


Resolved the previously reported local Blaze top-left touch failures: diagnostic scene-tree enumeration at(8,8) identified GameManager's offline banner background ColorRect at(6,4), size520x26, layer99, mouse_filter STOP. It appears asynchronously on connection failure, above the touch layer60, explaining environment/timing variation and untouched-master reproduction. Both banner controls now explicitly IGNORE input. Blaze touch gate deliberately shows the banner before the entire existing battery; no assertion removed or weakened. Final standalone BLAZE_RUSH_TOUCH ALL PASS, including all three top-left cases. First full run retains historical two failures before this fix; a fresh full run is queued.


## Merged release candidate ce5910d3

Preserves masterb34cca64/c5be58ce purse, elevator/hideout, walk-in shops and shopping. Full nativeCI PASS via unmodified local runner (only its3documented pause geometry exceptions); forced-offline Blaze gate ALL PASS. Compile, town-audio0pending, gold-town, armory-guns, purse, audio-buses, security18/18 and title5/5 PASS. Crowd autonomy33checks, street assets617checks PASS.

Exact production export: zero script errors; main198348336B, gate199229440B, margin881104B; extras60568768B/322files. Extras presence gate11named+89shipped PASS; all71town audio hashes match mounted pack. Native four-role output again0.421–0.689peak. Exact web BGM/jump output PASS. Browser's five engine/game checks PASS; overall verifier still FAIL due external certificate errors (retained in merged-web-verify.json). No trust bypass, no protected public town walkthrough or subjective final-take listening claim. Founder approved all3design previews.

Merged source fingerprint (runtime, tests, tools, workflow, lock and scan configuration) retained in merged-source-proof.json, enabling reuse only for identical files after a fresh master fetch. Source63c3fb88 branchCI40065830747SUCCESS is historical; merged branchCI40076803154pending. Master release, actual butler and final public BUILD pending.
