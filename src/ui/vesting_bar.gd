extends ProgressBar
## 100-Day Vesting Bar — tracks GOLD token collection progress.
## Fills 1% per gold_token collected (max 100 = 100% completion).
## At 100%: unlocks Gold Claim Certificate door in boss arena.
## If player dies before 100%: bar resets to 0 (teaches forfeiture mechanic).

@onready var label: Label = Label.new()

var max_gold_tokens: int = 100
var gold_collected: int = 0
var vesting_complete: bool = false

func _ready() -> void:
	max_value = max_gold_tokens
	value = 0
	vesting_complete = false

	# Add label
	label.text = "VESTING: %d/100" % gold_collected
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.position = Vector2(0, -5)
	add_child(label)

	# Listen to GoldMineSystem
	GoldMineSystem.gold_changed.connect(_on_gold_changed)
	GameManager.player_died.connect(_on_player_died)

	_on_gold_changed(GoldMineSystem.gold_balance)

func _on_gold_changed(new_amount: int) -> void:
	gold_collected = new_amount
	value = mini(gold_collected, max_gold_tokens)
	label.text = "VESTING: %d/100" % gold_collected

	if gold_collected >= max_gold_tokens and not vesting_complete:
		_complete_vesting()

func _on_player_died() -> void:
	# Whitepaper: death forfeits progress. Reset vesting bar.
	gold_collected = 0
	value = 0
	vesting_complete = false
	label.text = "VESTING: RESET (death forfeited progress)"
	label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2, 1.0))
	await get_tree().create_timer(2.0).timeout
	label.remove_theme_color_override("font_color")

func _complete_vesting() -> void:
	vesting_complete = true
	modulate = Color(1.0, 0.84, 0.0, 1.0)  # Gold flash
	label.text = "VESTING: COMPLETE ✓"
	label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0, 1.0))
	AudioManager.play_sfx("powerup")
	var toast := Label.new()
	toast.text = "100% VESTED — BOSS ARENA UNLOCKED"
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.position = Vector2(get_viewport().size.x / 2 - 150, 80)
	toast.add_theme_font_size_override("font_size", 24)
	get_tree().root.add_child(toast)
	var tween := create_tween()
	tween.tween_interval(3.0)
	tween.tween_property(toast, "modulate:a", 0.0, 0.4)
	tween.finished.connect(toast.queue_free)
