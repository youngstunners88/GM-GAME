extends Node
## Gate for the TransitionDirector (autoload; skills ep2-seamless-transition + gm-game-mobile-seamless-transitions).
## Proves: the Episode 2 warm-up completes incrementally within a frame budget (no long freeze), the hand-off goes
## cover -> load -> swap -> reveal -> idle, the global StateMachine follows (TRANSITIONING then PLAYING), nothing is
## left covering the screen, and the boss hand-offs use the director instead of the blue diamond wipe.
##
## PHONE HAND-OFF (mobile transitions audit 2026-10-22, DECISIONS section 5) - also proven here:
##  * the MENU route: SceneRouter.load_scene(EPISODE2_SCENE) is diverted to the director (card, warm-up, settle, reveal)
##    and a real Episode 2 scene comes out of it, with its first runner leg held at distance 0 and its music silent
##    until the cover lifts (F08 / F15 / F06);
##  * the old scene is FROZEN under the cover (the tree is paused), the freeze is re-asserted after state changes and
##    by the per-frame check, and PROCESS_MODE_ALWAYS nodes in the new scene still run while pausable ones wait (F09);
##  * the card is wordless and dp-sized on a touch device (one progress bar, no Labels), follows a rotation while it
##    is up, and keeps its words on desktop (F10); a cover grows the same bar after ~1.2 s, driven by warm_fraction (F09);
##  * a swap that fails (an empty PackedScene whose instantiate() returns null) fades and frees the cover, recovers the
##    StateMachine and routes home - no frozen frame, no retry loop; a missing destination frees the cover (F02);
##  * the Stage 3 film and its cover follow a rotation mid-film (F11).
## (A few "ERROR:" lines from the engine / ErrorReporter are EXPECTED in the failure sections: they ARE the failures.)
##
## Run: .godot-cache/Godot_v4.3-stable_linux.x86_64 --headless res://tests/transition_director_test.tscn

const EP2 := "res://src/episode2/ep2_entry.tscn"
const TARGET := "res://tests/fixtures/transition_target.tscn"
const PROBE := "res://tests/fixtures/transition_probe_target.tscn"
const HOME_FIXTURE := "res://tests/router_reveal_target.tscn"

var _fail: int = 0

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])


func _ready() -> void:
	print("TRANSITION DIRECTOR:")
	# The test node must survive the scene swap: live under the root, with a dummy "current scene" to be replaced.
	var root: Node = get_tree().root
	reparent.call_deferred(root)
	await get_tree().process_frame
	var dummy := Node.new()
	dummy.name = "DummyCurrentScene"
	root.add_child(dummy)
	get_tree().current_scene = dummy
	var td: Node = root.get_node("TransitionDirector")
	var mlm: Node = root.get_node("MobileLayoutManager")
	var win_size0: Vector2i = root.size
	var touch0: bool = bool(mlm.is_touch_device)
	var unlocked0: bool = GameManager.ep2_story_unlocked

	# 1. Warm-up is incremental and completes.
	var ep2: String = EP2
	td.prewarm(ep2)
	_check("prewarm starts WARMING", td.state == td.S.WARMING)
	var first_frac: float = td.warm_fraction()
	var worst_ms: float = 0.0
	var frames: int = 0
	var last_t: int = Time.get_ticks_usec()
	# While WARMING (the film is playing) the heavy script/scene items must be held back for the card.
	var held_late: bool = false
	while td.state == td.S.WARMING and frames < 400:
		await get_tree().process_frame
		var now0: int = Time.get_ticks_usec()
		worst_ms = maxf(worst_ms, float(now0 - last_t) / 1000.0)
		last_t = now0
		frames += 1
		if not td._late.is_empty():
			held_late = true
	_check("scripts/scenes are held back for the card, not loaded in front of the player", held_late and td.state == td.S.WARMING)
	_check("...so no single warm frame in front of the player stalled over 250 ms (%.0f ms worst)" % worst_ms, worst_ms < 250.0)
	# Stand-in for the covered phase (the card is up): everything left may load now.
	td.state = td.S.LOADING
	td._pump_warm(1.0e9)
	td._pump_warm(1.0e9)
	td.state = td.S.WARMING
	td._pump_warm(1.0)
	while td.state == td.S.WARMING and frames < 20000:
		await get_tree().process_frame
		var now: int = Time.get_ticks_usec()
		worst_ms = maxf(worst_ms, float(now - last_t) / 1000.0)
		last_t = now
		frames += 1
	_check("the whole Episode 2 warm-up finished (READY) over %d frames" % frames, td.state == td.S.READY, str(td.state))
	_check("it was spread over many frames, not one freeze", frames >= 5, str(frames))
	print("    worst single frame while warming: %.1f ms" % worst_ms)
	for si in td.slow_items:
		print("    slow item %.0f ms  %s" % [si[0], si[1]])
	_check("warm fraction reached 1.0", is_equal_approx(td.warm_fraction(), 1.0))
	_check("prewarm twice for the same path is a no-op", (func(): td.prewarm(ep2); return td.state == td.S.READY).call())
	_check("the two runner tracks the first leg plays at the reveal are in the Episode 2 warm list",
		_preset_has(td, "runner_run.mp3") and _preset_has(td, "runner_run_1.mp3"))

	# 1b. THE MENU ROUTE (F08/F15/F06): SceneRouter.load_scene(EPISODE2_SCENE) is diverted to the director and a REAL
	# Episode 2 scene comes out of it. Unlocked, so the first runner leg is built inside the new scene's _ready.
	GameManager.ep2_story_unlocked = true
	AudioManager.fade_out_music(0.01)
	var reveal_obs: Dictionary = {}
	var walk: Array = []
	var on_state := func(_f: String, to: String) -> void:
		walk.append(to)
		if to == "REVEALING":
			# (mutate the captured Dictionary: a lambda that REASSIGNS a captured variable changes only its own copy)
			var cs: Node = get_tree().current_scene
			var r: Node = _runner_of(cs)
			reveal_obs["scene"] = cs.scene_file_path if cs != null else ""
			reveal_obs["paused"] = get_tree().paused
			reveal_obs["runner"] = r != null
			reveal_obs["holding"] = r != null and bool(r.is_reveal_holding())
			reveal_obs["dist"] = float(r.get_distance()) if r != null else -1.0
			reveal_obs["music"] = AudioManager.current_music_player != null
	td.state_changed.connect(on_state)
	SceneRouter.load_scene(ep2, SceneRouter.Transition.FADE)
	_check("the router handed Episode 2 to the director: covering at once, router idle (no fade-to-black route)",
		td.state == td.S.COVERING and td._card.visible and td.target_path == ep2 and SceneRouter._loading_path == "", str(td.state))
	SceneRouter.load_scene(ep2, SceneRouter.Transition.FADE)       # a second tap on the EPISODE 2 button
	_check("a second EPISODE 2 tap while the hand-off runs is swallowed (still one target)", td.target_path == ep2 and td.is_busy())
	var hold_obs: Dictionary = {"max_dist": 0.0, "music": false, "unfrozen": 0, "runner_seen": false, "frames": 0}
	var guard1: int = 0
	while (td._going or td.state != td.S.IDLE) and guard1 < 6000:
		await get_tree().process_frame
		guard1 += 1
		hold_obs["frames"] = int(hold_obs["frames"]) + 1
		if td.handoff_holding():
			if not get_tree().paused:
				hold_obs["unfrozen"] = int(hold_obs["unfrozen"]) + 1
			var rr: Node = _runner_of(get_tree().current_scene)
			if rr != null:
				hold_obs["runner_seen"] = true
				hold_obs["max_dist"] = maxf(float(hold_obs["max_dist"]), float(rr.get_distance()))
			if AudioManager.current_music_player != null:
				hold_obs["music"] = true
	td.state_changed.disconnect(on_state)
	_check("menu route walked cover -> load -> swap -> reveal -> idle: %s" % str(walk),
		walk.has("COVERING") and walk.has("LOADING") and walk.has("SWAPPING") and walk.has("REVEALING") and walk[-1] == "IDLE")
	_check("the scene that came out is the real Episode 2 entry", String(reveal_obs.get("scene", "")) == ep2, str(reveal_obs))
	_check("the first runner leg was built inside the held scene and the old scene stayed frozen under the cover",
		bool(hold_obs["runner_seen"]) and int(hold_obs["unfrozen"]) == 0, str(hold_obs))
	_check("F15: the first leg is held at distance 0 while the cover is up (max %.2f m)" % float(hold_obs["max_dist"]),
		bool(reveal_obs.get("runner", false)) and bool(reveal_obs.get("holding", false)) and float(hold_obs["max_dist"]) == 0.0
		and float(reveal_obs.get("dist", -1.0)) == 0.0, str(reveal_obs))
	_check("F06: no track starts under the cover (the runner music waits for the reveal)",
		not bool(hold_obs["music"]) and not bool(reveal_obs.get("music", true)), str(hold_obs))
	_check("the freeze was still on at the reveal and is off afterwards", bool(reveal_obs.get("paused", false)) and not get_tree().paused)
	await get_tree().create_timer(0.35).timeout
	var run1: Node = _runner_of(get_tree().current_scene)
	_check("after the reveal the cart is released and runs (%.2f m)" % (float(run1.get_distance()) if run1 != null else -1.0),
		run1 != null and not run1.is_reveal_holding() and float(run1.get_distance()) > 0.2)
	var mp: AudioStreamPlayer = AudioManager.current_music_player
	_check("...and the runner music comes in at the reveal (fading in, not from the top of the volume range)",
		mp != null and mp.playing and mp.stream != null and mp.stream.resource_path.ends_with("runner_run.mp3") and mp.volume_db < -3.0,
		"" if mp == null else "%s %.1f dB" % [mp.stream.resource_path, mp.volume_db])
	# A LATER leg / a retry is built with the director idle: never held, music at once.
	AudioManager.fade_out_music(0.01)
	var later: Node = load("res://src/episode2/runner/runner_graybox.tscn").instantiate()
	add_child(later)
	later.setup(200.0)
	_check("a later leg (director idle) is NOT held and starts its music immediately",
		not later.is_reveal_holding() and AudioManager.current_music_player != null)
	later.queue_free()
	AudioManager.fade_out_music(0.01)
	_reset_scene(root)
	GameManager.ep2_story_unlocked = unlocked0
	_check("the state machine ended PLAYING after the menu route", StateMachine.get_current_state() == "PLAYING")

	# 1c. The runner's OWN hold (F15), independent of the freeze: a first-leg runner built while the director holds the cover
	# does not advance on physics ticks that DO reach it, and starts only once the director is at REVEALING. (The freeze
	# already keeps a paused runner still; this proves the runner does not lean on it.)
	AudioManager.fade_out_music(0.01)
	td._going = true
	td.state = td.S.SWAPPING
	var held_runner: Node = load("res://src/episode2/runner/runner_graybox.tscn").instantiate()
	add_child(held_runner)
	held_runner.setup(200.0)
	for i in 12:
		held_runner._physics_process(1.0 / 60.0)
	_check("runner hold: 12 physics ticks under the cover leave the cart at distance 0 (%.3f)" % float(held_runner.get_distance()),
		held_runner.is_reveal_holding() and float(held_runner.get_distance()) == 0.0)
	_check("runner hold: no music starts while it waits", AudioManager.current_music_player == null)
	td.state = td.S.REVEALING
	held_runner._physics_process(1.0 / 60.0)
	_check("runner hold: the first tick after the reveal starts the cart (%.3f m) and the music" % float(held_runner.get_distance()),
		not held_runner.is_reveal_holding() and float(held_runner.get_distance()) > 0.0 and AudioManager.current_music_player != null)
	td._going = false
	td.state = td.S.IDLE
	held_runner.queue_free()
	AudioManager.fade_out_music(0.01)

	# 2. Hand-off to a tiny scene: states, StateMachine, card, scene change.
	var states: Array = []
	td.state_changed.connect(func(_f, t): states.append(t))
	var target: String = TARGET
	var seen: Dictionary = {"transitioning": false}
	StateMachine.state_changed.connect(func(_f, t): if t == "TRANSITIONING": seen["transitioning"] = true)
	td.go(target, "TEST", "CARD")
	_check("go() covers immediately (state COVERING, card visible)", td.state == td.S.COVERING and td._card.visible)
	_check("desktop card keeps its words (title + subtitle visible)",
		td._title.visible and td._subtitle.visible and td._title.text == "TEST" and td._subtitle.text == "CARD")
	_check("a second go() while busy is ignored", (func(): td.go(ep2); return td.target_path == target).call())
	await td.finished
	_check("hand-off walked cover -> load -> swap -> reveal -> idle: %s" % str(states),
		states.has("COVERING") and states.has("LOADING") and states.has("SWAPPING") and states.has("REVEALING") and states[-1] == "IDLE")
	_check("the scene actually changed", get_tree().current_scene != null and get_tree().current_scene.name == "TransitionTarget")
	_check("the card is gone (nothing left covering the game)", not td._card.visible and td.state == td.S.IDLE)
	_check("StateMachine went TRANSITIONING then PLAYING", bool(seen["transitioning"]) and StateMachine.get_current_state() == "PLAYING")
	_check("the director can run again", not td.is_busy())

	# 2b. SEAMLESS MODE: the film's last frame is the cover; the loading card must NEVER show.
	var cover := ColorRect.new()
	cover.color = Color(0.7, 0.3, 0.1)
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	var card_ever: Dictionary = {"shown": false, "cover_alpha_min": 1.0}
	td.go(target, "", "", cover)
	var guard := 0
	while td.state != td.S.IDLE or td._going:
		await get_tree().process_frame
		if td._card.visible:
			card_ever["shown"] = true
		if is_instance_valid(cover) and cover.is_inside_tree():
			card_ever["cover_alpha_min"] = minf(float(card_ever["cover_alpha_min"]), cover.modulate.a)
		guard += 1
		if guard > 2000:
			break
	_check("cover mode: the black loading card never appeared", not bool(card_ever["shown"]))
	_check("cover mode: the film's frame stayed fully opaque until the scene was ready, then dissolved (min alpha %.2f)" % float(card_ever["cover_alpha_min"]),
		float(card_ever["cover_alpha_min"]) < 0.5)
	# queue_free() lands at the end of the frame in which the dissolve finished (the same frame the director goes IDLE),
	# so the cover is gone one frame later - not "freed" in the very frame the loop above exits in.
	_check("cover mode: the cover is queued for deletion the moment the dissolve ends",
		not is_instance_valid(cover) or cover.is_queued_for_deletion() or not cover.is_inside_tree())
	await get_tree().process_frame
	_check("cover mode: the cover is freed after the dissolve", not is_instance_valid(cover) or not cover.is_inside_tree())

	# 2c. prewarm(compile_now) pays the script compile immediately and leaves the queue free of scripts.
	td.prewarm(ep2, true)
	var scripts_left: int = 0
	for q in td._queue:
		if str(q).get_extension() in ["gd", "tscn", "scn"]:
			scripts_left += 1
	_check("prewarm(compile_now) leaves no script/scene in the film-phase queue (%d left)" % scripts_left, scripts_left == 0)
	_check("...and the compile froze ONE frame, measured (%.0f ms)" % float(td.last_compile_ms), td.last_compile_ms > 0.0)
	td._reset_warm()

	# 2c2. A half-faded CARD is never frozen by the compile: the script / scene loads wait until the card is opaque (LOADING);
	# a COVER (the film's frame) is opaque from its first frame, so there they start at once.
	td.state = td.S.COVERING
	td._cover = null
	_check("card mode: the screen is NOT covered while the card is still fading in", not td.is_screen_covered())
	td._queue = ["res://src/episode2/ep2_entry.gd"]
	td._total = 1
	td._process(0.0)
	_check("card mode: nothing is compiled during the card's fade-in", td._queue.size() == 1 and td._hold.is_empty())
	td._cover = ColorRect.new()
	_check("cover mode: the film's frame is opaque from the first covering frame", td.is_screen_covered())
	td._cover.free()
	td._cover = null
	td.state = td.S.LOADING
	_check("...and once the card is up (LOADING) the screen is covered", td.is_screen_covered())
	td._process(0.0)
	_check("...so the compile runs then", td._queue.is_empty() and not td._hold.is_empty())
	td._reset_warm()

	# 2d. FREEZE (F09): the old scene waits under the cover, the new scene's pausable nodes wait with it, ALWAYS nodes run,
	# and the pause is re-asserted after a state change and by the per-frame check.
	var Probe: GDScript = load("res://tests/fixtures/transition_probe_target.gd")
	Probe.spawn_runner = false
	Probe.last = null
	var fz: Dictionary = {"at_reveal": {}, "sync": null, "next": null, "after": null, "violations": 0, "armed": 0}
	var fz_hook := func(_f: String, to: String) -> void:
		if to == "SWAPPING":
			# a scene's _ready (or any state change) can unpause the tree: undo the freeze by hand, then fire the signal
			get_tree().paused = false
			StateMachine.state_changed.emit("TRANSITIONING", "TRANSITIONING")
			fz["sync"] = get_tree().paused
			get_tree().paused = false            # ...and leave it unpaused: only the per-frame check can repair this one
			fz["armed"] = 1
		elif to == "REVEALING":
			var p: Node = Probe.last
			if p != null and is_instance_valid(p):
				fz["at_reveal"] = {"pausable": p.pausable_ticks, "always": p.always_tick_count(), "holding": p.ready_holding,
					"paused_at_ready": p.ready_paused, "paused_now": get_tree().paused}
	td.state_changed.connect(fz_hook)
	td.go(PROBE, "", "", ColorRect.new())
	_check("go() froze the tree under the cover at once", td.is_frozen() and get_tree().paused)
	var fz_guard: int = 0
	while (td._going or td.state != td.S.IDLE) and fz_guard < 2000:
		await get_tree().process_frame
		fz_guard += 1
		# Sampled at process_frame, i.e. BEFORE that frame's _process runs: the first sample after the hand-made unpause can
		# still see "unpaused"; the director's per-frame check must have repaired it by the sample after that.
		if int(fz["armed"]) == 1:
			fz["next"] = get_tree().paused
			fz["armed"] = 2
		elif int(fz["armed"]) == 2:
			fz["after"] = get_tree().paused
			fz["armed"] = 3
		elif int(fz["armed"]) == 3 and td.handoff_holding() and not get_tree().paused:
			fz["violations"] = int(fz["violations"]) + 1
	td.state_changed.disconnect(fz_hook)
	_check("freeze: a StateMachine change under the cover re-pauses the tree at once", fz["sync"] == true, str(fz["sync"]))
	_check("freeze: a stray unpause (a scene's _ready) is repaired by the director's per-frame check within a frame (%s then %s)" % [str(fz["next"]), str(fz["after"])],
		fz["after"] == true)
	_check("freeze: no frame of the hold ran unpaused after that", int(fz["violations"]) == 0, str(fz["violations"]))
	var ar: Dictionary = fz["at_reveal"]
	_check("the new scene saw the hold in its _ready (handoff_holding true, tree paused)",
		bool(ar.get("holding", false)) and bool(ar.get("paused_at_ready", false)), str(ar))
	_check("freeze: a pausable node in the new scene did not tick under the cover (%s)" % str(ar.get("pausable", -1)),
		int(ar.get("pausable", -1)) == 0)
	_check("freeze: a PROCESS_MODE_ALWAYS node in the new scene kept running under the cover (%s ticks)" % str(ar.get("always", -1)),
		int(ar.get("always", 0)) > 0)
	_check("freeze: the tree was still paused when the reveal began, and runs freely afterwards",
		bool(ar.get("paused_now", false)) and not get_tree().paused and not td.is_frozen())
	await get_tree().process_frame
	await get_tree().process_frame
	_check("freeze: after the reveal the new scene's pausable nodes tick", Probe.last != null and Probe.last.pausable_ticks > 0)
	_reset_scene(root)

	# 2e. THE CARD ON A PHONE (F10): wordless, dp-sized, ONE bar, and it follows a rotation while it is up.
	mlm.is_touch_device = true
	root.size = Vector2i(844, 390)
	await get_tree().process_frame
	await get_tree().process_frame
	_check("touch device, no key presses: keys_shown() is false (the card must be wordless)", not TouchUi.keys_shown())
	for shape in [Vector2i(844, 390), Vector2i(390, 844), Vector2i(1024, 768)]:
		root.size = shape
		await get_tree().process_frame
		await get_tree().process_frame
		td._apply_card_layout()
		var vp: Vector2 = td.get_viewport().get_visible_rect().size
		var dp: float = TouchUi.metrics().dp
		var bar: Rect2 = Rect2(td._bar_bg.position, td._bar_bg.size)
		var gl: Rect2 = Rect2(td._glyph.position, td._glyph.size)
		var short_side: float = minf(vp.x, vp.y)
		var tag: String = "%dx%d" % [shape.x, shape.y]
		_check("[%s] wordless: no title, no subtitle, a drawn cart" % tag, not td._title.visible and not td._subtitle.visible and td._glyph.visible)
		_check("[%s] the bar is at least 8 dp thick (%.1f dp)" % [tag, bar.size.y / dp], bar.size.y / dp >= 8.0 - 0.01)
		_check("[%s] the bar is about half the short side long (%.2f)" % [tag, bar.size.x / short_side],
			bar.size.x / short_side > 0.35 and bar.size.x / short_side <= 0.62)
		_check("[%s] bar and glyph sit inside the screen, centred" % tag,
			Rect2(Vector2.ZERO, vp).encloses(bar) and Rect2(Vector2.ZERO, vp).encloses(gl)
			and absf(bar.get_center().x - vp.x * 0.5) < 1.0 and absf(gl.get_center().x - vp.x * 0.5) < 1.0)
	_check("ONE progress affordance: the bar is the only gauge, and it is not inside the card", td._bar_bg.get_parent() == td._prog and td._bar.get_parent() == td._prog)
	# rotation while the card is up
	root.size = Vector2i(844, 390)
	await get_tree().process_frame
	await get_tree().process_frame
	td.go(TARGET)
	await get_tree().process_frame
	root.size = Vector2i(390, 844)                 # the player turns the phone while the card is up
	await get_tree().process_frame
	await get_tree().process_frame
	var vp_turned: Vector2 = td.get_viewport().get_visible_rect().size
	_check("rotation with the card up: the bar is re-centred for the new shape without a new go()",
		absf(td._bar_bg.position.x + td._bar_bg.size.x * 0.5 - vp_turned.x * 0.5) < 1.0 and td._bar_bg.position.y > vp_turned.y * 0.4,
		"vp %s bar %s" % [str(vp_turned), str(td._bar_bg.position)])
	var words_visible: int = 0
	var scan: Array = [td]
	while not scan.is_empty():
		var n: Node = scan.pop_back()
		for c in n.get_children():
			scan.append(c)
		if n is Label and (n as Label).is_visible_in_tree() and (n as Label).text != "":
			words_visible += 1
	_check("touch card: not one visible Label anywhere under the director (%d)" % words_visible, words_visible == 0)
	await td.finished
	_reset_scene(root)
	root.size = win_size0
	mlm.is_touch_device = touch0
	await get_tree().process_frame

	# 2f. THE COVER'S "ALIVE" BAR (F09): hidden for the first ~1.2 s, then it fades in; driven by warm_fraction().
	td._cover = ColorRect.new()
	td._prog.visible = true
	td._going = true
	td._waited = 0.4
	td._update_progress_alpha()
	_check("cover: the alive bar is invisible during the first second", td._prog.modulate.a == 0.0, str(td._prog.modulate.a))
	td._waited = td.ALIVE_AFTER_SECONDS + td.ALIVE_FADE_SECONDS + 0.1
	td._update_progress_alpha()
	_check("cover: after ~1.2 s of an unmoving picture the bar is fully in", is_equal_approx(td._prog.modulate.a, 1.0), str(td._prog.modulate.a))
	td._cover.modulate.a = 0.5
	td._update_progress_alpha()
	_check("cover: the bar fades out with the cover's dissolve", is_equal_approx(td._prog.modulate.a, 0.5), str(td._prog.modulate.a))
	td._total = 4
	td._queue = ["a", "b"]
	td._late.clear()
	td._progress_shown = 0.0
	td._update_bar(10.0)
	_check("the bar width follows warm_fraction() (%.2f of %.0f)" % [td._progress_shown, td._bar_w],
		is_equal_approx(td._progress_shown, 0.5) and is_equal_approx(td._bar.size.x, td._bar_w * 0.5))
	td._cover.free()
	td._cover = null
	td._going = false
	td._queue.clear()
	td._total = 0
	td._prog.visible = false
	td._prog.modulate.a = 1.0
	td._waited = 0.0
	td._progress_shown = 0.0

	# 2g. FAILURE (F02): the swap itself fails. An EMPTY PackedScene instantiates to null, so change_scene_to_packed
	# fails exactly like an out-of-memory phone. Nothing may be left covering, the state recovers, and the player goes home.
	td.home_scene_path = HOME_FIXTURE
	var ab: Dictionary = {"path": "", "state_at_signal": "", "covers": 0, "enter_covering": 0}
	td.aborted.connect(func(p: String) -> void:
		ab["path"] = p
		ab["state_at_signal"] = StateMachine.get_current_state())
	var ab_hook := func(_f: String, to: String) -> void:
		if to == "COVERING":
			ab["enter_covering"] = int(ab["enter_covering"]) + 1
		if to == "SWAPPING":
			td._packed = PackedScene.new()
	td.state_changed.connect(ab_hook)
	var cover_ab := ColorRect.new()
	cover_ab.color = Color(0.3, 0.3, 0.3)
	cover_ab.set_anchors_preset(Control.PRESET_FULL_RECT)
	var before_ab: String = StateMachine.get_current_state()
	td.go(TARGET, "", "", cover_ab)
	var ab_guard: int = 0
	while String(ab["path"]) == "" and ab_guard < 3000:
		await get_tree().process_frame
		ab_guard += 1
	_check("abort: the director reported the failed hand-off (%s)" % str(ab["path"]), String(ab["path"]) == TARGET and td.abort_count == 1)
	_check("abort: the StateMachine was recovered (%s -> %s), not left TRANSITIONING" % [before_ab, ab["state_at_signal"]],
		String(ab["state_at_signal"]) == before_ab)
	_check("abort: the tree is not frozen and the director is free again", not get_tree().paused and not td.is_frozen() and not td._going)
	await get_tree().process_frame
	_check("abort: a house is drawn OVER the cover (the card was lifted above it) while the menu route runs",
		td._glyph.kind == td.CardGlyph.HOME and td._glyph.visible and td._card.visible and td._card.get_index() > cover_ab.get_index(),
		"card %d cover %d" % [td._card.get_index(), cover_ab.get_index() if is_instance_valid(cover_ab) else -1])
	var ab_wait: int = 0
	while (is_instance_valid(cover_ab) and cover_ab.is_inside_tree()) and ab_wait < 600:
		await get_tree().process_frame
		ab_wait += 1
	_check("abort: the cover was faded and FREED (nothing left eating touches)", not is_instance_valid(cover_ab) or not cover_ab.is_inside_tree())
	_check("abort: the card is hidden again, back under any cover, and the progress bar is off",
		not td._card.visible and td._card.get_index() == 0 and not td._prog.visible)
	_check("abort: the player was routed home (the router loaded %s)" % HOME_FIXTURE,
		get_tree().current_scene != null and get_tree().current_scene.scene_file_path == HOME_FIXTURE)
	_check("abort: NO retry loop - the director went COVERING once, is idle, holds nothing",
		int(ab["enter_covering"]) == 1 and td.state == td.S.IDLE and td._queue.is_empty() and td._hold.is_empty() and td.target_path == "")
	td.state_changed.disconnect(ab_hook)
	# a destination that is not in the build at all (the boss has already freed itself and hands over its cover)
	td.home_scene_path = TARGET
	var cover_missing := ColorRect.new()
	td.go("res://tests/fixtures/this_scene_does_not_exist.tscn", "", "", cover_missing)
	_check("missing destination: the passed cover is freed, not orphaned", cover_missing.is_queued_for_deletion() or not is_instance_valid(cover_missing))
	_check("missing destination: nothing began (not going, not frozen, idle)", not td._going and not td.is_frozen() and td.state == td.S.IDLE and td.abort_count == 2)
	var miss_wait: int = 0
	while (get_tree().current_scene == null or get_tree().current_scene.scene_file_path != TARGET) and miss_wait < 900:
		await get_tree().process_frame
		miss_wait += 1
	_check("missing destination: the player was routed home", get_tree().current_scene != null and get_tree().current_scene.scene_file_path == TARGET)
	td.home_scene_path = ""
	StateMachine.recover_from_transition()
	if StateMachine.get_current_state() != "PLAYING":
		StateMachine.change_state(StateMachine.State.PLAYING)

	# 2h. ROTATION MID-FILM (F11): the Stage 3 film's rect and its cover follow the viewport. A SubViewport stands in
	# for the phone's window (its size_changed is the same signal), so the test can turn it at will.
	var sv := SubViewport.new()
	sv.size = Vector2i(1280, 720)
	sv.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(sv)
	var film: Stage3BossDefeatCutscene = Stage3BossDefeatCutscene.new()
	film.keep_cover = true
	sv.add_child(film)
	film.play()
	await get_tree().process_frame
	var vid: VideoStreamPlayer = film._video_player
	_check("film: the Stage 3 video started in the stand-in window", is_instance_valid(vid))
	if is_instance_valid(vid):
		_check("film: at 16:9 the picture fills 1280x720 exactly (%s)" % str(vid.size), vid.size.is_equal_approx(Vector2(1280, 720)) and vid.position.is_equal_approx(Vector2.ZERO))
		sv.size = Vector2i(390, 844)                     # the phone is turned upright MID-FILM
		await get_tree().process_frame
		var want_p: Rect2 = Stage3BossDefeatCutscene._fill_rect(Vector2(390, 844))
		_check("film: turned to portrait mid-film, the picture is re-fitted (fill + crop) %s" % str(Rect2(vid.position, vid.size)),
			vid.size.is_equal_approx(want_p.size) and vid.position.is_equal_approx(want_p.position)
			and vid.position.x <= 0.0 and vid.position.x + vid.size.x >= 390.0 and vid.size.y >= 844.0 - 0.5)
		sv.size = Vector2i(844, 390)
		await get_tree().process_frame
		var want_l: Rect2 = Stage3BossDefeatCutscene._fill_rect(Vector2(844, 390))
		_check("film: turned back to landscape, re-fitted again", vid.size.is_equal_approx(want_l.size) and vid.position.is_equal_approx(want_l.position))
		sv.size = Vector2i(390, 844)
		await get_tree().process_frame
		film._finish()                                   # the film ends; the player turns the phone AFTER that, before the cover is made
		sv.size = Vector2i(844, 390)
		await get_tree().process_frame
		_check("film: once finished it stops following the viewport (the video keeps the old rect)",
			not sv.size_changed.is_connected(film._layout_video) and vid.size.is_equal_approx(want_p.size))
		var live_cover: Control = film.make_cover()
		_check("cover: make_cover() takes its rect from the viewport AS IT IS (not from the last layout): %s" % str(film._cover_rect),
			film._cover_rect.is_equal_approx(want_l))
		live_cover.free()
	# a cover built from a real picture keeps filling the screen while it waits through a rotation
	var img := Image.create(64, 36, false, Image.FORMAT_RGB8)
	img.fill(Color(0.8, 0.5, 0.2))
	var cover_frame: Control = Stage3BossDefeatCutscene.build_cover(ImageTexture.create_from_image(img))
	var cl := CanvasLayer.new()
	sv.add_child(cl)
	sv.size = Vector2i(1280, 720)
	cl.add_child(cover_frame)
	await get_tree().process_frame
	await get_tree().process_frame
	var pic: TextureRect = cover_frame.get_node_or_null("LastFrame") as TextureRect
	_check("cover: the last frame is a full-rect picture stretched 'covered' (fill + crop like the film)",
		pic != null and pic.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED and pic.expand_mode == TextureRect.EXPAND_IGNORE_SIZE)
	_check("cover: at 1280x720 it fills the window", cover_frame.size.is_equal_approx(Vector2(1280, 720)) and pic != null and pic.size.is_equal_approx(Vector2(1280, 720)))
	sv.size = Vector2i(390, 844)
	await get_tree().process_frame
	await get_tree().process_frame
	_check("cover: the phone turned upright while the cover waits - it follows (%s / %s)" % [str(cover_frame.size), str(pic.size if pic != null else Vector2.ZERO)],
		cover_frame.size.is_equal_approx(Vector2(390, 844)) and pic != null and pic.size.is_equal_approx(Vector2(390, 844)))
	var black: Control = Stage3BossDefeatCutscene.build_cover(null)
	_check("cover: no film frame (skipped / undecodable film) is a plain black cover, not an invisible one",
		black.get_child_count() == 1 and black.get_child(0) is ColorRect and (black.get_child(0) as ColorRect).color == Color.BLACK)
	black.free()
	_check("film: the touch profile is the single wordless SKIP (ep2_film), not the whole platformer cluster",
		film.touch_profile() == &"ep2_film" and MobileLayoutManager.KNOWN_PROFILES.has(film.touch_profile()))
	film.queue_free()
	cover_frame.queue_free()
	sv.queue_free()
	await get_tree().process_frame

	# 3. Routing: bosses use the director, never the blue diamond wipe, for the Episode 2 hand-off.
	for bp in ["res://src/boss/claim_jumper.gd", "res://src/boss/bandit_boss.gd"]:
		var src: String = FileAccess.get_file_as_string(bp)
		_check("%s prewarms on death and hands off through TransitionDirector.go" % bp.get_file(),
			src.contains("TransitionDirector.prewarm(GameManager.EPISODE2_SCENE, true)") and src.contains("TransitionDirector.go(GameManager.next_level_scene(3)")
			and src.contains("make_cover()")
			and not src.contains("next_level_scene(3), SceneRouter.Transition.DIAMOND"))
		_check("%s fades the boss theme out at death (no Music-bus mute)" % bp.get_file(),
			src.contains("AudioManager.fade_out_music(0.8)") and not src.contains("set_bus_mute"))
	var router_src: String = FileAccess.get_file_as_string("res://src/autoload/scene_router.gd")
	_check("the router diverts EPISODE2_SCENE to the director BEFORE it sets its own _loading_path",
		router_src.contains("_divert_to_director(path)") and router_src.find("_divert_to_director(path)") < router_src.find("_loading_path = path"))
	var card_bg: Color = td._bg.color
	_check("the loading card is black-violet, not blue (b - r < 0.05: %s)" % str(card_bg), card_bg.b - card_bg.r < 0.05)

	root.size = win_size0
	mlm.is_touch_device = touch0
	GameManager.ep2_story_unlocked = unlocked0
	print("TRANSITION_DIRECTOR: %s" % ("ALL PASS" if _fail == 0 else "FAIL (%d)" % _fail))
	get_tree().quit(_fail)


## Free whatever scene is current and install a fresh dummy (the next section needs a scene to replace).
func _reset_scene(root: Node) -> void:
	var cs: Node = get_tree().current_scene
	if cs != null and is_instance_valid(cs):
		cs.queue_free()
	var d := Node.new()
	d.name = "DummyCurrentScene"
	root.add_child(d)
	get_tree().current_scene = d


## The active RunnerGraybox of an Ep2Entry scene (null for any other scene).
func _runner_of(scene: Node) -> Node:
	if scene == null or not is_instance_valid(scene) or scene.scene_file_path != EP2:
		return null
	var sr: Variant = scene.get("_root")
	if sr is Node and (sr as Node).has_method("get_active"):
		return (sr as Node).get_active()
	return null


func _preset_has(td: Node, file_name: String) -> bool:
	for f in td.PRESETS[EP2].get("files", []):
		if String(f).ends_with(file_name):
			return true
	return false
