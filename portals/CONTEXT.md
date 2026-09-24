# Protocol Portals — context

Mission: glowing DOWNWARD ladders on the boss-approach path of Stages 1-3 lead to
short study rooms (whitepaper / official video), an 11-question examiner quiz from
LOCKED facts, and 3D ICP scorecard NFT eligibility on any completion.
Spec: founder's PROTOCOL_PORTALS_CLAUDE_CODE_SPEC. Skill: `.claude/skills/gm-game-protocol-portals`.

| Stage | Protocol | Glow | Examiner | Room | Ladder x |
|---|---|---|---|---|---|
| 1 Smoke Realm | SMOKE | neon green | Ember the Archivist | The Reading Ring | 2100 |
| 2 Crystal Caverns | DIAMONDS | cyan | The Assay Trio | The Pressure Study | 3300 |
| 3 Gold Rush | GOLD MINE | gold lantern | The Claim Recorder | The Claim Office | 3100 |

Routing (rate-limit lock): DeepSeek V4.1 Flash drafts code/JSON and describes
screenshots; Qwen 3.8 Max Prime fact-checks; Muse Spark voice only; Jev votes
(`scripts/jev.mjs`, decisions API); Opus 5.5 :batch escalation. Claude applies,
tests, exports, captures, ships via `scripts/ship-to-master.sh`.

Evidence: `10_ladders/` (gameplay-zoom captures), `90_gates/` (vision notes + Jev votes).
Traps: fresh `--import` before trusting a failure (stale class cache); DeepSeek
sometimes wraps output in ``` fences — strip before applying; the game font has
no "▼" glyph (renders as a box).
