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
var _walk_input: float = 0.0         # -1..1 along Z, set by walk_forward/back
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
const CAM_HAND := [Vector3(-0.3, 1.8, -1.2), -4.0, 184.0]
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

const BULL_MODEL := "res://src/episode2/assets/inferno_bull.glb"   # founder's "Bull Mine Gunslinger"
const BULL_NATIVE_H := 1.898         # model height (origin at its centre)
const BULL_NATIVE_FEET := 0.947      # centre -> feet in model units
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
	_walk_input = 0.0
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

	_update_camera(delta)

	if absf(_walk_input) > 0.01 and _beat != Beat.WAKE:
		_player_pos.z += _walk_input * WALK_SPEED * delta
		_player_pos.z = clampf(_player_pos.z, ENTRY_POSITION.z, EXIT_POSITION.z)

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


## Walking. -1 back toward the runner tunnel, +1 on toward Fort Knox.
func walk(direction: float) -> void:
	_walk_input = clampf(direction, -1.0, 1.0)


func walk_stop() -> void:
	_walk_input = 0.0


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
	if beat == Beat.HELMET:
		_has_helmet = true
		gear_granted.emit(HELMET_ID)
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


## Choose the framing this beat wants, and ease toward it.
func _update_camera(delta: float) -> void:
	if _camera == null or not is_instance_valid(_camera):
		return
	var want: Array
	match _beat:
		Beat.WAKE:
			want = CAM_WAKE
		Beat.DRINK, Beat.SIZING, Beat.TERMS, Beat.PROMISE:
			want = CAM_CLOSE
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
	var pitch: float = lerpf(_camera.rotation_degrees.x, _cam_target_pitch, t)
	# Yaw 180 keeps the camera looking down +Z, the orientation both Episode 2
	# cameras had to be corrected to after they were found facing backwards.
	var yaw: float = lerpf(_camera.rotation_degrees.y, _cam_target_yaw, t)
	_camera.rotation_degrees = Vector3(pitch, yaw, 0.0)


func _distance_to_bull() -> float:
	return absf(BULL_POSITION.z - _player_pos.z)


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
		var pour := CylinderMesh.new()
		pour.top_radius = 0.07
		pour.bottom_radius = 0.12
		pour.height = 1.9
		var pour_mi := MeshInstance3D.new()
		pour_mi.mesh = pour
		pour_mi.material_override = channel
		pour_mi.position = spec + Vector3(0.0, 1.0, -1.3)
		_visuals.add_child(pour_mi)
		var glow := Ep2Palette.make_forge_light()
		glow.position = spec + Vector3(0.0, 1.8, 0.0)
		_visuals.add_child(glow)
		var steam := _particles(26, 3.0, Color(0.75, 0.68, 0.62, 0.22), 1.1)
		steam.position = spec + Vector3(0.0, 1.8, 0.0)
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
	var bs: float = BULL_HEIGHT / BULL_NATIVE_H
	# The pivot sits at his feet so a lean rotates him about his boots, not about his belly.
	_bull_pivot = Node3D.new()
	_bull_pivot.name = "BullPivot"
	_bull_pivot.position = BULL_POSITION
	_visuals.add_child(_bull_pivot)
	var bull: Node3D = null
	if ResourceLoader.exists(BULL_MODEL):
		bull = (load(BULL_MODEL) as PackedScene).instantiate() as Node3D
	if bull:
		bull.position = Vector3(0.0, BULL_NATIVE_FEET * bs, 0.0)
		bull.scale = Vector3.ONE * bs
		bull.rotate_y(PI)
		_bull_pivot.add_child(bull)
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
	_box(Vector3(0.9, 0.9, 0.9), BULL_POSITION + Vector3(-1.4, 0.45, -0.5), timber)
	_prop(WHISKEY_MODEL, BULL_POSITION + Vector3(-1.4, 0.92, -0.5), 1.4)
	var glass_mat := StandardMaterial3D.new()
	glass_mat.albedo_color = Color(0.45, 0.22, 0.06, 0.85)
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat.roughness = 0.08
	glass_mat.metallic_specular = 0.8
	var body := CylinderMesh.new()
	body.top_radius = 0.075
	body.bottom_radius = 0.08
	body.height = 0.26
	_mesh(body, glass_mat, BULL_POSITION + Vector3(-1.15, 1.03, -0.3))
	var neck := CylinderMesh.new()
	neck.top_radius = 0.022
	neck.bottom_radius = 0.06
	neck.height = 0.16
	_mesh(neck, glass_mat, BULL_POSITION + Vector3(-1.15, 1.24, -0.3))

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
	_rifle_node = _prop(RIFLE_MODEL, BULL_POSITION + Vector3(-1.4, 1.0, -0.2), 1.0, PI * 0.5)
	# The helmet waits on the crate too.
	_helmet_node = _build_helmet()
	_helmet_node.position = BULL_POSITION + Vector3(-1.65, 1.05, -0.75)
	_visuals.add_child(_helmet_node)

	# --- the hangout: alcove, trophies, armory, Gatling, poster, braziers (see HideoutDressing).
	_dressing = HideoutDressing.build(_visuals)

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
	for ap in hero.find_children("*", "AnimationPlayer", true, false):
		(ap as AnimationPlayer).stop()
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
		_player_node.position.x = _player_pos.x
		_player_node.position.z = _player_pos.z
		var lying: bool = _beat <= Beat.WAKE
		if lying:
			# Out cold on his back at the Bull's boots, head toward him (the film ended here).
			_player_node.basis = Basis(Vector3(-1.0, 0.0, 0.0), Vector3(0.0, 0.0, 1.0), Vector3(0.0, 1.0, 0.0))
			_player_node.position.y = 0.3
			_player_node.position.z = _player_pos.z - 1.1
		else:
			_player_node.basis = Basis.IDENTITY
			_player_node.position.y = 0.35 if _in_cover else 0.0
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
# Positions are in the Bull pivot's local space (feet origin, he faces -Z). Tuned against real captures.
const BULL_GLASS_REST := Vector3(0.74, 0.95, -0.45)
const BULL_GLASS_LIP := Vector3(0.22, 2.38, -0.62)
const BULL_MOUTH := Vector3(0.0, 2.43, -0.58)
const BULL_HAND_OUT := Vector3(0.45, 1.65, -1.25)
const CRATE_OFFSET := Vector3(-1.4, 1.0, -0.2)


func _build_bull_props() -> void:
	var amber := StandardMaterial3D.new()
	amber.albedo_color = Color(0.82, 0.42, 0.08, 0.8)
	amber.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	amber.roughness = 0.08
	amber.emission_enabled = true
	amber.emission = Color(0.95, 0.45, 0.06)
	amber.emission_energy_multiplier = 0.7
	var tumbler := CylinderMesh.new()
	tumbler.top_radius = 0.11
	tumbler.bottom_radius = 0.09
	tumbler.height = 0.22
	_glass_node = Node3D.new()
	_glass_node.name = "BullGlass"
	_glass_node.position = BULL_GLASS_REST
	_bull_pivot.add_child(_glass_node)
	var gm := MeshInstance3D.new()
	gm.mesh = tumbler
	gm.material_override = amber
	_glass_node.add_child(gm)
	# The Bull's own model already holds the cigar in his teeth; we add only its ember glow and the smoke.
	var tip := SphereMesh.new()
	tip.radius = 0.03
	tip.height = 0.06
	var tm := StandardMaterial3D.new()
	tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tm.albedo_color = Color(1.0, 0.5, 0.15)
	_cigar_tip = MeshInstance3D.new()
	_cigar_tip.mesh = tip
	_cigar_tip.material_override = tm
	_cigar_tip.position = Vector3(0.05, 2.4, -0.75)
	_bull_pivot.add_child(_cigar_tip)
	_cigar_smoke = _particles(22, 3.0, Color(0.82, 0.8, 0.78, 0.3), 0.14)
	_cigar_smoke.position = _cigar_tip.position
	_cigar_smoke.direction = Vector3.UP
	_cigar_smoke.spread = 22.0
	_cigar_smoke.initial_velocity_min = 0.18
	_cigar_smoke.initial_velocity_max = 0.45
	_cigar_smoke.gravity = Vector3(0.05, 0.12, 0.0)
	_cigar_smoke.scale_amount_min = 0.7
	_cigar_smoke.scale_amount_max = 2.6
	_cigar_smoke.preprocess = 3.0
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


# --- Performance ----------------------------------------------------------------------------------------
# Neither actor has a clip for this scene (the Bull model is a statue; Lil Blunt's rig only carries the
# runner's poses), so the acting is procedural: small, readable, deterministic motions driven by the beat.

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


## Breathing, weight shift, a lean toward Lil Blunt while he hands something over, the raised glass and a
## cigar puff every few seconds.
func _animate_bull(delta: float) -> void:
	if _bull_pivot == null or not is_instance_valid(_bull_pivot):
		return
	var handing: bool = (_beat == Beat.HANDOFF and _rifle_t > 0.4 and _rifle_t < 2.8) \
		or (_beat == Beat.HELMET and _helmet_t > 0.4 and _helmet_t < 3.0)
	_lean = lerpf(_lean, 0.15 if handing else 0.0, clampf(4.0 * delta, 0.0, 1.0))
	var breath: float = sin(_anim_t * 1.7)
	_bull_pivot.rotation = Vector3(_lean + 0.008 * breath, 0.0, 0.014 * sin(_anim_t * 0.55))
	_bull_pivot.scale = Vector3(1.0, 1.0 + 0.006 * breath, 1.0)
	# The glass: up to his lip, a pause (the puff), back to his hip. One cycle every 9 s.
	if _glass_node:
		var ph: float = fmod(_anim_t, 9.0)
		var up: float = _smooth(ph / 1.0) - _smooth((ph - 2.4) / 1.1)
		if handing:
			up = 0.0
		_glass_node.position = BULL_GLASS_REST.lerp(BULL_GLASS_LIP, up)
		_glass_node.rotation_degrees.z = -22.0 * up
	# The cigar tip glows brighter on the puff, which follows the sip.
	if _cigar_tip:
		var pp: float = fmod(_anim_t + 4.5, 9.0)
		var puff: float = _smooth(pp / 0.6) - _smooth((pp - 1.4) / 0.9)
		(_cigar_tip.material_override as StandardMaterial3D).albedo_color = Color(1.0, 0.42, 0.1).lerp(Color(1.0, 0.85, 0.45), puff)
		_cigar_tip.scale = Vector3.ONE * (1.0 + 0.5 * puff)


## Lil Blunt: breathing and weight shift when still, a bob-and-sway while walking, three-quarter turn toward the
## camera while the Bull talks, a reach forward when something is handed over, and a hop for joy after the helmet.
func _animate_hero(delta: float) -> void:
	if _player_node == null or not is_instance_valid(_player_node) or _beat <= Beat.WAKE:
		return
	var walking: bool = absf(_walk_input) > 0.01
	if walking:
		_walk_phase += delta * 9.5
	var bob: float = absf(sin(_walk_phase)) * 0.075 if walking else 0.0
	var sway: float = sin(_walk_phase) * 0.07 if walking else 0.02 * sin(_anim_t * 0.9)
	var breath: float = 0.010 * sin(_anim_t * 2.1)
	var talking: bool = _beat >= Beat.DRINK and _beat <= Beat.PROMISE
	var yaw: float = 1.15 if talking and not walking else 0.0
	var reach: float = 0.0
	if _beat == Beat.HANDOFF:
		reach = _smooth((_rifle_t - 1.6) / 0.6) * (1.0 - _smooth((_rifle_t - 3.2) / 0.6))
	elif _beat == Beat.HELMET:
		reach = _smooth((_helmet_t - 1.8) / 0.6) * (1.0 - _smooth((_helmet_t - 3.2) / 0.6))
		yaw = 1.3 if reach > 0.0 else yaw
	# joy hop
	if _hop_v != 0.0 or _hop_y > 0.0:
		_hop_v -= 15.0 * delta
		_hop_y = maxf(0.0, _hop_y + _hop_v * delta)
		if _hop_y <= 0.0:
			_hop_v = 0.0
	var pitch: float = 0.16 * reach
	_player_node.basis = Basis.from_euler(Vector3(pitch, yaw, sway))
	_player_node.basis = _player_node.basis.scaled(Vector3(1.0, 1.0 + breath, 1.0))
	_player_node.position.y = (0.35 if _in_cover else 0.0) + bob + _hop_y + 0.05 * reach


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
	var hand: Vector3 = _bull_pivot.to_global(BULL_HAND_OUT) if _bull_pivot else crate
	# --- rifle
	if _rifle_node and is_instance_valid(_rifle_node) and _has_winchester:
		var held: Vector3 = Vector3(_player_pos.x + 0.55, 0.95 + _player_node.position.y, _player_pos.z + 0.2)
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
		var held_rot := Vector3(0.0, 0.0, deg_to_rad(-18.0))
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
