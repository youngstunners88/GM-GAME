extends SceneTree

## Headless test for the protocol portals build step 1.
## Run with: godot --headless --script res://tests/protocol_portals_test.gd
##
## class_name globals may not be registered under --script, so every script is
## preloaded by path here and referenced through those constants.

const PortalSignalsS := preload("res://src/protocol_portals/PortalSignals.gd")
const PortalSessionS := preload("res://src/protocol_portals/PortalSession.gd")
const QuizBankS := preload("res://src/protocol_portals/QuizBank.gd")

var _failures: int = 0


func _init() -> void:
    _test_banks()
    _test_transitions()
    _test_grading()
    _test_retry()
    _test_proceed_without_pass()
    _test_token_ids()

    if _failures == 0:
        print("PROTOCOL PORTALS: ALL PASS")
        quit(0)
    else:
        print("PROTOCOL PORTALS: FAILURES %d" % _failures)
        quit(1)


## Prints one line per check and counts failures.
func _check(ok: bool, label: String) -> void:
    if ok:
        print("[PASS] %s" % label)
    else:
        _failures += 1
        print("[FAIL] %s" % label)


## Builds a session already standing in QUIZ.
func _at_quiz(protocol: String):
    var S = PortalSignalsS.State
    var session = PortalSessionS.begin(1, protocol)
    session.transition(S.DESCENT)
    session.transition(S.STUDY_CHOICE)
    session.transition(S.EXAMINER_INTRO)
    session.transition(S.QUIZ)
    return session


func _test_banks() -> void:
    var prefixes := {"smoke": "S", "diamonds": "D", "gold": "G"}
    for protocol in ["smoke", "diamonds", "gold"]:
        var bank = QuizBankS.load_bank(protocol)
        _check(bank != null, "bank '%s' loads" % protocol)
        if bank == null:
            continue
        _check(bank.size() == PortalSignalsS.QUESTION_COUNT,
            "bank '%s' has %d questions" % [protocol, PortalSignalsS.QUESTION_COUNT])
        var key = bank.answer_key()
        _check(key.size() == PortalSignalsS.QUESTION_COUNT,
            "bank '%s' answer key has %d entries" % [protocol, PortalSignalsS.QUESTION_COUNT])
        for i in range(PortalSignalsS.QUESTION_COUNT):
            var q: Dictionary = bank.question(i)
            var expected: String = "%s%02d" % [prefixes[protocol], i + 1]
            _check(String(q.get("id", "")) == expected and String(q.get("fact_id", "")) == expected,
                "bank '%s' q%d id/fact_id == %s" % [protocol, i, expected])
            var options = q.get("options", [])
            var correct := int(q.get("correct", -1))
            _check(typeof(options) == TYPE_ARRAY and options.size() == 3
                and correct >= 0 and correct <= 2,
                "bank '%s' q%d has 3 options and correct in 0..2" % [protocol, i])
            _check(String(q.get("prompt", "")).length() > 0,
                "bank '%s' q%d has a prompt" % [protocol, i])


func _test_transitions() -> void:
    var S = PortalSignalsS.State
    var session = PortalSessionS.begin(1, "smoke")
    _check(session.state == S.WORLD, "begin() starts in WORLD")
    _check(session.transition(S.STUDY_CHOICE) == false, "WORLD -> STUDY_CHOICE is illegal")
    _check(session.transition(S.ASCENT) == false, "WORLD -> ASCENT is illegal")
    _check(session.transition(S.DESCENT) == true, "WORLD -> DESCENT is legal")
    _check(session.transition(S.WHITEPAPER) == false, "DESCENT -> WHITEPAPER is illegal")
    _check(session.transition(S.STUDY_CHOICE) == true, "DESCENT -> STUDY_CHOICE is legal")
    _check(session.transition(S.RESULT) == false, "STUDY_CHOICE -> RESULT is illegal")
    _check(session.transition(S.QUIZ) == false, "STUDY_CHOICE -> QUIZ is illegal")

    _check(session.choose_study("whitepaper") == true, "choose_study('whitepaper') is legal")
    _check(session.state == S.WHITEPAPER, "state is WHITEPAPER")
    _check(session.study_path == "whitepaper", "study_path recorded as whitepaper")
    _check(session.transition(S.STUDY_CHOICE) == true, "WHITEPAPER -> STUDY_CHOICE is legal")

    _check(session.choose_study("video") == true, "choose_study('video') is legal")
    _check(session.study_path == "video", "study_path recorded as video")
    _check(session.transition(S.STUDY_CHOICE) == true, "VIDEO -> STUDY_CHOICE is legal")
    _check(session.choose_study("nonsense") == false, "choose_study('nonsense') is rejected")

    _check(session.transition(S.EXAMINER_INTRO) == true, "STUDY_CHOICE -> EXAMINER_INTRO is legal")
    _check(session.transition(S.RESULT) == false, "EXAMINER_INTRO -> RESULT is illegal")
    _check(session.transition(S.QUIZ) == true, "EXAMINER_INTRO -> QUIZ is legal")
    _check(session.transition(S.DESCENT) == false, "QUIZ -> DESCENT is illegal")
    _check(session.transition(S.RESULT) == true, "QUIZ -> RESULT is legal")
    _check(session.transition(S.WORLD) == false, "RESULT -> WORLD is illegal")
    _check(session.transition(S.ASCENT) == true, "RESULT -> ASCENT is legal")
    _check(session.transition(S.WORLD) == true, "ASCENT -> WORLD is legal")
    _check(session.transition(S.DESCENT) == true, "WORLD -> DESCENT is legal on a second lap")


func _test_grading() -> void:
    var key: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]

    var perfect = _at_quiz("smoke")
    for i in range(PortalSignalsS.QUESTION_COUNT):
        perfect.answer(i, 0)
    var perfect_score = perfect.grade(key)
    _check(perfect_score == 11 and perfect.passed == true, "11/11 grades as a pass")
    _check(perfect.completed == true, "passing sets completed")

    var seven = _at_quiz("diamonds")
    for i in range(PortalSignalsS.QUESTION_COUNT):
        seven.answer(i, 0 if i < 7 else 1)
    var seven_score = seven.grade(key)
    _check(seven_score == 7 and seven.passed == true, "7/11 grades as a pass")

    var six = _at_quiz("gold")
    for i in range(PortalSignalsS.QUESTION_COUNT):
        six.answer(i, 0 if i < 6 else 1)
    var six_score = six.grade(key)
    _check(six_score == 6 and six.passed == false, "6/11 grades as a fail")
    _check(six.completed == false, "failing alone does not complete the run")

    var blank = _at_quiz("smoke")
    _check(blank.grade(key) == 0 and blank.passed == false, "unanswered questions score 0")


func _test_retry() -> void:
    var S = PortalSignalsS.State
    var key: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    var session = _at_quiz("smoke")
    for i in range(PortalSignalsS.QUESTION_COUNT):
        session.answer(i, 0)
    session.grade(key)
    _check(session.transition(S.RESULT) == true, "QUIZ -> RESULT before retry is legal")
    _check(session.transition(S.QUIZ) == true, "RESULT -> QUIZ retry is legal")

    var cleared := true
    for value in session.answers:
        if value != -1:
            cleared = false
    _check(cleared, "retry clears every answer back to -1")
    _check(session.score_correct == 0, "retry clears score_correct")
    _check(session.passed == false, "retry clears passed")


func _test_proceed_without_pass() -> void:
    var key: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    var session = _at_quiz("gold")
    _check(session.eligible_for_scorecard() == false, "fresh session is not scorecard eligible")
    for i in range(PortalSignalsS.QUESTION_COUNT):
        session.answer(i, 0 if i < 5 else 1)
    session.grade(key)
    _check(session.passed == false, "5/11 does not pass")
    session.proceed_without_pass()
    _check(session.completed == true, "proceed_without_pass sets completed")
    _check(session.proceeded_without_pass == true, "proceed_without_pass sets its own flag")
    _check(session.eligible_for_scorecard() == true, "proceeding without a pass grants eligibility")


func _test_token_ids() -> void:
    var ids = PortalSignalsS.TOKEN_IDS
    _check(ids.get("smoke") == "portal_smoke", "smoke token id is portal_smoke")
    _check(ids.get("diamonds") == "portal_diamonds", "diamonds token id is portal_diamonds")
    _check(ids.get("gold") == "portal_gold", "gold token id is portal_gold")

    var seen := {}
    var distinct_ok := true
    for protocol in ids.keys():
        var value: String = String(ids[protocol])
        if value.is_empty() or value.begins_with("s1_") or seen.has(value):
            distinct_ok = false
        seen[value] = true
    _check(distinct_ok, "token ids are non-empty, distinct, and outside the s1_ family")

    var key: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    var session = _at_quiz("diamonds")
    for i in range(PortalSignalsS.QUESTION_COUNT):
        session.answer(i, 0)
    session.grade(key)
    _check(session.nft_token_id == "portal_diamonds", "passed session records the protocol token id")
    var data: Dictionary = session.to_dict()
    _check(data.get("protocol") == "diamonds"
        and int(data.get("score_correct", -1)) == 11
        and data.get("passed") == true
        and data.get("completed") == true
        and data.get("nft_token_id") == "portal_diamonds",
        "to_dict() carries protocol, score, flags and token id")
