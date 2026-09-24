---
name: gm-game-protocol-portals-build
description: Build the full Protocol Portals feature — glowing ladders in Stages 1-3 PLUS the three learning pits beneath them (whitepaper prop, official X video shrine, examiner, 11-question quiz, result, ascent). TRIGGER on portals, ladders, study rooms, Ember, Assay Trio, Claim Recorder, quizzes, scorecard NFTs.
---


# Protocol Portals — full build (not props-only)


## 0. Orientation (never skip)
You are a fresh session until proven otherwise.
1. Read root `STATUS.md` and `portals/STATUS.md` if present.
2. Confirm step 1 already on master (`855515f`):
   - `src/protocol_portals/PortalSession.gd`
   - `src/protocol_portals/PortalSignals.gd`
   - `src/protocol_portals/QuizBank.gd`
   - `src/protocol_portals/data/quiz_{smoke,diamonds,gold}.json`
   - `tests/protocol_portals_test.gd` (155 checks)
3. Do NOT rebuild those files unless Qwen files a locked-fact defect.
4. Work ships ONLY via `scripts/ship-to-master.sh`. Only master reaches itch.
5. Rate-limit lock: this Claude session authors ≤5% of tokens. Dispatch the rest.


## 1. Mission (founder brief)
Secret-but-unmissable DOWNWARD ladders near each boss. Climbing down drops the player into a short classroom for that protocol. They study (whitepaper jump OR official X video), sit the examiner quiz, then climb the same shaft back. Completion always grants scorecard eligibility.


This session builds ALL THREE pits, not a ladder stub.


| Stage | Protocol | Glow | Near | Examiner | Room | Whitepaper art |
|---|---|---|---|---|---|---|
| 1 `src/level/level_01_smoke_realm.tscn` | SMOKE | neon green | Auditor | Ember the Archivist | The Reading Ring | DESIGN IN-SESSION (no JPG yet) — ash-ring / lounge neon certificate |
| 2 `src/level/level_02_crystal_caverns.tscn` | DIAMONDS | cyan facet pulse | Distributor | The Assay Trio | The Pressure Study | Drive JPG `1WfFMNpVSdFtrJBmOOY2VkRaVZJ1MkF5v` |
| 3 `src/level/level_03_gold_rush.tscn` | GOLD MINE | gold lantern pulse | Claim Jumper | The Claim Recorder | The Claim Office | Drive JPG `1fs50C83lpUEpFuMv7k0rj6BiKsbngzxg` |


Official study URLs — never substitute:
- SMOKE paper https://richs-crypto-projects.gitbook.io/smokering
- DIAMONDS paper https://richs-crypto-projects.gitbook.io/diamonds
- GOLD paper https://richs-crypto-projects.gitbook.io/goldmine
- SMOKE video https://x.com/DefiSparco/status/2082090949086519703
- DIAMONDS video https://x.com/richland100/status/2003193678790283561
- GOLD video https://x.com/richland100/status/2070925446124839334


Skip video after ~8s. If X embed fails, open the URL in WebView. Never a random recap.


## 2. Do-not-touch
- `src/level/ladder.tscn` / `ladder.gd` (climb ladders, vault exits)
- Blaze Rush, Smoke Lounge, Diamond Vault, Fort Knox entries
- Episode 2 runner / chambers
- `s1_boss` / `s1_blaze_rush` token ids
- Invented APYs, seed phrases, contract addresses


## 3. Architecture (write the missing pieces)
Already exists: Session, Signals, QuizBank, JSON banks.
Must now exist:








Separation: Session does not draw. Ladder does not grade. Examiner does not mint. ScorecardGrant does not call Meshy.


State machine already coded:
WORLD → DESCENT → STUDY_CHOICE → WHITEPAPER | VIDEO → EXAMINER_INTRO → QUIZ → RESULT → ASCENT → WORLD
Pass = 7/11. Fail = retry OR proceed with score. Completion always eligible.


## 4. Placement
Ladder on boss-approach path, readable BEFORE the fight, never inside boss hitbox, ≥200px from Blaze / Lounge / Vault / Reserve / Knox.
Entrance down. Exit up the same shaft.
Rooms are pockets, not a fourth stage. No long platforming. No 3D characters in 2D stages.


Claimed coords from the unpushed draft (re-measure against live ground; Level*.gd builds floor at runtime via LevelBase._floor_y_at):
- Stage 1 x≈2100 green
- Stage 2 x≈3300 cyan
- Stage 3 x≈3100 gold
Snap Y with the deferred floor helper. Do not hardcode a floating Y.


## 5. Whitepaper props
Physical plate in the room. Jump-on / interact loads the Gitbook overlay. EXIT plate returns to STUDY_CHOICE.
- Diamonds + Gold: Muse copies composition from the Drive JPGs (certificate / deed energy), not the pixel grid.
- Smoke: Muse designs the missing plate (see muse skill). DeepSeek builds the sprite + overlay.


## 6. Video shrines
One shrine per room, official URL only, skip after 8s, never blocks video-only players from the quiz. Place opposite the whitepaper so the STUDY_CHOICE read is left=paper / right=video (or paper on the lectern, shrine on the wall).


## 7. Examiners
2D props + dialogue box. They administer QuizBank. They never mint.
- Ember: archivist, green lamp, dry patience
- Assay Trio: three-voice crystal jury
- Claim Recorder: clerk with a stamp ledger


## 8. Definition of done (ALL three stages)
A stage is not done because a script exists.
1. PortalLadder instance in that stage `.tscn` on a PUSHED branch
2. Full room reachable: descent, study choice, paper overlay, video shrine, examiner, quiz UI, result (retry/proceed), ascent back to the same world x
3. Fresh export of current tree, 0 script errors
4. Playwright at GAMEPLAY ZOOM: ladder + room dividing line + examiner + both study props
5. Jev `ship` on `ladder_unmissable` AND `room_has_dividing_line` for that stage
6. `portals/STATUS.md` + root `STATUS.md` updated
7. `scripts/ship-to-master.sh` only after Jev ship on all three
If any gate fails, task stays OPEN. No override.


## 9. Improvements to what already shipped
Qwen must audit step-1 banks against founder facts S01–S11 / D01–D11 / G01–G11 before rooms go live. Fix only if a fact drifted. Do not rewrite voice until Muse + Qwen agree the fact is unchanged.
PortalSession is logic-only — keep it that way. Wire ScorecardGrant to `eligible_for_scorecard()` / `to_dict()` / `pending_icp`. Do not introduce a wallet.
