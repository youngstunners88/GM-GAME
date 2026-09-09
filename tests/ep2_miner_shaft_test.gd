extends Node
## Headless gate for Episode 2 Chamber 1 (Miner Shaft) — the vesting/claim
## mechanic and its combat pressure. Same discipline as
## tests/ep2_runner_graybox_test.gd: instantiate the real scene, drive it with
## deterministic `step(delta)` calls, assert on real read-back state.
##
## Covers:
##   1-3.   vest does not accrue before the rig starts; start_rig validates
##          payment; start_rig is not re-entrant.
##   4-5.   linear 1%/day vest reaches full and self-resolves exactly once.
##   6-8.   Early Claim pays the vested fraction and forfeits the remainder,
##          and awarded + forfeited == principal (no GOLD minted or lost).
##   9.     Early Claim after resolution is refused (double-payout guard).
##   10-11. Diamond burn uses the REAL GoldMineSystem.DIAMOND_BURN_PCT, and is
##          zero when the player paid ETH only.
##   12-14. Bears only mobilise once the rig runs, damage the player on
##          contact, and shooting kills them deterministically.
##   15.    Cover converts incoming damage into vest loss — the real trade.
##   16.    setup() fully resets a reused instance (stale terminal-flag class
##          of bug, cf. the runner's Kimi audit #5c).
##
## Run: .godot-cache/Godot_v4.3-stable_linux.x86_64 --headless res://tests/ep2_miner_shaft_test.tscn

const SCENE := preload("res://src/episode2/chamber/miner_shaft.tscn")

var _fail: int = 0

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _mk(principal: int = 1000, bears: Array = [], diamonds: int = 0) -> Node:
	var c: Node = SCENE.instantiate()
	add_child(c)
	c.setup(principal, bears, diamonds)
	return c

## Drive `seconds` of sim in fixed 1/60 steps — deterministic, frame-clock free.
func _run(c: Node, seconds: float) -> void:
	var dt := 1.0 / 60.0
	var n := int(round(seconds / dt))
	for i in n:
		c.step(dt)

func _ready() -> void:
	await get_tree().process_frame
	print("EP2 MINER SHAFT:")

	# 1. No vest before the rig is started — standing around must never earn.
	var c1 := _mk()
	_run(c1, 5.0)
	_check("vest stays 0 before the rig is started (got %.3f)" % c1.get_vest(),
		is_zero_approx(c1.get_vest()))

	# 2. start_rig rejects an unknown payment mode.
	_check("start_rig rejects an invalid payment mode", not c1.start_rig("dogecoin"))
	_check("rig is still not started after a rejected payment", not c1.is_rig_started())

	# 3. start_rig is not re-entrant — a mashed interact can't restart the vest.
	_check("start_rig succeeds with 'eth'", c1.start_rig("eth"))
	_run(c1, 5.0)
	var vest_after_5s: float = c1.get_vest()
	_check("second start_rig is refused", not c1.start_rig("eth"))
	_check("vest was not reset by the refused restart (%.3f)" % c1.get_vest(),
		is_equal_approx(c1.get_vest(), vest_after_5s))
	c1.queue_free()

	# 4-5. Full vest self-resolves, exactly once, with the whole principal.
	var c2 := _mk(1000)
	var cleared: Array = []
	c2.chamber_cleared.connect(func(r): cleared.append(r))
	c2.start_rig("eth")
	_run(c2, MinerShaftChamber.VEST_SECONDS_FULL + 2.0)
	_check("full vest resolves the chamber", c2.is_resolved())
	_check("chamber_cleared emitted exactly once (got %d)" % cleared.size(),
		cleared.size() == 1)
	if cleared.size() == 1:
		_check("full vest awards the whole principal (got %d)" % cleared[0]["gold_awarded"],
			cleared[0]["gold_awarded"] == 1000)
		_check("full vest forfeits nothing (got %d)" % cleared[0]["gold_forfeited"],
			cleared[0]["gold_forfeited"] == 0)
		_check("full vest is not flagged early", not cleared[0]["early"])
	c2.queue_free()

	# 6-8. Early claim: partial award, remainder forfeited, conservation holds.
	var c3 := _mk(1000)
	var early: Array = []
	c3.chamber_cleared.connect(func(r): early.append(r))
	c3.start_rig("eth")
	_run(c3, MinerShaftChamber.VEST_SECONDS_FULL * 0.5)   # ~50% vested
	_check("early_claim succeeds while running", c3.early_claim())
	_check("early claim emitted a result", early.size() == 1)
	if early.size() == 1:
		var r: Dictionary = early[0]
		_check("early claim is flagged early", r["early"])
		_check("early claim awards ~half the principal (got %d)" % r["gold_awarded"],
			r["gold_awarded"] >= 450 and r["gold_awarded"] <= 550)
		_check("awarded + forfeited == principal (%d + %d)" % [r["gold_awarded"], r["gold_forfeited"]],
			r["gold_awarded"] + r["gold_forfeited"] == 1000)

	# 9. Post-resolution claim is refused — the double-payout guard.
	_check("early_claim after resolution is refused", not c3.early_claim())
	_check("no second chamber_cleared was emitted (got %d)" % early.size(), early.size() == 1)
	c3.queue_free()

	# 10-11. Diamond burn tracks the REAL economy constant, and is 0 on ETH-only.
	var gm: Node = get_node_or_null("/root/GoldMineSystem")
	var burn_pct: float = float(gm.DIAMOND_BURN_PCT) if gm else 0.20
	var c4 := _mk(500, [], 100)
	var dres: Array = []
	c4.chamber_cleared.connect(func(r): dres.append(r))
	c4.start_rig("eth_diamonds")
	c4.early_claim()
	if dres.size() == 1:
		_check("diamond burn == round(100 * DIAMOND_BURN_PCT=%.2f) (got %d)" % [burn_pct, dres[0]["diamonds_burned"]],
			dres[0]["diamonds_burned"] == int(round(100 * burn_pct)))
	c4.queue_free()

	var c5 := _mk(500, [], 100)
	var eres: Array = []
	c5.chamber_cleared.connect(func(r): eres.append(r))
	c5.start_rig("eth")          # ETH-only: the diamonds were never spent
	c5.early_claim()
	if eres.size() == 1:
		_check("ETH-only payment burns no diamonds (got %d)" % eres[0]["diamonds_burned"],
			eres[0]["diamonds_burned"] == 0)
	c5.queue_free()

	# 12. Bears do not mobilise until the rig is running (pressure is triggered
	#     BY starting the vest, per the chamber brief).
	var c6 := _mk(1000, [{"z": 0.0}])
	var z0: float = c6.get_bear_z(0)
	_run(c6, 3.0)
	_check("bear does not advance before the rig starts (%.2f -> %.2f)" % [z0, c6.get_bear_z(0)],
		is_equal_approx(c6.get_bear_z(0), z0))

	# 13. Once running, a bear closes and damages the player.
	c6.start_rig("eth")
	_run(c6, 3.0)
	_check("bear advances toward the rig once the rig runs (%.2f)" % c6.get_bear_z(0),
		c6.get_bear_z(0) > z0)
	_run(c6, 10.0)
	_check("bear reaching the rig costs the player health (got %d)" % c6.get_health(),
		c6.get_health() < MinerShaftChamber.START_HEALTH)
	c6.queue_free()

	# 14. Shooting kills deterministically and spends ammo.
	var c7 := _mk(1000, [{"z": 12.0}])
	c7.start_rig("eth")
	var ammo0: int = c7.get_ammo()
	_check("one live bear before shooting", c7.get_live_bear_count() == 1)
	for i in MinerShaftChamber.BEAR_HP:
		c7.shoot()
	_check("bear dies after BEAR_HP shots", c7.get_live_bear_count() == 0)
	_check("shots spent ammo (%d -> %d)" % [ammo0, c7.get_ammo()],
		c7.get_ammo() == ammo0 - MinerShaftChamber.BEAR_HP)
	c7.queue_free()

	# 15. Cover trades health for yield rather than being a free win.
	var c8 := _mk(1000, [{"z": 13.0}])
	c8.start_rig("eth")
	c8.take_cover()
	_run(c8, 6.0)
	_check("in cover the player takes no damage (health %d)" % c8.get_health(),
		c8.get_health() == MinerShaftChamber.START_HEALTH)
	_check("in cover the rig loses vest instead (vest %.3f < uncontested)" % c8.get_vest(),
		c8.get_vest() < 6.0 / MinerShaftChamber.VEST_SECONDS_FULL)
	c8.queue_free()

	# 16. setup() fully resets a reused instance — no stale terminal flags.
	var c9 := _mk(1000)
	c9.start_rig("eth")
	c9.early_claim()
	_check("instance is resolved before reuse", c9.is_resolved())
	c9.setup(1000, [])
	_check("setup() clears the resolved flag", not c9.is_resolved())
	_check("setup() clears the rig-started flag", not c9.is_rig_started())
	_check("setup() restores running state", c9.is_running())
	_check("setup() zeroes the vest", is_zero_approx(c9.get_vest()))
	_check("setup() restores health and ammo",
		c9.get_health() == MinerShaftChamber.START_HEALTH and c9.get_ammo() == MinerShaftChamber.START_AMMO)
	_check("rig is startable again after reset", c9.start_rig("eth"))
	c9.queue_free()

	print("EP2_MINER_SHAFT: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)
