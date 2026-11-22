extends Node
## Founder 2026-11-22: "everything slows down after trading with Rich". Measures the town before the trade, with Rich's panel open,
## after buying the Sharps and the Shipment, and after the panel closes: frame time, process time, node count, draw calls, and every
## SubViewport still rendering. Run with a renderer so SubViewport cost shows:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --rendering-method gl_compatibility \
##     --resolution 1280x720 res://tools/ep2_perf/shop_trade_probe.tscn

var town: GoldTownChamber


func _phase(label: String, frames: int) -> void:
	var t_total: float = 0.0
	var proc: float = 0.0
	var draws: float = 0.0
	for i in frames:
		var t0: int = Time.get_ticks_usec()
		await get_tree().process_frame
		t_total += float(Time.get_ticks_usec() - t0) / 1000.0
		proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var live: Array = []
	for vp in get_tree().root.find_children("*", "SubViewport", true, false):
		var v := vp as SubViewport
		if v.render_target_update_mode != SubViewport.UPDATE_DISABLED and v.render_target_update_mode != SubViewport.UPDATE_ONCE:
			live.append(str(v.get_parent().name) + "/" + str(v.name))
	var shop: Ep2ArmoryShop = town._shop
	print("PROBE %-22s frame %6.2f ms  process %6.2f ms  draws %6.0f  nodes %6d  shop vis=%s proc=%s  live SubViewports %s" % [label,
		t_total / frames, proc / frames, draws / frames, Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		str(shop.visible) if shop else "-", str(shop.is_processing()) if shop else "-", str(live)])


func _snapshot() -> Dictionary:
	var out: Dictionary = {}
	for n in get_tree().root.find_children("*", "", true, false):
		if n is GeometryInstance3D and (n as GeometryInstance3D).is_visible_in_tree():
			out["G " + str(town.get_path_to(n)) if town.is_ancestor_of(n) else "G " + str(n.get_path())] = true
		if n.is_processing() or n.is_physics_processing():
			out["P " + str(n.get_path())] = true
	return out


func _diff(a: Dictionary, b: Dictionary) -> void:
	var added: Dictionary = {}
	for k in b:
		if not a.has(k):
			var parts: PackedStringArray = str(k).split("/")
			var key: String = "/".join(parts.slice(0, mini(parts.size(), 4)))
			added[key] = int(added.get(key, 0)) + 1
	for k in added:
		print("PROBE   + %4d  %s" % [added[k], k])
	var removed: int = 0
	for k in a:
		if not b.has(k): removed += 1
	print("PROBE   removed %d" % removed)


func _ready() -> void:
	var session: Ep2SessionRoot = load("res://src/episode2/session/ep2_session_root.tscn").instantiate()
	add_child(session)
	session.set_process(false)
	session.armory = Ep2ArmoryState.post_hideout()
	town = load("res://src/episode2/chamber/gold_town.tscn").instantiate()
	session.add_child(town)
	session._active = town
	session._wire_chamber(town)
	town.setup()
	GameManager.purse_add("btc", 60)
	for i in 120:
		await get_tree().process_frame
	var mode: String = "both"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("mode="): mode = a.substr(5)
	print("PROBE mode ", mode)
	await _phase("baseline", 90)
	var before: Dictionary = _snapshot()
	if mode != "buy_only":
		town._open_shop()
		await _phase("panel open", 90)
	if mode != "open_only":
		print("PROBE buy shipment: ", town.buy("river_gear", 0, "btc"), "  buy sharps: ", town.buy(Ep2ArmoryState.BUFF, 0, "btc"))
		await _phase("bought", 90)
	if mode != "buy_only":
		town._close_shop()
	await _phase("closed +0-1.5 s", 90)
	await _phase("closed +1.5-3 s", 90)
	await _phase("closed +3-6 s", 180)
	_diff(before, _snapshot())
	if mode == "open_only":
		town._shop.set_process(false)
		await _phase("closed, shop _process off", 180)
		var t0: int = Time.get_ticks_usec()
		for i in 100: town._shop._process(0.016)
		print("PROBE hidden shop _process cost: %.2f ms per call" % (float(Time.get_ticks_usec() - t0) / 100000.0))
		t0 = Time.get_ticks_usec()
		for i in 100: town._shop._tabs()
		print("PROBE   _tabs(): %.3f ms per call" % (float(Time.get_ticks_usec() - t0) / 100000.0))
	town._hud.call("open_panel") if town._hud.has_method("open_panel") else null
	get_tree().quit()
