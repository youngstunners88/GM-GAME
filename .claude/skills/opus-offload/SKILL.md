---
name: opus-offload
description: Offload a large, well-specified coding task to Claude Opus 5.5 on OpenRouter — it reads the files, writes the code, and iterates against the repo's own tests until they pass — so the interactive session spends only a brief and a review. Use when the session's rate limit is tight, when a change spans several large files (merges of parallel work, new systems, big refactors), or whenever the founder asks to "use Opus on OpenRouter".
---

# Opus offload — heavy coding on OpenRouter, verified locally

The session's rate limit is the scarce thing. Reading and writing big files is what
burns it. `scripts/opus-offload.mjs` moves that work to `anthropic/claude-opus-5.5` on
OpenRouter (metered: ~$4 in / $20 out per million tokens; `:batch` is half price but
async). The session only writes a brief and reviews the result.

## Use it

1. Write a task file (anywhere; `.farm/` is gitignored). Plain markdown, plus
   `@include <repo path>` lines — each is replaced by the real file. A missing path
   aborts **before** any spend.
2. Dry-run to see the size and price:
   `node scripts/opus-offload.mjs task.md --allow src/some/dir --dry-run`
3. Run it with a verify command:
   `node scripts/opus-offload.mjs task.md --allow src/some/dir --verify "bash .farm/verify.sh" --rounds 3`
   Each round: the model returns WHOLE files → they are written → your verify command
   runs → on failure, the relevant error lines go back to the model for another round.
4. Review `git diff`, run the real gates yourself, then commit and
   `scripts/ship-to-master.sh`. **Nothing is committed by the offload.**

## Writing a brief that works first time

- Say which files to output, and what each side/section must keep.
- Name the contract: include the test file; say "every assertion must still pass".
- Say which assets/APIs exist (include them) — the model cannot see the repo otherwise.
- State the Godot 4.3 traps (already in its system prompt: no `:=` from a Variant, tabs).

## Safety (why it's safe to run unattended)

- Model output is **data**. Files are written only inside the repo, only under
  `--allow` paths (default: directories of the included files). `.git/`, `.github/`,
  `.env*` and anything named like a secret are never writable.
- The only command executed is **your** `--verify` string. Nothing the model writes runs.
- Every call is logged with token counts and $ cost in `.farm/offload-log.jsonl`.

## Known traps

**Refresh Godot's class cache before verifying.** If the included files (or master)
add a `class_name`, run `.godot-cache/Godot_v4.3-stable_linux.x86_64 --headless --editor --quit`
first. On the first real run (merging two runner implementations) a stale cache made
master's own files fail to parse; all three paid rounds "failed" on correct code and
~$2.20 of the $3.39 was wasted. The model diagnosed it correctly in round 3.

**Fetch/proxy** (already fixed in the script):

Node's built-in `fetch` + the npm `undici` proxy dispatcher returns gzip bodies
undecoded, so `.json()` throws. The script uses undici's own `fetch` behind
`HTTPS_PROXY`. `scripts/or-call.mjs` still uses the mixed pattern.
