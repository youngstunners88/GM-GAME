class_name Ep2ArmoryState
extends RefCounted
## One resource owner per session. Cameras project this state; they never award ammunition.
signal changed
signal firearms_returned

const WIN := "winchester_1886"
const REM := "remington_1875_gold"
const BOW := "bear_longbow"
## An equipped mode while the Sheriff holds the irons, never a fourth slot.
const PICK := "pickaxe"
## Rich & Utah's new stock (founder 2026-11-01: "more weapons like a shotgun ... a bergmann mp18 submachine gun and a golden thompson
## submachine gun"). Bought at the counter with Episode 1 crypto like the rest; once owned they join the quick-switch armory.
const SHOT := "coach_shotgun"
const MP18 := "bergmann_mp18"
const TOMMY := "thompson_gold"
## The founder's locked set (2026-11-01 evening, "Guns Buff"): the Borchardt C-93 toggle-lock pistol and the Sharps buffalo gun join
## the quick-switch armory (keys 7 and 8), so all eight of his guns can be bought, carried and re-bought after jail.
## `SHOT` keeps its save id but is now his Winchester 1887 LEVER shotgun (the double-barrel coach gun was replaced by his Meshy model).
const BORCH := "borchardt_c93"
const BUFF := "sharps_buffalo"
const IDS := [WIN, REM, BOW, SHOT, MP18, TOMMY, BORCH, BUFF]
const NAMES := {WIN: "GM Lever Rifle", REM: "Golden BTC Revolver", BOW: "GM Bow",
	SHOT: "Lever Shotgun", MP18: "Drum SMG", TOMMY: "Golden Thompson", BORCH: "Borchardt Pistol", BUFF: "Buffalo Gun"}
const AMMO_TYPES := {WIN: "rifle_round", REM: "revolver_round", BOW: "bear_arrow", SHOT: "buckshot_shell", MP18: "nine_mm", TOMMY: "forty_five",
	BORCH: "seven_six_five", BUFF: "sharps_round"}
## Rounds that come with a gun when it is acquired (loaded + reserve; never refilled for free afterwards).
const START_RESERVE := {WIN: 24, REM: 18, BOW: 0, SHOT: 10, MP18: 64, TOMMY: 100, BORCH: 16, BUFF: 10}
## The guns' game profiles. Feel-values (F - free to tune): the coach gun is two barrels of buckshot (wide hit cone, a heavy kick,
## shell-by-shell reload); the two submachine guns fire while the trigger is HELD and change a whole drum at once.
const PROFILES := {
	SHOT: {"capacity": 5, "cycle": 0.62, "reload": 0.55, "kick": 4.6, "pellets": 8, "hit_scale": 2.4},
	BORCH: {"capacity": 8, "cycle": 0.24, "reload": 1.6, "kick": 2.0, "drum": true},
	BUFF: {"capacity": 1, "cycle": 1.1, "reload": 1.35, "kick": 6.5},
	MP18: {"capacity": 32, "cycle": 0.1, "reload": 2.3, "kick": 0.75, "automatic": true, "drum": true},
	TOMMY: {"capacity": 50, "cycle": 0.085, "reload": 2.7, "kick": 0.85, "automatic": true, "drum": true},
}
const SWITCH_TIME := 0.18
const VERSION := 1
const CONTROL_FILE := "user://ep2_armory_controls.cfg"
const ACTIONS := ["ep2_weapon_1", "ep2_weapon_2", "ep2_weapon_3", "ep2_weapon_previous", "ep2_armory",
	"ep2_weapon_4", "ep2_weapon_5", "ep2_weapon_6", "ep2_weapon_7", "ep2_weapon_8"]
## The quick-switch key for each slot in IDS order (1-8).
const SLOT_ACTIONS := ["ep2_weapon_1", "ep2_weapon_2", "ep2_weapon_3", "ep2_weapon_4", "ep2_weapon_5", "ep2_weapon_6",
	"ep2_weapon_7", "ep2_weapon_8"]
## The Armory (Rich & Utah, off Main Street) is the one PAID acquisition source.
## It sells firearms and ammunition for Episode 1 crypto; it never awards anything
## for free and respects the same finite reserve cap as earned ammunition.
const ARMORY_TENDER := ["btc", "eth", "wbtc", "sol", "titanx"]      # the whole purse pays (founder 2026-10-24)
const RESERVE_CAP := 2000
## The Armory's stock (single source of truth for the trade panel AND the chamber that debits it).
## Prices are feel-values in Episode 1 crypto coins (F - free to tune; never a protocol fact).
const SHOP: Array = [
	# FIRST ROW, ALWAYS (founder 2026-11-03): the Shipment - the water gear and sealed crates - is the priority buy. Without it Dude's lake
	# ride used to bounce Lil Blunt back to this counter; now nothing else here is sold until it is in his hands (`unlocks_stock`). The row
	# keeps its save id "river_gear", so a save that already holds it keeps it.
	{"id": "river_gear", "name": "THE SHIPMENT", "note": "WATER - SKIFF - SEALED CRATES", "price": 2, "rounds": 0},
	{"id": REM, "name": "GOLDEN BTC REVOLVER", "note": "SINGLE ACTION - BITCOIN CYLINDER", "price": 4, "rounds": 0},
	{"id": "revolver_ammo", "name": "SIXGUN CARTRIDGES", "note": "A BOX OF EIGHTEEN", "price": 1, "rounds": 18},
	{"id": BOW, "name": "GM BOW", "note": "RECURVE - GM MEDALLION", "price": 2, "rounds": 0},
	{"id": "arrows", "name": "GM ARROWS", "note": "A QUIVER OF TWELVE", "price": 1, "rounds": 12},
	{"id": WIN, "name": "GM LEVER RIFLE", "note": "WINCHESTER 1886 - GM RECEIVER", "price": 3, "rounds": 0},
	{"id": "rifle_ammo", "name": "REPEATER CARTRIDGES", "note": "A BOX OF TWENTY-FOUR", "price": 1, "rounds": 24},
	{"id": BORCH, "name": "BORCHARDT PISTOL", "note": "C-93 TOGGLE LOCK - EIGHT ROUNDS", "price": 3, "rounds": 0},
	{"id": "borchardt_ammo", "name": "7.65 BORCHARDT", "note": "TWO MAGAZINES - SIXTEEN", "price": 1, "rounds": 16},
	{"id": SHOT, "name": "LEVER SHOTGUN", "note": "WINCHESTER 1887 - FIVE SHELLS", "price": 3, "rounds": 0},
	{"id": "shotgun_ammo", "name": "BUCKSHOT SHELLS", "note": "A BOX OF TEN", "price": 1, "rounds": 10},
	{"id": "sniper", "name": "BUFFALO GUN", "note": "SHARPS 1874 - LADDER SIGHT", "price": 3, "rounds": 0},
	{"id": "sniper_ammo", "name": "SHARPS CARTRIDGES", "note": "A BOX OF TEN", "price": 2, "rounds": 10},
	{"id": MP18, "name": "DRUM SMG", "note": "BERGMANN MP18 - SNAIL DRUM", "price": 4, "rounds": 0},
	{"id": "mp18_ammo", "name": "9MM SNAIL DRUMS", "note": "TWO DRUMS - SIXTY-FOUR", "price": 1, "rounds": 64},
	{"id": TOMMY, "name": "GOLDEN THOMPSON", "note": "1928 - FIFTY-ROUND DRUM", "price": 6, "rounds": 0},
	{"id": "tommy_ammo", "name": ".45 DRUMS", "note": "TWO DRUMS - ONE HUNDRED", "price": 2, "rounds": 100},
]
## Shop rows that sell a firearm of the quick-switch armory, and the ammunition row that belongs to each gun. The buffalo gun keeps its
## story row id "sniper" (the day-88 overlook checks `sniper_owned`); buying it also puts the Sharps in the quick-switch armory (BUFF).
const SHOP_GUNS := [REM, BOW, WIN, BORCH, SHOT, MP18, TOMMY]
const SHOP_AMMO := {"rifle_ammo": WIN, "revolver_ammo": REM, "arrows": BOW, "borchardt_ammo": BORCH, "shotgun_ammo": SHOT,
	"mp18_ammo": MP18, "tommy_ammo": TOMMY}


## The unlock chain (founder 2026-11-03): the Shipment opens the counter, and the Sharps opens the other guns.
const GATE_ITEM := "river_gear"
const SHARPS_ITEM := "sniper"


## True when `id` may be sold to this state now: the Shipment always, everything else once he owns it, and the other guns only once he
## owns the Sharps too. Ammunition for a gun he carries stays on sale, and a gun the Sheriff holds can be bought back, so the chain can
## never leave him unable to reload or unarmed. Both links read `river_gear` and `sniper_owned`, which saves already carry.
## The panel greys rows with it and the chamber's buy() refuses with it, so the rule lives once.
static func unlocks_stock(armory_state: Ep2ArmoryState, id: String) -> bool:
	return lock_note(armory_state, id) == ""


## Why `id` is locked, in the counter's words ("" when it is not).
static func lock_note(armory_state: Ep2ArmoryState, id: String) -> String:
	if id == GATE_ITEM:
		return ""
	if armory_state == null or not armory_state.river_gear:
		return "SHIPMENT FIRST"
	if SHOP_GUNS.has(id) and not armory_state.sniper_owned and not armory_state.owns(id):
		return "SHARPS FIRST"
	return ""


static func shop_item(id: String) -> Dictionary:
	for item in SHOP:
		if str(item["id"]) == id:
			return item
	return {}


## The long rifle Rich sells for the day-88 overlook: the Sharps Model 1874 "Buffalo Gun" (founder 2026-10-20; the Colt Gatling on the Armory's post is
## NOT stock - it never appears in SHOP and nothing here can sell it). It is NOT one of the three
## quick-switch slots (the personal armory system is preserved untouched); it is
## carried into the river set-piece, so it is a separate acquisition.
const SNIPER := "armory_sniper"
var owned: Dictionary = {}
var equipped: String = WIN
var previous: String = REM
var firearms_confiscated: bool = false
var arrows: int = 0
var corpses: Dictionary = {}
var sniper_owned: bool = false
var sniper_rounds: int = 0
var river_gear: bool = false
## DUDE'S HORSE CARRIES ITS WOUNDS (founder 2026-11-04: "If the horse gets shot that must carry through so that Lil Blunt is unable to water it").
## 0 = sound, 1-2 = wounded (it walks but will not drink and cannot be ridden on), HORSE_WOUNDS_MAX = down. Held here because this state goes into
## every room hand-over and every save. Dude's care (treat_horse) is the one thing that clears it.
const HORSE_WOUNDS_MAX := 3
var horse_wounds: int = 0
## Guns the Sheriff is holding (jail). Each one comes back when the story returns the irons, or the moment Lil Blunt buys it again
## at Rich & Utah's (founder 2026-11-01: "upon release Lil Blunt needs to be able to acquire them").
var held: Dictionary = {}
var _guns: Dictionary = {}
var _switch_t: float = 0.0


func _init() -> void:
	for id in IDS:
		var gun: Ep2Winchester = Ep2Bow.new() if id == BOW else Ep2Winchester.new()
		gun.reserve = 0
		if id == REM:
			gun.capacity = 6           # existing runner's six-round game convention
			gun.cycle_time = 0.35      # existing runner's hammer cadence
		_apply_profile(id, gun)
		_guns[id] = gun
		_watch(gun)


## Give a new-stock gun its capacity, cadence, reload, kick and fire mode (PROFILES); the three original guns keep their defaults.
static func _apply_profile(id: String, gun: Ep2Winchester) -> void:
	if not PROFILES.has(id):
		return
	var p: Dictionary = PROFILES[id]
	gun.capacity = int(p["capacity"])
	gun.cycle_time = float(p["cycle"])
	gun.reload_interval = float(p["reload"])
	gun.kick_deg = float(p["kick"])
	gun.automatic = bool(p.get("automatic", false))
	gun.drum_reload = bool(p.get("drum", false))
	gun.pellets = int(p.get("pellets", 1))
	gun.hit_scale = float(p.get("hit_scale", 1.0))


func _watch(gun: Ep2Winchester) -> void:
	gun.fired.connect(func() -> void:
		if gun is Ep2Bow:
			arrows = gun.rounds
		_notify())
	gun.shell_loaded.connect(func(_rounds: int) -> void: changed.emit())


func _notify() -> void:
	changed.emit()


func firearm(id: String) -> Ep2Winchester:
	return _guns.get(id)


func active_gun() -> Ep2Winchester:
	if equipped == PICK:
		return firearm(previous if IDS.has(previous) else WIN)
	return firearm(equipped)


func owns(id: String) -> bool:
	return bool(owned.get(id, false))


func acquire(id: String, source: Ep2Winchester = null) -> bool:
	if not IDS.has(id) or owns(id):
		return false
	owned[id] = true
	var gun: Ep2Winchester = firearm(id)
	if source != null:
		_guns[id] = source
		_watch(source)
	else:
		gun.rounds = arrows if id == BOW else gun.capacity
		gun.reserve = int(START_RESERVE.get(id, 18))
		gun.locked = false
		gun.reload_locked = false
	if not firearms_confiscated and (id == WIN or not owns(equipped)):
		equipped = id
	changed.emit()
	return true


## A gun taken in the world, not bought: grants it, or tops it back up when he has it already. Never changes what is in his hands.
func take_found(id: String) -> void:
	if acquire(id):
		return
	var gun: Ep2Winchester = firearm(id)
	gun.rounds = gun.capacity
	gun.reserve = maxi(gun.reserve, int(START_RESERVE.get(id, 18)))
	changed.emit()


## The Armory's paid path (Rich & Utah, off Main Street). `tender` is the Episode 1
## crypto currency ("btc" / "eth" / "sol"); the calling room owns the balance and
## debits it before asking. A purchase never re-sells an owned gun and never marks
## ammunition free (the finite reserve cap is unchanged).
func purchase_firearm(id: String, tender: String) -> bool:
	if not IDS.has(id) or not ARMORY_TENDER.has(tender):
		return false
	if owns(id):
		if not is_held(id):
			return false
		# re-bought after jail: a fresh gun off Rich's rack, loaded, with its starting box
		held.erase(id)
		var gun: Ep2Winchester = firearm(id)
		gun.cancel_reload()
		gun.locked = false
		gun.reload_locked = false
		if id == BOW:
			arrows = maxi(arrows, 12)
			(gun as Ep2Bow).rounds = arrows
		else:
			gun.rounds = gun.capacity
			gun.reserve = maxi(gun.reserve, int(START_RESERVE.get(id, 18)))
		_take_up(id)
		changed.emit()
		return true
	if not acquire(id):
		return false
	if id == BOW and arrows < 12:
		arrows = 12
		(firearm(BOW) as Ep2Bow).rounds = arrows
	if firearms_confiscated:
		_take_up(id)
	changed.emit()
	return true


## A gun bought while the Sheriff holds the rest goes straight into Lil Blunt's hands (no pickaxe-only walk out of Rich's).
func _take_up(id: String) -> void:
	if equipped == id:
		return
	if IDS.has(equipped) and not is_held(equipped):
		previous = equipped
	equipped = id
	_switch_t = SWITCH_TIME


func is_held(id: String) -> bool:
	return bool(held.get(id, false))


func purchase_ammo(id: String, rounds: int, tender: String) -> bool:
	if not owns(id) or rounds <= 0 or not ARMORY_TENDER.has(tender):
		return false
	if id == BOW:
		var room: int = 999 - arrows
		if room <= 0:
			return false
		arrows += mini(rounds, room)
		(firearm(BOW) as Ep2Bow).rounds = arrows
	else:
		var gun: Ep2Winchester = firearm(id)
		gun.reserve = mini(gun.reserve + rounds, RESERVE_CAP)
	changed.emit()
	return true


## The day-88 long rifle: a one-time Armory purchase (Episode 1 crypto only).
func purchase_sniper(tender: String) -> bool:
	if not ARMORY_TENDER.has(tender):
		return false
	if sniper_owned and owns(BUFF) and not is_held(BUFF):
		return false
	sniper_owned = true
	if owns(BUFF):
		return purchase_firearm(BUFF, tender) or true
	acquire(BUFF)
	firearm(BUFF).reserve = maxi(firearm(BUFF).reserve, sniper_rounds)
	if firearms_confiscated:
		_take_up(BUFF)
	changed.emit()
	return true


## Long-rifle cartridges for the day-88 set-piece (sold by the box, finite like the rest).
func purchase_sniper_ammo(rounds: int, tender: String) -> bool:
	if not sniper_owned or rounds <= 0 or sniper_rounds >= RESERVE_CAP or not ARMORY_TENDER.has(tender):
		return false
	sniper_rounds = mini(sniper_rounds + rounds, RESERVE_CAP)
	if owns(BUFF):
		firearm(BUFF).reserve = mini(firearm(BUFF).reserve + rounds, RESERVE_CAP)
	changed.emit()
	return true


## The river gear (skiff / sealed buoyant crates) that carries the day-88 shipment.
func purchase_river_gear(tender: String) -> bool:
	if river_gear or not ARMORY_TENDER.has(tender):
		return false
	river_gear = true
	changed.emit()
	return true


## Standalone post-hideout scenes declare their story entry, separate from rendering.
static func post_hideout() -> Ep2ArmoryState:
	var state := Ep2ArmoryState.new()
	state.acquire(WIN)
	return state


## Take the Winchester, Remington and Bow out of circulation at the jailhouse.
## Ownership, ammunition and purchases are preserved; only selection changes.
func confiscate_firearms() -> void:
	if firearms_confiscated:
		equipped = PICK
		return
	var current: Ep2Winchester = active_gun()
	if current != null:
		current.cancel_reload()
		current.set_aim(false)
	if IDS.has(equipped):
		previous = equipped
	held.clear()
	for id in IDS:
		if owns(id):
			held[id] = true
	firearms_confiscated = true
	equipped = PICK
	_switch_t = 0.0
	changed.emit()


## Return the held irons when the story says Lil Blunt leaves town. No weapon
## is granted that he did not already own, and the pick remains a safe fallback.
func return_firearms() -> void:
	if not firearms_confiscated:
		return
	firearms_confiscated = false
	held.clear()
	if IDS.has(equipped) and owns(equipped):
		changed.emit()                 # he already bought a gun back at Rich's: keep it in his hands
		firearms_returned.emit()
		return
	var choice: String = previous if IDS.has(previous) and owns(previous) else ""
	if choice == "":
		for id in IDS:
			if owns(id):
				choice = id
				if id == WIN:
					break
	if choice == "":
		equipped = PICK
		previous = WIN
	else:
		equipped = choice
		previous = REM if choice == WIN else WIN
	_switch_t = 0.0
	changed.emit()
	firearms_returned.emit()


func select(id: String) -> bool:
	if is_held(id) or not owns(id) or id == equipped:
		return false
	active_gun().cancel_reload()
	active_gun().set_aim(false)
	previous = equipped
	equipped = id
	active_gun().set_aim(false)
	_switch_t = SWITCH_TIME
	changed.emit()
	return true


func select_previous() -> bool:
	return select(previous)


func ready() -> bool:
	if equipped == PICK:
		return firearms_confiscated
	return owns(equipped) and not is_held(equipped) and _switch_t <= 0.0


func step(delta: float) -> void:
	_switch_t = maxf(0.0, _switch_t - delta)
	for gun in _guns.values():
		(gun as Ep2Winchester).step(delta)   # holstered cooldowns continue; switching never resets one


func record_corpse(id: String, arrow_count: int, has_bow: bool = false) -> void:
	if not corpses.has(id):
		corpses[id] = {"arrows": clampi(arrow_count, 0, 100), "searched": false, "bow": has_bow}
		changed.emit()


func claim_corpse(id: String) -> int:
	if not corpses.has(id) or bool(corpses[id]["searched"]):
		return -1
	if bool(corpses[id].get("bow", false)):
		acquire(BOW)
	var count: int = mini(int(corpses[id]["arrows"]), 999 - arrows)
	# Leave excess arrows on the body rather than destroy them at the storage cap.
	arrows += count
	(firearm(BOW) as Ep2Bow).rounds = arrows
	corpses[id]["arrows"] -= count
	corpses[id]["searched"] = int(corpses[id]["arrows"]) == 0
	changed.emit()
	return count


func wound_horse() -> void:
	horse_wounds = mini(horse_wounds + 1, HORSE_WOUNDS_MAX)
	changed.emit()


func treat_horse() -> void:
	horse_wounds = 0
	changed.emit()


func horse_is_sound() -> bool: return horse_wounds == 0
func horse_is_down() -> bool: return horse_wounds >= HORSE_WOUNDS_MAX


func snapshot() -> Dictionary:
	var weapons: Dictionary = {}
	for id in IDS:
		var gun: Ep2Winchester = firearm(id)
		weapons[id] = {"owned": owns(id), "loaded": gun.rounds, "reserve": gun.reserve,
			"cycle": gun._cycle, "reload_t": gun._reload_t, "reloading": gun.reloading,
			"locked": gun.locked, "reload_locked": gun.reload_locked, "training_complete": gun.training_complete}
	return {"version": VERSION, "weapons": weapons, "equipped": equipped, "previous": previous,
		"arrows": arrows, "corpses": corpses.duplicate(true), "switch_t": _switch_t,
		"sniper": sniper_owned, "sniper_rounds": sniper_rounds, "river_gear": river_gear, "horse_wounds": horse_wounds,
		"confiscated": firearms_confiscated, "held": held.keys()}


func restore(data: Dictionary, earned_remington: bool = false) -> void:
	owned.clear()
	corpses.clear()
	arrows = 0
	firearms_confiscated = false
	var valid: bool = SaveSafe.to_int(data.get("version", 0)) == VERSION and data.get("weapons") is Dictionary
	for id in IDS:
		var gun: Ep2Winchester = firearm(id)
		gun.cancel_reload()
		var entry: Dictionary = data["weapons"].get(id, {}) if valid and data["weapons"].get(id, {}) is Dictionary else {}
		var acquired: bool = bool(entry.get("owned", false))
		owned[id] = acquired
		gun.rounds = clampi(SaveSafe.to_int(entry.get("loaded", 0)), 0, gun.capacity) if acquired else 0
		gun.reserve = clampi(SaveSafe.to_int(entry.get("reserve", 0)), 0, 2000) if acquired else 0
		gun._cycle = clampf(SaveSafe.to_float(entry.get("cycle", 0)), 0, gun.cycle_time)
		gun._reload_t = clampf(SaveSafe.to_float(entry.get("reload_t", 0)), 0, gun.reload_interval)
		gun.reloading = acquired and bool(entry.get("reloading", false)) and gun.reserve > 0 and not gun.is_full()
		gun.locked = bool(entry.get("locked", not acquired))
		gun.reload_locked = bool(entry.get("reload_locked", not acquired))
		gun.training_complete = acquired and bool(entry.get("training_complete", false))
		gun.set_aim(false)
		gun.ads = 0.0
	if earned_remington and not owns(REM):
		acquire(REM)     # old campaign saves prove acquisition by Stage 3 progress
	if valid:
		arrows = clampi(SaveSafe.to_int(data.get("arrows", 0)), 0, 999)
		var records: Variant = data.get("corpses", {})
		if records is Dictionary:
			for id in records:
				if records[id] is Dictionary:
					corpses[str(id)] = {"arrows": clampi(SaveSafe.to_int(records[id].get("arrows", 0)), 0, 100), "searched": bool(records[id].get("searched", false)), "bow": bool(records[id].get("bow", false))}
	(firearm(BOW) as Ep2Bow).rounds = arrows
	firearms_confiscated = valid and bool(data.get("confiscated", false))
	held.clear()
	if firearms_confiscated:
		var kept: Variant = data.get("held", null)
		for id in IDS:
			if owns(id) and (not kept is Array or (kept as Array).has(id)):
				held[id] = true          # a save from before per-gun holds: everything he owned is held
	var wanted: String = str(data.get("equipped", REM if owns(REM) else WIN))
	if firearms_confiscated and (not IDS.has(wanted) or is_held(wanted) or not owns(wanted)):
		equipped = PICK
	else:
		equipped = wanted
		if equipped == PICK or not owns(equipped):
			equipped = WIN if owns(WIN) else REM if owns(REM) else WIN
	previous = REM if equipped in [WIN, PICK] else WIN
	if firearms_confiscated and IDS.has(str(data.get("previous", ""))):
		previous = str(data["previous"])
	sniper_owned = valid and bool(data.get("sniper", false))
	sniper_rounds = clampi(SaveSafe.to_int(data.get("sniper_rounds", 0)), 0, RESERVE_CAP) if sniper_owned else 0
	if sniper_owned and not owns(BUFF):
		# a save from before the buffalo gun joined the quick-switch armory: the Sharps he paid for is in it
		owned[BUFF] = true
		var sharps: Ep2Winchester = firearm(BUFF)
		sharps.rounds = sharps.capacity
		sharps.reserve = sniper_rounds
		sharps.locked = false
		sharps.reload_locked = false
	river_gear = valid and bool(data.get("river_gear", false))
	horse_wounds = clampi(SaveSafe.to_int(data.get("horse_wounds", 0)), 0, HORSE_WOUNDS_MAX) if valid else 0
	_switch_t = clampf(SaveSafe.to_float(data.get("switch_t", 0)), 0.0, SWITCH_TIME) if valid else 0.0
	changed.emit()


func detached_copy() -> Ep2ArmoryState:
	var copy := Ep2ArmoryState.new()
	copy.restore(snapshot())
	return copy


static func install_actions() -> void:
	var config := ConfigFile.new()
	config.load(CONTROL_FILE)
	var bindings: Dictionary = {"ep2_weapon_1": [KEY_1, JOY_BUTTON_LEFT_SHOULDER], "ep2_weapon_2": [KEY_2, JOY_BUTTON_RIGHT_SHOULDER],
		"ep2_weapon_3": [KEY_3, JOY_BUTTON_DPAD_UP], "ep2_weapon_previous": [KEY_Q, JOY_BUTTON_Y], "ep2_armory": [KEY_TAB, JOY_BUTTON_BACK],
		"ep2_weapon_4": [KEY_4, JOY_BUTTON_DPAD_RIGHT], "ep2_weapon_5": [KEY_5, JOY_BUTTON_DPAD_DOWN], "ep2_weapon_6": [KEY_6, JOY_BUTTON_DPAD_LEFT],
		"ep2_weapon_7": [KEY_7, JOY_BUTTON_LEFT_STICK], "ep2_weapon_8": [KEY_8, JOY_BUTTON_RIGHT_STICK]}
	for action in bindings:
		if InputMap.has_action(action):
			continue             # existing custom/rebound controls take precedence
		InputMap.add_action(action)
		var key := InputEventKey.new()
		key.physical_keycode = bindings[action][0]
		InputMap.action_add_event(action, key)
		var button := InputEventJoypadButton.new()
		button.button_index = bindings[action][1]
		InputMap.action_add_event(action, button)
		if config.has_section_key("keyboard", action):
			rebind_key(action, SaveSafe.to_int(config.get_value("keyboard", action)), false)


static func key_label(action: String) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return OS.get_keycode_string(event.physical_keycode if event.physical_keycode != 0 else event.keycode)
	return "Unbound"


static func rebind_key(action: String, code: int, persist: bool = true) -> bool:
	if not ACTIONS.has(action) or code <= 0 or code in [KEY_R, KEY_SPACE, KEY_ESCAPE, KEY_K, KEY_X]:
		return false
	# Keep movement, interaction and existing menu shortcuts usable.
	for other in InputMap.get_actions():
		if other == action:
			continue
		for event in InputMap.action_get_events(other):
			if event is InputEventKey and (event.physical_keycode == code or event.keycode == code):
				return false
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			InputMap.action_erase_event(action, event)
	var key := InputEventKey.new()
	key.physical_keycode = code
	InputMap.action_add_event(action, key)
	if persist:
		var config := ConfigFile.new()
		config.load(CONTROL_FILE)
		config.set_value("keyboard", action, code)
		config.save(CONTROL_FILE)
	return true
