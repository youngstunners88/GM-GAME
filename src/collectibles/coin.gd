extends Area2D

## Per-stage collectible token.
##
## Founder: the stage tokens should be shaped like the protocol logos -- stage
## 1 the TitanX mark, stage 2 DIAMONDS, stage 3 GoldMine -- instead of the same
## generic gold disc in every level. The swap is done here at runtime rather
## than by forking coin.tscn three ways, so every coin already placed in every
## level scene picks up the right face with no scene edits.
##
## Stage 1 was originally baked from the Lil Blunt / FOMO mark (a reasonable
## guess at "stage 1 = the game's own SmokeRing mascot" given the project's
## three documented ecosystem protocols). Founder, circling that exact token in
## a screenshot: "I want you to make these the TitanX logos that I originally
## requested!!!" -- TitanX is a fourth protocol, not previously listed in
## CLAUDE.md's ecosystem section. Re-baked from his source art; not guessed at.
##
## Source tokens are baked at 64x64 (scripts/... mk_tokens /
## keyout-founder-art) from the badge art and drawn at TOKEN_SCALE so the
## on-screen footprint stays the 40px the original coin sprite had and the
## 44x44 collision box still matches.
const STAGE_TOKENS := {
    1: "res://src/assets/sprites/sprite_token_l1.png",
    2: "res://src/assets/sprites/sprite_token_l2.png",
    3: "res://src/assets/sprites/sprite_token_l3.png",
}
const TOKEN_SCALE := Vector2(0.625, 0.625)

func _ready() -> void:
    add_to_group("collectible")
    body_entered.connect(_on_body_entered)
    var base := _apply_stage_token()
    # Spin animation. Squashes to a sliver and back, RELATIVE to `base` --
    # tweening to the absolute Vector2(1.0) here would blow a 64px token up to
    # 1.6x its intended size on the first loop and leave it there, which is
    # exactly the bug that kept the Blaze Rush diamonds oversized.
    var tween := create_tween().set_loops()
    tween.tween_property($Sprite, "scale:x", base.x * 0.1, 0.3)
    tween.tween_property($Sprite, "scale:x", base.x, 0.3)

## Swaps in the current stage's logo token and returns the sprite's base scale
## (unchanged if this stage has no token art, so L4+ still works).
func _apply_stage_token() -> Vector2:
    var path: String = STAGE_TOKENS.get(GameManager.current_level, "")
    if path == "" or not ResourceLoader.exists(path):
        return $Sprite.scale
    $Sprite.texture = load(path)
    $Sprite.scale = TOKEN_SCALE
    # Brand art is photographic, not pixel art: nearest-neighbour downscaling
    # aliases the fine linework into noise at this size.
    $Sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    return TOKEN_SCALE

func _on_body_entered(body: Node2D) -> void:
    if body.is_in_group("player"):
        collect()

func collect() -> void:
    GameManager.add_coin()
    ComboSystem.add_score(10)
    AudioManager.play_sfx_at("coin", global_position)
    EffectSpawner.burst("coin_sparkle", global_position)
    ScreenShake.light()
    set_deferred("monitoring", false)
    var tween := create_tween()
    tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.1)
    tween.tween_property(self, "position:y", position.y - 20, 0.2)
    tween.parallel().tween_property(self, "modulate:a", 0.0, 0.2)
    tween.finished.connect(queue_free)
