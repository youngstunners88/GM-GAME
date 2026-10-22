extends Node

# Async scene loading with optional transition + memory tracking.
# Uses ResourceLoader's threaded path so the main thread keeps rendering
# the previous scene (or fade) while the next scene loads.

signal load_progress(progress: float)
signal load_finished(scene_path: String)
## Emitted when the incoming scene is fully REVEALED: the wipe-in / fade-in that
## follows a load_scene() has finished (immediately, for a transition with no
## cover). A scene that must not start its action under a half-covered screen
## (Blaze Rush's armed start) waits for this; it never fires for a load that a
## newer load_scene() superseded. Callers of _play_in_transition do NOT await it,
## so _abort_load keeps its order (reveal started, THEN recover_from_transition).
signal revealed

enum Transition { INSTANT, FADE, SLIDE, SMOKE, DIAMOND, GOLD }

## Default length of a wipe out / in (SMOKE, DIAMOND, GOLD).
const DEFAULT_WIPE_SECONDS: float = 0.45
## Blaze Rush's shorter wipe. Used ONLY by callers that pass
## blaze_wipe_seconds() next to blaze_transition_for_level(); the global default
## above is never changed (boss-3 / Episode 2 hand-offs, vault doors etc. keep 0.45).
const BLAZE_WIPE_SECONDS: float = 0.30

## Length of the wipe of the load in flight (and of its reveal).
var _wipe_seconds: float = DEFAULT_WIPE_SECONDS
## False from load_scene() until the reveal that follows it has finished.
var _revealed: bool = true
## Bumped by every load_scene(); a reveal that finds a newer load in flight stays quiet.
var _load_gen: int = 0

var _loading_path: String = ""
var _transition_type: Transition = Transition.INSTANT
var _node_count_before: int = 0

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    set_process(false)

## Which wipe pattern matches a campaign realm's own palette. Shared by every
## Blaze Rush entry/exit so the dissolve never clashes with the scene it's
## covering (founder, 2026-09-17: the SMOKE pattern's green/purple tint,
## hardcoded for all three realms, flashed over the cyan Crystal Caverns and
## the amber Gold Rush canyon alike — read as a stray green/purple blemish
## rather than a themed transition). L1 is the actual Smoke Realm, so SMOKE
## is correct there, not a fallback.
static func blaze_transition_for_level(level_index: int) -> Transition:
    match level_index:
        2:
            return Transition.DIAMOND
        3:
            return Transition.GOLD
        _:
            return Transition.SMOKE

## How long a Blaze Rush wipe lasts (0.30 s each way instead of 0.45 s: the secret
## mode is the FAST one and a phone player is in a short-session loop). Pass it as
## load_scene()'s third argument NEXT TO blaze_transition_for_level(); nothing else
## shortens a wipe.
static func blaze_wipe_seconds() -> float:
    return BLAZE_WIPE_SECONDS

## True when no load is mid-flight and the last reveal has finished.
func is_revealed() -> bool:
    return _revealed

## `wipe_seconds` <= 0 (the default) keeps DEFAULT_WIPE_SECONDS; it only matters
## for the SMOKE / DIAMOND / GOLD wipes.
func load_scene(path: String, transition_type: Transition = Transition.FADE, wipe_seconds: float = -1.0) -> void:
    if _loading_path != "":
        push_warning("SceneRouter: load already in progress for %s" % _loading_path)
        return

    # EPISODE 2 is staged by the TransitionDirector, never by a plain fade: the menu button and the ?ep2=1 boot used to
    # fade to black, then compile ep2_entry + six chambers in ONE frame and start the fade-in on top of the first-draw
    # stall (black, a freeze, a pop). The director gives it a dp-sized wordless card, a budgeted warm-up, a settle and a
    # reveal, exactly like the boss-3 hand-off. Diverted BEFORE _loading_path is set, so this guard can never be left set.
    if _divert_to_director(path):
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
    _wipe_seconds = wipe_seconds if wipe_seconds > 0.0 else DEFAULT_WIPE_SECONDS
    _revealed = false
    _load_gen += 1
    _node_count_before = _count_nodes()
    print("[SceneRouter] Loading %s (nodes before: %d)" % [path, _node_count_before])

    match transition_type:
        Transition.FADE:
            SceneTransition.fade_out()
            await get_tree().create_timer(0.3).timeout
        Transition.SMOKE:
            SceneTransition.wipe_out("smoke", _wipe_seconds)
            await get_tree().create_timer(_wipe_seconds).timeout
        Transition.DIAMOND:
            SceneTransition.wipe_out("diamond", _wipe_seconds)
            await get_tree().create_timer(_wipe_seconds).timeout
        Transition.GOLD:
            SceneTransition.wipe_out("gold", _wipe_seconds)
            await get_tree().create_timer(_wipe_seconds).timeout
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

## True when the TransitionDirector took this load (Episode 2 only). A hand-off already in flight swallows the
## duplicate request (a second tap on the EPISODE 2 button). A missing scene falls through to the normal route, whose
## failure handling (_abort_load) is the established one.
func _divert_to_director(path: String) -> bool:
    if path != GameManager.EPISODE2_SCENE or not ResourceLoader.exists(path):
        return false
    if TransitionDirector.is_busy():
        return true
    TransitionDirector.go(path)
    return true

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
    # Captured BEFORE the first await: a newer load_scene() may reassign these
    # while this reveal is still running.
    var kind: Transition = _transition_type
    var seconds: float = _wipe_seconds
    var gen: int = _load_gen
    match kind:
        Transition.SMOKE, Transition.DIAMOND, Transition.GOLD:
            await SceneTransition.wipe_in(seconds)
        Transition.FADE:
            await SceneTransition.fade_in()
        _:
            # No cover to lift (INSTANT / SLIDE): the legacy fade_in on a clear
            # overlay, and the scene is revealed right now.
            SceneTransition.fade_in()
    if gen != _load_gen:
        return
    _revealed = true
    revealed.emit()

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
