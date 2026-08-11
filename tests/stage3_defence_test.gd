extends Node2D
## Stage 3 defence-of-the-realm gates.
##
## Founder: "There is a massive glistch with the final boss as he is fucking
## dumb and dies by falling off the ledge. The gnome characters also are
## stupid and fall off ledges automatically... The boss falls off the ledge and
## then Lil Blunt is unable to deal with him so the game cannot proceed."
##
## Both are measured under REAL physics on a REAL platform with a REAL void
## beside it — not by reading the AI code.

const CLAIM_JUMPER := preload("res://src/boss/claim_jumper.tscn")
const TAX_COLLECTOR := preload("res://src/enemies/tax_collector.tscn")

var _fail: int = 0

func _ready() -> void:
	await get_tree().process_frame
	print("STAGE 3 DEFENCE:")
	await _test_boss_does_not_walk_off_a_ledge()
	await _test_boss_arena_clamp_catches_a_fall()
	await _test_gnome_does_not_walk_off_a_ledge()
	_test_big_axe_survives_another_powerup()
	await _test_snakes_spit_venom()
	await _test_gnomes_fire_arrows()
	await _test_stage2_boss_outruns_a_sprinting_player()
	await _test_stage2_boss_chases_inside_the_real_arena()
	await _test_stage3_boss_chases_inside_the_real_arena()
	await _test_gnome_arrow_is_an_arrow_not_an_orb()
	_test_no_two_powerups_look_identical()
	print("STAGE3_DEFENCE: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

## A single platform ending at `edge_x`, with nothing beyond it.
func _make_ledge(edge_x: float, y: float) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(1200, 80)
	cs.shape = rect
	cs.position = Vector2(edge_x - 600.0, y + 40.0)
	body.add_child(cs)
	add_child(body)
	return body

func _make_player(at: Vector2) -> CharacterBody2D:
	var p := CharacterBody2D.new()
	p.collision_layer = 2
	p.collision_mask = 0
	p.add_to_group("player")
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(32, 32)
	cs.shape = r
	cs.position = Vector2(16, 16)
	p.add_child(cs)
	p.global_position = at
	add_child(p)
	return p

func _test_boss_does_not_walk_off_a_ledge() -> void:
	var edge_x := 1000.0
	var floor_y := 600.0
	var ledge := _make_ledge(edge_x, floor_y)
	# Player parked in the VOID past the edge — maximum temptation to walk off.
	var player := _make_player(Vector2(edge_x + 400.0, floor_y - 40.0))
	var boss: Node2D = CLAIM_JUMPER.instantiate()
	add_child(boss)
	boss.global_position = Vector2(edge_x - 300.0, floor_y - 80.0)
	for i in 240:
		await get_tree().physics_frame

	_check("boss did not fall into the void chasing a player across a gap",
		boss.global_position.y < floor_y + 200.0,
		"boss y = %.0f (floor %.0f)" % [boss.global_position.y, floor_y])
	_check("boss is still alive and fightable",
		is_instance_valid(boss) and not bool(boss.get("is_dead")))

	boss.queue_free(); player.queue_free(); ledge.queue_free()
	await get_tree().physics_frame

func _test_boss_arena_clamp_catches_a_fall() -> void:
	# No floor at all: only the arena clamp can save him.
	var boss: Node2D = CLAIM_JUMPER.instantiate()
	add_child(boss)
	boss.global_position = Vector2(4050, 500)
	boss.set("arena_min", Vector2(3790, 100))
	boss.set("arena_max", Vector2(4310, 560))
	for i in 180:
		await get_tree().physics_frame
	_check("arena clamp stops the boss falling out of the world with no floor",
		boss.global_position.y <= 561.0,
		"boss y = %.0f, clamp max 560" % boss.global_position.y)
	_check("arena clamp keeps the boss inside the arena horizontally",
		boss.global_position.x >= 3789.0 and boss.global_position.x <= 4311.0,
		"boss x = %.0f" % boss.global_position.x)
	boss.queue_free()
	await get_tree().physics_frame

func _test_gnome_does_not_walk_off_a_ledge() -> void:
	var edge_x := 1000.0
	var floor_y := 600.0
	var ledge := _make_ledge(edge_x, floor_y)
	var gnome: Node2D = TAX_COLLECTOR.instantiate()
	add_child(gnome)
	# Patrolling toward the edge with no player anywhere near.
	gnome.global_position = Vector2(edge_x - 200.0, floor_y - 32.0)
	await get_tree().physics_frame
	gnome.set("patrol_distance", 4000.0)
	gnome.set("moving_right", true)
	for i in 300:
		await get_tree().physics_frame
	_check("gnome patrol turns at the ledge instead of walking into the void",
		gnome.global_position.y < floor_y + 200.0,
		"gnome y = %.0f (floor %.0f)" % [gnome.global_position.y, floor_y])
	gnome.queue_free(); ledge.queue_free()
	await get_tree().physics_frame

func _test_big_axe_survives_another_powerup() -> void:
	# Founder: collecting the big axe "doesnt let him throw the huge axe".
	# current_power_up is a single slot, so ANY later pickup used to silently
	# cancel it. Drive the real activation path, then pick up something else.
	GameManager.activate_power_up("bigaxe", 25.0)
	_check("big axe is active right after pickup", GameManager.has_power_up("bigaxe"))
	GameManager.activate_power_up("big", 10.0)   # a magic mushroom
	_check("big axe SURVIVES collecting another power-up",
		GameManager.has_power_up("bigaxe"),
		"a mushroom cancelled the axe — the single-slot bug")
	GameManager.activate_power_up("blaze", 12.0)
	_check("big axe survives a weed leaf too", GameManager.has_power_up("bigaxe"))
	GameManager.big_axe_timer = 0.0
	_check("big axe expires on its own timer", not GameManager.has_power_up("bigaxe"))


const HOSTILE_VINE := preload("res://src/enemies/hostile_vine.tscn")
const DISTRIBUTOR := preload("res://src/boss/distributor.tscn")

## Founder: "I also want all of the snakes to spit venom in all the stages."
## The striking vines ARE the snakes, and they were a purely passive hazard —
## anything that kept its distance was never threatened.
func _test_snakes_spit_venom() -> void:
	get_tree().call_group("boss_projectile", "queue_free")
	await get_tree().physics_frame
	var player := _make_player(Vector2(260, 300))
	var vine: Node2D = HOSTILE_VINE.instantiate()
	add_child(vine)
	vine.global_position = Vector2(0, 300)
	# Force the extended (dangerous) state — venom only fires while extended,
	# so the existing tell still telegraphs it.
	vine.call("extend")
	var spat := false
	for i in 240:
		await get_tree().physics_frame
		for n in get_children():
			if n.is_in_group("boss_projectile"):
				spat = true
				break
		if spat:
			break
	_check("a snake spits venom at a player in range", spat)
	get_tree().call_group("boss_projectile", "queue_free")
	vine.queue_free(); player.queue_free()
	await get_tree().physics_frame

## Founder: "have the gnome like characters fire arrows at Lil Blunt from their
## bow and arrows in ANY direction". The aim must be a real vector at the
## player, not the enemy's own patrol axis — otherwise a gnome on a ledge can
## never threaten anyone below it.
func _test_gnomes_fire_arrows() -> void:
	get_tree().call_group("boss_projectile", "queue_free")
	await get_tree().physics_frame
	var ledge := _make_ledge(1000.0, 600.0)
	var gnome: Node2D = TAX_COLLECTOR.instantiate()
	add_child(gnome)
	gnome.global_position = Vector2(500, 568)
	# Player well BELOW and to the side — only a genuinely aimed shot reaches.
	var player := _make_player(Vector2(660, 700))
	var arrow: Node2D = null
	for i in 300:
		await get_tree().physics_frame
		for n in get_children():
			if n.is_in_group("boss_projectile"):
				arrow = n
				break
		if arrow != null:
			break
	_check("a gnome fires an arrow at a player in range", arrow != null)
	if arrow != null:
		var d: Vector2 = arrow.get("direction")
		_check("the arrow is aimed in an arbitrary direction, not axis-locked",
			absf(d.y) > 0.08,
			"direction = %s (y component too small to be aimed)" % str(d))
	get_tree().call_group("boss_projectile", "queue_free")
	gnome.queue_free(); player.queue_free(); ledge.queue_free()
	await get_tree().physics_frame

## Founder: "the boss is not chasing Lil Blunt which makes it too easy."
## The existing boss_stakes gate only proves he closes on a STATIONARY player.
## This one runs away from him at the player's real top speed (walk 200 *
## sprint 1.2 = 240 px/s), which is the case that was actually failing.
func _test_stage2_boss_outruns_a_sprinting_player() -> void:
	var player := _make_player(Vector2(600, 500))
	var boss: Node2D = DISTRIBUTOR.instantiate()
	add_child(boss)
	boss.global_position = Vector2(0, 400)
	await get_tree().physics_frame
	var start_gap: float = absf(player.global_position.x - boss.global_position.x)
	for i in 300:
		# Player sprints away every frame.
		player.global_position.x += 240.0 * (1.0 / 60.0)
		await get_tree().physics_frame
	var end_gap: float = absf(player.global_position.x - boss.global_position.x)
	_check("the L2 boss closes on a player sprinting away at top speed",
		end_gap < start_gap,
		"gap went %.0f -> %.0f — he cannot catch a running player" % [start_gap, end_gap])
	boss.queue_free(); player.queue_free()
	await get_tree().physics_frame

## THE GATE THAT WAS MISSING, and the reason the founder saw "still not moving"
## after the last pass reported the chase FIXED.
##
## `_test_stage2_boss_outruns_a_sprinting_player` above builds the Distributor
## with NO arena bounds, so `_clamp_to_arena()` returns immediately and the
## test measures a boss flying in open space. The real level ALWAYS sets those
## bounds. The clamp was the whole bug: it pinned him against the arena edge
## whenever the player fought from the west of the arena, and no amount of
## extra speed could show up in a test that never switched the clamp on.
##
## This one reproduces level_02_crystal_caverns.gd exactly — same raw arena
## box, same spawn — and then kites the player to the WEST WALL, which is the
## specific place he used to freeze.
func _test_stage2_boss_chases_inside_the_real_arena() -> void:
	# Values copied from level_02_data.tres + level_02_crystal_caverns.gd.
	var arena_start: float = 3700.0
	var arena_end: float = 4400.0
	var spawn := Vector2(4050.0, 500.0)
	var player := _make_player(Vector2(4300.0, 500.0))
	var boss: Node2D = DISTRIBUTOR.instantiate()
	boss.set("arena_min", Vector2(arena_start, spawn.y - 320.0))
	boss.set("arena_max", Vector2(arena_end, spawn.y + 120.0))
	boss.global_position = spawn
	add_child(boss)
	await get_tree().physics_frame
	var travelled: float = 0.0
	var last_x: float = boss.global_position.x
	# The player runs west at full sprint until they hit the wall, then holds
	# it — the exact thing the founder does when the fight starts.
	for i in 420:
		player.global_position.x = maxf(arena_start,
			player.global_position.x - 240.0 * (1.0 / 60.0))
		await get_tree().physics_frame
		travelled += absf(boss.global_position.x - last_x)
		last_x = boss.global_position.x
	var centre_x: float = boss.global_position.x + 120.0
	var gap: float = absf(centre_x - player.global_position.x)
	_check("the L2 boss actually MOVES inside a real arena box",
		travelled > 400.0,
		"boss travelled only %.0f px in 7s of kiting — he is pinned" % travelled)
	# Half a body (120) is the closest his centre can physically get to a player
	# standing ON the west wall. 150 allows that plus a little settling; the old
	# origin-clamped build sat at 210 and could never improve.
	_check("the L2 boss reaches a player pinned against the west arena wall",
		gap < 150.0,
		"boss centre stalled %.0f px away (west wall is unreachable)" % gap)
	boss.queue_free(); player.queue_free()
	await get_tree().physics_frame

## Founder: stage 3 boss is "too easy" — he must chase, not stalk. Run under the
## real L3 arena box, on a real floor, with the ledge sense live, so a chase fix
## cannot quietly reintroduce the void death he complained about before.
func _test_stage3_boss_chases_inside_the_real_arena() -> void:
	var arena_start: float = 3700.0
	var arena_end: float = 4400.0
	var spawn := Vector2(4050.0, 500.0)
	# Solid floor across the whole arena — nothing to fall off, so any failure
	# here is a chase failure and not a ledge failure.
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 1
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(1400, 80)
	cs.shape = rect
	cs.position = Vector2(4050.0, 620.0)
	floor_body.add_child(cs)
	add_child(floor_body)
	var player := _make_player(Vector2(4350.0, 520.0))
	var boss: Node2D = CLAIM_JUMPER.instantiate()
	boss.set("arena_min", Vector2(arena_start, spawn.y - 400.0))
	boss.set("arena_max", Vector2(arena_end, spawn.y + 60.0))
	boss.global_position = spawn
	add_child(boss)
	await get_tree().physics_frame
	var start_gap: float = absf((boss.global_position.x + 40.0) - player.global_position.x)
	for i in 420:
		player.global_position.x = maxf(arena_start,
			player.global_position.x - 240.0 * (1.0 / 60.0))
		await get_tree().physics_frame
	var end_gap: float = absf((boss.global_position.x + 40.0) - player.global_position.x)
	_check("the L3 boss closes on a player kiting at full sprint",
		end_gap < start_gap,
		"gap went %.0f -> %.0f" % [start_gap, end_gap])
	_check("the L3 boss reaches a player pinned against the west arena wall",
		end_gap < 120.0,
		"boss centre stalled %.0f px away" % end_gap)
	_check("chasing did not drop the L3 boss out of the world",
		boss.global_position.y < spawn.y + 200.0,
		"boss y = %.0f" % boss.global_position.y)
	boss.queue_free(); player.queue_free(); floor_body.queue_free()
	await get_tree().physics_frame

## Founder: "arrows must look like arrows, not circular boss orbs."
##
## The old shot was boss_projectile.tscn — a spinning fx_dot.png CIRCLE with a
## different tint. Behaviour tests could never catch that, because the
## behaviour was fine; the picture was the bug. So this asserts on the SCRIPT
## the projectile is running, which is the one thing that distinguishes an
## arrow from an orb no matter how it is tinted.
func _test_gnome_arrow_is_an_arrow_not_an_orb() -> void:
	get_tree().call_group("boss_projectile", "queue_free")
	await get_tree().physics_frame
	var ledge := _make_ledge(1000.0, 600.0)
	var gnome: Node2D = TAX_COLLECTOR.instantiate()
	add_child(gnome)
	gnome.global_position = Vector2(500, 568)
	var player := _make_player(Vector2(660, 640))
	var arrow: Node2D = null
	for i in 300:
		await get_tree().physics_frame
		for n in get_children():
			if n.is_in_group("boss_projectile"):
				arrow = n
				break
		if arrow != null:
			break
	_check("a gnome still fires when the player is in range", arrow != null)
	if arrow != null:
		var scr: Script = arrow.get_script()
		var path: String = "" if scr == null else scr.resource_path
		_check("the gnome's shot is an ARROW, not the circular boss orb",
			path.ends_with("gnome_arrow.gd"),
			"projectile script is %s" % path)
		# Rotated to its heading is what makes it read as an arrow rather than
		# a sideways stick; an unrotated node would be a horizontal line.
		var d: Vector2 = arrow.get("direction")
		_check("the arrow is rotated to point where it is flying",
			absf(angle_difference(arrow.rotation, d.angle())) < 0.05,
			"rotation %.2f vs heading %.2f" % [arrow.rotation, d.angle()])
	get_tree().call_group("boss_projectile", "queue_free")
	gnome.queue_free(); player.queue_free(); ledge.queue_free()
	await get_tree().physics_frame

## T5 — STAGE 3 CLARITY. Founder: the stage "is still shitty", cut the
## clutter, and "if a prop is unclear, REMOVE it rather than invent lore".
##
## The concrete instance this catches: big_axe.tscn and pickaxe_tool.tscn both
## pointed at `sprite_item_pickaxe.png`, and Level 3 spawns BOTH. Two different
## power-ups with different effects were pixel-identical on screen, so the
## second one could only read as a duplicate of the first — i.e. as clutter —
## and no player could tell which one they had just picked up. The big axe got
## its own drawn sprite; this stops any future power-up from being added by
## copying another one's scene and forgetting the art.
func _test_no_two_powerups_look_identical() -> void:
	var seen: Dictionary = {}
	var clashes: Array[String] = []
	var dir := DirAccess.open("res://src/powerups")
	if dir == null:
		_check("power-up directory is readable", false)
		return
	for f: String in dir.get_files():
		# Exported builds rename .tscn to .remap / .scn; check the base name.
		var name: String = f.trim_suffix(".remap")
		if not name.ends_with(".tscn") and not name.ends_with(".scn"):
			continue
		var packed := load("res://src/powerups/%s" % name) as PackedScene
		if packed == null:
			continue
		var inst := packed.instantiate()
		var spr := inst.get_node_or_null("Sprite") as Sprite2D
		if spr != null and spr.texture != null:
			var tex: String = spr.texture.resource_path
			if seen.has(tex):
				clashes.append("%s and %s both use %s" % [seen[tex], name, tex])
			else:
				seen[tex] = name
		inst.queue_free()
	_check("no two power-ups are drawn with the same sprite",
		clashes.is_empty(), "; ".join(clashes))
