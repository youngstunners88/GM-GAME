<!-- dispatched: x-ai/grok-4.5
     prompt: prompts/grok-titles-onboarding.md
     files inlined: 0
     tokens: 937 in / 666 out
     cost: $0.0059
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
# Lil Blunt — title/UI hierarchy + controls panel

## Problem 1 — readability hierarchy

### 1. Font-size ladder (1280×720 base)
| Role | px | Notes |
|------|-----|--------|
| **Title** | **72** | One line if possible: `LIL BLUNT` |
| **Subtitle** | **32** | `THE SMOKE REALM` once, under title — drop the duplicate in the title block |
| **Primary buttons** (PLAY / CONTINUE / QUIT) | **36** | Keep ~400px column; add vertical gap so taps aren’t cramped |
| **Secondary buttons** (Onboarding, Leaderboard, etc.) | **24** | Prefer 320×52 hit targets; cap list length or fold extras into a “More” sheet |

Hierarchy at arm’s length: title dominates → primaries read as the action → secondaries clearly subordinate.

### 2. Contrast / legibility
**Yes** — near-white on dark green art will muddy on phone screens and busy plates. Minimal fix: **1–2px dark outline (or soft drop shadow) on all UI type**; no full plate needed if outline is consistent.

### 3. Single most important fix
**Raise primary actions (title + PLAY/CONTINUE) and give every label a dark outline** — size without separation still fails on stretch/HTML5.

---

## Problem 2 — control-instruction panel

### 1. Copy block (chill, short, both inputs)

**How you roll**

- **Move** — A/D or ←/→ · drag / tilt the stick  
- **Jump** — Space / W · tap jump *(again in air = double jump)*  
- **Attack** — J · tap attack  
- **Dash** — K / Shift · tap dash  
- **Interact / climb** — E · tap interact  

Footer line: *You’re good. Go easy.*

(Keep labels matching whatever the game actually binds; don’t add skills that aren’t in build.)

### 2. Layout principles
- **Where:** Lower third or gentle side card; 60–70% max width; never center-modal over the player spawn.
- **Dismiss:** One clear **Got it** / tap-outside; also **Start** if shown pre-run. Persist dismiss in save so it doesn’t nag.
- **Later access:** Same panel from menu (`Controls` / `How to play`) and pause — one component, two entry points.
- **Kbd vs touch:** One row per action, two short suffixes on the same line (`key · touch`) — icons if you have them; no separate tabs or doubled paragraphs.

### 3. Auto-show vs opt-in
**Auto-show once on first run** (after or on the first gameplay entry), then menu-only. First-time phones need the hint; repeats should stay chill.