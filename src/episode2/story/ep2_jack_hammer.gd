class_name Ep2JackHammer
extends RefCounted
## JACK HAMMER (Jackson Mccree): the Episode 2 main antagonist's first thread - bounty -> horse -> auction (founder lock 2026-10-21,
## design/ep2/jack_hammer/PROMPT_EPISODE2_JACK_HAMMER_BOUNTY_HORSE_AUCTION.md; skills ep2-jack-hammer-narrative, ep2-jack-hammer-dialogue).
##
## SINGLE SOURCE of the identity, the locked facts and every line of the thread. Rooms, HUD, voice passes and tests read it; nobody retypes a line.
## Dialogue is timed text for now (no voice key on this box); `id` is the future voice file key (`vo_<id>`). Spoken lines say "coin", never "Bitcoin" /
## "crypto" / tickers (the town's word; the tender shows on the panel). No whitepaper numbers, no yields, no addresses, no horse-as-protocol mechanic.

const STREET_NAME := "Jack Hammer"
const OFFICIAL_NAME := "Jackson Mccree"
const BOUNTY_CURRENCY := "XAUt"                     # gold XAUt: the lock's own word; never a new token name, never a soft currency
const HORSE_PRICE_BTC := 0.5                        # half a Bitcoin of Episode 1 crypto
const HORSE_TENDER := "btc"
## FOUNDER RULING 2026-10-21: one BTC coin face is one Bitcoin. The purse holds whole faces, so the stable takes ONE face and hands half a Bitcoin back as change.
const BTC_FACE_VALUE := 1.0
const HORSE_FACES_PAID := 1
const HORSE_CHANGE_BTC := 0.5                       # BTC_FACE_VALUE * HORSE_FACES_PAID - HORSE_PRICE_BTC
## FOUNDER RULING 2026-10-21: the auction is a SECOND SETTLEMENT in the next town (not an event hall): the trail ends at its edge. No full open world: a short trail + a bounded settlement.
const AUCTION_PLACE := "next_town"
## FOUNDER RULING 2026-10-21: mean, with an eye patch. Since 2026-10-27 the shipped model is the founder's OWN Jack Hammer (Drive
## "Jack+Hammer.glb", Ep2Extras.JACK_HAMMER, 1.92 m), which wears no patch - his model is his call; EYE_PATCH_EYE records the 10-21 ruling.
const HEIGHT_M := 1.92
const EYE_PATCH_EYE := "left"                       # his left eye is covered; the right one is the cold one
## The auction's people (founder 2026-10-27: "Renegade the charismatic auctioneer. He hosts the auction"; "Jack Hammer. He will be at the
## auction"): both are the founder's own streamed models; the auction settlement places them from this list.
const AUCTION_CAST: Array = [
	{"id": "renegade", "who": "RENEGADE", "role": "host", "model": "res://src/episode2/extras/folk/renegade.glb", "height_m": 1.82},
	{"id": "jack_hammer", "who": "JACK HAMMER", "role": "bidder", "model": "res://src/episode2/extras/people/jack_hammer.glb", "height_m": 1.92},
]
const BEAT_ORDER: Array = ["JOB_ASK", "BOUNTY", "JAIL_WORD", "STABLE", "TRAIL", "AUCTION"]

## The wanted notice on the Sheriff's wall (a 3D sign or a HUD card; the paper's formal name is Jackson Mccree).
const NOTICE: Array = [
	"WANTED",
	"JACKSON MCCREE",
	"called JACK HAMMER",
	"For bringing bears onto claimed ground and for jumping early claims.",
	"REWARD: GOLD, paid in XAUt.",
]

## Every line: {id, who, text}. `who` is a display name in capitals, like the jail scene. Order within a beat is playing order.
const LINES: Dictionary = {
	"JOB_ASK": [
		{"id": "jh_lb_job", "who": "LIL BLUNT", "text": "Sheriff. Where does a man find paid work in this town?"},
		{"id": "jh_sheriff_job_1", "who": "SHERIFF", "text": "Paid work. With that rifle and that map, you came to the right door."},
		{"id": "jh_sheriff_job_2", "who": "SHERIFF", "text": "Top sheet on the board behind me. Read it, then come back and ask me again."},
	],
	"BOUNTY": [
		{"id": "jh_sheriff_bounty_1", "who": "SHERIFF", "text": "Jack Hammer, the town calls him. Jackson Mccree on the paper."},
		{"id": "jh_sheriff_bounty_2", "who": "SHERIFF", "text": "He brought the bears in so the early claims could be jumped before the vault side locks up. Whoever puts him in front of me draws the reward."},
		{"id": "jh_sheriff_bounty_3", "who": "SHERIFF", "text": "It is paid in gold. XAUt, by the book."},
		{"id": "jh_lb_where", "who": "LIL BLUNT", "text": "Where do I find him?"},
		{"id": "jh_sheriff_bounty_4", "who": "SHERIFF", "text": "Nobody has seen him sit still. Ask the man in my cell. He knows more than he told me."},
	],
	"JAIL_WORD": [
		{"id": "jh_lb_cell", "who": "LIL BLUNT", "text": "Jack Hammer. Where will he be?"},
		{"id": "jh_acc_auction_1", "who": "ACCOMPLICE", "text": "The auction. He never misses one. He walks in to bid, or he walks in to take it. Depends who is selling."},
		{"id": "jh_acc_auction_2", "who": "ACCOMPLICE", "text": "You want him, you get there before the doors open. It is a ride."},
	],
	"STABLE": [
		{"id": "jh_hand_greet", "who": "STABLE HAND", "text": "Heading for the auction? Nobody walks that trail."},
		{"id": "jh_hand_price", "who": "STABLE HAND", "text": "She is sound and she does not spook at gunfire. Half a coin and she is yours."},
		{"id": "jh_hand_refuse", "who": "STABLE HAND", "text": "No coin, no horse. I do not take credit."},
		{"id": "jh_hand_sold", "who": "STABLE HAND", "text": "She is yours. The trail runs out past the last lamp. Keep low and keep riding."},
	],
	"TRAIL": [
		{"id": "jh_bandit_1", "who": "BANDIT", "text": "That is the rider! Get him off that horse!"},
		{"id": "jh_bandit_2", "who": "BANDIT", "text": "Hammer's coin says he never reaches the auction!"},
		{"id": "jh_bandit_3", "who": "BANDIT", "text": "Shoot the horse if you cannot hit the man!"},
	],
	"AUCTION": [
		{"id": "jh_arrive_mounted", "who": "", "text": "THE AUCTION. JACK HAMMER IS EXPECTED."},
		{"id": "jh_arrive_foot", "who": "", "text": "THE AUCTION - ON FOOT. THE HORSE DID NOT MAKE IT."},
	],
}

## HUD objectives per beat (what the player is told to do next).
const OBJECTIVES: Dictionary = {
	"JOB_ASK": "Ask the Sheriff where a man finds paid work.",
	"BOUNTY": "Read the wanted notice. The Sheriff will tell you the rest.",
	"JAIL_WORD": "Ask the man in the cell where Jack Hammer will be.",
	"STABLE": "Buy a horse at the stables. The auction is a ride.",
	"TRAIL": "Ride for the auction. Do not let them take you off the horse.",
	"AUCTION": "Find Jack Hammer (Jackson Mccree) at the auction.",
}


static func lines(beat: String) -> Array:
	return LINES.get(beat, [])


static func line(id: String) -> Dictionary:
	for beat in LINES:
		for ln in LINES[beat]:
			if str(ln["id"]) == id:
				return ln
	return {}


static func objective(beat: String) -> String:
	return str(OBJECTIVES.get(beat, ""))


## "WHO: text" for a toast; narration (empty `who`) is just the text.
static func toast_text(ln: Dictionary) -> String:
	return str(ln["text"]) if str(ln.get("who", "")) == "" else "%s: %s" % [ln["who"], ln["text"]]


## Every spoken / written string of the thread (the gate scans it for forbidden words and numbers).
static func all_text() -> String:
	var out: String = " ".join(NOTICE) + " "
	for beat in LINES:
		for ln in LINES[beat]:
			out += str(ln["text"]) + " "
	for k in OBJECTIVES:
		out += str(OBJECTIVES[k]) + " "
	return out
