# Protocol Portals — status (one line per task)

- SHIPPED 855515f — step 1: PortalSession / PortalSignals / QuizBank + 3 locked banks (Qwen: 0/33 problems), 155 checks.
- OPEN — step 2: glowing ladders in the Stage 1-3 .tscn files. Built + tested
  (tests/portal_ladder_test.gd ALL PASS, compile ALL PASS, first export 0 script errors,
  0 console errors). First gameplay-zoom capture review (DeepSeek vision) found defects:
  "▼" glyph renders as a box, weak halo, gold low contrast. Fix drafted by DeepSeek and applied
  (test ALL PASS). REMAINING: re-export + re-capture + DeepSeek notes + Jev
  `ladder_unmissable`/`ship` vote recorded here, then ship-to-master. The re-export command
  was denied in-session, so the gate has not run on the fixed build. NOT on master.
- Cost so far step 2: DeepSeek $0.0084 draft + $0.0009 vision + $0.0066 fix.

- IN FLIGHT — step 3: three learning pits (Reading Ring / Pressure Study / Claim Office) reachable
  from the ladders (E), whitepaper plate (founder Drive art for diamonds/gold, drawn SMOKE certificate),
  video shrine (official X URL, DONE after 8 s), examiner, 11-question quiz, result retry/proceed,
  climb back to the same world x, ScorecardGrant eligibility (no mint). Copy: Opus 5.5 (Muse blocked by
  OpenRouter 18+ setting). Qwen FACT_LOCK: PASS (0 defects).
  Jev round 2 (evidence 10_ladders/step3c, votes 90_gates/*.jev.txt):
  smoke BLOCK (examiner figure invisible on green) · diamonds SHIP 0.73 · gold SHIP 0.63.
  Round 3 (Ember redraw + trio spacing) in flight. Not on master until all three ship.
- Spend step 3: DeepSeek ~$0.075, Opus copy $0.104, Qwen audit $0.137, Jev $0.0001.

- OPEN — step 3 gauntlet stopped after 3 repair rounds (gauntlet-loop max). Final votes on build web7
  (evidence 10_ladders/step3e, votes 90_gates/*T*.jev.txt):
  smoke SHIP (0.51) · gold SHIP (0.66) · diamonds BLOCK (0.92).
  Diamonds blockers: (1) a debug spawn at exactly x=3050 in Stage 2 renders a fully black frame,
  reproducible twice on this build (x=2950/3150 are fine; the same spot was fine on web6) —
  unexplained, must be root-caused before shipping; (2) Assay Trio reads as three identical flat
  shapes, centre one overlapping the player; label crowds the divider.
  Per the rules nothing ships to master until all three are Jev SHIP.
- Lanes: Muse blocked (OpenRouter 18+ confirmation needed at openrouter.ai/settings/preferences);
  Opus 5.5 (non-batch) used for copy per founder.

- SHIPPED d035f52 (founder override, 2026-09-25) — step 3 on master. Diamonds fixes in flight with Opus 5.5.
- FIXED (verified on web export) — Stage 2 x=3050 black frame: MouthRingOutline was parented to the ring with show_behind_parent; now a sibling (Opus 5.5, $1.03). Frame luma 0.5 -> 67.0. Assay Trio redrawn as three distinct jurors.

- IN FLIGHT — TOUR REBUILD (founder brief 2026-09-25, docs/founder_briefs/2026-09-25/):
  part 1 DONE (a3 commit): PortalLadder is a real climb shaft — no E, uses enter/exit_ladder_zone + move_down,
  descends only at the shaft bottom (Opus 5.5, $1.63). Leader stills cut out in src/assets/portals/leaders/.
  part 2 (walkable tour + Companion + TourStop) and part 3 (tests) BLOCKED: OpenRouter HTTP 402
  "in_flight_budget_exhausted" — account at $71.95 of $75 used. Needs credits added. Not shipped; Jev not voted.
  Brief file: prompts/portals/tour_rebuild_opus_part2.md — rerun unchanged once credits are added.
