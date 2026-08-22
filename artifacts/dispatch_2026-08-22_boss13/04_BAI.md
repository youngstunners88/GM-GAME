# B-AI — TEST HARNESS DESIGN ONLY. No product code.

Design a headless Godot 4.3 acceptance harness for Boss 3 (Claim Jumper) that a
founder would accept. Context:

- Real scene: res://src/level/level_03_gold_rush.tscn
- Fight starts via level._on_boss_trigger(player)
- Boss arena x 3700..4400. Boss spawn x=4050. Boss BODY=280, origin top-left.
- The founder circled a region around the MINECART / GOLD PILE and says the boss
  never gets past it. Approximate world x of that region: 4150-4300 (east half).
- Previous gates FAILED the founder because they measured altitude and hop counts,
  never world X. He said: "reject any claim that only shows bounded Y while X is frozen."

## Deliver
1. A bot movement path (formula in terms of t seconds) that FORCES the boss to have to
   traverse the circled region in both directions. State why teleporting/discontinuous
   bot paths invalidate the result.
2. The exact assertions, with numeric thresholds, covering:
   - boss centre X must pass BOTH sides of the circled band
   - max continuous frames with |dx| < 0.5 (freeze) — give a number and justify it
   - % of run inside the player's contact radius (anti "glued on top") — give a number
   - at least one air-hop, and how to detect it from velocity.y alone without false
     positives from the first hop
3. How the harness must FAIL on pre-fix code. Name the specific pre-fix behaviour each
   assertion catches.
4. One paragraph: what this harness still CANNOT prove, that only a browser capture can.
