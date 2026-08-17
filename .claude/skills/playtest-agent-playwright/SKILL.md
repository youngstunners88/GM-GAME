---
name: playtest-agent-playwright
description: Automated browser playtest agent for Lil Blunt GM-GAME. Drives the non-threaded web export with Playwright, warps to bosses/levels when hooks exist, captures before/after screenshots, and reduces founder manual up-and-down testing. Use when founder reports live defects, after residual prompts, or when claiming FIXED on visual/gameplay items.
---

# Playtest agent (Playwright)

## Goal

Stop forcing the founder to climb Stage 1–3 and fight bosses by hand for every claim. The agent captures evidence; the founder only confirms hard-refresh on the live itch build.

## Prerequisites

- Non-threaded web export (`variant/thread_support=false`)
- Local or CI-served `index.html` + `index.pck`
- Playwright + Chromium available in the agent environment
- Prefer existing `scripts/playtest-*.mjs` patterns; extend rather than invent a second harness

## Mandatory behaviours

1. **Boot proof** — export loads, 0 script errors in console.
2. **HUD proof** — capture frame showing SCORE/HUD region (black plate gone or still present).
3. **Stage 3 proof** — warp or traverse to Level 3; capture:
   - figure/sun scale
   - mine cart presence + interaction if triggerable
   - path at timed gate / former block box
   - BTC/wBTC coin clarity
4. **Boss proof (when in scope)** — use `?boss=2` / `?boss=3` if present; otherwise honest “could not reach” instead of fake chase claims.
5. **Write frames** to `docs/captures/YYYY-MM-DD-<topic>/` and list paths in STATUS.
6. **Never claim FIXED from headless gates alone** when the founder’s complaint was visual.

## Founder load reduction

| Founder used to do | Agent does |
|--------------------|------------|
| Start game, reach Stage 3 | Warp / drive + screenshot |
| Check HUD black box | Capture HUD region |
| Fight bosses to see chase | `?boss=N` warp + frame sequence |
| Spot path blockers | Walk-path probe + capture |

Founder still does **one** hard-refresh on itch after butler ships. That is the only required human loop for visual residuals.

## Failure modes (report honestly)

- Menu click coordinates stale → recalibrate, do not invent “boot failed”
- Score-gated portals → use debug warp only if it exists; revert debug code before commit
- OpenRouter / image lanes down → do not block playtest screenshots on them
