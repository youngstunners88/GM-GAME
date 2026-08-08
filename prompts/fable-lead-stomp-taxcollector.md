# Fable-5 — lead implementer brief: stomp-attack, Tax Collector, token walk-through

You are the session lead implementer for a Godot 4.3 GDScript project (Lil
Blunt Adventure). Primary Claude Code will apply your code verbatim after
verifying it compiles and matches the real files below — so your code must
be copy-paste-ready GDScript, not pseudocode, and must not invent APIs.
Static typing mandatory (project convention: `var x: Type = ...`).

## Task A — Stomp = attack (defect #10)

Currently there is NO stomp/head-jump mechanic anywhere in the codebase
(confirmed by grep — no stomp logic exists). Enemies only take damage from
the player's thrown weapons (axe/flame) or from `body.take_damage()` calls
enemies make against the player on contact. Landing on an enemy currently
either does nothing special or (for `EnemyBase`-derived enemies with a
`deal_damage` hurtbox path) may hurt the PLAYER instead.

Requirement: landing on an enemy's head (falling onto it from above) must:
1. Deal damage to / kill the enemy (call its `take_damage(1)` or an
   instant-kill for weak enemies — your call, but state which).
2. NOT damage the player.
3. Give the player a small bounce (like Mario) so stomping feels good and
   chains are possible — a short upward velocity kick.
4. Only count as a stomp when the player is clearly ABOVE and falling onto
   the enemy (moving downward, contact roughly from above) — a side or
   below hit must NOT count as a stomp (that should stay a normal player-
   takes-damage contact, unchanged).

Relevant files below. `_on_hurtbox_body_entered` in player.gd already special-
cases boulders (pickaxe) and hazards. `EnemyBase` is every enemy's base class.
Tell me: where exactly to add the stomp check (which signal/callback), how to
detect "falling onto it" (what velocity/position comparison), and give the
exact code diff for player.gd (and EnemyBase or a shared helper if that's
cleaner — your call, but keep it to the minimum files needed).

@include src/player/player.gd
@include src/enemies/enemy_base.gd

## Task B — Tax Collector / Auditor: chase + attack simultaneously, remove blocking obstacle

The founder's actual boss (Stage 1) is `src/boss/auditor.gd` ("The Auditor",
also voiced/named "Tax Collector" in-game). Current behaviour, confirmed by
reading the file: PATROL (walk back and forth, throw ranged clipboards on a
cadence, occasional hop) -> CHARGE (dash toward a POSITION SNAPSHOTTED once
when charge began, not the live player) -> VULNERABLE (takes damage) -> back
to PATROL. It does NOT continuously chase the live player, does not jump
during pursuit, and throwing/charging are separate states (never
simultaneous). The founder's complaint: "too easy (patrol only)... must
chase + attack simultaneously, move freely, and jump."

Separately, there is a regular enemy `src/enemies/tax_collector.gd` (NOT the
boss) that already has excellent chase/jump/alert AI (PATROL/ALERT/PURSUE
states, jumps gaps, telegraphs before pursuing). The founder likely wants the
BOSS brought up to a similar standard, NOT replaced with this exact enemy
(the boss needs to also keep its ranged clipboard attacks and phase system).

Give me a concrete redesign of `auditor.gd`'s PATROL/CHARGE states (I will
review before applying) that:
1. Makes the boss continuously move toward the LIVE player position while
   in the aggressive state (re-read player position every frame, not a
   stale snapshot) — "move freely."
2. Adds jumping when the player is above or a wall blocks the path (model
   this on tax_collector.gd's jump gate logic: `max_jump_gap` check so it
   never commits to a jump it can't land).
3. Lets it throw clipboards WHILE moving/chasing, not only during a
   separate stationary PATROL throw-cadence — "chase + attack simultaneously."
4. Keeps the existing phase system (P1/P2/P3 HP thresholds), VULNERABLE
   damage window, and token-spectacle hooks (diamond shards, gold platforms)
   untouched — only change the aggression/movement states.
5. Stays fair: some kind of telegraph/tell before the boss becomes
   aggressive, matching this project's established "fairness contract"
   pattern (see tax_collector.gd's ALERT state for the house style).

Also: the founder mentions "remove the useless obstacle that blocks chase."
I have NOT yet located a specific obstacle object in the boss arena scene —
if you can infer one from the file below (e.g. a StaticBody2D or wall placed
in the arena setup that would interrupt a charge/chase path), name it and
where to remove it; otherwise say "not found in the provided file, needs the
arena .tscn" rather than inventing one.

@include src/boss/auditor.gd
@include src/enemies/tax_collector.gd

## Output format
For each task, give: (1) a one-paragraph explanation of your approach, (2)
the exact new/changed function bodies as GDScript code blocks labeled with
the file path, (3) any new constants/exports needed. Do not restate the
whole file — only the changed functions, with enough surrounding context
(function signature + a few lines before/after) that I can locate the
insertion point unambiguously.
