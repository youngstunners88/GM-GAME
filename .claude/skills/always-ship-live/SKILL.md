---
name: always-ship-live
description: END-OF-TURN GATE for every change to the game. Commit, push, ship to master, prove master's CI deployed to the CURRENT itch page, and never report "done" or "live" before that proof. TRIGGER at the end of EVERY turn that touched the repo, whenever the founder says "ship", "you didn't ship/commit", "the URL changed", "is it live", or complains about stale links; also before writing any itch/deploy URL anywhere.
---

# Why this exists
Founder 2026-10-01, furious: "You didn't ship and commit!!! You must ALWAYS ship!!! The URL has changed!!!"
The work HAD shipped, but the turn ended without the founder seeing proof, STATUS still linked a dead page
(`lil-blunt-adventure`), and "shipped to master" was reported instead of "live". From his side that is the same as not
shipping. This skill makes the proof part of the work.

# The one source of truth for the URL
`CLAUDE.md` -> Deployment, and `ITCH_TARGET` in `.github/workflows/export-game.yml`
(currently https://youngstunners88.itch.io/smokerealm, butler `youngstunners88/smokerealm:html5`).
Run `bash scripts/ship-check.sh` first: it prints the live URL from the workflow and FAILS if any tracked file outside
history/prompt archives still names a retired slug. Never type an itch URL from memory; copy it from the script output.
When the founder changes the URL: update `ITCH_TARGET`, CLAUDE.md, STATUS.md header, `docs/SOCIAL_LINKS.md`, then add the
old slug to `RETIRED_SLUGS` in `scripts/ship-check.sh` in the same commit.

# The end-of-turn sequence (every turn that changed a file, no exceptions, no asking)
1. `bash scripts/ship-check.sh` (uncommitted files, unpushed commits, behind master, stale URLs).
2. Update `STATUS.md` (what changed, what is next) and commit with a real message.
3. `git push -u origin <branch>`; retry on network errors only.
4. `bash scripts/ship-to-master.sh`. On a merge conflict keep BOTH sessions' work (CLAUDE.md parallel-session rule);
   built files (`web/game/index.html`) take master's version, STATUS.md keeps both entries. A stale class cache
   ("Identifier X not declared") is `godot --headless --editor --quit`, not a code bug.
5. PROVE IT LIVE with the GitHub MCP (no `gh` CLI exists): `actions_list list_workflow_runs export-game.yml
   branch=master` -> the run whose `head_sha` is the shipped commit must be `completed/success`; then
   `actions_list list_workflow_jobs <run_id>` -> step "Deploy to itch.io via butler" must be `success`;
   `get_job_logs` tail must say "Pushed to https://youngstunners88.itch.io/smokerealm". A CI run takes ~8-10 min: if it is
   still `in_progress`, say "deploying", never "live", and check again (ScheduleWakeup/send_later) instead of ending silent.
6. Tell the founder in two lines: the URL, the commit, and "deploy confirmed" or "deploying, will confirm".
   Include the build tag, and "hard refresh".

# Words you may not use without the proof
"live", "deployed", "shipped" (to the founder). Before step 5 the honest words are "pushed" and "merged to master".

# Related traps this rule also covers
- Authorised spend is authorised: when the founder has said "spend what we have" (Meshy, ElevenLabs, OpenRouter), do
  not ask again; check the balance, spend, report the total.
- "The keys / the code" in Episode 2 means keyboard+mouse controls (skill `ep2-free-roam-controls`) and the access
  gate, never an API key. Do not ask which one.
- The web pack must stay under the CI gate (190 MiB). If a new asset breaks it, exclude dev folders or shrink
  assets BEFORE shipping; a red master build never deploys. Check with `bash scripts/ep2-local-export.sh`.
- One commit per turn is fine; zero is not. The Stop hook is a backstop, not the plan.
