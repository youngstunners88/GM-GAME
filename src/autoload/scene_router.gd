extends Node

# Async scene loading with optional transition + memory tracking.
# Uses ResourceLoader's threaded path so the main thread keeps rendering
# the previous scene (or fade) while the next scene loads.

signal load_progress(progress: float)
signal load_finished(scene_path: String)

enum Transition { INSTANT, FADE, SLIDE, SMOKE, DIAMOND }

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

    # ALWAYS restore real time BEFORE a transition.
    #
    # Founder, 2026-08-23 (2nd occurrence): "After big mode on Stage 3 the game
    # is completely frozen while the music continues." Root cause (measured):
    # the hitstop juice in player.gd::_hitstop and axe.gd::_boss_hitstop sets the
    # GLOBAL `Engine.time_scale = 0.05`, then `await`s a short timer and only
    # restores 1.0 on the line AFTER the await. On Stage 3 any boss touch is
    # `GameManager.boss_contact_restart()`, which reloads the level THROUGH this
    # function — so if a hit lands (hitstop starts) and contact fires within the
    # same ~0.06s window, the player/axe node is freed mid-await, its restore
    # line never runs, and `Engine.time_scale` is left pinned at 0.05. It is a
    # global on the Engine, so it SURVIVES the reload: the fresh scene then runs
    # physics/_process at 5% while the audio server (unaffected) plays on —
    # exactly "frozen, but the music continues". blaze_rush.gd already had to
    # defend its own timers against "a stuck Engine.time_scale"; this is the
    # root cause it was working around.
    #
    # Every transition, respawn and boss-restart passes through here, so
    # resetting at the top makes a stranded hitstop self-heal on the next load
    # and never persist into a new scene. It also stops the fade timer below
    # (NOT ignore_time_scale) from running at 5% and stretching 0.3s into 6s.
    Engine.time_scale = 1.0
    # And clear any stranded pause for the same reason (a modal panel freed by a
    # mid-open reload would otherwise leave the tree paused). change_state below
    # already sets paused=false for TRANSITIONING, but making it explicit here
    # documents the invariant: NO global sim state survives a transition.
    get_tree().paused = false

    StateMachine.change_state(StateMachine.State.TRANSITIONING)
    _loading_path = path
    _transition_type = transition_type
    _node_count_before = _count_nodes()
    print("[SceneRouter] Loading %s (nodes before: %d)" % [path, _node_count_before])

    match transition_type:
        Transition.FADE:
            SceneTransition.fade_out()
            await get_tree().create_timer(0.3).timeout
        Transition.SMOKE:
            SceneTransition.wipe_out("smoke")
            await get_tree().create_timer(0.45).timeout
        Transition.DIAMOND:
            SceneTransition.wipe_out("diamond")
            await get_tree().create_timer(0.45).timeout
        _:
            pass

    # Web export: ResourceLoader's threaded path can stall forever (the load
    # starts but never reaches LOADED), leaving the fade overlay on screen.
    # The pck is already in memory on web, so load synchronously instead.
    if OS.has_feature("web"):
        var scene_path := _loading_path
        var err_web := get_tree().change_scene_to_file(scene_path)
        if err_web != OK:
            push_error("SceneRouter: change_scene_to_file failed for %s (err %d)" % [scene_path, err_web])
            # A failed scene change strands the player on a fade overlay — the
            # most player-visible failure this game has.
            ErrorReporter.report("scene_load_failed", {"path": scene_path, "err": err_web, "route": "web"})
            _abort_load()
            return
        await get_tree().process_frame
        # Keep _loading_path set until here so a second load_scene() call
        # cannot race this coroutine through the await window.
        _loading_path = ""
        _play_in_transition()
        print("[SceneRouter] Loaded %s (sync web path)" % scene_path)
        load_finished.emit(scene_path)
        return

    var err := ResourceLoader.load_threaded_request(path)
    if err != OK:
        push_error("SceneRouter: load_threaded_request failed for %s (err %d)" % [path, err])
        ErrorReporter.report("scene_load_failed", {"path": path, "err": err, "route": "threaded_request"})
        _abort_load()
        return
    set_process(true)

## A load failed and the scene did NOT change: lift the fade overlay and put
## the StateMachine back where it was, otherwise the session soft-locks in
## TRANSITIONING with the player frozen and no recovery UI.
func _abort_load() -> void:
    _loading_path = ""
    set_process(false)
    _play_in_transition()
    StateMachine.recover_from_transition()

## Reveal the freshly loaded (or restored) scene with whatever transition
## covered it — wipes reverse their dissolve, everything else lifts the fade.
func _play_in_transition() -> void:
    match _transition_type:
        Transition.SMOKE, Transition.DIAMOND:
            SceneTransition.wipe_in()
        _:
            SceneTransition.fade_in()

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
            ErrorReporter.report("scene_load_failed", {"path": _loading_path, "route": "threaded_status"})
            _abort_load()

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

    _play_in_transition()

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
