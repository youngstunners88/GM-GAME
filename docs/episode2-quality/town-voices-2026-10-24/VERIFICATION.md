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
