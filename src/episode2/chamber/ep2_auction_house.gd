class_name Ep2AuctionHouse
extends Node3D
## THE AUCTION HOUSE (founder brief PROMPT_AUCTION_HOUSE_RENEGADE_JACK_HAMMER_2026-11-08): the Gold Rush Auction as a public Wild West
## night - CAD hall and stage (tools/ep2_cad/auction_house_cad.py -> extras/town/auction_house.glb, dressed by Ep2Pbr's tileable sets),
## Renegade calling the week's lot from the block, women serving the floor, and the FIRST touch of Jack Hammer: seen, recognised, flees.
## Built INSIDE AuctionRoadChamber, so lake -> road -> grounds -> hall is one space: no door trigger, no swap, no teleport.
## Local frame: origin = the porch's front edge (road s = AuctionRoadChamber.PORCH_S), +z = the road's forward (into the hall), +x = right.
## The collision numbers mirror the CAD script's (W, D, DOOR_W, SIDE_DOOR_*, STAGE_*): change both together.
## Phases: "" outside -> "calls" (inside: Renegade works the room) -> "jack" (recognition) -> "flee" -> "after" -> "left" (out the front).

signal phase_changed(phase: String)

const KIT := "res://src/episode2/extras/town/auction_house.glb"
const RENEGADE := Ep2Extras.RENEGADE                # the founder's Drive GLB, shared with the cast record (Ep2JackHammer): authored clips
const JACK := "res://src/episode2/extras/people/jack_hammer.glb"
const DUDE := "res://src/episode2/assets/town/dude_stable_owner.glb"
const POSTER := "res://src/episode2/extras/town/posters/poster_jack_hammer.jpg"
const AUDIO := "res://src/episode2/extras/audio/town/"
const PEOPLE := "res://src/episode2/extras/people/"
const W := 22.0
const Z0 := 2.0                                     # the front wall; the hall runs to Z0 + 30
const Z1 := 32.0
const DOOR_W := 3.2
const SIDE_DOOR_Z := 26.0
const SIDE_DOOR_W := 1.4
const STAGE_Z0 := 24.0
const STAGE_Z1 := 31.6
const STAGE_X := 6.5
const STAGE_H := 1.1
const RAIL_Z := 12.0
const RAIL_GAP := 1.6
const BLEACH := Rect2(8.2, 6.0, 2.6, 12.0)          # x from 8.2 to the wall, z 6..18 (mirrored on the left)
const RADIUS := 0.35
const JACK_MARK := Vector3(-8.4, 0, 21.4)
const RENEGADE_MARK := Vector3(0.45, STAGE_H, 25.3)       # beside the rostrum, not behind it: the whole host reads from the floor
const HITCH := Vector3(-6.5, 0, -15.0)              # the hitching rail, beside the road short of the porch
const CALL_GAP := 5.8
const CALLS := [
	"RENEGADE: Welcome, claim holders, to the Gold Rush Auction! Seven days, one pool - every ounce of GOLD you forfeit buys your share of this week's XAUT. Pro-rata, no favourites!",
	"RENEGADE: Paper at the door, paddles on the floor! Your license gets you a number - your GOLD gets you the weight. The whole mine is bidding this week!",
	"RENEGADE: Do I hear forfeit? I hear forfeit! Paddle forty-one, paddle eighty-eight - real gold in a real box, settled when the week closes!",
]
const JACK_LINES := [
	"LIL BLUNT: Eye patch, long coat... that's the face on the Sheriff's poster. Jack Hammer.",
	"JACK HAMMER: Keep staring, little man. I only came to hear what's shipping out after the sale.",
	"RENEGADE: Well now - the man on my own claim board, standing right under it! Somebody fetch the Sheriff!",
]
const FLEE_LINE := "JACK HAMMER: Another day, auctioneer."
const PRESSURE_LINE := "RENEGADE: Lead in my hall?! There he goes - the one-eyed gent's running!"
const AFTER_LINES := [
	"LIL BLUNT: He's riding for the rail line. 'What's shipping'... he's after the claim shipment.",
	"RENEGADE: Ladies and gentlemen - THAT is the kind of excitement GOLD buys! Back to the week's lot!",
]
const DOOR_LINE := "DOORMAN: Evening. License? ...Mike Dean's seal - you're good. Take a number inside, they're calling the week's lot."
const BIDDERS := [["townsman_clerk", -3.0, 16.0], ["townsman_oldtimer", 3.4, 16.1], ["townsman_grandfather", -4.8, 19.6],
	["townsman_bald_worker", 4.4, 19.5], ["townsman_rancher", -5.6, 15.9], ["townsman_youth", 5.6, 19.4]]
const WATCHERS := [["townsman_oldtimer", -5.0, 11.2, 0.0], ["townsman_clerk", 4.6, 11.3, 0.0], ["townswoman_grandma", 9.4, 9.5, 0.9],
	["townsman_grandfather", -10.2, 14.0, 1.35], ["townsman_bald_worker", 10.2, 15.5, 1.35]]
const SERVERS := [
	["townsgirl_bob", [Vector3(-2, 0, 4), Vector3(0, 0, 11), Vector3(-4.2, 0, 17.2), Vector3(0, 0, 13), Vector3(2, 0, 6)], "Talk"],
	["townsgirl_braided", [Vector3(5, 0, 8), Vector3(0.8, 0, 12.6), Vector3(4.6, 0, 20.4), Vector3(7.4, 0, 22.6), Vector3(1, 0, 13)], "Talk"],
	["townswoman_lady", [Vector3(-7.4, 0, 23.0), Vector3(-5.2, 0, 21.2)], "Observe"],
	["townswoman_dressmaker", [Vector3(-4.2, 0.12, 0.9), Vector3(4.2, 0.12, 0.9)], "Greet"],
]

var built: bool = false
var phase: String = ""
var renegade: Ep2TownFolk
var jack: Ep2TownFolk
var say: Callable = Callable()                      # (text, seconds): the room's HUD speech
var _step: int = 0
var _kit: Node3D
var _rects: Array = []                              # Rect2 solids in (x, z), un-expanded
var _folk: Array = []                               # every shootable person but Jack
var _crowd: Array = []                              # bidders + watchers (react to the calls)
var _servers: Array = []                            # [folk, route, index, wait, pause clip]
var _doorman: Ep2TownFolk
var _arrival: Ep2TownFolk
var _t: float = 0.0
var _line: int = -1
var _door_said: bool = false
var _side_door: Node3D
var _door_swing: float = 0.0
var _cheer: AudioStreamPlayer3D
var _bell: AudioStreamPlayer3D
var _gallop: AudioStreamPlayer3D


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _kit != null:
		_kit.free()                                 # the template stays out of the tree (the room moves between parents when prebuilt)


## One slice per call (the room's build steps, or its _tick when the streamed pack mounts late). True once everything is up.
func build_next() -> bool:
	if built or not Ep2Extras.has(KIT):
		return built
	match _step:
		0: _shell()
		1: _furnish()
		2: _people()
	_step += 1
	built = _step >= 3
	if built:
		reset()
	return built


## Back to the start of the visit (a retry / a resumed road): Jack at the claim board, Renegade at the block, the floor at work.
func reset() -> void:
	phase = ""
	_t = 0.0
	_line = -1
	_door_said = false
	_door_swing = 0.0
	if _side_door != null:
		_side_door.rotation.y = 0.0
	if jack != null:
		jack.visible = true
		jack.walk_clip = "Walk"
		jack.place(JACK_MARK)
		jack.face_point(RENEGADE_MARK)
		jack.hold_clip("Idle")
	if renegade != null:
		renegade.place(RENEGADE_MARK)
		renegade.face_point(Vector3(0, 0, 10))
		renegade.hold_clip("Idle")


func _kit_piece(piece: String, pos: Vector3, yaw: float = 0.0, parent: Node3D = self) -> Node3D:
	var src: Node3D = _kit.find_child(piece, true, false) as Node3D if _kit != null else null
	if src == null:
		return null
	var n: Node3D = src.duplicate() as Node3D
	n.transform = Transform3D(Basis(Vector3.UP, yaw), pos)
	Ep2Pbr.dress(n)
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		for si in m.mesh.get_surface_count():
			var mat: Material = m.mesh.surface_get_material(si)
			if mat != null and mat.resource_name == "Glow":
				m.set_surface_override_material(si, _lamplit_glass())
	parent.add_child(n)
	return n


## Window glass lit from inside: warm, not blown to white under the filmic curve (the kit's emission 3.0 clips).
func _lamplit_glass() -> StandardMaterial3D:
	var g := StandardMaterial3D.new()
	g.albedo_color = Color(0.55, 0.32, 0.14)
	g.emission_enabled = true
	g.emission = Color(1.0, 0.58, 0.24)
	g.emission_energy_multiplier = 0.9
	g.roughness = 0.3
	return g


func _solid(cx: float, cz: float, hx: float, hz: float) -> void:
	_rects.append(Rect2(cx - hx, cz - hz, hx * 2.0, hz * 2.0))


func _label(text: String, pos: Vector3, yaw: float, size: int, color: Color = Color(0.98, 0.84, 0.46)) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.008
	l.modulate = color
	l.outline_modulate = Color(0.12, 0.06, 0.02)
	l.position = pos
	l.rotation.y = yaw
	add_child(l)


func _light(pos: Vector3, energy: float, rng: float, color: Color = Color(1.0, 0.68, 0.36)) -> OmniLight3D:
	var o := OmniLight3D.new()
	o.position = pos
	o.light_energy = energy
	o.omni_range = rng
	o.light_color = color
	add_child(o)
	return o


func _sound(file: String, pos: Vector3, loop: bool, unit: float, db: float = 0.0) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.position = pos
	p.bus = "SFX"
	p.unit_size = unit
	p.max_distance = 160.0
	p.volume_db = db
	if Ep2Extras.has(AUDIO + file):
		var s: AudioStream = (load(AUDIO + file) as AudioStream).duplicate()
		if loop and s is AudioStreamOggVorbis:
			(s as AudioStreamOggVorbis).loop = true
		p.stream = s
	add_child(p)
	if loop and p.stream != null:
		p.autoplay = true
		p.play()
	return p


## The hall, the stage, the signage and the light: what the road already sees from the gate.
func _shell() -> void:
	_kit = (load(KIT) as PackedScene).instantiate() as Node3D
	_kit_piece("Auc_Building", Vector3.ZERO)
	_kit_piece("Auc_Stage", Vector3.ZERO)
	_label("AUCTION HOUSE", Vector3(0, 10.55, Z0 - 0.2), PI, 150)
	var banner: MeshInstance3D = MeshInstance3D.new()
	var quad := BoxMesh.new()
	quad.size = Vector3(7.0, 0.95, 0.04)
	banner.mesh = quad
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(0.45, 0.06, 0.05)
	cloth.roughness = 0.9
	banner.material_override = cloth
	banner.position = Vector3(0, 7.85, Z0 - 0.16)
	add_child(banner)
	_label("GOLD RUSH AUCTION", Vector3(0, 7.85, Z0 - 0.2), PI, 72)
	_label("THIS WEEK'S CLAIM", Vector3(0, 6.5, STAGE_Z0 - 0.4), PI, 64)
	# the stage key from the truss and two chandelier pools; the porch lamps; the windows glow by their own emission
	var key := SpotLight3D.new()
	key.position = Vector3(0, 6.9, 17.0)
	key.light_color = Color(1.0, 0.8, 0.52)
	key.light_energy = 6.0
	key.spot_range = 22.0
	key.spot_angle = 34.0
	key.shadow_enabled = true
	add_child(key)
	key.look_at_from_position(key.position, RENEGADE_MARK + Vector3(0, 1.2, 0), Vector3.UP)
	_light(Vector3(0, 6.0, 9.0), 1.3, 13.0)
	_light(Vector3(0, 4.6, 25.0), 2.4, 9.0, Color(1.0, 0.74, 0.44))     # the stage's own pool: the block is the brightest place in the room
	var foot := MeshInstance3D.new()                                    # footlights: a row of oil-lamp flames along the stage lip
	var fm := BoxMesh.new()
	fm.size = Vector3(STAGE_X * 2.0 - 0.6, 0.06, 0.06)
	foot.mesh = fm
	var flame := StandardMaterial3D.new()
	flame.albedo_color = Color(1.0, 0.7, 0.35)
	flame.emission_enabled = true
	flame.emission = Color(1.0, 0.66, 0.3)
	flame.emission_energy_multiplier = 1.6
	foot.material_override = flame
	foot.position = Vector3(0, STAGE_H + 0.05, STAGE_Z0 + 0.12)
	add_child(foot)
	_light(Vector3(0, 6.0, 18.5), 1.1, 12.0)
	for sx in [-1.0, 1.0]:
		_light(Vector3(sx * 5.0, 3.6, 0.9), 1.2, 7.5)
	# solids: front wall (door gap), side walls (Jack's door gap on the left), back wall, stage + steps, rail, bleachers, porch posts
	var hw: float = W * 0.5
	_solid(-(hw + DOOR_W * 0.5) * 0.5, Z0, (hw - DOOR_W * 0.5) * 0.5, 0.1)
	_solid((hw + DOOR_W * 0.5) * 0.5, Z0, (hw - DOOR_W * 0.5) * 0.5, 0.1)
	_solid(hw - 0.1, (Z0 + Z1) * 0.5, 0.1, (Z1 - Z0) * 0.5)
	var lo: float = SIDE_DOOR_Z - SIDE_DOOR_W * 0.5
	var hi: float = SIDE_DOOR_Z + SIDE_DOOR_W * 0.5
	_solid(-hw + 0.1, (Z0 + lo) * 0.5, 0.1, (lo - Z0) * 0.5)
	_solid(-hw + 0.1, (hi + Z1) * 0.5, 0.1, (Z1 - hi) * 0.5)
	_solid(0, Z1 - 0.1, hw, 0.1)
	_solid(0, (STAGE_Z0 + STAGE_Z1) * 0.5, STAGE_X + 1.6, (STAGE_Z1 - STAGE_Z0) * 0.5)
	for i in 6:
		var x: float = -hw + 0.4 + i * (W - 0.8) / 5.0
		_solid(x, 0.25, 0.16, 0.16)
	_cheer = _sound("crowd_cheer.ogg", Vector3(0, 1.6, 17.0), false, 8.0, -4.0)
	_bell = _sound("town_draw_bell.ogg", RENEGADE_MARK + Vector3(0, 1.0, 0), false, 6.0, -6.0)
	_sound("town_saloon.ogg", Vector3(0, 2.0, 15.0), true, 7.0, -3.0)      # the night bed: heard faintly from the gate, full in the hall


## Block, strongbox, claim board and Jack's poster, the rail and side seating, the floor's benches, chandeliers, bunting, the grounds.
func _furnish() -> void:
	_kit_piece("Auc_Lectern", Vector3(-0.85, STAGE_H, 25.5))
	_kit_piece("Auc_Strongbox", Vector3(3.2, STAGE_H, 27.2), 0.3)
	_label("XAUT", Vector3(3.2, STAGE_H + 0.32, 26.86), PI + 0.3, 28)
	_kit_piece("Auc_ClaimBoard", Vector3(-W * 0.5 + 0.22, 0.9, 19.4), -PI * 0.5)
	_label("THIS WEEK'S CLAIM\nSEVEN DAYS · ONE POOL\nGOLD IN · XAUT OUT, PRO-RATA\nNUMBERS TAKEN AT THE DOOR", Vector3(-W * 0.5 + 0.36, 3.05, 19.4), PI * 0.5, 30)
	if ResourceLoader.exists(POSTER):
		var poster := Sprite3D.new()
		poster.texture = load(POSTER)
		poster.pixel_size = 0.7 / maxf(float(poster.texture.get_width()), 1.0)
		poster.position = Vector3(-W * 0.5 + 0.24, 1.9, 22.3)
		poster.rotation.y = PI * 0.5
		add_child(poster)
	for side in [-1.0, 1.0]:
		for i in 6:
			_kit_piece("Auc_Rail", Vector3(side * (2.1 + i), 0.12, RAIL_Z))
		for k in 3:
			_kit_piece("Auc_Bleacher", Vector3(side * (BLEACH.position.x + 0.4), 0.0, BLEACH.position.y + 2.0 + 4.0 * k), 0.0 if side > 0 else PI)
		_solid(side * 4.9, RAIL_Z, 3.3, 0.08)                # bays from the aisle gap (1.6) to the seating (8.2)
		_solid(side * (BLEACH.position.x + BLEACH.size.x * 0.5), BLEACH.position.y + BLEACH.size.y * 0.5, BLEACH.size.x * 0.5, BLEACH.size.y * 0.5)
		for z in [15.2, 18.6]:
			for x in [3.6, 6.6]:
				var bench: Node3D = Ep2KitProps.instance("Twn_Bench")
				if bench != null:
					bench.position = Vector3(side * x, 0.12, z)
					add_child(bench)
					_solid(side * x, z, 0.95, 0.3)
	for z in [9.0, 18.5]:
		var ch: Node3D = Ep2KitProps.instance("Twn_Chandelier")
		if ch != null:
			ch.position = Vector3(0, 6.9, z)
			add_child(ch)
	for x in [-7.0, -3.0, 1.0, 5.0]:
		_kit_piece("Auc_Bunting", Vector3(x + 1.0, 4.05, -0.05))
	# the grounds: lamp posts pooling warm light up the last stretch of road, the hitching rail with two horses already tied
	for i in 6:
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var z: float = -40.0 + i * 6.0
		_kit_piece("Auc_LampPost", Vector3(side * 4.6, 0, z), 0.0 if side < 0 else PI)
		_light(Vector3(side * 4.0, 2.5, z), 1.5, 7.0)
		_solid(side * 4.6, z, 0.12, 0.12)
	_kit_piece("Auc_HitchRail", HITCH, PI * 0.5)
	_solid(HITCH.x, HITCH.z, 0.12, 2.3)
	var horse_scene: PackedScene = load(LogansLakeChamber.HORSE_MODEL) if ResourceLoader.exists(LogansLakeChamber.HORSE_MODEL) else null
	for dz in [-3.0, 3.0]:
		if horse_scene == null:
			break
		var h: Node3D = Node3D.new()
		var m: Node3D = horse_scene.instantiate() as Node3D
		m.rotation.y = -PI * 0.5
		h.add_child(m)
		h.position = HITCH + Vector3(1.3, 0, dz)
		h.rotation.y = -PI * 0.5                    # nose to the rail
		add_child(h)
		for ap in m.find_children("*", "AnimationPlayer", true, false):
			if (ap as AnimationPlayer).has_animation("horse_stand"):
				(ap as AnimationPlayer).play("horse_stand")
		_solid(h.position.x, h.position.z, 1.0, 0.45)


func _person(model: String, pos: Vector3, height: float = 1.74) -> Ep2TownFolk:
	var f := Ep2TownFolk.new()
	f.looping_clips.assign(["Idle", "Walk", "Talk", "Observe", "Run", "Alert"])
	f.use_height = true
	add_child(f)
	f.setup(model if model.begins_with("res://") else PEOPLE + model + ".glb", height, Color(0.35, 0.3, 0.25))
	f.place(pos)
	return f


## Lend Mixamo clips between two Tripo rigs with the same bone names (Renegade has no cheer/clap; Jack has no run). Rotation tracks only,
## so a different rest height never lifts or sinks the body. The clips go into this person's own player, never the source model's library.
static func lend(folk: Ep2TownFolk, src_path: String, clips: Dictionary) -> void:
	if folk.model == null or not ResourceLoader.exists(src_path):
		return
	var src: Node = (load(src_path) as PackedScene).instantiate()
	var found: Array = src.find_children("*", "AnimationPlayer", true, false)
	var sks: Array = folk.model.find_children("*", "Skeleton3D", true, false)
	var src_sks: Array = src.find_children("*", "Skeleton3D", true, false)
	if found.is_empty() or sks.is_empty() or src_sks.is_empty():
		src.free()
		return
	var from: String = str(src.get_path_to(src_sks[0])) + ":"
	var to: String = str(folk.model.get_path_to(sks[0])) + ":"
	var ap: AnimationPlayer = folk.anim_player()
	if ap == null:
		ap = AnimationPlayer.new()
		folk.model.add_child(ap)
		ap.root_node = NodePath("..")
	var lib: AnimationLibrary = ap.get_animation_library("lent") if ap.has_animation_library("lent") else AnimationLibrary.new()
	for dst in clips:
		var a: Animation = (found[0] as AnimationPlayer).get_animation(clips[dst])
		if a == null:
			continue
		a = a.duplicate(true)
		for t in range(a.get_track_count() - 1, -1, -1):
			var path: String = str(a.track_get_path(t))
			if a.track_get_type(t) != Animation.TYPE_ROTATION_3D or not path.begins_with(from):
				a.remove_track(t)
			else:
				a.track_set_path(t, NodePath(to + path.substr(from.length())))
		a.loop_mode = Animation.LOOP_LINEAR if dst in ["Idle", "Talk", "Run", "Walk"] else Animation.LOOP_NONE
		lib.add_animation(dst, a)
	if not ap.has_animation_library("lent"):
		ap.add_animation_library("lent", lib)
	src.free()
	folk._bind_clips()


func _people() -> void:
	renegade = _person(RENEGADE, RENEGADE_MARK, 1.82)
	renegade.name = "Renegade"
	lend(renegade, JACK, {"Cheer": "cheer", "Clap": "clap", "Agree": "agree"})   # his own Idle/Talk/Greet/Point; the floor-work gestures lent
	jack = _person(JACK, JACK_MARK, 1.84)
	jack.name = "JackHammer"
	lend(jack, DUDE, {"Run": "run_001"})
	for row in BIDDERS:
		var f: Ep2TownFolk = _person(row[0], Vector3(row[1], 0.12, row[2]))
		f.face_point(RENEGADE_MARK)
		_attach(f, "Auc_Paddle", Vector3(0, 0.02, 0.04), Vector3(0, 0, 90))
		_crowd.append(f)
	for row in WATCHERS:
		var f: Ep2TownFolk = _person(row[0], Vector3(row[1], row[3] if row[3] > 0.0 else 0.12, row[2]))      # the floor, or a seating tier
		f.face_point(RENEGADE_MARK)
		_crowd.append(f)
	for row in SERVERS:
		var route: Array = row[1]
		var f: Ep2TownFolk = _person(row[0], route[0] + Vector3(0, 0.12, 0), 1.68)
		if row[2] == "Talk":
			_attach(f, "Auc_Tray", Vector3(0.0, 0.08, 0.06), Vector3(0, 0, 90))
		_servers.append([f, route, 0, randf() * 2.0, row[2]])
	_doorman = _person("townsman_rancher", Vector3(2.6, 0.12, 1.3))
	_doorman.face_point(Vector3(0, 0, -20))
	_arrival = _person("townsman_youth", Vector3(-7.0, 0, -36.0))
	_arrival.walk_path([Vector3(-1.4, 0, -6.0), Vector3(-0.8, 0.12, 1.0), Vector3(-2.6, 0.12, 10.6)], 1.3)
	_folk = _crowd + [renegade, _doorman, _arrival]
	for s in _servers:
		_folk.append(s[0])
	_side_door = Node3D.new()
	_side_door.position = Vector3(-W * 0.5 + 0.1, 0.12, SIDE_DOOR_Z - SIDE_DOOR_W * 0.5)
	add_child(_side_door)
	var leaf := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.06, 2.45, SIDE_DOOR_W - 0.06)
	leaf.mesh = bm
	leaf.position = Vector3(0, 1.22, SIDE_DOOR_W * 0.5)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.22, 0.14, 0.08)
	leaf.material_override = wood
	_side_door.add_child(leaf)
	_gallop = _sound("horse_whinny.ogg", Vector3(-W * 0.5 - 12.0, 1.0, SIDE_DOOR_Z + 6.0), false, 10.0)


func _attach(f: Ep2TownFolk, piece: String, pos: Vector3, rot: Vector3) -> void:
	var src: Node3D = _kit.find_child(piece, true, false) as Node3D
	if src == null:
		return
	var p: Node3D = src.duplicate() as Node3D
	p.name = piece
	Ep2Pbr.dress(p)
	f.attach_prop(p, "RightHand", pos, rot)


## True while the player is inside the hall's walls.
func inside(p: Vector3) -> bool:
	return p.z > Z0 + 0.3 and p.z < Z1 and absf(p.x) < W * 0.5


## Push a point (local) out of every solid (walls, stage, rail, seating, benches, posts, horses). Twice: corners settle.
func collide(p: Vector3) -> Vector3:
	for _pass in 2:
		for r in _rects:
			var rr: Rect2 = (r as Rect2).grow(RADIUS)
			if not rr.has_point(Vector2(p.x, p.z)):
				continue
			var dl: float = p.x - rr.position.x
			var dr: float = rr.end.x - p.x
			var dn: float = p.z - rr.position.y
			var df: float = rr.end.y - p.z
			var m: float = minf(minf(dl, dr), minf(dn, df))
			if m == dl: p.x = rr.position.x
			elif m == dr: p.x = rr.end.x
			elif m == dn: p.z = rr.position.y
			else: p.z = rr.end.y
	return p


## Any shot near the event is pressure: Jack does not wait to see where the next one goes.
func pressure() -> void:
	if built and phase in ["", "calls", "jack"]:
		_say(PRESSURE_LINE if renegade != null and not renegade.dead else FLEE_LINE, 3.5)
		_flee()


## A round along (eye, dir) in local space: a person falls (COMMON-SENSE RULE); Jack is never killed here - the shot sends him running.
func shot(eye: Vector3, dir: Vector3) -> bool:
	if not built:
		return false
	for f in _folk + [jack]:
		var folk: Ep2TownFolk = f
		if folk == null or folk.dead or not folk.visible:
			continue
		var centre: Vector3 = folk.position + Vector3(0, 1.0, 0)
		var t: float = (centre - eye).dot(dir)
		if t > 0.0 and t < 120.0 and (eye + dir * t).distance_to(centre) < 0.45:
			if folk == jack:
				pressure()
			else:
				folk.fall_dead()
				pressure()
			return true
	return false


func _say(text: String, seconds: float) -> void:
	if say.is_valid():
		say.call(text, seconds)


func _set_phase(p: String) -> void:
	phase = p
	_t = 0.0
	_line = -1
	phase_changed.emit(p)


func _flee() -> void:
	if phase in ["flee", "after", "left"] or jack == null:
		return
	_set_phase("flee")
	_door_swing = 0.0
	jack.walk_clip = "Run"
	jack.walk_path([Vector3(-9.8, 0.12, SIDE_DOOR_Z - 0.6), Vector3(-W * 0.5 - 1.5, 0.12, SIDE_DOOR_Z), Vector3(-W * 0.5 - 9.0, 0, SIDE_DOOR_Z + 9.0),
		Vector3(-W * 0.5 - 30.0, 0, SIDE_DOOR_Z + 30.0)], 5.2)
	for f in _crowd:
		if not (f as Ep2TownFolk).dead:
			(f as Ep2TownFolk).face_point(jack.position)
			(f as Ep2TownFolk).play_clip("Alert")


## The room's frame: `p` the player (local), `fwd` his view direction (local).
func tick(delta: float, p: Vector3, fwd: Vector3) -> void:
	if not built:
		return
	_t += delta
	for f in _folk + [jack]:
		if f != null:
			(f as Ep2TownFolk).step(delta)
	_tick_servers(delta)
	_tick_reactions(delta)
	if _arrival != null and not _arrival.is_walking() and not _arrival.dead:
		_arrival.face_point(RENEGADE_MARK)
	if not _door_said and _doorman != null and not _doorman.dead and p.distance_to(_doorman.position) < 4.0:
		_door_said = true
		_doorman.face_point(p)
		_doorman.play_clip("Talk")
		_say(DOOR_LINE, 4.5)
	match phase:
		"":
			if inside(p) and p.z > Z0 + 1.0:
				_set_phase("calls")
				if _bell.stream != null: _bell.play()
		"calls":
			var due: int = int(_t / CALL_GAP)
			if due > _line and due < CALLS.size():
				_line = due
				if not renegade.dead:
					_say(CALLS[_line], CALL_GAP - 0.3)
					renegade.play_clip(["Greet", "Point", "Cheer"][_line])
				_react()
			var to_jack: Vector3 = jack.position + Vector3(0, 1.5, 0) - (p + Vector3(0, 1.5, 0))
			var seen: bool = to_jack.length() < 16.0 and to_jack.normalized().dot(fwd.normalized()) > 0.93
			if (_line >= 1 and seen) or _t > CALL_GAP * CALLS.size() + 1.5:
				_set_phase("jack")
		"jack":
			var due: int = int(_t / 3.9)
			if due > _line and due < JACK_LINES.size():
				_line = due
				var text: String = JACK_LINES[_line]
				if not (text.begins_with("RENEGADE") and renegade.dead):
					_say(text, 3.7)
				if _line == 1:
					jack.face_point(p)
					jack.play_clip("Talk")
				if _line == 2:
					renegade.play_clip("Point")
					renegade.face_point(jack.position)
			if _t > 3.9 * JACK_LINES.size():
				_say(FLEE_LINE, 2.5)
				_flee()
		"flee":
			_door_swing = minf(1.0, _door_swing + delta * 3.0) if jack.position.z > SIDE_DOOR_Z - 2.0 or jack.position.x < -9.0 else _door_swing
			_side_door.rotation.y = -1.9 * _door_swing
			if not jack.is_walking():
				jack.visible = false
				if _gallop.stream != null: _gallop.play()
				_set_phase("after")
		"after":
			_side_door.rotation.y = lerpf(_side_door.rotation.y, -0.2, clampf(delta, 0.0, 1.0))
			var due: int = int(_t / 4.2)
			if due > _line and due < AFTER_LINES.size():
				_line = due
				if not (AFTER_LINES[_line].begins_with("RENEGADE") and renegade.dead):
					_say(AFTER_LINES[_line], 4.0)
					if _line == 1:
						renegade.face_point(Vector3(0, 0, 10))
						renegade.play_clip("Cheer")
						_react()
			if p.z < Z0 - 0.6 and _t > 1.0:
				_set_phase("left")


## The floor answers the block: paddles up, applause. People, not a chorus line (founder 2026-11-14: "they cheer like robots"): each one
## answers in his own time (REACT_SPREAD), with his own choice of cheer, clap or a nod (REACT_WEIGHTS), a few only look on, and the room's one
## cheer recording is not struck again on top of itself (CHEER_COOLDOWN; between whoops the claps carry the reaction).
const REACT_SPREAD := 0.55
const REACT_WEIGHTS := [["Cheer", 0.34], ["Clap", 0.38], ["Agree", 0.18], ["", 0.10]]
const CHEER_COOLDOWN := 7.0
var _react_queue: Array = []                       # [folk, seconds until he moves, clip]
var _cheer_at: float = -INF
## How many times the cheer recording was started, and every [seconds after the call, clip] the floor was given (the gate reads these).
var cheers_played: int = 0
var react_log: Array = []


func _react() -> void:
	if _cheer.stream != null and _t - _cheer_at >= CHEER_COOLDOWN:
		_cheer_at = _t
		cheers_played += 1
		_cheer.pitch_scale = randf_range(0.94, 1.06)
		_cheer.play()
	_react_queue.clear()
	react_log.clear()
	for f in _crowd:
		if (f as Ep2TownFolk).dead:
			continue
		var roll: float = randf()
		var clip: String = ""
		for w in REACT_WEIGHTS:
			roll -= float(w[1])
			if roll <= 0.0:
				clip = str(w[0])
				break
		var wait: float = randf() * REACT_SPREAD
		react_log.append([wait, clip])
		if clip != "":
			_react_queue.append([f, wait, clip])


## Each person starts his own answer when his moment comes.
func _tick_reactions(delta: float) -> void:
	for i in range(_react_queue.size() - 1, -1, -1):
		var r: Array = _react_queue[i]
		r[1] = float(r[1]) - delta
		if float(r[1]) > 0.0:
			continue
		var f: Ep2TownFolk = r[0]
		_react_queue.remove_at(i)
		if is_instance_valid(f) and not f.dead and phase in ["calls", "jack", "after"]:
			if not f.play_clip(str(r[2]), randf_range(0.9, 1.12)):
				f.play_clip("Clap")


func _tick_servers(delta: float) -> void:
	for s in _servers:
		var f: Ep2TownFolk = s[0]
		if f.dead:
			continue
		if f.is_walking():
			continue
		s[3] -= delta
		if s[3] > 0.0:
			if f.current_clip() != str(s[4]).to_lower():
				f.play_clip(s[4])
			continue
		var route: Array = s[1]
		s[2] = (int(s[2]) + 1) % route.size()
		f.walk_to(route[s[2]] + Vector3(0, 0.12, 0), 1.25)
		s[3] = 1.8 + randf() * 2.2
