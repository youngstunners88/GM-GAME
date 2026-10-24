Current result: verified live; see [RELEASE.md](RELEASE.md). Earlier packed raw-Ogg hash claims are superseded by the isolated public imported-payload audit.

# Town voice continuation verification — 2026-10-24

Status: feature-branch draft, NOT DEPLOYED. Original audio source15ed3fc6; current master434109bb integrated through mergea3fe4cec. No recordings changed or regenerated in this continuation.

## Checked

- Checksum-verified Godot4.3 stable77dcf97d8, clean native import; SCRIPT_COMPILE ALL PASS.
- Town audio: all runtime assertions pass (13actual greetings, story suppression, duel quiet, bell/go same tick, one bell per round/retry, missing-bell lock, six jail speech steps, Rich recorded playback,43dialogue +4effect duration audits). Gate exits2 for24pending recordings, never claims ALL PASS.
- Armory guns: ALL PASS.
- Gold town: jail, foul/loss/win, purchases, full entrance/queued responses, geared exit and handoff complete. One deliberate gate failure remains: seven required new sheriff takes are missing. Purchase/jail/retry budgets now use recorded durations instead of fixed short assumptions.
-47SHA256 receipt matches, all files decode, max sample peak0.88392829895<1. Exact raw Ogg final-granule checks pass. Nine positive stream timestamps explain the former differences; no tolerance relaxation. See audio-audit.json. No subjective listening or browser audible-output verdict is claimed.
- Security Sentinel18/18 after narrowly recognizing only public sha256/source_hash fields in the generated receipt. Synthetic checks confirm private_key fields and64hex literals in other files are still detected. First scan's false positive and successful rerun retained in audit-log.md.
- Founder title lock5/5 unchanged; nonthreaded export/access controls untouched. Offline bank planning works without a credential.

## Full native regression result

Normal workflow headless block ran via scripts/ci-gates-local.sh. It is not green: gold-town and town-audio gates are blocked by missing cast; three Blaze rush top-left touch assertions fail locally, alongside the three already documented pause tap-target geometry differences. Untouched master434109bb in a separate worktree reproduces the phone-portrait/tablet top-left failures (two); the phone-landscape failure did not reproduce on that rerun. Master's upstream workflow40059635704 (sourceb1227b47) is successful. Do not weaken control tests or report this as a full release pass. Full log set: work/town-voices/full-ci.log and /tmp/tmp.FMW2ei2Q1P/ (ephemeral).

## Credentials and remaining release work

Owner says at least four new ElevenLabs bindings are saved, includingELEVEN/ELEV. All-variable-name discovery, fresh shell/process, current environment-status spec5 and safe diagnostic metadata expose onlyELEVENLABS_API_KEY. No secret-file inspection or values printed. Real voices-read succeeds with historical inventory; user/subscription reads deny missing user_read. No new voice, audition, TTS or deletion calls made. The new environment containing those bindings must be attached/applied to this chat/runtime, then verify intended account/capacity and select its binding explicitly.

Three original designs and24takes remain; Rich's Episode1ID is unchanged. After recording, rerun affected/full tests, resolve local touch baseline differences, verify audible native/web output, exact export/pack/security gates, non-forced master release, actual butler upload and publicly servedBUILD. No master update/deployment/public audio claim made for this incomplete cast.


## Completed cast — current continuation

Founder supplied and approved all three design previews. Read-only account/subscription and individual voice lookups verified the new voices under their separate bindings: Utah under ELEV, Sheriff GM and Prison Sam under ELEVEN. Explicit binding selection recorded in the handoff and reusable town voice skill. No deletion or legacy fallback.

Recorded the remaining24takes; all67dialogue clips +4effects are present. All47old files hash-match, all47old receipt objects are semantically unchanged, all71files decode and match their receipts, decoded sample peak0.88392829895. `completed-cast-audit.json` retains the numeric summary. Chromium played all71assets through an analyser connected to AudioContext.destination, all nonzero (`browser-asset-audio-output.json`). This verifies asset output, not the Godot web mix graph or subjective listening to final dialogue takes. Founder approval covers the three design previews.

Current pinned Godot4.3: SCRIPT_COMPILE ALL PASS; EP2_TOWN_AUDIO ALL PASS (pending0); EP2_GOLD_TOWN ALL PASS; EP2_ARMORY_GUNS ALL PASS. Security18/18 and title lock5/5 pass. Full regression and export/release results pending; this paragraph supersedes only the missing-cast status above. No public deployment claimed.


Native mixer capture found the old +6dB announcer gain clipping normalized recorded speech (sample peak up to1.37488). Explicit recorded streams now play at unity gain; legacy root-voice calls retain+6dB. Regression assertion added. Four actual AudioManager streams (sheriff, prisoner, Utah, Rich), captured through Master AudioEffectCapture for0.7s each, now have peaks0.421–0.689. This establishes native mixer output, not hardware listening. See native-town-mix.json. After this fix pinned compile, town-audio0pending, gold-town, armory-guns and audio-buses pass again.


Resolved the previously reported local Blaze top-left touch failures: diagnostic scene-tree enumeration at(8,8) identified GameManager's offline banner background ColorRect at(6,4), size520x26, layer99, mouse_filter STOP. It appears asynchronously on connection failure, above the touch layer60, explaining environment/timing variation and untouched-master reproduction. Both banner controls now explicitly IGNORE input. Blaze touch gate deliberately shows the banner before the entire existing battery; no assertion removed or weakened. Final standalone BLAZE_RUSH_TOUCH ALL PASS, including all three top-left cases. First full run retains historical two failures before this fix; a fresh full run is queued.


Exact nonthreaded4.3export: zero script/parse errors, main198286800B below199229440B by942640B; extras60397632B. Extras presence gate passes; mounted extras pack contains all71audio files matching receipts. Browser boots and reaches actual Level1; all five engine/game/threading checks PASS. General verify-game overall FAIL is external ERR_CERT_AUTHORITY_INVALID in this Chromium profile; no bypass applied. Separate exact-export WebAudio output gate PASS: context running, BGM101 and jump128 on0–128peak scale. See exact-export-gates.txt and exact-web-audio-output.json. Automatic approval review rejected persistent proxy-CA installation as browser-wide trust beyond prior authorization; explicit approval requested, pending.


Pre-merge final source63c3fb88: full nativeCI PASS with only the runner's3existing documented pause geometry exceptions; allBlaze assertions pass, including forced-offline banner corner taps. BranchCI40065830747SUCCESS. Immediately before publishing fetched masterb34cca64: concurrentc5be58ce adds purse/shop/elevator/hideout work. Integrated throughce5910d3, preserved both town-audio and purse gates, greeting signal and shopping routines. Conflict resolution retains both STATUS entries and master's generated web page. Historical pre-merge export/test results do not validate this new merged runtime; compile rerunPASS, fullCI/exactexport/security queued/running again. Read-only public compiled-pack verification identifies existing concurrent releaseBUILD2026-10-24-c5be58c; this is NOT the new town-voice release.


## Merged release candidate ce5910d3

Preserves masterb34cca64/c5be58ce purse, elevator/hideout, walk-in shops and shopping. Full nativeCI PASS via unmodified local runner (only its3documented pause geometry exceptions); forced-offline Blaze gate ALL PASS. Compile, town-audio0pending, gold-town, armory-guns, purse, audio-buses, security18/18 and title5/5 PASS. Crowd autonomy33checks, street assets617checks PASS.

Exact production export: zero script errors; main198348336B, gate199229440B, margin881104B; extras60568768B/322files. Extras presence gate11named+89shipped PASS; all71town audio hashes match mounted pack. Native four-role output again0.421–0.689peak. Exact web BGM/jump output PASS. Browser's five engine/game checks PASS; overall verifier still FAIL due external certificate errors (retained in merged-web-verify.json). No trust bypass, no protected public town walkthrough or subjective final-take listening claim. Founder approved all3design previews.

Merged source fingerprint (runtime, tests, tools, workflow, lock and scan configuration) retained in merged-source-proof.json, enabling reuse only for identical files after a fresh master fetch. Source63c3fb88 branchCI40065830747SUCCESS is historical; merged branchCI40076803154pending. Master release, actual butler and final public BUILD pending.


# Town voices release — verified live

Runtime release: `70c5dba70f5fc4399dfb80f5babe29543397916d`, including merged master `b34cca64` / concurrent purse, elevator, hideout, walk-in shops and shoppers.

Production [workflow40077607425](https://github.com/youngstunners88/GM-GAME/actions/runs/40077607425) SUCCESS; Deploy to itch.io via butler SUCCESS. Actual upload:83.58%reused,46.14MiBfresh; Pushed to https://youngstunners88.itch.io/smokerealm. Merged featureCI40076803154SUCCESS. Master updated non-forced through ship-to-master.sh after fresh fetch and identical runtime/gate-file fingerprint checks.

Public BUILD `2026-10-24-70c5dba` read from the actual served main pack's compiled GameManager; directory MD5 validated before accepting the string. Public main pack198313680B, below199229440B by915760B. Public extras60568032B. Public iframe:https://html-classic.itch.zone/html/18305533-2199698/index.html?v=1792831220. Normally validated HTTPS; no Chromium trust change or certificate bypass.

**Correction to earlier packed-hash claims:** the earlier local FileAccess raw-Ogg hash check could fall back to source files, because the pack carries imported Vorbis resources rather than raw Ogg containers. It did not establish packed-byte equality. Final public-pack audit uses a separate minimal Godot4.3 project, with ONLY the downloaded public extras pack mounted and raw source Oggs asserted absent. All71imported streams load; length-prefixed encoded Vorbis packet SHA256 matches packets extracted from the original receipt-matching Oggs, and every engine duration matches receipt seconds+start_seconds within0.00005s.71recordings,0failures. This supersedes all earlier raw packed-hash assertions; no tolerance was relaxed and no take regenerated.

All67dialogue +4effects complete;47preserved source files and receipt objects unchanged. Utah, SheriffGM and PrisonSam are founder-created originals; founder approved their design previews. Rich retains Episode1LNV6ahDtkAOqwn1X3R7a. Bell alone opens draw window, with recorded sheriff instructions. Native full merged suite PASS using existing runner's3documented local pause geometry exceptions. Compile/town0pending/gold-town/armory/purse/audio-buses/security18/title5PASS. Forced-offline Blaze batteryPASS, including all3top-left cases. Exact local export has0script errors, main198348336B,extras60568768B.

Native recorded-role mix output verified0.421–0.689peak after removing legacy+6dB boost ONLY for explicit normalized recorded streams. Legacy voice gain unchanged. Chromium all71raw assets produce output; merged exact-export BGM/jump outputPASS. Browser's5engine/game/thread checksPASS, but overall generic verifierFAIL from external ERR_CERT_AUTHORITY_INVALID. Automatic approval review rejected persistent Chromium proxy-CA installation because it changes browser-wide TLS trust outside prior authorization; requested approval was not explicitly supplied, so trust remains unchanged. Public BUILD and audio payloads instead verified with normally validated HTTPS and isolated Godot. No protected public town playthrough or subjective listening verdict on final takes is claimed.

Prisoner image reviewed from mergedCI40076803154actual gameplay camera: founder prisoner remains behind bars; screenshot is visual evidence only, not speech/audio proof.
