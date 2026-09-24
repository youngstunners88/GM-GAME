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
