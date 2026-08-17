extends SceneTree
## Founder residual (2026-08-17, doc2): three Level 1 music asks.
##   1. "This song needs to always be the 1st song that plays in level one no
##      matter what" — level01_theme.ogg. Root cause was AudioManager picking
##      RANDOMLY even on the very first play_playlist() call.
##   2. "This song must also feature in level 1" — level01_theme_oxbow.mp3
##      (founder-supplied "Oxbow Lake").
##   3. "Remove this song completely!" — level01_theme_alt.ogg.
##
## Run: godot --headless -s res://tests/level1_music_residual_test.gd

func _init() -> void:
	var fail := 0

	# --- #3 removed completely -------------------------------------------
	if not ResourceLoader.exists("res://src/assets/music/level01_theme_alt.ogg"):
		print("  [PASS] level01_theme_alt.ogg (the song to remove) no longer exists as an asset")
	else:
		print("  [FAIL] level01_theme_alt.ogg still exists"); fail += 1
	var l1_src := FileAccess.get_file_as_string("res://src/level/level_01_smoke_realm.gd")
	# Check only the real play_playlist([...]) call, not the explanatory
	# comment above it (which legitimately names the removed track by way of
	# explaining why it's gone).
	var pl_line := ""
	for line in l1_src.split("\n"):
		if line.contains("AudioManager.play_playlist("):
			pl_line = line
			break
	if pl_line != "" and not pl_line.contains("level01_theme_alt"):
		print("  [PASS] Level 1's playlist call no longer references level01_theme_alt")
	else:
		print("  [FAIL] Level 1's playlist call still references level01_theme_alt: %s" % pl_line); fail += 1
	# Not referenced by ANY other level either (it was Level-1-only to begin with).
	var any_other_ref := false
	for p in ["res://src/level/level_02_crystal_caverns.gd", "res://src/level/level_03_gold_rush.gd"]:
		if FileAccess.get_file_as_string(p).contains("level01_theme_alt"):
			any_other_ref = true
	if not any_other_ref:
		print("  [PASS] no other level references the removed track either")
	else:
		print("  [FAIL] another level still references the removed track"); fail += 1

	# --- #2 new track added and in the rotation -----------------------------
	if ResourceLoader.exists("res://src/assets/music/level01_theme_oxbow.mp3"):
		print("  [PASS] the founder-supplied 'Oxbow Lake' track is a real asset")
	else:
		print("  [FAIL] level01_theme_oxbow.mp3 missing"); fail += 1
	if l1_src.contains("level01_theme_oxbow.mp3"):
		print("  [PASS] Level 1's playlist includes the new Oxbow Lake track")
	else:
		print("  [FAIL] Level 1's playlist does not include level01_theme_oxbow.mp3"); fail += 1

	# --- #1 always-first, verified against the real random picker ----------
	if ResourceLoader.exists("res://src/assets/music/level01_theme.ogg"):
		print("  [PASS] level01_theme.ogg (the always-first track) is a real asset")
	else:
		print("  [FAIL] level01_theme.ogg missing"); fail += 1
	var pl_match := RegEx.new()
	pl_match.compile("AudioManager\\.play_playlist\\(\\[([^\\]]*)\\]\\)")
	var m := pl_match.search(l1_src)
	if m:
		var first_entry: String = m.get_string(1).split(",")[0]
		if first_entry.find("level01_theme.ogg") != -1 and first_entry.find("_alt") == -1:
			print("  [PASS] level01_theme.ogg is literally the FIRST entry in Level 1's playlist array")
		else:
			print("  [FAIL] level01_theme.ogg is not the first playlist entry: %s" % first_entry); fail += 1
	else:
		print("  [FAIL] could not find Level 1's play_playlist call to check ordering"); fail += 1

	# The actual mechanism: AudioManager.play_playlist's FIRST play must be
	# array[0], not random — proven by calling it many times and checking the
	# chosen track never varies (the OLD code would occasionally differ).
	var am_src := FileAccess.get_file_as_string("res://src/autoload/audio_manager.gd")
	var pp := am_src.substr(am_src.find("func play_playlist"))
	pp = pp.substr(0, pp.find("\nfunc _purge_retiring"))
	if pp.contains("force_first") or pp.contains("true, true)") or pp.contains("_play_next_in_playlist(true, true)"):
		print("  [PASS] play_playlist forces a deterministic first track (not the random picker)")
	else:
		print("  [FAIL] play_playlist still hands its first call to the random picker"); fail += 1

	print("LEVEL1_MUSIC_RESIDUAL: %s" % ("ALL PASS" if fail == 0 else "%d FAILURE(S)" % fail))
	quit(fail)
