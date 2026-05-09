# Level 2: Crystal Caverns

## Theme & Aesthetic
Cyan-violet ethereal cave biome representing the DIAMONDS protocol's ETH reward pools. Bioluminescent crystal walls, suspended diamond clusters, refracted light beams, and floating ETH-glyph particles. Color palette: deep navy (#0a0e2c), violet (#5a3d99), cyan glow (#3effff).

## Length & Bounds
4400 × 720 px playable area. Camera limit_right = 4400. Boss arena begins at x=3700 with sealed walls at x=3700 and x=4400. Kill zone at y=850 (deeper pit than Smoke Realm).

## Enemy Placements
- tax_collector: Vector2(700, 600), Vector2(1500, 600), Vector2(2400, 600), Vector2(3200, 600)
- fly_swarm: Vector2(550, 280), Vector2(1300, 250), Vector2(2100, 200), Vector2(2900, 280)
- hostile_vine: Vector2(900, 600), Vector2(1800, 600), Vector2(2700, 600)
- rolling_boulder: Vector2(1600, 150), Vector2(2800, 150), Vector2(3500, 150)

## Platform Layout
Ground segments: (0,650,400,70), (500,650,300,70), (900,650,500,70), (1500,650,400,70), (2000,650,400,70), (2500,650,500,70), (3100,650,400,70). Boss arena floor: (3700,650,700,70). Floating crystal platforms (cyan ColorRect 0.3,0.7,0.9): (300,500,100,20), (600,400,120,20), (900,350,100,20), (1200,450,120,20), (1500,300,100,20), (1900,400,150,20), (2300,250,100,20), (2700,400,120,20), (3100,300,100,20), (3450,450,100,20).

## Power-Up Positions
- weed_leaf (blaze): Vector2(450, 540)
- magic_mushroom (big): Vector2(1450, 540)
- diamond_shard: Vector2(2450, 540), Vector2(2350, 200) (secret high-route)
- diamond_shard (boss prep): Vector2(3650, 540)

## Ethereum Ring Locations
Rare and skill-gated: Vector2(640, 350) (requires double-jump from 600 platform), Vector2(1540, 250) (secret behind breakable block at 1500,500), Vector2(2340, 200) (high crystal route), Vector2(3450, 400) (ledge before boss).

## Boss: The Distributor
A bloated, top-heavy crystal golem clutching three glowing ETH spheres he refuses to share. Phases: PATROL hoarding, SHARD_THROW (ranged attack), VULNERABLE when one of his three reward orbs is shattered. 7 HP total (2 hits per orb + 1 finisher). On defeat: orbs scatter as collectible Ethereum Rings rewarding the player for breaking the hoard. Score: 750.
