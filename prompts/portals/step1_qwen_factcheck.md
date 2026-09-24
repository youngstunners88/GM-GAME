You are a strict fact-checker. Below are LOCKED facts and three quiz banks. For EACH question, verify: (1) the option at index `correct` states its locked fact faithfully and adds nothing beyond it; (2) neither distractor is also arguably true per the locked facts; (3) no invented numbers, APYs, addresses, dates, or claims. Reply ONLY with a JSON array of problems: [{"id":"S04","problem":"...","fix":{"prompt":"...","options":["...","...","..."],"correct":N}}]. Return [] if all 33 are clean. Keep fixes minimal and faithful to the locked fact.

LOCKED FACTS:
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

BANKS:
{
    "protocol": "smoke",
    "examiner": "Ember the Archivist",
    "questions": [
        {
            "id": "S01",
            "fact_id": "S01",
            "prompt": "What is the primary role of SMOKE?",
            "options": [
                "SMOKE is the culture token and the sink / burn token.",
                "SMOKE is a stablecoin pegged to XAUT.",
                "SMOKE is only used as a quiz reward."
            ],
            "correct": 0
        },
        {
            "id": "S02",
            "fact_id": "S02",
            "prompt": "What can rising Lounge LP basket pairs do to the buy/burn engine?",
            "options": [
                "They have no effect on the buy/burn engine.",
                "They can strengthen the buy/burn engine.",
                "They convert the basket into GOLD."
            ],
            "correct": 1
        },
        {
            "id": "S03",
            "fact_id": "S03",
            "prompt": "How does the ecosystem treat arbitrage?",
            "options": [
                "It ignores arbitrage and lets the value leave.",
                "It captures arbitrage and recycles the value back into the ecosystem.",
                "It bans all multi-chain activity."
            ],
            "correct": 1
        },
        {
            "id": "S04",
            "fact_id": "S04",
            "prompt": "What can rising Lounge pairs do?",
            "options": [
                "They reduce burn power.",
                "They replace the burn engine with the Vault.",
                "They can increase burn power."
            ],
            "correct": 2
        },
        {
            "id": "S05",
            "fact_id": "S05",
            "prompt": "What kind of room is this?",
            "options": [
                "A classroom.",
                "A DEX where you trade tokens.",
                "A staking vault."
            ],
            "correct": 0
        },
        {
            "id": "S06",
            "fact_id": "S06",
            "prompt": "What does the Whitepaper prop do in this room?",
            "options": [
                "It mints the scorecard NFT.",
                "It teaches the real rules before the quiz.",
                "It replaces the quiz entirely."
            ],
            "correct": 1
        },
        {
            "id": "S07",
            "fact_id": "S07",
            "prompt": "What does a burn do to a token?",
            "options": [
                "It locks the token in a vault forever.",
                "It increases the circulating supply.",
                "It removes the token from circulating supply."
            ],
            "correct": 2
        },
        {
            "id": "S08",
            "fact_id": "S08",
            "prompt": "What does multi-chain supply frame?",
            "options": [
                "The arbitrage question.",
                "The GOLD vesting schedule.",
                "The quiz pass bar."
            ],
            "correct": 0
        },
        {
            "id": "S09",
            "fact_id": "S09",
            "prompt": "Who administers the test in the SMOKE room?",
            "options": [
                "The Assay Trio.",
                "Ember the Archivist.",
                "The Claim Recorder."
            ],
            "correct": 1
        },
        {
            "id": "S10",
            "fact_id": "S10",
            "prompt": "Is the video study path allowed?",
            "options": [
                "No, only the Whitepaper counts.",
                "No, video is blocked until you pass.",
                "Yes, the video path is allowed."
            ],
            "correct": 2
        },
        {
            "id": "S11",
            "fact_id": "S11",
            "prompt": "What happens when you pass in the SMOKE room?",
            "options": [
                "You return to Stage 1 and the NFT is recorded.",
                "You skip straight to the Gold Rush auction.",
                "You leave the room without any record."
            ],
            "correct": 0
        }
    ]
}
{
    "protocol": "diamonds",
    "examiner": "The Assay Trio",
    "questions": [
        {
            "id": "D01",
            "fact_id": "D01",
            "prompt": "What role does BLAZE play on the Diamond path?",
            "options": [
                "BLAZE is on the Diamond mint path.",
                "BLAZE only pays out wBTC.",
                "BLAZE replaces the Vault."
            ],
            "correct": 0
        },
        {
            "id": "D02",
            "fact_id": "D02",
            "prompt": "What creates scarcity in the DIAMONDS protocol?",
            "options": [
                "An unlimited emission schedule.",
                "Emission ending combined with sinks.",
                "Removing all sinks from the protocol."
            ],
            "correct": 1
        },
        {
            "id": "D03",
            "fact_id": "D03",
            "prompt": "What is the Vault?",
            "options": [
                "A place to mint GOLD without staking anything.",
                "A market for swapping SMOKE pairs.",
                "Staking Diamonds for shares and rewards."
            ],
            "correct": 2
        },
        {
            "id": "D04",
            "fact_id": "D04",
            "prompt": "What does the Crush Bonus do?",
            "options": [
                "It forfeits extra Diamonds for more shares.",
                "It refunds Diamonds and reduces shares.",
                "It burns GOLD to buy XAUT."
            ],
            "correct": 0
        },
        {
            "id": "D05",
            "fact_id": "D05",
            "prompt": "Which asset is required to mint GOLD?",
            "options": [
                "SMOKE.",
                "Diamonds.",
                "wBTC."
            ],
            "correct": 1
        },
        {
            "id": "D06",
            "fact_id": "D06",
            "prompt": "What does the Handler do with first-cycle mint-side Diamonds?",
            "options": [
                "It dumps them straight onto the chart.",
                "It burns them and closes the mint path.",
                "It absorbs them instead of dumping the chart."
            ],
            "correct": 2
        },
        {
            "id": "D07",
            "fact_id": "D07",
            "prompt": "Who administers the test in the DIAMONDS room?",
            "options": [
                "The Assay Trio.",
                "Ember the Archivist.",
                "The Claim Recorder."
            ],
            "correct": 0
        },
        {
            "id": "D08",
            "fact_id": "D08",
            "prompt": "What is this DIAMONDS room?",
            "options": [
                "The Diamond Vault set-piece itself.",
                "A study room, not the Diamond Vault set-piece.",
                "Fort Knox."
            ],
            "correct": 1
        },
        {
            "id": "D09",
            "fact_id": "D09",
            "prompt": "What does the certificates flavour represent, at a high level?",
            "options": [
                "Ownership of a seed phrase.",
                "A fixed annual percentage yield.",
                "Mine ownership and exclusive access."
            ],
            "correct": 2
        },
        {
            "id": "D10",
            "fact_id": "D10",
            "prompt": "Is the video study path allowed?",
            "options": [
                "Yes, the video path is allowed.",
                "No, video-only players cannot reach the quiz.",
                "Only if you hold a certificate."
            ],
            "correct": 0
        },
        {
            "id": "D11",
            "fact_id": "D11",
            "prompt": "What does completing this room grant?",
            "options": [
                "A testnet SMOKE faucet.",
                "A Diamonds scorecard NFT on ICP.",
                "An automatic GOLD allocation."
            ],
            "correct": 1
        }
    ]
}
{
    "protocol": "gold",
    "examiner": "The Claim Recorder",
    "questions": [
        {
            "id": "G01",
            "fact_id": "G01",
            "prompt": "What does the mining vest look like?",
            "options": [
                "About 100 days, about 1% per day.",
                "About 10 days, about 10% per day.",
                "About 365 days with no release at all."
            ],
            "correct": 0
        },
        {
            "id": "G02",
            "fact_id": "G02",
            "prompt": "What happens if you claim early?",
            "options": [
                "You receive double the unvested GOLD.",
                "You forfeit the unvested GOLD.",
                "Nothing changes and the vest continues as normal."
            ],
            "correct": 1
        },
        {
            "id": "G03",
            "fact_id": "G03",
            "prompt": "What does Fort Knox pay on staked GOLD?",
            "options": [
                "XAUT.",
                "SMOKE.",
                "wBTC."
            ],
            "correct": 2
        },
        {
            "id": "G04",
            "fact_id": "G04",
            "prompt": "What does the Melt Bonus do?",
            "options": [
                "It burns extra GOLD for a large share multiplier.",
                "It refunds GOLD and lowers the share multiplier.",
                "It converts GOLD into Diamonds instantly."
            ],
            "correct": 0
        },
        {
            "id": "G05",
            "fact_id": "G05",
            "prompt": "What do Gold Rush auctions compete for?",
            "options": [
                "wBTC.",
                "XAUT.",
                "Diamonds."
            ],
            "correct": 1
        },
        {
            "id": "G06",
            "fact_id": "G06",
            "prompt": "What can the mint path include?",
            "options": [
                "Only SMOKE.",
                "Only wBTC.",
                "ETH, or ETH plus Diamonds."
            ],
            "correct": 2
        },
        {
            "id": "G07",
            "fact_id": "G07",
            "prompt": "Who administers the test in the GOLD room?",
            "options": [
                "The Claim Recorder.",
                "The Assay Trio.",
                "Ember the Archivist."
            ],
            "correct": 0
        },
        {
            "id": "G08",
            "fact_id": "G08",
            "prompt": "What is this GOLD room?",
            "options": [
                "Fort Knox itself.",
                "A study room, not Fort Knox.",
                "A Gold Rush auction house."
            ],
            "correct": 1
        },
        {
            "id": "G09",
            "fact_id": "G09",
            "prompt": "What do long locks do?",
            "options": [
                "They remove all share weight.",
                "They only affect SMOKE burns.",
                "They weight commitment and shares."
            ],
            "correct": 2
        },
        {
            "id": "G10",
            "fact_id": "G10",
            "prompt": "Is the video study path allowed?",
            "options": [
                "Yes, the video path is allowed.",
                "No, only the Whitepaper can be studied.",
                "Only after the vest fully completes."
            ],
            "correct": 0
        },
        {
            "id": "G11",
            "fact_id": "G11",
            "prompt": "What does completing this room grant?",
            "options": [
                "A Diamonds scorecard NFT on ICP.",
                "A Gold scorecard NFT on ICP.",
                "Guaranteed XAUT from the next auction."
            ],
            "correct": 1
        }
    ]
}
