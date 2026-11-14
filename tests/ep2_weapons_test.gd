extends Node
## WEAPON TABS SHOW ONLY WHAT LIL BLUNT HAS, THE PICKAXE TAB, AND RICH & UTAH'S SHOP ORDER (founder 2026-11-07; skill ep2-build-logic).
## Asserts what the player sees: the tab strip at Rich's counter (Ep2ArmoryShop: its tabs and their visible buttons, the case), the cards and every
## word Tabs draws (Ep2WeaponSelector.drawn_text), the counter's rows from the top, and the chain that locks them.
## Run: .godot-cache/Godot_v4.3-stable_linux.x86_64 --headless res://tests/ep2_weapons_test.tscn

const TOWN := preload("res://src/episode2/chamber/gold_town.tscn")
const POSE := preload("res://src/episode2/actors/ep2_armory_pose.gd")
## Every row id the saves and the story know, pinned: the order may change, these never do.
const ROW_IDS := ["river_gear", "sniper", "sniper_ammo", "winchester_1886", "rifle_ammo", "remington_1875_gold", "revolver_ammo", "bear_longbow",
	"arrows", "borchardt_c93", "borchardt_ammo", "coach_shotgun", "shotgun_ammo", "bergmann_mp18", "mp18_ammo", "thompson_gold", "tommy_ammo"]
## The guns after the Sharps, in the order the story puts them in his hands (hideout, runner, woods archer, the draw, then counter-only stock).
const STORY_GUNS := [Ep2ArmoryState.WIN, Ep2ArmoryState.REM, Ep2ArmoryState.BOW, Ep2ArmoryState.BORCH, Ep2ArmoryState.SHOT, Ep2ArmoryState.MP18,
	Ep2ArmoryState.TOMMY]
## Words Tabs used to write for guns he did not have.
const TEASES := ["SOLD AT RICH", "NOT YET ACQUIRED", "RECOVER FROM AN ARCHER", "REBUY AT RICH"]
var _failures: int = 0
var _layer: CanvasLayer = null


func check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] ", label)
	else:
		_failures += 1
		print("  [FAIL] ", label, " ", detail)


func _ready() -> void:
	var save_guard: RefCounted = preload("res://tests/ep2_save_guard.gd").new()
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_window().size = Vector2i(1280, 720)
	_layer = CanvasLayer.new()
	add_child(_layer)
	await _test_new_save()
	await _test_purchase_reveals()
	await _test_confiscation_hides()
	await _test_pickaxe_tab()
	await _test_pickaxe_always()
	await _test_pickaxe_melee()
	_test_shop_order()
	_test_lock_chain()
	await _test_case_takeout()
	save_guard = null
	print("EP2_WEAPONS: %s" % ("ALL PASS" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(0 if _failures == 0 else 1)


# --- helpers: what the player sees ------------------------------------------------------------------------------------------

func _shop_for(st: Ep2ArmoryState) -> Ep2ArmoryShop:
	var shop := Ep2ArmoryShop.new()
	_layer.add_child(shop)
	shop.open_shop(st, 50)
	shop.grace = 0.0
	return shop


func _tab_keys(shop: Ep2ArmoryShop) -> Array:
	var out: Array = []
	for tab in shop._tabs():
		out.append(str(tab["key"]))
	return out


func _visible_tab_buttons(shop: Ep2ArmoryShop) -> int:
	var n: int = 0
	for b in shop._tab_btns:
		n += 1 if b.visible else 0
	return n


func _selector_for(st: Ep2ArmoryState) -> Ep2WeaponSelector:
	var sel := Ep2WeaponSelector.new()
	sel.state = st
	_layer.add_child(sel)
	return sel


func _frames(n: int = 3) -> void:
	for i in n:
		await get_tree().process_frame


## Names of guns he does not have now, as Tabs or the strip would write them.
func _unearned_words(st: Ep2ArmoryState) -> Array:
	var out: Array = []
	for id in Ep2ArmoryState.IDS:
		if not (st.owns(id) and not st.is_held(id)):
			out.append(str(Ep2ArmoryState.NAMES[id]).to_upper())
	for tab in Ep2ArmoryShop.WEAPON_TABS:
		if not Ep2ArmoryShop.tab_owned(st, tab):
			out.append(str(tab["label"]))
	return out


func _named(text: PackedStringArray, words: Array) -> Array:
	var hits: Array = []
	var all: String = " | ".join(text)
	for w in words:
		if all.contains(str(w)):
			hits.append(w)
	return hits


# --- the tests ------------------------------------------------------------------------------------------------------------

func _test_new_save() -> void:
	print("-- A NEW SAVE: nothing he has not earned shows or is named")
	var bare := Ep2ArmoryState.new()                       # before the hideout hands him the Winchester
	var shop := _shop_for(bare)
	await _frames()
	check("before any gun, the strip at Rich's has only his pickaxe", _tab_keys(shop) == [Ep2ArmoryState.PICK] and _visible_tab_buttons(shop) == 1, str(_tab_keys(shop)))
	shop.queue_free()
	var st := Ep2ArmoryState.post_hideout()                # the town's real starting state: the Winchester from the hideout
	shop = _shop_for(st)
	await _frames()
	check("in town: the Winchester and the pickaxe, and nothing else", _tab_keys(shop) == [Ep2ArmoryState.WIN, Ep2ArmoryState.PICK], str(_tab_keys(shop)))
	check("one visible tab button per tab he owns", _visible_tab_buttons(shop) == 2, str(_visible_tab_buttons(shop)))
	var sel := _selector_for(st)
	await _frames()
	check("Tabs has one card, the Winchester", sel.shown_ids() == [Ep2ArmoryState.WIN], str(sel.shown_ids()))
	var visible_cards: int = 0
	for c in sel.cards:
		visible_cards += 1 if c.visible else 0
	check("...and one card on screen", visible_cards == 1, str(visible_cards))
	var hits: Array = _named(sel.drawn_text, _unearned_words(st) + TEASES)
	check("Tabs names no gun he has not earned, and teases none", hits.is_empty(), str(hits))
	check("no bear arrows line before a bow or an arrow", not " ".join(sel.drawn_text).contains("BEAR ARROWS"))
	var switched: bool = false
	for id in Ep2ArmoryState.IDS:
		if id != Ep2ArmoryState.WIN:
			switched = switched or st.select(id)
	check("no quick-switch key brings out a gun he does not have", not switched and st.equipped == Ep2ArmoryState.WIN)
	sel.queue_free()
	shop.queue_free()
	await _frames(1)


func _test_purchase_reveals() -> void:
	print("-- BUYING A GUN REVEALS ITS TAB")
	var st := Ep2ArmoryState.post_hideout()
	var shop := _shop_for(st)
	var sel := _selector_for(st)
	await _frames()
	check("before the Sharps is bought, no SHARPS tab and no Buffalo Gun card", not _tab_keys(shop).has(Ep2ArmoryState.BUFF) and sel.card_slot(Ep2ArmoryState.BUFF) < 0)
	st.purchase_river_gear("btc")
	await _frames()
	check("the Shipment is logistics, not a gun: it adds no weapon tab", _tab_keys(shop) == [Ep2ArmoryState.WIN, Ep2ArmoryState.PICK], str(_tab_keys(shop)))
	st.purchase_sniper("btc")
	await _frames()
	check("the Sharps bought: its tab is on the strip", _tab_keys(shop).has(Ep2ArmoryState.BUFF) and _visible_tab_buttons(shop) == 3, str(_tab_keys(shop)))
	check("...and its card is in Tabs, named", sel.card_slot(Ep2ArmoryState.BUFF) >= 0 and " ".join(sel.drawn_text).contains("BUFFALO GUN"))
	check("...and its quick-switch key works", st.select(Ep2ArmoryState.BUFF))
	st.purchase_firearm(Ep2ArmoryState.TOMMY, "btc")
	await _frames()
	check("a second gun: both its tabs (gun and held) appear, nothing else", _tab_keys(shop).has(Ep2ArmoryState.TOMMY) and _tab_keys(shop).has(Ep2ArmoryState.TOMMY + "_held")
		and not _tab_keys(shop).has(Ep2ArmoryState.MP18) and _visible_tab_buttons(shop) == 5, str(_tab_keys(shop)))
	var hits: Array = _named(sel.drawn_text, _unearned_words(st) + TEASES)
	check("Tabs still names only what he owns", hits.is_empty(), str(hits))
	sel.queue_free()
	shop.queue_free()
	await _frames(1)


func _test_confiscation_hides() -> void:
	print("-- A JAIL CONFISCATION HIDES THEM; BUYING BACK SHOWS THEM AGAIN")
	var st := Ep2ArmoryState.post_hideout()
	st.purchase_river_gear("btc")
	st.purchase_sniper("btc")
	var shop := _shop_for(st)
	var sel := _selector_for(st)
	st.confiscate_firearms()
	await _frames()
	check("the Sheriff holds the irons: the strip shows only the pickaxe", _tab_keys(shop) == [Ep2ArmoryState.PICK] and _visible_tab_buttons(shop) == 1, str(_tab_keys(shop)))
	check("Tabs shows no card", sel.shown_ids().is_empty())
	var said: String = " ".join(sel.drawn_text)
	check("Tabs says where they are, and names no gun", said.contains("THE SHERIFF HOLDS YOUR IRONS") and _named(sel.drawn_text, _unearned_words(st)).is_empty(), said)
	st.purchase_sniper("btc")                             # bought back at Rich's while the rest are held
	await _frames()
	check("the Sharps bought back: its tab and card return, the Winchester's do not", _tab_keys(shop) == [Ep2ArmoryState.BUFF, Ep2ArmoryState.PICK]
		and sel.shown_ids() == [Ep2ArmoryState.BUFF], "%s %s" % [str(_tab_keys(shop)), str(sel.shown_ids())])
	st.return_firearms()
	await _frames()
	check("the irons returned: every gun he owns is back", _tab_keys(shop) == [Ep2ArmoryState.BUFF, Ep2ArmoryState.WIN, Ep2ArmoryState.PICK]
		and sel.shown_ids() == [Ep2ArmoryState.WIN, Ep2ArmoryState.BUFF], "%s %s" % [str(_tab_keys(shop)), str(sel.shown_ids())])
	sel.queue_free()
	shop.queue_free()
	await _frames(1)


func _test_pickaxe_tab() -> void:
	print("-- THE PICKAXE TAB (his own tool: there from the start, sold nowhere)")
	var tab: Dictionary = {}
	for t in Ep2ArmoryShop.WEAPON_TABS:
		if str(t["key"]) == Ep2ArmoryState.PICK:
			tab = t
	check("WEAPON_TABS has a pickaxe tab keyed to Ep2ArmoryState.PICK, with no shop row", not tab.is_empty() and str(tab["row"]) == "")
	check("its model is the founder's War Pick, streamed (extras), not the 62 MB Meshy download",
		not tab.is_empty() and str(tab["model"]) == Ep2Extras.SHOWCASE_DIR + "war_pick_held.glb" and Ep2Extras.has(str(tab["model"])))
	check("no shop row sells a pickaxe", Ep2ArmoryState.shop_item(Ep2ArmoryState.PICK).is_empty())
	var st := Ep2ArmoryState.post_hideout()
	var shop := _shop_for(st)
	var bought: Array = []
	shop.buy_requested.connect(func(id: String, _p: int, _t: String) -> void: bought.append(id))
	await _frames()
	var at: int = _tab_keys(shop).find(Ep2ArmoryState.PICK)
	var row_before: int = shop.index
	shop._tab_btns[at].pressed.emit()
	await _frames(4)
	check("its tab puts the pick in the case and lights the tab", shop.showcase_key == Ep2ArmoryState.PICK and shop._case_piece != null and shop.active_tab() == at)
	check("...without moving the highlight or buying anything", shop.index == row_before and bought.is_empty())
	shop.index = 1
	await _frames(2)
	check("moving the highlight hands the case back to that row", shop.showcase_key != Ep2ArmoryState.PICK and shop.active_tab() != at)
	st.confiscate_firearms()
	await _frames()
	check("the Sheriff never takes it: its tab stays through a confiscation", _tab_keys(shop).has(Ep2ArmoryState.PICK))
	shop.queue_free()
	await _frames(1)


## Founder 2026-11-14: the native pickaxe is always usable in the shooter, not only while the Sheriff holds the irons.
func _test_pickaxe_always() -> void:
	print("-- THE PICKAXE IS ALWAYS IN REACH (never bought, never confiscated to get it, the guns stay his)")
	var st := Ep2ArmoryState.post_hideout()
	st.acquire(Ep2ArmoryState.REM)
	var rifle_rounds: int = st.firearm(Ep2ArmoryState.WIN).rounds
	check("a normal run, nothing confiscated: the pick can be taken up", not st.firearms_confiscated and st.can_select(Ep2ArmoryState.PICK) and st.select(Ep2ArmoryState.PICK)
		and st.equipped == Ep2ArmoryState.PICK)
	check("it is not a ninth gun: IDS is still the eight firearms and nothing was bought", not Ep2ArmoryState.IDS.has(Ep2ArmoryState.PICK) and not st.owns(Ep2ArmoryState.PICK))
	check("the guns stay owned, loaded and un-held", st.owns(Ep2ArmoryState.WIN) and st.owns(Ep2ArmoryState.REM) and not st.is_held(Ep2ArmoryState.WIN)
		and st.firearm(Ep2ArmoryState.WIN).rounds == rifle_rounds and not st.firearms_confiscated)
	st.step(Ep2ArmoryState.SWITCH_TIME + 0.05)
	check("the pick is ready to swing once the switch is done", st.ready())
	check("Q (previous) takes the rifle back, and Q again the pick", st.select_previous() and st.equipped == Ep2ArmoryState.WIN and st.select_previous() and st.equipped == Ep2ArmoryState.PICK)
	check("a gun key takes any owned gun back", st.select(Ep2ArmoryState.REM) and st.equipped == Ep2ArmoryState.REM)
	st.select(Ep2ArmoryState.PICK)
	var copy: Ep2ArmoryState = st.detached_copy()
	check("the pick stays up through a room hand-over and a save, with the gun to return to remembered", copy.equipped == Ep2ArmoryState.PICK and copy.previous == Ep2ArmoryState.REM
		and copy.owns(Ep2ArmoryState.WIN) and not copy.firearms_confiscated)
	check("the pick has its own key (9) beside the eight gun keys", InputMap.has_action(Ep2ArmoryState.PICK_ACTION) or Ep2ArmoryState.ACTIONS.has(Ep2ArmoryState.PICK_ACTION))
	# the first-person view: visible in his hands, a swing counts and lands once, and the rifle fires again afterwards
	var cam := Camera3D.new()
	add_child(cam)
	var vm := Ep2Viewmodel.new()
	add_child(vm)
	var st2 := Ep2ArmoryState.post_hideout()
	vm.bind_armory(st2)
	vm.attach(cam)
	st2.select(Ep2ArmoryState.PICK)
	var landed := [0]
	vm.pickaxe_landed.connect(func() -> void: landed[0] += 1)
	for i in 20:
		vm.step(1.0 / 60.0, false, false, 0.0)
	var view: Node3D = vm.rifle
	check("the pick view is in his hands and shown (not the rifle, not hidden)", view != null and view.name == "PickaxeViewmodel" and view.visible and view.get_parent() == cam)
	check("it is the founder's War Pick in his glove with a sleeve running out of frame (streamed pack mounted)", view.has_meta("held")
		and view.find_child("PickaxeHeld", true, false) != null and view.find_child("ArmSleeve", true, false) != null)
	var s: Vector3 = view.global_transform.basis.get_scale()
	check("sane size on screen (0.5 - 1.2 of the model)", s.x > 0.5 and s.x < 1.2 and absf(s.x - s.y) < 0.01, str(s))
	var rounds_before: int = st2.firearm(Ep2ArmoryState.WIN).rounds
	check("fire swings it: the swing counts and costs no round", vm.fire() and vm.pickaxe_swings == 1 and st2.firearm(Ep2ArmoryState.WIN).rounds == rounds_before)
	check("a second press mid-swing does nothing", not vm.fire() and vm.pickaxe_swings == 1)
	for i in 40:
		vm.step(1.0 / 60.0, false, false, 0.0)
	check("the swing lands exactly once", landed[0] == 1, str(landed[0]))
	check("and it swings again when the first is done", vm.fire() and vm.pickaxe_swings == 2)
	for i in 40:
		vm.step(1.0 / 60.0, false, false, 0.0)
	st2.select(Ep2ArmoryState.WIN)
	for i in 30:
		vm.step(1.0 / 60.0, false, false, 0.0)
	check("back on the rifle it fires a round as before", vm.rifle.name == "Viewmodel" and vm.fire() and st2.firearm(Ep2ArmoryState.WIN).rounds == rounds_before - 1)
	vm.queue_free()
	cam.queue_free()
	# Tabs: his own tile, never a gun card
	var sel := _selector_for(st)
	await _frames()
	check("Tabs has a pickaxe tile of its own; the gun cards are still only his guns", sel.pick_card != null and sel.pick_card.visible
		and sel.shown_ids() == [Ep2ArmoryState.WIN, Ep2ArmoryState.REM] and sel.cards.size() == Ep2ArmoryState.IDS.size(), str(sel.shown_ids()))
	check("the tile is on screen and clear of every gun card", Rect2(Vector2.ZERO, sel.size).encloses(sel.pick_rect())
		and not sel.pick_rect().intersects(sel.card_rect(0)) and not sel.pick_rect().intersects(sel.card_rect(3)), str(sel.pick_rect()))
	st.select(Ep2ArmoryState.WIN)
	sel.point_at(sel.pick_card.get_global_rect().get_center())
	check("pointing at it previews the pick (release equips it)", sel.highlighted == Ep2ArmoryState.PICK and st.can_select(sel.highlighted))
	await _frames()
	check("it is named on the tile where keys are shown", " ".join(sel.drawn_text).contains("PICKAXE"))
	sel.queue_free()
	await _frames(1)


## The swing is a real melee hit in the real woods: arm's length only, no round spent, and the rifle still his.
func _test_pickaxe_melee() -> void:
	print("-- A PICKAXE SWING HITS WHAT IS IN REACH (real woods room, a real bear)")
	var w: WoodsQuadChamber = (load("res://src/episode2/chamber/woods_quad.tscn") as PackedScene).instantiate() as WoodsQuadChamber
	add_child(w)
	w.setup(0, [], 0)
	await get_tree().process_frame
	var br: Ep2BearBrain = w.get_bear("Twitch")
	check("the woods has its scout bear", br != null)
	if br == null:
		w.queue_free()
		return
	br.actor.stop()
	Ep2BearKit.pose(br.actor, "idle")
	br.actor.visible = true
	br.hp = 1
	w._player_pos = Vector3.ZERO
	check("in the woods the pick is taken up like any weapon (no jail needed)", w.select_weapon(Ep2ArmoryState.PICK) and w.armory.equipped == Ep2ArmoryState.PICK)
	var rounds: int = w.armory.firearm(Ep2ArmoryState.WIN).rounds
	var swing := func(distance: float) -> bool:
		br.actor.position = Vector3(0.0, 0.0, distance)
		var swung: bool = false
		for i in 50:
			var eye: Vector3 = w._player_pos + Vector3(0.0, w.eye_height, 0.0)
			var t: Vector3 = br.actor.position + Vector3(0.0, br.actor.height_m * 0.55, 0.0) - eye
			w._look_yaw = atan2(t.x, t.z)
			w._look_pitch = atan2(t.y, Vector2(t.x, t.z).length())
			if i == 12:
				swung = w.shoot()
			w.step(1.0 / 60.0)
			br.actor.position = Vector3(0.0, 0.0, distance)      # hold him there: this is about reach, not his charge
		return swung
	var far: bool = swing.call(9.0)
	check("a swing at a bear 9 m away swings and does not touch him", far and not br.is_dead() and br.hp == 1, "swung %s hp %d" % [far, br.hp])
	var near: bool = swing.call(1.9)
	check("a swing at a bear within reach lands: he is down, the kill is Lil Blunt's", near and br.is_dead() and str(br.get_meta("killed_by", "")) == "player",
		"swung %s dead %s" % [near, br.is_dead()])
	check("no round was spent and the rifle is still his", w.armory.firearm(Ep2ArmoryState.WIN).rounds == rounds and w.armory.owns(Ep2ArmoryState.WIN)
		and w.select_weapon(Ep2ArmoryState.WIN))
	w.queue_free()
	await _frames(1)


func _test_shop_order() -> void:
	print("-- RICH & UTAH'S COUNTER, TOP TO BOTTOM")
	var ids: Array = []
	for row in Ep2ArmoryState.SHOP:
		ids.append(str(row["id"]))
	var sorted_ids: Array = ids.duplicate()
	sorted_ids.sort()
	var pinned: Array = ROW_IDS.duplicate()
	pinned.sort()
	check("every row and save id is unchanged (only the order moved)", sorted_ids == pinned, str(ids))
	check("first THE SHIPMENT", ids[0] == "river_gear" and str(Ep2ArmoryState.SHOP[0]["name"]) == "THE SHIPMENT")
	check("second the BUFFALO GUN (the Sharps)", ids[1] == "sniper" and str(Ep2ArmoryState.SHOP[1]["name"]) == "BUFFALO GUN")
	check("third its SHARPS CARTRIDGES", ids[2] == "sniper_ammo" and str(Ep2ArmoryState.SHOP[2]["name"]) == "SHARPS CARTRIDGES")
	var gun_order: Array = []
	var paired: bool = true
	for i in ids.size():
		if Ep2ArmoryState.SHOP_GUNS.has(ids[i]):
			gun_order.append(ids[i])
			var next: String = ids[i + 1] if i + 1 < ids.size() else ""
			paired = paired and Ep2ArmoryState.SHOP_AMMO.get(next, "") == ids[i]
	check("then each gun with its own ammunition right under it", paired, str(ids))
	check("the guns in the order the story puts them in his hands", gun_order == STORY_GUNS, str(gun_order))
	var opener_first: bool = true
	for id in Ep2ArmoryState.SHOP_GUNS:
		opener_first = opener_first and ids.find("sniper") < ids.find(id)
	check("the Sharps, which opens the other guns, sits above every gun it opens", opener_first)


func _test_lock_chain() -> void:
	print("-- THE CHAIN STILL HOLDS")
	var st := Ep2ArmoryState.post_hideout()
	var shut: bool = true
	for row in Ep2ArmoryState.SHOP:
		if str(row["id"]) != Ep2ArmoryState.GATE_ITEM:
			shut = shut and Ep2ArmoryState.lock_note(st, str(row["id"])) == "SHIPMENT FIRST"
	check("before the Shipment every other row says SHIPMENT FIRST", shut)
	st.purchase_river_gear("btc")
	check("after it the Sharps is open", Ep2ArmoryState.unlocks_stock(st, "sniper"))
	var waiting: bool = true
	for id in Ep2ArmoryState.SHOP_GUNS:
		if not st.owns(id):
			waiting = waiting and Ep2ArmoryState.lock_note(st, id) == "SHARPS FIRST"
	check("every gun he does not own waits for the Sharps", waiting)
	check("ammunition for the gun he carries stays on sale", Ep2ArmoryState.unlocks_stock(st, "rifle_ammo"))
	st.purchase_sniper("btc")
	var open: bool = true
	for row in Ep2ArmoryState.SHOP:
		open = open and Ep2ArmoryState.unlocks_stock(st, str(row["id"]))
	check("with the Sharps every row is open", open)


## Founder 2026-11-07: "improve the way Rich takes it out the glass so that it's not tacky". Headless through the real chamber: the logic that
## makes it believable (the frames are in docs/episode2-quality/weapon-tabs-2026-11-07/takeout).
func _test_case_takeout() -> void:
	print("-- RICH TAKES THE SHARPS OUT OF THE CASE, AND PUTS IT BACK")
	var c: GoldTownChamber = TOWN.instantiate()
	add_child(c)
	c.setup(0, [], 0)
	await get_tree().process_frame
	var case: Ep2SharpsCase = c._case
	check("the case has its own lid and one rifle (the scoped showcase Sharps), and the kit rifle is put away", case != null and case.lid != null and case.rifle != null
		and c._sharps_case == case.rifle and not (c._visuals.find_child("Arm2_Sharps_Bldg_Armory", true, false) as Node3D).visible)
	if case == null:
		c.queue_free()
		return
	var held_scene: String = (POSE.make_rifle().get_child(0) as Node).scene_file_path
	check("the rifle in the case is the model he holds", (case.rifle.get_child(0) as Node).scene_file_path == held_scene and held_scene != "")
	var intro: Ep2ArmoryIntro = c.get_intro()
	c._player_pos = Ep2GoldTown.local_to_world("Bldg_Armory", GoldTownChamber.ARMORY_SPOT)
	c._advance_to(GoldTownChamber.Beat.ARMORY)
	for i in 60 * 60:
		if intro.stage == Ep2ArmoryIntro.Stage.SHARPS_REACH:
			break
		c.step(1.0 / 60.0)
	var rest: Vector3 = case.rest_point()
	var stand: Vector3 = c.get_rich().global_position
	check("he walks to the case first and stands within arm's reach of the grip", intro.stage == Ep2ArmoryIntro.Stage.SHARPS_REACH
		and Vector2(stand.x - rest.x, stand.z - rest.z).length() < 0.65, "%.2f m" % Vector2(stand.x - rest.x, stand.z - rest.z).length())
	var through_glass: int = 0
	var hand_off: int = 0
	var moved: int = 0
	var lid_peak: float = 0.0
	var at_chest: float = INF
	var ik: Ep2ArmIK = case._ik.get("Right")
	for i in 60 * 120:                                     # the reach, every line he says, the put-back
		if intro.stage == Ep2ArmoryIntro.Stage.GATLING_WALK:
			break
		var was_free: bool = case.rifle.visible
		var before: Transform3D = case.rifle.global_transform
		c.step(1.0 / 60.0)
		lid_peak = maxf(lid_peak, case.lid_angle)
		if case.rifle.visible and case.rifle.global_position.distance_to(rest) > 0.01:
			moved += 1
			if case.lid_angle < Ep2SharpsCase.LID_OPEN * 0.9:
				through_glass += 1
			var grip: Vector3 = case.rifle.global_transform * POSE.wrist_on_rifle("Right")
			if ik == null or ik.influence < 0.99 or ik.target_world.distance_to(grip) > 0.001:
				hand_off += 1
		if was_free and not case.rifle.visible and intro.stage == Ep2ArmoryIntro.Stage.SHARPS_REACH:
			at_chest = before.origin.distance_to(case._chest().origin)
	check("the lid opens (about 75 degrees) before the rifle comes out", lid_peak >= Ep2SharpsCase.LID_OPEN * 0.99, "%.2f" % lid_peak)
	check("the rifle travels (it is never swapped between frames)", moved > 60, str(moved))
	check("it never moves while the lid is shut: nothing passes through the glass", through_glass == 0, str(through_glass))
	check("whenever it moves his right hand is solved onto its grip", hand_off == 0, str(hand_off))
	check("it goes onto his hand bone only once it is at his chest, where the held clips grip it", at_chest < 0.001, str(at_chest))
	check("put back: home on the felt, the lid shut, his arms his own again", intro.stage == Ep2ArmoryIntro.Stage.GATLING_WALK and case.rifle.visible
		and case.rifle.global_position.distance_to(rest) < 0.001 and case.lid_angle == 0.0 and ik != null and ik.influence == 0.0 and c.get_rich().held_prop("Sharps") == null,
		"stage %d visible %s off %.3f lid %.2f ik %.2f" % [intro.stage, case.rifle.visible, case.rifle.global_position.distance_to(rest), case.lid_angle, ik.influence if ik != null else -1.0])
	c.queue_free()
	await get_tree().process_frame
