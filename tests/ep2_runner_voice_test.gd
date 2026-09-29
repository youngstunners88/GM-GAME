extends Node
## Gate for runner_voice.gd (skill ep2-voice-barks): Lil Blunt reacts, in varied words,
## and bears are heard from far away, louder as the cart closes in.
## Run: .godot-cache/Godot_v4.3-stable_linux.x86_64 --headless res://tests/ep2_runner_voice_test.tscn

const SCENE := preload("res://src/episode2/runner/runner_graybox.tscn")
const Bank := preload("res://src/episode2/runner/voice_bank.gd")
const Voice := preload("res://src/episode2/runner/runner_voice.gd")
var _fail: int = 0

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _ready() -> void:
	# Vocabulary depth: the founder asked for variation.
	for cat in ["boulder_smash", "hit", "hop_success", "jump_clear", "bear_down", "zip_catch", "coin_streak"]:
		_check("%s has >=4 distinct lines" % cat, Bank.CATEGORIES[cat]["ids"].size() >= 4, cat)
	_check("hop celebration has >=8 lines", Bank.CATEGORIES["hop_success"]["ids"].size() >= 8)
	var missing: Array = []
	for cat in Bank.CATEGORIES:
		for id in Bank.CATEGORIES[cat]["ids"]:
			if not ResourceLoader.exists(Bank.DIR + str(id) + ".mp3"):
				missing.append(id)
	_check("every bark has an ElevenLabs take on disk", missing.is_empty(), str(missing))
	for id in Voice.BEAR_GROWLS + ["ep2_bear_roar", "ep2_bear_fall"]:
		_check("bear sound %s on disk" % id, ResourceLoader.exists(Voice.BEAR_DIR + id + ".mp3"))

	# No repeats inside a bag, and never the same line twice in a row across bags.
	var pk := Voice.Pick.new()
	pk.rng.seed = 5
	var ids: Array = Bank.CATEGORIES["hop_success"]["ids"]
	var seen: Dictionary = {}
	var prev: String = ""
	var back_to_back: bool = false
	var bag_dupe: bool = false
	for i in ids.size() * 6:
		var s: String = pk.next("hop_success", ids)
		if s == prev:
			back_to_back = true
		prev = s
		if i % ids.size() == 0:
			seen.clear()
		if seen.has(s):
			bag_dupe = true
		seen[s] = true
	_check("no line twice in a row", not back_to_back)
	_check("every line said once before any repeats", not bag_dupe)

	# Priority + gap rules.
	_check("boulder cuts a coin cheer", Voice.may_speak("boulder_smash", 10.0, {}, int(Bank.CATEGORIES["coin_streak"]["priority"])))
	_check("coin cheer never cuts a boulder scream", not Voice.may_speak("coin_streak", 10.0, {}, int(Bank.CATEGORIES["boulder_smash"]["priority"])))
	_check("category gap holds", not Voice.may_speak("coin_streak", 10.0, {"coin_streak": 8.0}, -1))
	# Bears: audible far, louder near, monotone.
	var last: float = -100.0
	var mono: bool = true
	for d in [45.0, 35.0, 25.0, 15.0, 8.0]:
		var db: float = Voice.bear_db(d)
		if db < last:
			mono = false
		last = db
	_check("bear gets louder as the cart approaches", mono and Voice.bear_db(8.0) > Voice.bear_db(40.0) + 12.0)
	_check("bear silent beyond hearing range", Voice.bear_db(60.0) <= -60.0)

	# Wired into the runner: a boulder wreck makes him scream, a hop makes him cheer.
	var r: Node3D = SCENE.instantiate()
	add_child(r)
	r.set_physics_process(false)
	var v: Node = r.get_node_or_null("Voice")
	_check("Voice node present in runner scene", v != null)
	if v:
		r.cart_wrecked.emit(0, "boulder")
		_check("boulder wreck -> boulder_smash line", v.spoken.size() == 1 and str(v.spoken[0]).begins_with("ep2_vo_boulder_smash"), str(v.spoken))
		r.cart_wrecked.emit(1, "rail_end")
		_check("rail end is not a boulder scream", v.spoken.size() == 1)
		v._voice.stop()
		v._now += 5.0
		r.obstacle_hit.emit(2)
		_check("getting hit -> hit line", v.spoken.size() == 2 and str(v.spoken[1]).begins_with("ep2_vo_hit"), str(v.spoken))
	print("VOICE TEST: %s" % ("PASS" if _fail == 0 else "FAIL (%d)" % _fail))
	get_tree().quit(0 if _fail == 0 else 1)
