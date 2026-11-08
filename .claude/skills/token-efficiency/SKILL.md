---
name: token-efficiency
description: Spend fewer tokens on this repo without losing quality - what actually burns context here (measured), the reading/searching/testing habits that stop it, when to hand volume work to a cheap model or subagent, and the verdict on DietCode / ScaleDown (what it does, what it sends out, how the founder installs it on his own machine). TRIGGER at the start of any long session, when the context fills fast, when the founder says "token burn", "rate limit", "efficient", "DietCode", "ScaleDown", or before reading a log, STATUS.md, a big skill or a whole test output.
---

# Token efficiency (founder 2026-10-14)

## What burned tokens here (measured)
| Culprit | Size | Rule |
|---|---|---|
| `STATUS.md` was **1.3 MB** (~320k tokens) and the manifest said "always load" | split 2026-10-14: 100 KB current + `docs/status-archive/` | `sed -n 1,40p STATUS.md` ONLY. Add new entries at the top; when it passes ~120 KB move the oldest to the archive. |
| `CLAUDE.md` 29 KB loaded every turn | cannot shrink the routing table | do not paste skill bodies into it; add one routing row, put detail in a skill |
| Big skills (`design-system`, `setup-engine`, `ux-design`: 30-40 KB each) | | load only the skill the task names, never browse the skill folder |
| `export.log`, `gate_*.log`, Godot headless output (hundreds of KB, `meta values` spam) | | never `cat`/Read a log: `grep -E "FAIL|ALL PASS|SCRIPT ERROR|Parse" log \| head`; `tail -n 20`; Godot: add `2>&1 \| grep -vE "meta' values"` |
| Whole-file reads of `woods_quad.gd` (2.5k lines), `smelting_facility.gd`, `interlude_base.gd` | | `Grep -n` for the symbol, then `Read` with `offset`/`limit` (60-120 lines) |
| Tool results that echo big JSON (Drive reads, manifest dumps, `gh api` bodies) | | pipe through `python3 -c`/`jq` and print only the fields you need; list ids with `--jq` |
| Re-reading a file you just edited, re-printing whole diffs | | the Edit tool errors if it failed; `git diff --stat` instead of `git diff` |
| Repeating the task list / skill list reminders | | ignore them; do not re-announce |

## Habits
1. **Manifest first, then only what it lists** (`.claude/context-manifests/default.md`). Never "load the repo".
2. **Search before read**: `Grep` (files_with_matches -> then content with `-C 3`, `head_limit`) beats opening files. Use `Glob` for names.
3. **Run gates quietly**: `... 2>&1 | grep -E "FAIL|ALL PASS|SCRIPT ERROR"`; run independent gates in parallel (`&` + `wait`); look at a failing line's context only.
4. **Captures**: one contact sheet (PIL, 4-8 frames at 400-640 px) per Read instead of one image per Read.
5. **Volume to cheap models, judgement to Claude** (CLAUDE.md "MODEL ROLE SPLIT"): scanning many frames/logs/diffs -> `scripts/or-call.mjs deepseek/deepseek-v4.1-flash`; Claude re-verifies before it lands. Big well-specified code -> `scripts/opus-offload.mjs`. Exploration across many files -> an Explore subagent (its reading does not enter this context).
6. **Don't verify by re-deriving**: trust a passing gate; spend tokens on what the gate cannot see (the capture).
7. **Replies short** (founder rule). No recaps of what the tools already showed.
8. Heavy compute (Cycles bakes, 4K textures) -> the Runpod GPU (`ep2-cloud-gpu-runpod`), not minutes of container time you babysit.

## Sessions and worktrees burn tokens too (2026-11-05)
- A new session or subagent re-reads its context from cold. Start one only when the job is big and separate enough to pay for it (`parallel-session-build`).
- A noisy tree makes every `git status` and diff expensive, and invites accidental commits (`worktree-hygiene`).
- Before opening a "reference" image, check that it is one: `*_Image_*.jpg` beside a GLB are texture atlases.
- Combine captures into one sheet, and print only measured numbers from a capture run.
- Ship once: run the gates that can fail before the full ship, because a failed ship repeats a long gate run.

## Founder-brief loop (2026-11-08, the Inferno->Flux brief: ~15 tool calls end to end)
1. Drive link: `get_file_metadata` with `excludeContentSnippets` first (title + size), then read it once. Honour its "Token rules" section.
2. `grep -n` the brief's nouns in the one file it names -> `sed -n A,Bp` 40-120 line slices -> patch with one scripted multi-replace (asserts each anchor is unique).
3. Gates to a log, print only `[PASS]/[FAIL]/ALL PASS` lines; extend the existing gate with a regression check instead of a new test scene.
4. STATUS: one bullet. Reply: a few lines. No plan essays, no re-reads after edits.

## Feature-brief loop at scale (2026-11-08, lake repair + auction road: 1 new room, 6 files, ~60 tool calls)
- Locate with greps of the brief's nouns + `grep -n "^func "` on the big files; read 30-80 line slices only. Never open river_cover/gold_town whole.
- Copy an existing room's shape (setup, collide, shot ray) from grep hits instead of reading interlude_base.
- One gate for the brief's acceptance table (source checks + headless steps); run it plus the 8-10 neighbouring gates in parallel, printing only FAIL/ALL PASS counts per log.
- No .godot cache in a fresh container: bootstrap (retry on GitHub 504) and one `--import` before any test, all output to a log.

## DietCode / ScaleDown (npm `dietcode` 0.5.0, https://docs.scaledown.ai) - evaluated 2026-10-14, NOT installed by the agent
What it is (read from the package, nothing was executed): Claude Code hooks (`UserPromptSubmit`, `PostToolUse`, `PreCompact`) + a status line + an optional local proxy
(`dietcode claude`) that rewrites each outgoing request and keeps a running summary of old turns. Compression is done by **Scaledown's cloud API (`api.scaledown.xyz`)**
with a `SCALEDOWN_API_KEY`. Only the proxy mode truly shrinks context; the hooks can only add hints and compress big tool outputs.
Why the agent did not run it: (1) `dietcode setup` is interactive and needs the founder's own ScaleDown key (browser sign-in); (2) it **sends prompts and tool outputs - i.e. repo code and anything
that scrolls past in a terminal, including env dumps - to a third party**; (3) it **rewrites `~/.claude/settings.json` hooks + status line and appends the key to `~/.zshrc`/`~/.bashrc`**; (4) the
sandbox container is ephemeral, so nothing would persist to his machine anyway. A packaged `postinstall` script also runs on `npm install -g`.
If the founder wants it on his own machine (his call, his key):
```
npm install -g dietcode        # review: https://www.npmjs.com/package/dietcode
dietcode setup                 # asks for the ScaleDown key; writes hooks/status line/shell exports
# restart Claude Code; then, for real per-turn savings:  dietcode claude
```
Safer first trial: proxy/hooks on a throwaway branch session, never with `OPENROUTER_API_KEY`/`MUAPI_API_KEY`/`RUNPOD_API` exported in the same shell, and check `~/.claude/settings.json` afterwards
(it replaces existing `UserPromptSubmit`/`PostToolUse`/`PreCompact` hooks). The free, local habits above give most of the saving with none of that exposure. The GitHub repo `scaledown-team/SLM_Agent` was
not pulled: this session's GitHub access is scoped to GM-GAME only.
