class_name Ep2ArmoryState
extends RefCounted
## One resource owner per session. Cameras project this state; they never award ammunition.
signal changed

const WIN := "winchester_1886"
const REM := "remington_1875_gold"
const BOW := "bear_longbow"
const IDS := [WIN, REM, BOW]
const NAMES := {WIN: "Winchester 1886", REM: "Golden Remington 1875", BOW: "Recovered Bear Bow"}
const AMMO_TYPES := {WIN: "rifle_round", REM: "revolver_round", BOW: "bear_arrow"}
const SWITCH_TIME := 0.18
const VERSION := 1
const CONTROL_FILE := "user://ep2_armory_controls.cfg"
const ACTIONS := ["ep2_weapon_1", "ep2_weapon_2", "ep2_weapon_3", "ep2_weapon_previous", "ep2_armory"]
## The Armory (Rich & Utah, off Main Street) is the one PAID acquisition source.
## It sells firearms and ammunition for Episode 1 crypto; it never awards anything
## for free and respects the same finite reserve cap as earned ammunition.
const ARMORY_TENDER := ["btc", "eth", "sol"]
const RESERVE_CAP := 2000
## The Armory's stock (single source of truth for the trade panel AND the chamber that debits it).
## Prices are feel-values in Episode 1 crypto coins (F - free to tune; never a protocol fact).
const SHOP: Array = [
	{"id": "sniper", "name": "LONG RIFLE", "note": "SET TRIGGER - FOR THE OVERLOOK", "price": 3, "rounds": 0},
	{"id": "sniper_ammo", "name": "LONG-RIFLE CARTRIDGES", "note": "A BOX OF TEN", "price": 2, "rounds": 10},
	{"id": "rifle_ammo", "name": "REPEATER CARTRIDGES", "note": "A BOX OF TWENTY-FOUR", "price": 1, "rounds": 24},
	{"id": "revolver_ammo", "name": "SIXGUN CARTRIDGES", "note": "A BOX OF EIGHTEEN", "price": 1, "rounds": 18},
	{"id": "river_gear", "name": "RIVER GEAR", "note": "SKIFF AND SEALED CRATES", "price": 2, "rounds": 0},
]


static func shop_item(id: String) -> Dictionary:
	for item in SHOP:
		if str(item["id"]) == id:
			return item
	return {}


## The long rifle Rich sells for the day-88 overlook. It is NOT one of the three
## quick-switch slots (the personal armory system is preserved untouched); it is
## carried into the river set-piece, so it is a separate acquisition.
const SNIPER := "armory_sniper"
var owned: Dictionary = {}
var equipped: String = WIN
var previous: String = REM
var arrows: int = 0
var corpses: Dictionary = {}
var sniper_owned: bool = false
var sniper_rounds: int = 0
var river_gear: bool = false
var _guns: Dictionary = {}
var _switch_t: float = 0.0


func _init() -> void:
	for id in IDS:
		var gun: Ep2Winchester = Ep2Bow.new() if id == BOW else Ep2Winchester.new()
		gun.reserve = 0
		if id == REM:
			gun.capacity = 6           # existing runner's six-round game convention
			gun.cycle_time = 0.35      # existing runner's hammer cadence
		_guns[id] = gun
		_watch(gun)


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
		gun.reserve = 24 if id == WIN else 0 if id == BOW else 18
		gun.locked = false
		gun.reload_locked = false
	if id == WIN or not owns(equipped):
		equipped = id
	changed.emit()
	return true


## The Armory's paid path (Rich & Utah, off Main Street). `tender` is the Episode 1
## crypto currency ("btc" / "eth" / "sol"); the calling room owns the balance and
## debits it before asking. A purchase never re-sells an owned gun and never marks
## ammunition free (the finite reserve cap is unchanged).
func purchase_firearm(id: String, tender: String) -> bool:
	if not IDS.has(id) or owns(id) or not ARMORY_TENDER.has(tender):
		return false
	return acquire(id)


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
	if sniper_owned or not ARMORY_TENDER.has(tender):
		return false
	sniper_owned = true
	changed.emit()
	return true


## Long-rifle cartridges for the day-88 set-piece (sold by the box, finite like the rest).
func purchase_sniper_ammo(rounds: int, tender: String) -> bool:
	if not sniper_owned or rounds <= 0 or sniper_rounds >= RESERVE_CAP or not ARMORY_TENDER.has(tender):
		return false
	sniper_rounds = mini(sniper_rounds + rounds, RESERVE_CAP)
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


func select(id: String) -> bool:
	if not owns(id) or id == equipped:
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
	return owns(equipped) and _switch_t <= 0.0


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


func snapshot() -> Dictionary:
	var weapons: Dictionary = {}
	for id in IDS:
		var gun: Ep2Winchester = firearm(id)
		weapons[id] = {"owned": owns(id), "loaded": gun.rounds, "reserve": gun.reserve,
			"cycle": gun._cycle, "reload_t": gun._reload_t, "reloading": gun.reloading,
			"locked": gun.locked, "reload_locked": gun.reload_locked, "training_complete": gun.training_complete}
	return {"version": VERSION, "weapons": weapons, "equipped": equipped, "previous": previous,
		"arrows": arrows, "corpses": corpses.duplicate(true), "switch_t": _switch_t,
		"sniper": sniper_owned, "sniper_rounds": sniper_rounds, "river_gear": river_gear}


func restore(data: Dictionary, earned_remington: bool = false) -> void:
	owned.clear()
	corpses.clear()
	arrows = 0
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
	equipped = str(data.get("equipped", REM if owns(REM) else WIN))
	if not owns(equipped):
		equipped = WIN if owns(WIN) else REM if owns(REM) else WIN
	previous = REM if equipped == WIN else WIN
	sniper_owned = valid and bool(data.get("sniper", false))
	sniper_rounds = clampi(SaveSafe.to_int(data.get("sniper_rounds", 0)), 0, RESERVE_CAP) if sniper_owned else 0
	river_gear = valid and bool(data.get("river_gear", false))
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
		"ep2_weapon_3": [KEY_3, JOY_BUTTON_DPAD_UP], "ep2_weapon_previous": [KEY_Q, JOY_BUTTON_Y], "ep2_armory": [KEY_TAB, JOY_BUTTON_BACK]}
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
