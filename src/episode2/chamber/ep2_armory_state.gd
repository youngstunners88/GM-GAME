class_name Ep2ArmoryState
extends RefCounted
## One resource owner per session. Cameras project this state; they never award ammunition.
signal changed

const WIN := "winchester_1886"
const REM := "remington_1875_gold"
const IDS := [WIN, REM]
const NAMES := {WIN: "Winchester 1886", REM: "Golden Remington 1875"}
const AMMO_TYPES := {WIN: "rifle_round", REM: "revolver_round"}
const SWITCH_TIME := 0.18
const VERSION := 1
const CONTROL_FILE := "user://ep2_armory_controls.cfg"
const ACTIONS := ["ep2_weapon_1", "ep2_weapon_2", "ep2_weapon_previous", "ep2_armory"]
var owned: Dictionary = {}
var equipped: String = WIN
var previous: String = REM
var arrows: int = 0
var corpses: Dictionary = {}
var _guns: Dictionary = {}
var _switch_t: float = 0.0


func _init() -> void:
	for id in IDS:
		var gun := Ep2Winchester.new()
		gun.reserve = 0
		if id == REM:
			gun.capacity = 6           # existing runner's six-round game convention
			gun.cycle_time = 0.35      # existing runner's hammer cadence
		_guns[id] = gun
		_watch(gun)


func _watch(gun: Ep2Winchester) -> void:
	gun.fired.connect(_notify)
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
		gun.rounds = gun.capacity
		gun.reserve = 24 if id == WIN else 18
		gun.locked = false
		gun.reload_locked = false
	if id == WIN or not owns(equipped):
		equipped = id
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


func record_corpse(id: String, arrow_count: int) -> void:
	if not corpses.has(id):
		corpses[id] = {"arrows": clampi(arrow_count, 0, 100), "searched": false}
		changed.emit()


func claim_corpse(id: String) -> int:
	if not corpses.has(id) or bool(corpses[id]["searched"]):
		return -1
	var count: int = mini(int(corpses[id]["arrows"]), 999 - arrows)
	# Leave excess arrows on the body rather than destroy them at the storage cap.
	arrows += count
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
			"locked": gun.locked, "reload_locked": gun.reload_locked}
	return {"version": VERSION, "weapons": weapons, "equipped": equipped, "previous": previous,
		"arrows": arrows, "corpses": corpses.duplicate(true), "switch_t": _switch_t}


func restore(data: Dictionary, earned_remington: bool = false) -> void:
	owned.clear()
	corpses.clear()
	arrows = 0
	var valid: bool = SaveSafe.to_int(data.get("version", 0)) == VERSION and data.get("weapons") is Dictionary
	for id in IDS:
		var gun: Ep2Winchester = firearm(id)
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
					corpses[str(id)] = {"arrows": clampi(SaveSafe.to_int(records[id].get("arrows", 0)), 0, 100), "searched": bool(records[id].get("searched", false))}
	equipped = str(data.get("equipped", REM if owns(REM) else WIN))
	if not owns(equipped):
		equipped = WIN if owns(WIN) else REM if owns(REM) else WIN
	previous = REM if equipped == WIN else WIN
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
		"ep2_weapon_previous": [KEY_Q, JOY_BUTTON_Y], "ep2_armory": [KEY_TAB, JOY_BUTTON_BACK]}
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
