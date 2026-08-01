# Grok 4.5 brief — Blaze Rush art direction: weave in the world, without clutter

You are the art-direction advisor for Lil Blunt Adventure's secret
Geometry-Dash-style mode, "Blaze Rush." It currently uses a deliberately
distinct "Electric Haze" palette (near-black void, purple haze blobs, neon
green player cube, orange/red candle hazards = "market-dip candles," cream
$SMOKE tokens, violet "FUD wall" obstacles with a "FUD" text tag). The
founder's complaint: it "feels divorced from Lil Blunt's world" — bland
black/purple void, no sense this is the SAME game as the forest/cave/gold-
rush campaign levels.

Client brand context: three tokens — **$SMOKE** (Lil Blunt's own token,
green/forest, the mascot brand), **$DIAMONDS** (ETH rewards protocol, cyan/
blue crystal imagery, already used for Distributor boss shards), **$GOLD**
(GoldMine DeFi, wild-west gold-rush, already used for Stage 3). Blaze Rush
already awards SMOKE (always) and GOLD (first clear) and DIAMONDS (flawless
first clear) as real in-game currency.

## Constraints (so your answer stays implementable)
- Rendering is currently 100% procedural (ColorRect/CPUParticles2D, no
  sprites) — deliberately, so it built fast with zero art dependency. We
  have Muapi (an AI art-generation pipeline already used for other realms'
  sprites/backgrounds/logos) available NOW to add real art on top.
- It's an auto-runner at high speed (320-460px/s) — anything busy or highly
  detailed in the FOREGROUND will blur/distract; background elements have
  more room to be detailed since they scroll slower (parallax).
- Must stay readable: hazards (candles, gaps, FUD walls) must remain
  instantly recognizable as "dangerous" at speed — do not let branding
  soften or camouflage a hazard silhouette.

## What I need (short, concrete, under 300 words)
1. **One vertical slice recommendation**: if you could only ship ONE visual
   change first (per this project's own "one slice before batch" rule),
   what single element would you pick to prove "this is Lil Blunt's world"
   fastest — a background element, a token redesign, a hazard reskin, or
   something else? Say which and why.
2. **Rotating logo/background concept**: the founder specifically asked for
   "rotating protocol logos" via Muapi. Where would 1-3 rotating
   SMOKE/DIAMONDS/GOLD logo elements live in this scene without competing
   with gameplay-critical silhouettes (hazards, ground, player)? Background
   parallax layer? A milestone/checkpoint marker? Be specific about WHERE.
3. **Weed-world infusion, without clutter**: 2-3 concrete, minimal ideas to
   make the void feel like it's UNDER/BEHIND/PART OF the Smoke Realm rather
   than a separate biome — e.g. a specific color/shape motif borrowed from
   the campaign levels, not a full re-theme.
4. **What to explicitly NOT do**: the single biggest way this could go
   wrong (become cluttered, slow, or unreadable at speed).
