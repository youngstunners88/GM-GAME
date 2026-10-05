extends Node
## Gate for the founder's round-3 range corrections (2026-10-04): a LARGE taxidermy bear target, a pre-shot-up wall,
## Bull side by side with Lil Blunt, first-person HANDS on the rifle, and the lesson's spoken counts matching FIVE
## targets. Skill ep2-range-lesson. Run: godot --headless res://tests/ep2_range_v3_test.tscn

const SMELT := preload("res://src/episode2/chamber/smelting_facility.tscn")
var _fail: int = 0
func _check(l: String, ok: bool, d: String = "") -> void:
	if ok: print("  [PASS] %s" % l)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [l, d])

func _manifest(id: String) -> String:
	var f := FileAccess.open("res://assets/audio-manifest.json", FileAccess.READ)
	for v in (JSON.parse_string(f.get_as_text()) as Dictionary).get("voice", []):
		if str(v.get("id", "")) == id: return str(v.get("text", ""))
	return ""

func _ready() -> void:
	print("EP2 RANGE V3:")
	# --- the spoken counts say FIVE ---
	for id in ["vo_bull_range_intro", "vo_bull_range_first_hit", "vo_bull_range_done"]:
		var t: String = _manifest(id).to_lower()
		_check("%s never says three/other two/six nine twelve" % id, not ("three" in t or "other two" in t or "twelve" in t))
	_check("the intro names five targets", "five" in _manifest("vo_bull_range_intro").to_lower())
	_check("the first-hit line says break the other FOUR", "four" in _manifest("vo_bull_range_first_hit").to_lower())
	_check("the closing line says all FIVE", "five" in _manifest("vo_bull_range_done").to_lower())
	# --- layout ---
	_check("five targets, last is the bear", RangeDressing.TARGET_SPOTS.size() == 5 and RangeDressing.TARGET_KINDS[4] == "bear")
	_check("the bear hit radius is large (a big target)", float(RangeDressing.TARGET_RADII[4]) >= 0.8)
	_check("the bear stands close and big (>= 3 m tall)", RangeDressing.BEAR_HEIGHT >= 3.0)
	var bull_rel: Vector3 = RangeDressing.BULL_LINE - RangeDressing.LINE
	_check("Bull stands beside the player (within 2.5 m laterally, a step ahead)", absf(bull_rel.x) <= 2.5 and bull_rel.z < 0.0 and bull_rel.z > -2.5, str(bull_rel))
	var c: SmeltingFacilityChamber = SMELT.instantiate()
	c.intro_film = false
	add_child(c)
	c.setup(0, [], 0)
	await get_tree().process_frame
	c._ensure_room()
	_check("the wall is PRE-DAMAGED: a MultiMesh of bullet holes", c._visuals.find_child("WallDamage", true, false) != null)
	var dmg: MultiMeshInstance3D = c._visuals.find_child("WallDamage", true, false) as MultiMeshInstance3D
	_check("...with plenty of holes (%d)" % (dmg.multimesh.instance_count if dmg else 0), dmg != null and dmg.multimesh.instance_count >= 60)
	var bear: Node3D = c._mold_nodes[4] as Node3D
	_check("the bear target is the taxidermy model (node 'Bear' present)", bear != null and bear.get_node_or_null("Bear") != null)
	c._on_video_film_finished()
	for i in 20: c.step(1.0 / 60.0)
	_check("first-person: Lil Blunt's HANDS are on the rifle", c._rifle_node.get_node_or_null("Hands") != null)
	_check("...both arms (right on the stock wrist, left under the fore-end)", c._rifle_node.get_node("Hands").get_node_or_null("RightArm") != null and c._rifle_node.get_node("Hands").get_node_or_null("LeftArm") != null)
	# a ray at the bear's chest hits it (large target), a shot well off does not
	c.debug_skip_lesson()
	c.spread_scale = 0.0
	c._player_pos = Vector3(RangeDressing.LINE.x, 0.0, RangeDressing.LINE.z)
	c.aim_at(c.get_mold_position(4))
	for i in 60: c.step(1.0 / 60.0)
	_check("a shot at the bear's chest breaks it", c.shoot() == true and c._mold_broken[4])
	c.queue_free()
	print("EP2_RANGE_V3: %s" % ("ALL PASS" if _fail == 0 else "FAIL (%d)" % _fail))
	get_tree().quit(_fail)
