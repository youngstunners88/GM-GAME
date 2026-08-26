extends CanvasLayer
## F3 truth overlay (merged 2026-08-26 residual, Phase 1). Toggle with F3 (also
## '?debug=1' on web forces it on at boot). Shows the live player + boss state so
## a founder screenshot during a freeze or a "boss parked" moment is hard
## evidence of the actual flags — injected BEFORE trusting any logic claim.
##
## Read-only: it never touches game state, only reports it. Off by default so it
## never covers normal play.

var _label: Label
var _on: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 128
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_constant_override("outline_size", 4)
	_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6, 1.0))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_label.position = Vector2(12, 70)
	add_child(_label)
	_label.visible = false
	# Web: allow ?debug=1 to force the overlay on for a founder capture session.
	if OS.has_feature("web"):
		var q: String = str(JavaScriptBridge.eval(
			"new URLSearchParams(window.location.search).get('debug') || ''", true))
		if q == "1":
			_on = true
			_label.visible = true

func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo and k.keycode == KEY_F3:
		_on = not _on
		_label.visible = _on

func _process(_delta: float) -> void:
	if not _on:
		return
	_label.text = _compose()

func _compose() -> String:
	var lines: Array[String] = []
	lines.append("BUILD %s   PAUSED %s   TIME_SCALE %.2f"
		% [GameManager.BUILD_TAG, str(get_tree().paused), Engine.time_scale])
	lines.append("STATE %s" % StateMachine.get_current_state())
	var pl := get_tree().get_first_node_in_group("player")
	if pl != null and is_instance_valid(pl):
		var v: Vector2 = pl.get("velocity") if pl.get("velocity") != null else Vector2.ZERO
		lines.append("PLAYER pos(%.0f,%.0f) |v|=%.0f floor=%s wall=%s climb=%s dying=%s scale=%.2f"
			% [pl.global_position.x, pl.global_position.y, v.length(),
				str(pl.call("is_on_floor") if pl.has_method("is_on_floor") else "?"),
				str(pl.call("is_on_wall") if pl.has_method("is_on_wall") else "?"),
				str(pl.get("_climbing")), str(pl.get("_dying")), pl.scale.x])
	# Any live bosses (group "boss"): state + lunge/dive + gap to player.
	for b in get_tree().get_nodes_in_group("boss"):
		if not is_instance_valid(b):
			continue
		var state_v = b.get("current_state")
		if state_v == null:
			state_v = b.get("current_phase_state")
		var surge = b.get("_surge_active")
		var gap := "?"
		if pl != null and is_instance_valid(pl):
			gap = "%.0f" % absf((b.global_position.x) - pl.global_position.x)
		lines.append("BOSS %s state=%s lunge=%s gap=%s"
			% [str(b.get("boss_display_name")), str(state_v), str(surge), gap])
	return "\n".join(lines)
