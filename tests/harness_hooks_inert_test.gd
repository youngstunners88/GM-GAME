extends Node
## HARNESS_HOOKS_INERT: the two test-harness hooks (src/debug/harness_hooks.gd) must do NOTHING in a build that does
## not carry the `gm_harness` feature tag - i.e. the shipped itch build and this headless editor run.
##   (a) ?ep2gate=skip must not open the Episode 2 access-code gate
##   (b) ?bosskill=1 must not kill the stage-3 boss, and the boss credit / NFT path must stay reachable
## The headless run can never have the tag or be a web build, so the decision logic is driven through the pure
## allowed() function with every web/tag combination (a positive control proves the hook WOULD fire when both are
## set), and the real call sites are checked structurally. Mutation checks: scripts/check-harness-hooks.py header.

const HarnessHooks := preload("res://src/debug/harness_hooks.gd")
const ENTRY := preload("res://src/episode2/ep2_entry.gd")
const FAKE_BOSS := preload("res://tests/fixtures/harness_fake_boss.gd")
var _fail: int = 0

func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_fail += 1

func _src(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_as_text() if f != null else ""

func _ready() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ENTRY.UNLOCK_FILE))
	# --- 0. this build is the untagged one --------------------------------------------------------------------
	_check("this build does NOT carry the gm_harness tag", not OS.has_feature("gm_harness"))
	_check("this build is not a web build", not OS.has_feature("web"))

	# --- 1. the pure gate: every web/tag combination --------------------------------------------------------------
	var q := "?debug=1&ep2gate=skip&bosskill=1"
	_check("gate: web+tag+param -> allowed (positive control)", HarnessHooks.allowed(true, true, "ep2gate", "skip", q))
	_check("gate: web+tag+param(bosskill) -> allowed (positive control)", HarnessHooks.allowed(true, true, "bosskill", "1", q))
	_check("gate: web, NO tag -> refused (the shipped build)", not HarnessHooks.allowed(true, false, "ep2gate", "skip", q))
	_check("gate: tag but NOT web -> refused", not HarnessHooks.allowed(false, true, "ep2gate", "skip", q))
	_check("gate: neither -> refused", not HarnessHooks.allowed(false, false, "ep2gate", "skip", q))
	_check("gate: wrong value -> refused", not HarnessHooks.allowed(true, true, "ep2gate", "no", q))
	_check("gate: param absent -> refused", not HarnessHooks.allowed(true, true, "ep2gate", "skip", "?debug=1"))
	_check("gate: bosskill=0 -> refused", not HarnessHooks.allowed(true, true, "bosskill", "1", "?bosskill=0"))
	_check("param(): plain, no leading ?", HarnessHooks.param("a=b&c=d", "c") == "d")
	_check("param(): value containing '='", HarnessHooks.param("?k=a=b", "k") == "a=b")
	_check("param(): prefix of another key is not a match", HarnessHooks.param("?ep2gateX=skip", "ep2gate") == "")

	# --- 2. the real wrappers in THIS build -----------------------------------------------------------------------
	_check("real: ep2_gate_skip_requested() is false", not HarnessHooks.ep2_gate_skip_requested())
	_check("real: boss_kill_requested() is false", not HarnessHooks.boss_kill_requested())

	# --- 3. hook (a): the access-code gate stays shut -------------------------------------------------------------
	GameManager.ep2_story_unlocked = false
	_check("hook a: apply_ep2_gate_skip() returns false", not HarnessHooks.apply_ep2_gate_skip())
	_check("hook a: ...and did not unlock the story flag", not GameManager.ep2_story_unlocked)
	var entry: Node = ENTRY.new()                      # not in the tree: _is_unlocked() only needs GameManager + user://
	_check("hook a: Ep2Entry._is_unlocked() is false with no code and no earned flag", not entry._is_unlocked())
	entry.free()
	var es := _src("res://src/episode2/ep2_entry.gd")
	var i_fn := es.find("func _is_unlocked()")
	var i_hook := es.find("HarnessHooks.apply_ep2_gate_skip()", i_fn)
	var i_next := es.find("\nfunc ", i_fn + 10)
	_check("hook a: _is_unlocked() calls the harness hook (and nothing else reads ep2gate)",
		i_fn >= 0 and i_hook > i_fn and (i_next < 0 or i_hook < i_next))

	# --- 4. hook (b): the fast kill does nothing, the credit path stays reachable --------------------------------
	var boss := Node.new()
	boss.set_script(FAKE_BOSS)
	boss.add_to_group("boss")
	add_child(boss)
	# positive control: the selection logic itself works on this fixture, so the no-op results below mean something
	var killed: bool = HarnessHooks._kill_boss(get_tree(), "harness_fake_boss.gd")
	_check("hook b control: _kill_boss() finds and kills the fixture boss", killed and boss.died == 1)
	_check("hook b control: ...and marks it no-credit", boss.has_meta(HarnessHooks.META_NO_CREDIT))
	_check("hook b: skip_boss_credit() is STILL false without the tag, even for a marked boss",
		not HarnessHooks.skip_boss_credit(boss))
	boss.free()

	var boss2 := Node.new()
	boss2.set_script(FAKE_BOSS)
	boss2.add_to_group("boss")
	add_child(boss2)
	await HarnessHooks.kill_boss_after(get_tree(), 0.0, 3, "harness_fake_boss.gd")
	for _i in 4:
		await get_tree().process_frame
	_check("hook b: kill_boss_after(stage 3) did NOT kill the boss without the tag", boss2.died == 0 and not boss2.is_dead)
	_check("hook b: ...and did not mark it", not boss2.has_meta(HarnessHooks.META_NO_CREDIT))
	await HarnessHooks.kill_boss_after(get_tree(), 0.0, 1, "harness_fake_boss.gd")
	_check("hook b: other stages never kill either", boss2.died == 0)
	boss2.free()

	var cj := _src("res://src/boss/claim_jumper.gd")
	var i_guard := cj.find("if not preload(\"res://src/debug/harness_hooks.gd\").skip_boss_credit(self):")
	var i_mark := cj.find("GameManager.mark_boss_defeated(\"claim_jumper\")")
	_check("hook b: ClaimJumper.die() keeps mark_boss_defeated behind ONLY the harness skip guard",
		i_guard >= 0 and i_mark > i_guard and cj.substr(i_guard, i_mark - i_guard).count("\n") == 1)
	_check("hook b: LevelBase fires kill_boss_after only from the debug boss warp",
		_src("res://src/level/level_base.gd").count("kill_boss_after(") == 1)

	# --- 5. nobody else reads the harness parameters -----------------------------------------------------------
	var strays: Array[String] = []
	_scan("res://src", strays)
	_check("no other file under src/ mentions ep2gate or bosskill (strays: %s)" % ", ".join(strays), strays.is_empty())

	DirAccess.remove_absolute(ProjectSettings.globalize_path(ENTRY.UNLOCK_FILE))
	print("HARNESS_HOOKS_INERT: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(0 if _fail == 0 else 1)

func _scan(dir: String, strays: Array[String]) -> void:
	for f: String in DirAccess.get_files_at(dir):
		if f.get_extension() != "gd" or (dir + "/" + f) == "res://src/debug/harness_hooks.gd":
			continue
		var t := _src(dir + "/" + f)
		if t.contains("ep2gate") or t.contains("bosskill"):
			strays.append(dir + "/" + f)
	for d: String in DirAccess.get_directories_at(dir):
		_scan(dir + "/" + d, strays)
