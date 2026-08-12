# SESSION 4 — SHARED FACTS (full-env vaults + S2/S3 bosses + hammer + S3 respawn)

Founder prompt: docs/founder-prompts/PROMPT_VAULTS_FULL_ENV_LIKE_BLAZE_BOSSES_HAMMER.md
Baseline: master `131c204` / export `ab46ab5`. New Claude session; prior chat
context gone. Founder attached 6 screenshots (a vision model is confirming them
in parallel — descriptions below are from the orchestrating Claude viewing them
directly, trust them).

## The founder's verdict, verbatim, per screenshot
1. Diamond Vault entrance: "This is just a whole. Its supposed to take us into
   the next element of the Diamond vault JUST AS ENTERING THE BLAZE RUSH TAKES
   US TO A DIFFERENT ENVIRONMENT COMPLETELY! ... This environment should be
   where the player can decide to STAKE THEIR DIAMONDS that they have collected
   ... as a gamified example of the real application." (Screenshot shows the
   player dropped into the current in-level pit — the shallow chamber from last
   session. REJECTED.)
2. Stage 2 boss (The Distributor): "still not chasing!!! He's still not firing
   the diamonds nor the shards which makes his attack the same as the 1st boss."
   (A prior session moved the crystal-shard attack to rotation slot 0, proven
   in a headless gate to fire at ~2.2s. The founder still sees it broken LIVE.)
3. Stage 3 (Gold Rush): "This hammer doesnt work" — pointing at something near
   the player. NOTE: there is NO "hammer" anywhere in the codebase (grep -ri
   hammer = 0 hits). The tools that exist are: the thrown AXE (base attack,
   axe.gd), the BIG AXE power-up (big_axe.gd — HUD shows "BIGAXE" in another
   screenshot), and the PICKAXE tool (pickaxe_tool.gd — smashes boulders/breaks
   blocks by walking into them). The vision model is identifying which of these
   the founder calls "the hammer" from the screenshot.
4. Fort Knox entrance: same complaint as #1 — "supposed to take us into the next
   element of Fort Knox just as entering blaze rush takes us to a different
   environment completely! ... when Lil Blunt dies in stage 3 he appears
   somewhere else! He must reappear exactly or close to where he died!"
5. Stage 3 boss (Claim Jumper): "the boss has tried to blow me up but it didnt
   do any damage! ... And why is his back facing Lil Blunt?" (Screenshot: a
   large orange dynamite explosion mid-screen; the boss on the right visibly
   facing AWAY from the player.)
6. Stage 3 boss: "The boss doesnt move beyond this point and only jumps directly
   up. He's way too easy to kill."

## ARCHITECTURE LOCK (founder, non-negotiable)
The vaults must be **Blaze-Rush-class full-environment loads** — a SEPARATE
SCENE with a full backdrop change — NOT an in-level pit with platforms. The
current `protocol_vault.gd` (an in-level Node2D chamber, from last session) is
explicitly rejected and must be replaced or wrapped with a scene-transition
design. "Do not defend the pit."

## THE EXACT PATTERN TO FOLLOW ALREADY EXISTS IN THIS CODEBASE
The **Smoke Lounge secret realm** is already a Blaze-class separate-scene bonus
environment with a clean enter→explore→return loop. Reuse its plumbing:
- `secret_door.gd` (Area2D entrance): on player contact, stores
  `GameManager.secret_return = {scene_path, position}` then
  `SceneRouter.load_scene(REALM)`. One-visit-per-stage via
  `is_side_entrance_used("secret", level)` / `mark_side_entrance_used`.
- `secret_realm.gd` (the full scene): code-authored, parallax backdrops, its
  own camera limits, content, and a `return_portal` instance.
- `return_portal.gd`: on contact, `SceneRouter.load_scene(secret_return.scene_path)`.
- `level_base.gd::_spawn_player()`: if `secret_return.scene_path == this scene`,
  spawns the player at `secret_return.position + Vector2(40,-50)` and clears it.
  THIS IS THE RESUME MECHANISM — return-to-entry-position is already solved.
- Blaze Rush uses the parallel `dash_return` dict + a `save_checkpoint(level,
  990+level, portal_pos)` trick + an exit watchdog (belt-and-braces so the
  player is never stranded). See blaze_exit.gd excerpt.

So a "full-environment vault" = a new `secret_door`-style entrance where the pit
is now + a new code-authored vault scene (model on secret_realm.gd) with the
diamond-stake / gold interactables + a `return_portal`. The return-to-stage
plumbing is already proven; do not reinvent it.

## Diamond staking — the gamified protocol loop the founder wants
The player collects DIAMONDS during play (HUD shows "DIAMONDS 31/39" in the
screenshots). GoldMineSystem already tracks diamonds:
- `GoldMineSystem.collect_diamonds(n)` (applies a 20% burn per the whitepaper),
  `GoldMineSystem.diamonds_balance` (verify exact member name), a
  `diamonds_changed` signal. There is also `mine_gold`, `gold_balance`,
  `forfeit_to_auction`, `settle_auction`, `fort_knox_shares`,
  `auction_gold_pool` (used by claim_jumper.die()'s Gold Rush Auction
  settlement). The Diamond Vault stake loop should commit collected diamonds
  into a readable staking action with a payoff/risk, using these real systems —
  a gamified example of the DIAMONDS protocol's three-payout-pool staking.

Real GoldMineSystem primitives already implemented (verified signatures):
- `collect_diamonds(raw:int) -> int` (20% burn, returns kept), `diamonds_balance:int`,
  `diamonds_changed(new:int)` signal.
- `stake_in_fort_knox(amount:int, days_committed:int) -> int` (returns shares;
  288 days = base, 2888 days = 2x; the real Fort Knox GOLD staking).
- `melt_gold(amount_to_melt:int, staked_amount:int) -> float` (melt bonus).
- `mine_gold`, `gold_balance`, `fort_knox_shares`, `forfeit_to_auction`,
  `settle_auction`, `xaut_balance`.
- There is NO `stake_diamonds` yet — the Diamond Vault stake loop either adds a
  DIAMONDS-side staking function (mirroring stake_in_fort_knox, for the DIAMONDS
  three-pool model) or gamifies commit/burn via collect_diamonds. Propose the
  cleanest real-protocol-faithful loop.

## T4 — Stage 3 boss (Claim Jumper) real facts
- `claim_jumper.tscn` has NO `art_faces_right` line on its BossSprite (ColorRect
  node), so it DEFAULTS to `true` (art assumed to face right). `boss_sprite.gd`:
  `set_facing(face_right)` sets `flip_h = (face_right != art_faces_right)`. If
  `sprite_boss_bandit-cart.png` actually faces LEFT, every `set_facing(true)`
  (moving right toward the player) shows his BACK — exactly the auditor's old
  bug, which was fixed by setting `art_faces_right = false` in auditor.tscn.
  (The tax-collector and this bandit-cart are both 131-141x150 art.)
- `set_facing` is only called when `absf(velocity.x) > 12.0`. If the boss's
  horizontal velocity is ~0 (stuck at a ledge / clamp / a braking state), facing
  never updates and freezes on the last value.
- "Doesn't move beyond this point, only jumps straight up": the boss has a
  ledge-sense (`_ledge_ahead` / `_gap_crossable`) that zeroes `velocity.x` at a
  ledge lip, and an arena clamp (`_clamp_to_arena`). Last session also added a
  THROW→VULNERABLE state machine. One of these is likely freezing his advance
  in the real arena. Re-derive against the real level_03 arena geometry.
- Dynamite (`dynamite.gd`) `_explode()`: creates an Area2D (layer 0 / mask 2 =
  player), awaits one physics frame, then `get_overlapping_bodies()` →
  `take_damage(1)`. Player `take_damage()` no-ops if `invincible_timer > 0`
  (1.0s after any hit, 1.5s after respawn) or if not PLAYING. The blast targets
  the player's position AT THROW TIME with a 1.3–2.0s fuse, so a moving player
  legitimately dodges — but the founder reports standing in it and taking
  nothing. Root-cause whether it's i-frames, timing, mask, the await, or the
  blast simply missing.

## T6 — Stage 3 death respawn (STRONG root-cause candidate, verify)
`player.gd::_respawn_or_game_over()` (lives remain branch):
```
var checkpoint := GameManager.get_checkpoint(GameManager.current_level)
if checkpoint == Vector2.ZERO:
    checkpoint = GameManager.get_checkpoint(1)   # <-- cross-level fallback
if checkpoint != Vector2.ZERO:
    global_position = checkpoint + Vector2(0, -50)
else:
    global_position = GameManager.player_position + Vector2(0, -260)
```
On Stage 3 with no Stage-3 checkpoint yet, this teleports the player to LEVEL 1's
checkpoint COORDINATE inside the Level 3 scene — "appears somewhere else". The
founder wants respawn at/near the death position (or last safe ground). Fix
likely: drop the cross-level `get_checkpoint(1)` fallback; respawn near death
position / last grounded position instead.

## T3 — Stage 2 boss: gates pass, founder says broken live
`distributor.gd` currently: MIN_PURSUE_SPEED 345, crystal shards at rotation
slot 0 (fires ~2.2s per last session's gate). The recurring problem: headless
gates pass but the founder sees no chase and no crystals live. Re-derive in the
REAL arena; consider whether the boss's `_physics_process` is even running in
the shipped build, whether the crystal projectile is visually distinguishable
from the Stage-1 clipboard, and whether the chase is real against a kiting
player in the actual arena bounds — not just "closes on a stationary player".

## Constraints that still hold (do not regress)
- Web export must stay non-threaded.
- Vault exit must never soft-lock; return to the entry stage + position.
- Boss arena clamps must not reintroduce ledge-fall death (a prior fixed bug).
- `.import` files are gitignored + CI-regenerated; ship source PNGs at a safe
  ~2-3x oversample (a prior pixelation bug).
