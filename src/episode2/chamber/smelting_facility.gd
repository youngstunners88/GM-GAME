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

enum Beat {
	ARRIVAL,      # cart brakes into heat and light; control hands to walking
	APPROACH,     # cross the floor to the Bull
	DRINK,        # the shared drink and cigar — the character beat
	SIZING,       # he takes your measure
	HANDOFF,      # the Winchester 1886
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
const COMPANION_ID := "inferno_bull"

## Beat → the Bull's line, and how long to hold before the beat can advance.
## Hold times are the MEASURED durations of the committed clips (see
## INFERNO_BULL_CHARACTER_PROFILE.md §5), so a line is never cut off by an
## impatient player mashing interact.
const BEAT_LINES := {
	Beat.DRINK: {"id": "vo_bull_made_it", "hold": 3.58},
	Beat.HANDOFF: {"id": "vo_bull_take_rifle", "hold": 5.80},
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

## Camera framing per beat. A browser capture of the first build showed the
## whole encounter playing at postage-stamp scale from the wide establishing
## shot: the Bull was two horns in the middle distance and the rifle hand-off
## was invisible. This is a CONVERSATION, so the camera pushes in for it and
## pulls back out for the verb teach, which needs the room again.
##
## Each entry is [position, pitch degrees].
const CAM_WIDE := [Vector3(0.0, 4.2, -14.0), -14.0]
const CAM_CLOSE := [Vector3(1.1, 2.3, 1.4), -8.0]
const CAM_TEACH := [Vector3(-1.0, 3.2, -3.0), -12.0]
const CAM_LERP := 1.8          # units/sec — a push-in, not a snap

var _visuals: Node3D = null
var _camera: Camera3D = null
var _cam_target_pos: Vector3 = CAM_WIDE[0]
var _cam_target_pitch: float = float(CAM_WIDE[1])
var _player_node: Node3D = null
var _mold_nodes: Array = []
var _rifle_node: Node3D = null

const BULL_MODEL := "res://src/episode2/assets/inferno_bull_placeholder.glb"
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
	_beat = Beat.ARRIVAL
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
	beat_changed.emit(_beat)


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

	_update_camera(delta)

	if absf(_walk_input) > 0.01:
		_player_pos.z += _walk_input * WALK_SPEED * delta
		_player_pos.z = clampf(_player_pos.z, ENTRY_POSITION.z, EXIT_POSITION.z)

	match _beat:
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
		Beat.DRINK, Beat.SIZING, Beat.HANDOFF, Beat.TERMS, Beat.PROMISE:
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
	if beat == Beat.HANDOFF:
		_has_winchester = true
		weapon_granted.emit(WINCHESTER_ID)
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
		Beat.DRINK, Beat.SIZING, Beat.HANDOFF, Beat.TERMS, Beat.PROMISE:
			want = CAM_CLOSE
		Beat.VERB_TEACH:
			want = CAM_TEACH
		_:
			want = CAM_WIDE
	_cam_target_pos = want[0]
	_cam_target_pitch = float(want[1])
	var t: float = clampf(CAM_LERP * delta, 0.0, 1.0)
	_camera.position = _camera.position.lerp(_cam_target_pos, t)
	var pitch: float = lerpf(_camera.rotation_degrees.x, _cam_target_pitch, t)
	# Yaw 180 keeps the camera looking down +Z, the orientation both Episode 2
	# cameras had to be corrected to after they were found facing backwards.
	_camera.rotation_degrees = Vector3(pitch, 180.0, 0.0)


func _distance_to_bull() -> float:
	return absf(BULL_POSITION.z - _player_pos.z)


# --- Getters (HUD + tests) ---------------------------------------------------------
func get_beat() -> int: return _beat
func get_beat_name() -> String: return Beat.keys()[clampi(_beat, 0, Beat.size() - 1)]
func has_winchester() -> bool: return _has_winchester
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

	_apply_art()

	# --- the cavern shell. Wider and taller than the runner tunnel: the spec
	# wants this to feel like arriving somewhere after a confined chase.
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(22.0, 0.4, 30.0)
	_mesh(floor_mesh, Ep2Palette.make("rock_deep"), Vector3(0.0, -0.2, 3.5))
	for sx in [-1.0, 1.0]:
		var wall := BoxMesh.new()
		wall.size = Vector3(0.6, 10.0, 30.0)
		_mesh(wall, Ep2Palette.make("rock"), Vector3(11.0 * sx, 4.6, 3.5))
	var ceiling := BoxMesh.new()
	ceiling.size = Vector3(22.6, 0.6, 30.0)
	_mesh(ceiling, Ep2Palette.make("rock_deep"), Vector3(0.0, 9.6, 3.5))
	# Back wall behind the Bull, so the room closes and the exit reads as the
	# only way on.
	var back := BoxMesh.new()
	back.size = Vector3(22.0, 10.0, 0.6)
	_mesh(back, Ep2Palette.make("rock"), Vector3(0.0, 4.6, 18.5))

	# --- timber framing, the same vocabulary as the runner tunnel.
	var bz: float = -6.0
	while bz < 17.0:
		for sx2 in [-1.0, 1.0]:
			var post := BoxMesh.new()
			post.size = Vector3(0.5, 8.0, 0.5)
			_mesh(post, Ep2Palette.make("wood"), Vector3(10.3 * sx2, 3.6, bz))
		var beam := BoxMesh.new()
		beam.size = Vector3(21.2, 0.5, 0.5)
		_mesh(beam, Ep2Palette.make("wood"), Vector3(0.0, 7.5, bz))
		bz += 7.5

	# --- the working facility. Crucibles are the light source AND the staging:
	# the reference has the Bull seated among them with pours going behind him.
	for spec in [Vector3(-6.0, 0.0, 8.5), Vector3(6.5, 0.0, 11.0), Vector3(-3.0, 0.0, 13.5)]:
		if _prop(CRUCIBLE_MODEL, spec, 1.0) == null:
			var cm := CylinderMesh.new()
			cm.top_radius = 0.9
			cm.bottom_radius = 0.9
			cm.height = 1.6
			_mesh(cm, Ep2Palette.make("gold"), spec + Vector3(0, 0.8, 0))
		var glow := Ep2Palette.make_forge_light()
		glow.position = spec + Vector3(0.0, 1.8, 0.0)
		_visuals.add_child(glow)

	for spec2 in [Vector3(8.6, 0.0, 4.0), Vector3(-8.6, 0.0, 6.5)]:
		if _prop(INGOT_RACK_MODEL, spec2, 1.0) == null:
			var rm := BoxMesh.new()
			rm.size = Vector3(1.9, 1.5, 0.7)
			_mesh(rm, Ep2Palette.make("gold"), spec2 + Vector3(0, 0.75, 0))

	# Lanterns on the timber, cooler counterpoint to the pours.
	for lz in [-4.0, 2.0, 9.0]:
		var lamp := Ep2Palette.make_lantern_light()
		lamp.position = Vector3(9.4, 3.6, lz)
		_visuals.add_child(lamp)
		_prop(LANTERN_MODEL, Vector3(9.4, 3.2, lz), 1.2)

	_camera = get_node_or_null("Camera3D") as Camera3D
	if _camera:
		_camera.position = CAM_WIDE[0]
		_camera.rotation_degrees = Vector3(float(CAM_WIDE[1]), 180.0, 0.0)

	# --- the Bull, seated, whiskey at hand. Staging from the reference image.
	# A dedicated warm key on him: he is near-black hide (the profile's
	# "massive anthropomorphic black bull") in a dark room, and the first
	# capture showed him reduced to two horns. The reference has him lit by the
	# molten gold he is sitting among, so this is on-model, not a cheat.
	var bull_key := Ep2Palette.make_forge_light()
	bull_key.light_energy = 3.2
	bull_key.omni_range = 9.0
	bull_key.position = BULL_POSITION + Vector3(-1.8, 2.4, -2.2)
	_visuals.add_child(bull_key)
	if _prop(BULL_MODEL, BULL_POSITION, 1.0, PI) == null:
		var bm := BoxMesh.new()
		bm.size = Vector3(1.4, 2.4, 1.0)
		_mesh(bm, Ep2Palette.make("bandit"), BULL_POSITION + Vector3(0, 1.2, 0))
	_prop(WHISKEY_MODEL, BULL_POSITION + Vector3(-1.1, 0.55, -0.5), 1.4)
	# A crate he's using as a table, so the glass isn't floating.
	var crate := BoxMesh.new()
	crate.size = Vector3(0.9, 0.55, 0.9)
	_mesh(crate, Ep2Palette.make("crate"), BULL_POSITION + Vector3(-1.1, 0.28, -0.5))

	# --- the verb-teach target: a rack of EMPTY casting molds. Safe by design —
	# per the spec, Chamber 0 has no live enemies, so the gun's first real use
	# still has its stakes waiting on the approach to Fort Knox.
	for i in MOLD_TARGETS:
		var mold := BoxMesh.new()
		mold.size = Vector3(0.7, 0.45, 0.5)
		var mi := _mesh(mold, Ep2Palette.make_unique("iron"),
			MOLD_RACK_POSITION + Vector3(0.0, 1.05, float(i) * 1.1 - 1.1))
		_mold_nodes.append(mi)
	var bench := BoxMesh.new()
	bench.size = Vector3(1.1, 0.8, 3.6)
	_mesh(bench, Ep2Palette.make("wood"), MOLD_RACK_POSITION + Vector3(0.0, 0.4, 0.0))

	# --- the player, and the rifle he does not have yet.
	_player_node = _prop(PLAYER_MODEL, _player_pos, 1.15)
	if _player_node == null:
		var pm := BoxMesh.new()
		pm.size = Vector3(0.7, 1.7, 0.7)
		_player_node = _mesh(pm, Ep2Palette.make("leaf_green"), _player_pos + Vector3(0, 0.85, 0))
	# Rifle starts in the Bull's hands and moves to the player's on hand-off,
	# so the beat is visible and not just a flag flipping in a HUD.
	_rifle_node = _prop(RIFLE_MODEL, BULL_POSITION + Vector3(-0.9, 1.15, 0.0), 1.0, PI * 0.5)

	# --- the exit toward Fort Knox. Raised to 4.6 m: at 3.0 the bar sat exactly
	# behind the seated Bull's head in the pushed-in conversation framing and
	# read as a green halo around him.
	var gate := BoxMesh.new()
	gate.size = Vector3(4.5, 0.4, 0.4)
	_mesh(gate, Ep2Palette.make("gate"), Vector3(0.0, 4.6, EXIT_POSITION.z))


## Push the shared Episode 2 art direction onto this scene, using the FORGE
## environment rather than the tunnel one.
func _apply_art() -> void:
	var we := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we:
		we.environment = Ep2Palette.make_forge_environment()
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
		_player_node.position.y = 0.35 if _in_cover else 0.0
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
	# The rifle physically changes hands.
	if _rifle_node and is_instance_valid(_rifle_node):
		if _has_winchester:
			_rifle_node.position = Vector3(_player_pos.x + 0.45, 1.15, _player_pos.z)
			_rifle_node.rotation = Vector3(0.0, 0.0, deg_to_rad(-18.0))
		else:
			_rifle_node.position = BULL_POSITION + Vector3(-0.9, 1.15, 0.0)
