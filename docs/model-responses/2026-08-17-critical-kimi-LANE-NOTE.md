<!-- LANE: model-kimi-chase-geometry -->

# Kimi K3 lane — partial (honest record)

Three dispatch attempts:

1. `crit-kimi.md` (full `distributor.gd`, 1094 lines inlined) — returned EMPTY:
   `finish_reason: length`, 7000 completion tokens spent, 27372 chars of
   internal reasoning, no visible answer.
2. `crit-kimi2.md` (full `claim_jumper.gd` inlined) — same failure mode:
   empty, 25244 reasoning chars.
3. `crit-kimi3.md` — reissued with the MEASURED telemetry instead of raw source
   and a hard "under 500 words" instruction. Dispatched; see the verdict file
   if present.

Root cause of 1 and 2: this model reasons extremely long over large inlined
files and exhausts the output budget before emitting anything. The lesson,
recorded so the next session does not repeat it: give this lane DATA
(measurements, constants, a specific hypothesis to confirm or refute), not
whole files.

The chase question was ultimately answered by direct instrumented measurement
of the real web build rather than by static analysis — see
`docs/captures/2026-08-17-chase-numeric/` and the root-cause note in
`tests/boss_standoff_assay_test.gd`.
