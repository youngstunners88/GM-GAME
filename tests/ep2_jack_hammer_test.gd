extends Node
## Founder lock 2026-10-21 (PROMPT_EPISODE2_JACK_HAMMER_BOUNTY_HORSE_AUCTION): the Jack Hammer thread's identity, wording rules and order are enforced here, not remembered
## (skills ep2-jack-hammer-narrative, ep2-jack-hammer-dialogue). Pure logic + data; run: godot --headless res://tests/ep2_jack_hammer_test.tscn
var failures: int = 0


func check(label: String, ok: bool, detail: String = "") -> void:
	print("  [PASS] " if ok else "  [FAIL] ", label, "" if ok or detail.is_empty() else "  (" + detail + ")")
	if not ok:
		failures += 1


func _ready() -> void:
	print("-- IDENTITY AND LOCKED FACTS")
	check("the antagonist is Jack Hammer, formal name Jackson Mccree (spelled as the lock spells it)", Ep2JackHammer.STREET_NAME == "Jack Hammer" and Ep2JackHammer.OFFICIAL_NAME == "Jackson Mccree")
	check("the bounty is paid in gold XAUt", Ep2JackHammer.BOUNTY_CURRENCY == "XAUt")
	check("the horse costs half a Bitcoin, tendered in Episode 1 crypto only", is_equal_approx(Ep2JackHammer.HORSE_PRICE_BTC, 0.5) and Ep2JackHammer.HORSE_TENDER == "btc")
	check("the locked beat order is job, bounty, jail word, stable, trail, auction", Ep2JackHammer.BEAT_ORDER == ["JOB_ASK", "BOUNTY", "JAIL_WORD", "STABLE", "TRAIL", "AUCTION"])
	for b in Ep2JackHammer.BEAT_ORDER:
		check("beat %s has lines (or a card) and an objective" % b, not Ep2JackHammer.lines(b).is_empty() and Ep2JackHammer.objective(b) != "")

	print("-- THE WORDS (every string of the thread)")
	var all: String = Ep2JackHammer.all_text()
	var low: String = all.to_lower()
	check("the Sheriff is asked for work in the first beat, by Lil Blunt", str(Ep2JackHammer.lines("JOB_ASK")[0]["who"]) == "LIL BLUNT" and "work" in str(Ep2JackHammer.lines("JOB_ASK")[0]["text"]).to_lower())
	check("the notice names Jackson Mccree, called Jack Hammer, and the reward in XAUt", "JACKSON MCCREE" in " ".join(Ep2JackHammer.NOTICE) and "JACK HAMMER" in " ".join(Ep2JackHammer.NOTICE) and "XAUt" in " ".join(Ep2JackHammer.NOTICE))
	var bounty_text: String = ""
	for ln in Ep2JackHammer.lines("BOUNTY"):
		bounty_text += str(ln["text"]) + " "
	check("the Sheriff says Jack Hammer, Jackson Mccree, gold and XAUt, and that he brought the bears in for the early claims", "Jack Hammer" in bounty_text and "Jackson Mccree" in bounty_text and "gold" in bounty_text.to_lower() and "XAUt" in bounty_text and "bears" in bounty_text and "early claims" in bounty_text)
	var jail_text: String = ""
	for ln in Ep2JackHammer.lines("JAIL_WORD"):
		jail_text += str(ln["who"]) + ": " + str(ln["text"]) + " "
	check("the accomplice (or a jailor) places Jack Hammer at the auction in one clear line", "Jack Hammer" in jail_text and "auction" in jail_text.to_lower() and ("ACCOMPLICE" in jail_text or "JAILOR" in jail_text))
	var stable_text: String = ""
	for ln in Ep2JackHammer.lines("STABLE"):
		stable_text += str(ln["text"]) + " "
	check("the stable hand prices the horse as half a coin (spoken: coin, never Bitcoin)", "Half a coin" in stable_text and not ("bitcoin" in low or "btc" in low or "crypto" in low))
	var trail_text: String = ""
	for ln in Ep2JackHammer.lines("TRAIL"):
		trail_text += str(ln["text"]) + " "
	check("the bandits try to get him off the horse", "off that horse" in trail_text and Ep2JackHammer.lines("TRAIL").size() >= 3)
	check("the auction arrival cards exist for mounted and on foot", Ep2JackHammer.line("jh_arrive_mounted") != {} and Ep2JackHammer.line("jh_arrive_foot") != {} and "AUCTION" in str(Ep2JackHammer.line("jh_arrive_foot")["text"]))
	var bad: Array = []
	for w in ["%", "$", "apy", "yield", "0x", "stake", "staking", "liquidity pool", "wallet", "contract", "dollar", "eth", "sol "]:
		if w in low:
			bad.append(w)
	var digit: bool = false
	for ch in all:
		if ch >= "0" and ch <= "9":
			digit = true
	check("no whitepaper numbers, yields, addresses, dollars or tickers anywhere in the thread", bad.is_empty() and not digit, "%s digit=%s" % [str(bad), str(digit)])
	check("no horse-as-protocol-product: no staking, LP or yield in any line", not ("stake" in low or "lp" in low.split(" ") or "yield" in low))
	check("Fort Knox is not replaced: nothing in the thread calls Jack Hammer the final boss or ends the game", not ("final" in low or "end of the game" in low))
	var ids: Dictionary = {}
	var dup: bool = false
	for beat in Ep2JackHammer.LINES:
		for ln in Ep2JackHammer.LINES[beat]:
			if ids.has(ln["id"]):
				dup = true
			ids[ln["id"]] = true
	check("every line has a unique voice id", not dup and ids.size() >= 17, "%d" % ids.size())

	print("-- THE ARC (order, tender, outcomes)")
	var a := Ep2JackHammerArc.new()
	check("nothing is started until he asks the Sheriff for work", not a.started() and a.beat == "" and not a.reveal_bounty())
	check("asking the Sheriff for work starts the thread once", a.ask_sheriff_for_work() and a.beat == "JOB_ASK" and not a.ask_sheriff_for_work())
	check("the cell cannot place him before the bounty is known", not a.hear_auction_word() and not a.reach_stable())
	check("the bounty is learned from the Sheriff", a.reveal_bounty() and a.knows_bounty and a.beat == "BOUNTY")
	check("the stable is locked until the auction word is heard", not a.reach_stable() and a.hear_auction_word() and a.knows_auction and a.reach_stable() and a.beat == "STABLE")
	check("no horse without the tender: short of half a coin is refused and nothing is spent", a.buy_horse(0.4) == -1.0 and not a.horse_owned and a.spent_btc == 0.0)
	check("only Episode 1 crypto buys it: another tender is refused", a.buy_horse(2.0, "gold") == -1.0 and not a.horse_owned)
	check("half a coin buys the horse once, and the caller is told what is left", is_equal_approx(a.buy_horse(1.25), 0.75) and a.horse_owned and is_equal_approx(a.spent_btc, 0.5))
	check("a second horse is not sold, the horse is not free twice", a.buy_horse(5.0) == -1.0 and is_equal_approx(a.spent_btc, 0.5))
	check("the trail starts with the horse in hand", a.start_trail() and a.beat == "TRAIL")
	a.lose_horse()
	check("a horse shot out from under him is lost and he goes on", a.horse_lost and not a.horse_owned)
	check("he arrives at the auction on foot, with the delay recorded", a.arrive(42.0) and a.arrived and not a.arrived_mounted and is_equal_approx(a.arrival_delay_s, 42.0) and a.beat == "AUCTION")
	var b := Ep2JackHammerArc.new()
	b.ask_sheriff_for_work(); b.reveal_bounty(); b.hear_auction_word(); b.reach_stable()
	check("the trail cannot start without buying the horse", not b.start_trail() and not b.arrive())
	b.buy_horse(0.5); b.start_trail()
	check("the default fantasy: he arrives mounted", b.arrive() and b.arrived_mounted and b.result()["jack_hammer"]["mounted"])
	var saved: Dictionary = JSON.parse_string(JSON.stringify(b.snapshot()))
	var c := Ep2JackHammerArc.new()
	c.restore(saved)
	check("the thread survives a save round trip", c.beat == "AUCTION" and c.horse_owned and c.arrived and c.arrived_mounted and is_equal_approx(c.spent_btc, 0.5))
	var d := Ep2JackHammerArc.new()
	d.restore({"beat": "TRAIL", "horse": false, "horse_lost": false, "bounty": true, "auction": true})
	check("a corrupt save can never put him on the trail without a horse", d.beat != "TRAIL" and d.beat != "AUCTION")
	var e := Ep2JackHammerArc.new()
	e.restore({"beat": "STABLE", "bounty": true, "auction": true, "spent_btc": 99.0, "delay": -5, "junk": "x"})
	check("a save in the stable before the purchase stays there; wrong-shaped numbers are bounded", e.beat == "STABLE" and not e.horse_owned and e.spent_btc <= 0.5 and e.arrival_delay_s == 0.0)
	print("-- FOUNDER RULINGS 2026-10-21 (one coin face = one Bitcoin, half back as change; the auction is a second settlement)")
	check("one BTC coin face is one Bitcoin and the horse's half comes back as change", is_equal_approx(Ep2JackHammer.BTC_FACE_VALUE * Ep2JackHammer.HORSE_FACES_PAID - Ep2JackHammer.HORSE_PRICE_BTC, Ep2JackHammer.HORSE_CHANGE_BTC) and is_equal_approx(Ep2JackHammer.HORSE_CHANGE_BTC, 0.5))
	check("the auction is a second settlement in the next town", Ep2JackHammer.AUCTION_PLACE == "next_town")
	var g := Ep2JackHammerArc.new()
	g.ask_sheriff_for_work(); g.reveal_bounty(); g.hear_auction_word()
	check("no face can be paid before the stable", g.buy_horse_with_face(3).is_empty() and not g.horse_owned)
	g.reach_stable()
	check("no face, no horse; another tender is refused", g.buy_horse_with_face(0).is_empty() and g.buy_horse_with_face(2, "gold").is_empty() and not g.horse_owned and g.change_btc == 0.0)
	var paid: Dictionary = g.buy_horse_with_face(3)
	check("one face buys the horse and half a Bitcoin comes back", g.horse_owned and int(paid["faces_left"]) == 2 and int(paid["faces_paid"]) == 1 and is_equal_approx(float(paid["change_btc"]), 0.5) and is_equal_approx(g.change_btc, 0.5))
	check("the horse is not sold twice by face either", g.buy_horse_with_face(3).is_empty() and is_equal_approx(g.change_btc, 0.5))
	var g2 := Ep2JackHammerArc.new()
	g2.restore(JSON.parse_string(JSON.stringify(g.snapshot())))
	check("the change survives a save; a stable-only save cannot carry change", is_equal_approx(g2.change_btc, 0.5))
	var g3 := Ep2JackHammerArc.new()
	g3.restore({"beat": "STABLE", "bounty": true, "auction": true, "change_btc": 9.0})
	check("change in a save without a horse is dropped", g3.change_btc == 0.0)
	var f := Ep2JackHammerArc.new()
	f.restore({"beat": "NOPE"})
	check("an unknown beat in a save is refused", f.beat == "")
	print("EP2_JACK_HAMMER: ", "ALL PASS" if failures == 0 else "%d FAILED" % failures)
	get_tree().quit(1 if failures > 0 else 0)
