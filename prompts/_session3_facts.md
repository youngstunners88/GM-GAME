## SESSION 3 — SHARED FACTS (vault interiors + S2 chase + S3 pressure)

Founder prompt: docs/founder-prompts/PROMPT_VAULT_INTERIORS_S2_CHASE_S3_PRESSURE.md
Baseline: master `8371caa` / export `804e81b` (the Diamond Vault / Fort Knox
drop-in-with-ladder from last session, already live).

### Founder's live verdict (verbatim, do not argue)
- Vaults: "needs to be **complete sections of their own**; not just a hole in
  the ground with a ladder and tokens." Required: multiple platforms/chambers
  (not one pit floor), protocol-appropriate hazards/guards, 2+ interactable
  types beyond a coin pile, a real enter->explore->reward->exit loop. Still
  downward entry + upward exit, still no soft-lock.
- Stage 2 boss: "still does not chase Lil Blunt live" and "not firing
  diamonds/crystals/crystal shards" — DESPITE a prior session's fix that
  raised chase speed (265->315->345) and added a 3-way attack rotation
  including a new crystal-shard attack. Treat that prior "FIXED" claim as
  FAILED LIVE. Re-derive fresh, in the REAL arena, don't re-assert the old fix.
- Stage 3 boss: "size OK, too easy to kill." Not a chase-speed problem this
  time — an effectiveness/DPS-exposure problem.

### Real founder art, already extracted + resized into the repo this turn
(Lanczos-resampled to a healthy ≤2-3x oversample ratio — same fix as last
session's TAP OUT pixelation bug; do not suggest displaying these near their
original 1024-1672px source size.)

- `src/assets/art/vaults/diamond_vault_backdrop.png` — 1024x576, full-bleed
  (no alpha). Wide painted scene: multiple staggered floating platforms,
  stone staircases, glowing crystal pillars, hanging chains, a large central
  circular sigil/door motif. DIAMONDS-cyan/violet palette. Intended as a
  ParallaxBackground-style backdrop for the vault interior (same technique
  `level_base.gd::set_boss_background()` already uses for boss arenas).
- `src/assets/art/vaults/fort_knox_backdrop.png` — 1024x576, full-bleed.
  Industrial mine-forge scene: wooden cart tracks, gear wheels, molten-metal
  furnaces, chained gold ingot piles, Bitcoin roundels. Amber/brass palette.
  Same backdrop role, Fort Knox side.
- `src/assets/art/vaults/diamond_deposit_pillar.png` — 187x280, alpha cutout.
  A glowing crystal deposit pedestal/pillar prop — reads as a "deposit here"
  altar. Candidate for an INTERACTABLE reward object inside the Diamond Vault.
- `src/assets/art/vaults/goldmine_melt_forge.png` — 187x280, alpha cutout.
  A steampunk forge pouring gold ingots, with a Bitcoin-branded pressure
  gauge. Candidate INTERACTABLE for Fort Knox (echoes the existing
  `melt_forges` mechanic already in `level_base.gd::_setup_entities()` —
  `EntitySpawner.spawn("melt_forge", ...)` — check whether reusing that
  entity type is better than a new bespoke prop).
- `src/assets/art/vaults/fort_knox_vault_door.png` — 380x380, alpha cutout.
  A massive circular bank-vault door, Bitcoin-branded, radial rivets/handles.
  Candidate backdrop centerpiece for Fort Knox (parallels the Diamond
  backdrop's own circular sigil motif) — a locked/opened door as the visual
  anchor of "you are inside something important," not necessarily interactive.

### Real physics constraint that bounds vault size (do not violate)
`level_base.gd::_setup_kill_zone()` builds ONE full-LEVEL-WIDTH Area2D
(mask=player only) at world y = kill_zone_y+175 ± 200, i.e. **y 825..1225 for
both L2 and L3** (kill_zone_y=850 in both). This Area2D does not care what
solid geometry is "in front of it" — it is a pure shape-overlap test, so ANY
vault content occupying y 825-1225 will trigger `pit_death()` even standing on
a solid vault floor there, UNLESS the kill zone itself is modified (a
level_base.gd change affecting every level's pit logic — treat as high-risk,
avoid unless a model makes a strong case for it). The walk surface is at
y=650. **That leaves ~175px of vertical room (650 to 825) to build "multiple
platforms/chambers" in — going deeper needs kill-zone surgery.**
The existing vault (last session) already uses a floor at y=800 (single tier).
Widening horizontally with 2-3 staggered platform tiers inside that ~175px
band is the safe way to add "multiple platforms," OR propose kill-zone
exclusion by x-range if you think that's worth the risk — argue for it
explicitly if so, don't assume it silently.

### Current vault implementation (last session's shipped version, to expand)
(the full text of `src/level/protocol_vault.gd` is attached separately by
whichever top-level prompt needs it — this shared-facts file only describes
it in prose so the file isn't duplicated across every dispatch)

### Current Stage 2 boss
`distributor.gd` already includes last session's fixes (MIN_PURSUE_SPEED 345,
PULL_FLOOR_MARGIN 72, 3-way action rotation incl. crystal shards) that the
founder says still fails live. Full file attached separately where needed.

Real Stage 2 arena facts (level_02_crystal_caverns.tscn /
level_02_data.tres), NOT the idealized open-ground test arena:
- `BossSpawn` Marker2D at world (4050, 550).
- `BossTrigger` Area2D at world (3700, 400) — player must cross x=3700 to
  start the fight.
- `boss_arena` data: `start_x=3700, end_x=4400`.
- Level script sets `boss.arena_min = Vector2(3700, 550-320)` = (3700, 230),
  `boss.arena_max = Vector2(4400, 550+120)` = (4400, 670).
- Ground segment across the whole arena: `Vector4(3700, 650, 700, 70)` —
  single flat floor, walk surface y=650, no floating platforms inside
  3700-4400 (last platform is at x=3450, before the arena starts).
- Distributor's physical CharacterBody2D `collision_mask=14` (Player+Enemies+
  Collectibles) — deliberately does NOT include World(1), so he flies through
  platforms/walls by design (no gravity, pure hover). Ground segments cannot
  physically block him.

### Current Stage 3 boss
Full file attached separately where needed.

Real combat-economy facts:
- Player `max_health = 3` (src/autoload/game_manager.gd).
- Player's thrown axe deals `damage = 1` per hit to a boss/enemy, on a
  `AXE_COOLDOWN = 0.4s` (src/player/combat_handler.gd) — up to ~2.5 hits/s,
  i.e. up to 2.5 DPS sustained, from whatever range the axe can reach.
- Dynamite (claim_jumper's only attack) deals `take_damage(1)` (1 of the
  player's 3 HP) per stick, `explosion_radius=100`, and (this session's prior
  pass) a phase-scaled fuse from 2.0s down to a floor of 1.3s — still a
  telegraphed, dodgeable hazard (visible pulsing warning ring drawn the whole
  fuse duration).
- **`claim_jumper.gd::take_damage()` has NO state gating** — compare
  `auditor.gd`/`distributor.gd`, both of which only accept damage during an
  explicit `VULNERABLE`/telegraphed window. Claim Jumper can be hit for full
  damage in ANY state (PATROL or THROW), from any range the axe reaches, with
  zero requirement to ever be near him or time an opening.
- Claim Jumper `max_health = 18`, `phase_thresholds = [12, 6]` (3 phases).

### Vault soft-lock rules already proven (must still hold after expansion)
- `ladder.gd` has a `destructible: bool` export (default true); vault ladders
  MUST keep `destructible = false` (a destroyed sole exit ladder over a
  kill-band-guarding floor is unrecoverable — proven last session).
- `top_exit_offset` must never be the default `(0,-20)` — it must land the
  player's centre solidly onto real ground east of the entry pit, never over
  open air.
