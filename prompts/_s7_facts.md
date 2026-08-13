# SESSION 7 SHARED FACTS — Lil Blunt Adventure (Godot 4.3 GDScript 2D platformer)

You are a co-worker model advising on a specific change. You cannot run the
game. Be concrete, terse, Godot-4.3-correct. Do NOT restate the codebase.

## Founder live complaints (from real play + screenshots)
1. ALL vault/stake/crush/scale TEXT is far too small and has NO outline —
   unreadable on the busy blue/gold backdrops. Ship-blocker, repeated.
2. In the Diamond Vault the player "can't see or use the diamond tokens I
   collected" — the clerk options are tiny/undecodable; wants OBVIOUS LARGE
   buttons for: show holdings, STAKE diamond tokens (0..owned), CRUSH Blaze
   Diamonds (0..stack limit), confirm.
3. Stage 2 boss's diamond bomb + shards "don't reach Lil Blunt when he's far"
   — projectiles must travel across the whole arena. And the boss is "STILL
   not chasing" horizontally in the real Stage 2 arena.
4. Lil Blunt is too small — make him slightly bigger (keep collision playable).
5. One oversized on-screen element is distracting — shrink/reposition it.
6. The stake "scale" instrument is unclear and badly positioned; founder art
   (a steampunk BTC/gold balance) should be the scale, with large outlined
   left/right values and understandable motion, in BOTH Diamond Vault & Fort Knox.

## Current code facts
- Vault UI lives in `src/level/vault_realm.gd`. Labels use
  add_theme_font_size_override only (readout 20, clerk prompt 18, amount 26,
  hint 13, altar/clerk plates 13). NO font_outline_color / outline_size
  overrides anywhere -> no outline. The clerk is a text panel driven by
  ui_left/ui_right to adjust an amount + interact to confirm (no big buttons).
- Economy (src/autoload/goldmine_system.gd): `diamonds_balance` ($DIAMONDS
  tokens), `stake_diamonds(amount,days)`, `blaze_diamonds` +
  `crush_blaze_diamonds(amount)` (mints 5 $DIAMONDS each), BLAZE_DIAMOND_STACK_LIMIT=20.
- Stage 2 boss (src/boss/distributor.gd): `_throw_shards()` fires diamond
  projectiles at speed 170+40*(phase-1); `_throw_crystal_shards()` at
  260+50*(phase-1). Both are boss_projectile.tscn with a diamond/shard
  Polygon2D and tint alpha 0 (no circles — fixed session 6). Boss chases via
  `_hover_pursue` with MIN_PURSUE_SPEED 345; arena bounds set by the level.
- Player render: `src/player/lil_blunt_visual.gd` draws the 49x72 outfit
  texture at native scale (_spr.scale = 1); feet anchored via
  `_spr.position.y = FEET_LOCAL_Y(16) - tex_h/2 + _art_offset_y`. Collision box
  is a 32px RectangleShape2D on the Player. No render-scale field exists yet.

## Godot 4.3 label outline API (confirm/correct me)
- `label.add_theme_font_size_override("font_size", N)`
- `label.add_theme_color_override("font_outline_color", Color.BLACK)`
- `label.add_theme_constant_override("outline_size", K)`  # K in px, ~ N/4

## Hard constraints
- Web export stays non-threaded. Never hardcode wallet/contract addresses.
- Godot 4.3: `var x := <Variant>` (e.g. from get_first_node_in_group()) is a
  HARD parse error — type explicitly.
- Every fix needs a real-physics/real-scene headless gate that FAILS on the
  pre-fix code. Founder art exists (Mira Voss clerk, Gold Scale) — wire it,
  don't invent a different clerk/scale.
