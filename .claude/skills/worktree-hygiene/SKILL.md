---
name: worktree-hygiene
description: Keep GM Game's git worktrees and working trees clean - audit how many worktrees exist and what each holds, tell what is safe to remove, keep stray generated files and scratch output out of commits, and leave a tree tidy at the end of a session. Read-only by default; removing anything needs the founder's say-so. TRIGGER on "dirt in the worktree", "too many worktrees", "clean up", "disk space", "stale branches", stray files in git status, or at the end of a session that created a worktree.
---

# Worktree hygiene

Measured 2026-11-05: **27 worktrees using 8.4 GB** under `.claude/worktrees`. Each one holds its own `.godot` cache and assets. Dirt also costs tokens: a noisy `git status` gets read every session, and stray files get committed by accident.

## Audit first (read-only)
```bash
bash scripts/worktree-audit.sh
```
For each worktree it prints the branch, uncommitted files, commits not on master, the last commit's age and the size. It deletes nothing.

## What may be removed
| Audit shows | Meaning | Action |
|---|---|---|
| `dirty 0`, `unmerged 0` | Everything in it is on master | Candidate: list it for the founder |
| `dirty` above 0 | Uncommitted work, possibly the only copy | Leave it. Report it |
| `unmerged` above 0 | Commits not on master | Leave it. Report it |
| Recent activity, whatever the numbers | Another session may be working there | Leave it |

**Rules:**
- Removing a worktree needs the founder's approval, and never one a live session may be using.
- Use `git worktree remove <path>`, which refuses a dirty tree. **Never use `--force`**, and never `rm -rf` a worktree.
- Never delete an unmerged branch. A worktree you made yourself in this session, once merged, is yours to remove.

## Keeping dirt out of a tree
- **Scratch goes in `.farm/`** (git-ignored) or the session scratchpad: raw generations, reference renders, test captures, logs.
- **Stage by name or by folder,** never a blind `git add -A` at the repo root. Read `git status --short` before each commit.
- **Godot's generated files:** a replaced GLB leaves its old extracted textures behind (`<model>_Image_0.jpg` and their `.import` files). Remove the orphans in the same commit. New `.import` files need `git add -f`.
- **Wrong engine noise:** a mass change to `.import` files usually means the 4.7 binary ran. Revert those, and use `.godot-cache/Godot_v4.3-stable_linux.x86_64`.
- **Other people's files:** if you did not write it, do not commit, clean or stash it (`parallel-session-build`).
- **Captures:** commit only the few frames that prove something, under `docs/captures/<topic>/`, and leave the rest in `.farm/`.

## End of a session
1. `git status --short` shows only what you meant to leave.
2. Your work is committed and pushed.
3. Any worktree you made, once merged, is removed: `git worktree remove <path>`.
4. Your report names anything you left behind, and why.
