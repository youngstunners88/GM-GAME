extends Node
## Real cue/round ownership, streamed cast, full recorded durations and quiet speech lanes.
var failures := 0
var pending := 0

func check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["PASS" if ok else "FAIL", label])
	if not ok: failures += 1

func _ready() -> void:
	await get_tree().process_frame
	var c: GoldTownChamber = load("res://src/episode2/chamber/gold_town.tscn").instantiate()
	add_child(c)
	c.setup()
	c.set_physics_process(false)
	check("town audio is silent until activated, then loops", c._town_audio.active and c._town_audio._wind.playing and c._town_audio._saloon.playing)
	check("every supplied public town figure has a recorded voice bank", Ep2TownVoiceBank.GREETINGS.size() == Ep2TownPeople.ROSTER.size())
	check("all supplied public figures are actually built", c._people.people.size() == Ep2TownPeople.ROSTER.size())
	for person in c._people.people:
		c._town_audio.story_busy = false
		c._town_audio.quiet = false
		c._town_audio._greet_cd = 0.0
		check(person.id + " can actually speak a nearby greeting", c._town_audio.greet(person.id, person.folk, 1))
	c._town_audio.step(0.0, c._people, c._player_pos, true, false)
	check("story speech immediately stops ambient speech", not c._town_audio._greeting.playing)
	check("a greeting cannot interrupt the story", not c._town_audio.greet("oldtimer", null, 2))
	c._town_audio.step(0.0, c._people, c._player_pos, false, true)
	check("duel suppresses chatter and lowers ambience", c._town_audio.quiet and c._town_audio._saloon.volume_db <= -28.0)
	var voices: Array = []
	c.line_spoken.connect(func(id): voices.append(id))
	var bell_events := [0]
	c.draw_bell_rung.connect(func(): bell_events[0] += 1)
	c._advance_to(GoldTownChamber.Beat.DRAW)
	c._draw_wait = 0.1
	c._hold = 0.0
	c._show_active = false
	c._tick_draw(0.11)
	check("bell rings on the exact go-state tick", c.get_draw_state() == "go" and c._town_audio.bell_count == 1 and bell_events[0] == 1)
	check("spoken Draw is not a second signal", not voices.has("vo_sheriff_draw"))
	c._tick_draw(0.1)
	check("one toll per round", c._town_audio.bell_count == 1)
	c._start_round()
	c._hold = 0.0
	c._draw_wait = 0.0
	c._tick_draw(0.01)
	check("a retry gets exactly one fresh toll", c._town_audio.bell_count == 2 and bell_events[0] == 2)
	c._start_round()
	var recording: AudioStream = c._town_audio._bell.stream
	c._town_audio._bell.stream = null
	c._draw_wait = 0.0
	c._hold = 0.0
	c._tick_draw(0.01)
	check("a missing bell can never silently open the firing window", c.get_draw_state() == "wait" and bell_events[0] == 2)
	c._town_audio._bell.stream = recording
	var jail: Array = c._jail_show_steps()
	var spoken := 0
	for step in jail:
		if step.get("do") == "say": spoken += 1
	check("all six jail exchanges use actual voice holds", spoken == GoldTownChamber.JAIL_LINES.size())
	if c._intro != null:
		var text: String = Ep2ArmoryIntro.SHARPS_LINES[3][1]
		c._intro._say("RICH", text)
		var id: String = Ep2TownVoiceBank.id_for("rich", text)
		check("Rich's full gun explanation has its recorded duration", c._intro._line_t >= Ep2TownVoiceBank.seconds(id) and c._intro._line_t > 4.2)
		check("Rich's intro really plays the recorded stream", AudioManager._voice_player != null and AudioManager._voice_player.stream == Ep2TownVoiceBank.stream(id))
		check("normalized recorded speech does not inherit the announcer boost", AudioManager._voice_player != null and is_zero_approx(AudioManager._voice_player.volume_db))
	else:
		check("built armory has its existing gun introduction", false)
	# Godot uses the final granule / sample rate. ffprobe subtracts positive start PTS.
	# Audit that exact offset instead of accepting an unexplained duration tolerance.
	for id in Ep2TownVoiceBank.LINES:
		var row: Dictionary = Ep2TownVoiceBank.LINES[id]
		if not row["ready"]:
			pending += 1
			continue
		var stream: AudioStream = Ep2TownVoiceBank.stream(id)
		check(id + " recorded take is packaged and timed (%.3f / %.3f)" % [stream.get_length() if stream else 0.0, (float(row["seconds"]) + float(row["start_seconds"]))], stream != null and absf(stream.get_length() - (float(row["seconds"]) + float(row["start_seconds"]))) < 0.00005)
	var receipts = JSON.parse_string(FileAccess.get_file_as_string("res://assets/town-audio-generated.json"))
	for id in ["town_wind", "town_saloon", "town_boardwalk", "town_draw_bell"]:
		var effect: AudioStream = load(Ep2TownSoundscape.ROOT + id + ".ogg") as AudioStream
		check(id + " effect is packaged with exact encoded duration", effect != null and absf(effect.get_length() - (float(receipts[id]["seconds"]) + float(receipts[id]["start_seconds"]))) < 0.00005)
	print("EP2_TOWN_AUDIO: %s (pending recordings: %d)" % ["ALL PASS" if failures == 0 and pending == 0 else ("BLOCKED BY CAST CAPACITY" if failures == 0 else "%d FAILURE(S)" % failures), pending])
	get_tree().quit(1 if failures else (2 if pending else 0))
