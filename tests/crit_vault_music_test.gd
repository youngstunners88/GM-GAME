extends SceneTree
## Founder critical fix — the vaults must play their EXCLUSIVE tracks, never the
## parent stage themes. Source-level regression gate (the actual bug was a wrong
## playlist wiring, not runtime behaviour): asserts vault_realm.gd wires
## diamonds_are_forever.mp3 (Diamond Vault) + goldmine.mp3 (Fort Knox) and NO
## longer references level02_theme / level03_theme anywhere in the music path.
##
## Run: godot --headless -s res://tests/crit_vault_music_test.gd

func _init() -> void:
	var src := FileAccess.get_file_as_string("res://src/level/vault_realm.gd")
	var fail := 0
	# The exclusive tracks are wired.
	if src.find("diamonds_are_forever.mp3") == -1:
		print("  [FAIL] Diamond Vault does not wire diamonds_are_forever.mp3"); fail += 1
	else:
		print("  [PASS] Diamond Vault wires diamonds_are_forever.mp3 (exclusive)")
	if src.find("goldmine.mp3") == -1:
		print("  [FAIL] Fort Knox does not wire goldmine.mp3"); fail += 1
	else:
		print("  [PASS] Fort Knox wires goldmine.mp3 (exclusive)")
	# The WRONG parent-stage themes are gone from the vault.
	if src.find("level02_theme") != -1 or src.find("level03_theme") != -1:
		print("  [FAIL] vault still references a parent stage theme (level02/level03) — the exact bug"); fail += 1
	else:
		print("  [PASS] no parent stage theme (level02/level03) referenced in the vault")
	print("CRIT_VAULT_MUSIC: %s" % ("ALL PASS" if fail == 0 else "%d FAILURE(S)" % fail))
	quit(fail)
