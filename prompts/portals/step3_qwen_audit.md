You are the compliance auditor for an in-game "Protocol Portals" feature. Audit the files below against these LOCKED rules and reply with a first line exactly `FACT_LOCK: PASS` or `FACT_LOCK: FAIL`, then a JSON array of defects [{"file":"","line_hint":"","rule":"","problem":"","fix":""}] (empty array if none). No other prose.

RULES:
1. Official URLs only: paper smoke https://richs-crypto-projects.gitbook.io/smokering, diamonds https://richs-crypto-projects.gitbook.io/diamonds, gold https://richs-crypto-projects.gitbook.io/goldmine; video smoke https://x.com/DefiSparco/status/2082090949086519703, diamonds https://x.com/richland100/status/2003193678790283561, gold https://x.com/richland100/status/2070925446124839334. Each protocol must map to ITS OWN urls.
2. Pass bar 7/11; failing must offer BOTH retry and proceed-with-score; any completion grants scorecard eligibility.
3. The Examiner must never mint or call ScorecardGrant; ScorecardGrant must never mint, network, or call Meshy; no wallet flow.
4. No seed phrases, contract addresses, APYs, or invented protocol facts anywhere in code or copy (portal_copy.json is voice only — it must NOT state protocol facts beyond names).
5. Quiz banks: each question must test only its locked fact:
@include .claude/skills/gm-game-lane-qwen-portals/SKILL.md
Locked fact list S01-S11 / D01-D11 / G01-G11:
@include prompts/portals/locked_facts.txt
6. Video path must never block the quiz; skip/DONE enabled after ~8 s.
7. Ladder placement: Stage 1 x=2100 (boss trigger 2700), Stage 2 x=3300 (trigger 3700), Stage 3 x=3100 (trigger 3700); >=200 px from Blaze/Lounge/Vault/Reserve/Knox entries (Stage1 lounge 2350, blaze 1450; Stage2 vault ~2450, blaze 2100; Stage3 reserve 3420, knox 2690, blaze 2600).
8. Rooms are classrooms: not a DEX, not the Diamond Vault, not Fort Knox.

FILES:
@include src/protocol_portals/data/quiz_smoke.json
@include src/protocol_portals/data/quiz_diamonds.json
@include src/protocol_portals/data/quiz_gold.json
@include src/protocol_portals/data/portal_copy.json
@include src/protocol_portals/StudyRoom.gd
@include src/protocol_portals/Examiner.gd
@include src/protocol_portals/ScorecardGrant.gd
@include src/protocol_portals/VideoShrine.gd
@include src/protocol_portals/WhitepaperJump.gd
@include src/protocol_portals/PortalTravel.gd
