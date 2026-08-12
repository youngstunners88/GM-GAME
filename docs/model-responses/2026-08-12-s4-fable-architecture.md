<!-- dispatched: anthropic/claude-fable-5
     prompt: prompts/s4-fable-architecture.md
     files inlined: 13
     tokens: 35085 in / 15462 out
     cost: $1.1240
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
# A. Vaults → Blaze-class separate scenes

## A1. Entrance

New `src/level/vault_door.gd/.tscn` — a straight clone of `secret_door.gd`, parameterized:

```gdscript
extends Area2D
@export var realm_path: String = "res://src/level/diamond_vault_realm.tscn"
@export var entrance_kind: String = "vault"
var _used := false

func _ready() -> void:
	if GameManager.is_side_entrance_used(entrance_kind, GameManager.current_level):
		queue_free()
		return
	body_entered.connect(_on_body_entered)
	# (copy secret_door's pulse tween)

func _on_body_entered(body: Node2D) -> void:
	if _used or not body.is_in_group("player"):
		return
	_used = true
	GameManager.mark_side_entrance_used(entrance_kind, GameManager.current_level)
	GameManager.secret_return = {
		"scene_path": get_tree().current_scene.scene_file_path,
		"position": global_position,
	}
	AudioManager.play_sfx("powerup")
	ScreenShake.shake(0.2, 4.0)
	SceneRouter.load_scene(realm_path, SceneRouter.Transition.SMOKE)
```

**Reuse `secret_return`** — do not add a `vault_return` dict. Only one bonus scene can be active at a time; `level_base._spawn_player()` already consumes `secret_return` and drops the player at `position + Vector2(40,-50)`. Zero new resume code. One-visit-per-stage via `entrance_kind = "vault"` in the existing side-entrance API (assumption: `is_side_entrance_used(kind, level)` keys on an arbitrary string — verify; if it's an enum, add a "vault" entry).

**Level wiring** (`level_02_crystal_caverns.gd` / `level_03_gold_rush.gd::_setup_depth_routes()`): replace the `protocol_vault` instantiate with `vault_door` at the same position, `realm_path` = diamond realm (L2) / fort knox realm (L3).

**kill_zone_gaps: yes, REMOVE.** No chamber below the surface means the gap is now a hole in the pit-death net. Delete the `kill_zone_gap_range()` registrations from both levels. **Missing fact:** I don't have `_setup_depth_routes()` source, so I can't see whether the floor *mouth* (the 100/140px opening the player dropped through) is carved into the level's ground segments or was implied by the vault. If the level carves it, restore solid ground there — the door is now a walk-into Area2D on the surface, secret_door-style.

**Edge case:** if the player game-overs *inside* a vault realm, `secret_return` stays set and the next fresh entry into that level will spawn at the door. Clear `secret_return` in `GameManager.reset_session()` / the game-over path (verify whether reset_session already does — not in provided files).

## A2. The scenes

`src/level/diamond_vault_realm.gd/.tscn` + `fort_knox_realm.gd/.tscn`, modeled on `secret_realm.gd`. **Missing fact:** `secret_realm.gd` source wasn't provided — I need it to copy its exact player-spawn + camera-limit code. Skeleton pending that:

```gdscript
extends Node2D
const REALM_W := 2304.0
const REALM_H := 768.0
const FLOOR_Y := 648.0            # floor top
const PLAYER_SPAWN := Vector2(160, FLOOR_Y - 100)
const PORTAL_X := 2140.0

func _ready() -> void:
	_build_backdrop()      # ParallaxBackground → ParallaxLayer, diamond_vault_backdrop.png / fort_knox_backdrop.png (already referenced by protocol_vault)
	_build_floor()         # StaticBody2D layer 1, full REALM_W span — no pits, ever
	_build_walls()         # x=0 and x=REALM_W
	_build_stake_area()    # A3
	_spawn_return_portal() # return_portal.tscn at (PORTAL_X, FLOOR_Y - 60)
	_spawn_player()        # copy secret_realm's spawn + camera limits (limits: 0, 0, REALM_W, REALM_H)
```

Here a `ParallaxBackground` IS correct (unlike the in-vault Sprite2D note in protocol_vault) — the whole screen is the realm, same as the boss arenas.

## A3. Stake loops

Reuse protocol_vault's **proven** interact pattern (owner-side `_player_at_*` flags + `Input.is_action_just_pressed("interact")` + `MobileInputHandler.touch_interact` — the melt_forge convention). Two altars per realm:

- **Altar A (288-DAY POOL)** at x≈800, safe. **Altar B (2888-DAY POOL)** at x≈1500, behind a hazard lane (port the crystal-shard drop / gear guard from protocol_vault, x 1150–1400) — that's the risk half of payoff/risk.
- Each interact press stakes **25% of current balance (min 1)**.

Diamond Vault needs one new GoldMineSystem function, mirroring the verified `stake_in_fort_knox` signature:

```gdscript
var diamond_shares: int = 0
signal diamond_shares_changed(new_shares: int)

func stake_diamonds(amount: int, days_committed: int) -> int:
	amount = clampi(amount, 0, diamonds_balance)
	if amount <= 0:
		return 0
	diamonds_balance -= amount
	diamonds_changed.emit(diamonds_balance)
	var shares := amount * (2 if days_committed >= 2888 else 1)
	diamond_shares += shares
	diamond_shares_changed.emit(diamond_shares)
	return shares
```

This is cleaner than gamifying via `collect_diamonds` (that's the *collection* burn, already applied when the diamonds were picked up; staking them again through it would double-burn and misrepresent the protocol).

- Diamond realm altar calls: `GoldMineSystem.stake_diamonds(amt, 288)` / `(amt, 2888)`.
- Fort Knox altar calls: `GoldMineSystem.stake_in_fort_knox(amt, 288)` / `(amt, 2888)` (exists, verified). Also drop a `melt_forge.tscn` instance in Fort Knox — real entity, exercises `melt_gold`.

**Readout:** a `CanvasLayer` Label per realm, refreshed from `diamonds_changed`/`diamond_shares_changed` (or `gold_balance`/`fort_knox_shares` for Fort Knox): `DIAMONDS 24 | STAKED 12 | SHARES 18 (2888d = 2x)`. On stake: `AudioManager.play_sfx("powerup")`, `ScreenShake.light()`, floating `+N SHARES` label.

## A4. Exit

`return_portal.tscn` instance — its existing `secret_return.scene_path` load + `_spawn_player()`'s position resume delivers exactly the founder's "reappear where you entered." **Yes, add the Blaze watchdog:** copy `_arm_exit_watchdog()` from `blaze_exit.gd` into `return_portal.gd` (armed after `load_scene`). SceneRouter's silent `_loading_path` no-op is a known stranding vector and "vault exit must never soft-lock" is a hard constraint; this also hardens the Smoke Lounge for free.

# B. Claim Jumper

**B1 — back-facing.** Two stacked bugs:
1. `claim_jumper.tscn` never sets `art_faces_right` on the BossSprite, so it defaults `true`. Pending vision confirmation that `sprite_boss_bandit-cart.png` faces left (same art family and same symptom as the auditor, which needed `false`): set `art_faces_right = false` on the `$ColorRect` node in the tscn.
2. The `absf(velocity.x) > 12` gate freezes facing whenever the ledge sense / clamp / VULNERABLE brake zeroes velocity. Delete the `set_facing` call in `_ground_chase()` and face the *player* every frame at the top of `_physics_process` (after the `is_dead` return):

```gdscript
var plf := get_tree().get_first_node_in_group("player")
if plf:
	var dxf: float = plf.global_position.x - (global_position.x + HALF_BODY)
	if absf(dxf) > TURN_DEAD_ZONE:
		boss_sprite.set_facing(dxf > 0.0)
```

**B2 — "stops advancing, only jumps straight up."** The mechanism is the ledge sense + hop interacting: `_ground_chase` zeroes `velocity.x` at the lip, *then* PATROL triggers the hop (`at_ledge and _gap_crossable`), but with velocity.x already zeroed the hop is purely vertical — he lands on the same lip and loops forever. Minimal fix, in PATROL's hop block:

```gdscript
if want_hop:
	velocity.y = HOP_VELOCITY
	if at_ledge and _gap_crossable(direction):
		velocity.x = patrol_speed * direction   # commit forward — a landing is confirmed
	_hop_cooldown = 0.7
```

Airborne frames skip the ledge sense (`if is_on_floor()`), so the carry persists; `_gap_crossable` gates it, so the ledge-fall death bug cannot return, and `_clamp_to_arena` still bounds him. Secondary check: `_ledge_ahead` probes 156px past centre (toe+16) — on any Level 3 arena platform narrower than ~320px he'll be perma-`at_ledge`. **Missing fact:** the actual `boss_arena` geometry in `level_03_gold_rush.gd` — send it so I can verify the probe against real platform widths.

**B3 — explosion no damage.** Root cause: off-by-one in the await. `get_tree().physics_frame` emits at the **start** of the next physics frame, *before* the step that registers the new Area2D's overlaps — so `get_overlapping_bodies()` reads pre-registration state and returns empty every time. Replace the ghost-Area2D dance with a synchronous shape query in `_explode()`:

```gdscript
var space := get_world_2d().direct_space_state
var params := PhysicsShapeQueryParameters2D.new()
var circle := CircleShape2D.new()
circle.radius = explosion_radius
params.shape = circle
params.transform = Transform2D(0.0, global_position)
params.collision_mask = 2          # player
params.collide_with_bodies = true
for hit in space.intersect_shape(params, 8):
	var body: Node = hit.get("collider")
	if body and body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(1)
```

No await, no cleanup, no frame-timing dependency. Secondary: dynamite spawns at `player_pos + (0,-80)`, so the blast centre floats 80px up — with radius 100 the ground coverage below the centre is only 20px past the player's origin. Bump `explosion_radius` to **120** so standing on the marker is unambiguously a hit. I-frames (1.0s post-hit) can still legitimately eat a blast right after contact damage — acceptable, but that's not the founder's case (clean stand-in-blast).

# C. The "hammer" — fix path per candidate

- **BIG AXE (HUD "BIGAXE"):** most likely complaint is it not breaking things in its path. `axe.gd`'s collision deliberately excludes World (layer 1) — so `_on_body_entered` never fires for layer-1 breakable blocks and `_smash_destructible` is dead against them. Fix: in `_ready()`, when `big`, OR-in the World bit to `collision_mask`; piercing is safe because a plain floor hit falls through all branches and never despawns. **Missing:** the breakable-block script + its layer to confirm.
- **PICKAXE tool:** "doesn't work" = expired (20s duration) or founder walked into a non-breakable. Fix: HUD countdown for "PICKAXE", and verify the breakable's walk-into check actually queries the active power-up type. **Missing:** the breakable/boulder script and `power_up_handler` state API.
- **Base thrown axe:** strong sleeper candidate given this is Stage 3 — `claim_jumper.take_damage()` no-ops outside VULNERABLE, so axing the boss mid-chase looks exactly like "this hammer doesn't work." Fix: on gated hits, play a deflect clank + white spark + brief boss flash so the gate reads as armor, not a bug (add an `else` feedback branch in `take_damage`, or have `_on_hitbox_area_entered` spawn the deflect when not vulnerable).

Apply whichever the vision model confirms; all three are cheap and non-conflicting.

# D. Stage 3 respawn

Confirmed root cause: `get_checkpoint(1)` teleports to a Level-1 coordinate inside the Level-3 scene. Delete the cross-level fallback and respawn on last safe ground. In `player.gd`:

```gdscript
# --- fields ---
var _last_safe_position: Vector2 = Vector2.ZERO
var _prev_safe_position: Vector2 = Vector2.ZERO
var _safe_pos_timer: float = 0.0

# --- in _physics_process(delta), while alive ---
if is_on_floor():
	_safe_pos_timer -= delta
	if _safe_pos_timer <= 0.0:
		_safe_pos_timer = 0.5
		_prev_safe_position = _last_safe_position if _last_safe_position != Vector2.ZERO else global_position
		_last_safe_position = global_position
```

```gdscript
# --- _respawn_or_game_over(), lives-remain branch, replacing the fallback chain ---
var checkpoint := GameManager.get_checkpoint(GameManager.current_level)
if checkpoint != Vector2.ZERO:
	global_position = checkpoint + Vector2(0, -50)
elif _prev_safe_position != Vector2.ZERO:
	global_position = _prev_safe_position + Vector2(0, -10)   # last safe GROUND, not death pos
else:
	global_position = GameManager.player_position + Vector2(0, -260)
```

The two-slot buffer (`_prev_safe_position`) means a pit death respawns at the sample *before* the lip, not on a crumbling edge sampled the same instant. Checkpoint-first ordering is preserved for levels that have one; the 1.5s respawn invincibility already covers hazards near the safe spot. Note `_last_safe_position` also matches the founder's literal ask ("reappear exactly or close to where he died") for combat deaths on solid ground.