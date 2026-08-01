# Episode 1 — human playtest checklist

**This is the gate.** Nobody — human or agent — should call Episode 1 done,
or merge PR #12, until you've personally run this list. Every item below is
something that was reported broken at some point and has since been fixed;
this checklist exists to confirm the fixes hold up in your hands, not just
in a test harness.

Take ~15 minutes. You don't need to finish the game.

**How to record results:** put a ✅ or ❌ next to each numbered item as you
go. For any ❌, grab a screenshot and note what you saw. A single ❌ is more
useful than a general "it felt off" — it tells us exactly where to look.

---

## Setup

**Option A — play the live build (easiest):**
https://youngstunners88.itch.io/lil-blunt-adventure

**Option B — play the exact PR branch build** (if you want to be sure
you're testing this branch and not an older deploy): ask for a fresh export
and a local link. Worth doing if anything below looks suspiciously like an
old bug you thought was fixed — you may be seeing a stale cached build.

**Controls:** MOVE `A`/`D` · JUMP `W`/`Space` (again mid-air = double jump)
· ATTACK `J` · DASH `K` · CLIMB `W`/`S` on a ladder · `ESC` to pause/exit.

---

## 1. Boot and first impression

1. Game loads to the title screen without a hang or a black screen.
2. Title text is readable — not tiny, not lost against the background art.
3. The How-To-Play / controls panel appears on first run and dismisses
   cleanly (`ESC` or the button). It should not trap you.
4. Hit PLAY — Level 1 (Smoke Realm) actually starts.

## 2. Core movement

5. Walk left and right. Lil Blunt's legs animate, and he faces the way he's
   moving.
6. Jump, then jump again mid-air — double jump works.
7. Dash (`K`) — you get a visible burst of speed.
8. **Legs don't sink into the ground.** Watch his feet while walking on
   flat ground: they should sit on the surface, not clip below it.

## 3. Ladders

9. Find a ladder, climb to the top with `W`.
10. **At the top, you end up standing ON the platform** — not floating in
    mid-air beside it, and not dropped back down. Try this on more than one
    ladder if you pass a few.

## 4. Torch in hand *(the one you've flagged repeatedly)*

11. Grab the torch power-up. Look at the HUD — a `TORCH` timer bar appears.
12. **Standing still**: the torch is held at hand/waist height, flame above
    him. Not dragging at his feet.
13. **While walking**: still in his hand. It should bob *with* him, not
    float or slide loose from the hand. This is the case that was actually
    broken before — please check it specifically, not just standing still.
14. Turn around and walk the other way — it stays in his hand on both
    sides.

## 5. Stomp

15. Find a Tax Collector minion (the small ground enemy). Jump and land on
    its head.
16. **The enemy dies, your score goes up, and you do NOT lose a life.** You
    should bounce off it.
17. Walk into an enemy from the side instead — *that* should still hurt
    you. (Stomp is a top-only attack; side contact is still dangerous.)

## 6. Combat

18. Press `J` to throw. The projectile appears and travels.
19. A connecting hit damages/kills a normal enemy.

## 7. The Auditor boss *(newly tuned — your feel call matters most here)*

20. Reach the end of Level 1 to trigger the Auditor boss arena.
21. **You can see the boss.** He's on screen, with a health bar at the top.
    You can also see yourself. Neither of you vanishes off-frame.
22. He telegraphs before charging — a brief freeze, facing you, with a
    sound, *before* he comes at you.
23. He actually chases you when you move away, jumps gaps, and throws
    clipboards while moving.
24. **The feel question — this is the one we tuned and need your verdict
    on:** turn and run right as he starts a chase. He now ramps up to full
    speed over ~0.7s and can't hurt you on contact for the first ~0.35s.
    Does that first encounter feel *fair* now, or does he still catch and
    hit you faster than you can react? There's no wrong answer — we changed
    this based on a review, not a playtest, so your read is the real
    verdict.
25. Hit him during his red/vulnerable window — damage registers and the
    health bar drops.

## 8. Blaze Rush (the secret side mode)

26. Find and enter the Blaze Portal in Level 1.
27. Blaze Rush looks like part of the game world — a moonlit treeline, not
    a flat black void.
28. **Press `ESC` mid-run.** You get out.
29. **Critically: you land back in the level you came from, with your
    progress intact — the game does NOT restart from the beginning.** Same
    check if you finish the run properly instead of exiting.

## 9. Stages 2 and 3

30. Progress to (or jump to) Level 2 (Crystal Caverns) and Level 3 (Gold
    Rush).
31. **In each, the boss is visible when you reach the arena** — this was
    the long-standing "boss disappears" bug. Confirm you can see both the
    boss and yourself, and that the camera follows you properly instead of
    freezing while you walk off-screen.
32. No invisible walls or spots where you get stuck and can't progress.

## 10. Mobile *(only if you want to test on a phone)*

33. Open the itch.io link on your phone.
34. Touch controls actually appear and work — you can move, jump, and
    attack.
35. Text is readable at arm's length.

## 11. Anything else

36. Note any crash, freeze, missing sound, or visual that looks wrong —
    even if it's not on this list. Screenshot it.

---

## What to send back

Just the numbers that failed, plus screenshots. If everything passes, say
so — that's the green light to merge PR #12, and that decision stays yours.

**Known and expected — not bugs:**
- Some art is still placeholder (protocol logos, founder portrait in the
  Smoke Lounge).
- Lil Blunt's own voice barks and the "talk to Lil Blunt" companion are
  being built now — if you're testing before those land, their absence is
  expected, not a failure.
