---
name: gm-game-protocol-portals
description: Build and ship the Protocol Portals feature for Lil Blunt (GM-GAME) — glowing downward ladders in Stages 1-3 leading to study rooms, examiner quizzes, and 3D ICP scorecard NFT eligibility. TRIGGER on any mention of portals, ladders, study rooms, examiners, Ember, Assay Trio, Claim Recorder, protocol quizzes, or scorecard NFTs in the GM-GAME repo.
---

# GM-GAME Protocol Portals — Build Skill

## 0. Orientation FIRST (ICM — never skip)
You may be a fresh session. Before writing one line of code:
1. Read `portals/CONTEXT.md` and `portals/STATUS.md` in the repo root. They are
   the single source of truth for what is done, what is in flight, and what is next.
2. If they don't exist, create them using the workspace scaffold in §8 below.
3. Check how far your branch is behind master (ship gate). Work ships ONLY via
   `scripts/ship-to-master.sh` — the same anti-stranding machinery from the
   Episode 2 session. Never end a session with unmerged portal work.
4. Load `DELEGATION_CHARTER.md` if present: drafting goes to
   `deepseek/deepseek-v4.1-flash`; Claude Code orchestrates, applies, verifies.

## 1. Mission
Embed secret-but-unmissable DOWNWARD portals in Stages 1-3 so players learn
SMOKE, DIAMONDS, and GOLD MINE before a short examiner quiz. Completing any
room grants 3D ICP scorecard NFT eligibility.

## 2. NON-NEGOTIABLE COMPLETION GATE
A portal task is DONE only when ALL of the following are true. "Code written"
or "scene edited" is NOT done:
- The ladder instance exists in the stage's `.tscn` (not only in a branch-only file).
- A fresh export of the current master merge runs with 0 script errors.
- Playwright captures the ladder at GAMEPLAY ZOOM (not editor zoom, not zoomed-in).
- Jev returns `ship` on `ladder_unmissable` for that stage.
- STATUS.md updated and work shipped to master via `scripts/ship-to-master.sh`.
If any step fails, the task stays OPEN in STATUS.md. This is the rule that
prevents another "I played the game and the ladders aren't there" incident.

## 3. Stage mapping
| Stage | Protocol | Glow | Near (boss-approach) | Examiner | Room |
|---|---|---|---|---|---|
| 1 Smoke Realm | SMOKE | Neon green | Auditor | Ember the Archivist | The Reading Ring |
| 2 Crystal Caverns | DIAMONDS | Cyan facet pulse | Distributor | The Assay Trio | The Pressure Study |
| 3 Gold Rush | GOLD MINE | Gold lantern pulse | Claim Jumper | The Claim Recorder | The Claim Office |

Placement rules: ladder on the boss-approach path, readable BEFORE the fight,
never inside the boss hitbox, never on Blaze Rush / Lounge / Diamond Vault /
Fort Knox entries. Entrance is downward; exit climbs back up the same shaft.
Rooms are short learning pockets — not a fourth stage.

## 4. Architecture (res://)
```
src/protocol_portals/
  PortalSession.gd      # state only, never draws
  PortalSignals.gd      # autoload signals
  PortalLadder.gd       # glowing ladder, interaction, descent warp
  StudyRoom.tscn        # shared room, three skins
  WhitepaperJump.gd     # physical whitepaper prop -> Gitbook overlay
  VideoShrine.gd        # official X media, skip after ~8s
  Examiner.gd           # administers quiz, never mints
  QuizBank.gd           # loads locked JSON banks
  ScorecardGrant.gd     # NFT eligibility + mint request, never calls Meshy
  JevPortalGate.gd      # collects evidence, calls Jev decisions API
data/quiz_smoke.json  quiz_diamonds.json  quiz_gold.json
rooms/smoke/ReadingRing.tscn
rooms/diamonds/PressureStudy.tscn
rooms/gold/ClaimOffice.tscn
examiners/Ember.tscn  AssayTrio.tscn  ClaimRecorder.tscn
```
Separation of duties: Session does not draw. Ladder does not grade. Examiner
does not mint. ScorecardGrant does not call Meshy. Meshy/Blender are content
pipeline, not runtime 80M-poly imports. Interfaces: IStudySource,
IExaminerView, INftGrant, IPortalGate.

Stage 1 ships NOW into `level/level_01_smoke_realm.tscn`. Stages 2-3 reuse
the SAME `PortalLadder.tscn` + `StudyRoom.tscn` — adding them later must be a
one-line scene instance, not a rewrite.

## 5. State machine (PortalSession)
WORLD -> DESCENT -> STUDY_CHOICE -> WHITEPAPER | VIDEO -> EXAMINER_INTRO ->
QUIZ -> RESULT -> ASCENT -> WORLD
Fields: stage_id, protocol, study_path, answers[11], score_correct, passed,
completed, proceeded_without_pass, nft_token_id, pending_icp.
Pass bar = 7/11. Fail = retry quiz OR proceed with score. Completion ALWAYS
grants scorecard eligibility (even without pass).

## 6. Study sources (official URLs only — never substitute)
- Whitepapers (Gitbook overlay): SmokeRing https://richs-crypto-projects.gitbook.io/smokering · DIAMONDS https://richs-crypto-projects.gitbook.io/diamonds · GOLD MINE https://richs-crypto-projects.gitbook.io/goldmine
- Videos (X shrine, skip allowed after ~8s, NEVER block video-only players):
  Stage 1 https://x.com/DefiSparco/status/2082090949086519703 ·
  Stage 2 https://x.com/richland100/status/2003193678790283561 ·
  Stage 3 https://x.com/richland100/status/2070925446124839334
If an X embed fails in-engine, open the URL in WebView. Never swap in a random recap.

## 7. Quiz banks (LOCKED facts)
11 MCQs each, 3 options, one correct. Facts live in the founder spec §7
(S01-S11, D01-D11, G01-G11). Do NOT invent facts, seed phrases, contract
addresses, or unverified APYs. Voice/rephrasing may go to the muse lane
(`meta/muse-spark-1.3`) but the fact must not change. One fact-check pass of
the generated JSON against the spec by `qwen/qwen3.8-max-prime`.

## 8. Workspace scaffold (create once, keep updated)
```
portals/
  CONTEXT.md     # mission, stage map, routing catalog, open questions
  STATUS.md      # one line per task: OPEN / IN FLIGHT / SHIPPED + commit hash
  10_ladders/    # per-stage ladder notes + Playwright frame paths
  20_rooms/      # room skin notes, whitepaper/video overlay state
  30_quiz/       # bank drafts + fact-check results
  40_nft/        # grant flow, token ids, mint results
  90_gates/      # Jev votes + evidence packs
```
Walk test: a fresh agent must orient from these files alone. Update STATUS.md
every time a task changes state — an unwritten status is a lost session.

## 9. Build order
Folder tree + PortalSession -> Stage 1 glowing ladder + screenshot ->
StudyRoom + Smoke skin -> whitepaper/video overlays -> Examiner +
quiz_smoke.json -> Result UI -> ScorecardGrant token ids -> Stages 2-3
instances -> media pipeline (see gm-game-media-pipeline) -> Jev gauntlet
(see gm-game-jev-gauntlet) -> STATUS.md -> ship.

## 10. Godot traps (learned the hard way, $2.20 of the founder's money)
- STALE CLASS CACHE: after merging branches, `.godot` caches can hide classes
  (the Ep2Palette incident). Run a FRESH IMPORT before believing any test
  failure. Do not burn a model round-trip on a cache artifact.
- Verify in the exported build, not just the editor.
- Pack budget: master export was ~155.6 MB (~43 MB headroom) — the portal
  rooms must fit inside it.

## 11. Non-goals
No wBTC/ETH/Robinhood parking NFTs in these rooms. No pay-to-win quiz. Not
replacing Diamond Vault or Fort Knox (that's gm-game-protocol-setpieces — do
not merge). No long platforming in study rooms. No 3D characters in 2D stages.
