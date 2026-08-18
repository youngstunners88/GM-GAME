# Code audit — why do players perceive that these bosses "don't chase"?

A founder has rejected 10+ chase fixes for the Stage 2 (Distributor) and Stage 3
(Claim Jumper) bosses, saying "the 2nd and 3rd bosses still don't chase". Prior
sessions proved with headless tests AND browser captures that the boss DOES close
horizontal distance. The founder still says no.

Audit the two boss scripts below. I want the PERCEPTUAL failure, not the numeric
one. Specifically look for:
- Does the boss spend most of its time in a non-chasing state (attack windup,
  cooldown, hover, teleport) so that the chase is real but rarely visible?
- Does it stop/standoff at a distance that reads as "hovering"?
- Does it re-target only on state entry (stale snapshot) so it lunges at where
  the player WAS?
- Is chase speed below the player's run speed (player can always outrun = looks
  like no chase)?
- Any state that can trap it far from the player.

Player run speed and dash are in player.gd. Give me a RANKED list of concrete
causes with file:line, and the single highest-impact change for each boss.

@include src/boss/distributor.gd
@include src/boss/claim_jumper.gd
