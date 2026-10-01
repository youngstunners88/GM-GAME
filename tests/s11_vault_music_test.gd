extends Node2D
## S11 — vault music gate. The Diamond Vault and Fort Knox used to run in
## silence (reverb + SFX only). Each now plays its OWN exclusive track
## (Diamond Vault -> diamonds_are_forever, Fort Knox -> goldmine) via
## AudioManager.play_playlist — the founder ruled they must NEVER play the
## parent stage theme. This proves each vault ends up with a NON-EMPTY playlist
## carrying its own track and no stage theme, so a future edit can't silently
## drop vault music or leak the stage theme again.
##
## Run: godot --headless res://tests/s11_vault_music_test.tscn

const DIAMOND_VAULT := preload("res://src/level/diamond_vault_realm.tscn")
const FORT_KNOX := preload("res://src/level/fort_knox_realm.tscn")

var _fail: int = 0

func _ready() -> void:
	await get_tree().process_frame
	print("S11 VAULT MUSIC:")
	await _check_vault(DIAMOND_VAULT, "Diamond Vault", "diamonds_are_forever")
	await _check_vault(FORT_KNOX, "Fort Knox", "goldmine")
	print("S11_VAULT_MUSIC: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _check_vault(scene: PackedScene, vault_name: String, expect_theme: String) -> void:
	var realm: Node = scene.instantiate()
	add_child(realm)
	await get_tree().process_frame
	# AudioManager (autoload) holds the active playlist set by play_playlist().
	var playlist: Array = AudioManager.get("_playlist")
	_check("%s requests a non-empty music playlist (not silent)" % vault_name,
		playlist != null and playlist.size() >= 1,
		"playlist=%s" % str(playlist))
	var matches := false
	if playlist != null:
		for p in playlist:
			if str(p).findn(expect_theme) != -1:
				matches = true
	_check("%s plays its own exclusive track (%s), never the stage theme" % [vault_name, expect_theme],
		matches, "playlist=%s" % str(playlist))
	# Founder rule: a vault NEVER plays its parent stage theme.
	var leaked := false
	if playlist != null:
		for p in playlist:
			if str(p).findn("level02") != -1 or str(p).findn("level03") != -1:
				leaked = true
	_check("%s does not leak the parent-stage theme" % vault_name, not leaked,
		"playlist=%s" % str(playlist))
	realm.queue_free()
	await get_tree().process_frame
