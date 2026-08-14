@include prompts/_s8_facts.md
@include src/boss/distributor.gd
# Kimi K3 — real-arena chase numbers. Terse; numbers + line-level changes.
Q1 S2 boss: HOVER_ACCEL is now 1600 and MIN_PURSUE_SPEED 345, arena 700px wide
(3700..4400), boss body 240 wide (so clamped centre range is only ~460px). The
founder STILL says "not chasing". Reason from the included file: does the
half-body arena inset + HOVER_ABOVE (~250px above player) + the climb-lock
(BODY*0.75 band) leave him hovering overhead rather than closing horizontally in
THIS narrow arena? Give the single most-likely remaining cause and a minimal
numeric change. Propose a headless gate on a WEAVING player that measures the
boss's own horizontal pursuit (not a confounded gap metric).
Q2 dialogue open delay: what's a good per-line reveal cadence (seconds) so an
E-to-talk panel reads as paced, not instant, without feeling sluggish?
