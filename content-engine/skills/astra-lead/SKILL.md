---
name: astra-lead
description: Route creative authorship to Astra GPT-6 on OpenRouter. Use for hooks, shot lists, Seedance prompt drafts, and viral structure on any drop. Claude Code executes files and tools; Astra is the lead LLM for creative.
---

# Astra GPT-6 Lead

## When
Any new hook, script beat, shot list, or Seedance prompt draft — for any drop.

## How
1. Load `content-engine/CLAUDE.md` + `script-lab/CONTEXT.md` + the drop's
   `drop.md` + locked references only. Load the drop's **format** file from
   `formats/` so Astra writes to the right skeleton.
2. Call OpenRouter with the current Astra GPT-6 model id (verify the live
   catalog; do not guess a dead slug).
3. Ask Astra for:
   - 3 hooks
   - beat sheet with timestamps, matching the drop's format
   - marked 10s hero window (for video formats)
   - per-shot visual prompts (fidelity-safe)
4. Claude writes Astra's output into the drop folder
   (`brief.md`, `script_final.md`, `script_shots.md`). Do not silently rewrite
   Astra's locked lines.
5. If OpenRouter errors, log it in STATUS.md and stop creative authorship — do
   not substitute a weaker model as "the lead."

## Temperature
0.7–0.9 creative; 0.2 when converting a locked shot into a Seedance prompt.
