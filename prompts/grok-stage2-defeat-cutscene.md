# Design brief: Stage 2 boss-defeat cutscene → Gold Rush (Stage 3)

## Context: this is a sequel brief, not a first draft

I already shipped an equivalent Stage 1 boss-defeat cutscene (Auditor ->
Crystal Caverns) using an architecture you and gpt-6-astra-pro converged on
last time: a screen-space `CanvasLayer` overlay, built from in-game
assets/systems only (never a rendered video — Godot 4.3's web export only
reliably plays MUTED Ogg Theora, so a video with dialogue baked in can't
ship), driven by a single `_run()` coroutine using this project's hardened
`get_tree().create_timer(t, true, false, true)` idiom, with an independent
hard-deadline `SceneTreeTimer` guaranteeing a `finished` signal even if a
step is interrupted. That shipped as PR #63, gated, security-clean.

**This brief is for the SAME architecture, new content**: Stage 2's boss
(Distributor / "Crystalline Bureaucrat", boss_id `"crystal"`) defeated,
leading into Stage 3 (Gold Rush). Design the beat sheet; I already know how
to build the plumbing.

## What's different from Stage 1 (don't reuse those specifics)

- **Weapon focus**: Lil Blunt is already in his MINER outfit (Stage 2 sets
  this on entry) with a pickaxe (`sprite_item_pickaxe.png` — same asset as
  before). The founder's brief wants the pickaxe to feel decisive: smashing
  incoming crystal-shard projectiles, then landing the finishing blow on the
  boss.
- **Boss**: a multi-part crystal titan (blue primary + gold secondary
  "head"), fires diamond/crystal shard projectiles. Existing VO
  categories already give it "death" lines (2, randomized, via
  `BossVoiceSystem.say(self, "crystal", "death", true)` — already fires at
  the top of `distributor.gd::die()`, moments before this cutscene would
  start). This cutscene's own one-off line is a SEPARATE beat (the crystal
  shattering), not a third death-pool entry.
- **Destination palette**: Stage 3 is Gold Rush — this project's own gold
  color constant is `Color(0.95, 0.8, 0.3, 1.0)` (from
  `level_03_gold_rush.gd`). The palette wash at the end should land near
  that, not blue-purple.
- **Reusable art**: `src/assets/art/vaults/fort_knox_vault_door.png`
  already exists in this project (a vault-wheel door asset) — use it for
  the "gate opens into Stage 3" beat instead of a plain ColorRect, since a
  real asset exists this time.
- **Exit flow is simpler**: `distributor.gd::die()` has NO victory_screen —
  after its own death tween it just shows a plain "LEVEL COMPLETE!" Label
  for 3s, then `queue_free()` + `SceneRouter.load_scene(next_level, DIAMOND)`.
  The cutscene replaces/precedes that Label-and-wait, not a Web3 screen.
- **No outfit swap needed**: Lil Blunt is already dressed for mining;
  Stage 3 doesn't change his outfit either (no MINER->? call exists there).

## The actual question

Design ONLY the beat sheet (visual + audio + timing), not the code. Total
runtime target 7-9 seconds (matching Stage 1's actual shipped ~8s, not the
brief's literal "15s" — that number came from an assumption of a rendered
video; an in-engine sequence this frozen-input-window doesn't need to hit an
exact runtime, just read clearly). Beats, in order:

1. Crystal barrage vs. pickaxe defense (quick, reads as combat climax)
2. Close-range smash — cracks/shatter on the boss, Lil Blunt VO
   ("Nice diamonds. Mine now." or "Pickaxe beats crystal, baby.")
3. Finishing blow + collapse — boss's own VO already fired; this beat is
   the visual shatter/collapse, screen-space (shard-burst using the same
   kind of particle technique as Stage 1's smoke beat, but crystal-colored:
   blue/purple/gold, sharp not soft)
4. Gate opens (using the real `fort_knox_vault_door.png` asset) + gold
   palette wash signaling Stage 3

For each beat: exact duration, which existing asset/technique it uses (name
it, or say "new ColorRect/particle, same technique as Stage 1 beat N" when
no asset fits), and where the one VO line fires.

## Hard constraints

- Screen-space CanvasLayer overlay only, same as Stage 1 — no world-space
  actor staging, no touching the live player node's transform/visibility.
- Do not touch `distributor.gd`'s existing tween, VO, or scoring — only
  where the new cutscene inserts between the tween and the Label/scene-load.
- Do not invent a new weapon, a new boss part, or change Lil Blunt's look —
  stay inside the founder's actual reference beats (pickaxe smashes crystal,
  gate opens gold).
- Keep it ≤ 9 real seconds — this is a frozen-input interstitial, not a
  cinematic; shorter reads better and the founder's asked-for 15s target was
  written for a different medium.

## Output format

A numbered beat table: `# | start-end (s) | visual (asset/technique) | audio
(VO or SFX) | failure-safety note (what happens if the named asset were
missing)`. No prose padding.
