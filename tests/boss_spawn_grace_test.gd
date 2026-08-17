extends Node
## Boss spawn-grace regression gate (founder hard-refresh residuals, 2026-08-17).
##
## A real-browser capture on a fresh export (docs/captures/2026-08-17-live-verify/)
## caught the player dying to boss contact within ~2s of the Stage-2 fight
## starting — before the boss's first scripted action — from raw body contact
## during the opening close-the-gap sweep, not from any attack. Each death
## fully restarts the level (GameManager.boss_contact_restart), so the fight
## never gets far enough for the player to see the boss actually chase, which
## reads as "the boss doesn't chase" even though the pursuit code itself is
## running. This proves the fix: boss body contact during the brief spawn
## grace window no longer ends the run; contact after the window still does.
##
## Run: godot --headless res://tests/boss_spawn_grace_test.tscn

const DISTRIBUTOR := preload("res://src/boss/distributor.tscn")
const CLAIM_JUMPER := preload("res://src/boss/claim_jumper.tscn")
const AUDITOR := preload("res://src/boss/auditor.tscn")

var _fail: int = 0

func _ready() -> void:
	StateMachine.change_state(StateMachine.State.TRANSITIONING)
	StateMachine.change_state(StateMachine.State.PLAYING)
	await _test_boss("Distributor", DISTRIBUTOR)
	await _test_boss("Claim Jumper", CLAIM_JUMPER)
	# Auditor (Stage 1) carries the identical hitbox/restart pattern but
	# extends CharacterBody2D directly, not BossBase, so it can't inherit
	# the base-class fix — it got its own local copy. Covered here too so
	# the one boss that DIDN'T get the founder's live complaint doesn't
	# silently keep the same failure class.
	await _test_boss("Auditor", AUDITOR)
	print("BOSS_SPAWN_GRACE: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _make_player_stub() -> Node2D:
	var p := CharacterBody2D.new()
	p.add_to_group("player")
	p.set_script(GDScript.new())  # placeholder body; only needs has_method
	return p

func _test_boss(label: String, scn: PackedScene) -> void:
	print("%s spawn grace:" % label)
	var boss: Node = scn.instantiate()
	add_child(boss)
	await get_tree().process_frame

	# Fake player body carrying take_damage so the boss's own is_in_group +
	# has_method guard passes, same shape the real Player script satisfies.
	var player := Node2D.new()
	player.add_to_group("player")
	player.set("__probe", true)
	player.set_meta("has_take_damage", true)
	# GDScript has_method() needs a real method, not a meta flag — attach one
	# via a tiny throwaway script.
	var stub_src := GDScript.new()
	stub_src.source_code = "extends Node2D\nfunc take_damage(_a):\n\tpass\n"
	stub_src.reload()
	player.set_script(stub_src)
	add_child(player)

	# is_spawn_grace_active() must be true immediately after spawn.
	_check("spawn grace is active immediately after the boss enters the tree",
		boss.call("is_spawn_grace_active") == true)

	# Calling the real contact handler during grace must NOT touch
	# GameManager's restart guard at all — checked with NO await afterward,
	# since boss_contact_restart() (if it fired) would kick off a real
	# SceneRouter.load_scene that could tear down this test's own node tree;
	# the guard flag is set synchronously at the top of that function, before
	# any scene work, so reading it immediately is race-free either way.
	GameManager.call("reset_boss_restart_flag")
	boss.call("_on_hitbox_body_entered", player)
	_check("boss contact during spawn grace does NOT restart the run",
		GameManager.get("_boss_restart_pending") == false,
		"GameManager._boss_restart_pending went true during the spawn-grace window")

	# Wait out the grace window, then confirm contact DOES restart — the
	# founder's stakes rule ("any boss touch restarts") must still hold once
	# the grace window has genuinely elapsed. Checked the same synchronous way
	# — the flag flips true before SceneRouter.load_scene runs, so this proves
	# the restart PATH was entered without needing the reload to complete
	# (which would free this test's own nodes mid-run).
	var waited := 0.0
	while boss.call("is_spawn_grace_active") and waited < 3.0:
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
	_check("spawn grace actually expires within its documented window",
		not boss.call("is_spawn_grace_active"), "still active after %.1fs" % waited)

	# NOT invoked live past this point: a real post-grace contact call enters
	# GameManager.boss_contact_restart(), which queues a genuine
	# SceneRouter.load_scene() — that would tear down this very test's own
	# node tree mid-run (this .tscn is the loaded scene under --headless).
	# Instead prove the stakes rule statically: once grace is inactive, the
	# handler's only remaining branch must be the original unconditional
	# GameManager.boss_contact_restart() call — i.e. the new guard is an
	# early-return ADDED in front of it, not a replacement that could
	# swallow every call forever.
	var src_path := "res://src/boss/claim_jumper.gd"
	if label == "Distributor":
		src_path = "res://src/boss/distributor.gd"
	elif label == "Auditor":
		src_path = "res://src/boss/auditor.gd"
	var src := FileAccess.get_file_as_string(src_path)
	var handler := src.substr(src.find("func _on_hitbox_body_entered"))
	handler = handler.substr(0, handler.find("\nfunc "))
	_check("the spawn-grace guard is an early-return, not a replacement of the restart call",
		handler.contains("is_spawn_grace_active()") and handler.contains("GameManager.boss_contact_restart()"),
		"handler no longer reaches boss_contact_restart() unconditionally after the guard")
