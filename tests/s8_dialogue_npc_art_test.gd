extends Node2D
## Session-8 gates for the vault dialogue / NPC / art work, each written to FAIL
## on the pre-fix code:
##   T1a SteppedDialogue reveals ONE line per advance (no instant dump), clamps
##       at the last line, and leave() returns the farewell + resets.
##   T1b Mira stands on the floor (clerk node at FLOOR_Y, sprite bottom-anchored).
##   T1c/T6 clerk_open shows a single dialogue line first; the stake/crush/confirm
##       action controls stay HIDDEN until the dialogue reaches its last line.
##   T5  Gideon "Goldwater" Vale exists in Fort Knox with a stepped dialogue, and
##       the Assay Hall has golden highlighted platforms.
##   T4  Both realms show a founder emblem centerpiece (vault_emblem group) that
##       actually renders; the 2888-day primary pool plate is distinct/larger.
##
## Run: godot --headless res://tests/s8_dialogue_npc_art_test.tscn

const DIAMOND_VAULT := preload("res://src/level/diamond_vault_realm.tscn")
const FORT_KNOX := preload("res://src/level/fort_knox_realm.tscn")
const VAULT := preload("res://src/level/vault_realm.gd")

var _fail: int = 0

func _ready() -> void:
	await get_tree().process_frame
	print("SESSION 8 DIALOGUE / NPC / ART:")
	_test_stepped_dialogue_logic()
	await _test_mira_on_floor_and_stepped_panel()
	await _test_gideon_and_golden_platforms()
	await _test_emblems_render_and_primary_pool()
	print("S8_DIALOGUE_NPC_ART: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _collect(n: Node, want: String, acc: Array) -> void:
	if (want == "Label" and n is Label) or (want == "Button" and n is Button) or (want == "Sprite2D" and n is Sprite2D):
		acc.append(n)
	for c in n.get_children():
		_collect(c, want, acc)

## T1a — the reusable stepped-dialogue class, UI-free.
func _test_stepped_dialogue_logic() -> void:
	var d = VAULT.SteppedDialogue.new()
	d.lines = ["one", "two", "three"]
	d.farewell = "bye"
	_check("fresh dialogue has not started (idx -1)", d.idx == -1 and not d.started())
	_check("advance reveals ONE line at a time", d.advance() == "one" and d.idx == 0)
	_check("second advance -> next line", d.advance() == "two")
	_check("third advance -> last line, at_end true", d.advance() == "three" and d.at_end())
	_check("advancing past the end clamps (no dump)", d.advance() == "three" and d.idx == 2)
	_check("leave() returns the farewell and resets", d.leave() == "bye" and d.idx == -1)

## T1b/T1c/T6 — Mira on the floor; clerk_open steps, actions gated on dialogue end.
func _test_mira_on_floor_and_stepped_panel() -> void:
	GoldMineSystem.reset_session()
	GoldMineSystem.diamonds_balance = 40
	var realm: Node = DIAMOND_VAULT.instantiate()
	add_child(realm)
	await get_tree().process_frame
	var clerk := realm.get_node_or_null("VaultClerk")
	_check("Diamond Vault has Mira (VaultClerk)", clerk != null)
	if clerk != null:
		var floor_y: float = realm.get("FLOOR_Y")
		_check("Mira stands on the floor (clerk node at FLOOR_Y, not floating)",
			absf(clerk.position.y - floor_y) <= 1.0,
			"clerk.y=%.1f vs FLOOR_Y=%.1f" % [clerk.position.y, floor_y])
	# Open the clerk: one dialogue line shown, action controls hidden.
	realm.call("clerk_open")
	await get_tree().process_frame
	var actions: Array = realm.get("_clerk_actions")
	var visible_actions := 0
	for c in actions:
		if is_instance_valid(c) and c.visible:
			visible_actions += 1
	_check("on open, the stake/crush/confirm controls are HIDDEN (no instant dump)",
		visible_actions == 0, "%d action controls visible before dialogue ended" % visible_actions)
	# Step through the dialogue; after the last line the actions appear.
	for i in range(6):
		realm.call("_clerk_advance_dialogue")
	var visible_after := 0
	for c in actions:
		if is_instance_valid(c) and c.visible:
			visible_after += 1
	_check("after stepping to the last line, the action controls appear",
		visible_after >= 1, "actions still hidden after stepping through dialogue")
	realm.queue_free()
	GoldMineSystem.reset_session()
	await get_tree().process_frame

## T5 — Gideon in Fort Knox + golden highlighted platforms.
func _test_gideon_and_golden_platforms() -> void:
	var realm: Node = FORT_KNOX.instantiate()
	add_child(realm)
	await get_tree().process_frame
	var gideon := realm.get_node_or_null("GideonVale")
	_check("Fort Knox has Gideon Vale NPC", gideon != null)
	if gideon != null:
		var floor_y: float = realm.get("FLOOR_Y")
		_check("Gideon stands on the floor", absf(gideon.position.y - floor_y) <= 1.0,
			"gideon.y=%.1f vs FLOOR_Y=%.1f" % [gideon.position.y, floor_y])
	# Gideon dialogue steps one line at a time.
	realm.call("gideon_open")
	await get_tree().process_frame
	var g_open: bool = realm.get("_gideon_open")
	_check("Gideon dialogue opens (stepped)", g_open)
	# S10 T3 — a SECOND E on the last line must CLOSE (no dead input). Step past
	# the last line, then one more step should dismiss the dialogue.
	for _i in range(8):
		realm.call("gideon_step")
	await get_tree().process_frame
	var g_open_after: bool = realm.get("_gideon_open")
	_check("Gideon's terminal E closes the dialogue (no dead input)",
		not g_open_after, "dialogue still open after stepping past the last line")
	var golden := get_tree().get_nodes_in_group("golden_platform")
	_check("Fort Knox has golden highlighted platforms", golden.size() >= 1,
		"%d golden platforms" % golden.size())
	realm.queue_free()
	await get_tree().process_frame

## S10 T1/T2 — each realm shows a Security Sentinel that (a) renders, (b) is
## SMALLER than the old oversized 300px emblem, and (c) the Diamond Vault shows
## NO gold-scale "golden machine". Plus the primary-pool plate stays distinct.
func _test_emblems_render_and_primary_pool() -> void:
	for scene in [DIAMOND_VAULT, FORT_KNOX]:
		var realm: Node = scene.instantiate()
		add_child(realm)
		await get_tree().process_frame
		var diamonds: bool = realm.get("_diamonds")
		var realm_name := "Diamond Vault" if diamonds else "Fort Knox"
		var sentinel_h: float = realm.get("SENTINEL_H")
		# The Security Sentinel node (vault_sentinel group) renders the founder art.
		var sentinels := get_tree().get_nodes_in_group("vault_sentinel")
		var rendered := false
		var rendered_h := 0.0
		for e in sentinels:
			var sprs: Array = []
			_collect(e, "Sprite2D", sprs)
			for s in sprs:
				if s.texture != null and s.texture.resource_path.findn("sentinel") != -1:
					rendered = true
					rendered_h = float(s.texture.get_height()) * s.scale.y
		_check("%s shows a Security Sentinel that renders (founder art)" % realm_name,
			rendered, "no sentinel-textured sprite found")
		# Smaller than the oversized 300px emblem it replaced, still clearly visible.
		_check("%s Security Sentinel is smaller than the old oversized 300px prop" % realm_name,
			rendered and rendered_h < 300.0 and rendered_h >= 80.0,
			"rendered height %.0fpx (SENTINEL_H=%.0f) not in [80,300)" % [rendered_h, sentinel_h])
		# S10 T1 — no gold-machine (gold_scale) texture in the DIAMOND vault.
		if diamonds:
			var all_sprs: Array = []
			_collect(realm, "Sprite2D", all_sprs)
			var has_gold_machine := false
			for s in all_sprs:
				if s.texture != null and s.texture.resource_path.findn("gold_scale") != -1:
					has_gold_machine = true
			_check("Diamond Vault has NO gold-scale machine (removed per founder)",
				not has_gold_machine, "a gold_scale sprite is still present in the Diamond Vault")
		# The primary (2888-day) pool plate is larger + star-marked.
		var labels: Array = []
		_collect(realm, "Label", labels)
		var primary_plate := false
		for l in labels:
			if l.text.findn("PRIMARY") != -1 and l.get_theme_font_size("font_size") >= 30:
				primary_plate = true
		_check("%s primary 2888-day pool plate is distinct + larger" % realm_name,
			primary_plate, "no large PRIMARY pool plate")
		realm.queue_free()
		get_tree().call_group("vault_sentinel", "queue_free")
		await get_tree().process_frame
