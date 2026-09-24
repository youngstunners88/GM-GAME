You are drafting code for a Godot 4.3 GDScript web game (non-threaded HTML5 export, GL Compatibility). Output ONLY files, each wrapped exactly like:
=== FILE: <res-relative path> ===
<contents>
=== END ===
No prose outside the blocks.

Rules: GDScript 2.0 (Godot 4.3), 4-space indentation, static typing, well commented, no class_name that collides with an autoload, no network calls, no OS.execute / Expression / JavaScriptBridge.eval, no wallet or contract addresses. Keep the web build's thread-free constraint (no Thread).

FEATURE SPEC (authoritative excerpt):
4. Three pillars (teach and quiz only these)
SMOKE
Supply pressure — burns / buyback. SMOKE is culture + sink.
Smoke Lounge — multi-asset LP basket; rising pairs strengthen the burn engine.
Multi-chain / arb recycle — capture arb and recycle value into the ecosystem.
DIAMONDS
Scarcity path — BLAZE mints Diamonds; waves end; float is tight.
Vault + Crush — stake Diamonds; Crush Bonus forfeits extra Diamonds for more shares.
Bridge to GOLD — Diamonds required to mint GOLD; Handler absorbs first-cycle mint-side Diamonds.
GOLD MINE
Mining vest — ~100 days, ~1% per day; early claim forfeits the rest.
Fort Knox — stake GOLD for wBTC; Melt Bonus burns extra GOLD for a large share multiplier.
Gold Rush auctions — weekly forfeit GOLD to compete for XAUT.
Do not quiz seed phrases, contract addresses, or unverified APYs.
5. Room loop and state
WORLD → DESCENT → STUDY_CHOICE → WHITEPAPER | VIDEO → EXAMINER_INTRO → QUIZ → RESULT → ASCENT → WORLD
PortalSession fields: stage_id, protocol, study_path, answers[11], score_correct, passed, completed, proceeded_without_pass, nft_token_id, pending_icp.
Pass bar = 7/11. Fail = retry quiz OR proceed with score. Completion always grants scorecard eligibility.
6. Whitepaper jump + lazy video
Whitepaper is a physical prop. Jumping onto it loads the stage Gitbook in an overlay. EXIT plate returns to STUDY_CHOICE.
Video shrine plays the official X media. Allow skip after a short minimum watch (~8s). Never block video-only players from the quiz.
7. Examiner and quiz banks
11 multiple-choice questions, 3 options, one correct. Claude may rephrase for character voice but must not change the fact.
SMOKE S01–S11 (facts)
S01 SMOKE is the culture + sink / burn token.
S02 Lounge LP basket can strengthen buy/burn as pairs rise.
S03 Arb is captured and recycled, not ignored.
S04 Rising Lounge pairs can increase burn power.
S05 This room is a classroom, not a DEX.
S06 Whitepaper teaches the real rules before the quiz.
S07 A burn removes tokens from circulating supply.
S08 Multi-chain supply frames the arb question.
S09 Ember the Archivist administers the test.
S10 Video path is allowed.
S11 Pass returns to Stage 1 and records the NFT.
DIAMONDS D01–D11 (facts)
D01 BLAZE is on the Diamond mint path.
D02 Emission ending + sinks create scarcity.
D03 Vault is staking Diamonds for shares/rewards.
D04 Crush Bonus forfeits extra Diamonds for more shares.
D05 Diamonds are required to mint GOLD.
D06 Handler absorbs first-cycle mint-side Diamonds instead of dumping the chart.
D07 Assay Trio administers the test.
D08 This room is not the Diamond Vault set-piece.
D09 Certificates flavour = mine ownership / exclusive access (keep high-level).
D10 Video path is allowed.
D11 Completion grants Diamonds scorecard NFT on ICP.
GOLD G01–G11 (facts)
G01 ~100-day vest, ~1% per day.
G02 Early claim forfeits unvested GOLD.
G03 Fort Knox pays wBTC on staked GOLD.
G04 Melt Bonus burns extra GOLD for a large share multiplier.
G05 Gold Rush auctions compete for XAUT.
G06 Mint path can include ETH or ETH + Diamonds.
G07 Claim Recorder administers the test.
G08 This room is not Fort Knox.
G09 Long locks weight commitment / shares.
G10 Video path is allowed.
G11 Completion grants Gold scorecard NFT on ICP.
8. Folder map and architecture
res://src/protocol_portals/PortalSession.gd, PortalSignals.gd, PortalLadder.gd, StudyRoom.tscn, WhitepaperJump.gd, VideoShrine.gd, Examiner.gd, QuizBank.gd, ScorecardGrant.gd, JevPortalGate.gd
data/quiz_smoke.json, quiz_diamonds.json, quiz_gold.json
rooms/smoke/ReadingRing.tscn, rooms/diamonds/PressureStudy.tscn, rooms/gold/ClaimOffice.tscn
examiners/Ember.tscn, AssayTrio.tscn, ClaimRecorder.tscn
Session does not draw. Ladder does not grade. Examiner does not mint. ScorecardGrant does not call Meshy. Meshy + Blender are content pipeline, not runtime 80M-poly imports.
Interfaces: IStudySource, IExaminerView, INftGrant, IPortalGate.
9. ICP token ids
portal_smoke, portal_diamonds, portal_gold. Do not collide with s1_boss / s1_blaze_rush family.
Metadata: protocol, stage_id, score_correct, passed, study_path, minted_at, 2D image, GLB animation_url.
Phase 1 soulbound. One card per protocol per player. Art must include official protocol logo + score plate.

DELIVER these files for build step 1 ("folder tree + PortalSession" + quiz banks):

1. src/protocol_portals/PortalSignals.gd — `extends RefCounted`, `class_name PortalSignals`. Only constants: the state names (WORLD, DESCENT, STUDY_CHOICE, WHITEPAPER, VIDEO, EXAMINER_INTRO, QUIZ, RESULT, ASCENT) as an enum `State`, PASS_BAR := 7, QUESTION_COUNT := 11, VIDEO_MIN_WATCH_SEC := 8.0, protocol ids "smoke","diamonds","gold", and TOKEN_IDS dict protocol->"portal_smoke"/"portal_diamonds"/"portal_gold".

2. src/protocol_portals/PortalSession.gd — `extends RefCounted`, `class_name PortalSession`. Pure state, draws nothing, grades via answers compared to a supplied answer key, never mints. Fields exactly: stage_id:int, protocol:String, study_path:String ("" / "whitepaper" / "video"), answers:Array[int] (size 11, -1 = unanswered), score_correct:int, passed:bool, completed:bool, proceeded_without_pass:bool, nft_token_id:String, pending_icp:bool, plus state:int (PortalSignals.State). Signals: state_changed(from:int, to:int), graded(score:int, passed:bool). Methods: static func begin(stage_id:int, protocol:String) -> PortalSession; func transition(to:int) -> bool enforcing ONLY the legal edges of the loop WORLD→DESCENT→STUDY_CHOICE→(WHITEPAPER|VIDEO)→STUDY_CHOICE (return from overlay) and STUDY_CHOICE→EXAMINER_INTRO→QUIZ→RESULT; RESULT→QUIZ (retry, clears answers/score) ; RESULT→ASCENT→WORLD. choose_study(path). answer(index:int, choice:int). grade(answer_key:Array[int]) -> int sets score_correct/passed(>=7). func proceed_without_pass() marks completed=true, proceeded_without_pass=true. On pass, completed=true. func eligible_for_scorecard() -> bool returns completed. func to_dict() -> Dictionary (for save + ICP metadata: protocol, stage_id, score_correct, passed, study_path, completed, proceeded_without_pass, nft_token_id). nft_token_id set from PortalSignals.TOKEN_IDS when completed.

3. src/protocol_portals/QuizBank.gd — `extends RefCounted`, `class_name QuizBank`. static func load_bank(protocol:String) -> QuizBank reading res://src/protocol_portals/data/quiz_<protocol>.json with FileAccess; validates exactly 11 questions, each with id, fact_id, prompt, options (exactly 3 strings), correct (0..2); push_error and return null on invalid. Accessors: size(), question(i) -> Dictionary, answer_key() -> Array[int].

4. src/protocol_portals/data/quiz_smoke.json, quiz_diamonds.json, quiz_gold.json — JSON object {"protocol": "...", "examiner": "...", "questions":[...]} with 11 questions each, ids S01..S11 / D01..D11 / G01..G11 mapping 1:1 to the LOCKED facts above (fact_id equals the id). Each question tests exactly its locked fact and nothing else; one correct option that states the fact faithfully; two plausible but clearly wrong distractors. Do NOT invent numbers, APYs, addresses, seed phrases, dates, or any claim beyond the fact text. Vary the position of the correct option (use 0,1,2 roughly evenly). Examiners: smoke "Ember the Archivist", diamonds "The Assay Trio", gold "The Claim Recorder". Plain neutral wording (voice styling comes later).

5. tests/protocol_portals_test.gd — `extends SceneTree` headless test run with `godot --headless --script`. Checks: each bank loads, has 11 questions, 3 options each, fact_id sequence exact; session legal/illegal transitions; grade 7/11 passes, 6/11 fails; retry clears answers; proceed_without_pass makes eligible_for_scorecard true; token ids are portal_smoke/portal_diamonds/portal_gold and distinct from any string starting "s1_". Print "[PASS] ..." / "[FAIL] ..." per check and final "PROTOCOL PORTALS: ALL PASS" or "PROTOCOL PORTALS: FAILURES n", then quit(0 or 1). Note: class_name globals may not be registered under --script, so preload the scripts by path (const PortalSessionS := preload("res://src/protocol_portals/PortalSession.gd") etc.) and use those.
