extends Node
## Gate for the narrative-continuity MEMORY layer (founder 2026-10-04: "build a memory layer that helps with these
## kinds of logical nuances. Don't let Inferno repeat that now's the best time to go bear hunt. It's already in the
## video"). After the film plays, the hideout dialogue must DROP any line the film already established, and keep
## the forward-looking ones. Skill ep2-narrative-canon.
## Run: godot --headless res://tests/ep2_narrative_canon_test.tscn

const SMELT := preload("res://src/episode2/chamber/smelting_facility.tscn")
var _fail: int = 0
func _check(l: String, ok: bool, d: String = "") -> void:
	if ok: print("  [PASS] %s" % l)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [l, d])

func _ids(steps: Array) -> Array:
	var out: Array = []
	for s in steps:
		if s is Dictionary and str(s.get("do", "")) == "say":
			out.append(str(s["id"]))
	return out

func _ready() -> void:
	print("EP2 NARRATIVE CANON:")
	# the memory data itself
	_check("the bear-hunt line is flagged redundant-after-film", Ep2Canon.is_redundant_after_film("vo_bull_bears"))
	_check("it maps to the film's bears-took-the-Gold-Mine beat", Ep2Canon.fact_for("vo_bull_bears") == "bears_took_goldmine")
	_check("a forward-looking line is NOT flagged", not Ep2Canon.is_redundant_after_film("vo_bull_partner"))
	_check("the deal line is NOT flagged", not Ep2Canon.is_redundant_after_film("vo_bull_deal2"))

	var c: SmeltingFacilityChamber = SMELT.instantiate()
	c.intro_film = false
	add_child(c)
	c.setup(0, [], 0)
	await get_tree().process_frame
	var B = c.Beat
	# WITHOUT the film (e.g. a straight beat-sheet run), nothing is redundant: the bear line stays.
	c._film_played = false
	_check("no film -> the bear-hunt line is still in TERMS", "vo_bull_bears" in _ids(FacilityShow.steps_for(c, B.TERMS)))
	# WITH the film (the real game), the bear-hunt line is dropped, but TERMS still advances (padded), and the
	# Fort Knox partnership line survives.
	c._film_played = true
	var terms: Array = FacilityShow.steps_for(c, B.TERMS)
	_check("after the film -> Inferno does NOT repeat the bear-hunt invite", not ("vo_bull_bears" in _ids(terms)))
	_check("...and the emptied TERMS beat still has a step so it advances", not terms.is_empty())
	var promise: Array = FacilityShow.steps_for(c, B.PROMISE)
	_check("the forward-looking Fort Knox partnership line still plays", "vo_bull_partner" in _ids(promise))
	_check("Lil Blunt's agreement still plays", "vo_lb_partner_ok" in _ids(promise))
	c.queue_free()
	print("EP2_NARRATIVE_CANON: %s" % ("ALL PASS" if _fail == 0 else "FAIL (%d)" % _fail))
	get_tree().quit(_fail)
