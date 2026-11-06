---
name: parallel-session-build
description: How to run more than one builder on GM Game without them breaking each other - when a second Claude Code session, subagent or other model (opencode, DeepSeek) is worth it, one job per worktree and branch, one lead who reviews and ships, handoffs that survive a cold start, and what to do when someone else's edits appear in your tree. TRIGGER on "start another session", "new terminal", "parallel", "subagent", "orchestrator", "hand this off", "another model is working on", "rate limit, continue elsewhere", or files changing in git status that you did not touch.
---

# Building in parallel

More sessions give more **parallel work, not deeper thinking**. It is the same model in every terminal, and each new session starts cold, knowing only what it is told. Use them to do separate jobs at once, never to make one hard job "deeper". A hard job goes to one session on a stronger model or higher effort.

## Which tool
| Situation | Use |
|---|---|
| One job, even a hard one | This session |
| A large search, or an independent check of finished work | A subagent (`Agent`, with `isolation: "worktree"` if it writes) |
| Separate features that touch different files | A second session in its own worktree |
| A scripted, unattended run | `claude -p "<brief>"` in another terminal or tmux pane |
| Scanning a lot of logs, frames or diffs | A cheap model (see MODEL ROLE SPLIT in `CLAUDE.md`). Its output is a lead, not a fact |
| Gates or captures too slow for the laptop | `ep2-runpod-gate-pod` |

The `claude-code-orchestrator` MCP tools can also start workers. They were not tried when this was written, so prove them on a small job first.

## The rules
1. **One writer per worktree.** Never point two agents at one tree. Before starting, close the old agent and confirm no process has that directory as its working directory.
2. **One job per branch.** Name which files the job owns and which it must not touch. If two jobs need the same file, run them one after the other.
3. **One lead.** Workers build. One session reviews the diffs and ships. Treat a worker's "done" as a claim to verify.
4. **Everyone merges `origin/master` before shipping** and keeps both sides of a conflict (`CLAUDE.md`, PARALLEL-SESSION RULE).
5. **Three or four is a practical ceiling on this laptop.** Godot runs compete for CPU and can trip timing-sensitive gates. Wrap `--import` and exports in `flock /tmp/gm-godot.lock`.

## When someone else's edits appear in your tree
Happened 2026-11-05: another agent's half-finished scripts landed in a worktree while its ship gates ran, and the gates failed on classes it had never touched.
1. **Stop and look.** Run `git status --short` and check timestamps. If you did not write it, it is not yours.
2. **Never commit, reset, stash or clean it.** It may be the only copy.
3. **To ship your own committed work,** make a clean worktree from your commit and ship from there:
   ```bash
   git worktree add -b claude/ship-<topic> .claude/worktrees/ship-<topic> <your-commit>
   ln -s "$PWD/.godot-cache" .claude/worktrees/ship-<topic>/.godot-cache
   ```
   Run `--import` there first, because a fresh tree has no `.godot` cache.
4. **Tell the founder,** naming the files and what you left alone.

## A handoff that survives a cold start
Give the next session the original brief **and** this. A session can read files, but it cannot read another session's conversation.
- **Goal:** the definition of done, in the founder's terms.
- **Where:** worktree, branch, HEAD.
- **State:** done, in progress and never run, kept separate. Label unverified work as unverified.
- **Known problems:** exact errors and files, to re-check rather than trust.
- **Boundaries:** what it must not touch, and who owns that.
- **Traps:** the pinned Godot binary, the pack margin, secrets.
- **Finish line:** what to run, how to ship, and what to report.

## Limits
Starting more sessions costs more tokens, because each re-reads its context (`token-efficiency`). Never start one just to look busy, or because a task sounds big. Spawning is the expensive path: the job has to be big enough and separate enough to pay for it.
