extends RefCounted
class_name PortalTravel
## Static travel bookkeeping for the Protocol Portals loop.
##
## The ladder asks this class to descend; the study room asks it to ascend.
## Nothing here draws, mints or networks: it only remembers where the player
## came from, hands the study room its PortalSession and calls SceneRouter.
##
## SceneRouter is an autoload, so it is reached through Engine.get_main_loop()
## instead of a direct node path (static functions have no scene tree).

const SignalsScript := preload("res://src/protocol_portals/PortalSignals.gd")
const PortalSessionScript := preload("res://src/protocol_portals/PortalSession.gd")

const ROOM_SMOKE: String = "res://src/protocol_portals/rooms/smoke/ReadingRing.tscn"
const ROOM_DIAMONDS: String = "res://src/protocol_portals/rooms/diamonds/PressureStudy.tscn"
const ROOM_GOLD: String = "res://src/protocol_portals/rooms/gold/ClaimOffice.tscn"

## Autoload node name that owns load_scene(path, transition).
const ROUTER_NODE: String = "SceneRouter"

## True while the player is inside a study room and owes the level a return.
static var pending_return: bool = false
## Scene the player came from (the level that owns the ladder).
static var return_scene: String = ""
## World x of the ladder, kept for debugging / future spawn offsets.
static var return_x: float = 0.0
## Protocol of the run in flight ("smoke" | "diamonds" | "gold").
static var protocol: String = ""
## Stage id of the run in flight.
static var stage_id: int = 0
## The single live PortalSession, or null when no run is in flight.
## Typed RefCounted so this file never depends on a global class name being
## registered (it is also preloaded by headless tests).
static var session: RefCounted = null


## Room scene that belongs to a protocol. Unknown protocols fall back to smoke.
static func room_scene_for(protocol_id: String) -> String:
    match protocol_id.to_lower():
        "diamonds":
            return ROOM_DIAMONDS
        "gold":
            return ROOM_GOLD
        _:
            return ROOM_SMOKE


## Called by the ladder when the player presses "interact" inside the shaft.
## Stores the return point, opens the session, walks WORLD -> DESCENT and loads
## the matching study room with a fade.
static func descend(protocol_id: String, new_stage_id: int, from_scene_path: String, world_x: float) -> void:
    protocol = protocol_id.to_lower()
    stage_id = new_stage_id
    return_scene = from_scene_path
    return_x = world_x
    pending_return = false

    var fresh: RefCounted = PortalSessionScript.begin(stage_id, protocol)
    if fresh != null:
        fresh.call("transition", SignalsScript.State.DESCENT)
    session = fresh

    _load(room_scene_for(protocol))


## Called by the study room (ascent shaft / "CLIMB BACK").
## Walks the session up to WORLD when that edge is legal — a player leaving
## early from STUDY_CHOICE simply does not get the state change, they still
## get to go home.
static func ascend() -> void:
    if session != null:
        # ASCENT is only reachable from RESULT; anything else just leaves.
        if bool(session.call("transition", SignalsScript.State.ASCENT)):
            session.call("transition", SignalsScript.State.WORLD)

    pending_return = true
    if return_scene.is_empty():
        return
    _load(return_scene)


## True exactly once, when the pending return belongs to this scene/protocol.
## The ladder calls this right after its floor snap to place the player.
static func consume_return(scene_path: String, protocol_id: String) -> bool:
    if not pending_return:
        return false
    if not return_scene.is_empty() and return_scene != scene_path:
        return false
    if not protocol.is_empty() and protocol_id.to_lower() != protocol:
        return false
    pending_return = false
    return true


# ---- SceneRouter plumbing ---------------------------------------------------

## Loads a scene through the SceneRouter autoload. FADE is the default
## transition, which is exactly what a portal wants.
static func _load(path: String) -> void:
    if path.is_empty():
        return
    var router: Node = _router()
    if router == null:
        push_warning("PortalTravel: SceneRouter autoload not found, cannot load %s" % path)
        return
    router.call("load_scene", path)


## Resolves the SceneRouter autoload from the running SceneTree, or null when
## there is no tree (headless unit scripts) or no such autoload.
static func _router() -> Node:
    var loop: MainLoop = Engine.get_main_loop()
    if loop == null or not (loop is SceneTree):
        return null
    var tree: SceneTree = loop as SceneTree
    if tree.root == null:
        return null
    return tree.root.get_node_or_null(ROUTER_NODE)
