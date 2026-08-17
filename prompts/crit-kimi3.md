You are Kimi K3 (`model-kimi-chase-geometry`). Do NOT re-derive from source; I
have MEASURED the live behaviour. Validate or refute my diagnosis. Be brief and
decisive — answer in under 500 words, no long deliberation.

I instrumented the real Godot web build to post the boss's and player's true
world coordinates every physics tick, then drove the player like a fleeing
human (alternating direction + hops) for 16s in each real boss arena.

STAGE 2 (Distributor, hovering boss, arena 700px wide):
  boss travelled 1564 px; boss_x range 350 px; gap 350 -> 6.7 px
  gap_mean 64.6 px; gap_min 0; 0 level reloads; player survived 18s
  52% of all samples had |boss.x - player.x| < 60 px
  vertical gap while horizontally overlapping: min 165, mean 250

STAGE 3 (Claim Jumper, ground boss, arena 700px wide):
  boss travelled 3010 px; boss_x range 340 px; gap 230 -> 18.9 px
  gap_mean 100 px; gap_min 0
  4 FULL LEVEL RELOADS in 16 s; longest survival 4.07 s
  38% of samples had |dx| < 60 px

Context: ANY boss body contact calls GameManager.boss_contact_restart(), which
reloads the whole level and wipes the run's score (an explicit founder rule).
Both bosses steer toward the player's own x (the Distributor centre-seeks a
point directly above the player: target = player + (0, -250)).

Across 10+ sessions, every "fix" RAISED pursuit aggression
(MIN_PURSUE_SPEED 265 -> 315 -> 345, HOVER_ACCEL 430 -> 1600). The founder's
complaint has never changed and has now escalated from "doesn't chase" to
"doesn't MOVE".

MY DIAGNOSIS — confirm or refute each point:
(A) Both bosses already chase correctly. The pursuit code is not broken.
(B) Because they steer at the player's OWN x, they LOCK ON and sit on top of
    him. The camera follows the player, so a boss at |dx|<60 for half the fight
    has almost zero motion RELATIVE TO THE SCREEN — it looks parked/frozen even
    though it is travelling 1.5-3k px in world space. That is why the founder
    says "doesn't move".
(C) On Stage 3 the lock-on plus contact-restart makes the fight unsurvivable
    (4 s), so he is booted to the level start before any pursuit is observable.
(D) Therefore every previous "make it chase harder" fix made the REPORTED
    symptom strictly worse, which explains 10 failed attempts.
(E) The correct fix is a horizontal STANDOFF: the boss closes to a threat
    distance and holds/attacks from there instead of occupying the player's x —
    restoring visible relative motion AND making contact avoidable, without
    weakening pursuit or touching the founder's contact-restart stakes rule.

Give: AGREE/DISAGREE per point (one line each), then a recommended standoff
distance in px for a 240px-wide hovering boss and for a ground boss in a 700px
arena, and the single biggest way this fix could backfire.
