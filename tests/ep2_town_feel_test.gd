extends Node
## Founder 2026-10-27 town-feel gate: forward travel, committed journeys, a populated and un-synchronised saloon,
## contact reactions and the recorded steam train. Uses the real chamber, collision and imported cast.
const TOWN_BUMPS = preload("res://src/episode2/actors/ep2_town_bumps.gd")
const DT := 0.05
## The walking checks run at the browser's real 60 fps: the founder's "walking backwards" only shows at small frame steps (the crowd
## moves a walker ~1.7 cm a frame there, under the old 2 cm facing floor); at 0.05 s steps it never appears.
const WALK_DT := 1.0 / 60.0
const WALK_SECONDS := 90.0
const SIM_SECONDS := 300.0
var failures: int = 0


func check(label: String, ok: bool, detail: Variant = "") -> void:
	print("[PASS] " if ok else "[FAIL] ", label, "" if ok else " " + str(detail))
	if not ok:
		failures += 1


func _ready() -> void:
	var chamber: GoldTownChamber = load("res://src/episode2/chamber/gold_town.tscn").instantiate()
	add_child(chamber)
	chamber.setup()
	chamber.set_physics_process(false)
	var people: Ep2TownPeople = chamber.get_people()
	if people == null or people.people.size() < 2:
		check("real town chamber and cast build", false)
		print("EP2_TOWN_FEEL: 1 FAILURE(S)")
		get_tree().quit(1)
		return
	chamber._player_pos = Vector3(80.0, 0.0, 1300.0) # no accidental proximity greetings during the ambient measurement
	var previous: Dictionary = {}
	var window_start: Dictionary = {}
	var window_heading: Dictionary = {}
	var window_plan: Dictionary = {}
	var window_valid: Dictionary = {}
	var reversals: Dictionary = {}
	for p in people.people:
		previous[p.id] = p.folk.position
		window_start[p.id] = p.folk.position
		window_valid[p.id] = false
		reversals[p.id] = 0
	var moving_samples: int = 0
	var within_35: int = 0
	var over_100: int = 0
	var max_angle: float = 0.0
	var run_back: Dictionary = {}
	var longest_back: int = 0
	var next_minute: int = 1
	var occupancy_ok: bool = true
	var seconds: float = 0.0
	var frame: int = -1
	while seconds < SIM_SECONDS - 0.0001:
		frame += 1
		var dt: float = WALK_DT if seconds < WALK_SECONDS else DT
		for p in people.people:
			previous[p.id] = p.folk.position
		chamber.step(dt)
		seconds += dt
		for p in people.people:
			if p.state not in ["walk", "flee", "cel_go", "shop_in", "shop_out"]:
				continue                         # sitting down/standing up is a placement, not a walking sample
			var displacement: Vector3 = p.folk.position - (previous[p.id] as Vector3)
			var flat := Vector2(displacement.x, displacement.z)
			var speed: float = flat.length() / dt
			if speed > 0.3 and dt == WALK_DT:
				var travel: float = atan2(displacement.x, displacement.z)
				var angle: float = absf(rad_to_deg(wrapf(travel - p.folk.rotation.y, -PI, PI)))
				moving_samples += 1
				if angle <= 35.0:
					within_35 += 1
				if angle > 100.0:
					over_100 += 1
					run_back[p.id] = int(run_back.get(p.id, 0)) + 1
					longest_back = maxi(longest_back, int(run_back[p.id]))
				else:
					run_back[p.id] = 0
				max_angle = maxf(max_angle, angle)
		if seconds >= WALK_SECONDS and (frame + 1) % 20 == 0:
			for p in people.people:
				var before: Vector3 = window_start[p.id]
				var d := Vector2(p.folk.position.x - before.x, p.folk.position.z - before.z)
				var quiet_plan: bool = p.fear <= 0.0 and p.state not in ["greet", "flee", "shelter"] and p.blocked < 0.1 and not people.is_celebrating()
				if d.length() >= 0.25 and quiet_plan:
					var heading: float = atan2(d.x, d.y)
					if bool(window_valid[p.id]) and str(window_plan[p.id]) == p.destination and not p.destination.is_empty() \
							and absf(rad_to_deg(wrapf(heading - float(window_heading[p.id]), -PI, PI))) > 150.0:
						reversals[p.id] = int(reversals[p.id]) + 1
					window_heading[p.id] = heading
					window_plan[p.id] = p.destination
					window_valid[p.id] = true
				else:
					window_valid[p.id] = false
				window_start[p.id] = p.folk.position
		if next_minute <= 5 and seconds >= float(next_minute * 60) - dt * 0.5:
			var seated: int = _table_seated(people)
			print("EP2_TOWN_FEEL saloon minute ", next_minute, ": ", seated, " seated at tables")
			occupancy_ok = occupancy_ok and seated >= 3
			next_minute += 1
	var good_percent: float = 100.0 * float(within_35) / float(maxi(1, moving_samples))
	print("EP2_TOWN_FEEL walk: moving=", moving_samples, " within35=", within_35, " (", good_percent, "%) over100=", over_100, " max=", max_angle)
	var total_reversals: int = 0
	for p in people.people:
		total_reversals += int(reversals[p.id])
		print("EP2_TOWN_FEEL reversals ", p.id, ": ", reversals[p.id])
	print("EP2_TOWN_FEEL reversals total=", total_reversals, " per-person/5min=", float(total_reversals) / float(people.people.size()))
	# a pivot into a reversed leg lasts ~3 frames (the body swings round at 14/s); walking backwards is a run of them
	check("nobody walks backwards: no run of more than 6 frames (0.1 s) with the body > 100 deg off the travel", longest_back <= 6, longest_back)
	check("fewer than 0.5% of 60 fps walking samples are mid-pivot (> 100 deg)", float(over_100) <= 0.005 * float(maxi(1, moving_samples)), [over_100, moving_samples])
	check("at least 98% of moving samples face within 35 deg of travel", moving_samples > 0 and good_percent >= 98.0, good_percent)
	check("no unexplained mid-leg reversals (<=1/person/5min average)", total_reversals <= people.people.size(), total_reversals)
	check("three saloon-table drinkers at minutes 1, 3 and 5", occupancy_ok)
	# the saloon's drinkers each have their own sip (Ep2DrinkPose.install_variant): two table regulars and the two balcony regulars
	var lengths: Array = []
	for id in [Ep2TownPeople.TABLE_REGULARS[0], Ep2TownPeople.TABLE_REGULARS[1], Ep2TownPeople.BALCONY_REGULARS[0], Ep2TownPeople.BALCONY_REGULARS[1]]:
		lengths.append(_sip_length(people.person(id)))
	print("EP2_TOWN_FEEL sip lengths (table, table, balcony, balcony): ", lengths)
	check("two table drinkers are not phase-locked (their own sip lengths differ by > 0.25 s)", float(lengths[0]) > 0.0 and float(lengths[1]) > 0.0
		and absf(float(lengths[0]) - float(lengths[1])) > 0.25, lengths)
	check("the two balcony drinkers are not phase-locked either", float(lengths[2]) > 0.0 and float(lengths[3]) > 0.0
		and absf(float(lengths[2]) - float(lengths[3])) > 0.25, lengths)
	var laughs: int = 0
	for p in people.people:
		laughs += p.drink_beats
	check("the drinkers laugh or clink now and then (ambient beats over five minutes)", laughs >= 10, laughs)
	_test_bumps(chamber)
	_test_train(chamber)
	chamber.queue_free()
	print("EP2_TOWN_FEEL: ALL PASS" if failures == 0 else "EP2_TOWN_FEEL: %d FAILURE(S)" % failures)
	get_tree().quit(failures)


## The length of this person's sip clip (seated or standing), 0 when it was not built.
func _sip_length(p: Ep2TownPeople.Person) -> float:
	if p == null or p.folk == null or p.folk.anim_player() == null:
		return 0.0
	var player: AnimationPlayer = p.folk.anim_player()
	for name in ["SitDrink", "StandDrink"]:
		if player.has_animation(name):
			return player.get_animation(name).length
	return 0.0


func _table_seated(people: Ep2TownPeople) -> int:
	var count: int = 0
	var seats: Array = Ep2GoldTown.saloon_seats()
	for p in people.people:
		if p.state == "shop_buy" and p.shop == "Bldg_Saloon" and p.seat >= 0 and str(seats[p.seat]["kind"]) == "table":
			count += 1
	return count


func _test_bumps(chamber: GoldTownChamber) -> void:
	var bumps: TOWN_BUMPS = chamber._bumps
	var people: Ep2TownPeople = chamber.get_people()
	check("chamber owns the contact-reaction module", bumps != null)
	if bumps == null:
		return
	bumps.reset()
	var p: Ep2TownPeople.Person = people.people[0]
	var spot: Vector2 = people.navigation.closest(Vector2(0.0, 1425.0))
	p.shop = ""
	p.seat = -1
	p.destination = ""
	p.waypoints.clear()
	p.folk.use_height = false
	p.folk.place(Vector3(spot.x, 0.0, spot.y))
	p.state = "pause"
	p.timer = 30.0
	var player := Vector3(spot.x, 0.0, spot.y + 0.68)
	bumps.step(DT, player, Vector3(0.0, 0.0, -0.08))
	check("a person bump reacts once within 0.3 s", int(person_reactions(bumps, p.id)) == 1, person_reactions(bumps, p.id))
	for i in 6:
		bumps.step(DT, player, Vector3(0.0, 0.0, -0.08))
	check("the same contact does not retrigger during the 4 s cooldown", int(person_reactions(bumps, p.id)) == 1, person_reactions(bumps, p.id))
	var life: Ep2TownLife = chamber._visuals.find_child("TownLife", true, false) as Ep2TownLife
	var horse: Node3D = life.find_child("Horse0", true, false) as Node3D if life != null else null
	check("a real hitch-rail horse is available for contact", horse != null)
	if horse == null:
		return
	var forward := Vector3(cos(horse.rotation.y), 0.0, -sin(horse.rotation.y))
	var rear_player: Vector3 = horse.position - forward * 1.25
	var knock: Vector3 = bumps.step(DT, rear_player, forward * 0.08)
	var landed: Vector3 = rear_player
	var parts: int = maxi(1, ceili(knock.length() / 0.15))
	for i in parts:
		landed = chamber._collide(landed + knock / float(parts))
	check("a rear-arc horse bump kicks Lil Blunt back at least a metre", bumps.horse_kicks == 1 and Vector2(landed.x - rear_player.x, landed.z - rear_player.z).length() >= 1.0,
		[bumps.horse_kicks, knock, landed.distance_to(rear_player)])
	if ResourceLoader.exists(Ep2TownSoundscape.ROOT + "horse_kick.ogg"):
		check("the rear kick plays its recorded sound", bumps.kick_sounds == 1, bumps.kick_sounds)
	var front_horse: Node3D = life.find_child("Horse1", true, false) as Node3D
	if front_horse == null:
		check("a front horse bump shies but does not kick", false, "missing Horse1")
		return
	forward = Vector3(cos(front_horse.rotation.y), 0.0, -sin(front_horse.rotation.y))
	var front_player: Vector3 = front_horse.position + forward * 1.25
	var front_knock: Vector3 = bumps.step(DT, front_player, -forward * 0.08)
	check("a front horse bump shies but does not kick", front_knock.length() < 0.001 and bumps.horse_kicks == 1 and bumps.horse_shies >= 1,
		[bumps.horse_kicks, bumps.horse_shies])


func person_reactions(bumps: TOWN_BUMPS, id: String) -> int:
	return int(bumps.person_reactions.get(id, 0))


func _test_train(chamber: GoldTownChamber) -> void:
	var life: Ep2TownLife = chamber._visuals.find_child("TownLife", true, false) as Ep2TownLife
	check("the real chamber has its train", life != null)
	if life == null:
		return
	life._ensure_train_audio()
	check("the locomotive run is the recorded seamless steam loop", life._run_sfx.stream != null \
		and life._run_sfx.stream.resource_path.ends_with("train_steam_loop.ogg"), life._run_sfx.stream.resource_path if life._run_sfx.stream != null else "no stream")
	life._train.visible = false
	life._wait = 0.0
	life._passby_count = 0
	life._passby_armed = false
	life._pass_sfx.stop()
	var started: bool = false
	var finished: bool = false
	for i in int(150.0 / DT):
		life._process(DT)
		started = started or life._train.visible
		if started and not life._train.visible:
			finished = true
			break
	print("EP2_TOWN_FEEL pass-by: starts x=", life._passby_start_x, " peak lands x=", life._passby_peak_x, " count=", life._passby_count)
	check("the close pass-by fires exactly once in a crossing", life._passby_count == 1 and finished, life._passby_count)
	check("the pass-by's loudest second lands within 15 m of mid-street", absf(life._passby_peak_x) <= 15.0, life._passby_peak_x)
