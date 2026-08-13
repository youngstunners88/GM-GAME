@include prompts/_s7_facts.md

@include src/boss/distributor.gd

# YOUR ROLE: Kimi K3 — projectile range math + S2 chase + font min-size gates

Reason from the included distributor.gd.
Q1: boss_projectile despawns after `lifetime` seconds. Given _throw_shards speed
170+40*(phase-1) and _throw_crystal_shards 260+50*(phase-1), compute how far each
travels before despawn, and give the speed AND/OR lifetime change so a shot fired
from one side reaches a player ~1200px away across the arena. Exact numbers.
Q2: Is MIN_PURSUE_SPEED / the pursuit model enough that the boss visibly closes
horizontal distance on a kiting player in the real bounded Stage 2 arena? If not,
the minimal number to change. (Founder still says "not chasing.")
Q3: A headless gate for readability — how do you assert a Label is "readable"
without a browser? Propose the measurable proxy (font_size >= N AND outline_size
>= K on every vault label) and the exact node-walk to check it.
Be terse; numbers + line-level changes only.
