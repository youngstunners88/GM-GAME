extends Node
## RUNTIME proof for the founder's four failure modes on antagonist VO:
##   (a) silence      — after say(), the player is actually .playing with a stream
##   (b) volume <= 0   — the live player's volume_db is the +10 dB fix, not 0
##   (c) missing files — every category resolves to a real loadable clip
##   (d) same-line spam — 20 consecutive taunts never repeat back-to-back
## This drives the REAL BossVoiceSystem autoload (not a static file scan), so it
## exercises the actual playback path the game uses in a boss fight.

var _fail := 0

func _bad(m: String) -> void:
	_fail += 1
	push_error(m)
	print("  FAIL: ", m)

func _ready() -> void:
	await get_tree().process_frame
	var sys = BossVoiceSystem
	if sys == null:
		_bad("BossVoiceSystem autoload missing"); _finish(); return

	var dummy := Node2D.new()
	add_child(dummy)

	# (a)(b)(c): fire one line in every category for every boss and confirm the
	# live player plays a real stream at the +10 dB gain.
	for boss in ["tax", "crystal", "bandit"]:
		for cat in ["intro", "taunt", "mock", "hurt", "phase50", "phase25", "death"]:
			sys.say(dummy, boss, cat, true)  # force = bypass cooldown
			await get_tree().process_frame
			var p = sys._player
			if p == null:
				_bad("%s/%s: no _player" % [boss, cat]); continue
			if p.stream == null:
				_bad("%s/%s: player has no stream (missing/failed clip)" % [boss, cat])
			if not p.playing:
				_bad("%s/%s: player not playing (silent)" % [boss, cat])
			if p.volume_db < 8.0:
				_bad("%s/%s: player volume_db=%s below +8 dB" % [boss, cat, p.volume_db])
	print("  playback: every boss/category plays a real stream at +%s dB OK" % sys._player.volume_db)

	# (d): no immediate repeats across a long taunt run (uses tax taunt pool = 8).
	var seen_repeat := false
	var last := -999
	for i in range(20):
		sys.say(dummy, "tax", "taunt", true)
		await get_tree().process_frame
		var idx := int(sys._last_idx.get("tax:taunt", -1))
		if idx == last:
			seen_repeat = true
		last = idx
	if seen_repeat:
		_bad("same-line spam: a taunt repeated back-to-back")
	else:
		print("  variety: 20 consecutive taunts, zero back-to-back repeats OK")

	_finish()

func _finish() -> void:
	if _fail == 0:
		print("BOSS_VOICE_PLAYBACK_TEST: PASS")
		get_tree().quit(0)
	else:
		print("BOSS_VOICE_PLAYBACK_TEST: FAIL (%d)" % _fail)
		get_tree().quit(1)
