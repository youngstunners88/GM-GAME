extends Node

# Async scene loading with optional transition + memory tracking.
# Uses ResourceLoader's threaded path so the main thread keeps rendering
# the previous scene (or fade) while the next scene loads.

signal load_progress(progress: float)
signal load_finished(scene_path: String)

enum Transition { INSTANT, FADE, SLIDE }

var _loading_path: String = ""
var _transition_type: Transition = Transition.INSTANT
var _node_count_before: int = 0

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    set_process(false)

func load_scene(path: String, transition_type: Transition = Transition.FADE) -> void:
    if _loading_path != "":
        push_warning("SceneRouter: load already in progress for %s" % _loading_path)
        return

    StateMachine.change_state(StateMachine.State.TRANSITIONING)
    _loading_path = path
    _transition_type = transition_type
    _node_count_before = _count_nodes()
    print("[SceneRouter] Loading %s (nodes before: %d)" % [path, _node_count_before])

    if transition_type == Transition.FADE and SceneTransition.has_method("fade_out"):
        SceneTransition.fade_out()
        await get_tree().create_timer(0.3).timeout

    var err := ResourceLoader.load_threaded_request(path)
    if err != OK:
        push_error("SceneRouter: load_threaded_request failed for %s (err %d)" % [path, err])
        _loading_path = ""
        return
    set_process(true)

func _process(_delta: float) -> void:
    if _loading_path == "":
        set_process(false)
        return
    var progress: Array = []
    var status := ResourceLoader.load_threaded_get_status(_loading_path, progress)
    match status:
        ResourceLoader.THREAD_LOAD_IN_PROGRESS:
            if not progress.is_empty():
                load_progress.emit(progress[0])
        ResourceLoader.THREAD_LOAD_LOADED:
            _finalise_load()
        ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
            push_error("SceneRouter: failed to load %s" % _loading_path)
            _loading_path = ""
            set_process(false)

func _finalise_load() -> void:
    var packed: PackedScene = ResourceLoader.load_threaded_get(_loading_path)
    var path := _loading_path
    _loading_path = ""
    set_process(false)

    # Auto-cleanup previous scene
    var current := get_tree().current_scene
    if current != null:
        current.queue_free()

    var inst := packed.instantiate()
    get_tree().root.add_child(inst)
    get_tree().current_scene = inst

    if _transition_type == Transition.FADE and SceneTransition.has_method("fade_in"):
        SceneTransition.fade_in()

    var nodes_after := _count_nodes()
    print("[SceneRouter] Loaded %s (nodes after: %d, delta: %+d)" % [
        path, nodes_after, nodes_after - _node_count_before
    ])
    load_finished.emit(path)

func _count_nodes() -> int:
    return get_tree().root.get_child_count() + _count_descendants(get_tree().root)

func _count_descendants(n: Node) -> int:
    var total := 0
    for child in n.get_children():
        total += 1 + _count_descendants(child)
    return total
