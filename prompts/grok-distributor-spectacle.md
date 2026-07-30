# Grok 4.5 — Stage 2 Boss Design Brief: The Distributor's Spectacle Layer

You are a senior game designer consulting on a Godot 4.3 retro 16-bit 2D
platformer, "Lil Blunt Adventure". I need a design, not code. Be concrete and
opinionated. Assume the reader will implement exactly what you specify.

## The game in one paragraph

Lil Blunt is a chill, cute anthropomorphic weed nugget. Three stages, one boss
each. Crypto-themed but the game must be fun with zero crypto knowledge.
Collectibles are gold coins, Ethereum rings, wBTC. Power-ups: Blaze Mode
(speed/jump + auto-puff smoke), Magic Mushroom (grow + break blocks), Diamond
Shards (invincibility + damaging aura). Enemies are never weed-themed.

## The three bosses, as they exist RIGHT NOW

### Boss 1 — The Auditor (Stage 1, "Smoke Realm", green/chill forest)
Bureaucratic Tax Collector. **This is the richest fight and the parity bar.**
- States: PATROL → CHARGE (dashes at the player's last position) → VULNERABLE
- 3 HP phases: ranged clipboard throws go 1 shot → 2-shot spread → triple fan;
  patrol speed +25%/+50%; occasional reposition hops get more frequent
- **Token-gated spectacle** (cosmetic/spectacle only — NEVER extra difficulty
  for non-holders, and never pay-to-win):
  - DIAMONDS holders: "Diamond Surge" — summons slow drifting cyan shards. If
    the player hits one with their own attack, it REFLECTS back and damages the
    Auditor *outside* his normal vulnerable window. This is the fight's skill-
    expression moment and its best idea.
  - GOLD holders: golden one-way safe platforms rise in phase 3
  - SMOKE holders: any Blaze Mode grabbed during the fight lasts 2x

### Boss 3 — The Claim Jumper (Stage 3, "Gold Rush", sunset canyon/mine)
Unhinged bandit. Just rebuilt last session, now healthy:
- States: PATROL → TELL (bright quick-draw wind-up flash) → CHARGE → THROW →
  VULNERABLE (window SHRINKS each phase — less free damage as it escalates)
- Throws dynamite that lands ON the player's position, with a pulsing warning
  ring telegraph that speeds up as it nears detonation
- Damage only lands during the telegraphed VULNERABLE window

### Boss 2 — The Distributor (Stage 2) — **THE PROBLEM**
A bloated crystal golem hoarding three glowing ETH reward orbs he refuses to
share. Cold, robotic corporate-speak ("optimizing", "liquidating").
- States: PATROL → SHARD_THROW → VULNERABLE
- Fires aimed, slightly-homing ETH orbs. Phases: 3 orbs → 5 orbs → 5 fast orbs;
  cadence tightens; homing turns on at phase 2
- 7 HP, phases at 4 and 2
- **He has NO movement threat at all** — he only floats and patrols. No charge,
  no dash, no positional pressure.
- **He has ZERO token-gated spectacle.** The Auditor has three. He has none.
- **He has no skill-expression moment** — nothing like the reflect-shard.
- Net effect: he reads as a *thinner reskin of the Auditor's loop* (patrol →
  ranged → wait for window), and he sits in the MIDDLE of the difficulty curve
  where he should be the step up from Stage 1.

## Stage 2's identity — "Crystal Caverns"

- Cyan-violet ethereal cave. Bioluminescent crystal walls, suspended diamond
  clusters, refracted light beams, floating ETH-glyph particles.
- Palette: deep navy `#0a0e2c`, violet `#5a3d99`, cyan glow `#3effff`.
- Represents the **DIAMONDS protocol** — an ETH rewards protocol with three
  payout pools. Diamond imagery. The level is vertical and deep, with long
  ladder shafts over deadly pits.
- The boss's whole character premise is **hoarding rewards that should be
  distributed**. His three orbs = the three payout pools.

## What I'm asking you for

Design the Distributor's upgrade. Four deliverables:

### 1. A movement threat that is NOT a copy of the other two
Both existing bosses charge/dash in a straight line at the player. Give the
Distributor something mechanically different that still creates positional
pressure. Consider: he's a heavy, floating, top-heavy golem in a cave with
crystal walls and a high ceiling. Slam? Teleport-blink between crystal anchor
points? Orbit? A gravity/pull effect toward his hoard? Pick ONE, justify it,
and specify: telegraph, wind-up duration, the counter-play, and how it escalates
across the 3 phases.

### 2. A token-gated spectacle layer that is thematically Stage 2 / DIAMONDS
The Auditor's three perks are listed above — do NOT reuse them. Invent the
Crystal Caverns equivalents. Constraints that are non-negotiable:
- Cosmetic/spectacle and *player-favorable* only. A non-holder must fight
  EXACTLY the shipped fight — never harder, never gated content.
- Must read visually as DIAMONDS/crystal/ETH-pool themed.
- Give me one perk per token: DIAMONDS, GOLD, SMOKE.

### 3. A skill-expression moment — the Distributor's answer to reflect-shard
The reflect mechanic is the single best idea in the Auditor fight because it
rewards a precise player action with damage outside the normal window. Design
the Distributor's own version. It should tie to his THREE ORBS and the
"hoarding vs. distributing" premise. This should feel like the fight's
signature — the thing players describe when they talk about beating him.

### 4. Phase readability
Specify exactly what changes visually/audibly at each phase transition so a
player *sees* the escalation rather than just feeling numbers move. The other
two bosses use color shifts, screen shake, and voice taunts.

## Hard constraints on your answer

- Extend the existing 3-phase + health-bar structure. Do not propose a new boss
  framework or a 4th phase.
- Keep his orb/shard identity. He must not become a second Claim Jumper (no
  dynamite/explosives) or a second Auditor (no clipboard/paperwork).
- Everything must be buildable with: CharacterBody2D physics, Area2D hitboxes,
  Sprite2D/ColorRect visuals, CPUParticles2D, tweens, and simple procedural
  `_draw()` calls. NO new shaders, no new art assets, no video, no 3D.
- The fight must stay fair: every damaging thing needs a readable telegraph
  with real reaction time.
- Difficulty target: harder than the Auditor, easier than the Claim Jumper.

## Output format

Use these exact headings, keep it tight, no preamble:
1. **Movement Threat** — name, mechanic, telegraph, counter-play, phase scaling
2. **Token Spectacle** — one per token, each with the visual and the effect
3. **Signature Skill Moment** — the mechanic, the input, the reward, why it fits
4. **Phase Readability** — per-phase visual/audio checklist
5. **What I'd cut** — if only half of this ships, what matters most and why
