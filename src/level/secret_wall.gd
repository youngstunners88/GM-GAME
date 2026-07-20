extends StaticBody2D
## Secret wall (task #23, Video-Game Layer bridge). Looks like normal terrain
## but shimmers subtly; smash it (pickaxe, same interface as breakable_block)
## to reveal one of:
##   - a community-submitted lore snippet (backend /community-lore, marked
##     served so explorers keep finding fresh ones),
##   - a "Smoke Tip" (crypto education, local rotation),
##   - a referral-code bonus (SMOKE-<pid> +50 pts).
## Wallet connected → 20% of walls hide a Diamond Shard instead (teases the
## Crystal Caverns). No wallet → lore/tips only, no penalty. Every discovery
## fires the secret_found metric. Degrades fully offline (local tips only).

const SMOKE_TIPS: Array[String] = [
	"DYOR before aping into any token.",
	"Never share your seed phrase. Not even with the Oracle.",
	"Volatility is the toll; conviction is the vehicle. Stay chill.",
	"Fort Knox staking rewards the patient miner.",
	"If the FOMO is loud, breathe first. The Realm isn't going anywhere.",
]

## Deterministic per-instance variety without storing state: hash position.
var _variant: int = 0

@onready var sprite: Sprite2D = $Sprite
@onready var collision: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	add_to_group("breakable")
	add_to_group("secret_wall")
	collision.position = Vector2(16, 16)
	_variant = int(abs(global_position.x * 13.0 + global_position.y * 7.0))
	# The tell: a slow faint shimmer — discoverable, not invisible, per the
	# secret-door precedent. Normal terrain doesn't breathe.
	var tw := create_tween().set_loops()
	tw.tween_property(sprite, "modulate", Color(1.12, 1.12, 1.2, 1.0), 1.6)
	tw.tween_property(sprite, "modulate", Color(0.94, 0.94, 0.98, 1.0), 1.6)

## Same contract as breakable_block so the pickaxe smash path just works.
func break_block() -> void:
	AudioManager.play_sfx("damage")
	ScreenShake.shake(0.2, 4.0)
	Web3Bridge.report_metric("secret_found", {"kind": "wall"})
	GameManager.add_score(20)
	_reveal_payload()
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.05)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.2)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.2)
	tween.finished.connect(queue_free)

func _reveal_payload() -> void:
	# Wallet holders: 20% of walls yield a Diamond Shard collectible instead.
	if Web3Bridge.wallet_address != "" and randf() < 0.2:
		_spawn_shard()
		_show_text("A Diamond Shard! The Crystal Caverns are calling...")
		return
	# Rotate payload kinds deterministically: lore → tip → referral → lore...
	match _variant % 3:
		0:
			if Web3Bridge.has_backend():
				Web3Bridge.get_community_lore(_on_lore)
			else:
				_show_text(SMOKE_TIPS[_variant % SMOKE_TIPS.size()])
		1:
			_show_text(SMOKE_TIPS[_variant % SMOKE_TIPS.size()])
		2:
			GameManager.add_score(50)
			_show_text("Crew code: SMOKE-%s\nShare it for +50 pts (banked!)"
					% Web3Bridge.player_id().substr(0, 8).to_upper())
			Web3Bridge.report_metric("referral_code_used", {"source": "secret_wall"})

func _on_lore(res: Variant) -> void:
	if not is_inside_tree():
		return
	var text := ""
	if typeof(res) == TYPE_DICTIONARY:
		text = str((res as Dictionary).get("text", ""))
	if text == "":
		text = SMOKE_TIPS[_variant % SMOKE_TIPS.size()]
	else:
		text = "Realm lore: \"%s\"" % text
		Web3Bridge.report_metric("lore_read", {"source": "secret_wall"})
	_show_text(text)

## World-space floating text at the wall's position; fades on its own. Added
## to the level (not self — we're being freed).
func _show_text(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size = Vector2(280, 0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.z_index = 50
	lbl.position = global_position + Vector2(-124, -84)
	lbl.modulate = Color(0.85, 1.0, 0.9, 0.0)
	get_parent().add_child(lbl)
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "modulate:a", 1.0, 0.25)
	tw.tween_interval(4.0)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.6)
	tw.parallel().tween_property(lbl, "position:y", lbl.position.y - 24.0, 0.6)
	tw.finished.connect(lbl.queue_free)

## Diamond Shard pickup: reuse the diamond collectible if the spawner knows it,
## else a tinted ETH-ring sprite granting the diamond power-up on touch.
func _spawn_shard() -> void:
	var shard := Area2D.new()
	shard.collision_layer = 0
	shard.collision_mask = 2
	var spr := Sprite2D.new()
	spr.texture = load("res://src/assets/sprites/sprite_item_eth-ring.png")
	spr.modulate = Color(0.55, 0.9, 1.5, 1.0)
	spr.scale = Vector2(0.8, 0.8)
	shard.add_child(spr)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(28, 28)
	shape.shape = rect
	shard.add_child(shape)
	shard.global_position = global_position + Vector2(16, -8)
	shard.body_entered.connect(func(b: Node2D) -> void:
		if b.is_in_group("player"):
			AudioManager.play_sfx("powerup")
			GameManager.activate_power_up("diamond", 8.0)
			GameManager.add_score(100)
			shard.queue_free())
	get_parent().call_deferred("add_child", shard)
