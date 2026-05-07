# Design Workspace
This is where game thinking happens. Mechanics, level layouts, balance numbers, and UI/UX rules live here. Claude reads this before designing any game system.

## What Happens Here
- Mechanics design documents
- Level layout descriptions and flow diagrams
- Power-up behavior specs with exact numbers (duration, speed multiplier, jump boost %)
- Enemy AI behavior trees in plain English
- Boss arena design
- UI/HUD layout rules
- Difficulty curve planning

## Design Principles
- Feel first: Movement must be snappy and satisfying before anything else. Lil Blunt is CHILL — controls should feel smooth, not punishing.
- Secrets reward curiosity: Hidden paths behind smoke clouds, breakable blocks after mushroom power-up, vertical shafts with diamond shards.
- Flow over friction: Level 1 teaches run → jump → double jump → enemy → power-up → boss. No tutorial text; teach through level geometry.
- Crypto theming is subtle: Collectibles are "Ethereum rings" and coins. Power-ups reference protocols. But the game must be fun even if you know nothing about crypto.

## Power-Up Specs (Exact Numbers)
- Weed Leaves / Blunt Buds (SmokeRing/Blaze Mode):
  - Duration: 12 seconds
  - Speed multiplier: 1.4x
  - Jump boost: 1.3x higher
  - Auto-puff: Every 2 seconds, emits smoke cloud projectile that damages enemies on contact
  - Visual: Lil Blunt glows green, trailing smoke particles
- Magic Mushrooms:
  - Duration: 10 seconds OR until hit
  - Size scale: 1.5x
  - Can break BreakableBlock nodes
  - Visual: Lil Blunt grows, screen shake on block break
- Diamond Shards (Diamonds Protocol):
  - Duration: 8 seconds
  - Invincible + damaging aura (radius ~32px)
  - Visual: Diamond shield bubble, rainbow shimmer

## Enemy Behaviors
- Greedy Tax Collector: Patrols platform edge-to-edge. Speed 60px/s. Stops at ledges. Contact damage.
- Fly Swarm: Flies in sine-wave horizontal pattern. Speed 80px/s. 3-hit health (each fly is one hit).
- Rolling Boulder: Spawns at hilltop, rolls downhill. Destroys everything. Jump over it.
- Hostile Vines: Stationary. Extends/retracts on timer (2s cycle). Contact damage during extend.

## Boss Arena: The Auditor
- Arena: Flat ground + 3 floating smoke platforms
- Boss: Large Tax Collector with top hat, "The Auditor"
- Pattern: Spawn minions → charge attack → vulnerable window (3 seconds)
- 5 hit points. Defeat triggers level clear.

## Level 1 Flow
1. Flat ground tutorial (run)
2. Small pit (jump)
3. Tall wall (double jump)
4. First enemy (Tax Collector, easy dodge)
5. First power-up (Weed Leaf, gated behind breakable blocks)
6. Vertical section with smoke cloud platforms
7. Underground secret cave (Diamond Shards)
8. Enemy gauntlet (Fly Swarm + Vines)
9. Checkpoint before boss
10. Boss arena

## Good Work Looks Like
- Every mechanic doc includes: purpose, trigger, behavior, numbers, visual/audio cues
- Level docs describe platform placement in terms of screen sections (16:9, 1920x1080 base)
- Balance notes explain WHY numbers were chosen