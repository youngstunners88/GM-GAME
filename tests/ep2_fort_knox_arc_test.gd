extends Node
## Gate for the founder's LOCKED Episode 2 arc (PROMPT_EPISODE2_FORT_KNOX_AWESOMEX_FOUNDATION.md, skill ep2-fort-knox-arc).
##
## What it locks (the founder's own rules, 2026-10-09):
##  * the foundation file is in the repo and still carries the rules world-build tools must read first;
##  * CLAUDE.md routes Episode 2 work to the arc skill and the scene pipeline skill (they exist);
##  * PREP ONLY: the story chambers still have no claim-run / decoy / vault beats until the founder opens the prep pass;
##  * THREE HEARTS MAX and no second health system; NO DIAMONDS in this chapter's speech or scripts; no pickup-truck ending;
##    exactly ONE quad; Lil Blunt is first person with the rifle in his hands (never slung).
## If the founder opens the next step of the run: update the expected beats below AND the status table in the skill, same commit.
## Run: godot --headless res://tests/ep2_fort_knox_arc_test.tscn

var _fail: int = 0


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])


func _text(path: String) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""


func _ready() -> void:
	await get_tree().process_frame
	print("-- THE FOUNDER'S FILE")
	var doc: String = _text("res://PROMPT_EPISODE2_FORT_KNOX_AWESOMEX_FOUNDATION.md")
	_check("the foundation file is in the repo (world tools read it first)", doc != "")
	for phrase in ["Do not implement the ride until the founder says the prep pass is open", "Do not invent a second plot",
			"Three hearts max", "Do not put Diamonds in this chapter", "Auction waits", "Vehicles: one quad, then none",
			"Inferno Bull: driver, then sacrifice, then rescued. Not killed", "AwesomeX: third, late, dragon, machine guns, rescue",
			"Bull rescue mark. He is down, not a corpse"]:
		_check("the file still says: \"%s\"" % phrase, phrase in doc)

	print("-- ROUTING")
	var claude_md: String = _text("res://CLAUDE.md")
	_check("CLAUDE.md routes Episode 2 world-building to ep2-fort-knox-arc", "ep2-fort-knox-arc" in claude_md)
	_check("CLAUDE.md routes scene building to ep2-hyperreal-scene-pipeline", "ep2-hyperreal-scene-pipeline" in claude_md)
	_check("the arc skill exists", FileAccess.file_exists("res://.claude/skills/ep2-fort-knox-arc/SKILL.md"))
	_check("the scene pipeline skill exists", FileAccess.file_exists("res://.claude/skills/ep2-hyperreal-scene-pipeline/SKILL.md"))
	_check("the reference spec for the prep set pieces exists", FileAccess.file_exists("res://tools/ep2_forge/fort_knox_refs.json"))

	print("-- PREP ONLY: the playable slice stops at the spy point")
	var woods_beats: Array = WoodsQuadChamber.Beat.keys()
	_check("the woods chamber has only its groundwork beats (no CLAIM / DECOY / VAULT / SACRIFICE / RESCUE beat)",
		woods_beats == ["SNEAK", "REVEAL", "MOUNT", "RIDE", "SPY", "DONE"], str(woods_beats))
	var lift_beats: Array = MineLiftChamber.Beat.keys()
	_check("the lift chamber keeps its groundwork beats", lift_beats == ["ARRIVE", "BOARD", "LEVER", "RISE", "SURFACE", "DONE"], str(lift_beats))
	_check("the session root still ends the slice at the spy point (end_session)", "end_session" in _text("res://src/episode2/chamber/woods_quad.gd"))

	print("-- HEARTS, DIAMONDS, VEHICLES")
	_check("three hearts max in the hideout (the only health the story has)", SmeltingFacilityChamber.MAX_HEALTH == 3)
	var hud := Ep2FpsHud.new()
	_check("the first-person HUD carries a 3-heart cap by default", hud.health_max == 3)
	hud.free()
	var lift: MineLiftChamber = load("res://src/episode2/chamber/mine_lift.tscn").instantiate()
	add_child(lift)
	lift.setup(0, [], 0)
	await get_tree().process_frame
	_check("the interlude reports the 3-heart cap (no second health system)", lift.get_health() == 3)
	_check("Lil Blunt is first person with the rifle in his hands (ammo + viewmodel on the camera)",
		lift.is_fps() and lift.get_viewmodel() != null and lift.get_viewmodel().rifle.get_parent() == lift.get_camera() and lift.get_ammo() > 0)
	_check("...and the rifle is never slung on his back", lift._player_node.find_child("SlungRifle", true, false) == null)
	lift.queue_free()
	var w: WoodsQuadChamber = load("res://src/episode2/chamber/woods_quad.tscn").instantiate()
	add_child(w)
	w.setup(0, [], 0)
	await get_tree().process_frame
	var quads: int = 0
	for n in w.find_children("*", "Node3D", true, false):
		if str(n.name) == "FlameQuad":
			quads += 1
	_check("exactly ONE quad in the world (one quad, then none)", quads == 1, str(quads))
	w.queue_free()

	var manifest: Dictionary = JSON.parse_string(_text("res://assets/audio-manifest.json"))
	var story_ids := ["vo_bull_lava", "vo_bull_lift", "vo_bull_plan", "vo_lb_plan", "vo_bull_woods", "vo_bull_quad", "vo_lb_quad", "vo_bull_spy", "vo_lb_spy"]
	var clean: bool = true
	var bad: String = ""
	var checked: int = 0
	for e in manifest["voice"]:
		var id: String = str(e["id"])
		for pre in story_ids:
			if id.begins_with(pre):
				checked += 1
				var t: String = str(e["text"]).to_lower()
				if "diamond" in t or "auction" in t or "truck" in t:
					clean = false
					bad = id
	_check("none of the %d story lines mentions Diamonds, the Auction or a truck" % checked, clean and checked >= 20, bad)
	var code_clean: bool = true
	for p in ["res://src/episode2/chamber/interlude_base.gd", "res://src/episode2/chamber/mine_lift.gd", "res://src/episode2/chamber/woods_quad.gd", "res://src/episode2/chamber/ep2_viewmodel.gd"]:
		var src: String = _text(p).to_lower().replace("_diamonds_paid", "")      # the session-root setup() signature carries that name for every chamber; it is not a mechanic
		for banned in ["diamond", "pickup_truck", "pickup truck"]:
			if banned in src:
				code_clean = false
				bad = "%s has '%s'" % [p, banned]
	_check("no Diamonds / pickup-truck anywhere in the interlude code", code_clean, bad)

	await get_tree().process_frame
	if _fail == 0:
		print("EP2_FORT_KNOX_ARC: ALL PASS")
		get_tree().quit(0)
	else:
		print("EP2_FORT_KNOX_ARC: %d FAILED" % _fail)
		get_tree().quit(1)
