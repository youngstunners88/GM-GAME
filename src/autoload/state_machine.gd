extends Node

# Global game state machine. Replaces scattered booleans like
# is_dead, boss_spawned, game_over with a single source of truth.

signal state_changed(from_state: String, to_state: String)

enum State { MENU, PLAYING, PAUSED, GAME_OVER, LEVEL_COMPLETE, TRANSITIONING }

var _current: State = State.MENU
var _previous: State = State.MENU

# Allowed transitions. Anything not listed must go through TRANSITIONING.
const _ALLOWED: Dictionary = {
    State.MENU: [State.TRANSITIONING],
    State.PLAYING: [State.PAUSED, State.GAME_OVER, State.LEVEL_COMPLETE, State.TRANSITIONING],
    State.PAUSED: [State.PLAYING, State.TRANSITIONING],
    State.GAME_OVER: [State.PLAYING, State.TRANSITIONING],
    State.LEVEL_COMPLETE: [State.TRANSITIONING],
    State.TRANSITIONING: [State.MENU, State.PLAYING, State.GAME_OVER, State.LEVEL_COMPLETE],
}

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS

func can_transition(from: State, to: State) -> bool:
    if from == to:
        return false
    return to in _ALLOWED.get(from, [])

## Recovery hatch for failed scene loads ONLY: if we are stuck in
## TRANSITIONING (the scene never changed), revert to the state we came
## from so gameplay/menus keep working instead of soft-locking.
func recover_from_transition() -> void:
    if _current != State.TRANSITIONING:
        return
    var from := _current
    _current = _previous
    _apply_side_effects(_current)
    state_changed.emit(State.keys()[from], State.keys()[_current])

func change_state(new_state: State) -> bool:
    if not can_transition(_current, new_state):
        push_warning("Invalid state transition: %s → %s" % [
            State.keys()[_current], State.keys()[new_state]
        ])
        return false
    _previous = _current
    _current = new_state
    _apply_side_effects(new_state)
    state_changed.emit(State.keys()[_previous], State.keys()[_current])
    return true

func _apply_side_effects(state: State) -> void:
    # Centralised tree-pause logic. Game freezes only in PAUSED.
    get_tree().paused = (state == State.PAUSED)

func get_current_state() -> String:
    return State.keys()[_current]

func get_state_enum() -> State:
    return _current

func is_state(state: State) -> bool:
    return _current == state

func is_playing() -> bool:
    return _current == State.PLAYING

func is_paused() -> bool:
    return _current == State.PAUSED

func is_dead() -> bool:
    return _current == State.GAME_OVER
