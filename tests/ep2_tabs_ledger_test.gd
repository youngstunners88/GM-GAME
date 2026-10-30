extends Node
## Lil Blunt's Tabs ledger gate: finished-runner BTC reaches Rich exactly once,
## only his own bear kills tally, Dude's Chill Buds heal within the three-heart
## story cap, both ledgers survive the save file, and the selector draws headless.
## Run: godot --headless res://tests/ep2_tabs_ledger_test.tscn

var failures: int = 0
var _save_existed: bool = false
var _save_backup: String = ""


## Keeps the chamber transition out of this economy test while leaving the real
## completion handler free to be re-entered on the same frame.
class CreditSession:
	extends Ep2SessionRoot
	var entries: int = 0

	func _enter_chamber() -> void:
		entries += 1


func check(label: String, ok: bool, detail: String = "") -> void:
	print("  [PASS] " if ok else "  [FAIL] ", label, "" if ok or detail.is_empty() else "  (" + detail + ")")
	if not ok:
		failures += 1


func _reset_manager() -> void:
	GameManager.reset_session()


func _make_woods() -> WoodsQuadChamber:
	var woods := WoodsQuadChamber.new()
	# Only the combat/health piece is under test; do not build a kilometre of set.
	woods._room_built = true
	add_child(woods)
	woods.set_physics_process(false)
	woods._visuals = Node3D.new()
	woods._visuals.name = "Visuals"
	woods.add_child(woods._visuals)
	return woods


func _bear(woods: WoodsQuadChamber, bear_name: String, idx: int) -> Ep2BearBrain:
	return woods._spawn_bear({"name": bear_name, "role": "brawler", "routine": "sleep",
		"pos": Vector2(float(idx) * 4.0, 0.0), "hp": 1, "height": 2.1, "group": "scout"}, idx)


func _ready() -> void:
	_save_existed = FileAccess.file_exists(GameManager.SAVE_PATH)
	if _save_existed:
		_save_backup = FileAccess.get_file_as_string(GameManager.SAVE_PATH)

	print("-- RUNNER BTC: one finished leg, one purse credit")
	_reset_manager()
	var session := CreditSession.new()
	add_child(session)
	var runner: RunnerGraybox = Ep2SessionRoot.RUNNER_SCENE.instantiate()
	session.add_child(runner)
	runner.set_physics_process(false)
	var pickups: Array = []
	for i in 3:
		pickups.append({"z": 3.0 + float(i) * 3.0, "lane": 1, "type": "gold"})
	runner.setup(1000.0, pickups)
	for i in 90:
		runner.step(1.0 / 60.0)
	check("the real runner collected three tunnel BTC", runner.get_gold() == 3, "%d" % runner.get_gold())
	session._active = runner
	session._mode = Ep2SessionRoot.Mode.RUNNER
	session._on_chamber_reached()
	session._on_chamber_reached()
	check("calling the completion handler twice credits exactly 3 BTC", GameManager.purse_balance("btc") == 3,
		"btc %d, entries %d" % [GameManager.purse_balance("btc"), session.entries])
	check("the run records its credited amount for the ledger", GameManager.runner_btc_credited == 3)
	var town := GoldTownChamber.new()
	var sharps: Dictionary = Ep2ArmoryState.shop_item("sniper")
	check("a fresh purse plus this 3-coin run buys Rich's 3-BTC Sharps through the chamber buy()",
		int(sharps.get("price", 0)) == 3 and town.buy("sniper", 3, "btc") and town.armory.sniper_owned)
	check("Rich takes the BTC, does not mint more, and cannot sell the same rifle twice",
		GameManager.purse_balance("btc") == 0 and not town.buy("sniper", 3, "btc"))
	town.free()
	session.queue_free()

	print("-- BEAR TALLY: woods attribution and runner signals")
	_reset_manager()
	var woods := _make_woods()
	var player_bear := _bear(woods, "LedgerTarget", 0)
	player_bear.set_meta("killed_by", "player")
	woods._on_bear_died(player_bear)
	check("a bear Lil Blunt shot tallies under its role", int(GameManager.bear_tally.get("brawler", 0)) == 1
		and GameManager.bear_total() == 1, str(GameManager.bear_tally))
	var bull_bear := _bear(woods, "BullTarget", 1)
	bull_bear.set_meta("killed_by", "bull")
	woods._on_bear_died(bull_bear)
	check("Inferno Bull's kill does not increment Lil Blunt's tally", GameManager.bear_total() == 1
		and int(GameManager.bear_tally.get("brawler", 0)) == 1, str(GameManager.bear_tally))
	woods.queue_free()

	_reset_manager()
	var runner_session := Ep2SessionRoot.new()
	add_child(runner_session)
	runner_session.configure([{"chamber": "miner_shaft", "chamber_z": 500.0, "obstacles": [], "archers": []}], false)
	runner_session.start()
	var tally_runner: RunnerGraybox = runner_session.get_active() as RunnerGraybox
	check("the session entered a live runner for its kill-signal wiring", tally_runner != null)
	if tally_runner != null:
		tally_runner.set_physics_process(false)
		tally_runner.archer_down.emit("ledger_archer")
		tally_runner.shovel_bear_down.emit(7)
	check("runner archer and shovel signals each tally their own kind",
		int(GameManager.bear_tally.get("archer", 0)) == 1 and int(GameManager.bear_tally.get("shovel", 0)) == 1
		and GameManager.bear_total() == 2, str(GameManager.bear_tally))
	runner_session.queue_free()

	print("-- CHILL BUDS: heal once, never past three hearts")
	_reset_manager()
	var bud_woods := _make_woods()
	var hud_layer := CanvasLayer.new()
	bud_woods.add_child(hud_layer)
	var hud := Ep2FpsHud.new()
	hud_layer.add_child(hud)
	bud_woods._hud = hud
	hud.health_max = WoodsQuadChamber.HEALTH_MAX
	hud.show_health = true
	bud_woods._health = 2
	hud.health = 2
	GameManager.add_chill_buds(2)
	check("two buds at 2/3: use restores 3/3, updates the HUD, and leaves one bud",
		bud_woods.use_chill_bud() and bud_woods.get_health() == 3 and hud.health == 3 and GameManager.chill_buds == 1,
		"health %d, hud %d, buds %d" % [bud_woods.get_health(), hud.health, GameManager.chill_buds])
	check("at 3/3 the bud is refused and kept, with the chill toast",
		not bud_woods.use_chill_bud() and GameManager.chill_buds == 1 and hud.toast_text == "ALREADY FEELING CHILL")
	var plain_room := Ep2Interlude.new()
	check("a room without health also keeps the bud", not plain_room.use_chill_bud() and GameManager.chill_buds == 1)
	plain_room.free()
	bud_woods.queue_free()

	print("-- SAVE / LOAD")
	_reset_manager()
	GameManager.tally_bear("brawler")
	GameManager.tally_bear("brawler")
	GameManager.tally_bear("shovel")
	GameManager.add_chill_buds(5)
	check("the ledger saves with the purse", GameManager.save_session())
	_reset_manager()
	check("reset_session clears the transient and persistent ledger state",
		GameManager.bear_total() == 0 and GameManager.chill_buds == 0 and GameManager.runner_btc_credited == 0)
	check("the save loads", GameManager.load_session())
	check("save/load round-trips tally and buds",
		int(GameManager.bear_tally.get("brawler", 0)) == 2 and int(GameManager.bear_tally.get("shovel", 0)) == 1
		and GameManager.bear_total() == 3 and GameManager.chill_buds == 5,
		"%s, buds %d" % [str(GameManager.bear_tally), GameManager.chill_buds])

	print("-- SELECTOR: headless leather, purse and ledger")
	_reset_manager()
	GameManager.tally_bear("archer")
	GameManager.add_chill_buds(2)
	GameManager.runner_btc_credited = 3
	var selector := Ep2WeaponSelector.new()
	selector.state = Ep2ArmoryState.post_hideout()
	add_child(selector)
	# The project stretches canvas_items with aspect "expand" from 1280x720, so the logical screen is never smaller than that:
	# 16:9, a landscape phone, a 4:3 tablet and a portrait phone are the screens it really gets. The selector's _process sizes
	# itself from the viewport (a portrait screen gets a 390-wide panel scaled up); it is paused here and sized the same way.
	selector.set_process(false)
	for screen in [Vector2(1280, 720), Vector2(1560, 720), Vector2(1280, 960), Vector2(1280, 2770)]:
		var ui_scale: float = screen.x / 390.0 if screen.x / screen.y < 1.1 else 1.0
		selector.size = screen / ui_scale
		selector.queue_redraw()
		await get_tree().process_frame
		screen = selector.size
		var ledger: Rect2 = selector._ledger_band()
		var fits: bool = ledger.position.y > selector._purse_band().end.y
		for i in Ep2ArmoryState.IDS.size():
			var r: Rect2 = selector.card_rect(i)
			fits = fits and r.position.y > ledger.end.y and r.size.y >= 80.0 and r.position.x >= 0.0 and r.end.x <= screen.x
		var hint_y: float = selector.card_rect(1).end.y + 49.0 + 6.0        # the bottom hint line's baseline + descent
		check("at %dx%d the ledger sits under the purse, the cards under the ledger, the footer on screen" % [int(screen.x), int(screen.y)],
			fits and hint_y <= screen.y, "ledger %s, card1 %s" % [str(ledger), str(selector.card_rect(1))])
	check("the selector draws headless with a populated ledger",
		is_instance_valid(selector) and selector.cards.size() == Ep2ArmoryState.IDS.size())
	check("desktop still writes the selector's key / hold labels", " ".join(selector.drawn_text).contains("Hold"))
	# audit 2026-10-29 P1-3: the armory's labels named keys on a phone too. Force the touch answer
	# the way the manager reports it, redraw, and require none of them.
	var mgr: Node = get_node_or_null("/root/MobileLayoutManager")
	var was_touch: bool = bool(mgr.get("is_touch_device")) if mgr != null else false
	if mgr != null:
		mgr.set("is_touch_device", true)
	selector.queue_redraw()
	await get_tree().process_frame
	var phone_text: String = " ".join(selector.drawn_text)
	check("on a phone the selector writes no key names or hold / drag instructions",
		not phone_text.contains("Hold") and not phone_text.contains("EQUIP ON RELEASE")
		and not phone_text.contains("point or choose") and not phone_text.contains("Tab"), phone_text)
	if mgr != null:
		mgr.set("is_touch_device", was_touch)
	selector.queue_free()
	await get_tree().process_frame

	_reset_manager()
	_restore_save()
	print("EP2_TABS_LEDGER: ", "ALL PASS" if failures == 0 else "%d FAILURE(S)" % failures)
	get_tree().quit(failures)


func _restore_save() -> void:
	if _save_existed:
		var f := FileAccess.open(GameManager.SAVE_PATH, FileAccess.WRITE)
		if f != null:
			f.store_string(_save_backup)
			f.close()
	elif FileAccess.file_exists(GameManager.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GameManager.SAVE_PATH))
