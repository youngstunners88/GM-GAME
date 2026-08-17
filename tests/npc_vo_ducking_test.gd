extends SceneTree
## NPC VO audibility regression gate (founder hard-refresh residuals,
## 2026-08-17): "the other character[s] are too softly spoken as the music
## overpowers them" — Mira (Diamond Vault) and Gideon (Fort Knox). Their VO
## used to build its own throwaway AudioStreamPlayer on "Master" at unity
## gain with zero ducking. Source-level gate (the bug was in the wiring, not
## runtime timing): asserts vault_realm.gd's _play_vo now routes through
## AudioManager.play_voice(), which already carries the proven +6dB /
## -14dB-duck mechanism the announcer uses, and no longer builds its own
## bare Master-bus player.
##
## Run: godot --headless -s res://tests/npc_vo_ducking_test.gd

func _init() -> void:
	var src := FileAccess.get_file_as_string("res://src/level/vault_realm.gd")
	var fn := src.substr(src.find("func _play_vo"))
	fn = fn.substr(0, fn.find("\nfunc "))
	var fail := 0

	if fn.contains("AudioManager.play_voice("):
		print("  [PASS] Mira/Gideon VO routes through AudioManager.play_voice() (shared +6dB/duck path)")
	else:
		print("  [FAIL] _play_vo does not call AudioManager.play_voice()"); fail += 1

	if not fn.contains("bus = \"Master\""):
		print("  [PASS] no more bare unity-gain Master-bus player for NPC VO")
	else:
		print("  [FAIL] _play_vo still builds its own bare Master-bus player"); fail += 1

	# The shared mechanism itself: confirm play_voice still carries the boost
	# + duck (a regression here would silently re-break every VO line,
	# announcer included, not just Mira/Gideon).
	var am_src := FileAccess.get_file_as_string("res://src/autoload/audio_manager.gd")
	var pv := am_src.substr(am_src.find("func play_voice"))
	pv = pv.substr(0, pv.find("\nfunc _on_voice_finished"))
	if pv.contains("volume_db = 6.0"):
		print("  [PASS] play_voice still boosts VO +6dB over the mix")
	else:
		print("  [FAIL] play_voice no longer boosts VO volume"); fail += 1
	if pv.contains("-14.0"):
		print("  [PASS] play_voice still ducks music while a line plays")
	else:
		print("  [FAIL] play_voice no longer ducks music"); fail += 1

	# Smoke Lounge lock: this fix must not touch the video's own mute wiring.
	var secret_src := FileAccess.get_file_as_string("res://src/level/secret_realm.gd")
	if secret_src.contains("volume_db") and secret_src.find("smoke_lounge") != -1:
		print("  [PASS] Smoke Lounge video mute wiring untouched (still present)")
	else:
		print("  [FAIL] Smoke Lounge video mute wiring missing — do not touch it"); fail += 1

	print("NPC_VO_DUCKING: %s" % ("ALL PASS" if fail == 0 else "%d FAILURE(S)" % fail))
	quit(fail)
