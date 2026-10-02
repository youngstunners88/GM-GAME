extends SceneTree
## Founder rule (2026-10-02): every quiz question must TEACH THE PROTOCOL
## (SMOKE / DIAMONDS / GOLD MINE). Questions about the game itself - the room,
## the examiner, the quiz, the video/whitepaper props, the scorecard, stage
## flow - are banned. This gate fails the build if one comes back.
## Run: godot --headless --script res://tests/quiz_protocol_only_test.gd

const META := ["room", "quiz", "examiner", "administers", "the test", "scorecard", "icp",
	"video", "whitepaper prop", "study path", "stage 1", "stage 2", "stage 3", "pass bar",
	"this room", "set-piece", "classroom", "recorded", "stamp"]
const BANKS := ["smoke", "diamonds", "gold"]

func _init() -> void:
	var fails := 0
	for p in BANKS:
		var f := FileAccess.open("res://src/protocol_portals/data/quiz_%s.json" % p, FileAccess.READ)
		var d: Dictionary = JSON.parse_string(f.get_as_text())
		var qs: Array = d["questions"]
		if qs.size() != 11:
			print("  FAIL %s: expected 11 questions, got %d" % [p, qs.size()]); fails += 1
		for q in qs:
			var text: String = (str(q["prompt"]) + " " + " ".join(q["options"])).to_lower()
			for w in META:
				if text.contains(w):
					print("  FAIL %s %s mentions game-meta '%s': %s" % [p, q["id"], w, q["prompt"]]); fails += 1
	print("QUIZ_PROTOCOL_ONLY: %s" % ("ALL PASS" if fails == 0 else "%d FAILURE(S)" % fails))
	quit(fails)
