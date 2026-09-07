# Design brief — Episode 2: architectural layout for 5 protocol chambers

## What the game is
Lil Blunt Adventure. Episode 2 is a 3D over-the-shoulder minecart **runner**
through a gold mine, interleaved with **chambers**: 3D shooter/RPG spaces that
each dramatize one mechanic of a real DeFi protocol (Gold Mine) as a physical
place rather than a menu. Runner half is built and gated (auto-run, 3 rails,
jump/duck/zip-line, arrow + boulder hazards thrown by balaclava-bear enemies).
Chambers are designed on paper but **no chamber gameplay exists yet**.

Story frame (already locked by the founder): the FIRST chamber introduces an
"Inferno Bull" AI companion who hands the player a Winchester 1886; from there
the tone is Wild West 3D shooter. Player is always Lil Blunt; the Bull is an AI
ally. Enemies in chambers are on-screen agents (unlike the runner's off-screen
hazards).

## What's new and why I need layout help
The founder wants five chambers built as real architecture in **Pascal Editor**
(a React-Three-Fiber architectural editor: levels, walls, doors, zones, items).
I've proven I can author Pascal scenes programmatically — walls, levels,
openings, placed items — so I need concrete **spatial layouts**, in metres, that
I can build directly.

I already built a first-pass Fort Knox shell to establish the vocabulary:
24m x 16m main hall, 0.6m-thick 6m-high perimeter walls, a melt-furnace alcove
partitioned off the east end (7m x 6m), and two waist-high (1.2m) interior
screens as shooter cover. That's a starting point, not a commitment.

## The five chambers and the real protocol mechanic each must express
Do NOT invent protocol numbers. These are the real ones already in the game's
economy code, and the layout should make them *legible as space*:

1. **Fort Knox Vault** — staking + "melt". Players lock GOLD for a chosen
   duration (up to 2,888 days) and can "melt" up to 3x for up to a +900% share
   bonus. Needs: entrance, staking area, melt furnace, exit to tracks.
2. **Gold Rush Auction Hall** — a weekly 7-day auction for XAUT. Players deposit
   GOLD into a live shared pool and compete. Grand, theatrical, public.
3. **Stockpile Depot (interior)** — liquidity/stockpile: forfeited GOLD gets
   matched with wBTC, then either burned or injected as liquidity. Warehouse /
   rail-depot feel.
4. **Claim Certificate Office** — a certificate costs 22,000 Fort Knox shares
   + 0.5 XAUT and is non-transferable. Formal, bureaucratic, tighter space.
5. **Treasury / Sovereign Vault** — protocol-owned positions, viewable. Clean,
   prestigious, high-security, end-of-journey stakes.

## Hard constraints
- **Human scale.** Lil Blunt is a small character but treat him as ~1.7m for
  door/ceiling purposes; the runner cart rides on rails ~2.5m apart.
- Each chamber must have a clear **entry from the runner track** and an **exit
  back to the track** — the runner↔chamber loop is the episode's spine.
- Each must support **third-person shooter combat**: cover at the right
  heights, sightlines that aren't a flat empty box, no dead corners where an
  AI companion gets stuck.
- Pascal builds walls/levels/openings/zones/placed-items. It does NOT do
  organic rock or rails — those stay in the runner's own toolchain. Don't
  propose cave geometry here.
- Buildable: I need numbers I can turn into wall segments, not vibes.

## The actual questions

1. **Footprints.** For each of the five, give an approximate footprint in
   metres and a one-line justification tied to its protocol mechanic and its
   combat role (e.g. why the auction hall is bigger/more open than the claim
   office). Say if any should be multi-level.

2. **Zones + the interactive point.** For each chamber, list its 3-5 named
   zones and place them relative to the footprint (e.g. "melt furnace, east
   alcove 7x6"). Mark exactly ONE primary interaction point per chamber (the
   thing that executes the protocol mechanic) and say where it sits and why
   that position is good for a fight happening around it.

3. **Cover and sightlines.** Give a general rule for cover placement I can
   apply across all five (heights, spacing, how much of the floor should be
   covered vs open), plus per-chamber the one specific cover feature that
   makes its fight distinct rather than a reskin of the others.

4. **Entry/exit staging.** How should the transition from a high-speed
   minecart runner into a walkable interior be staged spatially so it doesn't
   feel like a loading-screen door? And the reverse on exit? One paragraph,
   concrete.

5. **Anything in my Fort Knox first pass you'd change**, given the above
   (24x16 hall, 7x6 melt alcove east, two 1.2m cover screens at x=6 and x=12)?

## Output format
Answer 1-5 in order. For 1 and 2 use a compact table or bullet list with real
numbers. Keep prose tight — I'm turning this straight into wall coordinates,
so favour specificity over description.
