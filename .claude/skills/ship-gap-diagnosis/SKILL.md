---
name: ship-gap-diagnosis
description: "The founder says X is missing from the live game but the code is on master" - find out whether it is not deployed, not in the export, streamed and failing to mount, not wired into the player flow, or sitting on an unmerged branch. TRIGGER on "it's not live", "I don't see it", "you said it shipped", "town people/windows/lake/Rich/Utah missing", stale links, or before telling the founder a feature is or is not live.
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash
---

# Ship-gap diagnosis (code on master != what players get)

Work top to bottom; stop at the first layer that explains the symptom. Every claim needs a SHA, run id or probe line. `gh` IS installed and logged in here (do not assume the GitHub MCP is the only route).

## 1. Is the branch you are on even current? (the 2026-10-20 trap)
```bash
git fetch origin && git rev-list --left-right --count HEAD...origin/master      # "0 50" = 50 behind: you are looking at an old tree
git worktree list                                                               # sibling worktrees hold other sessions' work: never clobber
for b in $(git branch -a --format='%(refname:short)'); do echo "$(git rev-list --count origin/master..$b) ahead  $b"; done | sort -rn | head
git log --all --oneline -S"<symbol>" -- src                                     # where did the feature land?
```
A branch "0 ahead" is already merged. Only branches that are ahead hold unmerged work; read `git diff --stat origin/master...<branch>`, do not merge blind.

## 2. Did master's CI deploy it?
```bash
gh run list --workflow export-game.yml --branch master --limit 8 --json databaseId,headSha,status,conclusion,displayTitle
gh run view <id> --json jobs --jq '.jobs[].steps[]|[.number,.name,.conclusion]|@tsv'     # "Deploy to itch.io via butler" must be success, not skipped
gh run view <id> --log | grep -E "Pushed to|Re-used|Pushing"                               # butler's proof line
```
Master's newest commit is usually the bot's `build: export Godot 4.3 game to web` (no workflow run of its own) - compare the **last workflow run's head_sha** with the commit that carries your change (`git merge-base --is-ancestor <sha> <head_sha>`). Known skip causes: dirty tree after Godot 4.3 rewrote `.import` files (use 4.3-format imports), stamped `game_manager.gd`, rebase races, gitleaks, a red test before butler.

## 3. Does the live page serve that commit, and do the streamed extras mount?
```bash
node scripts/live-itch-probe.mjs --expect <short sha> --extras --logan     # real Chromium on the public itch page; exit 0 only if all PASS
```
It prints `[BUILD]` (the commit the players run), `[EP2] extras ready`, the extras HTTP status and Logan's bones/clips. `WAIT` (exit 2) = itch still extracting the upload.

## 4. Is it inside the packs? (streamed extras)
New Episode 2 art lives in `src/episode2/extras/` -> **ep2_extras.pck**, NOT in `index.pck`; the game downloads it at Episode 2 start and every caller keeps an old-asset fallback (`Ep2Extras.has(path)`). A missing/failed pack therefore looks exactly like "the feature was never built" (old kit, no people, puppet Rich/Utah). Gate: `bash scripts/check-ep2-extras-pack.sh web/game` (CI runs it). Also check `.import` drift: `git status` after a headless import must be clean.

## 5. Is it wired into the player flow?
Episode 2 is behind an access code, then woods -> town (gold_town beats: Sheriff, saloon draw, jail, Armory tip, Armory, GEARED) -> `next_chamber: logans_lake`. The lake is only reached at the END of the town beats; `?ep2=1&ep2chamber=lake` (and `ep2lakeprobe=1`) warp straight to it for QA. "Not reachable" often means "the founder did not finish the town beats".

## 6. Only then: is it unbuilt?
No hits in `git log --all -S` and no spec in `design/ lore/ docs/ PROMPT_*.md` = ask the founder one precise question (see Gail, 2026-10-20: zero references anywhere in any branch).

Report each symptom as FIXED+LIVE (probe line), FIXED+DEPLOYING, or BLOCKED (why, what is needed).
