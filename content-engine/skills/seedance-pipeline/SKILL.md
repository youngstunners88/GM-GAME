---
name: seedance-pipeline
description: Build and run the Seedance 2 / 2.5 render plan for a drop's 30s master and 10s hero. Use when writing shot prompts, queuing renders, or assembling output.
---

# Seedance Pipeline

## Budget split
- Seedance 2 = full story (all shots)
- Seedance 2.5 = one 10s hero only, per drop

## Per-shot file (`drops/NNN_slug/prompts/shot-NN_seedance2.md`)
```
# shot-NN
Duration:
Hero window: yes/no
Camera:
Subject (locked):
Action:
Environment:
Must-include:
Must-not-invent:
Seedance model: 2 | 2.5
Prompt:
```

## Assembly
1. Render shots to the drop's `builds/`
2. Conform to the format length (30s for hype-30s)
3. Cut hero 10s from the marked window, or use the dedicated 2.5 render
4. Write masters to the drop's `output/` (naming from CLAUDE.md)
5. STATUS.md: render ids, model, seconds, cost, fail notes
6. Advance the drop's state on the calendar board (`rendering` → `assembled`)

## Never
- Swap Seedance 2.5 onto the full story
- Leave failed takes in `output/` — only masters ship there
- Fake a render if the tool path fails — log the failure (see mcp-video-tools)
