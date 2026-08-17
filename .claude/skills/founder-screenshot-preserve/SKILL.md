---
name: founder-screenshot-preserve
description: Mandatory preservation of every founder screenshot into the prompt MD and docs/captures. Use on every session that receives images from the founder. Prevents the recurring failure where Claude investigates blind because screenshots were not written into the prompt or the workspace.
---

# Founder screenshot preserve (non-negotiable)

## Why this exists

The founder has repeatedly sent annotated screenshots. Sessions keep investigating “blind” or losing the images. That is a process failure, not a founder failure.

## Rules

1. **Extract every image the same turn it arrives.** Decode base64 / save attachments under:
   - `artifacts/founder_shots_YYYY-MM-DD/shot_N.png` (workspace mirror)
   - `docs/captures/YYYY-MM-DD-founder/` inside the repo once the agent has the repo
2. **Reference the paths in the active PROMPT_*.md** with one line per defect:
   - `shot_1.png — black SCORE HUD plate`
   - Do not only say “see attachment.”
3. **Copy paths into STATUS.md** under the session section so the next agent does not lose them.
4. **Qwen VL (or vision lane) must open the real files** before claiming a visual FIXED.
5. **Never delete founder screenshots** from `docs/captures/` or `artifacts/founder_shots_*`.

## Anti-pattern

- “A new document just arrived — let me check if it contains screenshots” after already having started code work without them.
- Claiming FIXED on a circled region without the image path in the commit or STATUS.

## Success

Any future session can `ls docs/captures/…` and open the exact frames the founder circled.
