extends Node
## The boss-arena seal must stop the PLAYER leaving and must NOT wall the boss.
##
## Founder, 2026-08-22 (~50th "why doesn't boss 3 move"): `_create_wall`'s
## `player_only` flag built the seal on `collision_layer = 8`, which
## project.godot names layer 4 = "Collectibles" — and BOTH bosses carry
## `collision_mask = 13` (World|Enemies|Collectibles). The flag was simply not
## true: the wall sealing the player in was solid to the boss too. Level 3's
## arena starts at x=3700, and the Claim Jumper's x pinned at exactly 3710 with
## velocity.x forced to 0, pogo-hopping its face for the whole fight.
##
## The seal now uses a DEDICATED layer 9 ("ArenaSeal", 256) that only the
## player's body masks. This gate locks both halves of the contract so neither
## can silently regress.
##
## Run: godot --headless res://tests/arena_seal_contract_test.tscn

const SEAL_LAYER := 256
const PLAYER_MASK := 267   # 1|2|8|256 — player.tscn
const BOSS_MASK := 13      # 1|4|8 — auditor.tscn / claim_jumper.tscn

var _fail: int = 0

func _ready() -> void:
	await get_tree().process_frame
	print("ARENA SEAL CONTRACT:")
	_check("seal layer is dedicated, not Collectibles(8) and not Player(2)",
		SEAL_LAYER != 8 and SEAL_LAYER != 2)
	_check("the PLAYER still collides with the seal (cannot leave the arena)",
		(PLAYER_MASK & SEAL_LAYER) != 0,
		"player mask %d misses seal layer %d — the arena no longer seals" % [PLAYER_MASK, SEAL_LAYER])
	_check("the BOSS does NOT collide with the seal (not walled at the arena mouth)",
		(BOSS_MASK & SEAL_LAYER) == 0,
		"boss mask %d hits seal layer %d — he will pin at the arena edge again" % [BOSS_MASK, SEAL_LAYER])
	# The whole point of not reusing layer 2: enemy hurtboxes mask bit 2
	# (mask 70 = 2|4|64) and would proc on an invisible wall wearing the
	# Player layer. Grok 4.6 flagged it; this keeps it flagged.
	_check("seal is invisible to enemy hurtboxes (mask 70)", (70 & SEAL_LAYER) == 0,
		"enemy hurtbox mask 70 overlaps seal layer %d" % SEAL_LAYER)

	# The declared constants must match what the project actually ships.
	var player_scene: PackedScene = load("res://src/player/player.tscn")
	var p: Node = player_scene.instantiate()
	_check("player.tscn really carries mask %d" % PLAYER_MASK,
		p.collision_mask == PLAYER_MASK, "actual=%d" % p.collision_mask)
	p.queue_free()
	var boss_scene: PackedScene = load("res://src/boss/claim_jumper.tscn")
	var b: Node = boss_scene.instantiate()
	_check("claim_jumper.tscn really carries mask %d" % BOSS_MASK,
		b.collision_mask == BOSS_MASK, "actual=%d" % b.collision_mask)
	b.queue_free()

	var src := FileAccess.get_file_as_string("res://src/level/level_base.gd")
	_check("level_base._create_wall uses the dedicated seal layer",
		"wall.collision_layer = %d" % SEAL_LAYER in src,
		"the player_only branch no longer sets layer %d" % SEAL_LAYER)

	print("ARENA_SEAL_CONTRACT: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])
