extends Node
## Guards the antagonist-VO chain end to end (founder residual: "bosses went
## silent / lines don't vary"). Verifies, without needing autoloads:
##   1. boss_voice_system.gd sets a POSITIVE player gain (the root-cause fix —
##      it defaulted to 0 dB while hero/announcer run at +6 dB, so bosses were
##      6 dB under everything and vanished).
##   2. Every voice_id in assets/boss-voices.json is a full 20-char ElevenLabs
##      id (the founder's crystal id was truncated to 16 — catch that class of
##      bug before it ships silence again).
##   3. BossVoiceData.COUNTS exactly matches the line counts in the json.
##   4. Every clip the runtime can ask for exists on disk and is loadable.
## Run headless: godot --headless -s tests/boss_voice_sync_test.gd  (via .tscn)

const JSON_PATH := "res://assets/boss-voices.json"
const SYS_PATH := "res://src/boss/boss_voice_system.gd"
const VOICE_DIR := "res://src/assets/sounds/voice/boss/"

var _fail := 0

func _ready() -> void:
	_check_player_gain()
	_check_voice_ids_and_counts()
	if _fail == 0:
		print("BOSS_VOICE_SYNC_TEST: PASS")
		get_tree().quit(0)
	else:
		print("BOSS_VOICE_SYNC_TEST: FAIL (%d)" % _fail)
		get_tree().quit(1)

func _bad(msg: String) -> void:
	_fail += 1
	push_error(msg)
	print("  FAIL: ", msg)

func _check_player_gain() -> void:
	# The fix lives in a const + an assignment; assert the source carries a
	# clearly-positive gain so a future edit can't silently drop it back to 0.
	var txt := FileAccess.get_file_as_string(SYS_PATH)
	if txt == "":
		_bad("cannot read %s" % SYS_PATH); return
	if not txt.contains("PLAYER_VOLUME_DB"):
		_bad("boss_voice_system.gd missing PLAYER_VOLUME_DB gain const"); return
	if not txt.contains("_player.volume_db = PLAYER_VOLUME_DB"):
		_bad("boss_voice_system.gd never applies PLAYER_VOLUME_DB to the player")
	# Extract the numeric value and require >= 8 dB (founder floor).
	var re := RegEx.new()
	re.compile("PLAYER_VOLUME_DB\\s*:=\\s*([0-9.]+)")
	var mm := re.search(txt)
	if mm == null:
		_bad("could not parse PLAYER_VOLUME_DB value"); return
	var db := float(mm.get_string(1))
	if db < 8.0:
		_bad("PLAYER_VOLUME_DB=%s below +8 dB founder floor" % db)
	else:
		print("  player gain = +%s dB (>= +8) OK" % db)

func _check_voice_ids_and_counts() -> void:
	var txt := FileAccess.get_file_as_string(JSON_PATH)
	var data = JSON.parse_string(txt)
	if typeof(data) != TYPE_DICTIONARY:
		_bad("boss-voices.json did not parse"); return
	var bosses: Dictionary = data.get("bosses", {})
	for boss in bosses.keys():
		var cfg: Dictionary = bosses[boss]
		var vid := String(cfg.get("voice_id", ""))
		if vid.length() != 20:
			_bad("%s voice_id '%s' is %d chars (expected full 20)" % [boss, vid, vid.length()])
		var counts: Dictionary = BossVoiceData.COUNTS.get(boss, {})
		var lines: Dictionary = cfg.get("lines", {})
		for cat in lines.keys():
			var n_json: int = (lines[cat] as Array).size()
			var n_counts: int = int(counts.get(cat, -1))
			if n_json != n_counts:
				_bad("%s/%s: json has %d lines but COUNTS says %d" % [boss, cat, n_json, n_counts])
			# Every index the picker can produce must exist and load.
			for i in range(n_json):
				var p := "%s%s_%s_%d.mp3" % [VOICE_DIR, boss, cat, i]
				if not ResourceLoader.exists(p):
					_bad("missing clip %s" % p)
					continue
				if load(p) == null:
					_bad("unloadable clip %s" % p)
		if int(counts.size()) != int(lines.size()):
			_bad("%s: COUNTS has %d categories, json has %d" % [boss, counts.size(), lines.size()])
	if _fail == 0:
		print("  voice ids full-length, COUNTS in sync, all clips present & loadable OK")
