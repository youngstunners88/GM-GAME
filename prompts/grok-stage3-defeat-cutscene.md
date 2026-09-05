# Design brief: Stage 3 FINAL boss-defeat cutscene → Episode 1 close

## Context: third of a series, same proven architecture

I've already shipped two equivalent cutscenes (PR #63, gated, security-clean,
Kimi-audited with zero open findings on the second one): Stage 1 (Auditor)
and Stage 2 (Distributor), both screen-space `CanvasLayer` overlays built
from in-game assets only, driven by one `_run()` coroutine using
`get_tree().create_timer(t, true, false, true)`, with an independent
hard-deadline `SceneTreeTimer` guaranteeing `finished` fires no matter what.
Never a rendered video — Godot 4.3's web export only reliably plays MUTED
Ogg Theora, which would cost the dialogue that's the point of each scene.

**This is the FINALE**: Stage 3's boss (Claim Jumper — the bandit riding a
skull-emblazoned dynamite minecart, boss_id `"bandit"`) defeated, closing
Episode 1. This is the last level in the game today — no Stage 4 exists.
After this boss's existing death tween, the game currently shows a plain
"GAME COMPLETE!" Label for 3s then routes to the main menu. That
`SceneRouter.load_scene("res://src/ui/main_menu.tscn", DIAMOND)` +
`queue_free()` call stays exactly as-is — this cutscene only replaces the
plain Label, same pattern as Stage 2.

## Founder's required beats (from the brief) — richer than Stage 1/2, this is the finale

1. **Boss resistance** — sells that the Claim Jumper is dangerous, not a
   pushover (dynamite, still in control)
2. **Outthink the environment** — Lil Blunt uses the mine itself against him
   (not more punching)
3. **Bitcoin token leverage** — Lil Blunt plants/throws real BTC tokens
   (must read as unmistakably Bitcoin, not generic coins) into the dynamite
   load; detonation wrecks the cart
4. **Deeper into the mine** — a separate mining cart, Lil Blunt boards it,
   rides deeper (descending, not lateral), ending on motion, not a static
   pose, before the existing GAME COMPLETE routing takes over

## What already exists (reuse, don't invent new art)

- `sprite_item_wbtc.png` / `sprite_item_coin-btc.png` — real Bitcoin token
  sprites already in this game (already used elsewhere for collectibles) —
  use ONE of these for the token-leverage beat, not a generic coin.
- `sprite_boss_bandit-cart.png` — the boss's own live sprite IS the
  skull-emblazoned dynamite minecart (already exists, already what
  `claim_jumper.gd`/`claim_jumper.tscn` render as the boss).
- `sprite_prop_minecart-fast.png` / `sprite_prop_minecart-slow.png` — plain
  minecart sprites already in the game, usable for the "separate mining
  cart Lil Blunt boards to go deeper" beat.
- `sprite_item_pickaxe.png` — same pickaxe used in Stage 1/2's cutscenes.
- This project already has an established telegraphed-explosion visual
  language (`src/boss/dynamite.gd`): a pulsing fuse dot + an expanding
  warning ring that speeds up before detonating. Reuse that LANGUAGE (pulse
  + ring), not necessarily that exact file, for the dynamite beats here.
- The boss's own existing "death" VO category already fires at the top of
  `die()` before this cutscene starts (2 randomized lines, one of which is
  literally "The tokens—!" per boss-voices.json — check the real file for
  the actual current lines rather than assuming). Do not retrigger it.

## The actual question

Design ONLY the beat sheet (visual + audio + timing) for an IN-ENGINE
screen-space sequence, not a rendered video. Target 9-12 real seconds
(longer than Stage 1/2's ~7-8s since this is the finale with 4 required
beats, but still a frozen-input interstitial, not a literal 20s cinematic —
that number assumed a rendered video). Beats, in order, each with: exact
duration, which existing asset/technique it uses (name it, or say "new
ColorRect/particle, same technique as beat N" when nothing fits), and where
each VO line fires:

1. Dynamite resistance (boss looks dangerous, still in control)
2. Environmental outthink (Lil Blunt uses the mine, not just the pickaxe)
3. Bitcoin token plant + detonation (unmistakably BTC-branded, gold/orange
   blast, wrecks the cart)
4. Descending mine cart exit, ending on motion

One Claim Jumper line (early aggression OR defeat reaction — pick ONE, not
both, the boss's own randomized death line already covers the other beat)
and up to two short Lil Blunt lines (mid-triumph + exit line), per the
founder's "max two short lines per character."

## Hard constraints

- Screen-space `CanvasLayer` overlay only, exactly like Stage 1/2 — never
  touch the live player node's transform/visibility, never world-space
  actor staging.
- Do not touch `bandit_boss.gd`'s existing tween, VO, scoring, or the final
  `queue_free()` + `SceneRouter.load_scene(main_menu)` — only where the new
  cutscene inserts between the tween and the Label it replaces.
- Do not invent a Stage 4 or any new level — this closes Episode 1 and
  correctly returns to the main menu.
- Do not soft-pedal the boss in beat 1, and do not substitute a generic
  coin for the Bitcoin token in beat 3 — both are explicit founder
  requirements.
- Every cross-node tween reference must be validity-guarded on BOTH sides
  (Stage 1 shipped with exactly one gap here — an unguarded second
  reference — caught in self-review and independently confirmed by a code
  audit; Stage 2 closed that gap from the start and passed a clean audit).

## Output format

A numbered beat table: `# | start-end (s) | visual (asset/technique) | audio
(VO or SFX) | failure-safety note`. No prose padding.
