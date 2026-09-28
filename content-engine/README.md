# Smoke Content Engine

A **repeatable short-form video content engine** for the SmokeRing / Lil Blunt
ecosystem ($SMOKE on Solana, LilBlunt.win). It generalizes the original
single-launch-video pack into an ongoing machine: a content calendar, reusable
format recipes, and a fixed per-drop lifecycle that makes shipping the *next*
piece cheap.

This is a marketing sibling to the Lil Blunt Adventure game in the rest of this
repo — same brand, separate workspace, **no game code touched**.

## Start here (load order)

1. `CLAUDE.md` — engine identity, drop lifecycle, routing, hard rules
2. `STATUS.md` — what shipped, what's next
3. The workspace `CONTEXT.md` for your task (routing table in `CLAUDE.md`)
4. Only the skill the routing table names

## The loop

```
calendar backlog → pick format → scaffold drop → Astra brief → lock script
   → shot list → Seedance render → assemble → distribute → analyze → archive
                         │
                         └── analytics feed back into the backlog
```

## Layout

| Path | What |
|------|------|
| `calendar/` | Cadence, backlog, live drop board + `drops/NNN_slug/` per drop |
| `formats/` | Reusable recipes (hype-30s, hero-10s, still-post, x-thread) + template |
| `script-lab/` | Ideas → locked script + shot list (thinking only) |
| `production/` | Seedance prompts, MCP runs, builds, masters |
| `distribution/` | Platform cuts, captions, scheduling, analytics |
| `skills/` | Load-on-demand: astra-lead, seedance-pipeline, mcp-video-tools, distribution-smoke, content-calendar, drop-runner |
| `archive/` | Shipped + analyzed drops |

## Make a drop

1. Groom the calendar and pick the next item + format → `content-calendar` skill.
2. Scaffold it → `drop-runner` skill (creates `calendar/drops/NNN_slug/` + board row).
3. Fill creative → `astra-lead` (Astra GPT-6 leads; Claude files).
4. Render + assemble → `seedance-pipeline` (+ `mcp-video-tools`).
5. Publish → `distribution-smoke`.

## Rules that never bend

- No protocol invention; no fake APY / MC / TVL / "guaranteed SOL".
- Prompt fidelity — no new mascots, brands, or claims the brief didn't lock.
- Seedance 2.5 = one 10s hero clip per drop; Seedance 2 does the story.
- Astra GPT-6 authors creative; Claude Code executes tools and files.
- Update `STATUS.md` + the calendar board after every drop; commit and push.
