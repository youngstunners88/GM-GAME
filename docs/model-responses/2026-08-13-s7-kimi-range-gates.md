<!-- dispatched: moonshotai/kimi-k3
     prompt: prompts/s7-kimi-range-gates.md
     files inlined: 2
     tokens: 15444 in / 13030 out
     cost: $0.2418
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
# Q1 — Projectile range math

`lifetime` is **not in the provided files** — `boss_projectile.gd` is missing. Two comments in distributor.gd state orbs "live 4s", so I use **lifetime = 4.0s**; confirm the exact field name/default in `boss_projectile.gd` before wiring.

**Current max travel (speed × 4.0s) vs ~1200px needed:**

| Attack | P1 | P2 | P3 |
|---|---|---|---|
| `_throw_shards` 170/210/250 | 680px ✗ | 840px ✗ | 1000px ✗ |
| `_throw_crystal_shards` 260/310/360 | 1040px ✗ | 1240px ~ | 1440px ✓ |

Worst case is the diagonal: boss spawns orbs at `+(120, 50)` while hovering ~250px above the player → real distance ≈ √(1200² + 250²) ≈ **1226px**.

**Fix (recommended — raises range, not dodge difficulty).** Set lifetime per-instance, before `add_child`, same pattern as `speed`:

- In `_throw_shards()`, after `orb.speed = ...`: `orb.lifetime = 8.0` → 1360 / 1680 / 2000px (≥11% margin all phases).
- In `_throw_crystal_shards()`, after `shard.speed = ...`: `shard.lifetime = 5.0` → 1300 / 1550 / 1800px.

Safe mechanically: stale-volley redirects are already keyed off `_volley_id` (ignored), and `die()` already `queue_free`s the `boss_projectile` group, so 8s life cannot outlive the fight. Caveat to verify in boss_projectile.gd: `lifetime` must be read at/after `_ready` (set-before-`add_child` works), and confirm orbs don't already die on wall contact (symptom says they don't — 680px is barely half the arena).

**Speed-only alternative (not recommended):** shards → `320.0 + 40.0*(phase-1)` = 1280/1440/1600; crystals → `320.0 + 50.0*(phase-1)` = 1280/1480/1680. But 170→320 is +88% orb speed — guts the Forced-Distribution redirect window. Don't.

# Q2 — S2 chase

Floor math is fine for the tested case (345 vs sprint 240 = +105px/s straight-line), but every documented gate drove a **straight-line** player. The number that kills horizontal closing against a real (weaving) player is **HOVER_ACCEL = 430**: full reversal ±345 costs 690/430 = **1.6s** of near-zero net horizontal velocity; the player reverses in ~0.1s. Boss oscillates overhead, average closing ≈ 0 → reads as "not chasing." Raising MIN_PURSUE_SPEED a fourth time does nothing for this.

**Minimal change, one constant:**
```
const HOVER_ACCEL: float = 1600.0   # was 430; reversal 0.43s, 0→345 in 0.22s
```

**Cannot confirm without the Stage 2 level file (missing)** — the script that assigns `arena_min`/`arena_max` on the distributor. If its y-span leaves <250px above the player's head (HOVER_ABOVE) — or y is passed as 0/0 — `_clamp_to_arena`'s y-clamp (which applies **no half-body inset**, unlike x) pins his centre low, and the climb lock (`BODY*0.75` = 180px band) re-arms every time he's over the player, zeroing horizontal motion regardless of any speed constant. That is the other live candidate for "not chasing **horizontally** in the real arena." Send the level file.

Gate: real-arena, real-physics test with a **weaving** player (sinusoidal ±160px, ~0.9s period, 6s). Assert avg |centre.x − player.x| over the final 4s < 200px. Pre-fix it stays >350px (reversal lag); tune thresholds on first run.

# Q3 — Headless readability gate

**Proxy:** for every `Label`/`Button` under the vault scene root — effective font px ≥ floor **and** `outline_size` ≥ 4 (and ≥ font/5) **and** `font_outline_color` opaque near-black. Buttons additionally: `custom_minimum_size ≥ (160, 48)` (founder wants OBVIOUS LARGE). Thresholds: primary ≥ 24px, `*hint*` nodes ≥ 18px.

**Pre-fix failures (gate is red on current code):** hint/altar/clerk plates at 13 < 18, readout 20 < 24, and `outline_size` = 0 everywhere (no overrides exist).

```gdscript
const MIN_PRIMARY := 24.0
const MIN_HINT := 18.0
const MIN_OUTLINE := 4

func _collect(n: Node, acc: Array[Control]) -> void:
	if n is Label or n is Button:
		acc.append(n)
	for ch: Node in n.get_children():
		_collect(ch, acc)

func test_vault_text_readable() -> void:
	var ps := load("res://src/level/vault_realm.tscn") as PackedScene  # .tscn path inferred — confirm; only vault_realm.gd was provided
	var vault := ps.instantiate()
	add_child(vault)  # real tree so theme + global_transform resolve
	var ctrls: Array[Control] = []
	_collect(vault, ctrls)
	assert(ctrls.size() >= 6, "walk found no vault text — scene wiring broken")
	var failures: Array[String] = []
	for c: Control in ctrls:
		var fs: float
		var osz: int
		var oc: Color
		if c is Label and (c as Label).label_settings != null:
			var ls := (c as Label).label_settings
			fs = float(ls.font_size); osz = ls.outline_size; oc = ls.outline_color
		else:
			fs = float(c.get_theme_font_size("font_size"))
			osz = c.get_theme_constant("outline_size")
			oc = c.get_theme_color("font_outline_color")
		var eff: float = fs * c.global_transform.get_scale().x
		var floor_size: float = MIN_HINT if c.name.to_lower().contains("hint") else MIN_PRIMARY
		if eff < floor_size:
			failures.append("%s: font %.0fpx < %.0f" % [c.get_path(), eff, floor_size])
		if osz < MIN_OUTLINE or float(osz) < eff * 0.2:
			failures.append("%s: outline %d too thin for %.0fpx" % [c.get_path(), osz, eff])
		if oc.a < 0.9:
			failures.append("%s: outline not opaque" % c.get_path())
		if c is Button and (c as Button).custom_minimum_size < Vector2(160, 48):
			failures.append("%s: button below 160x48" % c.get_path())
	assert(failures.is_empty(), "\n".join(failures))
```

Notes:
- `label_settings` branch is required — if the fix uses `LabelSettings` instead of theme overrides, `get_theme_*` sees nothing and the gate lies green.
- Godot 4.3 constraint respected: `load()` cast via `as PackedScene`, no `:=` on Variant.
- Run the identical walk against the **Fort Knox realm scene — file not provided**, send its path. Founder requirement is BOTH realms.
- Clerk/scale art wiring (Mira Voss, Gold Scale) can't be gated by me — asset paths/node names are not in the provided files. Add: assert the clerk panel and scale nodes each contain a visible `Sprite2D`/`TextureRect` with non-null `texture` once you give me the node names.

**Missing files requested:** `boss_projectile.gd` (lifetime field), Stage 2 level script setting `arena_min`/`arena_max`, Fort Knox realm, `vault_realm.tscn` path confirmation.