extends Node
## Gate for the Episode 2 audio bus layout.
##
## Brief: artifacts/PROMPT_EPISODE2_VARCO_SOUND_INTEGRATION.md §4.3.
##
## Small gate, specific job. Episode 2's audio is designed as separable stems,
## and every one of them needs a bus to land on before a single VARCO credit is
## spent. Two things could go wrong silently and this catches both:
##   * a bus missing at runtime — the stem would fall back to SFX and the mix
##     would be unmixable, discovered only in a playtest;
##   * Music or SFX being disturbed — Episode 1 has SHIPPED and routes through
##     those two, so a change there breaks a live episode for a future one.
##
## FAILING-FIRST: all seven Episode 2 buses were absent before 2026-09-12.
##
## Extended 2026-09-16 (STAGE1_SMOKE_BOMBS_STRAIGHT_SHOT_AUDIO_DEAD): a founder
## P0 report that "all game sound has suddenly disappeared" — checked here as
## a permanent regression test rather than a one-off manual check, per the
## brief's explicit "gates updated... audio buses not muted." Every bus must
## come out of a fresh boot unmuted and at an audible volume; a muted bus or a
## volume floored to -80dB (left over from a headless test, or a stray
## AudioServer.set_bus_mute / volume_db = -80 call on a real code path) is
## exactly how sound "disappears" without any bus going missing.
##
## Run: .godot-cache/Godot_v4.3-stable_linux.x86_64 --headless \
##        res://tests/ep2_audio_buses_test.tscn

var _fail: int = 0

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _ready() -> void:
	await get_tree().process_frame
	print("EP2 AUDIO BUSES:")

	var am: Node = get_node_or_null("/root/AudioManager")
	if am == null:
		print("  [FAIL] AudioManager autoload missing")
		get_tree().quit(1)
		return

	for bus_name in ["Ambience", "Mechanical", "Threat", "Action", "Score", "VO", "UI"]:
		_check("bus %s exists" % bus_name, AudioServer.get_bus_index(bus_name) >= 0)

	# Episode 1's buses must be untouched by all of the above.
	_check("Music bus still present (Episode 1 routes through it)",
		AudioServer.get_bus_index("Music") >= 0)
	_check("SFX bus still present (Episode 1 routes through it)",
		AudioServer.get_bus_index("SFX") >= 0)

	_check("ep2_bus() resolves a real bus", am.ep2_bus("Threat") == AudioServer.get_bus_index("Threat"))
	_check("ep2_bus() falls back audibly on an unknown name, never to -1",
		am.ep2_bus("NotARealBus") >= 0)

	# Setup must be idempotent — it runs on every boot, and a second call must
	# not stack duplicate buses.
	var before: int = AudioServer.bus_count
	am._setup_ep2_buses()
	_check("re-running bus setup adds nothing (idempotent)",
		AudioServer.bus_count == before, "(%d -> %d)" % [before, AudioServer.bus_count])

	var score: int = AudioServer.get_bus_index("Score")
	am.ep2_set_score_duck(true)
	var ducked: float = AudioServer.get_bus_volume_db(score)
	am.ep2_set_score_duck(false)
	var restored: float = AudioServer.get_bus_volume_db(score)
	_check("score ducks for the runner and restores", ducked < -1.0 and is_equal_approx(restored, 0.0),
		"(%.1f dB -> %.1f dB)" % [ducked, restored])

	# --- audio-alive gate (2026-09-16 P0: "all sound disappeared") -----------
	# Checked on every bus that exists at this point, not just Music/SFX — a
	# missing bus falls back to SFX per ep2_bus(), but a MUTED SFX would still
	# silence everything routed through that fallback too.
	for i in AudioServer.bus_count:
		var name_i: String = AudioServer.get_bus_name(i)
		var muted: bool = AudioServer.is_bus_mute(i)
		var vol_db: float = AudioServer.get_bus_volume_db(i)
		_check("bus %s is not muted after boot" % name_i, not muted)
		_check("bus %s volume is not floored to silence" % name_i, vol_db > -79.0,
			"(%.1f dB)" % vol_db)

	if am.current_music_player != null:
		_check("stage music is actually playing after boot",
			am.current_music_player.playing,
			"(current_music_player exists but playing=false)")
	else:
		print("  [PASS] no current_music_player set (no stage music expected outside a level)")

	if _fail == 0:
		print("EP2_AUDIO_BUSES: ALL PASS")
		get_tree().quit(0)
	else:
		print("EP2_AUDIO_BUSES: %d FAILED" % _fail)
		get_tree().quit(1)
