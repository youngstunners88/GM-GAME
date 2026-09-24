extends RefCounted
class_name PortalSession

## Pure run state for one protocol portal attempt.
## - Draws nothing.
## - Grades only by comparing recorded answers to a supplied answer key.
## - Never mints and never talks to ICP; ScorecardGrant.gd handles that.
##
## The room loop is enforced by transition(); every other method only mutates
## data and never changes the state machine on its own.

const Signals := preload("res://src/protocol_portals/PortalSignals.gd")

## Emitted after a legal transition, with the previous and new state.
signal state_changed(from: int, to: int)

## Emitted by grade() with the final score and pass flag.
signal graded(score: int, passed: bool)

var stage_id: int = 0
var protocol: String = ""
## "" / "whitepaper" / "video"
var study_path: String = ""
## Always QUESTION_COUNT entries; -1 means unanswered.
var answers: Array[int] = []
var score_correct: int = 0
var passed: bool = false
var completed: bool = false
var proceeded_without_pass: bool = false
var nft_token_id: String = ""
var pending_icp: bool = false
var state: int = Signals.State.WORLD


## Creates a fresh session at the top of the loop.
static func begin(stage_id: int, protocol: String) -> PortalSession:
    var session := PortalSession.new()
    session.stage_id = stage_id
    session.protocol = protocol.to_lower()
    session.study_path = ""
    session.answers = _blank_answers()
    session.score_correct = 0
    session.passed = false
    session.completed = false
    session.proceeded_without_pass = false
    session.nft_token_id = ""
    session.pending_icp = false
    session.state = Signals.State.WORLD
    return session


## An array of QUESTION_COUNT entries, all -1 (unanswered).
static func _blank_answers() -> Array[int]:
    var blank: Array[int] = []
    blank.resize(Signals.QUESTION_COUNT)
    blank.fill(-1)
    return blank


## Returns true only for the legal edges of the room loop.
## WORLD -> DESCENT -> STUDY_CHOICE
## STUDY_CHOICE -> WHITEPAPER | VIDEO | EXAMINER_INTRO
## WHITEPAPER | VIDEO -> STUDY_CHOICE  (return from the overlay)
## EXAMINER_INTRO -> QUIZ -> RESULT
## RESULT -> QUIZ (retry) | RESULT -> ASCENT -> WORLD
static func _is_legal_edge(from_state: int, to_state: int) -> bool:
    match from_state:
        Signals.State.WORLD:
            return to_state == Signals.State.DESCENT
        Signals.State.DESCENT:
            return to_state == Signals.State.STUDY_CHOICE
        Signals.State.STUDY_CHOICE:
            return (to_state == Signals.State.WHITEPAPER
                or to_state == Signals.State.VIDEO
                or to_state == Signals.State.EXAMINER_INTRO)
        Signals.State.WHITEPAPER, Signals.State.VIDEO:
            return to_state == Signals.State.STUDY_CHOICE
        Signals.State.EXAMINER_INTRO:
            return to_state == Signals.State.QUIZ
        Signals.State.QUIZ:
            return to_state == Signals.State.RESULT
        Signals.State.RESULT:
            return to_state == Signals.State.QUIZ or to_state == Signals.State.ASCENT
        Signals.State.ASCENT:
            return to_state == Signals.State.WORLD
    return false


## Moves the session to `to` when that edge is legal. Returns false otherwise.
## A RESULT -> QUIZ retry wipes the previous answers, score and pass flag.
func transition(to: int) -> bool:
    if not _is_legal_edge(state, to):
        return false
    var from_state: int = state
    if from_state == Signals.State.RESULT and to == Signals.State.QUIZ:
        _reset_for_retry()
    state = to
    state_changed.emit(from_state, to)
    return true


## Records the study path and moves into the matching overlay.
## Only legal while sitting in STUDY_CHOICE.
func choose_study(path: String) -> bool:
    if state != Signals.State.STUDY_CHOICE:
        return false
    var target: int = -1
    match path:
        "whitepaper":
            target = Signals.State.WHITEPAPER
        "video":
            target = Signals.State.VIDEO
        _:
            return false
    study_path = path
    return transition(target)


## Records one answer (0..2). -1 means unanswered and is never stored here.
func answer(index: int, choice: int) -> bool:
    if index < 0 or index >= Signals.QUESTION_COUNT:
        return false
    if choice < 0 or choice > 2:
        return false
    if answers.size() != Signals.QUESTION_COUNT:
        answers = _blank_answers()
    answers[index] = choice
    return true


## Compares the recorded answers with a supplied key and sets the score.
## Passing also completes the run and assigns the protocol token id.
func grade(answer_key: Array[int]) -> int:
    var score: int = 0
    for i in range(Signals.QUESTION_COUNT):
        if i >= answers.size() or i >= answer_key.size():
            continue
        var given: int = answers[i]
        if given >= 0 and given == answer_key[i]:
            score += 1
    score_correct = score
    passed = score >= Signals.PASS_BAR
    if passed:
        _mark_completed()
    graded.emit(score_correct, passed)
    return score_correct


## Fail path escape hatch: the player keeps the score and still completes.
func proceed_without_pass() -> void:
    proceeded_without_pass = true
    _mark_completed()


## Completion always grants scorecard eligibility, pass or not.
func eligible_for_scorecard() -> bool:
    return completed


## Flat snapshot used for local saves and for ICP scorecard metadata.
func to_dict() -> Dictionary:
    return {
        "protocol": protocol,
        "stage_id": stage_id,
        "score_correct": score_correct,
        "passed": passed,
        "study_path": study_path,
        "completed": completed,
        "proceeded_without_pass": proceeded_without_pass,
        "nft_token_id": nft_token_id,
    }


## Wipes quiz progress so a retry starts from a clean sheet.
func _reset_for_retry() -> void:
    answers = _blank_answers()
    score_correct = 0
    passed = false


## Marks the run complete and pins the protocol's ICP token id.
func _mark_completed() -> void:
    completed = true
    if nft_token_id.is_empty():
        nft_token_id = String(Signals.TOKEN_IDS.get(protocol, ""))
    # The scorecard is only "pending" until ScorecardGrant confirms the mint.
    pending_icp = true
