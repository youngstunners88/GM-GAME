# Kimi K3 — MATH ONLY, tables. Godot 4.3, gravity 980.

PR #52 made ALL Level 1 floating platforms ONE-WAY (pass-through horizontally)
to fix the 220px Auditor pinning on two of them. Founder now: "the boss walks
through the blocks as if they don't apply to him — nothing Lil Blunt can
leverage for distance; fight impossible. Also still some flying." Global one-way
was too coarse.

Auditor: BODY 220, origin=top-left, feet=origin.y+220, body band = [origin.y,
origin.y+220] = [430,650] when grounded on y=650. LEAP -620 (196px). Walk 235.
Player: 28px tall, jump 94px.

Level 1 floating platforms (x,y,w,h), ground top y=650:
(300,500,100,20) (500,400,100,20) (750,350,120,20) (1100,450,100,20)
(1400,350,100,20) (1700,400,150,20) (2100,300,100,20) (2600,350,100,20)

## Deliver as a table, one row per platform:
For each platform: its bottom edge y (= y+h), does it intersect the grounded
boss body band [430,650]? (i.e. is it a horizontal WALL to a grounded boss, or
does he walk UNDER it?). Then classify:
- "WALL" = bottom > 430 (blocks/pins a grounded boss horizontally)
- "OVERHEAD" = bottom <= 430 (boss walks under; solid or one-way is invisible to him)

Then answer:
1. Which platforms are WALLs to the boss? (These are the only ones that ever
   pinned him AND the only ones where solid-vs-one-way changes his behaviour.)
2. If ONLY the WALL platforms get a boss-clearing mechanism (vault/leap with
   horizontal commit) and ALL platforms revert to SOLID, does the player regain
   every platform as a solid surface for spacing? Yes/no.
3. For each WALL platform, from the y=650 ground how much rise does the boss
   need to put his FEET on top (clear it), and can LEAP -620 (196px) + a
   horizontal commit carry him onto it or past it? Give the number.
4. Is there any platform the PLAYER stands on for spacing that is OVERHEAD to
   the boss (bottom <= 430)? If so, note that "solid to boss" is meaningless
   there (he's under it) — the spacing there comes from vertical separation, not
   a horizontal wall.
