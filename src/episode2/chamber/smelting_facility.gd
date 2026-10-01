class_name SmeltingFacilityChamber
extends Node3D
## Chamber 0 — THE SMELTING FACILITY. The Inferno Bull meeting and the
## Winchester 1886 hand-off.
##
## Spec: artifacts/episode2-gold-mine/chambers/00_SMELTING_FACILITY.md
## Character: artifacts/episode2-gold-mine/spec/INFERNO_BULL_CHARACTER_PROFILE.md
## Staging reference: references/inferno_bull_smelting.jpeg — the Bull seated
## among molten gold, whiskey in hand, cigar lit, pour-crucibles working behind
## him. That image is the blocking for this scene, not a mood board.
##
## THIS IS NOT A PROTOCOL CHAMBER. It mints, stakes and claims nothing; the
## economy starts at Fort Knox. It is a story set-piece that turns the episode
## from a runner into a Wild West shooter, and it is deliberately the warmest,
## brightest, safest space the player has been in since entering the mine —
## a breather placed between two high-intensity stretches.
##
## WHY IT IMPLEMENTS THE MINER-SHAFT INTERFACE
## `ep2_session_root.gd` instantiates a chamber, calls
## `setup(gold_principal, bears, diamonds_paid)`, connects `chamber_cleared` /
## `chamber_failed`, drives it with `step(delta)`, and routes player verbs
## through `start_rig` / `shoot` / `take_cover` / `leave_cover` /
## `early_claim`. This scene answers that whole interface so it is a drop-in
## sibling of MinerShaftChamber — the session root's guards, idempotency and
## commit boundary keep working untouched. Where a verb has no meaning here it
## says so in one line rather than silently doing nothing.

## Emitted once when the beat sheet completes. Carries zero economy — the
## session root's commit path handles a 0/0 result as a no-op, which is exactly
## what a story chamber should contribute.
signal chamber_cleared(result: Dictionary)
## Never emitted. There is no fail state in Chamber 0 — no enemies, no timer,
## no resource. Declared because the session root connects it unconditionally,
## and a missing signal is a hard error at connect time.
signal chamber_failed
## Beat transitions, for the HUD and for tests.
signal beat_changed(beat: int)
## A voice line started. Carries the manifest id (e.g. "vo_bull_take_rifle").
signal line_spoken(line_id: String)
## The Winchester changed hands. The permanent unlock for chamber sections.
signal weapon_granted(weapon_id: String)
## Gear handed over (the miner's helmet, founder 2026-09-30: "this is where Lil Blunt now gets his Gun and helmet").
signal gear_granted(gear_id: String)

enum Beat {
	CINEMATIC,    # the cliff-jump film (founder 2026-09-30): the cart flies, he jumps, rolls, hits his head
	WAKE,         # he comes to on the Bull's floor; the Bull nurses him with whiskey
	ARRIVAL,      # cart brakes into heat and light; control hands to walking
	APPROACH,     # cross the floor to the Bull
	DRINK,        # the shared drink and cigar — the character beat
	SIZING,       # he takes your measure
	HANDOFF,      # the Winchester 1886
	HELMET,       # ...and a miner's helmet: "that skull of yours ain't bulletproof"
	VERB_TEACH,   # shoot the empty mold rack; aim/fire/cover
	TERMS,        # "I don't do sidekicks."
	PROMISE,      # the Smoke Lounge
	EXIT,         # he falls in; walk out toward Fort Knox
	DONE,
}

# --- Layout (metres). Mirrors the reference staging: the player enters from the
# runner tunnel at -Z, the Bull is seated among the crucibles at +Z.
const ENTRY_POSITION := Vector3(0.0, 0.0, -8.0)
const BULL_POSITION := Vector3(1.6, 0.0, 6.0)
const MOLD_RACK_POSITION := Vector3(-4.2, 0.0, 2.0)
const EXIT_POSITION := Vector3(0.0, 0.0, 15.0)
## How close you must be for the meeting to start. Generous — this is a
## breather, not a precision-platforming beat.
const TALK_RANGE := 3.2
const WALK_SPEED := 3.4

# --- Free roam (founder 2026-10-01: "up = forward, back = backwards, left = left, right = right, space = jump,
# the mouse lets him view different directions"). Movement is relative to where the camera looks.
const RUN_SPEED := 5.6
const JUMP_VELOCITY := 5.4
const GRAVITY := 15.0
const MAX_AIR_JUMPS := 1              # Lil Blunt's double jump
const LOOK_SENSITIVITY := 0.0032      # radians per pixel of mouse travel
const LOOK_PITCH_MIN := -0.85
const LOOK_PITCH_MAX := 0.45
const CAM_DISTANCE := 3.9
const CAM_TARGET_HEIGHT := 1.45
## Where Lil Blunt stands for the scripted hand-overs (the camera cuts to CAM_HAND, so the snap is invisible).
const HAND_MARK := Vector3(-0.3, 0.0, 5.0)
## Room bounds for walking, inside the timber alcove walls.
const ROOM_X := 6.3

# --- Verb teach ---------------------------------------------------------------
## Empty casting molds on a rack. A SAFE target: per the spec's open question,
## Chamber 0 has no live enemies — the gun's first real use should have stakes,
## and those stakes belong on the approach to Fort Knox.
const MOLD_TARGETS := 3
const WINCHESTER_ID := "winchester_1886"
const HELMET_ID := "miner_helmet"
## The wake-up exchange: Lil Blunt's groggy line, then the Bull's whiskey line (measured clip lengths).
const WAKE_LINES := [{"id": "vo_lb_wake", "hold": 2.40}, {"id": "vo_bull_wake", "hold": 12.80}]
## Where he comes to: on the floor at the Bull's boots (inside TALK_RANGE, so the meeting follows).
const WAKE_POSITION := Vector3(0.4, 0.0, 3.6)
const FILM_OFFSET := Vector3(4000.0, 0.0, 0.0)   # the film set lives far from the room: no shared light, no overlap
const COMPANION_ID := "inferno_bull"

## Beat → the Bull's line, and how long to hold before the beat can advance.
## Hold times are the MEASURED durations of the committed clips (see
## INFERNO_BULL_CHARACTER_PROFILE.md §5), so a line is never cut off by an
## impatient player mashing interact.
const BEAT_LINES := {
	Beat.DRINK: {"id": "vo_bull_made_it", "hold": 3.58},
	Beat.HANDOFF: {"id": "vo_bull_take_rifle", "hold": 5.80},
	Beat.HELMET: {"id": "vo_bull_helmet", "hold": 6.71},
	Beat.TERMS: {"id": "vo_bull_no_sidekicks", "hold": 3.99},
	Beat.PROMISE: {"id": "vo_bull_smoke_lounge", "hold": 5.02},
	Beat.EXIT: {"id": "vo_bull_still_standing", "hold": 7.76},
}

# --- Live state ----------------------------------------------------------------
var _beat: int = Beat.ARRIVAL
var _running: bool = false
var _resolved: bool = false          # guards double-resolve, same rail as the shaft
var _player_pos: Vector3 = ENTRY_POSITION
var _hold: float = 0.0               # seconds left on the current line
var _elapsed: float = 0.0
var _has_winchester: bool = false
var _molds_left: int = MOLD_TARGETS
var _in_cover: bool = false
var _move_input: Vector2 = Vector2.ZERO   # x = strafe right, y = forward (relative to the camera's look)
var _run_input: bool = false
var _look_yaw: float = 0.0            # 0 = looking down +Z, toward the Bull and Fort Knox
var _look_pitch: float = -0.22
var _player_yaw: float = 0.0          # Lil Blunt's facing (0 = +Z)
var _vel_y: float = 0.0
var _air_jumps: int = 0
var _moving: bool = false
var _blockers: Array = []             # [Vector2 centre (x, z), radius] the player cannot walk through
var _cauldron_spots: Array = []
## Play the cliff-jump film + wake-up before the meeting. The game always does; the beat-sheet test turns
## it off to drive the conversation on its own (tests/ep2_cinematic_test.gd covers the film).
var intro_film: bool = true
var _film: CliffJumpCinematic = null
var _wake_i: int = 0
var _has_helmet: bool = false
var _helmet_node: Node3D = null
var _player_skel: Skeleton3D = null
var _player_pose: RunnerArmRest = null
## Set dressing handles + the procedural performance (see _animate). The Bull model is a statue (no skeleton),
## so his acting is whole-body: breathing, weight shift, a lean into the hand-off, a raised glass, cigar puffs.
var _dressing: Dictionary = {}
var _bull_pivot: Node3D = null
var _glass_node: Node3D = null
var _cigar_tip: MeshInstance3D = null
var _cigar_smoke: CPUParticles3D = null
var _anim_t: float = 0.0
var _rifle_t: float = 0.0             # seconds since the Winchester hand-off began
var _helmet_t: float = 0.0            # seconds since the helmet hand-over began
var _helmet_on_head: bool = false
var _rifle_in_hands: bool = false
var _hop_y: float = 0.0               # Lil Blunt's little joy-hop after the helmet
var _hop_v: float = 0.0
var _walk_phase: float = 0.0
var _lean: float = 0.0
var _bull_anim: AnimationPlayer = null
var _bull_clip: String = ""
var _bull_model: Node3D = null
var _stand_t: float = -1.0            # seconds since he began to stand (-1 = still seated, 99 = standing)
var _settle: float = 0.0
var _bull_hand: BoneAttachment3D = null
var _bull_left_hand: BoneAttachment3D = null
var _bull_face: BoneAttachment3D = null
var _hero_anim: AnimationPlayer = null
var _hero_clip: String = ""

## Camera framing per beat. A browser capture of the first build showed the
## whole encounter playing at postage-stamp scale from the wide establishing
## shot: the Bull was two horns in the middle distance and the rifle hand-off
## was invisible. This is a CONVERSATION, so the camera pushes in for it and
## pulls back out for the verb teach, which needs the room again.
##
## Each entry is [position, pitch degrees].
## z = -11.0, not -14.0. The floor and side walls span z = -11.5 to 18.5
## (30 m centred at 3.5), so the establishing camera used to sit 2.5 m BEYOND
## the back edge of the room, hanging in the runner tunnel with no shell behind
## it. Caught by the DeepSeek scene-kit pass reading the real code and confirmed
## by arithmetic — see deepseek-scenes/01_smelting_facility/_VERIFICATION.md.
## It survived a browser capture because "the wide shot looks empty" reads as
## graybox rather than as a camera outside the room.
const CAM_WIDE := [Vector3(0.0, 4.2, -11.0), -14.0, 180.0]
const CAM_CLOSE := [Vector3(1.1, 2.3, 1.4), -8.0, 180.0]
## The founder's target framing (design/ep2/inferno_bull_hideout_target.jpg): low, from the left front, so Bull
## and Lil Blunt play the hand-off in three-quarter view with the forge, the Fort Knox door and the poster behind.
const CAM_HAND := [Vector3(0.65, 1.6, 2.0), 0.0, 181.0]
const CAM_TEACH := [Vector3(-1.0, 3.2, -3.0), -12.0, 180.0]
## Coming to: high and to the side, so he is IN frame on the floor with the Bull standing over him.
const CAM_WAKE := [Vector3(2.1, 2.7, 0.4), -26.0, 180.0]
const CAM_LERP := 1.8          # units/sec — a push-in, not a snap

var _visuals: Node3D = null
var _camera: Camera3D = null
var _cam_target_pos: Vector3 = CAM_WIDE[0]
var _cam_target_pitch: float = float(CAM_WIDE[1])
var _cam_target_yaw: float = 180.0
var _player_node: Node3D = null
var _mold_nodes: Array = []
var _rifle_node: Node3D = null

## The same model rigged on Meshy (2026-10-01) with four library clips; origin at his feet, 2.4 m tall.
const BULL_RIG_MODEL := "res://src/episode2/assets/inferno_bull_rigged.glb"
const BULL_RIG_H := 2.4
## Lil Blunt's free walk / run cycles from his Meshy rig (armature-only GLBs, same track paths as the hero).
const HERO_WALK_CLIP := "res://src/episode2/assets/lil_blunt_walking_clip.glb"
const HERO_RUN_CLIP := "res://src/episode2/assets/lil_blunt_running_clip.glb"
const BULL_HEIGHT := 2.9             # he towers over Lil Blunt
const PLAYER_SCALE := 0.95           # Lil Blunt stands ~1.8 m here (the runner scales him up to read at speed)
const HELMET_SCALE := 0.72
const HELMET_LIFT := 0.2             # head bone -> the hat crown, in model metres
const CHANNEL_Z := 10.5
const GOLD_PILE_MODEL := "res://src/episode2/assets/gold_pile.glb"
const MOLTEN_SHADER := "res://src/episode2/art/molten_flow.gdshader"
const ROCK_TEX := "res://src/episode2/assets/textures/tex_rock_wall.jpg"
const GRAVEL_TEX := "res://src/episode2/assets/textures/tex_gravel.jpg"
const TIMBER_TEX := "res://src/episode2/assets/textures/tex_timber.jpg"
const RIFLE_MODEL := "res://src/episode2/assets/winchester_1886.glb"
const CRUCIBLE_MODEL := "res://src/episode2/assets/crucible.glb"
const INGOT_RACK_MODEL := "res://src/episode2/assets/ingot_rack.glb"
const WHISKEY_MODEL := "res://src/episode2/assets/whiskey_glass.glb"
const LANTERN_MODEL := "res://src/episode2/assets/lantern.glb"
const PLAYER_MODEL := "res://src/episode2/assets/lil_blunt_placeholder.glb"


# --- Session-root interface -----------------------------------------------------

## Called by ep2_session_root with the segment's economy parameters.
##
## All three are ACCEPTED AND IGNORED, on purpose. Chamber 0 carries no
## white-paper mechanic: no GOLD principal to vest, no bears to fight, no
## Diamonds to burn. Taking the arguments keeps this a drop-in sibling of the
## Miner Shaft so the session root needs no special case; ignoring them is
## enforced by `chamber_cleared` reporting a hard 0/0 below.
func setup(_gold_principal: int = 0, _bears: Array = [], _diamonds_paid: int = 0) -> void:
	_beat = Beat.CINEMATIC if intro_film else Beat.ARRIVAL
	_wake_i = 0
	_has_helmet = false
	_helmet_on_head = false
	_rifle_in_hands = false
	_rifle_t = 0.0
	_helmet_t = 0.0
	_hop_y = 0.0
	_hop_v = 0.0
	_lean = 0.0
	_resolved = false
	_running = true
	_player_pos = ENTRY_POSITION
	_hold = 0.0
	_elapsed = 0.0
	_has_winchester = false
	_molds_left = MOLD_TARGETS
	_in_cover = false
	_move_input = Vector2.ZERO
	_run_input = false
	_look_yaw = 0.0
	_look_pitch = -0.22
	_player_yaw = 0.0
	_vel_y = 0.0
	_air_jumps = 0
	_build_visuals()
	_sync_visuals()
	if _beat == Beat.CINEMATIC:
		_start_film()
	beat_changed.emit(_beat)


## The film is a child far away from the room; the room's sun is off while it plays (a directional light
## lights everything, film set included).
func _start_film() -> void:
	_film = CliffJumpCinematic.new()
	_film.name = "CliffJumpFilm"
	_film.position = FILM_OFFSET
	add_child(_film)
	var sun := get_node_or_null("Sun") as DirectionalLight3D
	if sun:
		sun.visible = false
	_film.finished.connect(_on_film_finished, CONNECT_ONE_SHOT)
	_film.start()


func _on_film_finished() -> void:
	var sun := get_node_or_null("Sun") as DirectionalLight3D
	if sun:
		sun.visible = true
	if _camera and is_instance_valid(_camera):
		_camera.make_current()
	if _film and is_instance_valid(_film):
		_film.release(1.8)
	_advance()


func _ready() -> void:
	if not _running:
		# Instantiated without setup() — still show the room rather than a void.
		_build_visuals()
		_sync_visuals()


func _physics_process(delta: float) -> void:
	if _running:
		step(delta)


## Deterministic advance. The headless-test entry point, mirroring
## RunnerGraybox.step() and MinerShaftChamber.step().
func step(delta: float) -> void:
	if not _running or _resolved:
		return
	_elapsed += delta
	if _hold > 0.0:
		_hold = maxf(0.0, _hold - delta)

	if _beat == Beat.CINEMATIC:
		if _film and is_instance_valid(_film):
			_film.step(delta)
		return
	if _film and is_instance_valid(_film):
		_film.step(delta)          # the fade back in after the film

	if has_player_control():
		_move_player(delta)
	else:
		_moving = false
	_update_vertical(delta)
	_update_camera(delta)

	match _beat:
		Beat.WAKE:
			if _hold <= 0.0:
				_wake_i += 1
				if _wake_i < WAKE_LINES.size():
					_hold = float(WAKE_LINES[_wake_i]["hold"])
					_speak(str(WAKE_LINES[_wake_i]["id"]))
				else:
					_advance()
		Beat.ARRIVAL:
			# Hands control over as soon as the cart has stopped. One second of
			# stillness so the change of pace registers before the player moves.
			if _elapsed >= 1.0:
				_advance()
		Beat.APPROACH:
			if _distance_to_bull() <= TALK_RANGE:
				_advance()
		Beat.VERB_TEACH:
			if _molds_left <= 0:
				_advance()
		Beat.EXIT:
			# He falls in and you walk out. Resolve on reaching the far door,
			# but never before his parting line has finished.
			if _hold <= 0.0 and _player_pos.z >= EXIT_POSITION.z - 1.0:
				_resolve()
		_:
			pass
	_sync_visuals()
	_animate(delta)


# --- Player verbs ----------------------------------------------------------------
#
# Mapped from the session root's existing chamber verbs so the controls the
# player already learned in the Miner Shaft carry over unchanged:
#   interact (E)  -> start_rig()      -> advance the beat / take the rifle
#   attack (LMB)  -> shoot()          -> fire at a mold during the verb teach
#   move_down (S) -> take_cover()     -> duck behind a crucible
#   dash          -> early_claim()    -> nothing to claim here; refuses loudly

## `interact`. Advances a conversational beat when one is waiting on the player.
## Named start_rig to satisfy the session root's chamber interface; the Miner
## Shaft's rig has no counterpart here. Returns true when it actually advanced.
func start_rig(_payment: String = "") -> bool:
	if not _running or _resolved:
		return false
	if _hold > 0.0:
		return false        # a line is still playing — let the Bull finish
	match _beat:
		Beat.DRINK, Beat.SIZING, Beat.HANDOFF, Beat.HELMET, Beat.TERMS, Beat.PROMISE:
			_advance()
			return true
		_:
			return false


## `attack`. During the verb teach this breaks an empty casting mold; the rest
## of the time the rifle stays down, because there is nothing in this room to
## shoot and pointing a gun at the Bull is not a mechanic.
func shoot() -> bool:
	if not _running or _resolved or not _has_winchester:
		return false
	if _beat != Beat.VERB_TEACH or _molds_left <= 0:
		return false
	_molds_left -= 1
	_sync_visuals()
	return true


func take_cover() -> void:
	_in_cover = true


func leave_cover() -> void:
	_in_cover = false


## No claim exists in Chamber 0. Returns false rather than resolving, so a
## player who dashes out of habit cannot skip the story beat — and so nothing
## can ever route a payout through a chamber that mints nothing.
func early_claim() -> bool:
	return false


## Legacy single-axis walk (tests, older callers): -1 back toward the runner tunnel, +1 forward.
func walk(direction: float) -> void:
	set_move_input(Vector2(0.0, clampf(direction, -1.0, 1.0)))


func walk_stop() -> void:
	set_move_input(Vector2.ZERO)


## Free-roam movement from the session root: x = strafe right (+) / left (-), y = forward (+) / back (-),
## relative to where the camera is looking. `run` = Shift held.
func set_move_input(v: Vector2, run: bool = false) -> void:
	_move_input = v.limit_length(1.0)
	_run_input = run


## Mouse look: `relative` is the mouse motion in pixels (right/down positive).
func look(relative: Vector2) -> void:
	if not has_player_control():
		return
	_look_yaw -= relative.x * LOOK_SENSITIVITY
	_look_pitch = clampf(_look_pitch - relative.y * LOOK_SENSITIVITY, LOOK_PITCH_MIN, LOOK_PITCH_MAX)


## Space. Jump from the floor, or Lil Blunt's double jump in the air. Returns true when he jumped.
func jump() -> bool:
	if not has_player_control():
		return false
	if _player_pos.y <= 0.001:
		_vel_y = JUMP_VELOCITY
		_air_jumps = 0
		return true
	if _air_jumps < MAX_AIR_JUMPS:
		_air_jumps += 1
		_vel_y = JUMP_VELOCITY * 0.85
		return true
	return false


## True whenever the player drives Lil Blunt and the camera. False during the film, while he is out cold, and
## during the two scripted hand-overs (the Winchester, the helmet) - control returns the moment each ends.
func has_player_control() -> bool:
	if not _running or _resolved:
		return false
	if _beat <= Beat.WAKE or _beat >= Beat.DONE:
		return false
	return not _in_scripted_handover()


func _in_scripted_handover() -> bool:
	return (_beat == Beat.HANDOFF and _rifle_t < 3.2) or (_beat == Beat.HELMET and _helmet_t < 3.6)


## The session root captures the mouse for look only while the player has control.
func wants_mouse_capture() -> bool:
	return has_player_control()


func _move_player(delta: float) -> void:
	var fwd := Vector3(sin(_look_yaw), 0.0, cos(_look_yaw))
	var right := Vector3(-fwd.z, 0.0, fwd.x)          # screen-right for a camera looking along `fwd`
	var wish: Vector3 = fwd * _move_input.y + right * _move_input.x
	if wish.length_squared() > 1.0:
		wish = wish.normalized()
	_moving = wish.length_squared() > 0.0025
	if not _moving:
		return
	var speed: float = RUN_SPEED if _run_input else WALK_SPEED
	var next: Vector3 = _collide(_player_pos + wish * speed * delta)
	_player_pos.x = next.x
	_player_pos.z = next.z
	_player_yaw = lerp_angle(_player_yaw, atan2(wish.x, wish.z), clampf(12.0 * delta, 0.0, 1.0))
	_walk_phase += delta * (13.0 if _run_input else 9.5)


func _update_vertical(delta: float) -> void:
	if _player_pos.y <= 0.0 and _vel_y <= 0.0:
		_player_pos.y = 0.0
		_vel_y = 0.0
		return
	_vel_y -= GRAVITY * delta
	_player_pos.y += _vel_y * delta
	if _player_pos.y <= 0.0:
		_player_pos.y = 0.0
		_vel_y = 0.0
		_air_jumps = 0


## Keep Lil Blunt in the room and out of the props and the molten channel (crossable only on the bridge).
func _collide(p: Vector3) -> Vector3:
	var q := p
	q.z = clampf(q.z, ENTRY_POSITION.z, EXIT_POSITION.z)
	q.x = clampf(q.x, -ROOM_X, ROOM_X)
	if absf(q.z - CHANNEL_Z) < 1.1 and absf(q.x) > 1.0:
		q.z = CHANNEL_Z - 1.1 if _player_pos.z < CHANNEL_Z else CHANNEL_Z + 1.1
	for b in _blockers:
		var c: Vector2 = b[0]
		var r: float = b[1]
		var d := Vector2(q.x - c.x, q.z - c.y)
		if d.length() < r:
			var out: Vector2 = (d.normalized() if d.length_squared() > 1e-6 else Vector2(1.0, 0.0)) * r
			q.x = c.x + out.x
			q.z = c.y + out.y
	return q


# --- Beats -------------------------------------------------------------------------

func _advance() -> void:
	if _beat >= Beat.DONE:
		return
	_beat += 1
	_on_beat_entered(_beat)
	beat_changed.emit(_beat)


func _on_beat_entered(beat: int) -> void:
	if beat == Beat.WAKE:
		# He comes to at the Bull's boots, so the meeting follows straight on.
		_player_pos = WAKE_POSITION
		_wake_i = 0
		_hold = float(WAKE_LINES[0]["hold"])
		_speak(str(WAKE_LINES[0]["id"]))
	if beat == Beat.HANDOFF:
		_has_winchester = true
		weapon_granted.emit(WINCHESTER_ID)
		_to_hand_mark()
	if beat == Beat.HELMET:
		_has_helmet = true
		gear_granted.emit(HELMET_ID)
		_to_hand_mark()
	if BEAT_LINES.has(beat):
		var line: Dictionary = BEAT_LINES[beat]
		_hold = float(line["hold"])
		_speak(str(line["id"]))


## Play one of the Bull's committed ElevenLabs lines.
##
## The voice is an ORIGINAL voice designed and owned by this project
## (`uWE48TmsTuIjyh2ifoNL`), not a stock pick, and all five clips are already
## on disk under src/assets/sounds/voice/. AudioManager is looked up rather
## than assumed so a headless gate can drive this scene with no autoloads.
func _speak(line_id: String) -> void:
	line_spoken.emit(line_id)
	var am: Node = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_voice"):
		am.play_voice(line_id)


func _resolve() -> void:
	if _resolved:
		return
	_resolved = true
	_running = false
	_beat = Beat.DONE
	beat_changed.emit(_beat)
	# HARD ZERO on both economy fields. Chamber 0 is a story beat; the white
	# paper's economy begins at Fort Knox. The session root will run its commit
	# path over this result and correctly move nothing.
	chamber_cleared.emit({
		"story": true,
		"chamber": "smelting_facility",
		"gold_awarded": 0,
		"gold_forfeited": 0,
		"companion": COMPANION_ID,
		"weapon": WINCHESTER_ID,
		"seconds": _elapsed,
	})


## Choose the framing: the player's follow camera whenever he has control (mouse look), the scripted
## shots only while a scripted beat owns the view (waking up, the two hand-overs, the verb-teach intro).
func _update_camera(delta: float) -> void:
	if _camera == null or not is_instance_valid(_camera):
		return
	if has_player_control():
		_follow_camera(delta)
		return
	var want: Array
	match _beat:
		Beat.WAKE:
			want = CAM_WAKE
		Beat.HANDOFF, Beat.HELMET:
			want = CAM_HAND
		Beat.VERB_TEACH:
			want = CAM_TEACH
		_:
			want = CAM_WIDE
	_cam_target_pos = want[0]
	_cam_target_pitch = float(want[1])
	_cam_target_yaw = float(want[2])
	var t: float = clampf(CAM_LERP * delta, 0.0, 1.0)
	_camera.position = _camera.position.lerp(_cam_target_pos, t)
	# Slerp the orientation (Euler lerps spin the long way round after a look_at from the follow camera).
	var goal := Basis.from_euler(Vector3(deg_to_rad(_cam_target_pitch), deg_to_rad(_cam_target_yaw), 0.0))
	_camera.basis = Basis(_camera.basis.orthonormalized().get_rotation_quaternion().slerp(goal.get_rotation_quaternion(), t))


## Third-person camera behind Lil Blunt, orbiting with the mouse, kept inside the room.
func _follow_camera(delta: float) -> void:
	var target: Vector3 = Vector3(_player_pos.x, _player_pos.y + CAM_TARGET_HEIGHT, _player_pos.z)
	var cp: float = cos(_look_pitch)
	var dir := Vector3(sin(_look_yaw) * cp, sin(_look_pitch), cos(_look_yaw) * cp)
	var want: Vector3 = target - dir * CAM_DISTANCE + Vector3(0.0, 0.25, 0.0)
	want.x = clampf(want.x, -(ROOM_X + 0.5), ROOM_X + 0.5)
	want.y = clampf(want.y, 0.5, 5.8)
	want.z = clampf(want.z, ENTRY_POSITION.z - 3.0, 17.0)
	_camera.position = _camera.position.lerp(want, clampf(10.0 * delta, 0.0, 1.0))
	var look_at_p: Vector3 = target + dir * 2.0
	if _camera.position.distance_squared_to(look_at_p) > 1e-4:
		_camera.look_at(look_at_p, Vector3.UP)


func _distance_to_bull() -> float:
	return Vector2(BULL_POSITION.x - _player_pos.x, BULL_POSITION.z - _player_pos.z).length()


## The hand-overs are staged: Lil Blunt steps onto his mark in front of the Bull (the camera cuts, so it is not a
## visible teleport) and stops; control returns when the item is in his hands.
func _to_hand_mark() -> void:
	_player_pos = HAND_MARK
	_vel_y = 0.0
	_move_input = Vector2.ZERO
	_player_yaw = atan2(BULL_POSITION.x - HAND_MARK.x, BULL_POSITION.z - HAND_MARK.z)


# --- Getters (HUD + tests) ---------------------------------------------------------
func get_beat() -> int: return _beat
func get_beat_name() -> String: return Beat.keys()[clampi(_beat, 0, Beat.size() - 1)]
func has_winchester() -> bool: return _has_winchester
func has_helmet() -> bool: return _has_helmet
func get_film() -> CliffJumpCinematic: return _film if _film and is_instance_valid(_film) else null
func get_molds_left() -> int: return _molds_left
func is_resolved() -> bool: return _resolved
func is_running() -> bool: return _running
func is_in_cover() -> bool: return _in_cover
func get_player_z() -> float: return _player_pos.z
func get_line_hold() -> float: return _hold
func get_distance_to_bull() -> float: return _distance_to_bull()
func get_player_position() -> Vector3: return _player_pos
func get_look_yaw() -> float: return _look_yaw
func is_moving() -> bool: return _moving
## Chamber 0 has no health and no fail state. Reported as full so a shared HUD
## does not have to special-case it.
func get_health() -> int: return 3
func get_ammo() -> int: return 8
func get_live_bear_count() -> int: return 0
func get_vest() -> float: return 0.0
func is_rig_started() -> bool: return _has_winchester


# --- Visuals -----------------------------------------------------------------------
#
# Built in code from Ep2Palette + the headless-built GLB props, same as the
# runner. Every prop has a primitive fallback: a GLB that fails to load must
# degrade to a VISIBLE box, never to nothing. That rule exists because Episode 2
# has already shipped a build where hazards were pure data with no mesh.

func _prop(path: String, pos: Vector3, scale: float = 1.0, yaw: float = 0.0) -> Node3D:
	if _visuals == null or not ResourceLoader.exists(path):
		return null
	var packed: PackedScene = load(path)
	if packed == null:
		return null
	var n: Node3D = packed.instantiate()
	n.position = pos
	n.scale = Vector3.ONE * scale
	if yaw != 0.0:
		n.rotate_y(yaw)
	_visuals.add_child(n)
	return n


func _mesh(m: Mesh, mat: StandardMaterial3D, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	_visuals.add_child(mi)
	return mi


func _build_visuals() -> void:
	if _visuals and is_instance_valid(_visuals):
		_visuals.queue_free()
	_visuals = Node3D.new()
	_visuals.name = "Visuals"
	add_child(_visuals)
	_mold_nodes.clear()
	_cauldron_spots.clear()
	_rifle_node = null
	_helmet_node = null
	_apply_art()
	# Founder 2026-09-30: Inferno Bull's environment "is currently shit" - it was grey primitive boxes. Rebuilt
	# as a working cave smelter in the Western-Modern-Warfare grade: textured rock and timber, boulders at the
	# wall base, a channel of molten gold behind the Bull (the room's main light), crucible pours with steam
	# and embers, a furnace mouth, ingot racks and gold, chains from the beams. Same layout constants, so the
	# beat sheet, cameras and tests are untouched.
	var rock: StandardMaterial3D = _tex(ROCK_TEX, Color(0.58, 0.48, 0.40), 0.22)
	var rock_dark: StandardMaterial3D = _tex(ROCK_TEX, Color(0.30, 0.25, 0.21), 0.16)
	var gravel: StandardMaterial3D = _tex(GRAVEL_TEX, Color(0.55, 0.47, 0.40), 0.45)
	var timber: StandardMaterial3D = _tex(TIMBER_TEX, Color(0.78, 0.58, 0.40), 0.6)
	var iron := Ep2Palette.make("iron")

	# --- the cavern: floor, rough walls, roof.
	_box(Vector3(24.0, 0.4, 32.0), Vector3(0.0, -0.2, 3.5), gravel)
	for sx in [-1.0, 1.0]:
		_box(Vector3(2.0, 12.0, 32.0), Vector3(12.0 * sx, 5.6, 3.5), rock)
	_box(Vector3(26.0, 1.2, 32.0), Vector3(0.0, 11.2, 3.5), rock_dark)
	_box(Vector3(24.0, 12.0, 2.0), Vector3(0.0, 5.6, 19.4), rock)
	# Boulders along both walls and the back: no straight box edge reads from any camera.
	var bz: float = -9.0
	while bz < 18.0:
		for side in [-1.0, 1.0]:
			_boulder(Vector3(10.4 * side + 0.6 * sin(bz), 0.0, bz), 2.2 + 1.3 * absf(sin(bz * 0.7)))
			_boulder(Vector3(10.8 * side, 5.0 + 1.5 * sin(bz * 1.3), bz + 1.5), 2.6)
		bz += 3.4
	for bx in [-8.0, -4.5, 4.5, 8.0]:
		_boulder(Vector3(bx, 0.0, 18.2), 2.8)

	# --- timber frames + beams along the room, chains hanging from them.
	var fz: float = -7.5
	while fz < 18.0:
		for sx2 in [-1.0, 1.0]:
			_box(Vector3(0.55, 10.2, 0.55), Vector3(9.4 * sx2, 5.0, fz), timber)
		_box(Vector3(19.4, 0.6, 0.6), Vector3(0.0, 9.9, fz), timber)
		fz += 5.0

	# --- THE MOLTEN CHANNEL: gold running across the room behind the Bull; the room's key light.
	var channel := ShaderMaterial.new()
	channel.shader = load(MOLTEN_SHADER)
	var trench := _box(Vector3(19.0, 0.2, 2.2), Vector3(0.0, 0.02, CHANNEL_Z), rock_dark)
	trench.visible = true
	var melt_mesh := PlaneMesh.new()
	melt_mesh.size = Vector2(18.6, 1.7)
	var melt := MeshInstance3D.new()
	melt.mesh = melt_mesh
	melt.material_override = channel
	melt.position = Vector3(0.0, 0.14, CHANNEL_Z)
	_visuals.add_child(melt)
	for lx in [-6.0, 0.0, 6.0]:
		var cl := OmniLight3D.new()
		cl.light_color = Color(1.0, 0.56, 0.18)
		cl.light_energy = 3.2
		cl.omni_range = 9.5
		cl.position = Vector3(lx, 1.1, CHANNEL_Z)
		_visuals.add_child(cl)
	var channel_embers := _particles(90, 3.5, Color(1.0, 0.6, 0.2), 0.05)
	channel_embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	channel_embers.emission_box_extents = Vector3(9.0, 0.1, 0.8)
	channel_embers.position = Vector3(0.0, 0.3, CHANNEL_Z)
	channel_embers.direction = Vector3.UP
	channel_embers.spread = 20.0
	channel_embers.initial_velocity_min = 0.5
	channel_embers.initial_velocity_max = 1.8
	channel_embers.gravity = Vector3(0.0, 0.3, 0.0)
	channel_embers.preprocess = 3.5
	_visuals.add_child(channel_embers)

	# --- crucibles pouring into the channel, steam rising.
	for spec in [Vector3(-6.5, 0.0, CHANNEL_Z + 2.4), Vector3(6.2, 0.0, CHANNEL_Z + 2.2), Vector3(-1.6, 0.0, CHANNEL_Z + 3.4)]:
		HideoutDressing.add_cauldron(_visuals, spec, channel)
		_cauldron_spots.append(spec)
		# Molten gold pouring from a chain-hung ladle into the cauldron (the target's glowing pour columns).
		var pour := CylinderMesh.new()
		pour.top_radius = 0.09
		pour.bottom_radius = 0.14
		pour.height = 3.2
		var pour_mi := MeshInstance3D.new()
		pour_mi.mesh = pour
		pour_mi.material_override = channel
		pour_mi.position = spec + Vector3(0.25, 2.8, 0.0)
		_visuals.add_child(pour_mi)
		var ladle_iron := _hideout_plain(Color(0.13, 0.11, 0.10))
		var ladle := _box(Vector3(0.9, 0.5, 0.9), spec + Vector3(0.55, 4.6, 0.0), ladle_iron)
		ladle.rotation.z = deg_to_rad(32.0)
		_box(Vector3(0.06, 1.6, 0.06), spec + Vector3(0.7, 5.6, 0.0), ladle_iron)
		var glow := Ep2Palette.make_forge_light()
		glow.position = spec + Vector3(0.0, 2.2, -0.6)
		_visuals.add_child(glow)
		var steam := _particles(26, 3.0, Color(0.75, 0.68, 0.62, 0.22), 1.1)
		steam.position = spec + Vector3(0.0, 1.5, 0.0)
		steam.direction = Vector3.UP
		steam.spread = 18.0
		steam.initial_velocity_min = 0.4
		steam.initial_velocity_max = 1.0
		steam.gravity = Vector3(0.0, 0.25, 0.0)
		steam.scale_amount_min = 0.8
		steam.scale_amount_max = 2.2
		steam.preprocess = 3.0
		_visuals.add_child(steam)

	# --- the furnace in the back wall: a brick mass with a white-hot mouth.
	_box(Vector3(7.0, 6.5, 2.6), Vector3(0.0, 3.25, 17.4), rock_dark)
	var mouth := StandardMaterial3D.new()
	mouth.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mouth.albedo_color = Color(1.0, 0.45, 0.12)
	_box(Vector3(3.2, 2.4, 0.2), Vector3(0.0, 1.9, 16.05), channel)
	var fl := OmniLight3D.new()
	fl.light_color = Color(1.0, 0.6, 0.25)
	fl.light_energy = 4.0
	fl.omni_range = 14.0
	fl.position = Vector3(0.0, 2.0, 14.8)
	_visuals.add_child(fl)

	# --- the gold: ingot racks, piles, crates.
	for spec2 in [Vector3(8.4, 0.0, 4.0), Vector3(-8.4, 0.0, 6.5)]:
		if _prop(INGOT_RACK_MODEL, spec2, 1.2) == null:
			var rm := BoxMesh.new()
			rm.size = Vector3(1.9, 1.5, 0.7)
			_mesh(rm, Ep2Palette.make("gold"), spec2 + Vector3(0, 0.75, 0))
	for gp in [Vector3(7.2, 0.0, 9.5), Vector3(-7.6, 0.0, 1.0), Vector3(4.6, 0.0, 12.6)]:
		_prop(GOLD_PILE_MODEL, gp, 1.3)
	for cp in [Vector3(-7.0, 0.0, -4.5), Vector3(7.4, 0.0, -2.8), Vector3(-6.2, 0.0, 12.8)]:
		_box(Vector3(1.1, 1.0, 1.1), cp + Vector3(0.0, 0.5, 0.0), timber)

	# Lanterns on the frames, a cooler counterpoint to the pours.
	for lz in [-4.0, 2.0, 9.0]:
		for lsx in [-1.0, 1.0]:
			var lamp := Ep2Palette.make_lantern_light()
			lamp.position = Vector3(8.9 * lsx, 3.6, lz)
			_visuals.add_child(lamp)
			var lp: Node3D = _prop(LANTERN_MODEL, Vector3(8.9 * lsx, 3.2, lz), 1.2)
			if lp:
				RunnerView.self_light(lp, 1.1, Color(1.0, 0.72, 0.38))

	_camera = get_node_or_null("Camera3D") as Camera3D
	if _camera:
		_camera.position = CAM_WIDE[0]
		_camera.rotation_degrees = Vector3(float(CAM_WIDE[1]), 180.0, 0.0)

	# --- INFERNO BULL: the founder's "Bull Mine Gunslinger" (Drive, 2026-09-30), standing by his whiskey.
	var bull_key := Ep2Palette.make_forge_light()
	bull_key.light_energy = 3.2
	bull_key.omni_range = 9.0
	bull_key.position = BULL_POSITION + Vector3(-1.8, 2.8, -2.2)
	_visuals.add_child(bull_key)
	# The pivot sits at his feet so a lean rotates him about his boots, not about his belly.
	_bull_pivot = Node3D.new()
	_bull_pivot.name = "BullPivot"
	_bull_pivot.position = BULL_POSITION
	_visuals.add_child(_bull_pivot)
	_bull_anim = null
	_bull_clip = ""
	var bull: Node3D = null
	if ResourceLoader.exists(BULL_RIG_MODEL):
		# Rigged (Meshy, 2026-10-01): origin at his feet.
		bull = (load(BULL_RIG_MODEL) as PackedScene).instantiate() as Node3D
		if bull:
			bull.scale = Vector3.ONE * (BULL_HEIGHT / BULL_RIG_H)
			bull.rotate_y(PI)
			_bull_pivot.add_child(bull)
			_bull_model = bull
			_stand_t = -1.0
			_setup_bull_rig(bull)
			# His seat: a sturdy crate under the Sit_and_Drink hips (0.70 model units -> 0.85 m).
			var seat := _box(Vector3(1.0, 0.66, 0.9), Vector3.ZERO, timber)
			seat.reparent(_bull_pivot, false)
			seat.position = Vector3(0.0, 0.33, 0.18)
			seat.name = "BullSeat"
	if bull:
		RunnerView.self_light(bull, 0.12, Color(1.0, 0.82, 0.62))
	else:
		var bm := BoxMesh.new()
		bm.size = Vector3(1.4, 2.4, 1.0)
		var fb := MeshInstance3D.new()
		fb.mesh = bm
		fb.material_override = Ep2Palette.make("bandit")
		fb.position = Vector3(0, 1.2, 0)
		_bull_pivot.add_child(fb)
	_build_bull_props()
	# His whiskey table: a crate, the glass, the bottle.
	_box(Vector3(0.9, 0.9, 0.9), BULL_POSITION + CRATE_OFFSET + Vector3(0.0, -0.55, -0.3), timber)
	_prop(WHISKEY_MODEL, BULL_POSITION + CRATE_OFFSET + Vector3(0.0, -0.08, -0.3), 1.4)
	var glass_mat := StandardMaterial3D.new()
	glass_mat.albedo_color = Color(0.45, 0.22, 0.06, 0.85)
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat.roughness = 0.08
	glass_mat.metallic_specular = 0.8
	var body := CylinderMesh.new()
	body.top_radius = 0.075
	body.bottom_radius = 0.08
	body.height = 0.26
	_mesh(body, glass_mat, BULL_POSITION + CRATE_OFFSET + Vector3(0.25, 0.03, -0.1))
	var neck := CylinderMesh.new()
	neck.top_radius = 0.022
	neck.bottom_radius = 0.06
	neck.height = 0.16
	_mesh(neck, glass_mat, BULL_POSITION + CRATE_OFFSET + Vector3(0.25, 0.24, -0.1))

	# --- the verb-teach target: a rack of EMPTY casting molds (safe by design; see the spec).
	for i in MOLD_TARGETS:
		var mold := BoxMesh.new()
		mold.size = Vector3(0.7, 0.45, 0.5)
		var mi := _mesh(mold, Ep2Palette.make_unique("iron"),
			MOLD_RACK_POSITION + Vector3(0.0, 1.05, float(i) * 1.1 - 1.1))
		_mold_nodes.append(mi)
	_box(Vector3(1.1, 0.8, 3.6), MOLD_RACK_POSITION + Vector3(0.0, 0.4, 0.0), timber)

	# --- LIL BLUNT: the real hero (not the old primitive), standing in the room, lying when he comes to.
	_player_node = _build_player()
	# The rifle starts on the Bull's crate and moves to the player's hands on hand-off.
	_rifle_node = _prop(RIFLE_MODEL, BULL_POSITION + CRATE_OFFSET, 1.0, PI * 0.5)
	# The helmet waits on the crate too.
	_helmet_node = _build_helmet()
	_helmet_node.position = BULL_POSITION + CRATE_OFFSET + Vector3(-0.25, 0.05, -0.55)
	_visuals.add_child(_helmet_node)

	# --- the hangout: alcove, trophies, armory, Gatling, poster, braziers (see HideoutDressing).
	_dressing = HideoutDressing.build(_visuals)
	_blockers = (_dressing.get("blockers", []) as Array).duplicate()
	_blockers.append([Vector2(BULL_POSITION.x, BULL_POSITION.z), 0.95])
	_blockers.append([Vector2(BULL_POSITION.x + CRATE_OFFSET.x, BULL_POSITION.z + CRATE_OFFSET.z), 0.55])
	for cs in _cauldron_spots:
		_blockers.append([Vector2(cs.x, cs.z), 1.1])
	for mz in [-1.2, 0.0, 1.2]:
		_blockers.append([Vector2(MOLD_RACK_POSITION.x, MOLD_RACK_POSITION.z + mz), 0.7])
	# A plank bridge over the molten channel: the only way across to Fort Knox.
	var bridge := _box(Vector3(2.0, 0.1, 2.8), Vector3(0.0, 0.06, CHANNEL_Z), timber)
	bridge.name = "ChannelBridge"

	# --- the exit toward Fort Knox: a timber doorway in the left wall's end, lit.
	for dsx in [-2.4, 2.4]:
		_box(Vector3(0.5, 5.0, 0.5), Vector3(dsx, 2.5, EXIT_POSITION.z + 1.0), timber)
	_box(Vector3(5.4, 0.5, 0.5), Vector3(0.0, 5.0, EXIT_POSITION.z + 1.0), timber)
	# A brass plate, not the old bright-green bar (it hung across the furnace like a UI element).
	_box(Vector3(3.2, 0.6, 0.15), Vector3(0.0, 4.6, EXIT_POSITION.z + 0.7), Ep2Palette.make("brass"))
	var sign := Label3D.new()
	sign.text = "FORT KNOX"
	sign.font_size = 64
	sign.pixel_size = 0.008
	sign.modulate = Color(0.12, 0.07, 0.03)
	sign.position = Vector3(0.0, 4.6, EXIT_POSITION.z + 0.6)
	sign.rotation.y = PI
	_visuals.add_child(sign)


## The hero, set up like the runner's (mirrored model, brightened, pose modifier) but STANDING, and at a
## size that makes the Bull loom over him.
func _build_player() -> Node3D:
	var root := Node3D.new()
	root.name = "Player"
	root.position = _player_pos
	_visuals.add_child(root)
	var hero: Node3D = null
	if ResourceLoader.exists(RunnerView.HERO_MODEL):
		var ps: PackedScene = load(RunnerView.HERO_MODEL)
		hero = ps.instantiate() as Node3D
	if hero == null:
		var pm := BoxMesh.new()
		pm.size = Vector3(0.7, 1.7, 0.7)
		var box := MeshInstance3D.new()
		box.mesh = pm
		box.material_override = Ep2Palette.make("leaf_green")
		box.position = Vector3(0.0, 0.85, 0.0)
		root.add_child(box)
		return root
	hero.scale = Vector3(-PLAYER_SCALE, PLAYER_SCALE, PLAYER_SCALE)
	root.add_child(hero)
	_hero_anim = null
	_hero_clip = ""
	for ap in hero.find_children("*", "AnimationPlayer", true, false):
		(ap as AnimationPlayer).stop()
		if _hero_anim == null:
			_hero_anim = ap
	if _hero_anim:
		_add_hero_clip("walk", HERO_WALK_CLIP)
		_add_hero_clip("run", HERO_RUN_CLIP)
		if not _hero_anim.has_animation("walk"):
			_hero_anim = null          # no walk cycle: fall back to the procedural bob
	var sks: Array = hero.find_children("*", "Skeleton3D", true, false)
	if not sks.is_empty():
		_player_skel = sks[0]
		_player_pose = RunnerArmRest.new()
		_player_pose.body_frame = true
		_player_pose.standing = true
		_player_pose.head_back = 0.25
		_player_pose.spine_back = 0.04
		_player_pose.gun_upper = Vector3(0.25, -0.95, 0.25)
		_player_pose.gun_fore = Vector3(0.75, -0.35, 0.2)
		_player_pose.gun_barrel = Vector3(0.85, -0.45, 0.1)
		_player_pose.pick_upper = Vector3(0.3, -0.9, 0.3)
		_player_pose.pick_fore = Vector3(0.55, 0.8, 0.1)
		_player_pose.pick_handle = Vector3(-0.45, 0.85, 0.3)
		_player_skel.add_child(_player_pose)
		_player_skel.skeleton_updated.connect(_on_player_skeleton_updated)
	RunnerView.self_light(hero, 0.08, Color(1.0, 0.86, 0.66))
	RunnerView.brighten_hero(hero)
	var key := OmniLight3D.new()
	key.light_color = Color(1.0, 0.84, 0.62)
	key.light_energy = 1.4
	key.omni_range = 4.5
	key.position = Vector3(0.8, 2.2, -1.2)
	root.add_child(key)
	return root


## Copy a clip out of an armature-only Meshy GLB (same rig, same track paths) into Lil Blunt's player.
func _add_hero_clip(clip_name: String, path: String) -> void:
	if _hero_anim == null or not ResourceLoader.exists(path):
		return
	var src: Node = (load(path) as PackedScene).instantiate()
	var aps: Array = src.find_children("*", "AnimationPlayer", true, false)
	if not aps.is_empty():
		var sp: AnimationPlayer = aps[0]
		var list: PackedStringArray = sp.get_animation_list()
		if not list.is_empty():
			var anim: Animation = sp.get_animation(list[0]).duplicate(true)
			anim.loop_mode = Animation.LOOP_LINEAR
			var lib: AnimationLibrary = _hero_anim.get_animation_library("")
			if lib and not lib.has_animation(clip_name):
				lib.add_animation(clip_name, anim)
	src.free()


## A brass miner's helmet with a working lamp - the one the Bull hands over.
func _build_helmet() -> Node3D:
	var h := Node3D.new()
	h.name = "MinerHelmet"
	var brass := Ep2Palette.make_unique("brass")
	brass.metallic = 0.25
	brass.roughness = 0.4
	var dome := SphereMesh.new()
	dome.radius = 0.24
	dome.height = 0.24
	dome.is_hemisphere = true
	var d := MeshInstance3D.new()
	d.mesh = dome
	d.material_override = brass
	h.add_child(d)
	var brim := CylinderMesh.new()
	brim.top_radius = 0.33
	brim.bottom_radius = 0.34
	brim.height = 0.035
	var b := MeshInstance3D.new()
	b.mesh = brim
	b.material_override = brass
	h.add_child(b)
	var ridge := BoxMesh.new()
	ridge.size = Vector3(0.05, 0.05, 0.46)
	var r := MeshInstance3D.new()
	r.mesh = ridge
	r.material_override = brass
	r.position = Vector3(0.0, 0.2, 0.0)
	h.add_child(r)
	var lamp := CylinderMesh.new()
	lamp.top_radius = 0.07
	lamp.bottom_radius = 0.07
	lamp.height = 0.08
	var lens := StandardMaterial3D.new()
	lens.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lens.albedo_color = Color(1.0, 0.92, 0.6)
	var l := MeshInstance3D.new()
	l.mesh = lamp
	l.material_override = lens
	l.rotation.x = PI * 0.5
	l.position = Vector3(0.0, 0.12, 0.23)
	h.add_child(l)
	var beam := SpotLight3D.new()
	beam.light_color = Color(1.0, 0.9, 0.65)
	beam.light_energy = 2.0
	beam.spot_range = 9.0
	beam.spot_angle = 22.0
	beam.position = Vector3(0.0, 0.12, 0.28)
	beam.rotation = Vector3(0.0, PI, 0.0)       # SpotLight shines down -Z; the lamp faces +Z
	h.add_child(beam)
	return h


## Godot 4.3 exposes the MODIFIED pose only inside skeleton_updated: sit the helmet on the real head bone.
func _on_player_skeleton_updated() -> void:
	if not _has_helmet or not _helmet_on_head or _helmet_node == null or not is_instance_valid(_helmet_node) or _player_skel == null:
		return
	var hb: int = _player_skel.find_bone("Head")
	if hb < 0:
		return
	# Position from the head BONE; orientation from his BODY (the rig's bone axes do not point "up": riding
	# the bone basis put the helmet edge-on in front of his face). Seated on the hat crown.
	var head: Vector3 = _player_skel.global_transform * _player_skel.get_bone_global_pose(hb).origin
	var body: Basis = _player_node.global_transform.basis.orthonormalized()
	_helmet_node.global_transform = Transform3D(body.scaled(Vector3.ONE * HELMET_SCALE),
		head + body.y * HELMET_LIFT * PLAYER_SCALE)


func _tex(path: String, tint: Color, uv_scale: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.roughness = 0.9
	if ResourceLoader.exists(path):
		m.albedo_texture = load(path)
		m.uv1_triplanar = true
		m.uv1_scale = Vector3.ONE * uv_scale
	return m


func _box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	_visuals.add_child(mi)
	return mi


func _boulder(pos: Vector3, size: float) -> void:
	if not ResourceLoader.exists(RunnerView.BOULDER_ROCK_MODEL):
		return
	var b: Node3D = (load(RunnerView.BOULDER_ROCK_MODEL) as PackedScene).instantiate()
	b.scale = Vector3.ONE * size          # boulder_rock.glb is 1 m tall, base at y = 0
	b.position = pos - Vector3(0.0, 0.1 * size, 0.0)
	b.rotation.y = pos.x * 1.3 + pos.z * 0.7
	RunnerView.self_light(b, 0.05, Color(1.0, 0.75, 0.5))
	_visuals.add_child(b)


func _particles(amount: int, lifetime: float, color: Color, size: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = color
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _soft_blob()
	q.material = m
	p.mesh = q
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = fade
	p.emitting = true
	return p


## Push the shared Episode 2 art direction onto this scene, using the FORGE
## environment rather than the tunnel one.
func _apply_art() -> void:
	var we := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we:
		we.environment = Ep2Palette.make_forge_environment()
		# The hangout is the warmest, brightest room in the episode (founder target image): lift the fill and bloom.
		we.environment.ambient_light_energy = 0.95
		we.environment.glow_intensity = 0.85
		we.environment.glow_hdr_threshold = 0.95
		# Founder 2026-10-01: "I don't like the greyscale" - push the grade toward the target's saturated gold.
		we.environment.adjustment_enabled = true
		we.environment.adjustment_saturation = 1.2
		we.environment.adjustment_contrast = 1.08
		we.environment.adjustment_brightness = 1.05
	var sun := get_node_or_null("Sun") as DirectionalLight3D
	if sun:
		var key := Ep2Palette.make_key_light()
		sun.light_color = key.light_color
		sun.light_energy = key.light_energy * 0.6   # the pours dominate here
		sun.shadow_enabled = key.shadow_enabled
		key.queue_free()


func _sync_visuals() -> void:
	if _visuals == null or not is_instance_valid(_visuals):
		return
	if _player_node and is_instance_valid(_player_node):
		var lying: bool = _beat <= Beat.WAKE
		if not lying:
			_player_node.position = Vector3(_player_pos.x, _player_pos.y, _player_pos.z)
		if lying:
			# Out cold on his back at the Bull's boots, head toward him (the film ended here).
			_player_node.basis = Basis(Vector3(-1.0, 0.0, 0.0), Vector3(0.0, 0.0, 1.0), Vector3(0.0, 1.0, 0.0))
			_player_node.position.y = 0.3
			_player_node.position.z = _player_pos.z - 1.1
			_player_node.position.x = _player_pos.x
		if _player_pose:
			_player_pose.influence = 0.35 if lying else 1.0
	# Broken molds drop and go dark — the verb teach needs visible feedback or
	# the player cannot tell a hit from a miss.
	for i in _mold_nodes.size():
		var mi: MeshInstance3D = _mold_nodes[i]
		if not is_instance_valid(mi):
			continue
		var broken: bool = i >= _molds_left
		mi.position.y = 0.25 if broken else 1.05
		mi.rotation.z = deg_to_rad(72.0) if broken else 0.0
		var m: StandardMaterial3D = mi.material_override
		if m:
			m.albedo_color = Color(0.20, 0.19, 0.19) if broken else Ep2Palette.table()["iron"].albedo


# --- The Bull's props: whiskey glass in hand, lit cigar, embers (founder target image) -----------------------
# Statue fallback positions are in the Bull pivot's local space (feet origin, he faces -Z). With the rig the glass
# rides his LEFT hand bone and the cigar ember rides the `headfront` bone, so they move with his clips.
const BULL_GLASS_REST := Vector3(0.74, 0.95, -0.45)
const BULL_MOUTH := Vector3(0.05, 2.4, -0.75)
const BULL_HAND_OUT := Vector3(0.45, 1.65, -1.25)
const CRATE_OFFSET := Vector3(1.55, 1.0, 0.3)
## Clip names inside inferno_bull_rigged.glb (Meshy library ids 11, 342, 313, 292).
const BULL_IDLE := "Idle_02"
const BULL_DRINK := "Stand_and_Drink"
const BULL_TALK := "Talk_with_Hands_Open"
const BULL_GUN := "Gesture_with_Hand_on_Gun"
## Seated clips on the same rig (library ids 343, 53; 33 kept as a spare), in their own GLB: the target image has
## him sitting on a crate. He sits until "SIZING" (he takes your measure), then stands for the hand-overs.
const BULL_SIT_CLIPS := "res://src/episode2/assets/inferno_bull_sit_clips.glb"
const BULL_SIT := "Sit_and_Drink"
const BULL_STAND_UP := "Sit_to_Stand_Transition_M"
const STAND_UP_SPEED := 1.8
## Root drift between Meshy clips (model units, measured with a skeleton probe): Sit_to_Stand starts from a chair
## 1.24 back and 0.25 higher than Sit_and_Drink's seat and ends 0.49 back of the standing clips' hips. The model is
## offset by a correction blended across the stand-up so he rises from HIS crate and ends on his mark.
const STAND_CORR_START := Vector3(0.02, -0.25, 1.24)
const STAND_CORR_END := Vector3(-0.16, 0.0, 0.49)


## Loop the idle/talk clips (Meshy clips import non-looping) and hang attachment points on his bones.
func _setup_bull_rig(bull: Node3D) -> void:
	var aps: Array = bull.find_children("*", "AnimationPlayer", true, false)
	if not aps.is_empty():
		_bull_anim = aps[0]
		if ResourceLoader.exists(BULL_SIT_CLIPS):
			var src: Node = (load(BULL_SIT_CLIPS) as PackedScene).instantiate()
			var saps: Array = src.find_children("*", "AnimationPlayer", true, false)
			var lib: AnimationLibrary = _bull_anim.get_animation_library("")
			if not saps.is_empty() and lib:
				for clip_name in (saps[0] as AnimationPlayer).get_animation_list():
					if not lib.has_animation(clip_name):
						lib.add_animation(clip_name, (saps[0] as AnimationPlayer).get_animation(clip_name).duplicate(true))
			src.free()
		for clip in [BULL_IDLE, BULL_TALK, BULL_DRINK, BULL_SIT]:
			if _bull_anim.has_animation(clip):
				_bull_anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		_bull_play(BULL_IDLE)
	var sks: Array = bull.find_children("*", "Skeleton3D", true, false)
	if sks.is_empty():
		return
	var sk: Skeleton3D = sks[0]
	_bull_hand = _bone_attachment(sk, "RightHand")
	_bull_left_hand = _bone_attachment(sk, "LeftHand")
	_bull_face = _bone_attachment(sk, "headfront")


func _bone_attachment(sk: Skeleton3D, bone: String) -> BoneAttachment3D:
	if sk.find_bone(bone) < 0:
		return null
	var ba := BoneAttachment3D.new()
	ba.name = "Att_" + bone
	ba.bone_name = bone
	sk.add_child(ba)
	return ba


func _bull_play(clip: String, speed: float = 1.0) -> void:
	if _bull_anim == null or not is_instance_valid(_bull_anim) or clip == _bull_clip or not _bull_anim.has_animation(clip):
		return
	_bull_clip = clip
	_bull_anim.play(clip, 0.4, speed)


func is_bull_seated() -> bool:
	return _bull_anim != null and _stand_t < 0.0 and _bull_anim.has_animation(BULL_SIT)


func _build_bull_props() -> void:
	var amber := StandardMaterial3D.new()
	amber.albedo_color = Color(0.82, 0.42, 0.08, 0.8)
	amber.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	amber.roughness = 0.08
	amber.emission_enabled = true
	amber.emission = Color(0.95, 0.45, 0.06)
	amber.emission_energy_multiplier = 0.7
	var tumbler := CylinderMesh.new()
	tumbler.top_radius = 0.09
	tumbler.bottom_radius = 0.075
	tumbler.height = 0.17
	_glass_node = Node3D.new()
	_glass_node.name = "BullGlass"
	var gm := MeshInstance3D.new()
	gm.mesh = tumbler
	gm.material_override = amber
	_glass_node.add_child(gm)
	if _bull_left_hand:
		# Meshy's "LeftHand" is the hand holding his rifle - the one the drink clips lift to his mouth.
		_bull_left_hand.add_child(_glass_node)
		_glass_node.position = Vector3(0.0, 0.08, 0.04)
	else:
		_glass_node.position = BULL_GLASS_REST
		_bull_pivot.add_child(_glass_node)
	# The model already holds the cigar in his teeth; we add only its ember glow and the smoke.
	var tip := SphereMesh.new()
	tip.radius = 0.025
	tip.height = 0.05
	var tm := StandardMaterial3D.new()
	tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tm.albedo_color = Color(1.0, 0.5, 0.15)
	_cigar_tip = MeshInstance3D.new()
	_cigar_tip.mesh = tip
	_cigar_tip.material_override = tm
	_cigar_smoke = _particles(22, 3.0, Color(0.82, 0.8, 0.78, 0.3), 0.14)
	_cigar_smoke.direction = Vector3.UP
	_cigar_smoke.spread = 22.0
	_cigar_smoke.initial_velocity_min = 0.18
	_cigar_smoke.initial_velocity_max = 0.45
	_cigar_smoke.gravity = Vector3(0.05, 0.12, 0.0)
	_cigar_smoke.scale_amount_min = 0.7
	_cigar_smoke.scale_amount_max = 2.6
	_cigar_smoke.preprocess = 3.0
	_cigar_smoke.local_coords = false
	if _bull_face:
		_bull_face.add_child(_cigar_tip)
		_bull_face.add_child(_cigar_smoke)
		_cigar_tip.position = Vector3(0.06, -0.05, 0.12)
		_cigar_smoke.position = _cigar_tip.position
	else:
		_cigar_tip.position = BULL_MOUTH
		_cigar_smoke.position = BULL_MOUTH
		_bull_pivot.add_child(_cigar_tip)
		_bull_pivot.add_child(_cigar_smoke)
	# Heat: embers lifting off his shoulders (he is associated with flame).
	var embers := _particles(40, 2.6, Color(1.0, 0.55, 0.15), 0.04)
	embers.position = Vector3(0.0, 1.7, -0.1)
	embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	embers.emission_box_extents = Vector3(0.7, 0.9, 0.35)
	embers.direction = Vector3.UP
	embers.spread = 25.0
	embers.initial_velocity_min = 0.2
	embers.initial_velocity_max = 0.7
	embers.gravity = Vector3(0.0, 0.25, 0.0)
	embers.preprocess = 2.6
	_bull_pivot.add_child(embers)


func _hideout_plain(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.7
	return m


## Where the Bull presents an item right now: between his two open hands (Talk_with_Hands_Open spreads them
## ~0.8 m to each side at chest height), a little in front of his chest, so it is visible and moves with his arms.
func get_bull_hand() -> Vector3:
	if _bull_hand and is_instance_valid(_bull_hand) and _bull_hand.is_inside_tree() and _bull_left_hand \
			and is_instance_valid(_bull_left_hand):
		var mid: Vector3 = (_bull_hand.global_position + _bull_left_hand.global_position) * 0.5
		var fwd: Vector3 = -_bull_pivot.global_transform.basis.z.normalized()
		return mid + fwd * 0.45 + Vector3(0.0, 0.05, 0.0)
	if _bull_pivot and is_instance_valid(_bull_pivot) and _bull_pivot.is_inside_tree():
		return _bull_pivot.to_global(BULL_HAND_OUT)
	return BULL_POSITION + BULL_HAND_OUT


# --- Performance ----------------------------------------------------------------------------------------
# The Bull plays his Meshy clips by beat (drink, talk with open hands for the hand-overs, hand-on-gun for his
# terms); Lil Blunt plays his walk/run cycle when he moves, and the props travel hand to hand.

func _animate(delta: float) -> void:
	if _visuals == null or not is_instance_valid(_visuals) or not is_inside_tree():
		return
	_anim_t += delta
	_animate_bull(delta)
	_animate_hero(delta)
	_animate_gear(delta)
	_animate_set(delta)


func _smooth(t: float) -> float:
	var c: float = clampf(t, 0.0, 1.0)
	return c * c * (3.0 - 2.0 * c)


func _bull_handing() -> bool:
	return (_beat == Beat.HANDOFF and _rifle_t > 0.3 and _rifle_t < 3.0) \
		or (_beat == Beat.HELMET and _helmet_t > 0.3 and _helmet_t < 3.4)


func _animate_bull(delta: float) -> void:
	if _bull_pivot == null or not is_instance_valid(_bull_pivot):
		return
	var handing: bool = _bull_handing()
	_lean = lerpf(_lean, 0.12 if handing else 0.0, clampf(4.0 * delta, 0.0, 1.0))
	# He turns to keep Lil Blunt in front of him (at most 60 degrees off his post).
	var to_p := Vector2(_player_pos.x - BULL_POSITION.x, _player_pos.z - BULL_POSITION.z)
	var want_yaw: float = 0.0
	if _in_scripted_handover() or is_bull_seated():
		want_yaw = 0.3          # square to the camera (and his crate), free hand on Lil Blunt's side for the offer
	elif to_p.length() < 9.0 and _beat > Beat.WAKE:
		want_yaw = clampf(wrapf(atan2(-to_p.x, -to_p.y), -PI, PI), -1.05, 1.05)
	var cur_yaw: float = lerp_angle(_bull_pivot.rotation.y, want_yaw, clampf(2.5 * delta, 0.0, 1.0))
	if _bull_anim:
		_bull_pivot.rotation = Vector3(_lean, cur_yaw, 0.0)
		# Seated until he takes your measure; any later beat finds him already standing.
		if _stand_t < 0.0 and _bull_anim.has_animation(BULL_SIT):
			if _beat == Beat.SIZING:
				_stand_t = 0.0
			elif _beat > Beat.SIZING:
				_stand_t = 99.0
		var stand_len: float = (_bull_anim.get_animation(BULL_STAND_UP).length / STAND_UP_SPEED) \
			if _bull_anim.has_animation(BULL_STAND_UP) else 0.0
		var corr := Vector3.ZERO
		if is_bull_seated():
			_bull_play(BULL_SIT)
			_bull_model.position = Basis(Vector3.UP, PI) * (corr * _bull_model.scale.x)
			return
		if _stand_t >= 0.0 and _stand_t < stand_len:
			_stand_t += delta
			var u: float = clampf(_stand_t / stand_len, 0.0, 1.0)
			corr = STAND_CORR_START.lerp(STAND_CORR_END, _smooth(u))
			_bull_play(BULL_STAND_UP, STAND_UP_SPEED)
			_bull_model.position = Basis(Vector3.UP, PI) * (corr * _bull_model.scale.x)
			return
		if _stand_t < 99.0 and _stand_t >= 0.0:
			_stand_t = 99.0
			_settle = 0.4           # crossfade window into the standing clips
		_settle = maxf(0.0, _settle - delta)
		# During the 0.4 s crossfade the correction eases out at the same rate the stand-up pose fades: no pop.
		_bull_model.position = Basis(Vector3.UP, PI) * (STAND_CORR_END * (_settle / 0.4) * _bull_model.scale.x)
		var clip: String = BULL_IDLE
		if handing:
			clip = BULL_TALK
		elif _beat == Beat.WAKE or (_beat == Beat.DRINK and _hold > 0.0):
			clip = BULL_DRINK
		elif _beat == Beat.TERMS and _hold > 0.0:
			clip = BULL_GUN
		elif _hold > 0.0:
			clip = BULL_TALK
		elif fmod(_anim_t, 16.0) > 7.0 and fmod(_anim_t, 16.0) < 15.9:
			clip = BULL_DRINK           # between lines he nurses his whiskey
		_bull_play(clip)
	else:
		# Statue fallback: whole-body breathing and sway.
		var breath: float = sin(_anim_t * 1.7)
		_bull_pivot.rotation = Vector3(_lean + 0.008 * breath, cur_yaw, 0.014 * sin(_anim_t * 0.55))
		_bull_pivot.scale = Vector3(1.0, 1.0 + 0.006 * breath, 1.0)
	if _cigar_tip:
		var pp: float = fmod(_anim_t + 4.5, 9.0)
		var puff: float = _smooth(pp / 0.6) - _smooth((pp - 1.4) / 0.9)
		(_cigar_tip.material_override as StandardMaterial3D).albedo_color = Color(1.0, 0.42, 0.1).lerp(Color(1.0, 0.85, 0.45), puff)
		_cigar_tip.scale = Vector3.ONE * (1.0 + 0.6 * puff)


## Lil Blunt: walk / run cycle while moving, faces where he walks; in a conversation he turns to the Bull; reach
## for each item on the hand-over; a hop for joy when the helmet lands.
func _animate_hero(delta: float) -> void:
	if _player_node == null or not is_instance_valid(_player_node) or _beat <= Beat.WAKE:
		return
	var talking: bool = _beat >= Beat.DRINK and _beat <= Beat.PROMISE
	if (talking or _in_scripted_handover()) and not _moving:
		var to_bull: float = atan2(BULL_POSITION.x - _player_pos.x, BULL_POSITION.z - _player_pos.z)
		# On the hand-over mark he turns three-quarters toward the camera, looking up at the Bull (target image).
		var want: float = to_bull + (1.35 if _in_scripted_handover() else 0.0)
		_player_yaw = lerp_angle(_player_yaw, want, clampf(5.0 * delta, 0.0, 1.0))
	var reach: float = 0.0
	if _beat == Beat.HANDOFF:
		reach = _smooth((_rifle_t - 1.6) / 0.6) * (1.0 - _smooth((_rifle_t - 3.2) / 0.6))
	elif _beat == Beat.HELMET:
		reach = _smooth((_helmet_t - 1.8) / 0.6) * (1.0 - _smooth((_helmet_t - 3.2) / 0.6))
	if _hop_v != 0.0 or _hop_y > 0.0:
		_hop_v -= 15.0 * delta
		_hop_y = maxf(0.0, _hop_y + _hop_v * delta)
		if _hop_y <= 0.0:
			_hop_v = 0.0
	var breath: float = 0.010 * sin(_anim_t * 2.1)
	var sway: float = 0.0 if _hero_anim else (sin(_walk_phase) * 0.07 if _moving else 0.02 * sin(_anim_t * 0.9))
	var bob: float = 0.0 if _hero_anim or not _moving else absf(sin(_walk_phase)) * 0.075
	_player_node.basis = Basis.from_euler(Vector3(0.16 * reach, _player_yaw, sway)).scaled(Vector3(1.0, 1.0 + breath, 1.0))
	_player_node.position = Vector3(_player_pos.x, (0.35 if _in_cover else 0.0) + _player_pos.y + bob + _hop_y + 0.05 * reach,
		_player_pos.z)
	if _hero_anim:
		var clip: String = ""
		if _moving and _player_pos.y <= 0.001:
			clip = "run" if _run_input else "walk"
		if clip != _hero_clip:
			_hero_clip = clip
			if clip == "":
				_hero_anim.pause()
			else:
				_hero_anim.play(clip, 0.15)
				_hero_anim.speed_scale = 1.25 if clip == "run" else 1.7
		if _player_pose:
			_player_pose.legs_free = clip != ""


## The rifle and the helmet travel by hand: crate -> the Bull's outstretched hand -> Lil Blunt, rather than
## teleporting.
func _animate_gear(delta: float) -> void:
	if _beat >= Beat.HANDOFF:
		if _beat == Beat.HANDOFF:
			_rifle_t += delta
		elif not _rifle_in_hands:
			_rifle_t = 99.0
	if _beat >= Beat.HELMET:
		if _beat == Beat.HELMET:
			_helmet_t += delta
		elif not _helmet_on_head:
			_helmet_t = 99.0
	var crate: Vector3 = BULL_POSITION + CRATE_OFFSET
	var hand: Vector3 = get_bull_hand()
	var body := Basis(Vector3.UP, _player_yaw)
	# --- rifle
	if _rifle_node and is_instance_valid(_rifle_node) and _has_winchester:
		var held: Vector3 = _player_node.position + body * Vector3(0.5, 0.95, 0.2) if _player_node else hand
		var t: float = _rifle_t
		var pos: Vector3 = held
		if t < 0.9:
			pos = crate.lerp(hand, _smooth(t / 0.9)) + Vector3(0.0, 0.35 * sin(_smooth(t / 0.9) * PI), 0.0)
		elif t < 2.1:
			pos = hand + Vector3(0.0, 0.03 * sin(_anim_t * 3.0), 0.0)
		elif t < 3.0:
			pos = hand.lerp(held, _smooth((t - 2.1) / 0.9))
		else:
			_rifle_in_hands = true
		_rifle_node.position = pos
		var held_rot := Vector3(0.0, _player_yaw, deg_to_rad(-18.0))
		_rifle_node.rotation = Vector3(0.0, PI * 0.5, 0.0).lerp(held_rot, _smooth((t - 2.1) / 0.9)) if t < 3.0 else held_rot
	# --- helmet
	if _helmet_node and is_instance_valid(_helmet_node) and _has_helmet and not _helmet_on_head:
		var t2: float = _helmet_t
		var head: Vector3 = _player_node.global_position + Vector3(0.0, 1.95, 0.0) if _player_node else hand
		var p2: Vector3 = hand
		if t2 < 0.9:
			p2 = crate.lerp(hand, _smooth(t2 / 0.9)) + Vector3(0.0, 0.3 * sin(_smooth(t2 / 0.9) * PI), 0.0)
		elif t2 < 2.2:
			p2 = hand + Vector3(0.0, 0.02 * sin(_anim_t * 3.0), 0.0)
		elif t2 < 3.2:
			p2 = hand.lerp(head + Vector3(0.0, 0.25, 0.0), _smooth((t2 - 2.2) / 1.0))
		else:
			_helmet_on_head = true
			_hop_v = 3.4       # joy
		_helmet_node.position = p2
		_helmet_node.rotation = Vector3.ZERO
		_helmet_node.scale = Vector3.ONE * HELMET_SCALE


## Fire and lamp flicker, so the room breathes with heat.
func _animate_set(_delta: float) -> void:
	var flames: Array = _dressing.get("flames", [])
	for i in flames.size():
		var l: OmniLight3D = flames[i]
		if not is_instance_valid(l):
			continue
		if not l.has_meta("e0"):
			l.set_meta("e0", l.light_energy)
		var e0: float = l.get_meta("e0")
		l.light_energy = e0 * (0.82 + 0.16 * sin(_anim_t * 13.0 + float(i) * 1.7) + 0.1 * sin(_anim_t * 29.0 + float(i) * 3.1))


var _blob_tex: GradientTexture2D = null

## One shared round soft-edged sprite for every smoke / steam / ember particle: untextured quads render as hard
## squares (the pixelated steam the first facility capture showed).
func _soft_blob() -> GradientTexture2D:
	if _blob_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		_blob_tex = GradientTexture2D.new()
		_blob_tex.gradient = g
		_blob_tex.fill = GradientTexture2D.FILL_RADIAL
		_blob_tex.fill_from = Vector2(0.5, 0.5)
		_blob_tex.fill_to = Vector2(1.0, 0.5)
		_blob_tex.width = 64
		_blob_tex.height = 64
	return _blob_tex
