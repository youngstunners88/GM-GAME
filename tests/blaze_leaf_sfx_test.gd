extends SceneTree
## Founder residual (2026-08-17, doc2): "Don't change the music when Lil
## Blunt gets this leaf, rather make some awesome unique sound." The
## weed_leaf pickup (power_up_type "blaze") used to hijack the whole level's
## MUSIC via push_music_override for its 12s duration; now it plays a single
## distinct one-shot SFX and the level music keeps running.
##
## Run: godot --headless -s res://tests/blaze_leaf_sfx_test.gd

func _init() -> void:
	var fail := 0

	if ResourceLoader.exists("res://src/assets/sounds/blaze_ignite.mp3"):
		print("  [PASS] the new blaze_ignite SFX is a real generated asset")
	else:
		print("  [FAIL] blaze_ignite.mp3 missing"); fail += 1

	var src := FileAccess.get_file_as_string("res://src/autoload/game_manager.gd")
	var fn := src.substr(src.find("func activate_power_up"))
	fn = fn.substr(0, fn.find("\nfunc deactivate_power_up"))

	if fn.contains("if type == \"blaze\":") and fn.contains("AudioManager.play_sfx(\"blaze_ignite\")"):
		print("  [PASS] picking up the weed leaf (type \"blaze\") plays the new SFX")
	else:
		print("  [FAIL] blaze pickup does not play blaze_ignite"); fail += 1

	# The bug: "blaze" used to be lumped into the SAME branch as "purple" that
	# calls push_music_override. Assert that branch no longer fires for blaze
	# specifically — i.e. the music-override line is reachable only under a
	# check that EXCLUDES "blaze" (the elif "purple" branch), not the old
	# combined `type == "blaze" or type == "purple"` condition.
	if not fn.contains("type == \"blaze\" or type == \"purple\""):
		print("  [PASS] blaze is no longer lumped into the music-override branch")
	else:
		print("  [FAIL] blaze still shares the push_music_override branch with purple"); fail += 1

	# Purple Weed (the separate flagship power-up) must be UNTOUCHED — its
	# music takeover is deliberate and wasn't what the founder flagged.
	if fn.contains("elif type == \"purple\":") and fn.contains("push_music_override(\"res://src/assets/sounds/fresh_boost.ogg\")"):
		print("  [PASS] Purple Weed still takes over the music (untouched, separate power-up)")
	else:
		print("  [FAIL] Purple Weed's music takeover was accidentally removed too"); fail += 1

	print("BLAZE_LEAF_SFX: %s" % ("ALL PASS" if fail == 0 else "%d FAILURE(S)" % fail))
	quit(fail)
