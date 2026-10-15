---
name: context-md-upkeep
description: Keep the workspace CONTEXT.md files (design/, assets/, src/, docs/) and CLAUDE.md's routing table true - the founder's coach's layered-MD method ("The Lesson 3.1": CLAUDE.md routes, one CONTEXT.md per workspace, skills plug in where needed; context files are living working notes). TRIGGER at the end of any task that changed where something lives, added a pipeline/tool/rule, or when a CONTEXT.md / routing row is found wrong; also when the founder sends a setup/toolkit doc.
user-invocable: true
allowed-tools: Read, Edit, Write, Grep, Glob, Bash
---

# Context MD upkeep (founder 2026-10-10: "the approach to MD files which I want us to implement and develop skills to update")

## The three layers (coach, Lesson 3.1 - the layers never change, the labels do)
1. `CLAUDE.md` (root): identity + ROUTING table (task -> workspace -> what to read -> skills). One row per kind of task.
2. One `CONTEXT.md` per workspace, under a page: what happens there, the process, the files, what good work looks like.
   `design/CONTEXT.md`, `assets/CONTEXT.md`, `src/CONTEXT.md`, `docs/CONTEXT.md`.
3. Skills (`.claude/skills/*/SKILL.md`) plug in from the routing table's Skills column.

## When to edit (same commit as the change)
- A file moved / a new system file exists -> the "where things are" table in that workspace's CONTEXT.md.
- A new pipeline, tool or CLI -> `assets/CONTEXT.md` pipelines table and `gm-game-tool-roster`.
- A founder rule ("realism edge as a standard", "never enlarge the ring") -> the workspace CONTEXT.md it governs, plus the skill.
- A routing row in CLAUDE.md points at a file that does not exist -> create it or fix the row (a context file that lies is worse
  than none - same rule as the context manifests).
## Check
`for f in design assets src docs; do test -f $f/CONTEXT.md || echo "missing $f/CONTEXT.md"; done` and grep CLAUDE.md's routing
paths for existence. Keep each CONTEXT.md under ~60 lines: link to skills for detail, do not copy them.
