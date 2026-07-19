extends Node
## DifficultyManager (autoload) — invisible adaptive difficulty (Video-Game
## Layer, task #23). Before a level starts it pulls this player's death heatmap
## and pacing stats from the backend (/player-analytics via Web3Bridge) and
## exposes TUNING FLAGS that levels/enemies consume. The player is never told:
## no UI, no announcement — the level just "feels right".
##
## Tuning rules (design spec, LEVEL_DEPTH.md):
##   died to Tax Collector > 3x  -> tax_speed_scale 0.85 (15% slower patrols)
##   died to boulders      > 2x  -> boulder_warning true (smoke puff 1s early)
##   avg completion  > 5 minutes -> extra_checkpoint true
##   retries        > 10         -> hint_leaf true (optimal-path powerup)
##
## Degrades to neutral defaults with no backend / offline / new player — the
## Book-Layer level is exactly the shipped design in that case.

## Neutral defaults — a fresh or offline player gets the authored level.
var tax_speed_scale: float = 1.0
var boulder_warning: bool = false
var extra_checkpoint: bool = false
var hint_leaf: bool = false
var loaded: bool = false

signal tuning_ready()

## Called by LevelBase before gameplay begins. Non-blocking: the level starts
## with defaults and re-tunes the moment analytics arrive (sub-second on a
## healthy backend; never at all offline — both are fine).
func refresh() -> void:
	tax_speed_scale = 1.0
	boulder_warning = false
	extra_checkpoint = false
	hint_leaf = false
	loaded = false
	if not Web3Bridge.has_backend():
		tuning_ready.emit()
		return
	Web3Bridge.get_player_analytics(_on_analytics)

func _on_analytics(res: Variant) -> void:
	if typeof(res) == TYPE_DICTIONARY and not (res as Dictionary).is_empty():
		var d := res as Dictionary
		var enemy_deaths: Dictionary = d.get("deaths_by_enemy", {})
		var obstacle_deaths: Dictionary = d.get("deaths_by_obstacle", {})
		if int(enemy_deaths.get("tax", 0)) > 3:
			tax_speed_scale = 0.85
		if int(obstacle_deaths.get("boulder", 0)) > 2:
			boulder_warning = true
		if float(d.get("avg_completion_time", 0)) > 300.0:
			extra_checkpoint = true
		if int(d.get("retry_count", 0)) > 10:
			hint_leaf = true
	loaded = true
	tuning_ready.emit()
