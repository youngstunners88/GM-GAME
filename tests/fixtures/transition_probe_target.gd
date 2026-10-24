extends Node
## Fixture destination for the hand-off tests (tests/transition_director_test.gd, tests/ep2_theme_handoff_test.gd,
## tests/touch_scene_swap_cleanup_test.gd). It records what a freshly swapped-in scene SEES while the
## TransitionDirector still holds the cover: whether the director says "holding", whether the tree is paused, how many
## frames a pausable node and an ALWAYS node were processed, and what TouchActions held when it was built.
## With `spawn_runner` set it also builds a real first-leg RunnerGraybox in _ready, exactly like Ep2SessionRoot does.

static var spawn_runner: bool = false
## The most recent instance (the tests read its counters).
static var last: Node = null

var ready_holding: bool = false
var ready_paused: bool = false
var held_at_ready: int = -1
var pausable_ticks: int = 0
var always_ticks: int = 0
var runner: Node = null


## A node that keeps processing while the tree is paused (like a PROCESS_MODE_ALWAYS autoload or overlay would).
class AlwaysTicker extends Node:
	var ticks: int = 0
	func _init() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
	func _process(_delta: float) -> void:
		ticks += 1


var _always: AlwaysTicker = null


func _ready() -> void:
	last = self
	ready_holding = TransitionDirector.handoff_holding()
	ready_paused = get_tree().paused
	held_at_ready = TouchActions.held_count()
	_always = AlwaysTicker.new()
	add_child(_always)
	if spawn_runner:
		runner = load("res://src/episode2/runner/runner_graybox.tscn").instantiate()
		add_child(runner)
		runner.setup(200.0)


func _process(_delta: float) -> void:
	pausable_ticks += 1
	always_ticks = _always.ticks if _always != null else 0


func always_tick_count() -> int:
	return _always.ticks if _always != null else 0
