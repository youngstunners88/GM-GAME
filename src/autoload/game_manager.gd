extends Node

signal score_changed(new_score: int)
signal health_changed(new_health: int)
signal power_up_changed(type: String, duration: float)
## Fires the moment a weed-leaf / Blaze pickup lands, so the player can run its
## eccentric celebration. Separate from power_up_changed because that also
## fires on expiry and for every other power-up type.
signal blaze_celebration
signal coins_changed(new_count: int)
signal rings_changed(new_count: int)
signal smoke_changed(new_count: int)
## $TITANX — the 4th protocol token (founder: "TitanX is a fourth protocol,
## not previously listed in CLAUDE.md's ecosystem section"). Lives here, not
## in GoldMineSystem: it is not a GoldMine mechanic, it is a peer token the
## same way DIAMONDS and GOLD are, so it gets its own counter rather than
## being misfiled under a thematically unrelated system.
signal titanx_changed(new_count: int)
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
## $TITANX collected. NOT reset by boss_contact_restart() — a protocol token
## allocation, same persistence class as GoldMineSystem's gold/diamonds/wBTC/
## XAUT (none of which a boss touch wipes either), unlike coins/rings/smoke
## which ARE run currency and ARE forfeit on a boss kill. See
## boss_contact_restart()'s own note on why that distinction exists.
var titanx_collected: int = 0
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

## Credit $TITANX. Founder: "$TITANX... are tokens and not coins" — a
## separate counter from add_coin() so a TitanX pickup is never counted, on
## screen or in code, as a coin.
##
## NO bonus add_score() here (Fable-5 review caught an earlier version that
## had one). Its sibling stage-branded pickups don't get a uniform bonus
## either: GoldMineSystem.collect_diamonds() adds no extra GameManager score
## at all, mine_gold() adds its own pre-existing +25 as part of a whitepaper
## mechanic this function has no business touching. Inventing a THIRD, unrelated
## number here (the previous version used 15) made three visually-parallel
## pickups score three unrelated amounts for no reason a player could ever
## learn. coin.gd's own ComboSystem.add_score(10), which fires for every
## stage-branded pickup identically, is the uniform per-pickup signal; this
## function should only ever touch the counter that's actually its job.
func add_titanx(amount: int = 1) -> void:
    titanx_collected += amount
    titanx_changed.emit(titanx_collected)

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
        StateMachine.change_state(StateMachine.State.GAME_OVER)

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
        full_wipe_restart()
        return true
    player_health = max_health
    health_changed.emit(player_health)
    return false

## FULL WIPE on running out of lives.
##
## Founder: "Lil Blunt should not be limited to 3 lives" AND, when they do run
## out, the run must RESTART rather than dead-end on a Game Over screen.
##
## "Wipe" means the progress earned during the failed run is genuinely
## discarded — the crucial part being the CHECKPOINTS. Refilling lives while
## leaving a mid-level checkpoint standing would drop the player straight back
## at the point they kept dying at, with a full life bar and no way to start
## the stage over: a restart in name only, and a softer loop than the founder
## asked for. The level is reloaded from its own start.
##
## Deliberately NOT a route to the menu: the whole point is that the player
## keeps playing.
## Pure run-state refill: restore lives + health and clear any active power-up,
## then persist. Deliberately does NOT clear checkpoints and does NOT load a
## scene — the CALLER owns the transition.
##
## This exists because player.gd's full-wipe path (_respawn_or_game_over, when
## lives hit 0) called `GameManager.refill_run()` — a function that never
## existed. On EVERY genuine out-of-lives wipe that line threw
## "Invalid call. Nonexistent function 'refill_run'", aborting the rest of
## _respawn_or_game_over so its own fade + SceneRouter.load_scene never ran: the
## run neither refilled nor restarted. Isolated boss/headless tests never
## exercised the real death path, so it stayed invisible until a real-level
## chase sim drove the player out of lives (dual_real_level_boss_chase_test).
## player.gd clears the checkpoint and drives its own fade+load around this
## call, so refilling here must stay load-free or the two loads race.
func refill_run() -> void:
    lives = max_lives
    lives_changed.emit(lives)
    player_health = max_health
    health_changed.emit(player_health)
    current_power_up = ""
    power_up_timer = 0.0
    big_axe_timer = 0.0
    power_up_changed.emit("", 0.0)
    save_session()

func full_wipe_restart() -> void:
    level_checkpoints.clear()
    # A full wipe is a brand-new attempt: the Blaze portal and secret door on
    # this level become available again (see reopen_side_entrances).
    reopen_side_entrances(current_level)
    # Shared refill (lives/health/power-up/save) — ONE implementation, so the
    # wipe path and player.gd's out-of-lives path can never drift apart.
    refill_run()
    # SceneRouter owns transitions; reload the level the player is on.
    SceneRouter.load_scene(level_scene(current_level), SceneRouter.Transition.FADE)

## BOSS CONTACT = BACK TO THE START OF THE LEVEL (founder's new stakes rule):
## "In level one when Lil Blunt is touched by the tax auditor he gets hurt,
##  but then the tax auditor dies. Lil Blunt is supposed to return to the
##  beginning if the tax auditor touches him. The same is true for ALL the
##  bosses REGARDLESS of his lives. This raises the stakes."
##
## So this is deliberately NOT a life loss and NOT ordinary damage — touching a
## boss costs the whole run of that level. The checkpoint for the level is
## cleared first, otherwise LevelBase would respawn him at the mid-level
## checkpoint and "return to the beginning" would quietly mean "return to
## wherever he last was", which is the softer outcome the rule exists to remove.
##
## Guarded because several bosses can land contact on the same frame as a
## projectile or a second hitbox, and two concurrent scene loads would race.
var _boss_restart_pending: bool = false

func boss_contact_restart() -> void:
    if _boss_restart_pending:
        return
    _boss_restart_pending = true
    # THIS IS A DEATH, NOT A SETBACK.
    #
    # Founder, repeatedly: "the moment he touches Lil Blunt the stage needs to
    # restart as Lil Blunt has DIED and the player has LOST ALL OF THEIR
    # POINTS." My previous version reloaded the level but carried the score,
    # coins, rings and SMOKE straight through — so a boss touch cost the
    # player nothing but a walk back, which is exactly the missing stakes he
    # kept reporting. Everything earned in the run is now forfeit.
    #
    # titanx_collected is DELIBERATELY absent from this list, exactly like
    # GoldMineSystem's gold/diamonds/wBTC/XAUT (also untouched here) — those
    # are protocol token holdings, not run currency, and a boss touch does
    # not liquidate a player's tokens any more than it liquidates their
    # DIAMONDS or GOLD.
    total_score = 0
    score_changed.emit(total_score)
    coins_collected = 0
    coins_changed.emit(coins_collected)
    ethereum_rings_collected = 0
    rings_changed.emit(ethereum_rings_collected)
    smoke_collected = 0
    smoke_changed.emit(smoke_collected)
    ComboSystem.break_combo()
    level_checkpoints.erase(current_level)
    # Boss contact is a death, so it is a fresh attempt too.
    reopen_side_entrances(current_level)
    player_health = max_health
    health_changed.emit(player_health)
    current_power_up = ""
    power_up_timer = 0.0
    power_up_changed.emit("", 0.0)
    big_axe_timer = 0.0
    last_damage_source = "boss_contact"
    # Read as a death: the same signal + audio any other fatal hit raises, so
    # HUD/analytics/VO all treat it identically.
    player_died.emit()
    AudioManager.play_sfx("damage")
    AudioManager.play_bark("vo_death", 0.0)
    save_session()
    SceneRouter.load_scene(level_scene(current_level), SceneRouter.Transition.FADE)
    # Cleared on the next level's _ready via reset_boss_restart_flag(); a bare
    # timer here would fire on a freed tree if the load is slow.
    get_tree().create_timer(3.0, true, false, true).timeout.connect(
        reset_boss_restart_flag)

func reset_boss_restart_flag() -> void:
    _boss_restart_pending = false

## ONE-SHOT SIDE ENTRANCES (founder, verbatim):
## "a player should only be able to enter once and once entered in that
##  particular stage they shouldn't be able to enter again as it interferes
##  with the gameplay when the player is running away from the tax collector
##  and entering the Smoke Lounge by accident. Therefore remove the big
##  diamond of the smoke lounge once someone exits."
##
## Keyed by level index. This MUST live here rather than on the portal node:
## the portals already had a `_used` bool, but it is per-INSTANCE, and coming
## back from the Lounge reloads the level and builds a brand-new portal with
## `_used` false again. That is precisely how he kept falling back in while
## fleeing the Tax Collector.
var secret_door_used: Dictionary = {}   # level_index -> true
var blaze_portal_used: Dictionary = {}  # level_index -> true
var vault_door_used: Dictionary = {}    # level_index -> true (Diamond Vault / Fort Knox)

func mark_side_entrance_used(kind: String, level: int) -> void:
    if kind == "secret":
        secret_door_used[level] = true
    elif kind == "vault":
        vault_door_used[level] = true
    else:
        blaze_portal_used[level] = true
    save_session()

func is_side_entrance_used(kind: String, level: int) -> bool:
    if kind == "secret":
        return bool(secret_door_used.get(level, false))
    elif kind == "vault":
        return bool(vault_door_used.get(level, false))
    return bool(blaze_portal_used.get(level, false))

## Reopen a level's side entrances (Blaze portal + secret door) for a FRESH
## ATTEMPT at that level.
##
## Founder: "player collects first diamond, then the game/section resets, but
## the diamond stays already claimed... claim state must not persist across a
## Blaze run restart."
##
## `blaze_portal_used` / `secret_door_used` were written by
## mark_side_entrance_used() and then cleared NOWHERE in the entire codebase —
## not on death, not on a full wipe, not even in reset_progress(). So the first
## time a player took the Blaze entrance on a level it was consumed for good:
## every later restart of that level rebuilt the portal, found the flag still
## true, and queue_free()d it on the spot.
##
## The once-per-visit rule still holds — this does NOT let the portal be
## re-entered inside a single attempt, which is what stopped the founder
## falling back in while fleeing the Tax Collector. It only says that dying and
## restarting the level is a NEW attempt, so the entrance is available again.
func reopen_side_entrances(level: int) -> void:
    secret_door_used.erase(level)
    blaze_portal_used.erase(level)
    vault_door_used.erase(level)

## Grant an extra life. No upper cap — the owner wants unlimited lives.
func add_life(amount: int = 1) -> void:
    if amount <= 0:
        return
    lives += amount
    lives_changed.emit(lives)

## Blaze/Purple own an exclusive music override; token guards its release
## against stale expiry (brief correction A).
var _blaze_music_token: int = -1

## INDEPENDENT TIMER FOR THE BIG-AXE WEAPON MODIFIER.
##
## Founder: "when Lil Blunt colllects it it doesnt let him throw the huge axe,
## its just the same sized axe as before."
##
## `current_power_up` is a SINGLE SLOT — activate_power_up overwrites it every
## time. The big axe is a WEAPON modifier, not a body state, but it was sharing
## that one slot with blaze / big / diamond / pickaxe / torch / bong / purple.
## So picking up literally any other power-up after the axe — a mushroom, a
## weed leaf, a shard — silently reverted the throw to a normal axe, which in a
## stage as pickup-dense as the Gold Rush happens within seconds. The axe kept
## its own 25s duration in name only.
##
## Tracked separately so the two cannot clobber each other. current_power_up is
## still set as well, so the HUD's power-up bar behaves exactly as before.
var big_axe_timer: float = 0.0

func activate_power_up(type: String, duration: float) -> void:
    if type == "bigaxe":
        big_axe_timer = duration
    current_power_up = type
    power_up_timer = duration
    power_up_changed.emit(type, duration)
    # Blaze / Purple Weed (the weed-leaf family) DELIBERATELY does not touch the
    # music. A previous session made these pickups push a music override
    # ("fresh_boost.ogg"), which re-broke a fix the founder had already asked
    # for and signed off: "You corrected the music from not changing when Lil
    # Blunt takes the weed leaf and now there's fucking music changes."
    # The level track keeps playing straight through the pickup. Do not
    # reintroduce a push_music_override here — the celebration below is what
    # sells the pickup, not a track swap.
    if type == "blaze" or type == "purple":
        _celebrate_blaze()
    else:
        AudioManager.play_sfx("powerup")
    # Analytics (task #23): which power-ups actually get used feeds the
    # founder digest + future tuning. Fire-and-forget, no-op offline.
    Web3Bridge.report_metric("powerup_used", {"type": type})

## Founder: "We need a really eccentric celebration from Lil Blunt for taking
## this leaf and a unique sound that is stoner based."
##
## Audio half lives here so it fires no matter which scene the leaf sits in;
## the visual half (spin + smoke burst + shout) is player-side, driven off the
## power_up_changed signal already emitted above. Deliberately NO music change.
func _celebrate_blaze() -> void:
    # Unique stoner-based pickup sound — a bong-rip/exhale swell, distinct from
    # the generic "powerup" chime every other pickup uses.
    AudioManager.play_sfx("blaze_leaf")
    # Lil Blunt shouts about it. 0.0 cooldown: this is a rare, deliberate beat,
    # it must never be swallowed by an unrelated bark's cooldown window.
    AudioManager.play_bark("vo_blaze_hype", 0.0)
    ScreenShake.shake(0.25, 4.0)
    blaze_celebration.emit()

func deactivate_power_up() -> void:
    # Release the Blaze music override (token-guarded — stale releases no-op,
    # so a scene change or second pickup can't restore an old track).
    if _blaze_music_token != -1:
        AudioManager.release_music_override(_blaze_music_token)
        _blaze_music_token = -1
    current_power_up = ""
    big_axe_timer = 0.0
    power_up_timer = 0.0
    power_up_changed.emit("", 0.0)

func has_power_up(type: String) -> bool:
    # The big axe survives other pickups — see big_axe_timer.
    if type == "bigaxe":
        return big_axe_timer > 0.0
    return current_power_up == type

func _process(delta: float) -> void:
    if power_up_timer > 0:
        power_up_timer -= delta
        if power_up_timer <= 0:
            deactivate_power_up()
    # Ticks on its own clock so another pickup cannot cut the axe short.
    if big_axe_timer > 0.0:
        big_axe_timer = maxf(0.0, big_axe_timer - delta)

func reset_level() -> void:
    player_health = max_health
    _clear_blaze_music_override()
    current_power_up = ""
    power_up_timer = 0.0
    big_axe_timer = 0.0
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
    big_axe_timer = 0.0
    health_changed.emit(player_health)
    total_score = 0
    coins_collected = 0
    ethereum_rings_collected = 0
    smoke_collected = 0
    smoke_changed.emit(0)
    titanx_collected = 0
    titanx_changed.emit(0)
    blaze_rush_completed.clear()
    secret_door_used.clear()
    blaze_portal_used.clear()
    vault_door_used.clear()
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

## Forget `level`'s mid-level checkpoint so its next load starts at the level's
## own spawn marker.
##
## THIS DID NOT EXIST, and player.gd called it anyway. The full-life-wipe path
## (`_respawn_or_game_over`, lives == 0) is supposed to restart the CURRENT
## level from its START — the founder's rule — and it opens by clearing the
## checkpoint so `_spawn_player` falls back to the spawn marker. Instead the
## call threw "Invalid call. Nonexistent function 'clear_checkpoint'", which
## ABORTS the rest of that function: the health/lives refill never ran and the
## `SceneRouter.load_scene` on the next line never ran either. A full wipe
## therefore left the game sitting in GAME_OVER with no reload at all.
##
## Nothing caught it because a GDScript call to a missing method is a runtime
## error, not a compile error — the script battery loads this file happily.
func clear_checkpoint(level: int) -> void:
    level_checkpoints.erase(level)

func save_session() -> bool:
    var data: Dictionary = {
        "total_score": total_score,
        "coins": coins_collected,
        "rings": ethereum_rings_collected,
        "smoke": smoke_collected,
        "titanx": titanx_collected,
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
    titanx_collected = maxi(0, int(data.get("titanx", 0)))
    _deserialize_blaze_completions(data.get("blaze_rush", {}))
    max_health = clampi(int(data.get("max_health", 3)), 1, 10)
    player_health = clampi(int(data.get("health", max_health)), 1, max_health)
    # Lives persist; no upper cap — add_life() is uncapped, so saves may
    # carry more lives than max_lives.
    lives = maxi(0, int(data.get("lives", max_lives)))
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
