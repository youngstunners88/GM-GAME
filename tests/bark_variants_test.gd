extends Node
## VO — Lil Blunt bark vocabulary gate.
##
## Founder: "Lil Blunt only has one line for hurt / hitting an enemy etc — his
## vocabulary is very low, give him at least three variations each." This asserts
## every wired bark id (played via AudioManager.play_bark) ships >= 3 loadable
## clips (base + _2/_3...), so the random-variant picker actually has variety.
##
## Run: godot --headless res://tests/bark_variants_test.tscn
const BASES := ["vo_hurt", "vo_attack", "vo_death", "vo_collect_major", "vo_boss_hype"]
var _fail := 0
func _ready() -> void:
	print("BARK VOCAB:")
	for base in BASES:
		var n := 0
		for suffix in ["", "_2", "_3", "_4", "_5", "_6"]:
			for ext in [".ogg", ".mp3"]:
				var p := "res://src/assets/sounds/voice/%s%s%s" % [base, suffix, ext]
				if ResourceLoader.exists(p):
					if load(p) is AudioStream:
						n += 1
					break
		var ok := n >= 3
		print("  [%s] %s has %d variations (>=3)" % ["PASS" if ok else "FAIL", base, n])
		if not ok:
			_fail += 1
	print("BARK_VOCAB: %s" % ("ALL PASS" if _fail == 0 else "%d FAIL" % _fail))
	get_tree().quit(_fail)
