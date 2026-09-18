---
name: content-calendar
description: Plan cadence, groom the drop backlog, pick the next drop, and keep the calendar board + STATUS in sync. Use when deciding what to make next, scheduling, or reviewing what shipped vs what's queued.
---

# Content Calendar

The engine's planning brain. Turns a backlog into a steady stream of drops and
keeps everyone honest about state.

## When
- "What should we make next?" / "plan the week" / "groom the backlog"
- After a drop ships (fold results back in)
- When cadence or a recurring anchor (bong party) needs scheduling

## How
1. Read `calendar/calendar.md` and `STATUS.md`.
2. **Groom the backlog**: order by priority, kill stale ideas, add new ones
   from `script-lab/ideas/` and from analytics winners.
3. **Pick the next drop**: choose the top backlog item + a **format** from
   `formats/`. Respect the cadence table (weekly anchor, mid-week hero, filler).
4. Confirm the pick with the founder if the format or claim is new.
5. Hand to `drop-runner` to scaffold it.
6. **Keep the board live**: every lifecycle change updates BOTH the drop board
   in `calendar/calendar.md` and `STATUS.md`.

## Grooming rules
- One promise per drop; don't queue two drops fighting for the same hook.
- Never spam the same 30s more than twice without a new hook.
- Feed analytics back: a beat that performed becomes a new backlog seed.
- Recurring anchors (weekly bong party) never fall off the calendar.

## Output
- Updated backlog + board in `calendar/calendar.md`
- A named "next drop" ready for `drop-runner`
- STATUS.md session note
