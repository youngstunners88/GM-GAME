extends Node2D
## Session-7 gates, each written to FAIL on the pre-fix code:
##   T1  Every vault Label is big + black-outlined (font >= 24, outline >= 4).
##       Pre-fix: outline_size 0 everywhere, several labels 13-20px.
##   T2  The Diamond Vault clerk exposes OBVIOUS LARGE BUTTONS — a CONFIRM Button
##       >= 88px tall — and the flow moves real balances. Pre-fix: no Button
##       nodes (text-only panel).
##   T3a S2 boss diamond volley travels across the arena (>= 1200px) before it
##       despawns. Pre-fix: 170px/s * 4s = 680px, short of the arena.
##   T3b S2 boss tracks a WEAVING player (the real "not chasing" case): average
##       horizontal gap over the last 4s stays tight. Pre-fix: HOVER_ACCEL 430
##       makes him oscillate overhead (avg gap wide).
##   T4  Lil Blunt's visual is scaled up (>1.0) while his feet stay on the floor
##       (<= 2px) and his collision box is unchanged.
##
## Run: godot --headless res://tests/s7_readable_ui_range_test.tscn

const DIAMOND_VAULT := preload("res://src/level/diamond_vault_realm.tscn")
const FORT_KNOX := preload("res://src/level/fort_knox_realm.tscn")
const DISTRIBUTOR := preload("res://src/boss/distributor.tscn")
const PLAYER := preload("res://src/player/player.tscn")

var _fail: int = 0

func _ready() -> void:
	await get_tree().process_frame
	print("SESSION 7 READABLE UI + RANGE + CHASE:")
	await _test_vault_text_is_big_and_outlined()
	await _test_clerk_has_big_confirm_button()
	await _test_s2_diamond_volley_crosses_arena()
	await _test_s2_boss_tracks_a_weaving_player()
	await _test_lil_blunt_scaled_up_feet_anchored()
	print("S7_READABLE_UI_RANGE: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _info(label: String, value: Variant) -> void:
	print("  [INFO] %s: %s" % [label, str(value)])

func _collect(n: Node, acc: Array) -> void:
	if n is Label or n is Button:
		acc.append(n)
	for ch in n.get_children():
		_collect(ch, acc)

## T1 — readability proxy across every vault Label (Kimi K3 s7).
func _test_vault_text_is_big_and_outlined() -> void:
	for scene in [DIAMOND_VAULT, FORT_KNOX]:
		var realm: Node = scene.instantiate()
		add_child(realm)
		await get_tree().process_frame
		# Open the clerk too (diamonds) so its labels/buttons are in the tree.
		if realm.get("_diamonds"):
			realm.call("clerk_open")
			await get_tree().process_frame
		var ctrls: Array = []
		_collect(realm, ctrls)
		var labels := ctrls.filter(func(c: Control) -> bool: return c is Label)
		_check("vault scene exposes readable labels (found %d)" % labels.size(), labels.size() >= 4)
		var bad := ""
		var worst := 999
		for c: Control in labels:
			var fs: int = c.get_theme_font_size("font_size")
			var osz: int = c.get_theme_constant("outline_size")
			worst = mini(worst, fs)
			if fs < 24 or osz < 4:
				bad = "'%s' font=%d outline=%d" % [(c as Label).text.substr(0, 16), fs, osz]
				break
		_check("every %s label is >= 24px with a >= 4px outline" % ("Diamond Vault" if realm.get("_diamonds") else "Fort Knox"),
			bad == "", "%s (smallest seen %d)" % [bad, worst])
		realm.queue_free()
		await get_tree().process_frame

## T2 — the clerk is a big-button panel now, not a tiny text adjuster.
func _test_clerk_has_big_confirm_button() -> void:
	GoldMineSystem.reset_session()
	GoldMineSystem.diamonds_balance = 50
	GoldMineSystem.add_blaze_diamonds(6)
	var realm: Node = DIAMOND_VAULT.instantiate()
	add_child(realm)
	await get_tree().process_frame
	realm.call("clerk_open")
	await get_tree().process_frame
	var ctrls: Array = []
	_collect(realm, ctrls)
	var confirm: Button = null
	var big_buttons := 0
	for c in ctrls:
		if c is Button:
			if (c as Button).custom_minimum_size.y >= 88.0:
				big_buttons += 1
			if (c as Button).name == "CONFIRM" or (c as Button).text == "CONFIRM":
				confirm = c
	_check("clerk panel has a CONFIRM button", confirm != null,
		"no CONFIRM Button — the clerk is still a tiny text panel")
	_check("clerk panel has large (>=88px) tap targets", big_buttons >= 1,
		"%d big buttons" % big_buttons)
	# Pressing CONFIRM applies the flow through GoldMineSystem.
	var shares_before: int = GoldMineSystem.diamond_shares
	if confirm != null:
		confirm.emit_signal("pressed")
	_check("pressing CONFIRM stakes + crushes through the real economy",
		GoldMineSystem.diamond_shares > shares_before and GoldMineSystem.blaze_diamonds == 0,
		"shares %d->%d, blaze=%d" % [shares_before, GoldMineSystem.diamond_shares, GoldMineSystem.blaze_diamonds])
	realm.queue_free()
	GoldMineSystem.reset_session()
	await get_tree().process_frame

## T3a — the diamond volley reaches across the arena before it despawns.
func _test_s2_diamond_volley_crosses_arena() -> void:
	get_tree().call_group("boss_projectile", "queue_free")
	await get_tree().physics_frame
	var boss: Node2D = DISTRIBUTOR.instantiate()
	add_child(boss)
	boss.global_position = Vector2(0, 0)
	var hb := boss.get_node("Hitbox") as Area2D
	hb.monitoring = false
	boss.set("current_phase", 1)
	# Aim straight down the +x axis: no player -> base dir is DOWN, so give it a
	# player far to the east to force a horizontal shot we can measure.
	var target := _stub_player(Vector2(1300, 0))
	await get_tree().physics_frame
	boss.call("_throw_shards")
	await get_tree().physics_frame
	var vid: int = int(boss.get("_volley_id"))
	var orb: Node = null
	for c in get_children():
		if c.is_in_group("boss_projectile") and int(c.get("volley_id")) == vid:
			orb = c
			break
	_check("diamond volley spawns", orb != null)
	var reached := 0.0
	if orb != null:
		var start_x: float = orb.global_position.x
		for i in range(540):  # up to 9s — the diamond now lives 8s
			await get_tree().physics_frame
			if not is_instance_valid(orb):
				break
			reached = maxf(reached, orb.global_position.x - start_x)
			if reached >= 1300.0:
				break
	_info("diamond travelled", "%.0fpx" % reached)
	_check("a phase-1 diamond travels >= 1200px across the arena (was 680px)",
		reached >= 1200.0,
		"only reached %.0fpx before despawn — can't reach a far player" % reached)
	get_tree().call_group("boss_projectile", "queue_free")
	boss.queue_free(); target.queue_free()
	await get_tree().process_frame

## T3b — REVERSAL RESPONSE, the real "not chasing" cause Kimi K3 found: at the
## old HOVER_ACCEL (430) the boss took ~1.6s of near-zero horizontal velocity to
## reverse direction, so against a juking player he oscillated overhead with
## ~zero average closing. This measures the thing that actually changed:
## after the player hard-reverses, how long until the boss's horizontal velocity
## follows? A confounded "average gap" metric can't tell a tracking boss from a
## boss frozen at x=0 (both sit near the player's mean position), so we measure
## the boss's own velocity response instead.
func _test_s2_boss_tracks_a_weaving_player() -> void:
	var boss: Node2D = DISTRIBUTOR.instantiate()
	add_child(boss)
	boss.set("arena_min", Vector2(-2000, -400))
	boss.set("arena_max", Vector2(2000, 400))
	boss.global_position = Vector2(0, 0)
	var hb := boss.get_node("Hitbox") as Area2D
	hb.monitoring = false
	var player := _stub_player(Vector2(600, 220))
	await get_tree().physics_frame
	# Phase 1: player far to the +x for 2.5s so the boss builds up +x velocity.
	for i in range(150):
		player.global_position = Vector2(600, 220)
		await get_tree().physics_frame
	var vx_before: float = (boss.get("velocity") as Vector2).x
	# Phase 2: player HARD-reverses to the far -x. Time how long the boss's
	# velocity.x stays positive (coasting the wrong way) before it turns around.
	var frames_wrong: int = 0
	for i in range(120):  # up to 2s
		player.global_position = Vector2(-600, 220)
		await get_tree().physics_frame
		if (boss.get("velocity") as Vector2).x > 0.0:
			frames_wrong += 1
		else:
			break
	var reverse_time: float = frames_wrong / 60.0
	_info("boss +x velocity before reversal", "%.0f" % vx_before)
	_info("boss reversal response time", "%.2fs" % reverse_time)
	_check("S2 boss was actually pursuing (+x velocity built up before reversal)",
		vx_before > 100.0, "vx=%.0f — boss wasn't moving toward the player at all" % vx_before)
	# Post-fix (accel 1600): ~0.22s to cross zero. Pre-fix (accel 430): ~0.8s+.
	_check("S2 boss reverses to chase a juking player quickly (<= 0.5s, was ~1.6s)",
		reverse_time <= 0.5,
		"took %.2fs to turn around — oscillates overhead instead of chasing (HOVER_ACCEL too low)" % reverse_time)
	boss.queue_free(); player.queue_free()
	await get_tree().process_frame

## T4 — the player render scale is applied, feet stay anchored, collision same.
func _test_lil_blunt_scaled_up_feet_anchored() -> void:
	var player: Node = PLAYER.instantiate()
	add_child(player)
	await get_tree().process_frame
	var visual: Node = player.get_node("Visual")
	var spr: Sprite2D = null
	for c in visual.get_children():
		if c is Sprite2D:
			spr = c
			break
	_check("player visual sprite exists", spr != null)
	if spr != null:
		_check("Lil Blunt is scaled up (render scale > 1.0)",
			spr.scale.x > 1.0, "scale.x=%.2f — still miniature" % spr.scale.x)
		# Feet anchor: the opaque bottom of the scaled sprite should sit at the
		# collision floor (FEET_LOCAL_Y = 16 in the Visual's local space).
		var tex: Texture2D = spr.texture
		var img := tex.get_image()
		var used := img.get_used_rect()
		var h := float(tex.get_height())
		var feet_local: float = spr.position.y - h * spr.scale.y / 2.0 + float(used.position.y + used.size.y) * spr.scale.y
		_info("scaled feet local-y (target 16)", "%.1f" % feet_local)
		_check("scaled sprite's feet stay anchored to the floor (<= 2px drift)",
			absf(feet_local - 16.0) <= 2.0,
			"feet at %.1f, expected ~16 — he would hover/sink" % feet_local)
	# Collision box unchanged (32px square on the Player).
	var col: CollisionShape2D = player.get_node("CollisionShape2D")
	var shape := col.shape as RectangleShape2D
	_check("player collision box is unchanged by the visual scale-up",
		shape != null and is_equal_approx(shape.size.x, 32.0) and is_equal_approx(shape.size.y, 32.0),
		"collision size=%s (expected 32x32)" % (str(shape.size) if shape else "null"))
	player.queue_free()
	await get_tree().process_frame

func _stub_player(at: Vector2) -> CharacterBody2D:
	var stub := GDScript.new()
	stub.source_code = "extends CharacterBody2D\nfunc take_damage(_a: int) -> void:\n\tpass\n"
	stub.reload()
	var p := CharacterBody2D.new()
	p.set_script(stub)
	p.collision_layer = 2
	p.collision_mask = 0
	p.add_to_group("player")
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(32, 48)
	cs.shape = r
	p.add_child(cs)
	p.global_position = at
	add_child(p)
	return p
