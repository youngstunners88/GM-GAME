class_name Ep2BackLotMiners
extends Node3D
## THE BACK-LOT MINERS (founder prompt PROMPT_BACK_MINERS_2026-11-08 + his five reference images: a long-beard digger, a muscular man
## resting on a pitchfork, two men talking gold, an old man sat on a crate beside a man with a pick and shovel).
## Ambient local gold miners in the dirt lots BEHIND the false fronts - never on Main Street, never in front of a door, never in the duel lane.
##
## Efficient by the founder's rule: no new GLBs. Each miner reuses one of the streamed Meshy townsfolk bodies (Ep2TownPeople.ROSTER files),
## work-dirtied by a material tint and set apart by build scale; the tools, dirt mounds, ore pile and crate are a few primitive meshes.
## The tools are props only - no combat AI. They hold the tool in the hand the clip really has there: each frame the handle is laid from
## the right hand bone to where the tool rests (blade in the mound, tines on the ground), so whatever the clip does the hand stays on it.
##
## Common sense (ep2-world-common-sense): every miner is solid (a collision circle in the town's props, the same list Lil Blunt collides
## with), a seated man sits on a real crate sized from his own seated hips, and gunfire makes them stop work and look toward it (Alert)
## before they go back to it - notify_danger(), called beside Ep2TownPeople.notify_danger.

const BODY_R := 0.42                       # a working man's room: Lil Blunt walks round him, not through him
const DANGER_HOLD := 7.0                   # seconds a miner stays alert after a shot before going back to work
const DIRT := Color(0.80, 0.72, 0.62)      # work dirt over the body's own albedo (multiplied, never a colour swap)
const CLIPS_DIR := "res://src/episode2/extras/people/clips/"
const TALK_REACH := 16.0                   # Lil Blunt this close to a lot: its miners talk (nobody chatters to an empty yard)
const TALK_REST := [14.0, 24.0]            # seconds between one conversation and the next in the same lot
const VOICE_DB := -3.0

## The clusters (world x/z). Left lot: behind Bldg_A / Bldg_B (backs at x ~ -17/-18). Right lot: behind the Treasury (back x ~ 21) and
## Bldg_D (back x ~ 18). Checked against the town's walls, doors and horses by tests/ep2_back_lot_miners_test.
## body: the townsfolk GLB; voice: its town-audio speaker; h: height; bulk: x/z scale (the muscular one is broader); clip: what he does
## (a "clip_res" is a Meshy library clip extracted by tools/meshy/extract_clip.gd for his own rig); face: the point he works toward;
## tool: shovel | pitchfork | pick | ""; grip: "two" = held in both hands along the swing, otherwise the working end sits on "rest".
const MINERS: Array = [
	# the long-beard digger breaking ground at his heap with a pick (ref 1; Meshy "Heavy Hammer Swing", 2026-11-08, 3 credits)
	{"id": "digger", "lot": "L", "body": "townsman_oldtimer.glb", "voice": "oldtimer", "h": 1.70, "bulk": 1.0, "at": Vector2(-21.4, 1424.2),
		"face": Vector2(-22.4, 1424.9), "clip": "Dig", "clip_res": "oldtimer_dig.res", "tool": "pick", "grip": "two",
		"rest": Vector3(-21.84, 0.10, 1424.5), "mound": Vector3(-22.75, 0.0, 1425.1)},
	# the strong man on his pitchfork by the second heap (ref 2). Every so often he stands the fork up, kneels and pulls a rock out of the
	# dirt to look at it ("Pull Radish", 3 credits: as a forking motion it dragged the fork flat along the ground, so it is his rock pull)
	{"id": "forkman", "lot": "L", "body": "townsman_bald_worker.glb", "voice": "bald_worker", "h": 1.86, "bulk": 1.12, "at": Vector2(-20.6, 1427.6),
		"face": Vector2(-21.6, 1428.9), "clip": "Observe", "now_and_then": "Lift", "clip_res": "bald_worker_lift.res", "tool": "pitchfork",
		"rest": Vector3(-20.25, 0.0, 1427.15), "mound": Vector3(-21.6, 0.0, 1429.2)},
	# two miners talking gold by the ore pile (ref 3)
	{"id": "talker_a", "lot": "R", "body": "townsman_rancher.glb", "voice": "rancher", "h": 1.82, "bulk": 1.04, "at": Vector2(22.6, 1431.0),
		"face": Vector2(22.6, 1432.6), "clip": "Observe", "tool": "", "ore": Vector3(24.2, 0.0, 1431.9)},
	{"id": "talker_b", "lot": "R", "body": "townsman_youth.glb", "voice": "youth", "h": 1.74, "bulk": 1.06, "at": Vector2(22.6, 1432.6),
		"face": Vector2(22.6, 1431.0), "clip": "Idle", "tool": ""},
	# the old man sat on a crate, done for the day, the pick and shovel stood by him (ref 4 / 5)
	{"id": "sitter", "lot": "R", "body": "townsman_grandfather.glb", "voice": "grandfather", "h": 1.72, "bulk": 1.0, "at": Vector2(24.4, 1428.2),
		"face": Vector2(22.6, 1431.8), "clip": "Rest", "tool": "", "seat": true,
		"lean": [["pick", Vector3(24.05, 0.0, 1427.3)], ["shovel", Vector3(24.95, 0.0, 1427.5)]]},
]

## What they talk about (founder 2026-11-08: "conversing with each other about the protocol in a way that's relevant to their lives as
## miners in the town - day 88, certificates, auctions, Jack Hammer"). Voiced by the town cast's own ElevenLabs voices
## (assets/town-audio.json "miners_*", Ep2TownVoiceBank). Each line: [miner id, line id]. A lot plays its talks in turn, one at a time.
const TALKS: Dictionary = {
	"L": [
		[["digger", "miners_day88_1"], ["forkman", "miners_day88_2"], ["digger", "miners_day88_3"], ["forkman", "miners_day88_4"]],
		[["forkman", "miners_river_1"], ["digger", "miners_river_2"], ["forkman", "miners_river_3"], ["digger", "miners_river_4"]],
	],
	"R": [
		[["talker_b", "miners_certs_1"], ["talker_a", "miners_certs_2"], ["talker_b", "miners_certs_3"], ["talker_a", "miners_certs_4"]],
		[["talker_a", "miners_auction_1"], ["talker_b", "miners_auction_2"], ["talker_a", "miners_auction_3"], ["talker_b", "miners_auction_4"]],
		[["sitter", "miners_hammer_1"], ["talker_a", "miners_hammer_2"], ["sitter", "miners_hammer_3"], ["talker_b", "miners_hammer_4"],
			["sitter", "miners_hammer_5"]],
	],
}

class Miner:
	var id: String = ""
	var lot: String = ""
	var folk: Ep2TownFolk
	var clip: String = "Idle"
	var face: Vector3 = Vector3.ZERO
	var home_face: Vector3 = Vector3.ZERO
	var tool: Node3D = null              # the held tool (top_level: laid along his hands every frame)
	var tool_kind: String = ""
	var two_hands: bool = false
	var rest: Vector3 = Vector3.ZERO
	var hand: int = -1                   # right hand bone index
	var hand_l: int = -1
	var skel: Skeleton3D = null
	var alert_t: float = 0.0
	var danger: Vector3 = Vector3.ZERO
	var voice: AudioStreamPlayer3D = null
	var talking: bool = false            # saying a line right now (Talk clip, tool planted)
	var extra: String = ""               # an occasional task between spells of his base clip ("" = none)
	var extra_t: float = 0.0             # seconds until it starts (> 0) / of it left (< 0)
	var extra_len: float = 0.0

var miners: Array = []
var circles: Array = []                  # [[Vector2, radius], ...] - appended to the town's collision props by the chamber
var player_pos := Vector3(0, 0, -9999)   # set by the town chamber each frame (talk only within earshot)
var talks_done: Array = []               # [lot, line id] of every line said (gate + soundscape audit)
var _mats: Dictionary = {}
var _lot: Dictionary = {}                # lot -> {"talk": index, "line": index, "t": seconds left on this line / rest}


## Build every miner whose body is streamed in (Ep2Extras); returns how many stand in the lots. Safe to call again.
func build(seed_value: int = 811) -> int:
	for m in miners:
		if is_instance_valid(m.folk): m.folk.queue_free()
	for c in get_children(): c.queue_free()
	miners.clear()
	circles.clear()
	talks_done.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for row in MINERS:
		var path: String = Ep2Extras.PEOPLE_DIR + str(row["body"])
		if not Ep2Extras.has(path): continue
		var m := Miner.new()
		m.id = str(row["id"])
		m.lot = str(row["lot"])
		m.folk = Ep2TownFolk.new()
		m.folk.name = "Miner_" + m.id
		m.folk.ground_fn = Ep2GoldTown.ground_y
		m.folk.clip_blend = 0.25
		m.folk.looping_clips.assign(["Idle", "Talk", "Inspect", "Rest", "Observe", "Alert", "Dig", "Lift"])
		add_child(m.folk)
		if not m.folk.setup(path, float(row["h"])):
			m.folk.queue_free()
			continue
		var bulk: float = float(row.get("bulk", 1.0))
		m.folk.model.scale = Vector3(m.folk.model.scale.x * bulk, m.folk.model.scale.y, m.folk.model.scale.z * bulk)
		_dirty(m.folk.model)
		var at: Vector2 = row["at"]
		m.folk.place(Vector3(at.x, 0.0, at.y))
		var face: Vector2 = row["face"]
		m.face = Vector3(face.x, 0.0, face.y)
		m.home_face = m.face
		m.folk.face_point(m.face)
		m.folk.rotation.y = m.folk.facing          # built behind the woods, unseen: already turned to his work
		m.clip = str(row["clip"])
		var extra_slot: String = str(row.get("now_and_then", ""))
		if row.has("clip_res"):
			var ok: bool = _add_clip(m.folk, extra_slot if extra_slot != "" else m.clip, CLIPS_DIR + str(row["clip_res"]))
			if not ok and extra_slot == "": m.clip = "Observe"     # the extracted clip is missing: he stands at his work, no floating pose
			if ok and extra_slot != "":
				m.extra = extra_slot
				m.extra_len = (load(CLIPS_DIR + str(row["clip_res"])) as Animation).length
				m.extra_t = rng.randf_range(6.0, 16.0)
		m.folk.hold_clip(m.clip)                   # his base clip: Ep2TownFolk.step() returns to it every frame
		# no two of them breathe, swing or gesture in step
		var ap: AnimationPlayer = m.folk.anim_player()
		if ap != null and ap.current_animation != "":
			ap.seek(rng.randf_range(0.0, maxf(ap.current_animation_length - 0.1, 0.0)), true)
		m.skel = _skeleton(m.folk)
		m.hand = _bone(m.skel, ["righthand", "hand_r", "r_hand", "handr"])
		m.hand_l = _bone(m.skel, ["lefthand", "hand_l", "l_hand", "handl"])
		if bool(row.get("seat", false)):
			_seat_crate(m)
		m.tool_kind = str(row.get("tool", ""))
		if m.tool_kind != "" and m.hand >= 0:
			m.tool = _tool(m.tool_kind)
			m.tool.top_level = true
			m.folk.add_child(m.tool)
			m.rest = row["rest"]
			m.two_hands = str(row.get("grip", "")) == "two" and m.hand_l >= 0
		if row.has("mound"):
			add_child(_mound(row["mound"], 1.0 if m.tool_kind == "pick" else 0.7, rng))
		if row.has("ore"):
			add_child(_ore_pile(row["ore"], rng))
		for lean in row.get("lean", []):
			add_child(_leaning(str(lean[0]), lean[1], m.face))
		m.voice = AudioStreamPlayer3D.new()
		m.voice.name = "Voice"
		m.voice.bus = "SFX"
		m.voice.unit_size = 6.0
		m.voice.max_distance = 34.0
		m.voice.volume_db = VOICE_DB
		m.voice.position = Vector3(0.0, float(row["h"]) * 0.92, 0.0)
		m.folk.add_child(m.voice)
		circles.append([at, BODY_R * bulk])
		miners.append(m)
	for lot in TALKS:
		_lot[lot] = {"talk": rng.randi() % (TALKS[lot] as Array).size(), "line": -1, "t": rng.randf_range(2.0, 6.0)}
	return miners.size()


## A Meshy library clip extracted for this body's rig, added to its own animation library under the game's slot name.
func _add_clip(folk: Ep2TownFolk, slot: String, path: String) -> bool:
	if not ResourceLoader.exists(path): return false
	var anim: Animation = load(path) as Animation
	var ap: AnimationPlayer = folk.anim_player()
	if anim == null or ap == null: return false
	Ep2TownFolk.own_default_library(ap).add_animation(slot, anim)
	return true


## A shot or a fight in town: everyone within reach stops work (and talk) and looks toward it, then goes back to it.
func notify_danger(where: Vector3, radius: float = 40.0) -> void:
	for m in miners:
		if Vector2(m.folk.position.x - where.x, m.folk.position.z - where.z).length() > radius: continue
		m.alert_t = DANGER_HOLD
		m.danger = where
		if m.voice != null: m.voice.stop()
		m.talking = false
	for lot in _lot:
		_lot[lot]["line"] = -1
		_lot[lot]["t"] = DANGER_HOLD + 4.0


func miner(id: String) -> Miner:
	for m in miners:
		if m.id == id: return m
	return null


func _process(delta: float) -> void:
	for lot in _lot:
		_step_talk(str(lot), delta)
	for m in miners:
		if not is_instance_valid(m.folk): continue
		if m.alert_t > 0.0:
			m.alert_t -= delta
			m.folk.face_point(m.danger)
			if m.folk.current_clip() not in ["alert", "observe"]:
				m.folk.hold_clip("Alert" if m.folk.play_clip("Alert") else "Observe")
			if m.alert_t <= 0.0:
				m.face = m.home_face
				m.folk.face_point(m.face)
				m.folk.hold_clip(m.clip)
		_step_extra(m, delta)
		m.folk.step(delta)                       # Ep2TownFolk turns (and keeps its feet on the ground) only when its owner steps it
		if m.tool != null:
			_lay_tool(m)


## One lot's conversation: within earshot of Lil Blunt, the next talk plays line by line - the speaker stops work, turns to whoever he
## answers and says it (Talk clip, his own voice from his own mouth); the others keep working and glance over. Between talks they work.
func _step_talk(lot: String, delta: float) -> void:
	var s: Dictionary = _lot[lot]
	s["t"] = float(s["t"]) - delta
	if float(s["t"]) > 0.0: return
	var talk: Array = TALKS[lot][int(s["talk"])]
	var line: int = int(s["line"]) + 1
	for m in miners:
		if m.lot == lot and m.talking:
			m.talking = false
			m.face = m.home_face
			m.folk.face_point(m.face)
			m.folk.hold_clip(m.clip)
	if line >= talk.size():                  # talk over: back to work, the next talk later
		s["line"] = -1
		s["talk"] = (int(s["talk"]) + 1) % (TALKS[lot] as Array).size()
		s["t"] = randf_range(TALK_REST[0], TALK_REST[1])
		return
	var near: bool = false
	for m in miners:
		if m.lot == lot and m.alert_t <= 0.0 and m.folk.position.distance_to(player_pos) < TALK_REACH: near = true
	if line == 0 and not near:
		s["t"] = 1.0                            # nobody to overhear: they keep working and look again in a second
		return
	var who: Miner = miner(str(talk[line][0]))
	var id: String = str(talk[line][1])
	if who == null:
		s["line"] = line
		s["t"] = 0.0
		return
	# whom he answers: the previous speaker, or on the first line the next one
	var to: Miner = miner(str(talk[line - 1][0] if line > 0 else talk[mini(1, talk.size() - 1)][0]))
	who.talking = true
	if to != null and to != who:
		who.face = to.folk.position
		who.folk.face_point(who.face)
	who.folk.hold_clip("Rest" if who.clip == "Rest" else "Talk")    # the seated man talks from his crate
	var take: AudioStream = Ep2TownVoiceBank.stream(id)
	if take != null:
		who.voice.stream = take
		who.voice.play()
	talks_done.append([lot, id])
	s["line"] = line
	s["t"] = Ep2Speech.pace(id, str(Ep2TownVoiceBank.LINES.get(id, {}).get("text", "")))


## The occasional task: once, between spells of his base clip, never while talking or alert.
func _step_extra(m: Miner, delta: float) -> void:
	if m.extra == "": return
	if m.talking or m.alert_t > 0.0:
		if m.extra_t < 0.0:
			m.extra_t = 8.0
		return
	if m.extra_t > 0.0:
		m.extra_t -= delta
		if m.extra_t <= 0.0:
			m.folk.hold_clip(m.extra)
			m.extra_t = -m.extra_len
		return
	m.extra_t += delta
	if m.extra_t >= 0.0:
		m.folk.hold_clip(m.clip)
		m.extra_t = randf_range(14.0, 26.0)


## Working: the handle lies along both hands (the pick's head past the right, the fork's tines below the lower hand). Talking or on
## alert: one hand on it, the working end planted on the ground at his side.
func _lay_tool(m: Miner) -> void:
	var r: Vector3 = (m.skel.global_transform * m.skel.get_bone_global_pose(m.hand)).origin
	if m.two_hands and not m.talking and m.alert_t <= 0.0:
		var l: Vector3 = (m.skel.global_transform * m.skel.get_bone_global_pose(m.hand_l)).origin
		if m.tool_kind == "pick":
			var axis: Vector3 = (r - l).normalized() if r.distance_to(l) > 0.08 else Vector3.UP
			_orient(m.tool, l - axis * 0.12, axis)               # handle end just past the left hand, the head beyond the right
		else:
			var hi: Vector3 = r if r.y >= l.y else l
			var lo: Vector3 = l if r.y >= l.y else r
			var axis: Vector3 = (hi - lo).normalized() if hi.distance_to(lo) > 0.08 else Vector3.UP
			_orient(m.tool, lo - axis * 0.95, axis)              # tines a metre past the lower hand, into the dirt he lifts
		return
	if m.extra != "" and m.extra_t < 0.0:     # kneeling at his task: the tool stands on its own, a little leant, where he left it
		_orient(m.tool, m.rest, Vector3(0.12, 1.0, 0.0).normalized())
		return
	var foot: Vector3 = m.rest if m.alert_t <= 0.0 and not m.talking else Vector3(r.x, r.y - 0.9, r.z)
	if m.talking and not m.two_hands:
		foot = m.rest
	var along: Vector3 = r - foot
	if along.length() < 0.05: return
	_orient(m.tool, foot, along.normalized())


func _orient(tool: Node3D, origin: Vector3, up: Vector3) -> void:
	var side: Vector3 = up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT).normalized()
	tool.global_transform = Transform3D(Basis(side, up, side.cross(up).normalized()), origin)


## A seated clip on a crate: the crate's top meets his hips, measured from his own Rest pose (founder 2026-11-04: nobody sits on air).
func _seat_crate(m: Miner) -> void:
	var hips: int = _bone(m.skel, ["hips", "pelvis"])
	var top: float = 0.45
	var at := Vector2(m.folk.position.x, m.folk.position.z)
	if hips >= 0 and m.folk.current_clip() == m.clip.to_lower():
		# measure the settled seated pose, not the cross-fade out of Idle that play_clip starts
		var ap: AnimationPlayer = m.folk.anim_player()
		var anim: StringName = ap.current_animation
		var t: float = ap.current_animation_position
		ap.stop()
		ap.play(anim, 0.0)
		ap.seek(t, true)
		var hp: Vector3 = (m.skel.global_transform * m.skel.get_bone_global_pose(hips)).origin
		top = clampf(hp.y - m.folk.position.y - 0.10, 0.3, 0.62)
		at = Vector2(hp.x, hp.z)
		# behind the hips a little: he sits on the front half of it
		var back: Vector3 = (m.folk.position - m.face).normalized() * 0.08
		at += Vector2(back.x, back.z)
	var crate := MeshInstance3D.new()
	crate.name = "MinerCrate"
	var bm := BoxMesh.new()
	bm.size = Vector3(0.62, top, 0.5)
	crate.mesh = bm
	crate.material_override = _mat("crate", Color(0.42, 0.31, 0.20), 0.92)
	crate.position = Vector3(at.x, Ep2GoldTown.ground_y(Vector3(at.x, 0, at.y)) + top * 0.5, at.y)
	crate.rotation.y = m.folk.rotation.y
	add_child(crate)
	set_meta("seat_top_" + m.id, crate.position.y + top * 0.5)


## Work dirt: every surface's own material, duplicated and multiplied toward dust (the body keeps its own look, only grimier).
func _dirty(root: Node) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_i: MeshInstance3D = mi
		if mesh_i.mesh == null: continue
		for s in mesh_i.mesh.get_surface_count():
			var src: Material = mesh_i.get_active_material(s)
			if src is BaseMaterial3D:
				var d: BaseMaterial3D = (src as BaseMaterial3D).duplicate()
				d.albedo_color = d.albedo_color * DIRT
				d.roughness = minf(1.0, d.roughness + 0.1)
				mesh_i.set_surface_override_material(s, d)


# ---- props: a few primitives, shared materials ------------------------------------------------------------------------------------

func _mat(key: String, c: Color, rough: float, metal: float = 0.0) -> StandardMaterial3D:
	if _mats.has(key): return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	_mats[key] = m
	return m


func _part(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


const TOOL_LEN := {"shovel": 1.52, "pitchfork": 1.95, "pick": 0.95}

## A tool with its working end at the origin and the handle up local +y (the grip at the top).
func _tool(kind: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Tool_" + kind
	var wood := _mat("handle", Color(0.48, 0.34, 0.21), 0.8)
	var iron := _mat("iron", Color(0.30, 0.29, 0.28), 0.45, 0.7)
	var handle := CylinderMesh.new()
	handle.top_radius = 0.018
	handle.bottom_radius = 0.022
	match kind:
		"shovel":
			handle.height = 1.15
			_part(root, handle, wood, Vector3(0, 0.30 + 0.575, 0))
			var blade := BoxMesh.new()
			blade.size = Vector3(0.24, 0.30, 0.02)
			_part(root, blade, iron, Vector3(0, 0.15, 0))
			var grip := CylinderMesh.new()
			grip.top_radius = 0.016; grip.bottom_radius = 0.016; grip.height = 0.14
			_part(root, grip, wood, Vector3(0, 1.45, 0), Vector3(0, 0, 90))
		"pitchfork":
			handle.height = 1.65                  # a long hay fork: in the lift his hands are 0.9 m apart on it
			_part(root, handle, wood, Vector3(0, 0.30 + 0.825, 0))
			var bar := BoxMesh.new()
			bar.size = Vector3(0.24, 0.04, 0.03)
			_part(root, bar, iron, Vector3(0, 0.30, 0))
			var tine := CylinderMesh.new()
			tine.top_radius = 0.008; tine.bottom_radius = 0.004; tine.height = 0.30
			for x in [-0.105, -0.035, 0.035, 0.105]:
				_part(root, tine, iron, Vector3(x, 0.15, 0))
		"pick":
			handle.height = 0.95
			_part(root, handle, wood, Vector3(0, 0.475, 0))
			var head := CylinderMesh.new()
			head.top_radius = 0.004; head.bottom_radius = 0.03; head.height = 0.32
			_part(root, head, iron, Vector3(0.16, 0.95, 0), Vector3(0, 0, 90))
			_part(root, head, iron, Vector3(-0.16, 0.95, 0), Vector3(0, 0, -90))
	return root


## A tool stood on its working end, leaning a few degrees back toward the seated man's crate.
func _leaning(kind: String, at: Vector3, toward: Vector3) -> Node3D:
	var t := _tool(kind)
	var g: float = Ep2GoldTown.ground_y(at)
	if kind == "pick":                      # a pick stands on its head's point, the handle up
		t.position = Vector3(at.x, g, at.z)
		t.rotation_degrees = Vector3(0, 0, 0)
	else:
		t.position = Vector3(at.x, g, at.z)
	var away: Vector3 = (at - toward)
	t.rotation.y = atan2(away.x, away.z)
	t.rotate_object_local(Vector3.RIGHT, deg_to_rad(-9.0))
	return t


## A heap of turned earth: a few flattened spheres and clods (ref 1's dig).
func _mound(at: Vector3, size: float, rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	root.name = "DirtMound"
	root.position = Vector3(at.x, Ep2GoldTown.ground_y(at), at.z)
	var earth := _mat("earth", Color(0.47, 0.35, 0.25), 1.0)
	for i in 4:
		var sm := SphereMesh.new()
		var r: float = size * rng.randf_range(0.45, 0.7)
		sm.radius = r
		sm.height = r * 1.1
		sm.radial_segments = 14
		sm.rings = 6
		_part(root, sm, earth, Vector3(rng.randf_range(-0.5, 0.5) * size, r * 0.12, rng.randf_range(-0.4, 0.4) * size))
	for i in 7:
		var clod := SphereMesh.new()
		clod.radius = rng.randf_range(0.05, 0.11)
		clod.height = clod.radius * 1.4
		clod.radial_segments = 6
		clod.rings = 3
		var a: float = rng.randf() * TAU
		_part(root, clod, earth, Vector3(cos(a), 0.0, sin(a)) * size * rng.randf_range(0.8, 1.3) + Vector3(0, 0.04, 0))
	return root


## The ore they are talking about: grey rock with gold flecks (the GoldMine read without a single coin).
func _ore_pile(at: Vector3, rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	root.name = "OrePile"
	root.position = Vector3(at.x, Ep2GoldTown.ground_y(at), at.z)
	var rock := _mat("rock", Color(0.40, 0.37, 0.33), 0.95)
	var gold := _mat("gold", Color(0.95, 0.72, 0.25), 0.3, 1.0)
	for i in 9:
		var bm := BoxMesh.new()
		var s: float = rng.randf_range(0.14, 0.3)
		bm.size = Vector3(s, s * 0.7, s * rng.randf_range(0.8, 1.2))
		_part(root, bm, rock, Vector3(rng.randf_range(-0.4, 0.4), s * 0.3 + (0.12 if i > 5 else 0.0), rng.randf_range(-0.35, 0.35)),
				Vector3(rng.randf_range(-25, 25), rng.randf() * 180.0, rng.randf_range(-25, 25)))
	for i in 6:
		var nug := SphereMesh.new()
		nug.radius = rng.randf_range(0.025, 0.045)
		nug.height = nug.radius * 1.5
		nug.radial_segments = 6
		nug.rings = 3
		_part(root, nug, gold, Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(0.12, 0.3), rng.randf_range(-0.25, 0.25)))
	return root


static func _skeleton(folk: Ep2TownFolk) -> Skeleton3D:
	var found: Array = folk.find_children("*", "Skeleton3D", true, false)
	return found[0] if not found.is_empty() else null


static func _bone(skel: Skeleton3D, keys: Array) -> int:
	if skel == null: return -1
	for i in skel.get_bone_count():
		var n: String = skel.get_bone_name(i).to_lower().replace(":", "_").replace(".", "_")
		for k in keys:
			if n.ends_with(str(k)) or n.replace("_", "").ends_with(str(k).replace("_", "")):
				return i
	return -1
