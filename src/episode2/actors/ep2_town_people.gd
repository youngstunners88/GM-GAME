class_name Ep2TownPeople
extends RefCounted
signal greeted(person_id: String, actor: Ep2TownFolk, count: int)
signal cold_greeted(person_id: String, actor: Ep2TownFolk)
## Independent deterministic ambient brains. All thirteen supplied public figures; the jail prisoner is story-controlled.
## No wall-clock timers, external AI, quest dialogue, combat targets or unbounded wandering.
const GREET_R := 3.6
const GREET_COOLDOWN := 24.0
const COLD_CLEARANCE := 2.5
const COLD_SPEAKERS := ["clerk", "oldtimer", "rancher", "grandma", "youth"]
const BODY_R := 0.31
const LOOPING_CLIPS := ["Idle", "Walk", "Observe", "Rest", "Talk", "Inspect", "Alert", "Play", "Cheer", "Clap", "DanceA", "DanceB"]
## The celebration after the draw (celebrate()): the ring's radius round Lil Blunt, how far people come from to join, the room kept round
## the fallen stranger, the cheering and the dancing (seconds), and the grace before a stray celebrant simply carries on.
const CEL_STATES := ["cel_go", "cel_cheer", "cel_dance"]
const CEL_R := 4.6
const CEL_REACH := 26.0
const CEL_PAIR_GAP := 1.25                # metres between dance partners' ring spots
const CEL_RUSH := 1.7                     # they hurry over to him (their own walk, played quicker)
const CEL_AVOID := 3.2
const CHEER_S := 9.0
const DANCE_S := 16.0
const CEL_GRACE := 12.0
## The children (and the youth) PLAY in their town: tag-style hops, a jump rope - their own clip from the Meshy cast.
const PLAYERS := ["boy", "braided_girl", "bob_girl", "youth"]
## walk_speed: the Meshy walk clip's own ground speed (m/s, measured by tools/meshy/townfolk_batch.py foot FK) - stride matching.
const ROSTER: Array = [
	{"id": "clerk", "file": "townsman_clerk.glb", "h": 1.76, "walk_speed": 0.648, "route": [Vector2(-2.6, 1408.5), Vector2(-2.6, 1423.0), Vector2(-2.6, 1437.0)], "speed": 0.95, "pause": [3.0, 8.0]},
	{"id": "oldtimer", "file": "townsman_oldtimer.glb", "h": 1.69, "walk_speed": 0.510, "route": [Vector2(2.6, 1424.0), Vector2(2.6, 1437.0), Vector2(1.2, 1444.0)], "speed": 0.78, "pause": [5.0, 12.0]},
	{"id": "rancher", "file": "townsman_rancher.glb", "h": 1.84, "walk_speed": 0.671, "route": [Vector2(2.9, 1431.0), Vector2(0.4, 1421.0), Vector2(2.9, 1431.0), Vector2(-0.8, 1436.0)], "speed": 1.05, "pause": [6.0, 14.0]},
	{"id": "dressmaker", "file": "townswoman_dressmaker.glb", "h": 1.66, "walk_speed": 1.344, "route": [Vector2(1.0, 1409.5), Vector2(1.0, 1427.0), Vector2(1.0, 1445.0)], "speed": 0.88, "pause": [2.5, 6.0]},
	{"id": "lady", "file": "townswoman_lady.glb", "h": 1.72, "walk_speed": 1.379, "route": [Vector2(-0.6, 1444.0), Vector2(-0.6, 1428.0), Vector2(-0.6, 1411.0)], "speed": 0.82, "pause": [4.0, 9.0]},
	{"id": "bald_worker", "file": "townsman_bald_worker.glb", "h": 1.8, "walk_speed": 1.266, "speed": 0.99, "route": [Vector2(-2.0, 1410), Vector2(2.0, 1412)], "pause": [4.0, 10.0]},
	{"id": "grandma", "file": "townswoman_grandma.glb", "h": 1.57, "walk_speed": 0.551, "speed": 0.68, "route": [Vector2(-2.0, 1413), Vector2(2.0, 1415)], "pause": [4.0, 10.0]},
	{"id": "grandfather", "file": "townsman_grandfather.glb", "h": 1.73, "walk_speed": 0.524, "speed": 0.73, "route": [Vector2(-2.0, 1416), Vector2(2.0, 1418)], "pause": [4.0, 10.0]},
	{"id": "grandmother", "file": "townswoman_grandmother.glb", "h": 1.59, "walk_speed": 0.495, "speed": 0.7, "route": [Vector2(-2.0, 1419), Vector2(2.0, 1421)], "pause": [4.0, 10.0]},
	{"id": "youth", "file": "townsman_youth.glb", "h": 1.67, "walk_speed": 1.167, "speed": 1.12, "route": [Vector2(-2.0, 1422), Vector2(2.0, 1424)], "pause": [4.0, 10.0]},
	{"id": "boy", "file": "townsboy.glb", "h": 1.36, "walk_speed": 0.956, "speed": 1.16, "route": [Vector2(-2.0, 1425), Vector2(2.0, 1427)], "pause": [4.0, 10.0]},
	{"id": "braided_girl", "file": "townsgirl_braided.glb", "h": 1.34, "walk_speed": 0.752, "speed": 1.02, "route": [Vector2(-2.0, 1428), Vector2(2.0, 1430)], "pause": [4.0, 10.0]},
	{"id": "bob_girl", "file": "townsgirl_bob.glb", "h": 1.28, "walk_speed": 1.084, "speed": 0.98, "route": [Vector2(-2.0, 1431), Vector2(2.0, 1433)], "pause": [4.0, 10.0]},
]

const PROFILES := {
	"clerk": {"social": 0.72, "rest": 0.45, "interests": ["saloon", "office", "notice"], "label": "Pianist", "temperament": "observant"},
	"oldtimer": {"social": 0.38, "rest": 0.90, "interests": ["rest_south", "horses", "notice"], "label": "Old-timer", "temperament": "reserved"},
	"rancher": {"social": 0.54, "rest": 0.30, "interests": ["horses", "water", "yard"], "label": "Rancher", "temperament": "practical"},
	"dressmaker": {"social": 0.67, "rest": 0.32, "interests": ["shop", "market", "office"], "label": "Dressmaker", "temperament": "busy"},
	"lady": {"social": 0.78, "rest": 0.40, "interests": ["market", "notice", "saloon"], "label": "Market visitor", "temperament": "outgoing"},
	"bald_worker": {"social": 0.42, "rest": 0.30, "interests": ["yard", "water", "office"], "label": "Worker", "temperament": "industrious"},
	"grandma": {"social": 0.80, "rest": 0.85, "interests": ["rest_south", "market", "notice"], "label": "Grandmother", "temperament": "welcoming"},
	"grandfather": {"social": 0.48, "rest": 0.82, "interests": ["rest_north", "horses", "saloon"], "label": "Grandfather", "temperament": "unhurried"},
	"grandmother": {"social": 0.64, "rest": 0.87, "interests": ["rest_north", "shop", "market"], "label": "Elder companion", "temperament": "companionable"},
	"youth": {"social": 0.61, "rest": 0.18, "interests": ["yard", "notice", "market"], "label": "Young townsman", "temperament": "curious"},
	"boy": {"social": 0.74, "rest": 0.24, "interests": ["water", "market", "rest_south"], "label": "Boy", "temperament": "energetic"},
	"braided_girl": {"social": 0.58, "rest": 0.30, "interests": ["shop", "market", "rest_north"], "label": "Braided girl", "temperament": "inquisitive"},
	"bob_girl": {"social": 0.45, "rest": 0.38, "interests": ["rest_south", "shop", "water"], "label": "Bob-haired girl", "temperament": "watchful"},
}
## Ground-level destinations beside the town's actual institutions. No invented enterable shops or raised-porch walking.
const PLACES := {
	"office": Vector2(-3.2, 1409), "saloon": Vector2(-3.2, 1424),
	"shop": Vector2(3.0, 1412), "market": Vector2(3.0, 1436),
	"notice": Vector2(-3.0, 1437), "horses": Vector2(2.6, 1428),
	"water": Vector2(-2.8, 1444), "yard": Vector2(-13.0, 1457),
	"rest_south": Vector2(-2.6, 1401), "rest_north": Vector2(3.0, 1450),
}
const SHELTERS := [Vector2(-3.2, 1401), Vector2(3.2, 1401), Vector2(-3.2, 1450), Vector2(3.2, 1450), Vector2(-15, 1456)]
const ACTIVITIES := ["work", "errand", "rest", "observe", "social", "play"]
## SHOPPING (founder 2026-10-24: "people in the town have real activities. perhaps some entering the stores and leaving. buying things").
## An errand can be a real trip into one of the walk-in shops (Ep2GoldTown.WALKIN_SHOPS, open when the streamed kit is drawn): walk the
## street graph to the foot of its porch steps, step up onto the porch, in through the door to the counter, buy (talk to the keeper),
## and back out - from the general store with a paper parcel in hand. One customer at a time per counter (reservation "shop:<piece>").
## Indoors is safe: a danger or the duel leaves a shopper inside until it has passed.
const SHOP_STATES := ["shop_queue", "shop_in", "shop_buy", "shop_leave_wait", "shop_out"]
## Traffic: one person at a time walks between the street and their place inside ("door:<piece>" reservation), so nobody passes
## through anybody in a doorway or an aisle; each visitor waits at their own spot along the front ("slot:<piece>#k", 1.3 m apart).
const SLOT_OFFSETS := [0.0, -1.3, 1.3, -2.6, 2.6]
## THE SALOON (founder 2026-10-24: "sitting and drinking in the saloon as well as the balcony above"; skill ep2-saloon-drinkers). A saloon
## visit is a shop visit whose "counter" is a free chair at a table (sit, drink - Ep2DrinkPose's SitDrink built from the person's own
## rig - then leave) or the bar (StandDrink). Each seat is its own reservation ("shop:Bldg_Saloon#<seat>"), so several drink at once.
## The two balcony regulars start the day up there and stay, drinking and watching the street.
const BALCONY_REGULARS := ["grandfather", "oldtimer"]
## The table regulars (founder 2026-10-27: "the bar has sitters"): two locals keep two of the saloon's table chairs all day, like the
## balcony pair (a third would take one too many cheering people off the street after the draw); visitors take the third chair or the
## bar. Every drinker has their own sip (Ep2DrinkPose.install_variant seeded by drink_seed: a 5.0-8.5 s loop), so no two share one
## rhythm, and now and then one laughs (their laugh clip + a recorded laugh) or clinks a glass (drink_events, Ep2TownSoundscape).
const TABLE_REGULARS := ["bald_worker", "grandmother"]
const DRINK_VARIANTS := {"SitIdle": "SitDrink", "SitLaugh": "SitDrink", "SitSmoke": "SitDrink",
	"StandIdle": "StandDrink", "StandLaugh": "StandDrink", "StandSmoke": "StandDrink"}
const GLASS := "res://src/episode2/assets/whiskey_glass.glb"
const SHOP_CHANCE := 0.55                # share of errands that become a shop visit when a counter is free
const PARCEL_SECONDS := 40.0

class Person:
	var external_owner: String = ""
	var id: String = ""
	var folk: Ep2TownFolk
	var route: Array = [] # historical route fixtures, no longer the decision policy
	var speed: float = 1.0
	var pause_range := Vector2(3, 8)
	var state: String = "pause"
	var timer: float = 1.0
	var greet_cd: float = 0.0
	var greets: int = 0
	var walked_m: float = 0.0
	var rng := RandomNumberGenerator.new()
	var profile: Dictionary = {}
	var activity: String = "observe"
	var destination: String = ""
	var waypoints: Array[Vector2] = []
	var recent: Array[String] = []
	var visits: Dictionary = {}
	var memories: Dictionary = {}
	var choices: int = 0
	var blocked: float = 0.0
	var recoveries: int = 0
	var social_cd: float = 0.0
	var partner: String = ""
	var fear: float = 0.0
	var threat := Vector2.ZERO
	var activity_time: float = 0.0
	var safety := Vector2.ZERO
	var shop: String = ""            # the walk-in shop (Bldg_A / B / C) this person is visiting, "" when outdoors
	var parcel_t: float = 0.0        # seconds left carrying what they bought
	var seat: int = -1                 # saloon place (Ep2GoldTown.saloon_seats() index), -1 = not in the saloon
	var slot: int = -1                 # their waiting spot along the shop front (SLOT_OFFSETS index), -1 = none
	var drink_seed: int = 0            # this person's own sip timing (Ep2DrinkPose.install_variant), from their id
	var drink_clock: float = 0.0       # seconds since their last laugh or clink in the saloon (ambient only, not saved)
	var drink_beats: int = 0
	var laugh_t: float = 0.0           # seconds left of a laugh before the sip comes back
	var drink_events: Array[Dictionary] = []   # {"kind": "laugh" | "clink", "at", "female", "variant"} for the soundscape

var people: Array = []
var navigation := Ep2TownNavigation.new()
var reservations: Dictionary = {}
var elapsed: float = 0.0
var _seed: int = 4101
var _configured: bool = false
var _mode: String = "normal" # normal | quiet | duel
var _cel: Dictionary = {}     # the celebration after the draw while it runs (celebrate()); empty otherwise
var _story_was_duel: bool = false
## Radius around the player that people keep clear of (0.68 on foot; the woods ride raises it for the quad).
var player_clearance: float = 0.68

func configure_space(info: Dictionary) -> void:
	navigation.configure(info)
	_configured = true

func build(parent: Node3D, seed_value: int = 4101) -> int:
	# Safe repeated build: retire only this controller's instances.
	for p in people:
		if is_instance_valid(p.folk):
			p.folk.get_parent().remove_child(p.folk)
			p.folk.queue_free()
	people.clear()
	reservations.clear()
	elapsed = 0.0
	_seed = seed_value
	if not _configured:
		# Compatibility fixtures pass no info; derive the same town collision using a temporary holder.
		var geometry := Node3D.new()
		parent.add_child(geometry)
		configure_space(Ep2GoldTown.build(geometry, true))
		parent.remove_child(geometry)
		geometry.queue_free()
	for row in ROSTER:
		var path: String = Ep2Extras.PEOPLE_DIR + str(row["file"])
		if not Ep2Extras.has(path): continue
		var p := Person.new()
		p.id = str(row["id"])
		p.rng.seed = seed_value + int(p.id.hash())
		p.drink_seed = absi(int(p.id.hash())) % 100003 + 7919
		p.profile = PROFILES[p.id].duplicate(true)
		p.folk = Ep2TownFolk.new()
		p.folk.name = "Person_" + p.id
		p.folk.clip_blend = 0.18
		p.folk.looping_clips.assign(LOOPING_CLIPS)
		p.folk.arrival_radius = 0.003
		parent.add_child(p.folk)
		if not p.folk.setup(path, float(row["h"])):
			p.folk.queue_free()
			continue
		# Meshy cast (2026-10-22): the walk clip keeps pace with the body (no foot slide) and carries its own bob
		p.folk.walk_clip_speed = float(row.get("walk_speed", 0.0))
		p.folk.procedural_bob = p.folk.walk_clip_speed <= 0.0
		p.route = row["route"]
		p.speed = float(row["speed"])
		p.pause_range = Vector2(float(row["pause"][0]), float(row["pause"][1]))
		# Spread people across their first interest and avoid overlapping starts.
		var origin: Vector2 = PLACES[p.profile["interests"][people.size() % 3]]
		var pos: Vector2 = navigation.closest(origin + Vector2(p.rng.randf_range(-1.3, 1.3), p.rng.randf_range(-1.8, 1.8)))
		for attempt in 40:
			if _body_clear(pos, p, Vector3(100, 0, 1300)): break
			pos = navigation.closest(origin + Vector2(p.rng.randf_range(-2.2, 2.2), p.rng.randf_range(-4, 4)))
		p.folk.place(Vector3(pos.x, 0, pos.y))
		p.folk.face_yaw(p.rng.randf() * TAU)
		p.timer = p.rng.randf_range(0.5, 8.0)
		p.social_cd = p.rng.randf_range(5, 20)
		people.append(p)
	_seat_regulars()
	return people.size()

## The balcony regulars take their seats (called at the end of build(); a restore() may later put them elsewhere).
func _seat_regulars() -> void:
	var seats: Array = Ep2GoldTown.saloon_seats()
	var k: int = 0
	for i in seats.size():
		if str(seats[i]["kind"]) != "balcony" or k >= BALCONY_REGULARS.size() or Ep2GoldTown.shop_spots("Bldg_Saloon").is_empty():
			continue
		var p: Person = person(BALCONY_REGULARS[k])
		k += 1
		if p == null:
			continue
		p.shop = "Bldg_Saloon"
		p.seat = i
		p.destination = "shop:Bldg_Saloon#%d" % i
		reservations[p.destination] = p.id
		p.activity = "rest"
		p.folk.use_height = true
		p.state = "shop_buy"
		_start_drinking(p, Ep2GoldTown.shop_spots("Bldg_Saloon"))
		p.timer = 30.0
	# the table regulars take the table chairs (one aisle-side chair per table), in roster order
	var t: int = 0
	for i in seats.size():
		if str(seats[i]["kind"]) != "table" or t >= TABLE_REGULARS.size() or Ep2GoldTown.shop_spots("Bldg_Saloon").is_empty():
			continue
		var p: Person = person(TABLE_REGULARS[t])
		t += 1
		if p == null:
			continue
		p.shop = "Bldg_Saloon"
		p.seat = i
		p.destination = "shop:Bldg_Saloon#%d" % i
		reservations[p.destination] = p.id
		p.activity = "rest"
		p.folk.use_height = true
		p.state = "shop_buy"
		_start_drinking(p, Ep2GoldTown.shop_spots("Bldg_Saloon"))
		p.timer = 30.0
		p.drink_clock = float(t) * 2.7                  # their first laugh or clink lands seconds apart, not together


func set_context(mode: String) -> void:
	if mode not in ["normal", "quiet", "duel"]: mode = "normal"
	if _mode == mode: return
	_mode = mode
	if mode == "duel":
		_story_was_duel = true
		for p in people:
			_release(p)
			p.folk.stop()
			p.partner = ""
			_seek_safety(p, Vector2(0, 1425), true)
	elif _story_was_duel:
		_story_was_duel = false
		for p in people:
			if p.state in CEL_STATES:
				continue                                # the celebration after the draw keeps its own clock
			p.fear = maxf(p.fear, 3.0)
			p.timer = p.rng.randf_range(2, 5)

func notify_danger(where: Vector3, radius: float = 24.0) -> void:
	for p in people:
		if _pos(p).distance_to(Vector2(where.x, where.z)) > radius: continue
		p.threat = Vector2(where.x, where.z)
		p.fear = p.rng.randf_range(12, 20)
		p.memories["last_danger"] = elapsed
		if p.state != "shelter" and _mode != "duel": _seek_safety(p, p.threat, false)

func step(delta: float, player_world: Vector3) -> void:
	if delta <= 0.0 or not is_finite(delta): return
	# Bounded substeps prevent collision tunnelling after a browser hitch.
	var remaining: float = minf(delta, 0.5)
	while remaining > 0.00001:
		var dt: float = minf(remaining, 0.05)
		elapsed += dt
		_tick_celebration(dt)
		for p in people: _step_one(p, dt, player_world)
		remaining -= dt


# --- THE CELEBRATION (founder 2026-10-25, PROMPT_EPISODE2_CAD_TRANSITIONS_DRAW_REWRITE section 4.1: "Townspeople celebrate Lil Blunt's
# win, then dance together") -------------------------------------------------------------------------------------------------------
## Everyone out in the street gathers on a ring round `centre` - kept clear of `avoid` (the fallen stranger) - and cheers or claps (their
## own retargeted CMU Cheer / Clap clips, tools/ep2_motion/clips_celebrate.json) for `cheer_s`; then neighbours on the ring pair off,
## face each other and dance (DanceA / DanceB: the two partners of one CMU salsa take, so a pair moves together) for `dance_s`; then
## everyone goes back to their own day. Indoors (a shop, the saloon, the balcony) they stay where they are. Returns how many joined.
func celebrate(centre: Vector3, avoid: Vector3, cheer_s: float = CHEER_S, dance_s: float = DANCE_S) -> int:
	var c2 := Vector2(centre.x, centre.z)
	var joined: Array = people.filter(func(p: Person) -> bool:
		return p.external_owner=="" and p.state not in SHOP_STATES and not p.folk.use_height and _pos(p).distance_to(c2) < CEL_REACH)
	# neighbours on the ring are neighbours in the list: partners are planned now (k, k+1) and given ADJACENT ring spots, so a couple
	# dances at arm's length; the odd one out claps
	joined.sort_custom(func(a: Person, b: Person) -> bool:
		return (_pos(a) - c2).angle() < (_pos(b) - c2).angle())
	var avoid2 := Vector2(avoid.x, avoid.z)
	var n: int = joined.size()
	var mates: Dictionary = {}
	for k in range(0, n - 1, 2):
		mates[joined[k].id] = joined[k + 1].id
		mates[joined[k + 1].id] = joined[k].id
	var slots: int = maxi(1, int(ceil(float(n) / 2.0)))
	var base: float = (_pos(joined[0]) - c2).angle() if n > 0 else 0.0
	for k in n:
		var p: Person = joined[k]
		var ang: float = base + TAU * float(k >> 1) / float(slots)
		var tangent := Vector2(-sin(ang), cos(ang))
		var side: float = (-0.5 if k % 2 == 0 else 0.5) if mates.has(p.id) else 0.0
		var spot: Vector2 = navigation.closest(c2 + Vector2(cos(ang), sin(ang)) * CEL_R + tangent * side * CEL_PAIR_GAP)
		if spot.distance_to(avoid2) < CEL_AVOID:
			spot = navigation.closest(avoid2 + (spot - avoid2).normalized() * CEL_AVOID)
		_release(p)
		p.partner = ""
		p.fear = 0.0
		p.safety = spot                                    # (the ring spot; restored as a plain pause - see snapshot())
		var path: Array[Vector2] = navigation.path(_pos(p), spot)
		p.waypoints = path
		p.state = "cel_go"
		p.timer = cheer_s + dance_s + CEL_GRACE
		p.folk.hold_clip("Observe")
		if path.is_empty():
			_join_cheer(p)
	_cel = {"centre": c2, "t": 0.0, "cheer": cheer_s, "dance": dance_s, "phase": "cheer", "mates": mates}
	return n


func is_celebrating() -> bool:
	return not _cel.is_empty()


## "cheer" | "dance" | "" - where the celebration is.
func celebration_phase() -> String:
	return str(_cel.get("phase", ""))


## The partner planned for `id` in the celebration ("" = none, the odd one out).
func celebration_mate(id: String) -> String:
	return str(_cel.get("mates", {}).get(id, ""))


func _join_cheer(p: Person) -> void:
	p.folk.stop()
	p.waypoints.clear()
	p.state = "cel_cheer"
	var c2: Vector2 = _cel.get("centre", _pos(p))
	p.folk.face_point(Vector3(c2.x, 0.0, c2.y))
	# half cheer with arms up, half clap - their own clips; a cast member without them keeps the greeting wave
	var want: String = "Cheer" if int(p.id.hash()) % 2 == 0 else "Clap"
	p.folk.hold_clip(want if _has_clip(p, want) else ("Cheer" if _has_clip(p, "Cheer") else "Greet"))
	if str(_cel.get("phase", "cheer")) == "dance":
		_start_dance(p)                                    # a late arrival: dances if the partner is waiting, else claps along


## A couple starts together, on the same frame (the two partners of one CMU salsa take stay in step), facing each other: the lower id
## leads (DanceA). Nothing happens until both have reached the ring. True when the couple is dancing.
func _start_dance(p: Person) -> bool:
	var mate: Person = person(celebration_mate(p.id))
	if mate == null or mate.state not in ["cel_cheer", "cel_dance"] or p.state not in ["cel_cheer", "cel_dance"]:
		return false
	for pair in [[p, mate], [mate, p]]:
		var a: Person = pair[0]
		var b: Person = pair[1]
		if a.state == "cel_dance":
			continue
		a.state = "cel_dance"
		a.partner = b.id
		var clip: String = "DanceA" if a.id < b.id else "DanceB"
		a.folk.hold_clip(clip if _has_clip(a, clip) else ("Clap" if _has_clip(a, "Clap") else "Greet"))
		a.folk.face_point(b.folk.position)
	return true


func _step_celebration(p: Person, dt: float, player: Vector3) -> void:
	match p.state:
		"cel_go":
			_move(p, dt, player)
			if p.state == "pause":                       # boxed in on the way: cheer where they stand
				_join_cheer(p)
		"cel_cheer":
			var c2: Vector2 = _cel.get("centre", _pos(p))
			p.folk.face_point(Vector3(c2.x, 0.0, c2.y))
		"cel_dance":
			var mate: Person = person(p.partner) if p.partner != "" else null
			if mate != null:
				p.folk.face_point(mate.folk.position)
	if p.timer <= 0.0 or _cel.is_empty():
		_end_celebration_for(p)


func _end_celebration_for(p: Person) -> void:
	p.state = "pause"
	p.partner = ""
	p.waypoints.clear()
	p.timer = p.rng.randf_range(1.0, 4.0)
	p.folk.hold_clip("Observe")


func _tick_celebration(dt: float) -> void:
	if _cel.is_empty():
		return
	_cel["t"] = float(_cel["t"]) + dt
	var t: float = _cel["t"]
	if str(_cel["phase"]) == "cheer" and t >= float(_cel["cheer"]):
		_cel["phase"] = "dance"
		for p in people:
			if p.state == "cel_cheer":
				_start_dance(p)
	elif str(_cel["phase"]) == "dance" and t >= float(_cel["cheer"]) + float(_cel["dance"]):
		_cel = {}
		for p in people:
			if p.state in CEL_STATES:
				_end_celebration_for(p)

func _step_one(p: Person, dt: float, player: Vector3) -> void:
	if p.folk.dead:
		p.folk.step(dt)
		return
	# The delivery owns ordinary movement; the existing crowd brain still owns
	# fleeing/cover when the draw or gunfire interrupts that errand.
	if p.external_owner!="" and p.state not in ["flee","shelter"]:return
	p.greet_cd = maxf(0, p.greet_cd - dt)
	p.social_cd = maxf(0, p.social_cd - dt)
	p.fear = maxf(0, p.fear - dt)
	p.timer = maxf(-1, p.timer - dt)
	p.activity_time += dt
	if p.parcel_t > 0.0:
		p.parcel_t = maxf(0.0, p.parcel_t - dt)          # never below zero: a saved 0 must restore (restore() bounds it 0..PARCEL_SECONDS)
		if p.parcel_t <= 0.0: p.folk.drop_prop("Parcel")
	var before: Vector2 = _pos(p)
	if _town_cold() and p.fear <= 0.0 and p.state not in SHOP_STATES and p.state not in CEL_STATES:
		if _cold_avoid(p, dt, player):
			return
		if p.id in COLD_SPEAKERS and p.state != "greet" and p.greet_cd <= 0.0 and _pos(p).distance_to(Vector2(player.x, player.z)) < GREET_R:
			_cold_greet(p, player)
	if p.state in CEL_STATES:
		_step_celebration(p, dt, player)
		if before.distance_to(_pos(p)) < 0.000001: p.folk.step(dt)
		return
	if p.state == "flee" and p.fear <= 0 and _mode != "duel":
		p.folk.stop()
		p.state = "pause"
		p.timer = p.rng.randf_range(1, 3)
	if p.state in ["walk", "flee"]:
		_move(p, dt, player)
		if p.state == "walk" and _mode == "normal" and p.fear <= 0 and _near_player(p, player): _greet(p, player)
	elif p.state in SHOP_STATES:
		_step_shop(p, dt)
		return
	elif p.state == "shelter":
		p.folk.face_point(Vector3(p.threat.x, 0, p.threat.y))
		if _mode != "duel" and p.fear <= 0 and p.timer <= 0:
			p.state = "pause"
			p.timer = p.rng.randf_range(1, 4)
			p.folk.hold_clip("Observe")
	elif p.state == "greet":
		p.folk.face_point(player)
		if p.timer <= 0:
			p.state = "pause"
			p.timer = p.rng.randf_range(1, 3)
			p.folk.hold_clip("Observe")
	elif p.state == "social":
		var other: Person = person(p.partner)
		if other != null: p.folk.face_point(other.folk.position)
		if p.timer <= 0 or other == null or other.state != "social":
			p.partner = ""
			p.state = "pause"
			p.timer = p.rng.randf_range(2, 5)
			p.folk.hold_clip("Idle")
	else:
		if p.external_owner!="":
			p.folk.step(dt)
			return
		if _mode == "normal" and p.fear <= 0 and _near_player(p, player):
			_greet(p, player)
		elif p.timer <= 0 and _mode != "duel":
			_choose(p)
		elif _mode == "normal" and p.social_cd <= 0 and p.fear <= 0:
			_try_social(p)
	if before.distance_to(_pos(p)) < 0.000001: p.folk.step(dt)

func _pos(p: Person) -> Vector2:
	return Vector2(p.folk.position.x, p.folk.position.z)

func person(id: String) -> Person:
	for p in people:
		if p.id == id: return p
	return null

func _near_player(p: Person, player: Vector3) -> bool:
	if _town_cold():
		return false
	return p.greet_cd <= 0 and absf(player.y) < 3.0 and _pos(p).distance_to(Vector2(player.x, player.z)) < GREET_R

func _greet(p: Person, player: Vector3) -> void:
	p.folk.stop()
	p.folk.hold_clip("Greet" if float(p.profile["social"]) >= 0.5 else "Observe")
	p.folk.face_point(player)
	p.state = "greet"
	p.timer = 2.4 if float(p.profile["social"]) >= 0.5 else 1.5
	p.greet_cd = GREET_COOLDOWN + (1.0 - float(p.profile["social"])) * 20.0
	p.greets += 1
	p.memories["player_seen"] = elapsed
	greeted.emit(p.id, p.folk, p.greets)
	# The destination is retained; the next decision can resume the interrupted errand.

func _release(p: Person) -> void:
	if reservations.get(p.destination, "") == p.id: reservations.erase(p.destination)
	p.destination = ""
	if p.state not in SHOP_STATES:
		p.shop = ""                     # a shop trip abandoned on the way (blocked, danger, a new plan) is no trip

## A bounded delivery borrows an existing worker; it never duplicates a townsman.
func reserve_delivery(id: String, restoring: bool = false) -> Person:
	var p: Person=person(id)
	if p==null or p.folk.dead or p.external_owner!="":return null
	if not restoring and (_mode!="normal" or not _cel.is_empty() or p.state in SHOP_STATES or p.state in CEL_STATES or p.partner!="" or p.parcel_t>0):return null
	_release(p)
	p.folk.stop()
	p.external_owner="road_farmer"
	return p

func release_delivery(p: Person) -> void:
	if p==null or p.external_owner!="road_farmer":return
	p.external_owner=""
	if is_instance_valid(p.folk):
		p.folk.stop()
		p.folk.use_height=false
	p.state="pause"
	p.timer=3
	p.shop=""
	p.partner=""
	p.waypoints.clear()

func _choose(p: Person) -> void:
	_release(p)
	var best_score: float = -INF
	var chosen: String = "observe"
	var place: String = ""
	for activity in ACTIVITIES:
		var score: float = p.rng.randf_range(0, 0.65)
		if activity == "work": score += 0.65 if p.id in ["bald_worker", "rancher", "dressmaker", "clerk", "youth"] else 0.12
		if activity == "rest": score += float(p.profile["rest"]) * minf(1.0, p.walked_m / 18.0)
		if activity == "social": score += float(p.profile["social"]) * 0.6
		if activity == "play": score += 0.7 if p.id in PLAYERS else -3.0
		if activity in p.recent: score -= 0.7
		if activity == "social" and (_mode != "normal" or p.social_cd > 0): score -= 2.0
		if score > best_score:
			best_score = score
			chosen = activity
	var interests: Array = p.profile["interests"]
	var candidates: Array = interests.duplicate()
	if chosen == "rest": candidates = ["rest_south", "rest_north"]
	elif chosen in ["errand", "observe"]: candidates.append("notice")
	var available_interest: bool = false
	for candidate in candidates:
		if not reservations.has(candidate) and _pos(p).distance_to(navigation.closest(PLACES[candidate])) >= 2.0:
			available_interest = true
	# A popular market/notice spot can stay reserved for minutes. Take a useful
	# secondary errand instead of repeatedly "arriving" at the place already occupied.
	if not available_interest:
		for candidate in PLACES:
			if candidate not in candidates: candidates.append(candidate)
	var best_place: float = -INF
	for candidate in candidates:
		var owner: String = str(reservations.get(candidate, ""))
		if not owner.is_empty() and owner != p.id: continue
		var point: Vector2 = navigation.closest(PLACES[candidate])
		if _pos(p).distance_to(point) < 2.0: continue
		var score: float = p.rng.randf_range(0, 1) - float(p.visits.get(candidate, 0)) * .18
		if candidate in interests: score += 0.65
		if score > best_place:
			best_place = score
			place = candidate
	if chosen == "errand" and _start_shopping(p):
		return
	p.activity = chosen
	p.choices += 1
	p.activity_time = 0.0
	p.recent.append(chosen)
	if p.recent.size() > 3: p.recent.pop_front()
	if place.is_empty():
		p.state = "pause"
		p.timer = p.rng.randf_range(2, 4)
		p.folk.hold_clip("Observe")
		return
	p.destination = place
	reservations[place] = p.id
	var target: Vector2 = navigation.closest(PLACES[place])
	p.waypoints = navigation.path(_pos(p), target)
	p.state = "walk"
	p.blocked = 0.0
	if p.waypoints.is_empty(): _arrive(p)

func _arrive(p: Person) -> void:
	if p.state == "cel_go":
		_join_cheer(p)
		return
	if p.destination.begins_with("shop:"):
		_enter_shop(p)
		return
	p.folk.stop()
	p.visits[p.destination] = int(p.visits.get(p.destination, 0)) + 1
	p.state = "pause"
	p.timer = p.rng.randf_range(5, 12)
	var clip: String = "Observe"
	if p.activity == "rest":
		clip = "Rest"
		p.timer *= 1.0 + float(p.profile["rest"])
	elif p.activity == "work": clip = "Inspect"
	elif p.activity == "play" and _has_clip(p, "Play"): clip = "Play"
	p.folk.hold_clip(clip)
	if not p.destination.is_empty():
		var target: Vector2 = PLACES[p.destination]
		# Face the institution/horse, rather than staring into the last path segment.
		p.folk.face_point(Vector3(target.x + (-4.0 if target.x < 0 else 4.0), 0, target.y))

## Turn an errand into a shop visit when a walk-in shop has room. False = no shop open / free / chosen (a normal errand runs).
func _start_shopping(p: Person) -> bool:
	if _mode != "normal" or p.rng.randf() > SHOP_CHANCE:
		return false
	var open: Array = []
	for piece in Ep2GoldTown.WALKIN_SHOPS:
		if Ep2GoldTown.shop_spots(str(piece)).is_empty():
			continue
		if str(piece) != "Bldg_Saloon" and reservations.has("shop:" + str(piece)):
			continue                                    # a shop serves one customer at a time
		if p.id in PLAYERS and str(piece) in ["Bldg_C", "Bldg_Saloon"]:
			continue                                    # the children go for candy at the general store, not to the assayer or the bar
		open.append(str(piece))
	if open.is_empty():
		return false
	var piece: String = open[p.rng.randi() % open.size()]
	if "saloon" in (p.profile.get("interests", []) as Array) and open.has("Bldg_Saloon") and p.rng.randf() < 0.6:
		piece = "Bldg_Saloon"                           # the saloon's regulars go for a drink more often than for groceries
	var key: String = "shop:" + piece
	var seat: int = -1
	if piece == "Bldg_Saloon":
		seat = _free_saloon_seat(p)
		if seat < 0:
			return false
		key = "shop:Bldg_Saloon#%d" % seat
	var slot: int = _free_slot(p, piece)
	if slot < 0:
		return false
	var out3: Vector3 = _slot_point(piece, slot)
	var target: Vector2 = navigation.closest(Vector2(out3.x, out3.z))
	var path: Array[Vector2] = navigation.path(_pos(p), target)
	if path.is_empty() and _pos(p).distance_to(target) > 1.0:
		return false
	p.activity = "errand"
	p.choices += 1
	p.activity_time = 0.0
	p.recent.append("errand")
	if p.recent.size() > 3: p.recent.pop_front()
	p.destination = key
	reservations[key] = p.id
	reservations["slot:%s#%d" % [piece, slot]] = p.id
	p.shop = piece
	p.seat = seat
	p.slot = slot
	p.waypoints = path
	p.state = "walk"
	p.blocked = 0.0
	if p.waypoints.is_empty(): _arrive(p)
	return true


## A free waiting spot along `piece`'s front for `p` (nobody standing there), or -1.
func _free_slot(p: Person, piece: String) -> int:
	for k in SLOT_OFFSETS.size():
		if reservations.has("slot:%s#%d" % [piece, k]):
			continue
		var w: Vector3 = _slot_point(piece, k)
		if navigation.is_clear(Vector2(w.x, w.z)) and _body_clear(Vector2(w.x, w.z), p, Vector3(100, 0, 1300)):
			return k
	return -1


func _slot_point(piece: String, k: int) -> Vector3:
	return Ep2GoldTown.local_to_world(piece, Vector3(float(SLOT_OFFSETS[k]), 0.0, Ep2GoldTown.PORCH_DEPTH + 1.1))


## At their spot in front of the shop: queue for the door.
func _enter_shop(p: Person) -> void:
	if Ep2GoldTown.shop_spots(p.shop).is_empty():
		_leave_shop_done(p)
		return
	p.visits["shop"] = int(p.visits.get("shop", 0)) + 1
	p.folk.stop()
	p.folk.hold_clip("Observe")
	p.state = "shop_queue"


## The way in: up onto the porch, through the door, then the place's own route (the aisle to a chair / the bar) or the counter.
func _legs_in(p: Person) -> Array:
	var spots: Dictionary = Ep2GoldTown.shop_spots(p.shop)
	var pts: Array = [spots["porch"], spots["door"]]
	if p.shop == "Bldg_Saloon" and p.seat >= 0:
		pts.append_array(Ep2GoldTown.saloon_seats()[p.seat]["route"])
	else:
		pts.append(spots["counter"])
	var legs: Array = []
	for w in pts:
		legs.append(Vector3((w as Vector3).x, Ep2GoldTown.shop_floor_y(p.shop, w), (w as Vector3).z))
	return legs


func _legs_out(p: Person) -> Array:
	var legs: Array = _legs_in(p)
	legs.reverse()
	legs.pop_front()                                     # they are standing on the last point already
	var w: Vector3 = _slot_point(p.shop, maxi(p.slot, 0))
	legs.append(Vector3(w.x, 0.0, w.z))
	return legs


func _door_key(p: Person) -> String:
	return "door:" + p.shop


func _take_door(p: Person) -> bool:
	var owner: String = str(reservations.get(_door_key(p), ""))
	if owner != "" and owner != p.id:
		return false
	reservations[_door_key(p)] = p.id
	return true


func _free_door(p: Person) -> void:
	if reservations.get(_door_key(p), "") == p.id:
		reservations.erase(_door_key(p))


func _step_shop(p: Person, dt: float) -> void:
	var spots: Dictionary = Ep2GoldTown.shop_spots(p.shop)
	if spots.is_empty():
		_leave_shop_done(p)
		return
	match p.state:
		"shop_queue":
			p.folk.face_point(spots["porch"])
			if _mode == "normal" and _take_door(p):
				p.folk.use_height = true
				p.folk.walk_path(_legs_in(p), minf(p.speed, 1.0))
				p.state = "shop_in"
		"shop_in":
			if not p.folk.is_walking():
				_free_door(p)
				p.state = "shop_buy"
				if p.shop == "Bldg_Saloon":
					_start_drinking(p, spots)
				else:
					p.timer = p.rng.randf_range(4.0, 8.0)
					p.folk.face_point(spots["face"])
					p.folk.hold_clip("Inspect")     # looking over the goods on the counter (no shopkeeper model yet: see STATUS)
		"shop_buy":
			p.folk.face_point(_face_point(p, spots))
			if p.id in BALCONY_REGULARS and p.seat >= 0 and str(Ep2GoldTown.saloon_seats()[p.seat]["kind"]) == "balcony":
				p.timer = maxf(p.timer, 30.0)          # the regulars stay up there all day
			if p.id in TABLE_REGULARS and p.seat >= 0 and str(Ep2GoldTown.saloon_seats()[p.seat]["kind"]) == "table":
				p.timer = maxf(p.timer, 30.0)          # and the table regulars keep their chairs
			if p.shop == "Bldg_Saloon":
				_tick_drinker(p, dt)
			if _mode == "duel":
				p.timer = maxf(p.timer, 1.0)            # nobody walks out into the street during the draw
			if p.timer <= 0.0:
				p.state = "shop_leave_wait"
		"shop_leave_wait":
			p.folk.face_point(_face_point(p, spots))
			if _mode != "duel" and _take_door(p):
				_stop_drinking(p)
				if str(Ep2GoldTown.WALKIN_SHOPS[p.shop][0]) == "general":
					p.folk.attach_prop(_parcel(), "RightHand", Vector3(0.0, -0.08, 0.06))
					p.parcel_t = PARCEL_SECONDS
					if _has_clip(p, "Carry"): p.folk.hold_clip("Carry")
				p.folk.walk_path(_legs_out(p), minf(p.speed, 1.0))
				p.state = "shop_out"
		"shop_out":
			if not p.folk.is_walking():
				_leave_shop_done(p)
	p.folk.step(dt)


func _leave_shop_done(p: Person) -> void:
	_free_door(p)
	p.folk.use_height = false
	p.folk.place(Vector3(p.folk.position.x, 0.0, p.folk.position.z))
	if reservations.get(p.destination, "") == p.id: reservations.erase(p.destination)
	if p.slot >= 0 and reservations.get("slot:%s#%d" % [p.shop, p.slot], "") == p.id: reservations.erase("slot:%s#%d" % [p.shop, p.slot])
	p.destination = ""
	p.shop = ""
	p.seat = -1
	p.slot = -1
	p.state = "pause"
	p.timer = p.rng.randf_range(2.0, 5.0)
	p.folk.hold_clip("Observe" if p.parcel_t <= 0.0 else ("Carry" if _has_clip(p, "Carry") else "Idle"))
	if _mode == "duel":
		_seek_safety(p, Vector2(0.0, p.folk.position.z), true)


## A free place in the saloon for a visitor: a table (aisle-side chair) or the bar. Balcony places belong to the regulars.
func _free_saloon_seat(p: Person) -> int:
	var seats: Array = Ep2GoldTown.saloon_seats()
	var free: Array = []
	for i in seats.size():
		if str(seats[i]["kind"]) != "balcony" and not reservations.has("shop:Bldg_Saloon#%d" % i):
			free.append(i)
	return int(free[p.rng.randi() % free.size()]) if not free.is_empty() else -1


func _face_point(p: Person, spots: Dictionary) -> Vector3:
	if p.shop == "Bldg_Saloon" and p.seat >= 0:
		return Ep2GoldTown.saloon_seats()[p.seat]["face"]
	return spots["face"]


## Sit down (or lean at the bar) with a whiskey: the drink clip is built from this person's own rig the first time it is needed.
func _start_drinking(p: Person, spots: Dictionary) -> void:
	var seated: bool = p.seat >= 0 and str(Ep2GoldTown.saloon_seats()[p.seat]["kind"]) == "table"   # the bar and the balcony rail: standing
	if p.seat >= 0:                                     # onto the chair / the place at the bar / the balcony rail, at its own height
		var seat: Dictionary = Ep2GoldTown.saloon_seats()[p.seat]
		var pos: Vector3 = seat["pos"]
		p.folk.place(Vector3(pos.x, float(seat["y"]), pos.z))
	p.folk.face_point(_face_point(p, spots))
	p.folk.rotation.y = p.folk.facing                   # sat (or set) down facing the table / bar / street, no slow swivel in place
	p.timer = p.rng.randf_range(35.0, 75.0)
	var clip: String = "SitDrink" if seated else "StandDrink"
	if _ensure_drink_clip(p, seated):
		p.folk.hold_clip(clip)
	else:
		p.folk.hold_clip("Rest" if seated else "Idle")
	if ResourceLoader.exists(GLASS):
		# attach_prop resets the held node's scale to undo the model's own, so the tumbler (a unit-height GLB) is scaled INSIDE a holder
		var holder := Node3D.new()
		holder.name = "Glass"
		var g: Node3D = (load(GLASS) as PackedScene).instantiate() as Node3D
		g.scale = Vector3.ONE * 0.1                     # a 10 cm whiskey tumbler
		g.position = Vector3(0.0, -0.03, 0.0)
		holder.add_child(g)
		p.folk.attach_prop(holder, "RightHand", Vector3(0.0, 0.07, 0.035))


## Up from the chair to the step behind it, glass back on the table.
func _stop_drinking(p: Person) -> void:
	p.laugh_t = 0.0
	p.drink_clock = 0.0
	p.folk.drop_prop("Glass")
	if p.shop == "Bldg_Saloon" and p.seat >= 0 and str(Ep2GoldTown.saloon_seats()[p.seat]["kind"]) == "table":
		var back: Vector3 = Ep2GoldTown.saloon_seats()[p.seat]["approach"]
		p.folk.place(Vector3(back.x, 0.06, back.z))


## "f" for the roster's townswomen and townsgirls, "m" for everyone else (the bump grunts and street laughs pick a voice by it).
static func sex_of(id: String) -> String:
	for row in ROSTER:
		if str(row["id"]) == id:
			var file: String = str(row["file"])
			return "f" if file.contains("townswoman") or file.contains("townsgirl") else "m"
	return "m"


## "SitLaugh" / "StandDrink" ...: the drinker's own clip of that kind (seated at a table, else standing at the bar or the balcony rail).
func _drink_name(p: Person, kind: String) -> String:
	var seated: bool = p.seat >= 0 and str(Ep2GoldTown.saloon_seats()[p.seat]["kind"]) == "table"
	return ("Sit" if seated else "Stand") + kind


## A drinker's small life between sips: every 9-17 s (their own period) a laugh (their laugh clip, then back to the sip) or a clinked
## glass, each also queued as a sound event for Ep2TownSoundscape. Ambient only: nothing here is saved or changes a decision.
func _tick_drinker(p: Person, dt: float) -> void:
	if p.laugh_t > 0.0:
		p.laugh_t -= dt
		if p.laugh_t <= 0.0:
			p.folk.hold_clip(_drink_name(p, "Drink"))
	p.drink_clock += dt
	var period: float = 9.0 + float(p.drink_seed % 800) / 100.0
	if p.drink_clock < period or _mode == "duel":
		return
	p.drink_clock -= period
	p.drink_beats += 1
	var head: Vector3 = p.folk.position + Vector3(0.0, 1.2, 0.0)
	if p.drink_events.size() >= 8:
		p.drink_events.pop_front()                      # nobody is listening (a test, a quiet town): never grows
	if (p.drink_seed + p.drink_beats) % 3 == 0:
		p.drink_events.append({"kind": "clink", "at": head})
		return
	var laugh: String = _drink_name(p, "Laugh")
	var player: AnimationPlayer = p.folk.anim_player()
	if player != null and player.has_animation(laugh) and p.laugh_t <= 0.0:
		p.folk.hold_clip(laugh)
		p.laugh_t = player.get_animation(laugh).length
	p.drink_events.append({"kind": "laugh", "at": head, "female": sex_of(p.id) == "f", "variant": (p.drink_seed + p.drink_beats) % 3})


## The clip a snapshot records: a drinker's laugh / idle variant saves as their sip (restore() replays the sip).
func _snapshot_clip(p: Person) -> String:
	return str(DRINK_VARIANTS.get(p.folk._base_clip, p.folk._base_clip))


func _ensure_drink_clip(p: Person, seated: bool) -> bool:
	var player: AnimationPlayer = p.folk.anim_player()
	if player == null or p.folk.model == null:
		return false
	var name: String = "SitDrink" if seated else "StandDrink"
	if player.has_animation(name):
		return true
	var skels: Array = p.folk.model.find_children("*", "Skeleton3D", true, false)
	if skels.is_empty():
		return false
	var skel: Skeleton3D = skels[0]
	var rel: Transform3D = p.folk.global_transform.affine_inverse() * skel.global_transform if p.folk.is_inside_tree() \
		else _relative(p.folk, skel)
	var b: Basis = rel.basis
	var inv: Basis = b.inverse()
	# their own sip: a seeded 5.0-8.5 s loop (plus idle / laugh / smoke clips), so two drinkers never share one rhythm
	return Ep2DrinkPose.install_variant(player, skel, (inv * Vector3(0, 0, 1)).normalized(), (inv * Vector3.UP).normalized(), b.get_scale().y,
		seated, p.drink_seed)


## A node's transform relative to an ancestor without the scene tree (tests build people off-tree).
static func _relative(ancestor: Node3D, n: Node3D) -> Transform3D:
	var t := Transform3D()
	var c: Node = n
	while c != null and c != ancestor:
		if c is Node3D:
			t = (c as Node3D).transform * t
		c = c.get_parent()
	return t


## What he bought at the general store: a paper parcel tied with string.
func _parcel() -> Node3D:
	var root := Node3D.new()
	root.name = "Parcel"
	var box := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.26, 0.16, 0.2)
	box.mesh = bm
	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color(0.72, 0.58, 0.40)
	paper.roughness = 0.95
	box.material_override = paper
	root.add_child(box)
	var string := StandardMaterial3D.new()
	string.albedo_color = Color(0.85, 0.82, 0.74)
	for axis in [0, 1]:
		var band := MeshInstance3D.new()
		var b2 := BoxMesh.new()
		b2.size = Vector3(0.012, 0.165, 0.205) if axis == 0 else Vector3(0.265, 0.165, 0.012)
		band.mesh = b2
		band.material_override = string
		root.add_child(band)
	return root


## True when this person's model carries an authored clip `name` (importer prefixes tolerated, as Ep2TownFolk does).
func _has_clip(p: Person, name: String) -> bool:
	var anim: AnimationPlayer = p.folk.anim_player()
	if anim == null: return false
	var want: String = name.to_lower()
	for clip in anim.get_animation_list():
		var key: String = String(clip).to_lower()
		if key == want or key.ends_with("/" + want) or key.ends_with("|" + want): return true
	return false

func _town_cold() -> bool:
	return GameManager.town_standing == "cold"


## After a shooting, people give Lil Blunt a wide berth instead of walking up
## with their usual greeting. They still carry on with their own errands.
func _cold_avoid(p: Person, dt: float, player: Vector3) -> bool:
	var here: Vector2 = _pos(p)
	var away: Vector2 = here - Vector2(player.x, player.z)
	if away.length() >= COLD_CLEARANCE:
		return false
	if away.length() < 0.01:
		away = Vector2.RIGHT
	var candidate: Vector2 = here + away.normalized() * maxf(p.speed * 1.25 * dt, 0.015)
	if _body_clear(candidate, p, player, false) and navigation.segment_clear(here, candidate):
		p.folk.walk_to(Vector3(candidate.x, 0.0, candidate.y), p.speed * 1.25)
		p.folk.step(dt)
		p.folk.stop()
	return true


func _cold_greet(p: Person, player: Vector3) -> void:
	p.folk.stop()
	p.folk.hold_clip("Observe")
	p.folk.face_point(player)
	p.state = "greet"
	p.timer = 1.6
	p.greet_cd = GREET_COOLDOWN
	p.memories["player_seen"] = elapsed
	cold_greeted.emit(p.id, p.folk)


func _body_clear(point: Vector2, owner: Person, player: Vector3, respect_cold: bool = true) -> bool:
	if not navigation.is_clear(point): return false
	var clearance: float = maxf(player_clearance, COLD_CLEARANCE) if respect_cold and _town_cold() else player_clearance
	if absf(player.y) < 2.2 and point.distance_to(Vector2(player.x, player.z)) < clearance: return false
	for other in people:
		if other == owner: continue
		if point.distance_to(_pos(other)) < BODY_R * 2.0: return false
	return true

func _move(p: Person, dt: float, player: Vector3) -> void:
	var here: Vector2 = _pos(p)
	# Consume reached nodes in the same tick so the walk clip never flickers to idle at corners.
	while not p.waypoints.is_empty() and here.distance_to(p.waypoints[0]) < 0.16:
		p.waypoints.pop_front()
	if p.waypoints.is_empty():
		if p.state == "flee":
			p.state = "shelter"
			p.timer = p.rng.randf_range(3, 6)
			p.folk.hold_clip("Alert")
		else: _arrive(p)
		return
	var target: Vector2 = p.waypoints[0]
	var direction: Vector2 = (target - here).normalized()
	var speed: float = p.speed * (1.45 if p.state == "flee" else (CEL_RUSH if p.state == "cel_go" else 1.0))
	var distance: float = minf(speed * dt, here.distance_to(target))
	var candidate: Vector2 = here + direction * distance
	var moved: bool = _body_clear(candidate, p, player) and navigation.segment_clear(here, candidate)
	if not moved:
		# Stable individual passing side, then alternate: no accumulated force can push through a body or wall.
		var side: float = 1.0 if int(p.id.hash()) % 2 == 0 else -1.0
		for sign_value in [side, -side]:
			var tangent: Vector2 = Vector2(-direction.y, direction.x) * float(sign_value)
			candidate = here + (direction * 0.25 + tangent).normalized() * distance
			if _body_clear(candidate, p, player) and navigation.segment_clear(here, candidate):
				moved = true
				break
	if moved:
		p.folk.walk_to(Vector3(candidate.x, 0, candidate.y), speed)
		p.folk.step(dt)
		p.folk.stop()
		p.walked_m += here.distance_to(_pos(p))
		var progress: float = here.distance_to(target) - _pos(p).distance_to(target)
		p.blocked = p.blocked + dt if progress < distance * 0.15 else maxf(0, p.blocked - dt)
	else:
		p.folk.stop()
		p.blocked += dt
	if p.blocked > 2.5:
		p.recoveries += 1
		p.blocked = 0.0
		if p.state == "flee": _seek_safety(p, p.threat, _mode == "duel")
		else:
			_release(p)
			p.state = "pause"
			p.timer = p.rng.randf_range(0.8, 2.0)

func _try_social(p: Person) -> void:
	p.social_cd = p.rng.randf_range(8, 16)
	if p.rng.randf() > float(p.profile["social"]): return
	for other in people:
		if other == p or other.external_owner != "" or other.state != "pause" or other.fear > 0 or other.social_cd > 0: continue
		var distance: float = _pos(p).distance_to(_pos(other))
		if distance < 0.8 or distance > 2.7: continue
		if elapsed - float(p.memories.get(other.id, -100.0)) < 60.0: continue
		if not navigation.segment_clear(_pos(p), _pos(other)): continue
		var duration: float = p.rng.randf_range(3.5, 6.5)
		for pair in [[p, other], [other, p]]:
			var a: Person = pair[0]
			var b: Person = pair[1]
			a.state = "social"
			a.partner = b.id
			a.timer = duration
			a.social_cd = 35.0 + (1.0 - float(a.profile["social"])) * 35.0
			a.memories[b.id] = elapsed
			a.folk.stop()
			a.folk.hold_clip("Talk")
		return

func _seek_safety(p: Person, danger: Vector2, duel: bool) -> void:
	if p.state == "shop_queue":
		_leave_shop_done(p)                         # waiting in the street for the door: not indoors yet, take cover like anyone
		if p.state in ["flee", "shelter"]: return
	elif p.state in SHOP_STATES:
		return                                      # indoors (or on the way in/out): the shop is the safest place in town
	_release(p)
	p.partner = ""
	p.threat = danger
	var options: Array = []
	var shelters: Array = SHELTERS.duplicate()
	if duel:
		# Clear sideways to the street verge; do not funnel thirteen people to two distant end points.
		for z in [-2.4, -1.2, 0.0, 1.2, 2.4]:
			for x in [-4.2, 4.2]: shelters.append(Vector2(x, _pos(p).y + z))
	for shelter in shelters:
		var safe: Vector2 = navigation.closest(shelter)
		var score: float = -_pos(p).distance_to(safe) if duel else safe.distance_to(danger) - _pos(p).distance_to(safe) * 0.28 + p.rng.randf_range(0, 2)
		if duel and absf(safe.x) < 3.8 and safe.y > 1412 and safe.y < 1442: continue
		if not _body_clear(safe, p, Vector3(100, 0, 1300)): continue
		var reserved: bool = false
		for other in people:
			if other != p and other.state in ["flee", "shelter"] and other.safety.distance_to(safe) < 1.0: reserved = true
		if reserved: continue
		options.append([score, safe])
	options.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	for option in options:
		var safe: Vector2 = option[1]
		var path: Array[Vector2] = navigation.path(_pos(p), safe)
		if path.is_empty(): continue
		p.safety = safe
		p.waypoints = path
		p.state = "flee"
		p.folk.hold_clip("Alert")
		return
	p.state = "shelter"
	p.safety = _pos(p)
	p.timer = 2.0
	p.folk.stop()
	p.folk.hold_clip("Alert")

## A vehicle (the quad rolling into town) is coming along `heading`: anyone standing in its path within `reach`
## metres steps sideways to the verge, then carries on with their own day once it has passed (short fear, no shelter).
func make_way(from: Vector3, heading: Vector2, reach: float = 14.0, half_width: float = 2.0) -> void:
	if heading.length_squared() < 0.0001 or _mode == "duel": return
	var fwd: Vector2 = heading.normalized()
	var side: Vector2 = Vector2(-fwd.y, fwd.x)
	var origin := Vector2(from.x, from.z)
	for p in people:
		if p.state in ["flee", "shelter"]: continue
		var rel: Vector2 = _pos(p) - origin
		var ahead: float = rel.dot(fwd)
		var lateral: float = rel.dot(side)
		if ahead < -1.0 or ahead > reach or absf(lateral) > half_width: continue
		var away: float = 1.0 if lateral >= 0.0 else -1.0
		var target: Vector2 = navigation.closest(_pos(p) + side * away * (half_width + 1.4 - absf(lateral)) + fwd * 0.6)
		var path: Array[Vector2] = navigation.path(_pos(p), target)
		if path.is_empty(): continue
		_release(p)
		p.partner = ""
		p.threat = origin
		p.safety = target
		p.fear = maxf(p.fear, 2.5)
		p.waypoints = path
		p.state = "flee"
		p.folk.hold_clip("Observe")

func duel_lane_clear() -> bool:
	for p in people:
		var q: Vector2 = _pos(p)
		if absf(q.x) < 3.5 and q.y > 1413 and q.y < 1441: return false
	return true

func snapshot() -> Dictionary:
	var rows: Array = []
	for p in people:
		var path: Array = []
		for point in p.waypoints: path.append([point.x, point.y])
		# a shopper is saved where they are (in the shop, on the porch) with the legs still to walk, and restored exactly there
		var legs: Array = []
		if p.state in SHOP_STATES:
			if p.folk.is_walking(): legs.append([p.folk._goal.x, p.folk._goal.y, p.folk._goal.z])
			for g in p.folk._path: legs.append([(g as Vector3).x, (g as Vector3).y, (g as Vector3).z])
		# the celebration after the draw is a moment, not a routine: it saves as a plain pause where they stand (restore() knows that)
		if p.state in CEL_STATES:
			path = []
		rows.append({"id": p.id, "position": [_pos(p).x, _pos(p).y], "activity": p.activity, "destination": p.destination,
			"shop": p.shop, "seat": p.seat, "slot": p.slot, "height": p.folk.position.y if p.state in SHOP_STATES else 0.0, "shop_legs": legs, "parcel_t": p.parcel_t,
			"recent": p.recent.duplicate(), "visits": p.visits.duplicate(), "memories": p.memories.duplicate(),
			"greet_cd": p.greet_cd, "greets": p.greets, "walked_m": p.walked_m, "choices": p.choices,
			"rng_state": str(p.rng.state), "fear": p.fear, "social_cd": p.social_cd,
			"state": "pause" if p.state in CEL_STATES else p.state, "timer": clampf(p.timer, -1.0, 4.0) if p.state in CEL_STATES else p.timer,
			"waypoints": path, "partner": "" if p.state in CEL_STATES else p.partner,
			"threat": [p.threat.x, p.threat.y], "safety": [p.safety.x, p.safety.y],
			"blocked": p.blocked, "recoveries": p.recoveries, "activity_time": p.activity_time,
			"clip": "Idle" if p.state in CEL_STATES else _snapshot_clip(p)})
	return {"version": 1, "elapsed": elapsed, "people": rows, "mode": _mode}

func _number(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= low and float(value) <= high

func _point(value: Variant) -> bool:
	return value is Array and value.size() == 2 and _number(value[0], -10000, 10000) and _number(value[1], -10000, 10000)

func _vector(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))

## Put the town back exactly as `data` (a snapshot()) left it; false - and nothing touched - when anything in it is invalid.
## `replan_paths` is the ride-in hand-over (founder 2026-10-22: the people live in the town before the drop-off): that crowd walked on
## the ride's lighter collision, so a planned path can clip a prop this town has. Such a walker keeps everything - place, plan,
## destination, random stream - and only their remaining path is planned again here, to the same last waypoint. A save loaded from
## disk never replans: a path through a wall there is a corrupt save and is rejected.
func restore(data: Dictionary, replan_paths: bool = false) -> bool:
	if data.get("version") != 1 or not data.get("people") is Array: return false
	var rows: Array = data["people"]
	if rows.size() != people.size() or not _number(data.get("elapsed"), 0, 10000000): return false
	if data.get("mode") not in ["normal", "quiet", "duel"]: return false
	# Validate everything before touching actors, random streams or reservations.
	var replan: Dictionary = {}                     # id -> the last waypoint to plan to again (replan_paths only)
	var seen: Dictionary = {}
	var destinations: Dictionary = {}
	var positions: Array[Vector2] = []
	var heights: Array[float] = []
	for row in rows:
		if not row is Dictionary or not row.get("id") is String: return false
		var id: String = row["id"]
		if person(id) == null or seen.has(id): return false
		seen[id] = row
		if not _point(row.get("position")): return false
		var point: Vector2 = _vector(row["position"])
		var shop: Variant = row.get("shop", "")
		if not shop is String or (shop != "" and Ep2GoldTown.shop_spots(shop).is_empty()): return false
		var shopping: bool = row.get("state") in SHOP_STATES
		if shopping and shop == "": return false
		if not shopping and shop != "" and str(row.get("destination", "")).get_slice("#", 0) != "shop:" + str(shop): return false   # on the way there
		if shopping:                                  # indoors / on its porch: must be within that shop's own footprint
			var l: Vector3 = Ep2GoldTown.building_xform(Ep2GoldTown.entry(shop)).affine_inverse() * Vector3(point.x, 0, point.y)
			var fp: Array = Ep2GoldTown.FOOTPRINT[shop]
			if absf(l.x) > float(fp[0]) * 0.5 or l.z < -float(fp[1]) or l.z > Ep2GoldTown.PORCH_DEPTH + 1.5: return false
			if not _number(row.get("height", 0.0), 0, Ep2GoldTown.BALCONY_Y + 0.1 if shop == "Bldg_Saloon" else 0.5): return false
			if not row.get("shop_legs") is Array or row["shop_legs"].size() > 3: return false
			for leg in row["shop_legs"]:
				if not leg is Array or leg.size() != 3: return false
				for c in leg:
					if not (c is int or c is float) or not is_finite(float(c)): return false
		elif not navigation.is_standing_clear(point): return false
		if not _number(row.get("parcel_t", 0.0), 0, PARCEL_SECONDS): return false
		var h: float = float(row.get("height", 0.0)) if shopping else 0.0
		for k in positions.size():
			if absf(heights[k] - h) < 1.0 and positions[k].distance_to(point) < 0.60: return false   # the balcony is above the porch
		positions.append(point)
		heights.append(h)
		if row.get("activity") not in ACTIVITIES: return false
		if row.get("state") not in ["pause", "walk", "flee", "shelter", "greet", "social"] + SHOP_STATES: return false
		if row.get("clip") not in ["Idle", "Observe", "Rest", "Talk", "Inspect", "Alert", "Greet", "Play", "Carry", "SitDrink", "StandDrink"]: return false
		var destination: Variant = row.get("destination")
		if not destination is String: return false
		if destination != "" and not PLACES.has(destination) \
				and not (destination.begins_with("shop:") and Ep2GoldTown.WALKIN_SHOPS.has(destination.trim_prefix("shop:").get_slice("#", 0))): return false
		var seat_v: Variant = row.get("seat", -1)
		if not (seat_v is int or seat_v is float) or int(seat_v) < -1 or int(seat_v) >= Ep2GoldTown.saloon_seats().size(): return false
		var slot_v: Variant = row.get("slot", -1)
		if not (slot_v is int or slot_v is float) or int(slot_v) < -1 or int(slot_v) >= SLOT_OFFSETS.size(): return false
		if destination != "":
			if destinations.has(destination): return false
			destinations[destination] = id
		if not row.get("partner") is String or (row["partner"] != "" and person(row["partner"]) == null): return false
		if not _point(row.get("threat")) or not _point(row.get("safety")): return false
		if not row.get("recent") is Array or row["recent"].size() > 3: return false
		for activity in row["recent"]:
			if activity not in ACTIVITIES: return false
		for key in ["visits", "memories"]:
			if not row.get(key) is Dictionary or row[key].size() > 32: return false
			for entry in row[key]:
				if not entry is String: return false
				if key == "visits" and not PLACES.has(entry): return false
				if key == "memories" and entry not in ["player_seen", "last_danger"] and person(entry) == null: return false
				if not _number(row[key][entry], 0, 10000000): return false
				if key == "memories" and float(row[key][entry]) > float(data["elapsed"]): return false
		for key in ["greet_cd", "social_cd", "fear", "timer", "blocked", "activity_time", "walked_m", "greets", "choices", "recoveries"]:
			if not _number(row.get(key), -1 if key == "timer" else 0, 10000000): return false
		for key in ["greet_cd", "social_cd", "fear", "timer", "blocked"]:
			if float(row[key]) > 120: return false
		var random_state: Variant = row.get("rng_state")
		if not random_state is String or random_state.length() > 20 or not random_state.is_valid_int(): return false
		if str(int(random_state)) != random_state: return false
		if not row.get("waypoints") is Array or row["waypoints"].size() > 128: return false
		var previous: Vector2 = point
		for waypoint in row["waypoints"]:
			if not _point(waypoint): return false
			var next: Vector2 = _vector(waypoint)
			if not navigation.segment_clear(previous, next):
				var goal: Vector2 = _vector(row["waypoints"][row["waypoints"].size() - 1])
				# the hand-over only: an end this town can stand on, reached by a path planned here; anything else is invalid
				if not replan_paths or not navigation.is_standing_clear(goal) or navigation.path(point, goal).is_empty(): return false
				replan[id] = goal
				break
			previous = next
	for row in rows:
		if row["state"] == "social":
			var partner: Dictionary = seen.get(row["partner"], {})
			if partner.get("state") != "social" or partner.get("partner") != row["id"]: return false
	reservations = destinations
	for row in rows:                                   # the visit's waiting spot and, for whoever is walking it, the door
		var shop_r: String = str(row.get("shop", ""))
		if shop_r == "": continue
		if int(row.get("slot", -1)) >= 0: reservations["slot:%s#%d" % [shop_r, int(row["slot"])]] = row["id"]
		if row.get("state") in ["shop_in", "shop_out"]: reservations["door:" + shop_r] = row["id"]
	elapsed = float(data["elapsed"])
	_mode = data["mode"]
	_story_was_duel = _mode == "duel"
	for row in rows:
		var p: Person = person(row["id"])
		var point: Vector2 = _vector(row["position"])
		p.folk.place(Vector3(point.x, 0, point.y))
		p.activity = row["activity"]
		p.recent.assign(row["recent"])
		p.visits = row["visits"].duplicate()
		p.memories = row["memories"].duplicate()
		p.greet_cd = float(row["greet_cd"])
		p.social_cd = float(row["social_cd"])
		p.greets = int(row["greets"])
		p.choices = int(row["choices"])
		p.walked_m = float(row["walked_m"])
		p.rng.state = int(row["rng_state"])
		p.fear = float(row["fear"])
		p.state = row["state"]
		p.timer = float(row["timer"])
		p.destination = row["destination"]
		p.partner = row["partner"]
		p.threat = _vector(row["threat"])
		p.safety = _vector(row["safety"])
		p.blocked = float(row["blocked"])
		p.recoveries = int(row["recoveries"])
		p.activity_time = float(row["activity_time"])
		p.waypoints.clear()
		if replan.has(p.id):
			p.waypoints.assign(navigation.path(point, replan[p.id]))
		else:
			for waypoint in row["waypoints"]: p.waypoints.append(_vector(waypoint))
		p.folk.hold_clip(row["clip"])
		# the shop visit: back in the shop at the saved height, the same legs still to walk, the parcel in hand if bought
		p.shop = str(row.get("shop", ""))
		p.folk.use_height = p.state in SHOP_STATES
		if p.folk.use_height:
			p.folk.place(Vector3(point.x, float(row.get("height", 0.0)), point.y))
			var legs: Array = []
			for leg in row.get("shop_legs", []): legs.append(Vector3(float(leg[0]), float(leg[1]), float(leg[2])))
			if not legs.is_empty(): p.folk.walk_path(legs, minf(p.speed, 1.0))
		p.seat = int(row.get("seat", -1))
		p.slot = int(row.get("slot", -1))
		p.folk.drop_prop("Glass")
		if p.state == "shop_buy" and p.shop == "Bldg_Saloon":
			var keep_timer: float = p.timer
			var keep_rng: int = p.rng.state
			_start_drinking(p, Ep2GoldTown.shop_spots(p.shop))
			p.folk.place(Vector3(point.x, float(row.get("height", 0.0)), point.y))
			p.timer = keep_timer
			p.rng.state = keep_rng
		p.folk.drop_prop("Parcel")
		p.parcel_t = float(row.get("parcel_t", 0.0))
		if p.parcel_t > 0.0: p.folk.attach_prop(_parcel(), "RightHand", Vector3(0.0, -0.08, 0.06))
	return true
