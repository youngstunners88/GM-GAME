extends Area2D
## Crypto-logo collectible (ETH / BTC / SOL). Same collect flow as a plain
## coin but worth more score, and it still counts toward the coin tally so
## the HUD counter and any coin-gated logic keep working. The logo is set per
## scene (coin_eth/coin_btc/coin_sol.tscn); value is data-driven via @export.

@export var score_value: int = 25

func _ready() -> void:
	add_to_group("collectible")
	body_entered.connect(_on_body_entered)
	# Coin spin (same juice as the base coin).
	var tween := create_tween().set_loops()
	tween.tween_property($Sprite, "scale:x", 0.15, 0.35)
	tween.tween_property($Sprite, "scale:x", 1.0, 0.35)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		collect()

func collect() -> void:
	GameManager.add_coin()
	ComboSystem.add_score(score_value)
	AudioManager.play_sfx_at("coin", global_position)
	EffectSpawner.burst("coin_sparkle", global_position)
	ScreenShake.light()
	set_deferred("monitoring", false)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.1)
	tween.tween_property(self, "position:y", position.y - 20, 0.2)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.2)
	tween.finished.connect(queue_free)
