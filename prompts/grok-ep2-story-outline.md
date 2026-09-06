# Design brief — Episode 2 story-first spec: outline + First Chamber beat

## What the game is
Lil Blunt Adventure. Episode 1 is a shipped 2D pixel-art Godot 4.3 platformer
(a chill weed-nugget mascot platformer for a crypto project ecosystem —
SmokeRing/DIAMONDS/GoldMine). Episode 2 is a new 3D over-the-shoulder minecart
runner + "chamber" shooter/RPG hybrid, currently in early graybox (engine
primitives only, no final art): a Godot-3D runner scene proving auto-run,
3-rail switching, jump, duck, zip-line, and two hazard types (arrows cleared
by duck, boulders cleared by jump) thrown by off-screen "balaclava bear"
enemies. No chamber gameplay exists yet — six chamber *design docs* exist,
each mapping a real DeFi protocol mechanic (100-day gold vesting, Fort Knox
staking/melt, weekly auctions, stockpile/liquidity, claim certificates,
treasury) to a physical in-game space, citing real numeric constants from
the project's economy code (never invented).

## What just changed
The founder escalated the brief from a single runner+chambers spec into a
story bible: Lil Blunt descends into the mine (runner), meets an "Inferno
Bull" companion in the first chamber who hands him a Winchester 1886 and
fights alongside him, and from that point on the tone shifts from mine-cart
runner into "Wild West 1800s / Modern Warfare-style 3D shooter." The design
must stay open for: more companions later, antagonist variety beyond bears,
and landscapes that move between underground and above-ground/frontier
settings. The six existing chamber mappings stay the same white-paper
pillars — only the *frame* (physical shooter/RPG space) escalates in tone.

**Real protocol fact, not invented:** the "Inferno Bull" corresponds to a
real token protocol (Inferno, minted with TitanX, 8×24h cycles, 90%
buy-and-burn) whose own docs say it is "BULLISH ON BLAZE" — a real
tokenomics relationship to this game's existing "Blaze Mode" mechanic
(Episode 1's power-up). The founder wants that real relationship
represented narratively (the Bull is thematically tied to Blaze), not a
generic wisecracking sidekick.

## Hard constraints
- Lil Blunt is the only *playable* protagonist. Companions (Bull, future
  ones) are AI-controlled narrative/combat support, never a second
  player-controlled character.
- Never invent protocol numbers — every chamber's mechanic must still cite
  real constants (already established: 100-day vesting/1%-day, 20% Diamond
  burn, Fort Knox up to 2,888-day lock with 3x melt for up to +900% share
  bonus, weekly 7-day XAUT auctions, 22,000 Fort Knox shares + 0.5 XAUT for
  a Claim Certificate). Do not invent new economics for Inferno either —
  only use what's stated above (8x24h cycles, 90% buy-and-burn, "bullish on
  Blaze"); flag anything you'd need more numbers for as an open question,
  don't fabricate.
- No art/engine decisions in this brief — Godot 4.3 3D is already the
  committed engine (two prior independent design reviews + real graybox
  work already built there); don't re-litigate that.
- The architecture must have a clean extension point for: (a) additional
  companions beyond the Bull, (b) additional antagonist types beyond
  balaclava bears, without a rewrite of the runner/chamber core loop.

## The actual questions

1. **Story outline structure.** Propose a concrete sequence (not
   necessarily final, but concrete) of runner segments and chambers that
   sequences all six existing white-paper pillars (Miner Shaft, Fort Knox
   Vault, Gold Rush Auction Hall, Stockpile Depot, Claim Certificate
   Office, Treasury/Sovereign Vault) into one coherent journey, with the
   Bull/Winchester hand-off explicitly in the FIRST chamber (the founder's
   hard rule) and a sensible escalation of tone/stakes afterward. Say
   which pillars work best underground vs. which could justify moving
   above-ground/frontier, and why, in 1-2 sentences each.

2. **First Chamber beat, beat-by-beat.** The founder wants: Bull entrance →
   Winchester 1886 hand-off → bear fight (with the Bull as an AI ally) →
   exit toward Fort Knox. Break this into a short beat sheet (5-8 beats) a
   level designer could build a graybox from — what triggers the Bull's
   entrance, how the weapon hand-off is staged (cutscene? interactive
   pickup? a scripted animation beat?), how bear combat differs now that
   Lil Blunt is armed (still duck/jump from the runner, or does chamber
   combat introduce new verbs — aim, shoot, take cover?), and what
   specifically signals "this chamber is done, exit toward Fort Knox."

3. **Companion architecture (design-level, not code).** What's the minimal
   set of "slots" a companion needs so a second companion later doesn't
   require rewriting the Bull? Think in terms of: how the companion moves
   with the player, how/when it fights, how its dialogue/voice barks are
   triggered, and how the player "has" 0 or 1 companion at a time (or more
   than one — your call, argue for whichever you'd recommend and why).

4. **Antagonist variety, without a core-loop rewrite.** The runner already
   has two opposite-cleared hazard types (arrow=duck-only,
   boulder=jump-only) thrown by off-screen "bears." For chamber combat
   (now armed, with a companion), what's the smallest set of antagonist
   *behavior* categories (not reskins — actual different threat patterns)
   that would let the founder add "antagonist variety" later without a
   redesign? Aim for 3-4 categories max, each different enough to matter
   (e.g. ranged vs. melee-rush vs. area-denial), not a long list.

## Output format
Answer 1-4 in order. Keep 1 and 3 to a tight paragraph each; 2 as an actual
numbered beat list; 4 as a short table or bullet list (category → behavior
→ why it's distinct). This informs design docs I'll write myself — don't
write prose I'd paste verbatim, give me the structure and the reasoning.
