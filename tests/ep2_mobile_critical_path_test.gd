extends Node
## Gate for the Episode 2 mobile sprint (2026-11-10): the residual soft-locks and forced waits on the critical path, each asserted as what a
## player would live through (seconds stood waiting, a story that moves on, a walk with no way back in it) rather than as a code path.
##   1. HIDEOUT LAVA: Lil Blunt who hops the lava before (or during) Inferno's warning is not held at the open door for the rest of the talk.
##   2. LIFT: a Lil Blunt who reaches the cage first is not left standing on it for the length of Inferno's stroll and turn.
##   3. QUAD: arriving late at the thicket still gets the reveal, the mount and the ride (Inferno used to stand and stare for good).
##   4. TOWN: Inferno back on his quad never walks past the fallen stranger to Lil Blunt and then BACK up the street to it; and a Lil Blunt
##      standing in the lane does not leave him sat on the idling quad for ever.
##   5. MUSIC: a line spoken while the ride / lake song blends in does not jump either song (the blend follows the duck as a ramp).
## The donkey's road to the water trough is gated in ep2_farmer_trip_test (it needs the real session and the real crowd).
## Run: godot --headless res://tests/ep2_mobile_critical_path_test.tscn  (pinned: EXPECTED_PASS checks, 0 FAIL)

const FACILITY := preload("res://src/episode2/chamber/smelting_facility.tscn")
const LIFT := preload("res://src/episode2/chamber/mine_lift.tscn")
const WOODS := preload("res://src/episode2/chamber/woods_quad.tscn")
const TOWN := preload("res://src/episode2/chamber/gold_town.tscn")
const EXPECTED_PASS := 31
const DT := 1.0 / 60.0
## The music checks run on wall-clock frames: under a loaded CI box the steepest legitimate step measured 255 dB/s. The bug they guard
## (a speech duck applied as a step) moved 720-960 dB/s, so 400 keeps a clear margin on both sides.
const MAX_DB_PER_S := 400.0

var _pass: int = 0
var _fail: int = 0


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		_pass += 1
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])


func _ready() -> void:
	print("-- EP2 MOBILE CRITICAL PATH")
	await test_lava_crossed_before_the_warning()
	await test_lava_crossed_during_the_warning()
	await test_lift_does_not_keep_him_waiting()
	await test_quad_after_a_delayed_arrival()
	await test_inferno_return_no_way_back()
	await test_quad_does_not_idle_in_front_of_him()
	await test_music_blend_under_speech()
	var pinned: bool = _pass == EXPECTED_PASS
	if not pinned:
		print("  [FAIL] pinned check count: %d passed, %d expected" % [_pass, EXPECTED_PASS])
	print("EP2_MOBILE_CRITICAL_PATH: %s (%d pass, %d fail)" % ["ALL PASS" if _fail == 0 and pinned else "FAIL", _pass, _fail])
	get_tree().quit(0 if _fail == 0 and pinned else 1)


# --- 1. the hideout's lava river ------------------------------------------------------------------------------------------------

## The hideout at the start of its EXIT beat (the range lesson done, Inferno about to lead out), `said` filled with [line id, facility time].
func _facility_at_exit(said: Array) -> SmeltingFacilityChamber:
	var hf: SmeltingFacilityChamber = FACILITY.instantiate()
	hf.intro_film = false
	add_child(hf)
	hf.setup(0, [], 0)
	hf.set_physics_process(false)
	await get_tree().process_frame
	hf._on_video_film_finished()
	hf.line_spoken.connect(func(id: String) -> void: said.append([id, hf._elapsed]))
	hf._enter_fps()
	hf._player_pos = Vector3(0.0, 0.0, SmeltingFacilityChamber.CHANNEL_Z - 2.5)
	hf._line_end = 0.0                           # the beats before EXIT are over: nobody is mid-sentence (setup's wake line is not on trial)
	hf._beat = SmeltingFacilityChamber.Beat.EXIT
	hf._on_beat_entered(SmeltingFacilityChamber.Beat.EXIT)
	return hf


func _ids(said: Array) -> Array:
	return said.map(func(row: Array) -> String: return str(row[0]))


func _time_of(said: Array, id: String) -> float:
	for row in said:
		if str(row[0]) == id:
			return float(row[1])
	return -1.0


func test_lava_crossed_before_the_warning() -> void:
	print("-- 1a. he hops the lava before Inferno has said a word about it")
	# Arrange: the EXIT beat has just begun; Lil Blunt is already on the far bank
	var said: Array = []
	var hf: SmeltingFacilityChamber = await _facility_at_exit(said)
	var far := Vector3(0.0, 0.0, SmeltingFacilityChamber.CHANNEL_Z + SmeltingFacilityChamber.LAVA_HALF + 0.6)
	hf._player_pos = far
	# Act: until the door lets him through
	var waited: float = 0.0
	while waited < 30.0 and not hf._exit_open():
		hf._player_pos = far
		hf.step(DT)
		waited += DT
	var open_at: float = hf._elapsed
	for i in 120:
		hf._player_pos = far
		hf.step(DT)
	# Assert
	_check("the door is open within 4.5 s of the beat starting (it was the whole warning: ~13 s) - waited %.1f s" % waited, hf._exit_open() and waited <= 4.5)
	_check("Inferno is across too (he hopped it; the door never opens on a companion left behind)",
		hf.get_bull().position.z > SmeltingFacilityChamber.CHANNEL_Z + SmeltingFacilityChamber.LAVA_HALF, str(hf.get_bull().position))
	_check("he does not warn or nag a Lil Blunt who is already over", not _ids(said).has("vo_bull_lava1") and not _ids(said).has("vo_bull_lava2")
		and not _ids(said).has("vo_bull_lava_nudge"), str(_ids(said)))
	_check("...he says \"made it\" and leads on", _ids(said).has("vo_bull_lava_made_it") and _time_of(said, "vo_bull_lava_made_it") <= open_at + 0.5
		and hf.get_bull().position.z > SmeltingFacilityChamber.CHANNEL_Z + SmeltingFacilityChamber.LAVA_HALF + 2.0,
		str(said))
	hf.queue_free()
	await get_tree().process_frame


func test_lava_crossed_during_the_warning() -> void:
	print("-- 1b. he hops over while Inferno is still warning him")
	# Arrange: Inferno is one second into "that river cooks" on the near bank
	var said: Array = []
	var hf: SmeltingFacilityChamber = await _facility_at_exit(said)
	var near := Vector3(0.0, 0.0, SmeltingFacilityChamber.CHANNEL_Z - 2.5)
	var guard: float = 0.0
	while guard < 20.0 and not _ids(said).has("vo_bull_lava1"):
		hf._player_pos = near
		hf.step(DT)
		guard += DT
	for i in 60:
		hf._player_pos = near
		hf.step(DT)
	var warned_at: float = _time_of(said, "vo_bull_lava1")
	var warning_ends: float = warned_at + hf._vo_len("vo_bull_lava1")
	# Act: Lil Blunt jumps now
	var far := Vector3(0.0, 0.0, SmeltingFacilityChamber.CHANNEL_Z + SmeltingFacilityChamber.LAVA_HALF + 0.6)
	var waited: float = 0.0
	while waited < 30.0 and not hf._exit_open():
		hf._player_pos = far
		hf.step(DT)
		waited += DT
	var open_at: float = hf._elapsed
	for i in 60 * 8:
		hf._player_pos = far
		hf.step(DT)
	var praised_at: float = _time_of(said, "vo_bull_lava_made_it")
	# Assert
	_check("the warning had begun (Arrange)", warned_at >= 0.0 and warning_ends > open_at, "%.2f .. %.2f, open %.2f" % [warned_at, warning_ends, open_at])
	_check("the door opens within 1.6 s of his landing (Inferno's own hop), not when the talk ends - waited %.2f s" % waited, waited <= 1.6)
	_check("the second instruction (\"hop over\") is dropped: he has done it", not _ids(said).has("vo_bull_lava2"), str(_ids(said)))
	_check("the warning is never cut off: \"made it\" starts only after it has ended (%.2f >= %.2f)" % [praised_at, warning_ends], praised_at >= warning_ends - 0.02)
	_check("...and the door did not wait for either line", open_at < praised_at)
	hf.queue_free()
	await get_tree().process_frame


# --- 2. the mine lift ----------------------------------------------------------------------------------------------------------

func test_lift_does_not_keep_him_waiting() -> void:
	print("-- 2. he runs to the cage ahead of Inferno")
	# Arrange: the lift as entered through the open doorway, Inferno a few steps in
	var lift: MineLiftChamber = LIFT.instantiate()
	add_child(lift)
	lift.setup(0, [], 0)
	lift.set_physics_process(false)
	await get_tree().process_frame
	# Act: Lil Blunt runs straight down the walkway onto the cage and stands there
	lift.set_move_input(Vector2(0.0, 1.0), true)
	var boarded_at: float = -1.0
	var rising_at: float = -1.0
	var t: float = 0.0
	while t < 60.0 and rising_at < 0.0:
		lift.step(DT)
		t += DT
		if boarded_at < 0.0 and lift._player_on_cage():
			boarded_at = t
			lift.set_move_input(Vector2.ZERO)
		if lift.get_beat_name() == "RISE":
			rising_at = t
	var stood: float = rising_at - boarded_at
	# Assert
	_check("he boards (%.1f s) and the cage starts (%.1f s)" % [boarded_at, rising_at], boarded_at >= 0.0 and rising_at >= 0.0)
	_check("he stands on the cage %.1f s before it moves (it was 4.6 s here: Inferno's stroll, his turn, the lever, another turn)" % stood, stood <= 3.6)
	_check("Inferno is aboard, in his corner by the lever", lift.get_bull().position.distance_to(MineLiftChamber.CAGE_STAND_BULL + Vector3(0.0, lift.get_cage_y(), 0.0)) < 0.6,
		str(lift.get_bull().position))
	_check("the lever was really pulled and the walkway gate is shut", lift._lever_t >= 0.0 and lift._gate_in_goal == 0.0)
	lift.queue_free()
	await get_tree().process_frame


# --- 3. the quad in the thicket -------------------------------------------------------------------------------------------------

func test_quad_after_a_delayed_arrival() -> void:
	print("-- 3. he dawdles in the wood and reaches the quad late")
	# Arrange: Inferno on the last stretch of the trail, Lil Blunt 40 m behind
	var w: WoodsQuadChamber = WOODS.instantiate()
	add_child(w)
	w.setup(0, [], 0)
	w.set_physics_process(false)
	w.debug_invulnerable = true
	await get_tree().process_frame
	var trail: Array = WoodsQuadChamber.SNEAK_TRAIL
	var end2: Vector2 = trail[trail.size() - 1]
	var before: Vector2 = trail[trail.size() - 2]
	w._sneak_i = trail.size() - 1
	w.get_bull().position = Vector3(before.x, 0.0, before.y)
	var back := Vector3((trail[trail.size() - 4] as Vector2).x, 0.0, (trail[trail.size() - 4] as Vector2).y)
	# Act 1: Inferno reaches the thicket alone and waits
	var stopped_short: bool = false
	for i in 60 * 25:
		w._player_pos = back
		w.step(DT)
		var gap: float = Vector2(w.get_bull().position.x, w.get_bull().position.z).distance_to(end2)
		if not w.get_bull().is_walking() and gap > 0.35 and gap < 1.6:
			stopped_short = true
	var waiting_beat: String = w.get_beat_name()
	# Act 2: Lil Blunt walks up to him
	var t: float = 0.0
	while t < 40.0 and w.get_beat_name() == "SNEAK":
		var to: Vector3 = w.get_bull().position - w._player_pos
		to.y = 0.0
		if to.length() > 3.0:
			w._player_pos += to.normalized() * 3.4 * DT
		w.step(DT)
		t += DT
	var revealed_after: float = t
	while t < 90.0 and w.get_beat_name() != "RIDE":
		w.step(DT)
		t += DT
	# Assert
	_check("Inferno waits for him at the thicket (the reveal is theirs together)", waiting_beat == "SNEAK")
	_check("...stopped short of the last trail mark, where the old arrival check could never pass again (Arrange)", stopped_short)
	_check("when he catches up the reveal starts (within %.1f s of walking up)" % revealed_after, w.get_beat_name() != "SNEAK" and revealed_after < 20.0, w.get_beat_name())
	_check("...and it runs through the mount to the ride: Inferno never just stands and stares", w.get_beat_name() == "RIDE", w.get_beat_name())
	w.queue_free()
	await get_tree().process_frame


# --- 4. Inferno back in town ---------------------------------------------------------------------------------------------------

func _town_after_the_draw() -> GoldTownChamber:
	var c: GoldTownChamber = TOWN.instantiate()
	add_child(c)
	c.setup(0, [], 0)
	await get_tree().process_frame
	var opp: Ep2TownFolk = c.get_opponent()
	opp.position = GoldTownChamber.OPP_MARK
	opp.fall_dead()
	c.get_minister().visible = true
	c.get_minister().position = opp.position + GoldTownChamber.KNEEL_AT
	c._minister_task = "kneeling"
	c._minister_t = 3.0
	c._advance_to(GoldTownChamber.Beat.LOOT)
	c._won_t = -1000.0
	c._got_peacemaker = true
	return c


func test_inferno_return_no_way_back() -> void:
	print("-- 4a. Lil Blunt waits by the saloon; Inferno rides in at the far end of the street, the body between them")
	# Arrange
	var c: GoldTownChamber = await _town_after_the_draw()
	var porch: Vector3 = Ep2GoldTown.door_world("Bldg_Saloon", 3.0)
	var bar: Vector3 = Ep2GoldTown.local_to_world("Bldg_Saloon", GoldTownChamber.BAR_SPOT)
	c._player_pos = porch
	var caps: Array = []
	c.captioned.connect(func(who: String, text: String) -> void: caps.append([who, text]))
	c._advance_to(GoldTownChamber.Beat.BULL_BACK)
	var bull: Ep2Actor = c.get_bull()
	var body: Vector3 = c.get_opponent().position
	# Act: Lil Blunt stays put until Inferno has stopped, then walks to him, then follows him to the bar
	var walked: float = 0.0
	var last: Vector3 = Vector3.INF
	var stop_spot: Vector3 = Vector3.INF          # where Inferno first stops and waits for him
	var greeted_bar: float = -1.0                 # how far he is from the bar when the talk begins
	var furthest_after: float = -1.0              # ...and the furthest he gets from it afterwards
	var reached_bar: bool = false
	for f in 240 * 60:
		var beat: String = c.get_beat_name()
		if beat in ["BULL_BACK", "BODY"]:
			if stop_spot != Vector3.INF:
				var to: Vector3 = bull.position - c._player_pos
				to.y = 0.0
				if to.length() > 2.6:
					c._player_pos += to.normalized() * minf(3.4 * DT, to.length() - 2.6)
		elif beat == "DRINKS":
			c._player_pos = bar
		c.step(DT)
		if c._bull_task != "riding":
			if last != Vector3.INF:
				walked += bull.position.distance_to(last)
			last = bull.position
			if stop_spot == Vector3.INF and c._bull_task == "to_lb" and not bull.is_walking() and c._bull_path.is_empty() and c._bull_wait_t == 0.0:
				stop_spot = bull.position
			if greeted_bar < 0.0 and c._bull_task == "greeted":
				greeted_bar = bull.position.distance_to(bar)
			if greeted_bar >= 0.0:
				furthest_after = maxf(furthest_after, bull.position.distance_to(bar))
		if beat == "DRINKS" and c._bull_task == "at_bar":
			reached_bar = true
			break
	var order: Array = caps.filter(func(l: Array) -> bool: return l[0] in ["INFERNO", "LIL BLUNT", "MIKE DEAN"]).map(func(l: Array) -> String: return str(l[1]))
	var what_i: int = order.find(GoldTownChamber.BODY_LINES[2][1])
	var whiskey_i: int = order.find(GoldTownChamber.BULL_BACK_LINES[1][1])
	# Assert
	_check("he stops at the fallen stranger on his way to Lil Blunt (%.1f m from the body)" % stop_spot.distance_to(body), stop_spot != Vector3.INF and stop_spot.distance_to(body) < 4.5)
	_check("after the talk he never gets further from the bar than where it began: no walk back up the street (%.1f m then, %.1f m at most after)" % [greeted_bar, furthest_after],
		greeted_bar >= 0.0 and furthest_after <= greeted_bar + 0.5)
	_check("his whole walk from the quad to the bar is one way (%.0f m; it was 117 m with the trip back)" % walked, reached_bar and walked < 95.0)
	_check("he asks who put a hole in him BEFORE \"First whiskey's on me\", and the bird line still plays", what_i >= 0 and whiskey_i > what_i
		and order.has(GoldTownChamber.BODY_LINES[3][1]) and order.count(GoldTownChamber.BULL_BACK_LINES[1][1]) == 1, str(order))
	_check("he reaches the bar", reached_bar, "%s %s" % [c.get_beat_name(), c._bull_task])
	c.queue_free()
	await get_tree().process_frame


func test_quad_does_not_idle_in_front_of_him() -> void:
	print("-- 4b. Lil Blunt stands in the lane to Rich's, in the quad's road, and does not move")
	# Arrange
	var c: GoldTownChamber = await _town_after_the_draw()
	var lane := Vector3(-2.2, 0.0, 1452.0)
	c._player_pos = lane
	c._advance_to(GoldTownChamber.Beat.BULL_BACK)
	var bull: Ep2Actor = c.get_bull()
	# Act: 60 s without Lil Blunt taking a step
	var off_at: float = -1.0
	var greeted_at: float = -1.0
	var quad_gap: float = INF
	var t: float = 0.0
	while t < 60.0 and greeted_at < 0.0:
		c._player_pos = lane
		c.step(DT)
		t += DT
		quad_gap = minf(quad_gap, Vector2(c.get_quad().position.x - lane.x, c.get_quad().position.z - lane.z).length())
		if off_at < 0.0 and c._bull_task != "riding":
			off_at = t
		if c._bull_task == "greeted":
			greeted_at = t
	# Assert
	_check("the quad stops for him, never through him (closest %.1f m)" % quad_gap, quad_gap > 1.6)
	_check("Inferno cuts the engine and gets off where he is (after %.1f s; he used to sit there for as long as Lil Blunt stood)" % off_at, off_at >= 0.0 and c.get_quad().is_parked)
	_check("...and the story goes on: he walks up and greets him (%.1f s)" % greeted_at, greeted_at >= 0.0 and bull.position.distance_to(lane) < 6.5)
	# the ride out later starts from where the quad really is, back down the road it came in on - never on toward Rich's first
	c._bull_task = "leaving"
	bull.position = c.get_quad().dismount_spot()
	c._ride_off()
	var first_leg: Vector3 = (c.get_quad().path[1] as Vector3) - (c.get_quad().path[0] as Vector3)
	var to_shop: Vector3 = Ep2GoldTown.local_to_world("Bldg_Armory", GoldTownChamber.QUAD_PARK_LOCAL) - c.get_quad().position
	_check("when he leaves, the quad turns back down the road it came in on", c._bull_task == "riding_off" and first_leg.dot(Vector3(to_shop.x, 0.0, to_shop.z)) < 0.0,
		"%s vs %s" % [first_leg, to_shop])
	c.queue_free()
	await get_tree().process_frame


# --- 5. the ride song and the lake song ------------------------------------------------------------------------------------------

func _music_decks() -> Dictionary:
	var out: Dictionary = {}
	for n in AudioManager.get_children():
		var p := n as AudioStreamPlayer
		if p != null and p.bus == "Music" and p.playing and not p.stream_paused:
			out[p.get_instance_id()] = db_to_linear(p.volume_db)
	return out


## The fastest any audible deck's level moves during `seconds`, in dB per second (frame to frame; a frame shorter than 1/60 s counts
## as 1/60 s, so the number is "dB per frame at 60 fps" x 60). The duck's own ramp is 80 dB/s; a level that STEPS with the duck moves
## 12-16 dB in one frame = 720-960 dB/s. Decks below -26 dB are ignored (the head and tail of a fade are steep in dB and inaudible).
func _worst_db_rate(seconds: float) -> float:
	var worst: float = 0.0
	var prev: Dictionary = {}
	var prev_us: int = Time.get_ticks_usec()
	var t0: int = prev_us
	while Time.get_ticks_usec() - t0 < int(seconds * 1.0e6):
		await get_tree().process_frame
		var now_us: int = Time.get_ticks_usec()
		var dt: float = maxf(float(now_us - prev_us) / 1.0e6, DT)
		var decks: Dictionary = _music_decks()
		for id in decks:
			if prev.has(id) and float(decks[id]) > 0.05 and float(prev[id]) > 0.05:
				worst = maxf(worst, absf(linear_to_db(float(decks[id])) - linear_to_db(float(prev[id]))) / dt)
		prev = decks
		prev_us = now_us
	return worst


func test_music_blend_under_speech() -> void:
	print("-- 5. he mounts and someone speaks while the ride song comes in; Logan speaks while the lake song comes in")
	if not ResourceLoader.exists(Ep2DrawMusic.TRACK) or not ResourceLoader.exists(Ep2DrawMusic.LAKE_TRACK):
		# the songs ship in the streamed extras; a build without them has nothing to blend (the gate must not pass vacuously in CI)
		_check("the ride and lake songs are present to test", false, "missing %s / %s" % [Ep2DrawMusic.TRACK, Ep2DrawMusic.LAKE_TRACK])
		return
	# Arrange: the town score at rest
	Ep2DrawMusic.begin_town(self)
	await get_tree().create_timer(1.0).timeout
	AudioManager._tween_music_to(0.0, 0.01)
	await get_tree().create_timer(0.2).timeout
	# Act 1: the mount - the ride song blends in over 8 s; a line starts 1 s in and ends ~2.7 s later, inside the blend
	Ep2DrawMusic.begin_trail(self)
	await get_tree().create_timer(1.0).timeout
	AudioManager.duck_for_speech(2.0)
	var mount_rate: float = await _worst_db_rate(5.0)
	var mid: Dictionary = _music_decks()
	var mid_power: float = 0.0
	for id in mid:
		mid_power += float(mid[id]) * float(mid[id])
	await get_tree().create_timer(3.0).timeout
	var after_mount: Dictionary = _music_decks()
	# Act 2: the lake - same, the line starting with the blend
	Ep2DrawMusic.begin_lake(self)
	AudioManager.duck_for_speech(2.0)
	var lake_rate: float = await _worst_db_rate(6.0)
	await get_tree().create_timer(3.0).timeout
	var after_lake: Dictionary = _music_decks()
	# Assert (before the fix both songs stepped 12 dB in a single frame when the line began and again when it ended: >= 720 dB/s)
	_check("mounting: no song jumps while a line is spoken inside the blend (fastest %.0f dB/s; the duck ramps at 80)" % mount_rate, mount_rate < MAX_DB_PER_S)
	_check("...the two songs together hold one loudness mid-blend (power %.2f)" % mid_power, mid_power > 0.7 and mid_power < 1.25)
	_check("...and it ends on the ride song alone, at full level", after_mount.size() == 1 and float(after_mount.values()[0]) > 0.9, str(after_mount))
	_check("the lake: no song jumps either (fastest %.0f dB/s)" % lake_rate, lake_rate < MAX_DB_PER_S)
	_check("...and it ends on the lake song alone, at full level", after_lake.size() == 1 and float(after_lake.values()[0]) > 0.9, str(after_lake))
	AudioManager.fade_out_music(0.1)
	await get_tree().create_timer(0.3).timeout
