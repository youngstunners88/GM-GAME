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
## Lil Blunt paid for the gear: ONE Bitcoin for the Winchester and the helmet together (founder 2026-10-02).
signal payment_made(amount: int)
## The scene flipped to first person (the shooter/RPG mode starts here; see Episode2Mode).
signal fps_started

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
## Where he stands at rest once the gear is handed over (beside his crate, not following Lil Blunt).
const BULL_REST := Vector3(2.6, 0.0, 6.3)
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
const HAND_MARK := Vector3(-0.7, 0.0, 5.4)
## Marks for Inferno Bull's choreography (skill ep2-bull-handoff-walk). He walks to the gun wall, takes the
## Winchester off the rack, walks to Lil Blunt and hands it over; then the same with the helmet on its peg.
const WALL_RACK_POS := Vector3(-6.7, 2.45, 6.8)        # the Winchester on the rack (his hand target)
const WALL_STAND := Vector3(-5.95, 0.0, 6.8)
const HELMET_PEG := Vector3(-6.7, 2.2, 10.2)
const HELMET_STAND := Vector3(-5.95, 0.0, 10.2)
const BTC_PRICE := 1                                   # one Bitcoin buys the rifle AND the helmet
## How an item sits in his right-hand holder (metres, in the hand bone's frame; tuned against captures).
const RIFLE_IN_HAND_POS := Vector3(0.0, 0.12, 0.05)
const RIFLE_IN_HAND_ROT := Vector3(-1.5708, 0.0, 0.0)
const RIFLE_HAND_SCALE := 1.0
const HELMET_IN_HAND_POS := Vector3(0.0, 0.18, 0.1)
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
const WAKE_LINES := ["vo_lb_wake", "vo_bull_wake"]
## Where he comes to: on the floor at the Bull's boots (inside TALK_RANGE, so the meeting follows).
const WAKE_POSITION := Vector3(0.4, 0.0, 3.6)
## The Seedance 2 transition film (founder 2026-10-03, skill ep2-seedance-film): the cart leaves the mine, flies the
## gap, Lil Blunt is knocked out, Inferno Bull patches him up, sells him the Winchester + helmet for a Bitcoin and
## starts target practice. NO MUSIC in it (the founder scores it later). Built by tools/ep2_film/compose_film.sh.
const FILM_VIDEO := "res://src/assets/video/cutscenes/ep2_cliff_to_hideout.ogv"
const FILM_SECONDS := 60.9
## The stage theme ("Deep mining 2"). The founder's film carries it from FILM_SONG_OFFSET seconds in; the game continues it
## from the matching position when the film ends (measured by chroma correlation: video 26.53 s == song 0 s).
const STAGE_THEME := "res://src/assets/music/ep2_deep_mining_theme.mp3"
const FILM_SONG_OFFSET := 26.53
const FILM_OFFSET := Vector3(4000.0, 0.0, 0.0)   # the film set lives far from the room: no shared light, no overlap
const COMPANION_ID := "inferno_bull"

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
var _film: CliffJumpCinematic = null            # the in-engine fallback film (used only if the video is missing)
var _vfilm: Ep2VideoFilm = null                 # the Seedance film
var _room_built: bool = false
var _wake_i: int = 0
var _has_helmet: bool = false
var _helmet_node: Node3D = null
var _player_skel: Skeleton3D = null
var _player_pose: RunnerArmRest = null
## Set dressing handles + the procedural performance (see _animate). The Bull model is a statue (no skeleton),
## so his acting is whole-body: breathing, weight shift, a lean into the hand-off, a raised glass, cigar puffs.
var _dressing: Dictionary = {}
var _bull: Ep2Actor = null            # rigged Inferno Bull: walks, turns, reaches (arm IK), carries props
var _show: FacilityShow = null        # the scripted performance (data-driven sequencer)
var _show_active: bool = false        # a scripted beat owns Lil Blunt and the camera
var _show_blocks_control: bool = false
var _glass_node: Node3D = null
var _bull_guard_rifle: Node3D = null # Bull's own gun, separate from the traded reward
var _bull_rest_arm: Ep2BullRestArm = null
var _cigar_tip: MeshInstance3D = null
var _cigar_smoke: CPUParticles3D = null
var _anim_t: float = 0.0
var _helmet_on_head: bool = false
var _rifle_in_hands: bool = false
var _hop_y: float = 0.0               # Lil Blunt's little joy-hop
var _hop_v: float = 0.0
var _walk_phase: float = 0.0
var _stand_t: float = -1.0            # seconds since he began to stand (-1 = still seated, 99 = standing)
var _stand_len: float = 0.0
var _settle: float = 0.0
var btc_paid: int = 0
var _coin: Node3D = null
var _pay_t: float = -1.0
var _vo_lens: Dictionary = {}
var _bull_blocker_i: int = -1
var _fps: bool = false
var _fps_hud: CanvasLayer = null
var _flash_light: OmniLight3D = null
var _recoil: float = 0.0
var _mold_broken: Array = []
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
## Coming to: high and to the side, so he is IN frame on the floor with the Bull standing over him.
const CAM_WAKE := [Vector3(2.1, 2.7, 0.4), -26.0, 180.0]
const FPS_EYE_HEIGHT := 1.55
const FPS_FOV := 78.0
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
const MOLTEN_SURFACE_ENERGY := 1.3   # broad flowing gold keeps colour variation; local lights supply the heat
const ROCK_TEX := "res://src/episode2/assets/textures/tex_rock_wall.jpg"
const GRAVEL_TEX := "res://src/episode2/assets/textures/tex_gravel.jpg"
const TIMBER_TEX := "res://src/episode2/assets/textures/tex_timber.jpg"
const RIFLE_MODEL := "res://src/episode2/assets/winchester_1886.glb"
const CRUCIBLE_MODEL := "res://src/episode2/assets/crucible.glb"
const INGOT_RACK_MODEL := "res://src/episode2/assets/ingot_rack.glb"
const WHISKEY_MODEL := "res://src/episode2/assets/whiskey_glass.glb"
const COIN_MODEL := "res://src/episode2/assets/btc_coin.glb"
const GLASS_MODEL := WHISKEY_MODEL
const GLASS_HEIGHT := 0.26
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
	_hop_y = 0.0
	_hop_v = 0.0
	_show_active = false
	_show_blocks_control = false
	btc_paid = 0
	_pay_t = -1.0
	_fps = false
	_recoil = 0.0
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
	_mold_broken = []
	for _m in MOLD_TARGETS:
		_mold_broken.append(false)
	_room_built = false
	if _beat == Beat.CINEMATIC and _start_video_film():
		# The film starts THIS frame; the room is built a moment later (step), never before it.
		beat_changed.emit(_beat)
		return
	_build_visuals()
	_room_built = true
	_sync_visuals()
	if _beat == Beat.CINEMATIC:
		_start_film()
	beat_changed.emit(_beat)


## Start the pre-rendered transition film. False when the video is not in the build (-> the in-engine film).
func _start_video_film() -> bool:
	var vf := Ep2VideoFilm.new()
	vf.name = "Ep2VideoFilm"
	if not vf.prepare(FILM_VIDEO, FILM_SECONDS):
		vf.free()
		return false
	_vfilm = vf
	vf.continue_track = STAGE_THEME
	vf.song_video_offset = FILM_SONG_OFFSET
	vf.drive_externally()
	add_child(vf)
	vf.finished.connect(_on_video_film_finished, CONNECT_ONE_SHOT)
	vf.start()
	return true


## Make sure the hideout exists (idempotent).
func _ensure_room() -> void:
	if _room_built:
		return
	_room_built = true
	_build_visuals()
	_sync_visuals()


## The film ends where target practice begins: the story the film told (patched up, introductions, the Winchester
## and the helmet for one Bitcoin) is applied to the game state, and play resumes in first person at the mold rack.
func _on_video_film_finished() -> void:
	_ensure_room()
	_stand_t = 99.0
	_return_bull_glass()
	if _bull:
		_bull.position = BULL_REST
		_bull.facing = PI
		_bull.rotation.y = PI
		_bull.play(BULL_IDLE, 1.0, 0.0)
		_bull_rest_arm.resting = true
	_player_pos = HAND_MARK
	_item_delivered("rifle")
	_item_delivered("helmet")
	btc_paid += BTC_PRICE
	payment_made.emit(BTC_PRICE)
	var sun := get_node_or_null("Sun") as DirectionalLight3D
	if sun:
		sun.visible = true
	if _camera and is_instance_valid(_camera):
		_camera.make_current()
	if _vfilm and is_instance_valid(_vfilm):
		_vfilm.release(0.8)         # the room was built behind its black: fade the black away, then it frees itself
	_vfilm = null
	_beat = Beat.HELMET
	_advance()      # -> VERB_TEACH: first person, the mold rack


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
	# Instantiated without setup() — still show the room rather than a void. Deferred: the session root calls
	# setup() in the same frame as add_child, and setup() decides when the room is built (after the film starts).
	_ready_fallback.call_deferred()


func _ready_fallback() -> void:
	if not _running and not _room_built:
		_ensure_room()


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
		if _vfilm and is_instance_valid(_vfilm):
			_vfilm.step(delta)      # the facility owns the film's clock (physics time), never both
			return
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

	if _show and _show.running:
		_show.step(delta)
	match _beat:
		Beat.WAKE:
			if _hold <= 0.0:
				_wake_i += 1
				if _wake_i < WAKE_LINES.size():
					_hold = _vo_len(str(WAKE_LINES[_wake_i])) + 0.3
					_speak(str(WAKE_LINES[_wake_i]))
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
			# They leave TOGETHER: the Bull leads to the Fort Knox door and you follow in first person.
			# Resolve once you reach the door, never before his line has finished.
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

## `interact` (E). The whole performance is scripted and plays by itself (Inferno Bull talks at a natural pace,
## walks, hands things over), so E never skips a line; it only nudges a stalled conversation along once he has
## finished talking. Returns true when it advanced something.
func start_rig(_payment: String = "") -> bool:
	if not _running or _resolved or _hold > 0.0 or _show_active:
		return false
	if _beat == Beat.DRINK and not (_show and _show.running):
		_advance()
		return true
	return false


## `attack` (LMB). On foot with the Winchester it fires: a muzzle flash, a kick, a shot. During the verb teach
## the shot breaks the casting mold under the crosshair. Returns true when a mold broke.
func shoot() -> bool:
	if not _running or _resolved or not _has_winchester or _show_active:
		return false
	_fire_fx()
	if _beat != Beat.VERB_TEACH or _molds_left <= 0:
		return false
	var idx: int = _mold_under_crosshair()
	if idx < 0:
		return false
	_mold_broken[idx] = true
	_molds_left -= 1
	_sync_visuals()
	return true


## Which unbroken mold is the crosshair on (index) or -1. A forgiving cone: this is a tutorial, not a test.
func _mold_under_crosshair() -> int:
	var eye: Vector3 = _eye_position()
	var cp: float = cos(_look_pitch)
	var dir := Vector3(sin(_look_yaw) * cp, sin(_look_pitch), cos(_look_yaw) * cp)
	var best: int = -1
	var best_d: float = 0.7
	for i in _mold_nodes.size():
		if _mold_broken[i] or not is_instance_valid(_mold_nodes[i]):
			continue
		var c: Vector3 = (_mold_nodes[i] as Node3D).global_position
		var t: float = (c - eye).dot(dir)
		if t < 0.5 or t > 30.0:
			continue
		var d: float = (c - (eye + dir * t)).length()
		if d < best_d:
			best_d = d
			best = i
	return best


func _eye_position() -> Vector3:
	return Vector3(_player_pos.x, _player_pos.y + FPS_EYE_HEIGHT, _player_pos.z)


## Point the view at a world position (tests, and the aim assist after a hand-over).
func aim_at(p: Vector3) -> void:
	var d: Vector3 = p - _eye_position()
	_look_yaw = atan2(d.x, d.z)
	_look_pitch = clampf(atan2(d.y, Vector2(d.x, d.z).length()), LOOK_PITCH_MIN, 1.2)


func get_mold_position(i: int) -> Vector3:
	return (_mold_nodes[i] as Node3D).global_position if i >= 0 and i < _mold_nodes.size() else Vector3.ZERO


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
	return not _show_blocks_control


func _in_scripted_handover() -> bool:
	return _show_active


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
		_hold = _vo_len(str(WAKE_LINES[0])) + 0.3
		_speak(str(WAKE_LINES[0]))
	if beat == Beat.SIZING or beat == Beat.HANDOFF or beat == Beat.HELMET:
		_to_hand_mark()
	if beat == Beat.VERB_TEACH:
		_enter_fps()
	if beat == Beat.TERMS or beat == Beat.PROMISE:
		_move_input = Vector2.ZERO
	var steps: Array = FacilityShow.steps_for(self, beat)
	if not steps.is_empty():
		if _show == null:
			_show = FacilityShow.new()
			_show.f = self
		# Dialogue-only beats keep Lil Blunt free to look around; choreographed ones own him and the camera.
		_show_blocks_control = beat in [Beat.SIZING, Beat.HANDOFF, Beat.HELMET, Beat.TERMS, Beat.PROMISE]
		_show_active = true
		_show.start(steps)


## The show for the current beat finished: move the story on.
func _on_show_done() -> void:
	if _beat == Beat.HELMET:
		_return_bull_glass()
	_show_active = false
	_show_blocks_control = false
	match _beat:
		Beat.DRINK, Beat.SIZING, Beat.HANDOFF, Beat.HELMET, Beat.TERMS, Beat.PROMISE:
			_advance()
		_:
			pass


## Length in seconds of a committed voice clip (so holds always match the real audio, never a stale constant).
func _vo_len(id: String) -> float:
	if _vo_lens.has(id):
		return float(_vo_lens[id])
	var path: String = "res://src/assets/sounds/voice/%s.mp3" % id
	var l: float = 3.0
	if ResourceLoader.exists(path):
		var st: AudioStream = load(path)
		if st:
			l = st.get_length()
	_vo_lens[id] = l
	return l


## He talks while he walks back with the item.
func _begin_carry_line(id: String) -> void:
	_hold = _vo_len(id)
	_speak(id)


## The Winchester / helmet arrives: flags, signals, a hop.
func _item_delivered(item: String) -> void:
	if item == "rifle":
		_has_winchester = true
		_rifle_in_hands = true
		weapon_granted.emit(WINCHESTER_ID)
	else:
		_has_helmet = true
		_helmet_on_head = true
		_hop_v = 3.6
		gear_granted.emit(HELMET_ID)


## World point an item travels to when handed over.
func item_target(item: String) -> Vector3:
	var base: Vector3 = _player_node.position if _player_node else _player_pos
	if item == "rifle":
		return base + Basis(Vector3.UP, _player_yaw) * Vector3(0.45, 1.05, 0.25)
	return base + Vector3(0.0, 1.98, 0.0)


# --- Payment: ONE Bitcoin for the rifle and the helmet ------------------------------------------------------

func _begin_payment() -> void:
	_pay_t = 0.0
	if _coin == null or not is_instance_valid(_coin):
		# The founder's Bitcoin (Meshy oLKt9Y): unit-diameter GLB, face normal +Z, scaled to 0.34 m.
		_coin = Node3D.new()
		_coin.name = "BitcoinCoin"
		var cm: Node3D = (load(COIN_MODEL) as PackedScene).instantiate()
		cm.scale = Vector3.ONE * 0.34
		_coin.add_child(cm)
		_visuals.add_child(_coin)
	_coin.visible = true
	_coin.global_position = _player_pos + Vector3(0.0, 1.1, 0.0)


func _payment_done() -> bool:
	return _pay_t < 0.0


func _animate_payment(delta: float) -> void:
	if _pay_t < 0.0 or _coin == null:
		return
	_pay_t += delta
	var k: float = clampf(_pay_t / 0.9, 0.0, 1.0)
	var from: Vector3 = _player_pos + Vector3(0.0, 1.1, 0.0)
	var to: Vector3 = _bull.hand_world("Right") if _bull else BULL_POSITION + Vector3(0.0, 1.6, 0.0)
	_coin.global_position = from.lerp(to, k) + Vector3(0.0, 0.5 * sin(k * PI), 0.0)
	_coin.rotation = Vector3(0.0, _pay_t * 14.0, 0.0)
	if k >= 1.0:
		_coin.visible = false
		_pay_t = -1.0
		btc_paid += BTC_PRICE
		_hop_v = 2.2
		payment_made.emit(BTC_PRICE)
		var am: Node = get_node_or_null("/root/AudioManager")
		if am and am.has_method("play_sfx"):
			am.play_sfx("coin")


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
	# HARD ZERO on both economy fields. Chamber 0 is a story beat; the white paper's economy begins at Fort Knox.
	# The session root runs its commit path over this result and correctly moves nothing. `btc_paid` is the
	# narrative price of the gear (a ledger line, not a GoldMine movement).
	chamber_cleared.emit({
		"story": true,
		"chamber": "smelting_facility",
		"gold_awarded": 0,
		"gold_forfeited": 0,
		"btc_paid": btc_paid,
		"companion": COMPANION_ID,
		"weapon": WINCHESTER_ID,
		"next_mode": "fps",
		"seconds": _elapsed,
	})


## Choose the framing: first person from the verb teach on; the player's follow camera whenever he has control
## in the hideout; a TWO-SHOT director camera while a scripted beat owns the view (the Bull walks, reaches, hands
## things over); the wake-up shot before that.
func _update_camera(delta: float) -> void:
	if _camera == null or not is_instance_valid(_camera):
		return
	if _fps:
		_fps_camera(delta)
		return
	if has_player_control():
		_follow_camera(delta)
		return
	if _show_active and _bull != null:
		_two_shot_camera(delta)
		return
	var want: Array = CAM_WAKE if _beat == Beat.WAKE else CAM_WIDE
	_cam_target_pos = want[0]
	_cam_target_pitch = float(want[1])
	_cam_target_yaw = float(want[2])
	var t: float = clampf(CAM_LERP * delta, 0.0, 1.0)
	_camera.position = _camera.position.lerp(_cam_target_pos, t)
	# Slerp the orientation (Euler lerps spin the long way round after a look_at from another camera).
	var goal := Basis.from_euler(Vector3(deg_to_rad(_cam_target_pitch), deg_to_rad(_cam_target_yaw), 0.0))
	_camera.basis = Basis(_camera.basis.orthonormalized().get_rotation_quaternion().slerp(goal.get_rotation_quaternion(), t))


## Keeps Bull and Lil Blunt in frame from the room side (-Z), low and close like the founder's target image; follows
## the Bull alone while he is off at the gun wall.
func _two_shot_camera(delta: float) -> void:
	var b: Vector3 = _bull.position
	var p: Vector3 = _player_pos
	var focus: Vector3 = (b + p) * 0.5 if b.distance_to(p) < 4.2 else b
	var span: float = clampf(b.distance_to(p), 2.0, 4.5)
	var side := Vector3(b.z - p.z, 0.0, p.x - b.x)
	side = side.normalized() if side.length_squared() > 1e-4 else Vector3(0.0, 0.0, -1.0)
	if side.z > 0.0:
		side = -side
	var want: Vector3 = focus + side * (3.2 + span * 0.45) + Vector3(0.0, 1.55, 0.0)
	want.x = clampf(want.x, -(ROOM_X + 0.3), ROOM_X + 0.3)
	want.z = clampf(want.z, ENTRY_POSITION.z, 17.0)
	_camera.position = _camera.position.lerp(want, clampf(2.4 * delta, 0.0, 1.0))
	var target: Vector3 = focus + Vector3(0.0, 1.45, 0.0)
	var goal: Basis = Basis.looking_at(target - _camera.position, Vector3.UP)
	_camera.basis = Basis(_camera.basis.orthonormalized().get_rotation_quaternion().slerp(goal.get_rotation_quaternion(), clampf(3.0 * delta, 0.0, 1.0)))


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
	_camera.fov = lerpf(_camera.fov, 68.0, clampf(6.0 * delta, 0.0, 1.0))
	var look_at_p: Vector3 = target + dir * 2.0
	if _camera.position.distance_squared_to(look_at_p) > 1e-4:
		_camera.look_at(look_at_p, Vector3.UP)


## FIRST PERSON (the shooter/RPG mode, Episode2Mode.FPS): the camera IS Lil Blunt's eye, mouse look, fov 78.
func _fps_camera(delta: float) -> void:
	var bob: float = sin(_walk_phase) * 0.035 if _moving else 0.0
	_camera.position = _eye_position() + Vector3(0.0, bob, 0.0)
	var cp: float = cos(_look_pitch)
	var dir := Vector3(sin(_look_yaw) * cp, sin(_look_pitch), cos(_look_yaw) * cp)
	_camera.look_at(_camera.position + dir, Vector3.UP)
	_camera.fov = lerpf(_camera.fov, FPS_FOV, clampf(6.0 * delta, 0.0, 1.0))


func _distance_to_bull() -> float:
	var bp: Vector3 = _bull.position if _bull else BULL_POSITION
	return Vector2(bp.x - _player_pos.x, bp.z - _player_pos.z).length()


## The hand-overs are staged: Lil Blunt steps onto his mark (the camera cuts to the two-shot, so it is not a
## visible teleport) and stops; control returns when the scripted beat ends.
func _to_hand_mark() -> void:
	_player_pos = HAND_MARK
	_vel_y = 0.0
	_move_input = Vector2.ZERO
	var bp: Vector3 = _bull.position if _bull else BULL_POSITION
	_player_yaw = atan2(bp.x - HAND_MARK.x, bp.z - HAND_MARK.z)


## Where the Bull stands when he talks to you in first person: just ahead of you on your right.
func companion_spot() -> Vector3:
	var fwd := Vector3(sin(_look_yaw), 0.0, cos(_look_yaw))
	var right := Vector3(-fwd.z, 0.0, fwd.x)
	return Vector3(_player_pos.x, 0.0, _player_pos.z) + fwd * 2.4 + right * 2.7


# --- Getters (HUD + tests) ---------------------------------------------------------
func get_beat() -> int: return _beat
func get_beat_name() -> String: return Beat.keys()[clampi(_beat, 0, Beat.size() - 1)]
func has_winchester() -> bool: return _has_winchester
func has_helmet() -> bool: return _has_helmet
func get_film() -> CliffJumpCinematic: return _film if _film and is_instance_valid(_film) else null
func get_video_film() -> Ep2VideoFilm: return _vfilm if _vfilm and is_instance_valid(_vfilm) else null
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
func is_fps() -> bool: return _fps
func get_btc_paid() -> int: return btc_paid
func get_bull() -> Ep2Actor: return _bull
func get_show() -> FacilityShow: return _show
func is_show_active() -> bool: return _show_active
## Which Episode 2 mode this scene is in right now (the mode drives damage, input hints and the camera).
func get_episode_mode() -> int:
	return Episode2Mode.Mode.FPS if _fps else Episode2Mode.Mode.HIDEOUT
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
	_room_built = true
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
	# Actual player-view furnace pixels clipped both R/G on 16.5% of its face at
	# energy 2.2, erasing the flowing crust. Keep the shader and its lights intact.
	channel.set_shader_parameter("energy", MOLTEN_SURFACE_ENERGY)
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
	for spec in [Vector3(-4.8, 0.0, CHANNEL_Z + 2.0), Vector3(4.8, 0.0, CHANNEL_Z + 1.8), Vector3(-2.8, 0.0, CHANNEL_Z + 3.4)]:
		HideoutDressing.add_cauldron(_visuals, spec, channel, 1.85)
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
		glow.light_energy = 2.8
		glow.omni_range = 7.0
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
	_box(Vector3(4.8, 4.6, 2.6), Vector3(-6.3, 2.3, 17.4), rock_dark)
	var mouth := StandardMaterial3D.new()
	mouth.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mouth.albedo_color = Color(1.0, 0.45, 0.12)
	_box(Vector3(2.5, 2.2, 0.2), Vector3(-6.3, 1.7, 16.05), channel)
	var fl := OmniLight3D.new()
	fl.light_color = Color(1.0, 0.6, 0.25)
	fl.light_energy = 4.0
	fl.omni_range = 6.5
	fl.position = Vector3(-6.3, 2.0, 14.8)
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
	bull_key.omni_range = 6.0
	bull_key.light_color = Color(1.0, 0.87, 0.70)
	bull_key.shadow_enabled = true
	bull_key.position = BULL_POSITION + Vector3(-1.8, 2.8, -2.2)
	_visuals.add_child(bull_key)
	_build_bull(timber)

	# --- the verb-teach target: a rack of EMPTY casting molds (safe by design; see the spec).
	for i in MOLD_TARGETS:
		var mold := BoxMesh.new()
		mold.size = Vector3(0.7, 0.45, 0.5)
		var mold_mat := Ep2Palette.make_unique("iron")
		mold_mat.albedo_color = Color(0.16, 0.12, 0.10)       # forged iron, not a cream block
		mold_mat.emission_enabled = true
		mold_mat.emission = Color(1.0, 0.45, 0.12)
		mold_mat.emission_energy_multiplier = 0.25
		var mi := _mesh(mold, mold_mat,
			MOLD_RACK_POSITION + Vector3(0.0, 1.05, float(i) * 1.1 - 1.1))
		_mold_nodes.append(mi)
	_box(Vector3(1.1, 0.8, 3.6), MOLD_RACK_POSITION + Vector3(0.0, 0.4, 0.0), timber)
	# TARGET PRACTICE IS A STUB (founder 2026-10-02: he is still designing the range): a marked lane on the floor and a
	# "locked" sign. No new set dressing; the mold rack stays the working verb-teach target until his art lands.
	var lane_mat := StandardMaterial3D.new()
	lane_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lane_mat.albedo_color = Color(1.0, 0.62, 0.15, 1.0)
	_box(Vector3(0.7, 0.02, 5.6), MOLD_RACK_POSITION + Vector3(0.0, 0.015, -4.4), lane_mat)
	var lock := Label3D.new()
	lock.text = "RANGE LOCKED - founder art incoming"
	lock.font_size = 40
	lock.pixel_size = 0.004
	lock.modulate = Color(1.0, 0.75, 0.3)
	lock.outline_size = 12
	lock.position = MOLD_RACK_POSITION + Vector3(0.0, 2.2, 0.0)
	lock.rotation.y = PI * 0.5
	_visuals.add_child(lock)

	# --- LIL BLUNT: the real hero (not the old primitive), standing in the room, lying when he comes to.
	_player_node = _build_player()
	# The helmet hangs on its peg at the end of the gun wall; the Winchester is the middle rifle on the rack.
	_helmet_node = _build_helmet()
	_helmet_node.position = HELMET_PEG + Vector3(0.3, -0.05, 0.0)
	_visuals.add_child(_helmet_node)

	# --- the hangout: alcove, trophies, armory, Gatling, poster, braziers (see HideoutDressing).
	_dressing = HideoutDressing.build(_visuals)
	_blockers = (_dressing.get("blockers", []) as Array).duplicate()
	_rifle_node = _dressing.get("rack_rifle") as Node3D
	_bull_blocker_i = _blockers.size()
	_blockers.append([Vector2(BULL_POSITION.x, BULL_POSITION.z), 0.95])
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
const HELMET_MODEL := "res://src/episode2/assets/miner_helmet.glb"


## The founder's own helmet (Meshy tVC8jD), baked by tools/ep2_forge/install_founder_props.py.
func _build_helmet() -> Node3D:
	var h := Node3D.new()
	h.name = "MinerHelmet"
	h.add_child((load(HELMET_MODEL) as PackedScene).instantiate())
	var beam := SpotLight3D.new()
	beam.light_color = Color(1.0, 0.9, 0.65)
	beam.light_energy = 2.0
	beam.spot_range = 9.0
	beam.spot_angle = 22.0
	beam.position = Vector3(0.0, 0.14, 0.3)
	beam.rotation = Vector3(0.0, PI, 0.0)
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
	var rock_material: StandardMaterial3D = _tex(ROCK_TEX, Color(0.46, 0.38, 0.30), 0.28)
	for mesh in b.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = rock_material
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
		we.environment.ambient_light_energy = 0.75
		we.environment.ambient_light_color = Color(0.74, 0.72, 0.68)
		we.environment.glow_intensity = 0.85
		we.environment.glow_hdr_threshold = 0.95
		# Founder 2026-10-01: "I don't like the greyscale" - push the grade toward the target's saturated gold.
		we.environment.adjustment_enabled = true
		we.environment.adjustment_saturation = 1.0
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
		var broken: bool = bool(_mold_broken[i]) if i < _mold_broken.size() else i >= _molds_left
		mi.position.y = 0.25 if broken else 1.05
		mi.rotation.z = deg_to_rad(72.0) if broken else 0.0
		var m: StandardMaterial3D = mi.material_override
		if m:
			m.albedo_color = Color(0.08, 0.07, 0.07) if broken else Color(0.16, 0.12, 0.10)
			m.emission_energy_multiplier = 0.0 if broken else 0.25


# --- Inferno Bull: rigged, walks, reaches, drinks (founder 2026-10-02) -------------------------------------
const BULL_IDLE := "Idle_02"
const BULL_SIT_CLIPS := "res://src/episode2/assets/inferno_bull_sit_clips.glb"
const BULL_WALK_CLIP := "res://src/episode2/assets/inferno_bull_walking_clip.glb"
const BULL_RUN_CLIP := "res://src/episode2/assets/inferno_bull_running_clip.glb"
const BULL_SIT := "Sit_and_Drink"
const BULL_STAND_UP := "Sit_to_Stand_Transition_M"
const BULL_SIP := "Stand_and_Drink"
const STAND_UP_SPEED := 1.8
## Root drift between Meshy clips (rig units, measured with a skeleton probe): Sit_to_Stand starts from a chair
## 1.24 back and 0.25 higher than Sit_and_Drink's seat and ends 0.49 back of the standing clips' hips. The model is
## offset by a correction blended across the stand-up so he rises from HIS crate and ends on his mark.
const STAND_CORR_START := Vector3(0.02, -0.25, 1.24)
const STAND_CORR_END := Vector3(-0.16, 0.0, 0.49)


func _build_bull(timber: StandardMaterial3D) -> void:
	_bull = Ep2Actor.new()
	_bull.name = "InfernoBull"
	_bull.position = BULL_POSITION
	_visuals.add_child(_bull)
	_stand_t = -1.0
	_stand_len = 0.0
	_settle = 0.0
	var ok: bool = _bull.setup(BULL_RIG_MODEL, BULL_RIG_H, BULL_HEIGHT,
		{"walk": BULL_WALK_CLIP, "run": BULL_RUN_CLIP}, [BULL_IDLE, BULL_SIT, BULL_SIP])
	if not ok:
		# No model: a visible stand-in, never nothing.
		var bm := BoxMesh.new()
		bm.size = Vector3(1.4, 2.4, 1.0)
		var fb := MeshInstance3D.new()
		fb.mesh = bm
		fb.material_override = Ep2Palette.make("bandit")
		fb.position = Vector3(0, 1.2, 0)
		_bull.add_child(fb)
		return
	_bull.add_all_clips(BULL_SIT_CLIPS)
	if _bull.anim:
		for c in [BULL_SIT, BULL_STAND_UP]:
			if _bull.anim.has_animation(c) and c == BULL_SIT:
				_bull.anim.get_animation(c).loop_mode = Animation.LOOP_LINEAR
		_stand_len = _bull.anim.get_animation(BULL_STAND_UP).length / STAND_UP_SPEED if _bull.anim.has_animation(BULL_STAND_UP) else 0.0
	_bull.idle_clip = BULL_IDLE
	_bull.facing = PI                 # he faces the room (-Z), seated on his crate
	_bull.rotation.y = PI
	_bull.play(BULL_SIT if _bull.anim and _bull.anim.has_animation(BULL_SIT) else BULL_IDLE, 1.0, 0.0)
	_fix_bull_materials(_bull.model)
	# His seat: a sturdy crate under the Sit_and_Drink hips (0.70 rig units -> 0.85 m), behind him.
	var seat := _box(Vector3(1.0, 0.66, 0.9), Vector3.ZERO, timber)
	# Parented to the ROOM, never to the rig: a seat on the actor walked across the hideout behind him
	# (founder 2026-10-02 "a box follows Inferno Bull"). It stays where he sat.
	seat.reparent(_visuals, false)
	seat.position = BULL_POSITION + Vector3(0.0, 0.33, 0.18)
	seat.name = "BullSeat"
	_build_bull_props()
	_bull_rest_arm = Ep2BullRestArm.new()
	_bull.skeleton.add_child(_bull_rest_arm)
	_bull.skeleton.skeleton_updated.connect(_sync_bull_hand_props)


## "He looks like an oil patch melting" (founder 2026-10-02): Meshy's rig drops the metallic-roughness texture, so
## glTF's default metallic = 1.0 made every surface a black mirror in a renderer with no reflections. Matte,
## non-metal leather and fur, a warm rim from the forge, and a little self-light so shadows are never pure black.
func _fix_bull_materials(root: Node) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		for i in m.mesh.get_surface_count():
			var src: Material = m.mesh.surface_get_material(i)
			if src is StandardMaterial3D:
				var d: StandardMaterial3D = (src as StandardMaterial3D).duplicate()
				d.metallic = 0.0
				d.metallic_specular = 0.25
				d.roughness = 0.78
				d.metallic_texture = null
				d.roughness_texture = null
				d.rim_enabled = true
				d.rim = 0.12
				d.rim_tint = 0.5
				d.emission_enabled = true
				d.emission = Color(1.0, 0.78, 0.55)
				d.emission_texture = d.albedo_texture
				d.emission_energy_multiplier = 0.12
				d.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
				m.set_surface_override_material(i, d)


func is_bull_seated() -> bool:
	return _bull != null and _stand_t < 0.0 and _bull.anim != null and _bull.anim.has_animation(BULL_SIT)


## SIZING: he rises from his crate (the clip's root drift is corrected so he stands on his mark).
func _begin_stand_up() -> void:
	if not is_bull_seated():
		_stand_t = 99.0
		return
	_stand_t = 0.0
	_bull.play(BULL_STAND_UP, STAND_UP_SPEED, 0.3)
	_set_glass_on_table()


## When he stands the whiskey goes down on the table (a separate glass, never skinned to his arm: founder
## 2026-10-02 "liquid arm"). Return it to his hand once the hand-over is finished.
func _set_glass_on_table() -> void:
	if _glass_node == null or not is_instance_valid(_glass_node):
		return
	_glass_node.reparent(_visuals, false)
	_glass_node.top_level = false
	_glass_node.position = HideoutDressing.WHISKEY_TABLE_POS + Vector3(0.55, 1.03 + GLASS_HEIGHT * 0.5, 0.2)
	_glass_node.rotation = Vector3.ZERO


## Restore his glass after the traded equipment leaves his hands. No idle sipping or IK loop.
func _return_bull_glass() -> void:
	if _glass_node and _bull:
		_glass_node.reparent(_bull.holder("LeftHand"), false)
		_glass_node.top_level = true
		_glass_node.scale = Vector3.ONE


## Place rigid props from the final modified bone pose, after animation and IK.
## The complete Winchester GLB node matrix maps its long axis onto scene -Z.
func _sync_bull_hand_props() -> void:
	if _bull == null or _bull.skeleton == null:
		return
	var sk: Skeleton3D = _bull.skeleton
	var forward: Vector3 = Basis(Vector3.UP, _bull.facing) * Vector3.FORWARD
	var across: Vector3 = Basis(Vector3.UP, _bull.facing) * Vector3.RIGHT
	var left: int = sk.find_bone("LeftHand")
	if left >= 0 and _glass_node and _glass_node.get_parent() != _visuals:
		var palm: Vector3 = (sk.global_transform * sk.get_bone_global_pose(left)).origin
		_glass_node.global_transform = Transform3D(Basis.IDENTITY, palm + Vector3.UP * 0.06 - forward * 0.10)
	var carrying_trade: bool = _rifle_node != null and _rifle_node.get_parent() == _bull.holder("RightHand")
	if _bull_guard_rifle:
		_bull_guard_rifle.visible = (_stand_t < 0.0 or _has_helmet) and not carrying_trade
	var gun: Node3D = _rifle_node if carrying_trade else _bull_guard_rifle
	var right: int = sk.find_bone("RightHand")
	if gun == null or not gun.visible or right < 0:
		return
	var palm: Vector3 = (sk.global_transform * sk.get_bone_global_pose(right)).origin
	var stock_axis: Vector3 = Vector3(-1.0, 0.15, -0.10).normalized() if carrying_trade else (across * 0.72 - Vector3.UP * 0.69).normalized()
	var depth: Vector3 = stock_axis.cross(Vector3.UP).normalized()
	var up: Vector3 = depth.cross(stock_axis).normalized()
	gun.global_transform = Transform3D(Basis(-depth, up, -stock_axis).scaled(Vector3.ONE * 1.05), palm - stock_axis * 0.12 - forward * 0.05)


func _stand_up_done() -> bool:
	return _stand_t >= 99.0 or _bull == null or _stand_len <= 0.0


func _bull_play(clip: String, speed: float = 1.0) -> void:
	if _bull:
		_bull.play(clip, speed)


func _build_bull_props() -> void:
	# The WHISKEY: a real tumbler in his left hand (the hand Stand_and_Drink / Sit_and_Drink lift to his mouth),
	# sized in METRES in a bone holder. (The first version was parented in rig units and was ~2 mm tall:
	# "I don't see his whiskey".)
	# The founder's own tumbler (Meshy LKhotS): unit-height GLB scaled to 0.26 m; its base sits on y = 0.
	_glass_node = Node3D.new()
	_glass_node.name = "BullGlass"
	var gm: Node3D = (load(GLASS_MODEL) as PackedScene).instantiate()
	gm.scale = Vector3.ONE * GLASS_HEIGHT
	gm.position = Vector3(0.0, -GLASS_HEIGHT * 0.5, 0.0)
	for mesh in gm.find_children("*", "MeshInstance3D", true, false):
		for i in mesh.mesh.get_surface_count():
			var source: Material = mesh.mesh.surface_get_material(i)
			if source is StandardMaterial3D:
				var mat: StandardMaterial3D = source.duplicate()
				mat.metallic = 0.0
				mat.metallic_texture = null
				mat.roughness = 0.25
				mat.emission_enabled = true
				mat.emission_texture = mat.albedo_texture
				mat.emission = Color(1.0, 0.85, 0.62)
				mat.emission_energy_multiplier = 0.22
				mesh.set_surface_override_material(i, mat)
	_glass_node.add_child(gm)
	var lh: Node3D = _bull.holder("LeftHand")
	if lh:
		lh.add_child(_glass_node)
		_glass_node.top_level = true
		_glass_node.position = GLASS_IN_HAND_POS
	else:
		_glass_node.position = BULL_POSITION + Vector3(0.7, 1.2, -0.3)
		_visuals.add_child(_glass_node)
	_bull_guard_rifle = (load(RIFLE_MODEL) as PackedScene).instantiate()
	_bull_guard_rifle.name = "BullPersonalWinchester"
	_bull.holder("RightHand").add_child(_bull_guard_rifle)
	_bull_guard_rifle.top_level = true
	RunnerView.self_light(_bull_guard_rifle, 0.12, Color(1.0, 0.88, 0.72))
	_fix_bull_materials(_bull_guard_rifle)
	# The cigar the model already holds in his teeth: add the ember glow and the smoke at the bone `headfront`.
	var tip := SphereMesh.new()
	tip.radius = 0.028
	tip.height = 0.056
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
	var fh: Node3D = _bull.holder("Head")
	if fh:
		fh.add_child(_cigar_tip)
		fh.add_child(_cigar_smoke)
		_cigar_tip.position = CIGAR_TIP_IN_HEAD
		_cigar_smoke.position = CIGAR_TIP_IN_HEAD
	else:
		_visuals.add_child(_cigar_tip)
		_visuals.add_child(_cigar_smoke)
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
	_bull.add_child(embers)


const GLASS_IN_HAND_POS := Vector3(0.0, 0.14, 0.04)
const CIGAR_TIP_IN_HEAD := Vector3(0.0, 0.3, 0.55)


func _hideout_plain(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.7
	return m


# --- Performance ----------------------------------------------------------------------------------------
# The Bull walks on a real walk cycle, turns to face what he talks to, reaches with arm IK and carries props
# on his hand bones. Lil Blunt walks on his own cycles, hops for joy, faces the Bull.

func _animate(delta: float) -> void:
	if _visuals == null or not is_instance_valid(_visuals) or not is_inside_tree():
		return
	_anim_t += delta
	_animate_bull(delta)
	_animate_hero(delta)
	_animate_gear(delta)
	_animate_payment(delta)
	_animate_fps(delta)
	_animate_set(delta)


func _smooth(t: float) -> float:
	var c: float = clampf(t, 0.0, 1.0)
	return c * c * (3.0 - 2.0 * c)


func _animate_bull(delta: float) -> void:
	if _bull == null or not is_instance_valid(_bull) or _bull.anim == null:
		return
	# Seated on his crate until he "takes your measure" (SIZING), drinking his whiskey; then he stands.
	if _stand_t < 0.0 and _bull.anim.has_animation(BULL_SIT):
		if _beat >= Beat.SIZING and _stand_t < 0.0 and not (_show and _show.running and _beat == Beat.SIZING):
			_stand_t = 99.0          # skipped past the stand-up (tests / fast-forward)
		else:
			_bull.play(BULL_SIT)
			_bull.model.position = Vector3.ZERO
			_bull.step(delta)
			return
	if _stand_t >= 0.0 and _stand_t < 99.0:
		_stand_t += delta
		var u: float = clampf(_stand_t / maxf(_stand_len, 0.01), 0.0, 1.0)
		var corr: Vector3 = STAND_CORR_START.lerp(STAND_CORR_END, _smooth(u))
		_bull.model.position = corr * _bull.model.scale.x
		if u >= 1.0:
			_stand_t = 99.0
			_settle = 0.4
			_bull.play(BULL_IDLE, 1.0, 0.4)
		_bull.step(delta)
		return
	if _rifle_node and _rifle_node.get_parent() == _bull.holder("RightHand") and _bull.is_walking():
		var front: Vector3 = Basis(Vector3.UP, _bull.facing) * Vector3.BACK
		_bull.reach("Right", _bull.position + front * 0.62 + Vector3.UP * 1.55, 0.35)
	# Standing: the offset eases out over the crossfade into the standing clips.
	_settle = maxf(0.0, _settle - delta)
	_bull.model.position = STAND_CORR_END * (_settle / 0.4) * _bull.model.scale.x
	if not _bull.is_walking() and _bull.reach_weight("Right") < 0.05 and _bull.current_clip() != BULL_IDLE \
			and _bull.current_clip() != "walk" and _bull.current_clip() != BULL_SIP:
		_bull.play(BULL_IDLE)
	if _bull_rest_arm:
		_bull_rest_arm.resting = not _bull.is_walking() and _bull.reach_weight("Right") < 0.01 and _bull.current_clip() == BULL_IDLE
	# Rest means REST: no idle sips, no waving. Arms only move for an action beat (grab, hand-over).
	_follow_player_in_fps(delta)
	if _bull_blocker_i >= 0 and _bull_blocker_i < _blockers.size():
		_blockers[_bull_blocker_i] = [Vector2(_bull.position.x, _bull.position.z), 0.95]
	_bull.step(delta)
	if _cigar_tip:
		var pp: float = fmod(_anim_t + 4.5, 9.0)
		var puff: float = _smooth(pp / 0.6) - _smooth((pp - 1.4) / 0.9)
		(_cigar_tip.material_override as StandardMaterial3D).albedo_color = Color(1.0, 0.42, 0.1).lerp(Color(1.0, 0.85, 0.45), puff)
		_cigar_tip.scale = Vector3.ONE * (1.0 + 0.6 * puff)


## He stays at his rest mark in the hideout and only moves for the show beats. The companion walk starts on the
## EXIT beat (founder 2026-10-02: "he follows Lil Blunt too much; no companion leash in the hideout").
func _follow_player_in_fps(_delta: float) -> void:
	if not _fps or (_show and _show.running) or _bull == null or _beat != Beat.EXIT:
		return
	var spot: Vector3 = companion_spot()
	var d: float = Vector2(_bull.position.x - spot.x, _bull.position.z - spot.z).length()
	if _beat == Beat.EXIT and _hold <= 0.0:
		var door := Vector3(EXIT_POSITION.x + 1.2, 0.0, EXIT_POSITION.z + 0.5)
		if Vector2(_bull.position.x - door.x, _bull.position.z - door.z).length() > 0.5:
			_bull.walk_to(door, 2.4)
		else:
			_bull.stop()
			_bull.face_point(Vector3(_player_pos.x, 0.0, _player_pos.z))
		return
	if d > 1.4 and not _bull.is_walking():
		_bull.walk_to(spot, minf(2.0 + d * 0.5, 4.6))
	elif d > 3.0:
		_bull.walk_to(spot, minf(2.0 + d * 0.5, 4.6))
	elif d <= 1.4 and not _bull.is_walking():
		_bull.face_point(_player_pos + Vector3(sin(_look_yaw), 0.0, cos(_look_yaw)) * 4.0)


## Lil Blunt: walk / run cycle while moving, faces where he walks; faces the Bull when talking; hops for joy.
func _animate_hero(delta: float) -> void:
	if _player_node == null or not is_instance_valid(_player_node) or _beat <= Beat.WAKE:
		return
	var talking: bool = _beat >= Beat.DRINK and _beat <= Beat.PROMISE
	if (talking or _show_active) and not _moving and _bull != null:
		var to_bull: float = atan2(_bull.position.x - _player_pos.x, _bull.position.z - _player_pos.z)
		_player_yaw = lerp_angle(_player_yaw, to_bull, clampf(5.0 * delta, 0.0, 1.0))
	if _hop_v != 0.0 or _hop_y > 0.0:
		_hop_v -= 15.0 * delta
		_hop_y = maxf(0.0, _hop_y + _hop_v * delta)
		if _hop_y <= 0.0:
			_hop_v = 0.0
	var breath: float = 0.010 * sin(_anim_t * 2.1)
	var sway: float = 0.0 if _hero_anim else (sin(_walk_phase) * 0.07 if _moving else 0.02 * sin(_anim_t * 0.9))
	var bob: float = 0.0 if _hero_anim or not _moving else absf(sin(_walk_phase)) * 0.075
	_player_node.basis = Basis.from_euler(Vector3(0.0, _player_yaw, sway)).scaled(Vector3(1.0, 1.0 + breath, 1.0))
	_player_node.position = Vector3(_player_pos.x, (0.35 if _in_cover else 0.0) + _player_pos.y + bob + _hop_y, _player_pos.z)
	_player_node.visible = not _fps
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


## After the hand-over the Winchester follows Lil Blunt (third person) or sits in the viewmodel (first person).
func _animate_gear(_delta: float) -> void:
	if _rifle_node and is_instance_valid(_rifle_node) and _rifle_in_hands and not _fps and _player_node:
		_rifle_node.position = _player_node.position + Basis(Vector3.UP, _player_yaw) * Vector3(0.45, 1.05, 0.25)
		_rifle_node.rotation = Vector3(0.0, _player_yaw, deg_to_rad(-18.0))
		_rifle_node.scale = Vector3.ONE * RIFLE_HAND_SCALE


# --- FIRST PERSON -----------------------------------------------------------------------------------------

## From the verb teach on, the game is a first-person shooter/RPG: the camera becomes Lil Blunt's eye, the
## Winchester becomes a viewmodel, a crosshair appears, and Inferno Bull is the companion at his side.
func _enter_fps() -> void:
	if _fps:
		return
	_fps = true
	if _player_skel:
		var body: Node = _player_skel.get_parent()
		while body and body.get_parent() and body.get_parent() != _visuals:
			body = body.get_parent()
		if body is Node3D:
			(body as Node3D).visible = false
	if _helmet_node and is_instance_valid(_helmet_node):
		_helmet_node.visible = false
	if _rifle_node and is_instance_valid(_rifle_node) and _camera:
		_rifle_node.reparent(_camera, false)
		_rifle_node.top_level = false
		_rifle_node.position = FPS_RIFLE_POS
		_rifle_node.rotation = FPS_RIFLE_ROT
		_rifle_node.scale = Vector3.ONE * 0.85
	if _fps_hud == null:
		_fps_hud = CanvasLayer.new()
		_fps_hud.layer = 12
		add_child(_fps_hud)
		var cross := Control.new()
		cross.set_anchors_preset(Control.PRESET_FULL_RECT)
		cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cross.draw.connect(func() -> void:
			var c: Vector2 = cross.size * 0.5
			var col := Color(1.0, 0.9, 0.5, 0.95)
			for d in [Vector2(-14, 0), Vector2(14, 0), Vector2(0, -14), Vector2(0, 14)]:
				cross.draw_line(c + d * 0.45, c + d, col, 2.5)
			cross.draw_circle(c, 2.0, col))
		_fps_hud.add_child(cross)
	_flash_light = OmniLight3D.new()
	_flash_light.light_color = Color(1.0, 0.8, 0.5)
	_flash_light.light_energy = 0.0
	_flash_light.omni_range = 7.0
	if _camera:
		_camera.add_child(_flash_light)
		_flash_light.position = Vector3(0.2, -0.15, -1.0)
	fps_started.emit()


const FPS_RIFLE_POS := Vector3(0.22, -0.17, -0.42)
const FPS_RIFLE_ROT := Vector3(0.05, 3.2416, 0.0)


## Muzzle flash, recoil kick and the shot itself.
func _fire_fx() -> void:
	_recoil = 1.0
	if _flash_light:
		_flash_light.light_energy = 4.0
	var am: Node = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_sfx"):
		am.play_sfx("ep2_gun_fire_%d" % (1 + int(Time.get_ticks_msec()) % 3))


func _animate_fps(delta: float) -> void:
	if not _fps:
		return
	_recoil = maxf(0.0, _recoil - delta * 7.0)
	if _flash_light:
		_flash_light.light_energy = maxf(0.0, _flash_light.light_energy - delta * 30.0)
	if _rifle_node and is_instance_valid(_rifle_node) and _rifle_node.get_parent() == _camera:
		var sway: float = sin(_anim_t * 1.6) * 0.004 + (sin(_walk_phase * 2.0) * 0.012 if _moving else 0.0)
		_rifle_node.position = FPS_RIFLE_POS + Vector3(0.0, sway, 0.0) + Vector3(0.0, 0.03 * _recoil, 0.1 * _recoil)
		_rifle_node.rotation = FPS_RIFLE_ROT + Vector3(0.12 * _recoil, 0.0, 0.0)


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
