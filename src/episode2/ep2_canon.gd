class_name Ep2Canon
extends RefCounted
## Episode 2 narrative-continuity MEMORY (founder 2026-10-04: "build a memory layer that helps with these kinds of
## logical nuances. Don't let Inferno repeat that now's the best time to go bear hunt. It's already in the video").
##
## The game must not re-tell the player something a cutscene already showed. This static helper reads
## `src/data/ep2_narrative_canon.json` - the single list of facts the cliff-to-hideout film establishes and the
## dialogue lines that would redundantly repeat them - and answers one question the dialogue system asks before it
## speaks: has the film already said this? If so, the line is dropped. Extend the JSON, not this code, as the
## story grows. Skill: ep2-narrative-canon.

const CANON_PATH := "res://src/data/ep2_narrative_canon.json"
static var _redundant: Dictionary = {}
static var _loaded: bool = false


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(CANON_PATH):
		return
	var f := FileAccess.open(CANON_PATH, FileAccess.READ)
	if f == null:
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	if data is Dictionary and (data as Dictionary).has("redundant_after_film"):
		_redundant = (data as Dictionary)["redundant_after_film"]


## True when `line_id` only restates something the film already established, so it must not play after the film.
static func is_redundant_after_film(line_id: String) -> bool:
	_load()
	return _redundant.has(line_id)


## The fact id a line would repeat (for logs/tests), or "" if the line is not redundant.
static func fact_for(line_id: String) -> String:
	_load()
	return str(_redundant.get(line_id, ""))
