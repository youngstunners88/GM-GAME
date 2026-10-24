extends RefCounted
## Test-harness hooks for the real-browser transition/touch probes (scripts/mobile-transition-probe.mjs).
##
## EVERYTHING in this file is compiled OUT of the shipped build by a CUSTOM FEATURE TAG, not by a URL flag:
##   * `gm_harness` is a custom feature that only scripts/ep2-local-export.sh can put into an export preset
##     (opt-in: `GM_HARNESS=1 bash scripts/ep2-local-export.sh`). The CI preset heredoc and scripts/export-web.sh keep
##     `custom_features=""`, so on itch.io `OS.has_feature("gm_harness")` is false and every function below returns
##     false / does nothing. A URL such as `?ep2gate=skip` on the live site is therefore ignored.
##   * scripts/check-harness-hooks.py (CI, no Godot) fails the build if a harness query parameter is read anywhere
##     except through `allowed()`, if `allowed()` stops requiring both `web` and the tag, or if either preset writer
##     ever contains gm_harness. tests/harness_hooks_inert_test.tscn proves the decision logic and the call sites.
##
## Two hooks, both unlocked-file so main_menu.gd (founder-locked) is untouched:
##   ?ep2gate=skip  - Ep2Entry._is_unlocked() treats the access-code gate as passed (GameManager.ep2_story_unlocked),
##                    exactly what beating boss 3 does in memory. Lets a script reach the runner from ?ep2=1.
##   ?bosskill=N    - with ?boss=3, the Claim Jumper is killed N seconds (1..120) after the arena opens, through his REAL die()
##                    (so TransitionDirector.prewarm -> film -> TransitionDirector.go all run unchanged), with ONE
##                    difference: GameManager.mark_boss_defeated("claim_jumper") is skipped, so no progression write
##                    and NO soulbound NFT can be issued (NftIssuer.on_boss_defeated is only reachable through it).
##
## Pure GDScript, no class_name (nothing to re-import): callers `const HarnessHooks := preload(...)`.
## The only JavaScriptBridge.eval is a literal string with no interpolation (sentinel INJ-003 safe).

const TAG := "gm_harness"
## Set on a boss by kill_boss_after(); read by skip_boss_credit() from claim_jumper.die().
const META_NO_CREDIT := &"gm_harness_no_credit"
const KILL_DELAY_MAX_S := 120
const KILL_LEVEL := 3
const KILL_SCRIPT_SUFFIX := "claim_jumper.gd"

## THE gate. A harness parameter is read only when the page is a web build AND the build carries the gm_harness tag;
## otherwise this returns "" (as if the parameter were absent) and the page URL is never even read.
## `web` / `tag` are parameters so the headless test can feed every combination; real callers pass OS.has_feature(...).
## `search_override` ("?a=b&c=d") replaces window.location.search in tests.
static func gated_value(web: bool, tag: bool, key: String, search_override: String = "") -> String:
	if not (web and tag):
		return ""
	var search: String = search_override if search_override != "" else _search()
	return param(search, key)

## True when the (gated) parameter `key` equals the non-empty `wanted`.
static func allowed(web: bool, tag: bool, key: String, wanted: String, search_override: String = "") -> bool:
	return wanted != "" and gated_value(web, tag, key, search_override) == wanted

## Value of `key` in a query string ("?a=b&c=d" or "a=b&c=d"); "" when absent. Pure.
static func param(search: String, key: String) -> String:
	for pair: String in search.trim_prefix("?").split("&", false):
		var kv: PackedStringArray = pair.split("=", true, 1)
		if kv.size() == 2 and kv[0] == key:
			return kv[1]
	return ""

## The ONLY JavaScriptBridge.eval in this file: a literal, no interpolation. Called from gated_value() after the gate.
static func _search() -> String:
	var v: Variant = JavaScriptBridge.eval("window.location.search", true)
	return str(v) if v != null else ""

# --- hook (a): access-code gate ---------------------------------------------------------------------------------

static func ep2_gate_skip_requested() -> bool:
	return allowed(OS.has_feature("web"), OS.has_feature("gm_harness"), "ep2gate", "skip")

## Called from Ep2Entry._is_unlocked(). Returns true when it unlocked the session. No-op in the shipped build.
static func apply_ep2_gate_skip() -> bool:
	if not ep2_gate_skip_requested():
		return false
	GameManager.ep2_story_unlocked = true
	print("[HARNESS] ep2gate=skip -> GameManager.ep2_story_unlocked (gm_harness build only)")
	return true

# --- hook (b): fast boss-3 kill -----------------------------------------------------------------------------------

## Seconds from the arena opening to the kill, from the (already gated) parameter value: its integer value clamped to
## KILL_DELAY_MAX_S, or 0.0 (= no kill) when it is empty / not a positive integer. Pure.
static func kill_delay(gated: String) -> float:
	if not gated.is_valid_int() or int(gated) < 1:
		return 0.0
	return float(mini(int(gated), KILL_DELAY_MAX_S))

static func boss_kill_delay_s() -> float:
	return kill_delay(gated_value(OS.has_feature("web"), OS.has_feature("gm_harness"), "bosskill"))

static func boss_kill_requested() -> bool:
	return boss_kill_delay_s() > 0.0

## Called (not awaited) from LevelBase._maybe_debug_boss_warp() right after the arena trigger fired. Does nothing
## unless the gate lets the parameter through, the level is stage 3 and the boss's script is claim_jumper.gd. The fuse
## belongs to `level`: if that level instance is gone when it burns (the player died and the level reloaded) it does
## nothing, so a stale fuse can never kill the NEXT instance's boss. `script_suffix` is a parameter only so the
## headless test can aim it at a fixture boss.
static func kill_boss_after(level: Node, level_index: int, script_suffix: String = KILL_SCRIPT_SUFFIX) -> void:
	var delay_s: float = boss_kill_delay_s()
	if level_index != KILL_LEVEL or delay_s <= 0.0 or level == null or not level.is_inside_tree():
		return
	print("[HARNESS] bosskill armed: stage-3 boss die() in %.1f s (gm_harness build only)" % delay_s)
	var tree: SceneTree = level.get_tree()
	await tree.create_timer(delay_s).timeout
	if not is_instance_valid(level) or not level.is_inside_tree():
		print("[HARNESS] bosskill: fuse dropped, its level is gone")
		return
	if not _kill_boss(tree, script_suffix):
		print("[HARNESS] bosskill: no live claim_jumper in group boss after %.1f s" % delay_s)

## Marks the first live boss whose script ends with `script_suffix` as no-credit and calls its real die().
## Private: only kill_boss_after() (after the gate) and the headless test (a positive control) call it.
static func _kill_boss(tree: SceneTree, script_suffix: String) -> bool:
	for b: Node in tree.get_nodes_in_group("boss"):
		if not is_instance_valid(b) or not b.has_method("die") or bool(b.get("is_dead")):
			continue
		var s: Script = b.get_script() as Script
		if s == null or not s.resource_path.ends_with(script_suffix):
			continue
		b.set_meta(META_NO_CREDIT, true)
		print("[HARNESS] bosskill: stage-3 boss die() with progression credit + NFT skipped (gm_harness build only)")
		b.call("die")
		return true
	return false

## Asked by ClaimJumper.die() before it records the defeat. True ONLY in a gm_harness build for a boss that
## kill_boss_after() marked - so the real kill (and every shipped build) still calls mark_boss_defeated.
static func skip_boss_credit(boss: Node) -> bool:
	return OS.has_feature("gm_harness") and is_instance_valid(boss) and boss.has_meta(META_NO_CREDIT)
