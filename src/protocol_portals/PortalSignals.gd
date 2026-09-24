extends RefCounted
class_name PortalSignals

## Shared, read-only vocabulary for the protocol portals feature.
## This script holds constants only: no state, no behaviour, no drawing.

## Room loop states. WORLD -> DESCENT -> STUDY_CHOICE -> (WHITEPAPER|VIDEO)
## -> STUDY_CHOICE (overlay return) -> EXAMINER_INTRO -> QUIZ -> RESULT
## -> (QUIZ retry | ASCENT) and ASCENT -> WORLD.
enum State {
    WORLD,
    DESCENT,
    STUDY_CHOICE,
    WHITEPAPER,
    VIDEO,
    EXAMINER_INTRO,
    QUIZ,
    RESULT,
    ASCENT,
}

## Correct answers required to pass the 11-question quiz.
const PASS_BAR: int = 7

## Every protocol quiz bank has exactly this many questions.
const QUESTION_COUNT: int = 11

## Minimum watch time (seconds) before the video shrine allows a skip.
const VIDEO_MIN_WATCH_SEC: float = 8.0

## Protocol ids used by stage data and metadata.
const PROTOCOL_SMOKE: String = "smoke"
const PROTOCOL_DIAMONDS: String = "diamonds"
const PROTOCOL_GOLD: String = "gold"

## ICP token ids, one soulbound scorecard per protocol per player.
## Deliberately distinct from the s1_boss / s1_blaze_rush family.
const TOKEN_IDS: Dictionary = {
    PROTOCOL_SMOKE: "portal_smoke",
    PROTOCOL_DIAMONDS: "portal_diamonds",
    PROTOCOL_GOLD: "portal_gold",
}
