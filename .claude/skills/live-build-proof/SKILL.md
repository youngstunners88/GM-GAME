---
name: live-build-proof
description: Standard for what "FIXED" is allowed to mean when a founder reports something broken in the LIVE build. A prior session claimed R2/R3/R4 fixed with a probe that only checked data in a dictionary — the founder correctly rejected it because live play still failed. Use whenever asked "is this actually fixed", before writing FIXED in STATUS/a commit, or when a founder says "still broken" after a prior FIXED claim.
user-invocable: true
allowed-tools: Read, Bash, Grep
---

# Live Build Proof

## The failure this exists to prevent

A session proved a Blaze Rush entry/exit fix by asserting
`GameManager.dash_return["level_index"] == 2` — true, but it never drove the
actual scene transition, the actual finish/ESC handler, or the actual
respawn. The founder played the real build and it was still broken. The
"FIXED" label was revoked and the founder explicitly banned "probe-only"
proof for this class of bug going forward. This skill is that ban, written
down so it survives to future sessions.

## The proof ladder — climb it in order, don't skip to the top

1. **Data check** (e.g. "the dict has the right key") — NEVER sufficient
   alone for a "still broken live" report. Useful only as a first sanity
   check before doing the real proof below.
2. **In-engine end-to-end proof** — drive the REAL code path: the actual
   scene load (`SceneRouter.load_scene`, awaiting `load_finished`), the
   actual handler function (not a reimplementation of its logic), asserting
   the resulting `current_scene`, node state, or player position after the
   real transition completes. This is the minimum bar for writing "FIXED" in
   response to a founder-reported live bug. See
   `docs/session-logs/2026-08-08b-blaze-rush-e2e-and-wipe.md` for a worked
   example (a probe that hands `current_scene` to a decoy node so it
   survives SceneRouter's scene-swap, then calls the real `_finish_run()`
   and `_exit_to_level()` and asserts the outcome).
3. **Live-channel confirmation** — even a correct end-to-end in-engine proof
   does NOT mean the founder will see it. Check which build they're
   actually playing (see "Live channel awareness" below) before declaring
   victory. A correct fix on an undeployed branch is invisible to a live
   playtest, and reporting it as "fixed" without this check is exactly the
   mistake that triggered the founder's ban.
4. **Founder playtest confirmation** — the actual, only real gate for
   declaring a feature/episode "done." Nothing an agent proves substitutes
   for this. Say so explicitly in STATUS rather than implying completion.

## Live channel awareness (mandatory before claiming "fixed" for a live report)

Before writing FIXED for anything the founder describes as a LIVE
observation (not a code review), check:

1. **Is this commit even deployed?** Run `itch-butler-deploy` Step 1/2 to
   check whether CI's auto-deploy is wired (repo secret) and/or whether a
   manual deploy has happened since this fix landed. If neither, the
   founder is playing old code — say that plainly instead of re-diagnosing
   the "bug."
2. **Is this commit merged/on the branch they're testing?** A fix living
   only on an unmerged PR branch that never got exported+deployed is not
   "live" by any definition. State the branch and whether it was deployed.
3. **When was the last deploy, and does it postdate this fix?** If you (or
   a prior session) deployed a build, name the build id/version and confirm
   this fix's commit is included in that deploy, not just "recently
   committed."

If any of these are unclear or negative, the honest STATUS entry is
**"code fixed and proven end-to-end; NOT YET on a build the founder can
play — here's what's needed to get it there,"** never a bare "FIXED."

## Writing the STATUS/commit claim

Required shape for a founder-reported live defect:

- `FIXED` + the specific end-to-end proof (what was driven, what was
  asserted, what the before/after states were) + live-channel status
  (deployed / not yet / how to deploy).
- or `STILL BROKEN` + the exact failing function/branch + why the previous
  fix attempt didn't cover it.

Never write "should be fixed," "this looks correct," or a proof summary
that only describes reading the code. If Fable/Kimi/another model produced
the proof, verify it was checking the real handler, not a description of
what the handler is supposed to do.

## Fighting context bloat

Load `game-flow` alongside this skill for the game's actual state-machine
rules (see its Founder overrides section) rather than re-deriving Blaze
Rush / death / Continue behavior from scratch each time. Do not load the
entire skill library to investigate one reported defect — this skill plus
`game-flow` is normally sufficient; add `game-development` only if the
suspected root cause is CI/export/gates, not gameplay logic.
