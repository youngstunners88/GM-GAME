class_name Ep2JackHammerArc
extends RefCounted
## The Jack Hammer thread as PURE LOGIC (no nodes): which beat he is on, what he has learned, whether he may buy the horse, how he arrived. A room drives it
## and shows `Ep2JackHammer.lines(...)`; this class decides what is allowed and carries the state into the next room (founder lock 2026-10-21).
##
## Order is locked: JOB_ASK (asks the Sheriff for work) -> BOUNTY (the notice + the Sheriff) -> JAIL_WORD (the cell / jailor places Jack Hammer at the auction)
## -> STABLE (half a Bitcoin buys the horse) -> TRAIL (ride-and-shoot) -> AUCTION. Nothing is skippable and nothing is free: no horse without the tender,
## no stable before the auction is known, no auction without the trail. The trail's outcome (mounted or on foot, late or not) is data for the auction scene.

signal beat_changed(beat: String)
signal horse_bought(price_btc: float)

const VERSION := 1

var beat: String = ""                         # "" until the Sheriff is asked
var knows_bounty: bool = false
var knows_auction: bool = false
var horse_owned: bool = false
var horse_lost: bool = false
var arrived: bool = false
var arrived_mounted: bool = false
var arrival_delay_s: float = 0.0
var spent_btc: float = 0.0
var change_btc: float = 0.0                   # half a Bitcoin handed back when a whole coin face paid for the horse


func started() -> bool:
	return beat != ""


## The job ask (after the draw / certificate cluster, with the map in hand). Idempotent.
func ask_sheriff_for_work() -> bool:
	if started():
		return false
	_go("JOB_ASK")
	return true


## The Sheriff answers: the bounty on Jack Hammer (Jackson Mccree), paid in gold XAUt.
func reveal_bounty() -> bool:
	if beat != "JOB_ASK":
		return false
	knows_bounty = true
	_go("BOUNTY")
	return true


## The cell (or a jailor) places Jack Hammer at the auction. Needs the bounty first: he asks because he knows who to ask about.
func hear_auction_word() -> bool:
	if beat != "BOUNTY" or not knows_bounty:
		return false
	knows_auction = true
	_go("JAIL_WORD")
	return true


## He walks into the stables: only once he knows the auction is a ride.
func reach_stable() -> bool:
	if beat != "JAIL_WORD" or not knows_auction:
		return false
	_go("STABLE")
	return true


func can_afford_horse(btc_balance: float) -> bool:
	return beat == "STABLE" and not horse_owned and btc_balance + 1e-9 >= Ep2JackHammer.HORSE_PRICE_BTC


## Buy the horse with half a Bitcoin of Episode 1 crypto. Returns the balance LEFT, or -1.0 when refused (wrong beat, owned already, short of the tender, wrong tender).
## The CALLER debits its own purse with that figure; this class never invents money and never gives the horse away.
func buy_horse(btc_balance: float, tender: String = Ep2JackHammer.HORSE_TENDER) -> float:
	if tender != Ep2JackHammer.HORSE_TENDER or not can_afford_horse(btc_balance):
		return -1.0
	horse_owned = true
	spent_btc += Ep2JackHammer.HORSE_PRICE_BTC
	horse_bought.emit(Ep2JackHammer.HORSE_PRICE_BTC)
	return maxf(0.0, btc_balance - Ep2JackHammer.HORSE_PRICE_BTC)


## The purse way (founder ruling 2026-10-21): one BTC coin face IS one Bitcoin, the horse takes a whole face and half a Bitcoin comes back as change.
## `faces` = whole BTC coin faces in the purse. Returns {"faces_left": int, "change_btc": float}, or {} when refused (wrong beat, owned, no face, wrong tender).
## The CALLER debits `faces_paid` faces and credits `change_btc` to its fractional-BTC balance; this class never invents money.
func buy_horse_with_face(faces: int, tender: String = Ep2JackHammer.HORSE_TENDER) -> Dictionary:
	if tender != Ep2JackHammer.HORSE_TENDER or beat != "STABLE" or horse_owned or faces < Ep2JackHammer.HORSE_FACES_PAID:
		return {}
	horse_owned = true
	spent_btc += Ep2JackHammer.HORSE_PRICE_BTC
	change_btc += Ep2JackHammer.HORSE_CHANGE_BTC
	horse_bought.emit(Ep2JackHammer.HORSE_PRICE_BTC)
	return {"faces_left": faces - Ep2JackHammer.HORSE_FACES_PAID, "faces_paid": Ep2JackHammer.HORSE_FACES_PAID, "change_btc": Ep2JackHammer.HORSE_CHANGE_BTC}


## The ride begins (only with the horse in hand).
func start_trail() -> bool:
	if beat != "STABLE" or not horse_owned:
		return false
	_go("TRAIL")
	return true


## The horse is shot out from under him: he finishes on foot (the exact fail branches stay light: lost horse, late arrival).
func lose_horse() -> void:
	if beat == "TRAIL" and horse_owned:
		horse_owned = false
		horse_lost = true


## The trail ends at the auction: mounted (default fantasy) or on foot, with how late he is.
func arrive(delay_s: float = 0.0) -> bool:
	if beat != "TRAIL":
		return false
	arrived = true
	arrived_mounted = horse_owned and not horse_lost
	arrival_delay_s = maxf(0.0, delay_s)
	_go("AUCTION")
	return true


func _go(next: String) -> void:
	beat = next
	beat_changed.emit(next)


## Result keys for the room hand-off / the auction scene.
func result() -> Dictionary:
	return {"jack_hammer": snapshot()}


func snapshot() -> Dictionary:
	return {"v": VERSION, "beat": beat, "bounty": knows_bounty, "auction": knows_auction, "horse": horse_owned, "horse_lost": horse_lost,
		"arrived": arrived, "mounted": arrived_mounted, "delay": arrival_delay_s, "spent_btc": spent_btc, "change_btc": change_btc}


## Wrong-shaped saves are refused field by field (SaveSafe-style bounds): a corrupt file can never put him on the trail without a horse.
func restore(data: Dictionary) -> void:
	var b: String = str(data.get("beat", ""))
	beat = b if (b == "" or Ep2JackHammer.BEAT_ORDER.has(b)) else ""
	var idx: int = Ep2JackHammer.BEAT_ORDER.find(beat)
	knows_bounty = bool(data.get("bounty", false)) and idx >= 1
	knows_auction = bool(data.get("auction", false)) and idx >= 2
	horse_owned = bool(data.get("horse", false)) and idx >= 3
	horse_lost = bool(data.get("horse_lost", false)) and idx >= 4
	arrived = bool(data.get("arrived", false)) and idx >= 5
	arrived_mounted = bool(data.get("mounted", false)) and arrived and not horse_lost
	arrival_delay_s = clampf(float(data.get("delay", 0.0)), 0.0, 3600.0)
	spent_btc = clampf(float(data.get("spent_btc", 0.0)), 0.0, Ep2JackHammer.HORSE_PRICE_BTC)
	change_btc = clampf(float(data.get("change_btc", 0.0)), 0.0, Ep2JackHammer.HORSE_CHANGE_BTC) if horse_owned or horse_lost else 0.0
	if idx >= 4 and not (horse_owned or horse_lost):
		beat = "JAIL_WORD" if knows_auction else ("BOUNTY" if knows_bounty else ("JOB_ASK" if idx >= 0 else ""))
