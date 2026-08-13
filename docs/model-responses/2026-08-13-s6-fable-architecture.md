<!-- dispatched: anthropic/claude-fable-5
     prompt: prompts/s6-fable-architecture.md
     files inlined: 1
     tokens: 2250 in / 2607 out
     cost: $0.1529
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
# T1 — Vault clerk economy

**(a) Counter placement.** Put both in `src/autoload/goldmine_system.gd` alongside `diamonds_balance`:

```gdscript
const BLAZE_DIAMOND_STACK_LIMIT: int = 99
var blaze_diamonds: int = 0

func add_blaze_diamond(n: int = 1) -> int:
    blaze_diamonds = clampi(blaze_diamonds + n, 0, BLAZE_DIAMOND_STACK_LIMIT)
    return blaze_diamonds
```
Persist in whatever dict `goldmine_system.gd` already saves (`diamonds_balance` etc.) — add `"blaze_diamonds": blaze_diamonds` to save, `blaze_diamonds = int(data.get("blaze_diamonds", 0))` on load. (I don't have the save function in the provided files; if it lives elsewhere, tell me the path.)

**(b) Crush rule — mint $DIAMONDS.**

```gdscript
const CRUSH_YIELD: int = 5  # 1 Blaze Diamond -> 5 $DIAMONDS

func crush_blaze_diamonds(amount: int) -> int:
    var n: int = clampi(amount, 0, blaze_diamonds)
    blaze_diamonds -= n
    var minted: int = n * CRUSH_YIELD
    diamonds_balance += minted
    return minted
```
Justify: it closes the loop — Blaze Rush skill feeds the ONE token that `stake_diamonds()` already consumes, so the clerk's two questions ("stake? crush?") are one funnel, not two disconnected sinks.

**(c) Dialogue panel.** One scene: `CanvasLayer > PanelContainer > VBox > Label (prompt) + Label (amount) + Label (hint)`. Clerk NPC in the vault has an `Area2D`; on player overlap + `interact`, instance the panel. Panel script holds `var amount: int = 0`, in `_unhandled_input`: `ui_left`/`ui_right` step ±1 (hold Shift → ±10 is optional, don't add new actions), `interact` confirms → calls `GoldmineSystem.stake_diamonds(amount, days)` or `crush_blaze_diamonds(amount)`, `ui_cancel` closes. UI is a dumb shell; ALL clamping lives in the autoload so headless tests never touch the UI.

**Failure mode:** clamping in the UI instead of the autoload → headless test passes with negative/overflow crush. Fix: `crush_blaze_diamonds` clamps internally (above).

**GATE:** `GoldmineSystem.blaze_diamonds = 3; assert(GoldmineSystem.crush_blaze_diamonds(10) == 15 and GoldmineSystem.diamonds_balance == before + 15)` — fails now: `blaze_diamonds`/`crush_blaze_diamonds` don't exist.

# T2 — S2 boss projectiles

**Recommend A.** Forced Distribution → Pool Drain is the boss's signature; deleting the volley guts a mechanic to fix a skin. `_throw_crystal_shards()` already proves the hide-dot+poly pattern — copy it in `_throw_shards()`:

```gdscript
p.tint = Color(0.7, 0.9, 1.0, 0.0)  # hide the dot circle
var poly := Polygon2D.new()
poly.polygon = PackedVector2Array([
    Vector2(0, -10), Vector2(7, 0), Vector2(0, 10), Vector2(-7, 0)
])  # classic diamond rhombus
poly.color = Color(0.75, 0.95, 1.0, 0.95)
p.add_child(poly)
```
Redirect/homing keep working untouched: `redirected` and movement live on the projectile root (the node `_throw_shards` spawns), and the Polygon2D is a child that just rides along. Optionally `poly.rotation = p.velocity.angle() + PI/2` per-frame in the projectile if it has a `_process` — but only if the projectile script is editable; the redirect logic must not read anything from the child.

**Failure mode:** setting the whole tint alpha to 0 also kills any modulate-based hit-flash on the projectile — if `boss_projectile.tscn` flashes via `tint`, flash the child poly instead.

**GATE:** spawn the shard volley headlessly; assert every projectile from `_throw_shards()` has ≥1 `Polygon2D` child AND `tint.a == 0.0` — fails now (current orbs are opaque dots with no poly child).

# T3 — S3 boss chase

Two-line fix inside the "player above" hop condition: require real horizontal intent, and update `direction` from the hop itself even inside the dead zone:

```gdscript
var dx: float = player.global_position.x - global_position.x
var player_above: bool = player.global_position.y < global_position.y - 80.0
if player_above and absf(dx) > TURN_DEAD_ZONE and _gap_crossable(direction):
    direction = signf(dx)   # commit direction BEFORE hopping
    _hop()
```
i.e. (1) gate the above-hop on `absf(dx) > TURN_DEAD_ZONE` so a roughly-overhead player can't trigger a stationary pogo; when the player is overhead-but-not-lateral, fall through to `_ground_chase(delta, speed)` and keep walking. (2) When the hop does fire, set `direction` first so the hop carries horizontal velocity. Ledge suicide stays safe: `_gap_crossable(direction)` still gates the hop and `_ground_chase`'s ledge-sense still zeroes `velocity.x` at lips — don't touch either.

**Failure mode:** removing the `_gap_crossable` check while "fixing" the hop → regressed ledge suicide. Keep it in the AND chain.

**GATE:** headless sim, player kiting 200px to the side and 100px above for 3s of physics ticks → assert `absf(boss.global_position.x - start_x) > 120.0` — fails now (boss pogos in place, Δx ≈ 0).

# T4 — Fort Knox depth

**Second chamber:** a "Mine Shaft" behind a breakable gold-vein wall in the current gold room — descending platforming beat with 3 collapsing-timer platforms (reuse whatever one-way platform exists; add a `Timer` that frees collision 0.6s after body_entered). Bottom holds the interactable.

**Interactable: the Assay Scale.** An `Area2D` station where Lil Blunt deposits `gold_balance` to convert into a Fort Knox stake via the EXISTING `stake_in_fort_knox(amount, days)` — same clerk-panel scene from T1 with different labels, so zero new UI code. Fits gold-mine identity (you assay ore → certified vault gold) and the logic is already headless-callable.

**Failure mode:** collapsing platforms freeing collision via `queue_free()` on the physics-callback frame in web non-threaded export → error spam; defer with `set_deferred("disabled", true)` on the CollisionShape2D instead.

**GATE:** load the Fort Knox scene headlessly; assert `get_tree().get_nodes_in_group("assay_scale").size() >= 1` (and stake path: `stake_in_fort_knox` reachable from its interact) — fails now: no second chamber, no `assay_scale` group exists.