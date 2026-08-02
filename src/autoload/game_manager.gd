extends Node

signal score_changed(new_score: int)
signal health_changed(new_health: int)
signal power_up_changed(type: String, duration: float)
signal coins_changed(new_count: int)
signal rings_changed(new_count: int)
signal smoke_changed(new_count: int)
signal player_died
signal lives_changed(new_lives: int)
## Systems architecture v3.0 §3.3 — signal-driven, never polled.
signal progression_unlocked(content: String)
signal crypto_price_updated(token: String, price: float)
signal crypto_balance_updated(token: String, balance: float)
signal wallet_address_changed(address: String)

# Persistent player data only — no state booleans (those live in StateMachine).
var total_score: int = 0
var coins_collected: int = 0
var ethereum_rings_collected: int = 0
var smoke_collected: int = 0
# Blaze Rush (secret dash mode) bookkeeping.
var blaze_rush_completed: Dictionary = {}   # level_index -> true once one-time bonuses paid
var dash_return: Dictionary = {}            # transient: scene_path/position/level_index for the return trip
var secret_return: Dictionary = {}          # transient: scene_path/position to return from a secret realm
var player_health: int = 3
var max_health: int = 3
## Lives — a hard fail (falling into a pit) costs one. Out of lives = game over.
var lives: int = 3
var max_lives: int = 3
var current_power_up: String = ""
var power_up_timer: float = 0.0
var current_level: int = 1
var level_checkpoints: Dictionary = {}
var player_position: Vector2 = Vector2.ZERO
## Analytics attribution (task #23): the last thing that hurt the player
## ("tax", "boulder", "vine", "fly", "pit", boss ids). Written by enemies/
## hazards on contact, read by player death reporting. Display-only data.
var last_damage_source: String = ""

const SAVE_PATH: String = "user://save.json"

## Level progression registry (brief correction G): the ordered campaign.
## Beating a level's boss advances to the next; the last completes the game.
## Single source of truth — bosses/victory screen route through here instead
## of each hardcoding "back to menu" (which made L2/L3 unreachable).
const LEVEL_SEQUENCE: Array[String] = [
    "res://src/level/level_01_smoke_realm.tscn",
    "res://src/level/level_02_crystal_caverns.tscn",
    "res://src/level/level_03_gold_rush.tscn",
]
const MENU_SCENE := "res://src/ui/main_menu.tscn"

## Scene path to advance to after clearing `level_index` (1-based). Returns the
## menu when the campaign is complete. Also unlocks the level for continue.
func next_level_scene(cleared_level_index: int) -> String:
    var next_idx := cleared_level_index  # 1-based cleared → 0-based next
    if next_idx >= 0 and next_idx < LEVEL_SEQUENCE.size():
        highest_unlocked_level = maxi(highest_unlocked_level, next_idx + 1)
        current_level = next_idx + 1
        return LEVEL_SEQUENCE[next_idx]
    return MENU_SCENE

func level_scene(level_index: int) -> String:
    var i := level_index - 1
    return LEVEL_SEQUENCE[i] if i >= 0 and i < LEVEL_SEQUENCE.size() else LEVEL_SEQUENCE[0]

## Highest level the player has reached (1-based). Persisted so Continue and a
## level-select can offer already-unlocked realms.
var highest_unlocked_level: int = 1

# ---------------------------------------------------------------------------
# STRUCTURED STATE (systems architecture v3.0 §3.1)
#
# Two dictionaries with fixed key sets, mutated ONLY through the methods below
# so every change emits a signal (§3.2: "Write global state — only via
# GameManager methods with signals"). They are Dictionaries rather than typed
# objects because they serialise straight to JSON with no adapter layer, which
# is what the existing save file already is.
# ---------------------------------------------------------------------------

## Campaign progress. `highest_unlocked_level` stays the authoritative int for
## level routing (LEVEL_SEQUENCE indexes it); this records the richer history
## that unlock gating and completion stats need.
var progression_state: Dictionary = {
    "levels_completed": [],     # Array[int] — 1-based level indices
    "bosses_defeated": [],      # Array[String] — boss ids
    "shooter_unlocked": false,  # v1.2 Blunt Force
    "space_unlocked": false,    # v1.3 Cosmic Blunt
    "total_play_time": 0.0,
}

## Live market data + the player's balances.
##
## NOT PERSISTED, deliberately. Prices go stale in seconds, and a saved balance
## is a stale balance that could make the game claim a player holds tokens they
## have since sold. This is a runtime cache fed by Web3Bridge/IcpBackend, and
## it must always be re-read from a live source. The one persisted crypto field
## is `wallet_address`, below, because that IS stable identity.
var crypto_state: Dictionary = {
    "smoke_balance": 0.0,
    "diamonds_balance": 0.0,
    "gold_balance": 0.0,
    "eth_price": 0.0,
    "btc_price": 0.0,
    "titanx_price": 0.0,
}

## Connected wallet, or "" when not connected. Persisted so a returning player
## keeps their identity without reconnecting. Never a key or seed — an address
## is public data (see docs/security/GAME_SECURITY_CHECKLIST.md).
var wallet_address: String = ""

# ---- progression API ------------------------------------------------------

## Record a cleared level. Idempotent: replaying level 2 must not append twice.
func mark_level_completed(level_index: int) -> void:
    var completed: Array = progression_state["levels_completed"]
    if level_index in completed:
        return
    completed.append(level_index)
    completed.sort()
    # Clearing the final level is what opens the shooter — the GDD's rule that
    # v1.2 unlocks from campaign completion, never from a wallet.
    if completed.size() >= LEVEL_SEQUENCE.size():
        unlock_content("shooter")
    save_session()

## Record a boss kill by id ("auditor", "distributor", "claim_jumper", ...).
func mark_boss_defeated(boss_id: String) -> void:
    var defeated: Array = progression_state["bosses_defeated"]
    if boss_id in defeated:
        return
    defeated.append(boss_id)
    save_session()

## Unlock a content tier. Emits so menus can reveal entries without polling.
func unlock_content(content: String) -> void:
    var key := "%s_unlocked" % content
    if not progression_state.has(key) or progression_state[key]:
        return
    progression_state[key] = true
    progression_unlocked.emit(content)
    save_session()

func is_unlocked(content: String) -> bool:
    return bool(progression_state.get("%s_unlocked" % content, false))

func add_play_time(seconds: float) -> void:
    progression_state["total_play_time"] = float(
        progression_state.get("total_play_time", 0.0)) + maxf(seconds, 0.0)

# ---- crypto API -----------------------------------------------------------

## Update one cached price. Ignores non-positive values so a failed fetch
## returning 0 can't blank a good price already on screen.
func set_crypto_price(token: String, price: float) -> void:
    var key := "%s_price" % token.to_lower()
    if not crypto_state.has(key) or price <= 0.0:
        return
    crypto_state[key] = price
    crypto_price_updated.emit(token.to_lower(), price)

## Update one cached balance. 0.0 IS meaningful here (a real empty wallet), so
## unlike prices it is accepted.
func set_crypto_balance(token: String, balance: float) -> void:
    var key := "%s_balance" % token.to_lower()
    if not crypto_state.has(key) or balance < 0.0:
        return
    crypto_state[key] = balance
    crypto_balance_updated.emit(token.to_lower(), balance)

func get_crypto(key: String) -> float:
    return float(crypto_state.get(key, 0.0))

func set_wallet_address(address: String) -> void:
    if address == wallet_address:
        return
    wallet_address = address
    wallet_address_changed.emit(address)
    save_session()

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    load_session()

func add_score(points: int) -> void:
    total_score += points
    score_changed.emit(total_score)

func add_coin() -> void:
    coins_collected += 1
    coins_changed.emit(coins_collected)
    add_score(10)

func add_ethereum_ring() -> void:
    ethereum_rings_collected += 1
    rings_changed.emit(ethereum_rings_collected)
    add_score(50)

## Bank $SMOKE tokens earned in Blaze Rush runs.
func add_smoke(amount: int) -> void:
    if amount <= 0:
        return
    smoke_collected += amount
    smoke_changed.emit(smoke_collected)

func take_damage(amount: int) -> void:
    if current_power_up == "diamond":
        deactivate_power_up()
        return
    player_health -= amount
    if player_health < 0:
        player_health = 0
    health_changed.emit(player_health)
    if player_health <= 0:
        GoldMineSystem.on_player_death()
        player_died.emit()
        # NOTE: the death-state transition is owned by Player.die(), NOT here.
        # This used to call StateMachine.change_state(GAME_OVER), which flipped
        # the state BEFORE Player.die() ran; die()'s own is_dead() guard then
        # bailed and the respawn sequence never executed — the player froze in
        # GAME_OVER. Player.take_damage() calls die() right after this returns.

func heal(amount: int) -> void:
    player_health = min(player_health + amount, max_health)
    health_changed.emit(player_health)

## Spend a life (pit fall). Returns true if that was the LAST life (game over).
## On a surviving loss, health refills so the checkpoint respawn is fair.
func lose_life() -> bool:
    lives -= 1
    if lives < 0:
        lives = 0
    lives_changed.emit(lives)
    if lives <= 0:
        GoldMineSystem.on_player_death()
        player_died.emit()
        StateMachine.change_state(StateMachine.State.GAME_OVER)
        return true
    player_health = max_health
    health_changed.emit(player_health)
    return false

## Blaze/Purple own an exclusive music override; token guards its release
## against stale expiry (brief correction A).
var _blaze_music_token: int = -1

func activate_power_up(type: String, duration: float) -> void:
    current_power_up = type
    power_up_timer = duration
    power_up_changed.emit(type, duration)
    AudioManager.play_sfx("powerup")
    # Major pickups only. Coins/rings never route through here (they call
    # add_coin/add_ethereum_ring), and the CLEAR path is the separate
    # deactivate_power_up(), so an expiry can't reach this line.
    if type != "" and duration > 0.0:
        AudioManager.play_bark("vo_collect_major", 10.0)
    # Blaze / Purple Weed: take over the MUSIC exclusively — no more jingle
    # layered over the level track. Pushing again refreshes the token so a
    # second pickup can't be stopped by the first's expiry.
    if type == "blaze" or type == "purple":
        _blaze_music_token = AudioManager.push_music_override("res://src/assets/sounds/fresh_boost.ogg")
    # Analytics (task #23): which power-ups actually get used feeds the
    # founder digest + future tuning. Fire-and-forget, no-op offline.
    Web3Bridge.report_metric("powerup_used", {"type": type})

func deactivate_power_up() -> void:
    # Release the Blaze music override (token-guarded — stale releases no-op,
    # so a scene change or second pickup can't restore an old track).
    if _blaze_music_token != -1:
        AudioManager.release_music_override(_blaze_music_token)
        _blaze_music_token = -1
    current_power_up = ""
    power_up_timer = 0.0
    power_up_changed.emit("", 0.0)

func has_power_up(type: String) -> bool:
    return current_power_up == type

func _process(delta: float) -> void:
    if power_up_timer > 0:
        power_up_timer -= delta
        if power_up_timer <= 0:
            deactivate_power_up()

func reset_level() -> void:
    player_health = max_health
    _clear_blaze_music_override()
    current_power_up = ""
    power_up_timer = 0.0
    # The HUD in the incoming level _ready()s BEFORE the player spawns and
    # reads these values — without this emit it keeps showing the previous
    # level's damaged heart count until the next hit.
    health_changed.emit(player_health)

func reset_session() -> void:
    player_health = max_health
    lives = max_lives
    lives_changed.emit(lives)
    _clear_blaze_music_override()
    current_power_up = ""
    power_up_timer = 0.0
    health_changed.emit(player_health)
    total_score = 0
    coins_collected = 0
    ethereum_rings_collected = 0
    smoke_collected = 0
    smoke_changed.emit(0)
    blaze_rush_completed.clear()
    dash_return = {}
    level_checkpoints.clear()
    GoldMineSystem.reset_session()

## Release a Blaze override if one is live (level reset / new session). The
## AudioManager token guard makes a double-release harmless.
func _clear_blaze_music_override() -> void:
    if _blaze_music_token != -1:
        AudioManager.release_music_override(_blaze_music_token)
        _blaze_music_token = -1

func save_checkpoint(level: int, checkpoint_id: int, pos: Vector2) -> void:
    level_checkpoints[level] = {"id": checkpoint_id, "pos": pos}

func get_checkpoint(level: int) -> Vector2:
    if level in level_checkpoints:
        return level_checkpoints[level].pos
    return Vector2.ZERO

func save_session() -> bool:
    var data: Dictionary = {
        "total_score": total_score,
        "coins": coins_collected,
        "rings": ethereum_rings_collected,
        "smoke": smoke_collected,
        "blaze_rush": _serialize_blaze_completions(),
        "health": player_health,
        "max_health": max_health,
        "lives": lives,
        "current_level": current_level,
        "highest_unlocked_level": highest_unlocked_level,
        "checkpoints": _serialize_checkpoints(),
        "goldmine": GoldMineSystem.get_save_data(),
        # v3.0 structured state. crypto_state is intentionally absent — prices
        # and balances are a live cache, never persisted (see its declaration).
        "progression_state": progression_state,
        "wallet_address": wallet_address,
    }
    var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if f == null:
        push_error("GameManager.save_session: cannot open %s" % SAVE_PATH)
        # A silent save failure loses a player's whole campaign — the worst
        # non-crash outcome in the game, and invisible without this.
        ErrorReporter.report("save_failed", {"path": SAVE_PATH})
        return false
    f.store_string(JSON.stringify(data))
    f.close()
    return true

func load_session() -> bool:
    if not FileAccess.file_exists(SAVE_PATH):
        return false
    var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if f == null:
        return false
    var raw := f.get_as_text()
    f.close()
    var parsed: Variant = JSON.parse_string(raw)
    if typeof(parsed) != TYPE_DICTIONARY:
        return false
    var data: Dictionary = parsed
    # Clamp everything from disk: user://save.json is player-editable, and
    # unclamped values (9999 health, level 42) corrupt the session state.
    # max_health loads FIRST so the health clamp uses the loaded ceiling
    # (the old order clamped against the previous session's value).
    total_score = maxi(0, int(data.get("total_score", 0)))
    coins_collected = maxi(0, int(data.get("coins", 0)))
    ethereum_rings_collected = maxi(0, int(data.get("rings", 0)))
    smoke_collected = maxi(0, int(data.get("smoke", 0)))
    _deserialize_blaze_completions(data.get("blaze_rush", {}))
    max_health = clampi(int(data.get("max_health", 3)), 1, 10)
    player_health = clampi(int(data.get("health", max_health)), 1, max_health)
    # Lives persist too (Kimi audit): reloading mid-run must not refill them.
    lives = clampi(int(data.get("lives", max_lives)), 0, max_lives)
    lives_changed.emit(lives)
    current_level = clampi(int(data.get("current_level", 1)), 1, 3)
    highest_unlocked_level = clampi(int(data.get("highest_unlocked_level", 1)), 1, LEVEL_SEQUENCE.size())
    _deserialize_checkpoints(data.get("checkpoints", {}))
    if data.has("goldmine"):
        GoldMineSystem.load_save_data(data.get("goldmine", {}))
    _deserialize_progression(data.get("progression_state", {}))
    wallet_address = str(data.get("wallet_address", ""))
    return true

## Merge saved progression over the defaults, key by key.
##
## BACKWARD COMPATIBILITY: a v1.0 save has no "progression_state" key at all,
## so this receives {} and every field keeps its default — the save still
## loads and the player keeps score, level, lives and checkpoints. Merging
## key-by-key (rather than assigning the dictionary wholesale) also means a
## save written by a NEWER build with extra keys degrades safely instead of
## replacing our dictionary with a foreign shape.
func _deserialize_progression(raw: Variant) -> void:
    if typeof(raw) != TYPE_DICTIONARY:
        return
    var data: Dictionary = raw

    var completed: Array = []
    for v in _as_array(data.get("levels_completed", [])):
        var idx := int(v)
        # Clamp to the real campaign: a hand-edited save must not inject
        # level 99 and trick the unlock logic into thinking it's finished.
        if idx >= 1 and idx <= LEVEL_SEQUENCE.size() and not idx in completed:
            completed.append(idx)
    completed.sort()
    progression_state["levels_completed"] = completed

    var bosses: Array = []
    for v in _as_array(data.get("bosses_defeated", [])):
        var boss_id := str(v)
        if boss_id != "" and not boss_id in bosses:
            bosses.append(boss_id)
    progression_state["bosses_defeated"] = bosses

    progression_state["shooter_unlocked"] = bool(data.get("shooter_unlocked", false))
    progression_state["space_unlocked"] = bool(data.get("space_unlocked", false))
    progression_state["total_play_time"] = maxf(
        float(data.get("total_play_time", 0.0)), 0.0)

    # Self-heal for v1.0 saves: they have no levels_completed but they DO have
    # highest_unlocked_level. Reconstruct the history from it so a long-time
    # player isn't told they've completed nothing.
    if completed.is_empty() and highest_unlocked_level > 1:
        for i in range(1, highest_unlocked_level):
            progression_state["levels_completed"].append(i)

func _as_array(v: Variant) -> Array:
    return v if typeof(v) == TYPE_ARRAY else []

func _serialize_checkpoints() -> Dictionary:
    var out: Dictionary = {}
    for level in level_checkpoints.keys():
        var cp: Dictionary = level_checkpoints[level]
        out[str(level)] = {
            "id": cp.id,
            "x": cp.pos.x,
            "y": cp.pos.y,
        }
    return out

func _serialize_blaze_completions() -> Dictionary:
    var out: Dictionary = {}
    for level in blaze_rush_completed.keys():
        out[str(level)] = bool(blaze_rush_completed[level])
    return out

func _deserialize_blaze_completions(raw: Dictionary) -> void:
    blaze_rush_completed.clear()
    for k in raw.keys():
        blaze_rush_completed[int(k)] = bool(raw[k])

func _deserialize_checkpoints(raw: Dictionary) -> void:
    level_checkpoints.clear()
    for k in raw.keys():
        var entry: Dictionary = raw[k]
        level_checkpoints[int(k)] = {
            "id": int(entry.get("id", 0)),
            "pos": Vector2(float(entry.get("x", 0.0)), float(entry.get("y", 0.0))),
        }

# ---- Offline mode (task: offline-mode skill, Video-Game Layer) -------------
# The game adapts to network state without breaking: a banner appears when the
# backend is unreachable, disappears on silent reconnect+sync (Web3Bridge owns
# probing, queueing, and cache; this owns the player-facing flag + banner).

## Global flag other systems may consult (oracle panel, menu wallet button).
var offline_mode: bool = false
var _offline_banner: CanvasLayer

func _enter_tree() -> void:
    # Deferred: Web3Bridge loads after GameManager in autoload order.
    call_deferred("_wire_offline_mode")

func _wire_offline_mode() -> void:
    if not has_node("/root/Web3Bridge"):
        return
    Web3Bridge.connectivity_changed.connect(_on_connectivity_changed)

func _on_connectivity_changed(online: bool) -> void:
    offline_mode = not online
    if offline_mode:
        _show_offline_banner()
    else:
        _hide_offline_banner()

func _show_offline_banner() -> void:
    if _offline_banner != null and is_instance_valid(_offline_banner):
        return
    _offline_banner = CanvasLayer.new()
    _offline_banner.layer = 99
    var lbl := Label.new()
    lbl.name = "Banner"
    lbl.text = "OFFLINE MODE — scores saved locally, will sync when reconnected"
    lbl.add_theme_font_size_override("font_size", 14)
    lbl.modulate = Color(1.0, 0.85, 0.5, 0.95)
    lbl.position = Vector2(12, 6)
    var bg := ColorRect.new()
    bg.color = Color(0.1, 0.08, 0.02, 0.75)
    bg.size = Vector2(520, 26)
    bg.position = Vector2(6, 4)
    _offline_banner.add_child(bg)
    _offline_banner.add_child(lbl)
    get_tree().root.add_child.call_deferred(_offline_banner)

func _hide_offline_banner() -> void:
    if _offline_banner != null and is_instance_valid(_offline_banner):
        _offline_banner.queue_free()
    _offline_banner = null

# ---- Shareable taglines (content engine feeds this list weekly) ------------
# Rotated into snapshot-moment X shares. PRIMARY source: the 50-seed
# res://src/autoload/share_taglines.json (Kimi K3, human-reviewed, packed into
# the export). The const below is the guaranteed fallback if the JSON is
# missing/corrupt. Weekly refreshes: content_engine/score_card_taglines.js.

var _loaded_taglines: Array = []

func _load_share_taglines() -> void:
    const PATH := "res://src/autoload/share_taglines.json"
    if not FileAccess.file_exists(PATH):
        return
    var f := FileAccess.open(PATH, FileAccess.READ)
    if f == null:
        return
    var parsed: Variant = JSON.parse_string(f.get_as_text())
    if typeof(parsed) == TYPE_DICTIONARY:
        var arr: Variant = (parsed as Dictionary).get("taglines", [])
        if typeof(arr) == TYPE_ARRAY and (arr as Array).size() >= 5:
            _loaded_taglines = arr

const SHARE_TAGLINES: Array[String] = [
    "Diamond hands, cloud feet.",
    "HODL my bong, I'm going in.",
    "Gas fees can't tax a double-jump.",
    "Bear market? My vibes are up only.",
    "Chill is the ultimate utility.",
    "Rug pulls fear the double-jump.",
    "Proof of Chill > Proof of Work.",
    "Staked, baked, and never shaked.",
    "My portfolio dips, Lil Blunt don't.",
    "Smoke Realm: where floors are lava, not prices.",
]

func random_tagline() -> String:
    if _loaded_taglines.is_empty():
        _load_share_taglines()
    if not _loaded_taglines.is_empty():
        return str(_loaded_taglines[randi() % _loaded_taglines.size()])
    return SHARE_TAGLINES[randi() % SHARE_TAGLINES.size()]
