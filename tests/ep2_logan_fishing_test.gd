extends Node
## Gate for PROMPT_EPISODE2_LOGAN_FISHING_RETURN_HUGE_FISH_2026-11-28 (skill `ep2-logan-fishing-process`):
##   1. rowing -> fishing is a readable chain (blades lift, oars ship and stay in view, hands go to the rod lying in the boat, rod up,
##      line cast out over >1.5 s) - no oar teleport, no rod pop-in, no one-frame line;
##   2. fishing -> rowing is the same chain backwards;
##   3. on the return from the ridge (after day-88) Logan is already fishing and stays fishing (never reset to rowing or the shore);
##   4. a huge fish jumps over his head with two splashes when Lil Blunt has him in view - once per visit, not on every camera wiggle -
##      and he is still fishing afterwards;
##   5. the player never fishes (no fish prompt, no fish in the purse).
## Measured on the real skiff GLB, the supplied Logan rig and the real lake chamber; nothing is asserted from the constants it set.
const LAKE := preload("res://src/episode2/chamber/logans_lake.tscn")
const DT := 1.0 / 30.0
var failures: int = 0
var checks: int = 0


func check(label: String, ok: bool, detail: String = "") -> void:
	checks += 1
	if not ok: failures += 1
	print("  [%s] %s %s" % ["PASS" if ok else "FAIL", label, detail])


func _lake(after: bool) -> LogansLakeChamber:
	var c: LogansLakeChamber = LAKE.instantiate() as LogansLakeChamber
	c.handoff = {"after_day88": after}
	add_child(c)
	c.set_physics_process(false)
	c.bind_armory(Ep2ArmoryState.new())
	c.setup(0, [], 0)
	return c


func _advance(c: LogansLakeChamber, seconds: float) -> void:
	for i in int(seconds / DT): c.step(DT)


func _until(c: LogansLakeChamber, cond: Callable, max_seconds: float) -> bool:
	for i in int(max_seconds / DT):
		if cond.call(): return true
		c.step(DT)
	return cond.call()


## Look straight at the boat from where he stands (yaw and pitch toward Logan).
func _look_at_boat(c: LogansLakeChamber, b: Ep2LoganSkiff) -> void:
	var eye: Vector3 = c._player_pos + Vector3(0, c.eye_height, 0)
	var to: Vector3 = b.boat.global_position + Vector3(0, 1.0, 0) - eye
	c._look_yaw = atan2(to.x, to.z)
	c._look_pitch = atan2(to.y, Vector2(to.x, to.z).length())


func _ready() -> void:
	await get_tree().process_frame
	await test_logan_skiff_row_to_fish_settle_is_readable_chain()
	await test_logan_skiff_return_from_ridge_already_fishing()
	await test_logan_lake_huge_fish_jumps_once_with_splash()
	print("LOGAN_FISHING: ", "ALL PASS" if failures == 0 else "%d FAIL" % failures, " (", checks, " checks)")
	get_tree().quit(0 if failures == 0 else 1)


func test_logan_skiff_row_to_fish_settle_is_readable_chain() -> void:
	# Arrange: first visit, the shipment launched, Logan walks to his boat and rows
	var c := _lake(false)
	await get_tree().process_frame
	var b: Ep2LoganSkiff = c._skiff
	check("skiff art is mounted", b != null and b.ready_art)
	if b == null or not b.ready_art:
		c.queue_free(); return
	check("the rod lies in the moored boat from the start (picked up later, never conjured)", b._rod.visible and b._rod_raise == 0.0 and not b.line_visible())
	c.armory.purchase_river_gear("btc")
	c._player_pos = c.STAGING_MARK + Vector3(-1, 0, 0)
	c._advance_to(c.Beat.STAGE)
	c.start_rig()
	check("Logan rows out", _until(c, func(): return b.state == b.State.ROW, 40.0))
	check("the rod stays visible, stowed, the whole row", b._rod.visible and b._rod_raise == 0.0)
	_until(c, func(): return b.state == b.State.SETTLE, 30.0)
	# Act: trace the settle frame by frame
	var oars_hidden := false
	var rod_hidden := false
	var max_tip_step := 0.0
	var max_oar_step := 0.0
	var max_palm_step := 0.0
	var line_early := false
	var t_line := -1.0
	var t_bobber_down := -1.0
	var t := 0.0
	var start_contact := 0.0
	for j in 2: start_contact = maxf(start_contact, b.palm_position("Left" if j == 0 else "Right").distance_to(b.grips[j].global_position))
	var tip: Vector3 = b.rod_tip_world()
	var oar_rot: Array = [b.oars[0].rotation, b.oars[1].rotation]
	var palms: Array = [b.palm_position("Left"), b.palm_position("Right")]
	var order_ok := true
	while b.state == b.State.SETTLE and t < 10.0:
		c.step(DT); t += DT
		for o in b.oars: if not o.visible: oars_hidden = true
		if not b._rod.visible: rod_hidden = true
		var nt: Vector3 = b.rod_tip_world()
		max_tip_step = maxf(max_tip_step, nt.distance_to(tip)); tip = nt
		for k in 2:
			max_oar_step = maxf(max_oar_step, (b.oars[k].rotation - oar_rot[k]).length()); oar_rot[k] = b.oars[k].rotation
			var p: Vector3 = b.palm_position("Left" if k == 0 else "Right")
			max_palm_step = maxf(max_palm_step, p.distance_to(palms[k])); palms[k] = p
		if b.line_visible() and b._rod_raise < .999: line_early = true
		if b._hand_blend > .01 and b.oars[0].rotation.y != 0.0 and absf(absf(b.oars[0].rotation.y) - b.SHIP_YAW) > .02: order_ok = false
		if b._rod_raise > .01 and b._hand_blend < .999: order_ok = false
		if t_line < 0.0 and b.line_visible(): t_line = t
		if t_bobber_down < 0.0 and b._cast >= 1.0: t_bobber_down = t
	print("SETTLE tip_step=", max_tip_step, " oar_step=", max_oar_step, " palm_step=", max_palm_step, " line=", t_line, " down=", t_bobber_down, " total=", t)
	# Assert
	check("palms start the settle on the oar grips", start_contact < .04, "%.3f" % start_contact)
	check("oars never vanish while he settles to fish", not oars_hidden)
	check("the rod never vanishes or pops in", not rod_hidden)
	check("each step finishes before the next starts (ship -> hands -> rod up -> cast)", order_ok)
	check("the line only goes out once the rod is up", not line_early)
	check("the cast reads: the bobber takes over 1.5 s to land", t_line > 0.0 and t_bobber_down - t_line > 1.5, "%.2f s" % (t_bobber_down - t_line))
	check("the rod tip moves smoothly (no teleport frame)", max_tip_step < .25, "%.3f m/frame" % max_tip_step)
	check("the oars swing in smoothly (no teleport frame)", max_oar_step < .12, "%.3f rad/frame" % max_oar_step)
	check("the hands travel from oars to rod (no snap)", max_palm_step < .2, "%.3f m/frame" % max_palm_step)
	check("he settles into the fishing idle", b.state == b.State.FISH and b.is_fishing_settled())
	var contact := 0.0
	var blade_low := INF
	for i in 60:
		c.step(DT)
		for j in 2:
			contact = maxf(contact, b.palm_position("Left" if j == 0 else "Right").distance_to(b._fish_grips[j].global_position))
			blade_low = minf(blade_low, b.blades[j].global_position.y)
	check("both palms hold the raised rod", contact < .04, "%.3f" % contact)
	check("shipped oars stay in the boat and out of the water", b.oars[0].visible and b.oars[1].visible and blade_low > b.WATER_Y + .03, "blade y %.2f" % blade_low)
	check("rod, line and bobber are out while he fishes", b._rod.visible and b.line_visible() and b._bobber.visible)
	# reverse chain
	_until(c, func(): return b.state == b.State.UNSETTLE, 40.0)
	var reverse_hidden := false
	var reverse_tip := 0.0
	tip = b.rod_tip_world()
	t = 0.0
	while b.state == b.State.UNSETTLE and t < 10.0:
		c.step(DT); t += DT
		for o in b.oars: if not o.visible: reverse_hidden = true
		if not b._rod.visible: reverse_hidden = true
		reverse_tip = maxf(reverse_tip, b.rod_tip_world().distance_to(tip)); tip = b.rod_tip_world()
	check("fishing -> rowing plays the chain backwards (reel in, rod down, oars out) over seconds", t > 5.0 and not reverse_hidden and reverse_tip < .25, "%.1f s" % t)
	check("he rows on with the rod stowed and the line in", b.state == b.State.ROW and b._rod_raise == 0.0 and not b.line_visible())
	c.queue_free()
	await get_tree().process_frame


func test_logan_skiff_return_from_ridge_already_fishing() -> void:
	# Arrange: the session comes back from the ridge after day-88
	var c := _lake(true)
	await get_tree().process_frame
	var b: Ep2LoganSkiff = c._skiff
	if b == null or not b.ready_art:
		check("skiff art is mounted on the return", false); c.queue_free(); return
	# Assert: fishing at once, not frozen rowing, not on the shore, not a T-pose
	check("on the return from the ridge Logan is already out fishing", b.state == b.State.FISH and b.is_fishing_settled() and b.hold_fishing)
	check("...rod up, line in the water, oars shipped in view", b._rod.visible and b.line_visible() and b.oars[0].visible and b.oars[1].visible and not b._rope.visible)
	check("...seated in the boat (not standing on the shore mark)", b.seat_error() < .02 and c._logan.global_position.distance_to(c.LOGAN_MARK) > 5.0, "seat %.3f" % b.seat_error())
	var contact := 0.0
	for j in 2: contact = maxf(contact, b.palm_position("Left" if j == 0 else "Right").distance_to(b._fish_grips[j].global_position))
	check("...hands on the rod (not empty hands)", contact < .04, "%.3f" % contact)
	# Act: a long visit
	_advance(c, 70.0)
	check("he is still fishing after a minute (never resets to rowing)", b.state == b.State.FISH and b.is_fishing_settled())
	check("the bobber sits on the water", absf(b.bobber_world().y - b.WATER_Y) < .08, "y %.3f" % b.bobber_world().y)
	c._on_setup()
	check("a reload of the return keeps him fishing", b.state == b.State.FISH and b.hold_fishing)
	c.queue_free()
	await get_tree().process_frame


func test_logan_lake_huge_fish_jumps_once_with_splash() -> void:
	# Arrange: back from the ridge, Logan fishing; Lil Blunt on the shore path, looking away
	var c := _lake(true)
	await get_tree().process_frame
	var b: Ep2LoganSkiff = c._skiff
	if b == null or not b.ready_art or c._fish_gag == null:
		check("fish gag is built with the skiff", false); c.queue_free(); return
	c._player_pos = Vector3(-7.0, 0, 30.0)
	c._look_yaw = PI; c._look_pitch = 0.0
	_advance(c, 3.0)
	check("no fish while Logan is out of view", not c.fish_gag_fired)
	# Act: he looks at Logan
	_look_at_boat(c, b)
	check("Logan's boat is in clear view from the path", c.fish_gag_in_view())
	var head: Vector3 = b.head_local()
	var leaned := false
	var fired_at := -1.0
	var t := 0.0
	while t < 6.0:
		c.step(DT); t += DT
		_look_at_boat(c, b)
		if c.fish_gag_fired and fired_at < 0.0: fired_at = t
		if absf(b._lean) > .12: leaned = true
	var g: Ep2LakeFishGag = c._fish_gag
	var peak: Vector3 = g.peak_reached
	print("FISH_GAG fired_at=", fired_at, " peak=", peak, " head=", head, " splashes=", g.splashes)
	# Assert
	check("the huge fish jumps once he has Logan in view (after a short settle, not instantly)", fired_at >= c.FISH_GAG_LOOK - DT and fired_at < 2.0, "%.2f s" % fired_at)
	check("it is comedy-scale (longer than Logan is tall)", g.LENGTH >= 2.4)
	check("its arc goes over Logan's head, close (a near miss)", peak.y - head.y > .4 and peak.y - head.y < 1.6 and Vector2(peak.x - head.x, peak.z - head.z).length() < .7, "clear %.2f m" % (peak.y - head.y))
	check("splash on the way out and on the belly-flop", g.splashes == 2)
	check("the splashes throw real water (particles + rings)", g.find_children("FishSplash", "CPUParticles3D", true, false).size() >= 1 or g.find_children("FishSplashRing", "", true, false).size() >= 1)
	check("Logan flinches", leaned)
	check("...and is still fishing after", b.state == b.State.FISH and b.is_fishing_settled() and not g.fish.visible)
	# camera wiggles: look away and back several times
	for k in 4:
		c._look_yaw = PI; _advance(c, 1.0)
		_look_at_boat(c, b); _advance(c, 1.5)
	check("one-shot per visit: wiggling the camera never re-fires it", g.splashes == 2 and not g.is_playing())
	var lake_src: String = FileAccess.get_file_as_string("res://src/episode2/chamber/logans_lake.gd").to_lower()
	check("the player never fishes: no fish prompt, no catch, no fish in the Tabs/purse", not lake_src.contains("fish [e]") and not lake_src.contains("catch_fish") and not lake_src.contains("purse_add(\"fish") and not c.has_method("catch_fish"))
	c._on_setup()
	check("a new visit re-arms the gag", not c.fish_gag_fired)
	c.queue_free()
	await get_tree().process_frame
