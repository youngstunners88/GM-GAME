---
name: ep2-3d-strategy-research
description: Find out what we don't know — engine bugs, web-export limits, 3D/animation/VFX techniques, API contracts — from the internet, efficiently, with a fixed routing table and a findings log. TRIGGER when a 3D/web/render/animation problem survives one round of local bisection, before adopting a new API or technique, when a vendor API errors in an unexplained way, or when asked for strategies to improve the 3D look/feel.
---

# Rule zero
**Search before the second bisection round.** Five local builds went into the "blank 3D on web"
bug (2026-09-27); one Exa query named it (godot#96968, research/001). Local bisection finds
*where*; the internet usually already knows *why*.

# Routing (verified 2026-09-27 — re-verify a route that errors, never assume)
| Need | Route | Notes |
|---|---|---|
| Find the issue/thread/doc for a symptom | **Exa MCP** `mcp__Exa__web_search_exa` (describe the ideal page + an `objective`) | best hit-rate on GitHub issues; returns highlights |
| Read a known URL fully | `mcp__Exa__web_fetch_exa` (batch URLs) or `WebFetch` | WebFetch answers a prompt against the page |
| Broad web search | `WebSearch` | titles + URLs; follow with fetch |
| Vendor API contract (Meshy, VARCO, OpenRouter…) | curl the docs page → strip HTML → grep the param names | never invent endpoints; quote the doc in the finding |
| Grounded quick answer | Gemini `google_search` tool (`gemini-3.5-flash`) | quota 429s happen — back off |
| Long logs / many pages to triage | DeepSeek V4.1 Flash via `scripts/or-call.mjs` | a lead, never a fact |
| JS-heavy page / interactive site | Tinyfish (`TINYFISH_API_KEY`) or Browser Use (`BROWSER_USE_API_KEY`) | reachable, not yet exercised |
| ✗ Firecrawl | key returns **401 Invalid token** (v1 and v2) | ask the founder to refresh it; don't route here |

# Separation of concerns
1. **Question** — one sentence, with the exact engine version (Godot 4.3, Compatibility/WebGL2,
   non-threaded web) and the measured symptom.
2. **Collect** — ≤3 searches, ≤5 pages. Collectors never write code.
3. **Digest** — extract the claim, the version it applies to, the workaround, the source URL.
4. **Verify here** — reproduce or fix it in this repo with a named proof (test, toggle, capture).
   Unverified = LEAD.
5. **Record** — `docs/research/3d/NNN_slug.md` + a row in `docs/research/3d/INDEX.md`
   (VERIFIED/LEAD, layer, proof). Then link it from the skill of the layer it changes.

# Reusable debug tools this skill relies on
- `?ep2off=<keys>` (TEST-ONLY) switches runner view features off in the web build
  (boulders, shadows, streaks, rig, strips, gold, halo, stress) — bisection without code edits.
- `?ep2bot=1` — autopilot plays so captures are deterministic.
- `scripts/ep2-blank-frame-probe.mjs` — brightness sampling: screenshot a crop every frame and log mean brightness vs track distance;
  identical means across many frames = the 3D pass is missing, not "dark art".

# Standing questions worth researching next (not yet done)
- Godot 4.3 Compatibility: cheapest convincing speed blur / motion lines for web.
- Animation retargeting of extra Meshy clips onto an existing rig (so one rig can gain clips).
- Web texture compression (ETC2/ASTC vs lossless) to buy pck headroom (176 MB of 190 MiB).
