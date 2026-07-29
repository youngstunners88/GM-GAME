extends EnemyBase
## Tax Collector — patrols a platform, then actively pursues Lil Blunt when he
## comes within detection range, jumping gaps and up to higher ledges.
##
## FAIRNESS CONTRACT (the same rule the v1.2 shooter drones follow): the enemy
## never lunges without warning. Entering ALERT freezes it for a beat, facing
## the player, before PURSUE begins — so the player always gets a frame to
## react instead of being ambushed by a sudden speed change.

enum State { PATROL, ALERT, PURSUE }

@export var patrol_speed: float = 60.0
@export var patrol_distance: float = 200.0
## Pursuit must outpace patrol or closing distance reads as "nothing changed".
@export var pursue_speed: float = 105.0
@export var detect_x: float = 200.0
@export var detect_y: float = 100.0
## Telegraph before the chase starts. Deliberately generous.
@export var alert_time: float = 0.5
## Give up only after the player has been clear this long. Without this
## hysteresis the enemy oscillates between PURSUE and PATROL on the boundary.
@export var lose_interest_time: float = 3.0
@export var jump_force: float = -430.0
## Widest gap worth attempting. Beyond this the jump cannot land, and trying
## would launch the enemy into the pit.
## Kimi re-audit: derived from this file's own kinematics, not picked by eye.
## jump_force=-430 / GRAVITY=980 -> ~0.439s to apex, ~0.878s total airtime at
## equal launch/land height; at pursue_speed=105 that's ~92px of horizontal
## travel — the OLD 150px guard let the enemy commit to jumps it could not
## physically complete. 80px keeps margin for landing on a RAISED ledge (which
## takes longer to reach and therefore covers LESS horizontal distance for the
## same launch, not more) and for DifficultyManager's slowed pursue_speed.
@export var max_jump_gap: float = 80.0

const GRAVITY: float = 980.0

var start_x: float = 0.0
var moving_right: bool = true
var state: State = State.PATROL

var _alert_timer: float = 0.0
var _out_of_range_timer: float = 0.0
var _jump_cooldown: float = 0.0
## Re-target on a timer rather than every frame — see _physics_process.
var _retarget_timer: float = 0.0
var _player: Node2D = null

func _ready() -> void:
    super._ready()
    start_x = global_position.x
    analytics_id = "tax"
    # Invisible adaptive difficulty (task #23): players who die to Tax
    # Collectors repeatedly get 15% slower patrols. No UI, no announcement.
    patrol_speed *= DifficultyManager.tax_speed_scale
    pursue_speed *= DifficultyManager.tax_speed_scale

func _physics_process(delta: float) -> void:
    # Kimi audit: don't let gravity accumulate unbounded while grounded.
    if is_on_floor() and velocity.y > 0.0:
        velocity.y = 0.0
    if is_dead:
        return

    _jump_cooldown -= delta
    # Player lookup is a scene-tree group search. Doing it every frame for
    # every Tax Collector in the level is wasted work; 0.2s is far finer than
    # human reaction time, so the AI loses nothing perceptible.
    _retarget_timer -= delta
    if _retarget_timer <= 0.0:
        _retarget_timer = 0.2
        _player = get_tree().get_first_node_in_group("player")

    velocity.y += GRAVITY * delta

    match state:
        State.PATROL:
            _do_patrol()
            if _player_in_range():
                state = State.ALERT
                _alert_timer = alert_time
                velocity.x = 0.0
                _face_player()
                AudioManager.play_sfx_at("tax_alert", global_position)
        State.ALERT:
            # Frozen tell: stand still, facing the player, before committing.
            # Kimi re-audit: this used to bail back to PATROL the instant the
            # player left range mid-telegraph, which re-armed a fresh
            # alert_time on the very next re-entry — a player hovering at the
            # detection edge could hold the enemy in perpetual telegraph and
            # it would never reach PURSUE. The telegraph now always completes
            # once triggered; PURSUE's own lose_interest_time hysteresis
            # (already the sole disengage path everywhere else) handles a
            # player who left before the telegraph even finished.
            velocity.x = 0.0
            _alert_timer -= delta
            if _alert_timer <= 0.0:
                state = State.PURSUE
                _out_of_range_timer = 0.0
        State.PURSUE:
            _do_pursue(delta)

    move_and_slide()

func _do_patrol() -> void:
    velocity.x = patrol_speed if moving_right else -patrol_speed
    if global_position.x > start_x + patrol_distance:
        moving_right = false
    elif global_position.x < start_x - patrol_distance:
        moving_right = true
    if is_on_wall():
        moving_right = not moving_right
    _face(moving_right)

func _do_pursue(delta: float) -> void:
    if _player == null or not is_instance_valid(_player):
        state = State.PATROL
        # Kimi re-audit: the timeout exit below re-anchors so the enemy
        # doesn't march back to spawn and look like it "forgot" the chase.
        # This exit (player freed/removed mid-pursuit) skipped that same
        # re-anchor — inconsistent for the same disengage outcome.
        start_x = global_position.x
        return

    if _player_in_range():
        _out_of_range_timer = 0.0
    else:
        _out_of_range_timer += delta
        if _out_of_range_timer >= lose_interest_time:
            state = State.PATROL
            # Re-anchor the patrol to wherever the chase ended. Otherwise the
            # enemy marches all the way back to its original spawn point and
            # looks like it forgot what it was doing.
            start_x = global_position.x
            return

    var dx := _player.global_position.x - global_position.x
    var toward := signf(dx)
    velocity.x = toward * pursue_speed
    _face(toward > 0.0)

    # Jump when the player is meaningfully above us, or when a wall blocks the
    # chase. Gated on max_jump_gap so the enemy never commits to a leap it
    # cannot land — the "don't overshoot into the pit" requirement.
    var dy := _player.global_position.y - global_position.y
    if is_on_floor() and _jump_cooldown <= 0.0:
        var wants_up := dy < -40.0
        var blocked := is_on_wall()
        if (wants_up or blocked) and absf(dx) <= max_jump_gap:
            velocity.y = jump_force
            _jump_cooldown = 0.8

func _player_in_range() -> bool:
    if _player == null or not is_instance_valid(_player):
        return false
    var d := _player.global_position - global_position
    return absf(d.x) <= detect_x and absf(d.y) <= detect_y

func _face_player() -> void:
    if _player != null and is_instance_valid(_player):
        _face(_player.global_position.x > global_position.x)

## Single flip owner. `sprite` is EnemyBase's CanvasItem; only scale.x is
## touched — deliberately NOT combined with flip_h, because two mirrors
## compose to identity (the bug that made the player always face right).
func _face(face_right: bool) -> void:
    if sprite:
        sprite.scale.x = 1.0 if face_right else -1.0
