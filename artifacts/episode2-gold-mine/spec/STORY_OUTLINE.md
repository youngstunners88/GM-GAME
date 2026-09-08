# Episode 2 — Story Outline (2026-09-06)

Per the founder's story-first spec (`FOUNDER_PROMPT_V3_ADDENDUM.md`,
Immediate Planning Task #2: "Produce a short Episode 2 story outline that
sequences the runner sections and chambers/landscapes, showing how each
white-paper pillar appears as a place"). Reviewed with Grok 4.5
(`docs/model-responses/2026-09-06-grok-ep2-story-outline.md`) and adapted
against the six chamber docs that already exist in `chambers/`.

**Status: planning only.** Nothing below is implemented — no chamber
graybox exists yet (only the runner half does, see `00_ARCHITECTURE.md`
§5a). This is the sequencing plan the next build phase works from.

## The journey, in order

> **Sequence revised 2026-09-08** by the Inferno Bull character profile:
> the Bull meeting + Winchester hand-off happen in a **smelting facility**
> immediately after the opening runner (a story set-piece with no protocol
> mechanic), and **Fort Knox** is the first protocol chamber. The Miner Shaft
> keeps its vesting mechanic but moves later and no longer hosts the
> companion introduction. See `chambers/00_SMELTING_FACILITY.md`.

```
[Runner: mine descent]
        │  bear hazards (arrow/boulder), duck/jump/zipline — already built
        ▼
[Chamber 0 — SMELTING FACILITY]  ★ Inferno Bull + Winchester 1886 hand-off
        │  STORY SET-PIECE — no protocol mechanic. Shared drink, gun hand-off,
        │  aim/fire/cover taught. Tone shifts to Wild West shooter here.
        │  (full beat sheet: chambers/00_SMELTING_FACILITY.md)
        ▼
[Runner or short walk: approach]
        │  first armed stretch — the gun's first real use has stakes
        ▼
[Chamber 1 — Fort Knox Vault]   (the first PROTOCOL chamber)
        │  Staking + Melt pillar: lock length, 3x melt for up to +900% share bonus
        │  Built: assets/chambers/fort_knox/fort_knox_shell.pascal.json
        ▼
[Runner: deeper rails]
        │  same verbs (duck/jump/zip), now armed and accompanied
        ▼
[Chamber 2 — Miner Shaft]
        │  GOLD Mining pillar: 100-day/1%-day vest, Diamond burn, early-claim
        │  tradeoff (chambers/01_CHAMBER_MINER_SHAFT.md — mechanic still valid)
        ▼
[Runner: mine-mouth → frontier track]
        │  FIRST underground→above-ground transition
        ▼
[Chamber 3 — Gold Rush Auction Hall]  (frontier/town square)
        │  Weekly 7-day XAUT auction pillar, made spatial/competitive
        ▼
[Runner: short frontier stretch]
        ▼
[Chamber 4 — Stockpile Depot]  (warehouse/rail depot, frontier)
        │  Liquidity/stockpile pillar: match forfeited GOLD with wBTC
        ▼
[Chamber 5 — Claim Certificate Office]  (frontier office)
        │  22,000 Fort Knox shares + 0.5 XAUT → non-transferable certificate
        ▼
[Runner: final approach — descent or fortified return]
        ▼
[Chamber 6 — Treasury / Sovereign Vault]  (underground, end-stakes)
        │  Protocol treasury + concentrated liquidity positions
        ▼
       END
```

## Underground vs. frontier — and why

| Chamber | Setting | Why |
|---|---|---|
| 1. Miner Shaft | Underground | Vesting reads as physical shaft-work; also where the tone shift *starts*, so it should still feel like "the mine" the runner has been building toward. |
| 2. Fort Knox Vault | Underground (or surface-adjacent) | Locks and a melt furnace read as a fortified vault, not a public space. |
| 3. Gold Rush Auction Hall | **Above-ground / frontier** | A weekly public auction is inherently a town/market activity — first deliberate underground→surface break, giving the tone shift room to land visually, not just narratively. |
| 4. Stockpile Depot | Above-ground / frontier | Warehousing and liquidity matching read as a rail depot or stockyard — logistics, not vault secrecy. |
| 5. Claim Certificate Office | Above-ground / frontier | A certificate office is a frontier institution (land office, bank teller), reinforcing the "official paperwork made physical" idea. |
| 6. Treasury / Sovereign Vault | Underground | End-stakes, sovereign reserve — returning underground for the finale mirrors the opening descent and reads as "returning to the mine's heart." |

Order and exact geography stay flexible (per the founder's spec) as long as
Chamber 1 = Bull + Winchester and the underground→frontier→underground arc
holds together as one continuous journey, not six disconnected rooms.

## Companion architecture (design-level; informs future companions, not just the Bull)

Recommendation (Grok, adopted): **max 1 active companion in gameplay at a
time.** A second simultaneous ally needs formation/friendly-fire/split-
objective design this project hasn't done yet — a second companion later
should be a *swap*, not a party-of-two, until proven otherwise in play.

Minimal slot set so a second companion (post-Bull) doesn't require
rewriting Chamber 1's code:

| Slot | Purpose |
|---|---|
| Identity | id, display name, theming hook (e.g. Blaze/Inferno), unlock flag |
| Presence | 0 or 1 `active_companion`; equipped/unequipped on a story gate |
| Follow | formation mode (tight/loose/hold) + navmesh follow; never player-possessed |
| Combat | stance (aggressive/defensive/hold), allowed verb set (melee/ranged/support), target filter, damage/down rules |
| Orders (thin) | 0-2 player callouts max (e.g. "on me"/"hold") — shared API, per-companion VO/anim only |
| Bark router | event keys (`on_enter`, `on_weapon_grant`, `on_wave_start`, `on_player_down`, `on_clear`, `on_idle`) → VO table |
| Grant table | what a companion can hand the player once (weapon/key/buff) — data-driven, not hardcoded per companion |

The Inferno Bull is one row in this table (ranged/support stance, Blaze-tied
bark set, grants the Winchester 1886 once). A later companion is a new row
plus content — the runner/chamber core loop doesn't change.

## Antagonist variety (design-level; chamber combat only — runner hazards unchanged)

The runner's off-screen bear hazards (arrow=duck-only, boulder=jump-only,
already built and gated) stay exactly as they are — this section is about
**on-screen chamber combat**, which needs its own small vocabulary so
"antagonist variety" doesn't mean a fifth hazard type bolted onto the runner:

| Category | Behavior | Distinct because |
|---|---|---|
| Thrower/lobber | Mid-long range, arcing projectiles (echoes the runner's duck/jump read, but on-screen and shootable) | Preserves the hazard literacy the player already learned; pressure is dodge-timing |
| Melee rusher | Closes distance fast, forces hip-fire/backpedal/Bull-peel | Opposite of the lobber — space denial via contact |
| Cover camper/picket | Holds an angle, peeks, suppresses until flushed | Demands aim/cover verbs and companion flanking |
| Area-denial setter | Places a lingering zone (fire/dust/barricade/alarm) that reshapes the arena for N seconds | Fights the map, not the hitbox |

**Extension rule:** a new antagonist type = new art + one of these four
behavior patterns (+ tuning) — don't add a fifth category until one of these
is proven redundant in actual play.

## Open questions (do not invent answers)
- Exact runner-segment lengths between chambers (30-60s was the original
  spec's number; unconfirmed for the frontier stretches).
- Whether Inferno has more numeric constants beyond 8×24h cycles / 90%
  buy-and-burn / "bullish on Blaze" that should surface in-chamber (e.g. as
  a Bull buff formula) — do not fabricate; ask if a numeric Bull ability is
  wanted.
- Chamber 1's exact bear-wave count/pacing (proposed 1-2 waves, untested).
- Whether the underground→frontier visual transition (Chamber 2→3) needs
  its own transition runner beat or a hard cut — open art/level question.
