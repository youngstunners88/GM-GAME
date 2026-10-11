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
## The lava river burned Lil Blunt (founder 2026-10-09: it must really hurt); carries the health left.
signal burned(health_left: int)

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
const MOLD_RACK_POSITION := Vector3(RangeDressing.LANE_X, 2.85, -9.3)   # the middle plaque, for aim rigs/tests
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
## The Bull's own shoulder-carried Winchester: bigger than the traded one so it reads on his 2.5 m frame.
const BULL_RIFLE_SCALE := 1.3
const HELMET_IN_HAND_POS := Vector3(0.0, 0.18, 0.1)
## Room bounds for walking, inside the timber alcove walls.
const ROOM_X := 6.3

# --- Verb teach ---------------------------------------------------------------
## Empty casting molds on a rack. A SAFE target: per the spec's open question,
## Chamber 0 has no live enemies — the gun's first real use should have stakes,
## and those stakes belong on the approach to Fort Knox.
const MOLD_TARGETS := 5   # four protocol-logo plaques + one bear, on the back wall (founder 2026-10-04 round 2)
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
## Build the hideout this many seconds into the film (hidden behind it), so the film->range cut is instant.
const PREBUILD_AT := 3.0
const FILM_OFFSET := Vector3(4000.0, 0.0, 0.0)   # the film set lives far from the room: no shared light, no overlap
const COMPANION_ID := "inferno_bull"

# --- THE LAVA RIVER (founder 2026-10-09: "make sure the lava river actually hurts so that Inferno Bull hops over and
# tells Lil Blunt to hop over"). The molten channel across the room is real: from the EXIT beat on, standing in it
# burns (a heart, a kick back to the bank, a flash, a yelp). The plank bridge is gone; the way out is a HOP.
const LAVA_HALF := 0.85              # burn zone is |z - CHANNEL_Z| < LAVA_HALF (the trench is 2.2 m; a little forgiveness)
const LAVA_SAFE_Y := 0.35            # feet this high clear the lava
const MAX_HEALTH := 3
const BURN_COOLDOWN := 0.9
## The interlude that follows the hideout: the mine lift up two floors to the surface (skill ep2-interlude-chain).
const NEXT_CHAMBER := "mine_lift"
var _health: int = MAX_HEALTH
var _lava_on: bool = false
var _lava_bank: float = -1.0        # which bank he last stood on: -1 near (hideout) side, +1 far (lift) side
var _burn_cd: float = 0.0
var _burns: int = 0

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
var _film_3d_off: bool = false       # the viewport 3D pass is disabled while the film covers the screen
var _room_built: bool = false
var _room_ready: bool = false       # the room is COMPLETELY built (a sliced pre-build sets _room_built first)
var _build_slice: bool = false       # spread _build_visuals over frames (only while the film covers the screen)
signal room_ready
var _film_played: bool = false   # the founder's cliff-to-hideout film actually ran this session (Ep2Canon gating)
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
var _bull_rifle_ready: bool = false
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
var _hud_ctl: Ep2FpsHud = null
# --- the target-practice lesson (skill ep2-range-lesson) ---
## Inferno leads Lil Blunt to the range (LEAD), DEMONSTRATES load / aim / fire (DEMO), then the player does each
## step in turn: LOAD (R), AIM (hold RMB), FIRE (LMB) and PRACTICE on all three plates. The rifle is locked until
## he has taught it (founder 2026-10-04: "the rifle doesn't fire until Inferno teaches Lil Blunt to load it, aim
## and fire").
enum Lesson { OFF, LEAD, DEMO, LOAD, AIM, FIRE, PRACTICE, DONE }
const BULL_DEMO := RangeDressing.BULL_LINE         # beside the firing line, facing the target wall (range_dressing owns the spot)
const LESSON_ARRIVE_RADIUS := 2.6                   # how close to the firing line starts the demo
const AIM_HOLD_SECONDS := 0.7                       # ADS must be held this long to count as "aimed"
const NAG_SECONDS := 14.0
const LESSON_STEPS := 4
var _gun: Ep2Winchester = Ep2Winchester.new()
var _lesson: int = Lesson.OFF
var _lesson_t: float = 0.0
var _lead_done: bool = false
var _aim_held: float = 0.0
var _nag_t: float = 0.0
var _hold_line_cd: float = 0.0
var _empty_line_cd: float = 0.0
var _cam_kick: float = 0.0
var _vm_low: float = 0.0
var _vm_lag: Vector2 = Vector2.ZERO
var _look_delta: Vector2 = Vector2.ZERO
var _sight_h: float = 0.0
var _flash_t: float = 0.0
var _fov_extra: float = 0.0
var _muzzle_flash: MeshInstance3D = null
var _later_calls: Array = []                        # [seconds_left, Callable]
var _rng := RandomNumberGenerator.new()
## Test hook: 0 = a perfectly steady hand (headless gates aim and expect a hit); 1 = the real spread.
var spread_scale: float = 1.0
var _hit_first: bool = false
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
const FPS_ADS_FOV := 58.0              # aimed down the sights: a ~1.3x zoom, the Modern Warfare ADS feel
const ADS_LOOK_SCALE := 0.55           # mouse look slows while aimed
const ADS_MOVE_SCALE := 0.55           # ...and so does walking
const CAM_LERP := 1.8          # units/sec — a push-in, not a snap

var _visuals: Node3D = null
var _camera: Camera3D = null
var _cam_target_pos: Vector3 = CAM_WIDE[0]
var _cam_target_pitch: float = float(CAM_WIDE[1])
var _cam_target_yaw: float = 180.0
var _player_node: Node3D = null
var _mold_nodes: Array = []
var _range_blockers: Array = []
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
const GLASS_HEIGHT := 0.31
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
	_gun = Ep2Winchester.new()
	_connect_gun()
	_lesson = Lesson.OFF
	_lesson_t = 0.0
	_lead_done = false
	_aim_held = 0.0
	_nag_t = 0.0
	_cam_kick = 0.0
	_hit_first = false
	_later_calls.clear()
	_room_built = false
	_film_played = false
	if _beat == Beat.CINEMATIC and _start_video_film():
		# The film starts THIS frame; the room is built a moment later (step), never before it.
		beat_changed.emit(_beat)
		return
	_build_visuals()
	_room_built = true
	_room_ready = true
	_sync_visuals()
	if _beat == Beat.CINEMATIC:
		_start_film()
		_show_film_proof("FILM in-engine fallback | the video file was missing or not decodable (see console [VIDEO])")
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
	# The film covers the whole screen, so the 3D world behind it is invisible - but it was still being RENDERED every frame
	# (lights, shadows, the half-built hideout). On a weak GPU / the web that starves the Theora decoder: the film stutters or
	# crawls ("the video isn't playing"). Switch the 3D pass off while the film plays; it comes back the moment it ends.
	_film_3d_off = true
	get_viewport().disable_3d = true
	return true


## Build the hideout BEHIND the film, one slice per frame (the room used to be one ~0.8 s synchronous build, which froze
## and stuttered the film picture and sound - founder 2026-10-05 "the video glitches"; skill ep2-seamless-transition).
func _prebuild_room() -> void:
	if _room_built:
		return
	_build_slice = true
	await _build_visuals()
	_build_slice = false
	_sync_visuals()
	_room_ready = true
	room_ready.emit()


## A small corner line right after the film saying how it ended (end / skip_hold / stall / decoder_early ...), so "the video
## isn't playing" can be settled from a screenshot instead of guessing (skill ep2-film-always-plays). Fades after 12 s.
func _show_film_proof(override: String = "") -> void:
	var text: String = override
	if text == "":
		text = _vfilm.summary() if _vfilm and is_instance_valid(_vfilm) else "FILM ? | no video node"
	var layer := CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	var lab := Label.new()
	lab.text = text
	lab.add_theme_font_size_override("font_size", 13)
	lab.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	lab.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	lab.position = Vector2(10.0, -26.0)
	layer.add_child(lab)
	var tw := create_tween()
	tw.tween_interval(10.0)
	tw.tween_property(lab, "modulate:a", 0.0, 2.0)
	tw.tween_callback(layer.queue_free)


## Make sure the hideout exists (idempotent).
func _ensure_room() -> void:
	if _room_built:
		return
	_room_built = true
	_build_visuals()
	_sync_visuals()
	_room_ready = true


## The film ends where target practice begins: the story the film told (patched up, introductions, the Winchester
## and the helmet for one Bitcoin) is applied to the game state, and play resumes in first person at the mold rack.
func _restore_3d_after_film() -> void:
	if _film_3d_off:
		_film_3d_off = false
		if is_inside_tree():
			get_viewport().disable_3d = false


func _exit_tree() -> void:
	_restore_3d_after_film()


func _on_video_film_finished() -> void:
	_restore_3d_after_film()
	_film_played = true
	_show_film_proof()
	if _room_built and not _room_ready:
		await room_ready              # the sliced pre-build is still finishing: wait, never build twice
	_ensure_room()
	_stand_t = 99.0
	_return_bull_glass()
	if _bull:
		_bull.position = BULL_REST
		# He faces Lil Blunt, not the wall: in profile his Winchester and his whiskey were hidden behind his own
		# body (founder 2026-10-04 "we still can't see his rifle or the whiskey glass"; skill ep2-bull-props-visible).
		var to_hero: float = atan2(HAND_MARK.x - BULL_REST.x, HAND_MARK.z - BULL_REST.z)
		_bull.facing = to_hero
		_bull.rotation.y = to_hero
		_bull.face_yaw(to_hero)
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
		_vfilm.release(0.6)         # the room is already built behind the film: a quick clean dissolve, no blank wait
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
			# Build the hideout WHILE the film plays over it, not after. The room (walls, furnace, the rigged
			# Bull, the five-target range, all the dressing) used to be built only when the film ended, on black
			# - a 1-2 s frozen blank screen at the cut (founder 2026-10-04: "a long period of blank screen that
			# delays for no reason"). The film is a full-screen CanvasLayer, so building the 3D behind it is
			# invisible; a brief hitch a few seconds into a 60 s film is unnoticeable next to a freeze at the cut.
			if not _room_built and _vfilm.elapsed() >= PREBUILD_AT:
				_prebuild_room()
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
	_tick_lava(delta)
	_gun.sprinting = _run_input and _moving
	_gun.step(delta)
	_tick_later(delta)
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
			_tick_lesson(delta)
		Beat.EXIT:
			# They leave TOGETHER: the Bull leads to the Fort Knox door and you follow in first person.
			# Resolve once you reach the door, never before his line has finished.
			if _hold <= 0.0 and not _show_active and _player_pos.z >= EXIT_POSITION.z - 1.0:
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


## `attack` (LMB). On foot with the Winchester it fires, once Inferno has taught it: the trigger goes through the
## Ep2Winchester logic (locked / empty / lever cycling), then a ray with the weapon's spread tests the three steel
## plates. Returns true when a plate went down.
func shoot() -> bool:
	if not _running or _resolved or not _has_winchester:
		return false
	if _show_active and _beat != Beat.VERB_TEACH:
		return false
	if _gun.trigger() != Ep2Winchester.Shot.OK:
		return false
	if _beat != Beat.VERB_TEACH or _molds_left <= 0:
		return false
	var idx: int = _plate_on_ray(_fire_dir())
	if idx < 0:
		return false
	_break_plate(idx)
	return true


func _break_plate(idx: int) -> void:
	_mold_broken[idx] = true
	_molds_left -= 1
	if _hud_ctl:
		_hud_ctl.hit_marker(true)
	_play_clang()
	if not _hit_first:
		_hit_first = true
	_sync_visuals()


## The camera's aim direction with the weapon's current spread applied (a gaussian cone: wide from the hip, tight
## when aimed, wider while moving or airborne). `spread_scale` 0 is the test hook for a perfectly steady hand.
func _fire_dir() -> Vector3:
	var sigma: float = _gun.spread_deg(_moving, _player_pos.y > 0.05) * spread_scale
	var yaw: float = _look_yaw + deg_to_rad(_rng.randfn(0.0, sigma)) if sigma > 0.0 else _look_yaw
	var pitch: float = _look_pitch + deg_to_rad(_rng.randfn(0.0, sigma)) if sigma > 0.0 else _look_pitch
	var cp: float = cos(pitch)
	return Vector3(sin(yaw) * cp, sin(pitch), cos(yaw) * cp)


## Nearest standing plate the ray passes within a plate's radius of, or -1.
func _plate_on_ray(dir: Vector3) -> int:
	var eye: Vector3 = _eye_position()
	var best: int = -1
	var best_t: float = 1.0e9
	for i in _mold_nodes.size():
		if _mold_broken[i] or not is_instance_valid(_mold_nodes[i]):
			continue
		var c: Vector3 = (_mold_nodes[i] as Node3D).global_position
		var t: float = (c - eye).dot(dir)
		if t < 0.5 or t > 40.0 or t >= best_t:
			continue
		var rad: float = float(RangeDressing.TARGET_RADII[i]) if i < RangeDressing.TARGET_RADII.size() else RangeDressing.PLATE_RADIUS
		if (c - (eye + dir * t)).length() <= rad + 0.03:
			best_t = t
			best = i
	return best


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
	var k: float = LOOK_SENSITIVITY * lerpf(1.0, ADS_LOOK_SCALE, _gun.ads)
	_look_yaw -= relative.x * k
	_look_pitch = clampf(_look_pitch - relative.y * k, LOOK_PITCH_MIN, LOOK_PITCH_MAX)
	_look_delta += relative


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
	var speed: float = (RUN_SPEED if _run_input else WALK_SPEED) * lerpf(1.0, ADS_MOVE_SCALE, _gun.ads)
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
	# Until the EXIT beat the channel is a wall (the choreography owns the room); from EXIT on it is a hazard, not a barrier.
	if _beat < Beat.EXIT and absf(q.z - CHANNEL_Z) < 1.1:
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
		_begin_lesson()
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
		Beat.VERB_TEACH:
			_on_lesson_show_done()
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
		"next_chamber": NEXT_CHAMBER,
		"seconds": _elapsed,
	})


# --- the lava river ------------------------------------------------------------------------------------------

## The EXIT show arms the river (before that the channel is a wall and nothing can burn).
func _lava_begin() -> void:
	_lava_on = true


## True once Lil Blunt stands on the far bank (past the burn zone), so Inferno can stop nagging and lead on.
func _lava_crossed() -> bool:
	return _player_pos.z > CHANNEL_Z + LAVA_HALF + 0.4


## Is Lil Blunt's body in the molten channel right now (feet below LAVA_SAFE_Y inside the burn zone)?
func in_lava() -> bool:
	return _lava_on and absf(_player_pos.z - CHANNEL_Z) < LAVA_HALF and _player_pos.y < LAVA_SAFE_Y


func _tick_lava(delta: float) -> void:
	if not _lava_on:
		return
	_burn_cd = maxf(0.0, _burn_cd - delta)
	var dz: float = _player_pos.z - CHANNEL_Z
	if absf(dz) >= LAVA_HALF:
		_lava_bank = 1.0 if dz > 0.0 else -1.0
	if in_lava() and _burn_cd <= 0.0:
		_burn()


## One burn: lose a heart, get kicked back to the bank he came from (with a hop so he can try again), flash, yelp.
## Out of hearts he is simply restored (the hideout is a story room: there is no game over, only a sore bottom).
func _burn() -> void:
	_burn_cd = BURN_COOLDOWN
	_burns += 1
	_health -= 1
	var out_of_hearts: bool = _health <= 0
	if out_of_hearts:
		_health = MAX_HEALTH
	_player_pos.z = CHANNEL_Z + _lava_bank * (LAVA_HALF + 0.55)
	_vel_y = JUMP_VELOCITY * 0.85
	_air_jumps = 0
	if _hud_ctl:
		_hud_ctl.hurt()
		_hud_ctl.toast("TRY AGAIN: RUN, JUMP, JUMP AGAIN" if out_of_hearts else "HOT! THE LAVA BURNS. HOP OVER IT", 2.2)
	var am: Node = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_sfx"):
		am.play_sfx("ep2_lava_burn")
	_yelp()
	burned.emit(_health)


## Lil Blunt's pain bark: any line of the voice bank's "hit" category (his alarm reactions).
func _yelp() -> void:
	var ids: Array = VoiceBank.CATEGORIES["hit"]["ids"]
	_speak(str(ids[_burns % ids.size()]))


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
	var bob: float = (sin(_walk_phase) * 0.035 if _moving else 0.0) * lerpf(1.0, 0.25, _gun.ads)
	_camera.position = _eye_position() + Vector3(0.0, bob, 0.0)
	var pitch: float = clampf(_look_pitch + _cam_kick, -1.4, 1.4)         # the kick lifts the VIEW, not the aim point
	var cp: float = cos(pitch)
	var dir := Vector3(sin(_look_yaw) * cp, sin(pitch), cos(_look_yaw) * cp)
	_camera.look_at(_camera.position + dir, Vector3.UP)
	var ads_k: float = _gun.ads * _gun.ads * (3.0 - 2.0 * _gun.ads)        # smoothstep: eases in and out
	# during the demonstration the view widens so Inferno (beside you) AND the targets are both in frame
	_fov_extra = lerpf(_fov_extra, 14.0 if _lesson == Lesson.DEMO else 0.0, 1.0 - exp(-delta * 3.0))
	_camera.fov = lerpf(FPS_FOV + _fov_extra, FPS_ADS_FOV, ads_k)


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
## Whether the founder's film ran this session (the narrative-canon memory uses it to drop lines the film covered).
func film_played() -> bool: return _film_played
func get_btc_paid() -> int: return btc_paid
func get_bull() -> Ep2Actor: return _bull
func get_show() -> FacilityShow: return _show
func is_show_active() -> bool: return _show_active
## Which Episode 2 mode this scene is in right now (the mode drives damage, input hints and the camera).
func get_episode_mode() -> int:
	return Episode2Mode.Mode.FPS if _fps else Episode2Mode.Mode.HIDEOUT
## Chamber 0 has no health and no fail state. Reported as full so a shared HUD
## does not have to special-case it.
func get_health() -> int: return _health
func get_ammo() -> int: return _gun.rounds
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
	_room_ready = false
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
		var ladle_scene: PackedScene = preload("res://src/episode2/assets/hideout/pour_ladle.glb")
		var ladle: Node3D = ladle_scene.instantiate()
		HideoutDressing.finish_materials(ladle)
		ladle.position = spec + Vector3(0.55, 4.6, 0.0)
		ladle.rotation.z = deg_to_rad(32.0)
		_visuals.add_child(ladle)
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
				HideoutDressing.finish_lantern(lp)

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
	if _build_slice: await get_tree().process_frame
	await _build_bull(timber)
	if _build_slice: await get_tree().process_frame

	# --- TARGET PRACTICE (skill ep2-range-lesson): three steel plates at 5.8 / 8.8 / 11.8 m down a marked lane.
	# RangeDressing owns how it looks; this scene owns the lesson and only reads the contract.
	var range_parts: Dictionary = RangeDressing.build(_visuals, timber)
	if _build_slice: await get_tree().process_frame
	for plate in range_parts["targets"]:
		_mold_nodes.append(plate)
	_range_blockers = (range_parts["blockers"] as Array).duplicate()

	# --- LIL BLUNT: the real hero (not the old primitive), standing in the room, lying when he comes to.
	_player_node = _build_player()
	if _build_slice: await get_tree().process_frame
	# The helmet hangs on its peg at the end of the gun wall; the Winchester is the middle rifle on the rack.
	_helmet_node = _build_helmet()
	_helmet_node.position = HELMET_PEG + Vector3(0.3, -0.05, 0.0)
	_visuals.add_child(_helmet_node)

	# --- the hangout: alcove, trophies, armory, Gatling, poster, braziers (see HideoutDressing).
	_dressing = await HideoutDressing.build(_visuals, _build_slice)
	_blockers = (_dressing.get("blockers", []) as Array).duplicate()
	_rifle_node = _dressing.get("rack_rifle") as Node3D
	_bull_blocker_i = _blockers.size()
	_blockers.append([Vector2(BULL_POSITION.x, BULL_POSITION.z), 1.5])
	for cs in _cauldron_spots:
		_blockers.append([Vector2(cs.x, cs.z), 1.1])
	for rb in _range_blockers:
		_blockers.append(rb)
	# (The plank bridge is gone, founder 2026-10-09: the lava burns and the way across is a hop.)

	# The Blender stone arch frames this exit; keep its opening unobstructed.
	# A brass plate, not the old bright-green bar (it hung across the furnace like a UI element).
	_box(Vector3(3.2, 0.6, 0.15), Vector3(0.0, 5.9, EXIT_POSITION.z + 0.7), Ep2Palette.make("brass"))
	var sign := Label3D.new()
	sign.text = "FORT KNOX"
	sign.font_size = 64
	sign.pixel_size = 0.008
	sign.modulate = Color(0.12, 0.07, 0.03)
	sign.position = Vector3(0.0, 5.9, EXIT_POSITION.z + 0.6)
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
		we.environment.ambient_light_energy = 0.52
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
	# Hit plates swing back and go dark - the verb teach needs visible feedback or the player cannot tell a hit
	# from a miss. RangeDressing owns how a plate looks standing or hit.
	for i in _mold_nodes.size():
		var broken: bool = bool(_mold_broken[i]) if i < _mold_broken.size() else i >= _molds_left
		RangeDressing.set_target_state(_mold_nodes[i] as Node3D, broken)


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
	if _build_slice: await get_tree().process_frame
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
	if _build_slice: await get_tree().process_frame
	if _bull.anim:
		for c in [BULL_SIT, BULL_STAND_UP]:
			if _bull.anim.has_animation(c) and c == BULL_SIT:
				_bull.anim.get_animation(c).loop_mode = Animation.LOOP_LINEAR
		_stand_len = _bull.anim.get_animation(BULL_STAND_UP).length / STAND_UP_SPEED if _bull.anim.has_animation(BULL_STAND_UP) else 0.0
	_bull.idle_clip = BULL_IDLE
	_bull.facing = PI                 # he faces the room (-Z), seated on his crate
	_bull.rotation.y = PI
	_bull.play(BULL_SIT if _bull.anim and _bull.anim.has_animation(BULL_SIT) else BULL_IDLE, 1.0, 0.0)
	if _build_slice: await get_tree().process_frame
	_fix_bull_materials(_bull.model, true)
	if _build_slice: await get_tree().process_frame
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
func _fix_bull_materials(root: Node, restored_bull: bool = false) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		for i in m.mesh.get_surface_count():
			var src: Material = m.mesh.surface_get_material(i)
			if src is StandardMaterial3D:
				var d: StandardMaterial3D = (src as StandardMaterial3D).duplicate()
				# SOLID from every side (founder 2026-10-05 "Inferno Bull is see-through at various occasions"): the Tripo/Meshy
				# head, hat and mask are single-sided shells that are open at the back, so with back-face culling the camera looked
				# through the head to whatever stood behind it (the whiskey glass). Double-sided + opaque + depth-writing closes it.
				d.cull_mode = BaseMaterial3D.CULL_DISABLED
				d.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
				d.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
				d.metallic = 0.0
				d.metallic_specular = 0.25
				d.roughness = 0.78
				d.metallic_texture = null
				d.roughness_texture = null
				# Source UVs verified in Blender against the runtime color map.
				# Restore PBR detail without replacing the animated rig or mesh.
				if restored_bull:
					d.resource_name = "InfernoBullRestoredPBR"
					d.albedo_texture = preload("res://src/episode2/assets/textures/bull_albedo.jpg")
					d.metallic_texture = preload("res://src/episode2/assets/textures/bull_metal_rough.png")
					d.roughness_texture = d.metallic_texture
					d.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
					d.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
					d.metallic = 0.65
					d.roughness = 1.0
					d.normal_enabled = true
					d.normal_texture = preload("res://src/episode2/assets/textures/bull_normal.png")
					d.normal_scale = 0.65
				d.rim_enabled = true
				d.rim = 0.12
				d.rim_tint = 0.5
				d.emission_enabled = true
				d.emission = Color(1.0, 0.78, 0.55)
				d.emission_texture = d.albedo_texture
				d.emission_energy_multiplier = 0.06 if restored_bull else 0.12
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


## Founder 2026-10-10: keep the whiskey on the table throughout the encounter.
## Both hands stay free of the glass during seating, walking and equipment hand-over.
func _set_glass_on_table() -> void:
	if _glass_node == null or not is_instance_valid(_glass_node):
		return
	if _glass_node.get_parent() != _visuals:
		_glass_node.reparent(_visuals, false)
	_glass_node.top_level = false
	_glass_node.position = HideoutDressing.WHISKEY_TABLE_POS + Vector3(0.55, 1.03 + GLASS_HEIGHT * 0.5, 0.2)
	_glass_node.rotation = Vector3.ZERO


## Existing choreography calls this after hand-over; the glass stays on the table.
func _return_bull_glass() -> void:
	_set_glass_on_table()


## Place rigid props from the final modified bone pose, after animation and IK.
## The complete Winchester GLB node matrix maps its long axis onto scene -Z.
func _sync_bull_hand_props() -> void:
	if _bull == null or _bull.skeleton == null:
		return
	var sk: Skeleton3D = _bull.skeleton
	var forward: Vector3 = Basis(Vector3.UP, _bull.facing) * Vector3.FORWARD
	var across: Vector3 = Basis(Vector3.UP, _bull.facing) * Vector3.RIGHT
	var carrying_trade: bool = _rifle_node != null and _rifle_node.get_parent() == _bull.holder("RightHand")
	if _bull_guard_rifle:
		_bull_guard_rifle.visible = (_stand_t < 0.0 or _has_helmet) and not carrying_trade
	var gun: Node3D = _rifle_node if carrying_trade else _bull_guard_rifle
	var right: int = sk.find_bone("RightHand")
	if gun == null or not gun.visible or right < 0:
		return
	var palm: Vector3 = (sk.global_transform * sk.get_bone_global_pose(right)).origin
	if carrying_trade:
		var stock_axis: Vector3 = Vector3(-1.0, 0.15, -0.10).normalized()
		var depth: Vector3 = stock_axis.cross(Vector3.UP).normalized()
		var up: Vector3 = depth.cross(stock_axis).normalized()
		gun.global_transform = Transform3D(Basis(-depth, up, -stock_axis).scaled(Vector3.ONE * 1.05), palm - stock_axis * 0.12 - forward * 0.05)
		return
	if _bull_rifle_ready:
		# DEMO / ready: both hands on the rifle, muzzle pointing where he faces (slightly up), stock at his shoulder.
		var fwd_front: Vector3 = -forward
		var muz: Vector3 = (fwd_front + Vector3.UP * 0.06).normalized()
		var sd: Vector3 = muz.cross(Vector3.UP).normalized()
		var lf: Vector3 = sd.cross(muz).normalized()
		gun.global_transform = Transform3D(Basis(sd, lf, muz).scaled(Vector3.ONE * BULL_RIFLE_SCALE),
			palm + muz * (0.30 * BULL_RIFLE_SCALE))
		return
	# His OWN Winchester: shoulder carry. Muzzle up past his right shoulder, tipped a little out and back, gripped
	# at the wrist of the stock, so its whole silhouette stands clear of his body from the front and both sides.
	# (The old low diagonal hid it behind his hip: founder 2026-10-04 "we still can't see his rifle".)
	# Rifle GLB: 1.2 m, muzzle +Z, centred (skill ep2-handoff-props). `across` is his LEFT, `forward` his BACK.
	var muzzle: Vector3 = (Vector3.UP * 0.94 - across * 0.20 + forward * 0.16).normalized()
	var side: Vector3 = muzzle.cross(-across).normalized()
	if side.dot(forward) < 0.0:
		side = -side
	var lift: Vector3 = muzzle.cross(side).normalized()     # right-handed: side x lift = muzzle
	var s: float = BULL_RIFLE_SCALE
	gun.global_transform = Transform3D(Basis(side, lift, muzzle).scaled(Vector3.ONE * s),
		palm + muzzle * (0.26 * s) - across * 0.02)


func _stand_up_done() -> bool:
	return _stand_t >= 99.0 or _bull == null or _stand_len <= 0.0


func _bull_play(clip: String, speed: float = 1.0) -> void:
	if _bull:
		_bull.play(clip, speed)


## Outer radius (metres, in the glass node's frame) of the scaled tumbler model, from its mesh AABBs.
func _glass_radius(gm: Node3D) -> float:
	var r: float = 0.0
	for mi in gm.find_children("*", "MeshInstance3D", true, false):
		var xf: Transform3D = Transform3D(Basis.from_scale(gm.scale), Vector3.ZERO)
		var chain: Array[Node3D] = []
		var n: Node = mi
		while n != gm and n is Node3D:
			chain.push_front(n as Node3D)
			n = n.get_parent()
		for c in chain:
			xf = xf * c.transform
		var bb: AABB = xf * (mi as MeshInstance3D).get_aabb()
		r = maxf(r, maxf(bb.size.x, bb.size.z) * 0.5)
	return r if r > 0.01 else GLASS_HEIGHT * 0.4


## Whiskey, ice and a rim inside the glass node (the glass base sits at y = -GLASS_HEIGHT / 2).
func _add_whiskey_inside(holder: Node3D, radius: float) -> void:
	var base_y: float = -GLASS_HEIGHT * 0.5
	var liquid_h: float = GLASS_HEIGHT * 0.62
	var liquid := MeshInstance3D.new()
	liquid.name = "Whiskey"
	var cm := CylinderMesh.new()
	cm.top_radius = radius * 0.86
	cm.bottom_radius = radius * 0.80
	cm.height = liquid_h
	cm.radial_segments = 20
	liquid.mesh = cm
	var lm := StandardMaterial3D.new()
	lm.albedo_color = Color(0.80, 0.33, 0.02)
	lm.roughness = 0.08
	lm.emission_enabled = true
	lm.emission = Color(1.0, 0.52, 0.10)
	lm.emission_energy_multiplier = 1.6
	liquid.material_override = lm
	liquid.position = Vector3(0.0, base_y + GLASS_HEIGHT * 0.10 + liquid_h * 0.5, 0.0)
	holder.add_child(liquid)
	var ice := MeshInstance3D.new()
	ice.name = "Ice"
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE * radius * 0.85
	ice.mesh = bm
	var im := StandardMaterial3D.new()
	im.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	im.albedo_color = Color(0.92, 0.97, 1.0, 0.55)
	im.roughness = 0.1
	im.emission_enabled = true
	im.emission = Color(1.0, 0.85, 0.6)
	im.emission_energy_multiplier = 0.25
	ice.material_override = im
	ice.position = Vector3(radius * 0.12, base_y + GLASS_HEIGHT * 0.10 + liquid_h * 0.92, 0.0)
	ice.rotation = Vector3(0.35, 0.6, 0.2)
	holder.add_child(ice)
	var rim := MeshInstance3D.new()
	rim.name = "Rim"
	var tm := TorusMesh.new()
	tm.inner_radius = radius * 0.93
	tm.outer_radius = radius * 1.0
	tm.rings = 24
	rim.mesh = tm
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.albedo_color = Color(1.0, 0.95, 0.85, 0.85)
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rim.material_override = rm
	rim.position = Vector3(0.0, GLASS_HEIGHT * 0.5 - 0.004, 0.0)
	holder.add_child(rim)


func _build_bull_props() -> void:
	# A room prop, never attached to Bull's hand.
	_glass_node = Node3D.new()
	_glass_node.name = "BullGlass"
	var gm: Node3D = (load(GLASS_MODEL) as PackedScene).instantiate()
	gm.scale = Vector3.ONE * GLASS_HEIGHT
	gm.position = Vector3(0.0, -GLASS_HEIGHT * 0.5, 0.0)
	# The founder's tumbler SHAPE stays; its baked texture (opaque white with orange flecks) read as a beer mug at
	# room distance (founder 2026-10-04 "we still can't see ... the whiskey glass"). It becomes clear glass with
	# real whiskey inside: an amber liquid that glows in the dim room, an ice cube and a bright rim.
	var glass_mat := StandardMaterial3D.new()
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat.albedo_color = Color(0.86, 0.93, 1.0, 0.22)
	glass_mat.roughness = 0.05
	glass_mat.metallic_specular = 1.0
	glass_mat.rim_enabled = true
	glass_mat.rim = 0.9
	glass_mat.rim_tint = 0.2
	glass_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for mesh in gm.find_children("*", "MeshInstance3D", true, false):
		for i in mesh.mesh.get_surface_count():
			mesh.set_surface_override_material(i, glass_mat)
	_glass_node.add_child(gm)
	_add_whiskey_inside(_glass_node, _glass_radius(gm))
	_visuals.add_child(_glass_node)
	_set_glass_on_table()
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
		_bull_rest_arm.resting = _bull.reach_weight("Right") < 0.01 and _bull.reach_weight("Left") < 0.01 and (_bull.current_clip() == BULL_IDLE or _bull.is_walking())
	# Rest means REST: no idle sips, no waving. Arms only move for an action beat (grab, hand-over).
	_follow_player_in_fps(delta)
	if _bull_blocker_i >= 0 and _bull_blocker_i < _blockers.size():
		_blockers[_bull_blocker_i] = [Vector2(_bull.position.x, _bull.position.z), 1.5]
	_bull.step(delta)
	if _cigar_tip:
		var pp: float = fmod(_anim_t + 4.5, 9.0)
		var puff: float = _smooth(pp / 0.6) - _smooth((pp - 1.4) / 0.9)
		(_cigar_tip.material_override as StandardMaterial3D).albedo_color = Color(1.0, 0.42, 0.1).lerp(Color(1.0, 0.85, 0.45), puff)
		_cigar_tip.scale = Vector3.ONE * (1.0 + 0.6 * puff)


## He stays at his rest mark in the hideout and only moves for the show beats. The companion walk starts on the
## EXIT beat (founder 2026-10-02: "he follows Lil Blunt too much; no companion leash in the hideout").
func _follow_player_in_fps(_delta: float) -> void:
	if not _fps or (_show and _show.running) or _bull == null:
		return
	if _beat != Beat.EXIT:
		_face_player_at_rest()
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


## At rest he stays put (no follow, skill ep2-bull-rest-pose) but turns in place to keep Lil Blunt in front of
## him, so his rifle and his whiskey stay on the player's side of his body. Turns only past REST_FACE_SLACK so he
## is not twitching after every mouse move.
const REST_FACE_SLACK := 0.45
func _face_player_at_rest() -> void:
	if _bull.is_walking():
		return
	var yaw: float = atan2(_player_pos.x - _bull.position.x, _player_pos.z - _bull.position.z)
	if absf(angle_difference(_bull.facing, yaw)) > REST_FACE_SLACK:
		_bull.face_yaw(yaw)


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
		_rifle_node.position = VM_HIP_POS
		_rifle_node.rotation = VM_HIP_ROT
		_rifle_node.scale = Vector3.ONE * VM_SCALE
		_build_muzzle_flash()
		_rifle_sight_height()                 # measure the sights BEFORE the hands are added (they must not count)
		Ep2ViewHands.attach(_rifle_node)      # Lil Blunt's hands + bracers on the rifle (founder round 3)
	if _fps_hud == null:
		_fps_hud = CanvasLayer.new()
		_fps_hud.layer = 12
		add_child(_fps_hud)
		_hud_ctl = Ep2FpsHud.new()
		_hud_ctl.mag = Ep2Winchester.MAG
		_fps_hud.add_child(_hud_ctl)
	_flash_light = OmniLight3D.new()
	_flash_light.light_color = Color(1.0, 0.8, 0.5)
	_flash_light.light_energy = 0.0
	_flash_light.omni_range = 7.0
	if _camera:
		_camera.add_child(_flash_light)
		_flash_light.position = Vector3(0.2, -0.15, -1.0)
	fps_started.emit()


## --- the first-person VIEWMODEL (skill ep2-fps-shooter-feel) --------------------------------------------------
## Camera space: -Z is forward, the rifle's muzzle is +Z in its own frame so a yaw of PI points it forward.
## Hip: low and right, the muzzle angled in toward the centre (the Modern Warfare carry), the stock near the
## shoulder and off-screen. ADS: centred, the sight line on the screen centre. Low ready: down and away while
## Inferno is still talking.
var VM_SCALE := 0.8
var VM_HIP_POS := Vector3(0.17, -0.16, -0.5)
var VM_HIP_ROT := Vector3(0.03, PI + 0.07, 0.0)
const VM_LOW_POS := Vector3(0.22, -0.64, -0.5)    # low ready / spyglass: dropped BELOW the frame (founder 2026-10-11: the old swing laid Lil Blunt's longer rifle across the spyglass view)
const VM_LOW_ROT := Vector3(-0.28, PI + 0.10, 0.0)
const VM_SPRINT_POS := Vector3(0.16, -0.40, -0.48)
const VM_SPRINT_ROT := Vector3(-0.30, PI + 0.18, 0.15)
var VM_ADS_DEPTH := -0.46
var VM_ADS_SIGHT_DROP := 0.012            # the front post sits a hair below the centre so the target stays visible


## Muzzle flash, recoil kick and the shot itself.
func _fire_fx() -> void:
	_recoil = 1.0
	_flash_t = 0.06
	if _gun:
		_cam_kick += _gun.kick_rad()
	if _flash_light:
		_flash_light.light_energy = 4.0
	_play_winchester()


func _build_muzzle_flash() -> void:
	if _muzzle_flash and is_instance_valid(_muzzle_flash):
		return
	var q := QuadMesh.new()
	q.size = Vector2(0.5, 0.5)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(1.0, 0.75, 0.35, 1.0)
	m.albedo_texture = _soft_blob()
	m.no_depth_test = true
	q.material = m
	_muzzle_flash = MeshInstance3D.new()
	_muzzle_flash.mesh = q
	_muzzle_flash.position = Vector3(0.0, 0.03, 0.66)
	_muzzle_flash.visible = false
	_rifle_node.add_child(_muzzle_flash)


## Height of the rifle's highest point (the sights) in its own frame, measured from its meshes once.
func _rifle_sight_height() -> float:
	if _sight_h > 0.0:
		return _sight_h
	var top: float = 0.0
	if _rifle_node and is_instance_valid(_rifle_node) and _rifle_node.is_inside_tree():
		var inv: Transform3D = _rifle_node.global_transform.affine_inverse()
		for mi in _rifle_node.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			if m == _muzzle_flash or m.mesh == null or _rifle_node.get_node_or_null("Hands") and _rifle_node.get_node("Hands").is_ancestor_of(m):
				continue
			var bb: AABB = (inv * m.global_transform) * m.get_aabb()
			top = maxf(top, bb.end.y)
	_sight_h = clampf(top, 0.03, 0.2) if top > 0.0 else 0.06
	return _sight_h

## The Winchester report (skill ep2-winchester-sound). Founder 2026-10-04: "horrid ... needs to sound dangerous,
## not like a toy". It used the runner's 1.2 s revolver samples through play_sfx at 0 dB. Now: three layered rifle
## samples (crack + heavy body + 2.4 s cavern echo, tools/ep2_audio/build_winchester.py) round-robin on their own
## pool so a quick follow-up shot never cuts the previous echo, then the lever cycle racks after each shot.
const WINCHESTER_SHOTS := ["ep2_winchester_shot_1.mp3", "ep2_winchester_shot_2.mp3", "ep2_winchester_shot_3.mp3"]
const WINCHESTER_LEVER := "ep2_winchester_lever.mp3"
const WINCHESTER_DB := 4.0
const WINCHESTER_LEVER_DB := 0.0
const WINCHESTER_LEVER_DELAY := 0.38
var _win_players: Array[AudioStreamPlayer] = []
var _win_lever: AudioStreamPlayer = null
var _win_next: int = 0
var _lever_due: float = -1.0
var winchester_shots_played: int = 0
var winchester_levers_played: int = 0


func _build_winchester_audio() -> void:
	if not _win_players.is_empty():
		return
	var bus: String = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	for i in WINCHESTER_SHOTS.size():
		var p := AudioStreamPlayer.new()
		p.name = "WinchesterShot%d" % i
		p.bus = bus
		p.volume_db = WINCHESTER_DB
		var path: String = "res://src/assets/sounds/" + str(WINCHESTER_SHOTS[i])
		if ResourceLoader.exists(path):
			p.stream = load(path) as AudioStream
		add_child(p)
		_win_players.append(p)
	_win_lever = AudioStreamPlayer.new()
	_win_lever.name = "WinchesterLever"
	_win_lever.bus = bus
	_win_lever.volume_db = WINCHESTER_LEVER_DB
	if ResourceLoader.exists("res://src/assets/sounds/" + WINCHESTER_LEVER):
		_win_lever.stream = load("res://src/assets/sounds/" + WINCHESTER_LEVER) as AudioStream
	add_child(_win_lever)


func _play_winchester() -> void:
	_build_winchester_audio()
	var p: AudioStreamPlayer = _win_players[_win_next % _win_players.size()]
	_win_next += 1
	if p.stream:
		p.pitch_scale = randf_range(0.96, 1.03)
		p.play()
		winchester_shots_played += 1
	_lever_due = WINCHESTER_LEVER_DELAY


## Racks the lever WINCHESTER_LEVER_DELAY after the shot (driven by the facility's own clock, so headless too).
func _tick_winchester_lever(delta: float) -> void:
	if _lever_due < 0.0:
		return
	_lever_due -= delta
	if _lever_due <= 0.0:
		_lever_due = -1.0
		if _win_lever and _win_lever.stream:
			_win_lever.play()
			winchester_levers_played += 1


func _animate_fps(delta: float) -> void:
	if not _fps:
		return
	_tick_winchester_lever(delta)
	_recoil = maxf(0.0, _recoil - delta * 6.0)
	_cam_kick = lerpf(_cam_kick, 0.0, 1.0 - exp(-delta / 0.14))
	_flash_t = maxf(0.0, _flash_t - delta)
	if _muzzle_flash and is_instance_valid(_muzzle_flash):
		_muzzle_flash.visible = _flash_t > 0.0
		_muzzle_flash.scale = Vector3.ONE * (0.7 + 0.8 * (_flash_t / 0.06))
	if _flash_light:
		_flash_light.light_energy = maxf(0.0, _flash_light.light_energy - delta * 30.0)
	_push_hud(delta)
	if not (_rifle_node and is_instance_valid(_rifle_node) and _rifle_node.get_parent() == _camera):
		return
	var ads: float = _gun.ads
	var ads_k: float = ads * ads * (3.0 - 2.0 * ads)
	var lowered: float = 1.0 if (_lesson == Lesson.LEAD or _lesson == Lesson.DEMO) else 0.0
	_vm_low = move_toward(_vm_low, lowered, delta * 2.6)
	var sprint: float = 1.0 if (_run_input and _moving and ads < 0.1) else 0.0
	var pos: Vector3 = VM_HIP_POS.lerp(VM_LOW_POS, _vm_low).lerp(VM_SPRINT_POS, sprint * (1.0 - _vm_low))
	var rot: Vector3 = VM_HIP_ROT.lerp(VM_LOW_ROT, _vm_low).lerp(VM_SPRINT_ROT, sprint * (1.0 - _vm_low))
	# aimed: centred with the sight line on the screen centre
	var ads_pos := Vector3(0.0, -(VM_ADS_SIGHT_DROP + _rifle_sight_height() * VM_SCALE), float(_rifle_node.get_meta("ads_depth", VM_ADS_DEPTH)))
	if _rifle_node.has_meta("ads_cam"):
		# the eye in the rifle's own frame (founder rifle): the node sits so that point lands on the camera; the rifle is yawed
		# PI toward the player, so its +Z points forward and its +Y up: node = (-cam.y * s, +cam.z * s) in camera space.
		var ec: Vector3 = _rifle_node.get_meta("ads_cam")
		ads_pos = Vector3(0.0, -ec.y * VM_SCALE - VM_ADS_SIGHT_DROP, ec.z * VM_SCALE)
	pos = pos.lerp(ads_pos, ads_k)
	rot = rot.lerp(Vector3(0.0, PI, 0.0), ads_k)
	# breathing + walk bob (both nearly vanish aimed), and the rifle LAGS the mouse a little
	var calm: float = lerpf(1.0, 0.18, ads_k)
	pos += Vector3(sin(_anim_t * 1.3) * 0.0035, sin(_anim_t * 1.9) * 0.004, 0.0) * calm
	if _moving:
		pos += Vector3(sin(_walk_phase) * 0.011, -absf(sin(_walk_phase)) * 0.013, 0.0) * calm
	var lag_target := Vector2(clampf(-_look_delta.x * 0.00045, -0.05, 0.05), clampf(_look_delta.y * 0.00045, -0.05, 0.05))
	_look_delta = Vector2.ZERO
	_vm_lag = _vm_lag.lerp(lag_target, 1.0 - exp(-delta * 12.0))
	pos += Vector3(_vm_lag.x, _vm_lag.y, 0.0) * calm
	rot.y += _vm_lag.x * 1.6
	# recoil: the rifle jumps back and its muzzle lifts, then settles
	pos += Vector3(0.0, 0.016, 0.085) * _recoil * lerpf(1.0, 0.55, ads_k)
	rot.x += 0.12 * _recoil * lerpf(1.0, 0.6, ads_k)
	# the lever cycle: after each shot the rifle dips and rolls as the lever is racked
	var cp: float = _gun.cycle_progress()
	if cp < 1.0:
		var k: float = sin(cp * PI)
		rot.z += 0.34 * k
		rot.x -= 0.2 * k
		pos.y -= 0.025 * k
	# the shell-by-shell reload: the rifle tilts to show the loading gate and taps once per shell
	if _gun.reloading:
		var tap: float = absf(sin(_anim_t * PI / Ep2Winchester.RELOAD_PER_SHELL))
		rot.z += -0.55
		rot.x += 0.28
		pos += Vector3(-0.05, -0.05 - 0.02 * tap, 0.04)
	_rifle_node.position = pos
	_rifle_node.rotation = rot


## Push the weapon and lesson state into the HUD every frame.
func _push_hud(_delta: float) -> void:
	if _hud_ctl == null:
		return
	_hud_ctl.spread_deg = _gun.spread_deg(_moving, _player_pos.y > 0.05)
	_hud_ctl.ads = _gun.ads
	_hud_ctl.set_ammo(_gun.rounds, _gun.reserve, Ep2Winchester.MAG)
	_hud_ctl.show_ammo = _has_winchester and (_lesson == Lesson.OFF or _lesson >= Lesson.LOAD)
	_hud_ctl.objective = _lesson_objective()
	var stepping: bool = _lesson >= Lesson.LOAD and _lesson <= Lesson.PRACTICE
	_hud_ctl.step_index = _lesson - Lesson.LOAD + 1 if stepping else 0
	_hud_ctl.step_total = LESSON_STEPS if stepping else 0
	_hud_ctl.health = _health
	_hud_ctl.health_max = MAX_HEALTH
	_hud_ctl.show_health = _lava_on


# --- The weapon's public verbs + the target-practice lesson (skill ep2-range-lesson) -------------------------------

## RMB held: aim down the sights. (The session root maps the mouse button; the gun clamps it while sprinting.)
func set_aim(on: bool) -> void:
	if not _fps or _show_blocks_control:
		_gun.set_aim(false)
		return
	_gun.set_aim(on)


## R: load shells one at a time. Returns true when a reload started.
func reload() -> bool:
	if not _fps or not _has_winchester or _show_blocks_control:
		return false
	return _gun.start_reload()


func get_gun() -> Ep2Winchester: return _gun
func get_reserve() -> int: return _gun.reserve
func get_lesson() -> int: return _lesson
func get_lesson_name() -> String: return Lesson.keys()[clampi(_lesson, 0, Lesson.size() - 1)]
func is_ads() -> bool: return _gun.ads > 0.5


func _connect_gun() -> void:
	_gun.fired.connect(_fire_fx)
	_gun.dry_fired.connect(_on_dry_fired)
	_gun.shell_loaded.connect(_on_shell_loaded)
	_gun.reload_finished.connect(_on_reload_finished)
	_gun.blocked.connect(_on_gun_blocked)


func _sfx(name: String) -> void:
	var am: Node = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_sfx"):
		am.play_sfx(name)


func _play_clang() -> void:
	_sfx("ep2_plate_clang")


func _toast(text: String, seconds: float = 1.6) -> void:
	if _hud_ctl:
		_hud_ctl.toast(text, seconds)


func _on_dry_fired() -> void:
	_sfx("ep2_winchester_dry")
	_toast("OUT OF ROUNDS  -  PRESS R")
	if _empty_line_cd <= 0.0 and _lesson >= Lesson.FIRE and _gun.reserve > 0:
		_empty_line_cd = 12.0
		_speak("vo_bull_range_empty")


func _on_shell_loaded(_n: int) -> void:
	_sfx("ep2_winchester_shell_load")


func _on_reload_finished() -> void:
	if _lesson == Lesson.LOAD:
		_lesson = Lesson.AIM
		_lesson_t = 0.0
		_aim_held = 0.0
		_speak("vo_bull_range_good_load")


func _on_gun_blocked(reason: String) -> void:
	if reason == "locked":
		_toast("WAIT FOR INFERNO")
		if _hold_line_cd <= 0.0 and _lesson >= Lesson.LEAD and _lesson <= Lesson.AIM:
			_hold_line_cd = 9.0
			_speak("vo_bull_range_hold")
	else:
		_toast("WATCH INFERNO FIRST")


## Delay a call by `seconds` of facility time (driven by step, so the headless gates see it too).
func _later(seconds: float, fn: Callable) -> void:
	_later_calls.append([seconds, fn])


func _tick_later(delta: float) -> void:
	var i: int = 0
	while i < _later_calls.size():
		_later_calls[i][0] -= delta
		if _later_calls[i][0] <= 0.0:
			var fn: Callable = _later_calls[i][1]
			_later_calls.remove_at(i)
			fn.call()
		else:
			i += 1


func _begin_lesson() -> void:
	_lesson = Lesson.LEAD
	_lesson_t = 0.0
	_lead_done = false
	_aim_held = 0.0
	_nag_t = 0.0
	_gun.locked = true
	_gun.reload_locked = true
	_gun.rounds = 0
	_gun.reserve = Ep2Winchester.RESERVE_START
	_add_line_marker()


## A pulsing ring on the floor at the firing line while Inferno is leading the way there.
var _line_marker: MeshInstance3D = null
func _add_line_marker() -> void:
	if _line_marker and is_instance_valid(_line_marker):
		return
	var tm := TorusMesh.new()
	tm.inner_radius = 0.7
	tm.outer_radius = 0.82
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.0, 0.7, 0.2, 0.9)
	_line_marker = MeshInstance3D.new()
	_line_marker.mesh = tm
	_line_marker.material_override = m
	_line_marker.position = Vector3(RangeDressing.LINE.x, 0.04, RangeDressing.LINE.z)
	if _visuals:
		_visuals.add_child(_line_marker)


func _player_near_line() -> bool:
	return Vector2(_player_pos.x - RangeDressing.LINE.x, _player_pos.z - RangeDressing.LINE.z).length() <= LESSON_ARRIVE_RADIUS


func _tick_lesson(delta: float) -> void:
	_lesson_t += delta
	_hold_line_cd = maxf(0.0, _hold_line_cd - delta)
	_empty_line_cd = maxf(0.0, _empty_line_cd - delta)
	if _line_marker and is_instance_valid(_line_marker):
		_line_marker.visible = _lesson == Lesson.LEAD
		_line_marker.scale = Vector3.ONE * (1.0 + 0.12 * sin(_anim_t * 4.0))
	match _lesson:
		Lesson.LEAD:
			# "Follow me": for the first 2.2 s the view eases round to him as he sets off (the player stays in
			# control after that), so the lesson never starts with Inferno walking away behind your back.
			if _lesson_t < 2.2 and _bull and not _show_blocks_control:
				var d: Vector3 = _bull.position - _eye_position()
				_look_yaw = lerp_angle(_look_yaw, atan2(d.x, d.z), 1.0 - exp(-delta * 2.5))
				_look_pitch = lerpf(_look_pitch, -0.12, 1.0 - exp(-delta * 2.5))
			if _lead_done:
				if _player_near_line():
					_start_demo()
				else:
					_nag_t += delta
					if _nag_t >= NAG_SECONDS:
						_nag_t = 0.0
						_speak("vo_bull_range_nag")
		Lesson.DEMO:
			_frame_demo(delta)
		Lesson.AIM:
			_aim_held = _aim_held + delta if _gun.ads >= 0.95 else 0.0
			if _aim_held >= AIM_HOLD_SECONDS:
				_lesson = Lesson.FIRE
				_lesson_t = 0.0
				_gun.locked = false
				_speak("vo_bull_range_good_aim")
		Lesson.FIRE:
			if _hit_first:
				_lesson = Lesson.PRACTICE
				_lesson_t = 0.0
				_speak("vo_bull_range_first_hit")
		Lesson.PRACTICE:
			if _molds_left <= 0:
				_lesson = Lesson.DONE
				_speak("vo_bull_range_done")
				_hold = _vo_len("vo_bull_range_done") + 0.4
		Lesson.DONE:
			if _hold <= 0.0:
				_advance()


func _lesson_objective() -> String:
	match _lesson:
		Lesson.LEAD:
			return "FOLLOW INFERNO BULL TO THE FIRING LINE"
		Lesson.DEMO:
			return "WATCH INFERNO"
		Lesson.LOAD:
			return "PRESS  R  TO LOAD THE WINCHESTER   (%d / %d)" % [_gun.rounds, Ep2Winchester.MAG]
		Lesson.AIM:
			return "HOLD  RIGHT MOUSE  TO AIM DOWN THE SIGHTS"
		Lesson.FIRE:
			return "AIM, THEN PRESS  LEFT CLICK  TO FIRE"
		Lesson.PRACTICE:
			return "SHOOT THE TARGETS   (%d left)   R = reload" % _molds_left
	return ""


## The Bull has reached the demo spot (LEAD) or finished the demonstration (DEMO).
func _on_lesson_show_done() -> void:
	match _lesson:
		Lesson.LEAD:
			_lead_done = true
		Lesson.DEMO:
			_demo_end()
			_lesson = Lesson.LOAD
			_lesson_t = 0.0
			_gun.reload_locked = false
			_show_blocks_control = false


func _start_demo() -> void:
	_lesson = Lesson.DEMO
	_lesson_t = 0.0
	_move_input = Vector2.ZERO
	_gun.set_aim(false)
	_look_yaw = PI           # face the target wall (-Z); _frame_demo refines it
	_show_blocks_control = true
	_show_active = true
	if _show == null:
		_show = FacilityShow.new()
		_show.f = self
	_show.start(FacilityShow.demo_steps(self))


## While Inferno demonstrates, the camera frames him and the plates (the player is locked, so this is a cut-scene
## look, not a fight with the mouse).
func _frame_demo(delta: float) -> void:
	if _bull == null:
		return
	var eye: Vector3 = _eye_position()
	var to_plate: Vector3 = get_mold_position(1) - eye
	var to_bull: Vector3 = _bull.position + Vector3(0.0, 1.6, 0.0) - eye
	var yaw: float = lerp_angle(atan2(to_plate.x, to_plate.z), atan2(to_bull.x, to_bull.z), 0.55)
	_look_yaw = lerp_angle(_look_yaw, yaw, 1.0 - exp(-delta * 3.0))
	# Step up beside him: ease onto the firing line so the two stand side by side (founder round 3: "why am I not
	# standing closer forward next to him").
	var k: float = 1.0 - exp(-delta * 2.5)
	_player_pos.x = lerpf(_player_pos.x, RangeDressing.LINE.x, k)
	_player_pos.z = lerpf(_player_pos.z, RangeDressing.LINE.z, k)
	_look_pitch = lerpf(_look_pitch, -0.04, 1.0 - exp(-delta * 3.0))


func _bull_front() -> Vector3:
	return Basis(Vector3.UP, _bull.facing) * Vector3.BACK


## "ready" = two-handed shooting hold (the demo), "carry" = shoulder carry (rest).
func _set_bull_rifle_mode(mode: String) -> void:
	_bull_rifle_ready = mode == "ready"


# --- the demonstration, one beat at a time (called by FacilityShow.demo_steps) ---
func _demo_shell() -> void:
	_sfx("ep2_winchester_shell_load")


func _demo_raise() -> void:
	if _bull == null:
		return
	_set_bull_rifle_mode("ready")
	# No shoulder-height IK raise: bending his arms that far webbed and melted the elbow on the founder's Tripo body
	# (founder 2026-10-11, red circle on the range demo). He fires from the hip: arms stay in the rest pose and the
	# rifle in his hand turns level toward the targets ("ready" mode in _sync_bull_hand_props).


func _demo_fire() -> void:
	_play_winchester()
	if _bull:
		var muzzle: Vector3 = _bull.position + _bull_front() * 1.5 + Vector3.UP * 1.2      # hip fire (no arm raise)
		var lt := OmniLight3D.new()
		lt.light_color = Color(1.0, 0.8, 0.5)
		lt.light_energy = 5.0
		lt.omni_range = 6.0
		lt.position = muzzle
		_visuals.add_child(lt)
		_later(0.09, lt.queue_free)
	_later(0.3, _demo_hit)


func _demo_hit() -> void:
	_mold_broken[1] = true
	_play_clang()
	_sync_visuals()


func _demo_end() -> void:
	if _bull:
		_bull.release("Right", 0.5)
		_bull.release("Left", 0.5)
	_set_bull_rifle_mode("carry")
	for i in _mold_broken.size():
		_mold_broken[i] = false
	_molds_left = MOLD_TARGETS
	_sync_visuals()


## Test / skip hook: jump straight to free practice with a loaded, unlocked rifle.
func debug_skip_lesson() -> void:
	if _show:
		_show.running = false
	_show_active = false
	_show_blocks_control = false
	_demo_end()
	_lesson = Lesson.PRACTICE
	_gun.locked = false
	_gun.reload_locked = false
	_gun.rounds = maxi(Ep2Winchester.MAG, MOLD_TARGETS + 1)   # test hook: clear every target (+ a deliberate miss) without a mid-run reload
	_gun.reserve = Ep2Winchester.RESERVE_START
	_lead_done = true


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

