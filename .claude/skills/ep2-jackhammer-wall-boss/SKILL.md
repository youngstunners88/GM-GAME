---
name: ep2-jackhammer-wall-boss
description: Router for the founder's 2026-11-05 brief "Jackhammer is the wall boss" - the OFFICIAL Jackhammer Wanted art replaces every weak Jack Hammer poster, RH (Rich) posters are reduced (never removed) across the whole Episode 2 environment, and a large SHOOTABLE Jackhammer billboard stands in the Gatling yard. TRIGGER on "Jackhammer Wanted", "official wanted poster", "too many RH posters", "Rich looks like the antagonist", "wall boss", "Gatling billboard / banner / big target", or the Drive files 15T7bTvoX0K2REwQ45sfMKnrvAjhNI35z / 1GCG24Wf3uzR6GX_xVstsOFWnt596UEAM.
---

# Jackhammer is the wall boss (founder 2026-11-05)

Brief (verbatim copy): `docs/founder-feedback/2026-11-05_jackhammer_posters_gatling_billboard.md`.
Why: the street reads as if **Rich** is the villain - his RH bill is the biggest paper on the saloon and on the notice board,
while Jack Hammer's painted bills are the smallest. Jack Hammer (Jackson McCree) is the antagonist; Rich runs the Armory.

## Three jobs, two component skills
| # | Job | Skill |
|---|---|---|
| P0-1 | Every Jack Hammer bill (blank, placeholder, painted engraving) -> the founder's OFFICIAL art | `ep2-official-wanted-rebalance` |
| P0-2 | Slide-reduce RH environment-wide; Jack Hammer becomes the majority AND the largest wanted face | `ep2-official-wanted-rebalance` |
| P0-3 | Billboard-class Jackhammer target by the Gatling that registers Gatling hits | `ep2-gatling-wanted-billboard` |

Order: import the official art first (the billboard reuses the same texture), then rebalance, then the billboard. One gate
covers all three (see the component skills): `tests/ep2_wanted_rebalance_test.tscn` + the billboard section of
`tests/ep2_gatling_hits_test.tscn`.

## Parallel-session rule (a second Claude session was running on another machine when these skills were written)
Before editing, `git fetch origin && git log origin/master --oneline -15 -- src/episode2/chamber/ep2_town_posters.gd src/episode2/actors/ep2_gatling_post.gd src/episode2/extras/town/posters`
and list `origin/claude/*` branches touched in the last day. If someone already landed part of this brief, **build on it**;
on a conflict keep both sessions' work (CLAUDE.md PARALLEL-SESSION RULE). Never land a second copy of the official image
under a different name - one canonical file.

## Locks that still hold
- Do not invent a Jack Hammer likeness: the poster face is the founder's art, full stop. It shows **no eye patch**, while
  `ep2-jack-hammer-character` locks the 3D model to "mean, eye patch". Do not paint a patch onto the poster and do not change
  the model - list the mismatch as an open question for the founder in STATUS.md.
- His art says "REWARD 10,000 BTC & THE PRESIDENT'S DAUGHTER". `ep2-wanted-posters`: the founder's posters are hung **as
  supplied**; the "no digits / no tickers" rule binds only posters WE paint. Do not edit his wording; note in STATUS.md that
  the narrative lock says the bounty is paid in gold (XAUt) so the founder can decide.
- Keep some RH (Rich stays the Armory face). Do not touch protocol chamber signage (Treasury, Certificates, Stockpile).
- Do not replace the Gatling mesh, do not remove the plates or bales, do not make the Gatling stock (`ep2-armory-guns`).
- Streamed extras (ADR-0005): new images live under `src/episode2/extras/`; `.import` committed with `git add -f` in the
  pinned-4.3 format (import with `.godot-cache/Godot_v4.3-stable_linux.x86_64 --headless --import`, twice).

## Done means
Gates green, captures from the player's camera (street walk-up, notice board, Armory front, mounted Gatling view before /
after a burst) looked at by you (`see-it-yourself`), STATUS.md entry ("environment-wide poster rebalance + Gatling billboard"),
vault log, `always-ship-live`. Write FIXED only after the founder's hard-refresh walk of town + the Armory Gatling yard;
until then "shipped, awaiting your walk".
