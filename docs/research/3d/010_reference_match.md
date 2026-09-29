# 010 — Reference match, not asset load (VERIFIED 2026-09-29)
A build with nine green suites shipped a deformed hero, missing weapons and filtered coins. New proof step:
`scripts/ref_compare.py <founder ref> <capture> <board> --grade` puts the target and the game on one labelled
board and grades it against the founder's 9-item checklist with DeepSeek vision (~$0.001, a lead not a verdict).
Each machine-checkable FAIL becomes a test (weapons present, pickaxe above rim, coin material).
