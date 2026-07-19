# godot-client — current state (2026-07-19)

## Built & verified (strict browser gate: boot + real PLAYING state)
- Full platformer: 3 levels + 3-phase bosses w/ ElevenLabs voices, combat
  (axe/multi-axe/fire-breath), lives + pit deaths, combo scoring, Blaze Rush
  runs, Chill Lounge secret realm, mobile controls, save/checkpoints.
- Layer Shift seams: wallet connect (user-signed only), victory screen
  (badge claim / score submit / NFT link), Oracle NPC + panel, leaderboard,
  lore panel, email signup (consent + skip-forever), invite-a-friend.
- L1 Level Depth: DifficultyManager (invisible adaptive tuning), climbing
  ladders + one-way platforms, secret walls, 3 routes, token boss phases
  (Diamond Surge / Gold Rush / 2× Blaze), snapshot moments, Hall of Blaze.

## In progress
- L2/L3 depth extension (this batch — see `../LEVEL_23_EXTEND.md`).

## Blocked / inert until client input
- Token perks + badge mint + boss spectacle render inert until contract
  addresses land in `config.json` (root `02-status.md` blocker #4).

## Known debt
- Emoji stripped from canvas UI (Godot default font has no glyphs) — a themed
  bitmap font would restore iconography.
- Hand-drawn animation frames still welcome (procedural bob/stretch ships).
