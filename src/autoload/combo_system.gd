extends Node
## Combo & score system — drives addictive feedback loops.
## Tracks collectible/enemy chains, score multipliers, and posts events
## to the JS launcher overlay for combo UI display.

signal combo_changed(value: int)
signal score_changed(value: int)
signal milestone_hit(milestone_name: String)

const COMBO_WINDOW: float = 3.0
const MILESTONES: Array[int] = [5, 10, 15, 25, 50, 100]

var current_combo: int = 0
var combo_timer: float = 0.0
var current_score: int = 0
var milestones_hit: Dictionary = {}

func _process(delta: float) -> void:
	if current_combo > 0:
		combo_timer -= delta
		if combo_timer <= 0:
			_reset_combo()

## Award points and increment combo. Score scales with combo multiplier.
func add_score(base_points: int) -> void:
	current_combo += 1
	combo_timer = COMBO_WINDOW
	var multiplier := _get_multiplier()
	var awarded := int(base_points * multiplier)
	current_score += awarded
	combo_changed.emit(current_combo)
	score_changed.emit(current_score)
	_check_milestones()
	_post_to_launcher("combo", current_combo)
	_post_to_launcher("score", current_score)

## Award points without breaking combo (background collectibles).
func add_score_no_combo(base_points: int) -> void:
	current_score += base_points
	score_changed.emit(current_score)
	_post_to_launcher("score", current_score)

func _get_multiplier() -> float:
	if current_combo >= 50: return 5.0
	if current_combo >= 25: return 4.0
	if current_combo >= 15: return 3.0
	if current_combo >= 10: return 2.5
	if current_combo >= 5: return 2.0
	if current_combo >= 3: return 1.5
	return 1.0

func _check_milestones() -> void:
	for m in MILESTONES:
		if current_combo >= m and not milestones_hit.has(m):
			milestones_hit[m] = true
			var name := "x%d Combo!" % m
			milestone_hit.emit(name)
			ScreenShake.shake(0.15, 4.0)

func _reset_combo() -> void:
	if current_combo > 0:
		current_combo = 0
		combo_timer = 0.0
		milestones_hit.clear()
		combo_changed.emit(0)
		_post_to_launcher("combo", 0)

## Called by player when taking damage — breaks the chain.
func break_combo() -> void:
	_reset_combo()

func reset_session() -> void:
	current_combo = 0
	combo_timer = 0.0
	current_score = 0
	milestones_hit.clear()

## Post a structured event to the JS launcher overlay if running in browser.
## The launcher iframe is same-origin, so target location.origin instead of
## '*' — a cross-origin embedder (e.g. itch.io framing us directly) has no
## launcher and must not receive game telemetry (security audit finding #3).
func _post_to_launcher(event_type: String, value: Variant) -> void:
	if OS.has_feature("web"):
		var payload := JSON.stringify({"type": event_type, "value": value})
		JavaScriptBridge.eval(
			"try { window.parent.postMessage(%s, window.location.origin); } catch (e) {}" % payload
		)

## Notify launcher of an achievement unlock by id.
func unlock_achievement(id: String) -> void:
	if OS.has_feature("web"):
		var payload := JSON.stringify({"type": "achievement", "id": id})
		JavaScriptBridge.eval(
			"try { window.parent.postMessage(%s, window.location.origin); } catch (e) {}" % payload
		)
