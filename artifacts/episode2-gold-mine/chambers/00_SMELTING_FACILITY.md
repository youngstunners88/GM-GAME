# Chamber 0 — The Smelting Facility (Inferno Bull meeting)

**Not a protocol chamber.** This is a story set-piece: it carries no
white-paper mechanic and mints no GOLD. It exists to introduce the Inferno
Bull, hand over the Winchester 1886, and turn the episode from a runner into
a Wild West shooter. Numbered 00 because it sits *before* the first protocol
chamber.

**Source:** `spec/INFERNO_BULL_CHARACTER_PROFILE.md` (founder, 2026-09-08),
§2 Narrative Function. Reference art:
`references/inferno_bull_smelting.jpeg` (the exact staging — Bull seated among
molten gold, whiskey in hand, cigar lit, miners working pour-crucibles behind
him), plus `inferno_bull_armed.jpeg` and `inferno_bull_whiskey.jpeg`.

> **This supersedes the earlier plan.** The Bull/Winchester beat was
> previously folded into `01_CHAMBER_MINER_SHAFT.md` (the vesting chamber),
> written before the character profile existed. The profile places the meeting
> in a smelting facility "right after Lil Blunt exits the opening mine-cart
> runner section", with Fort Knox as the first destination afterwards. The
> Miner Shaft keeps its vesting mechanic; it no longer owns this beat.

---

## Placement in the episode

```
[Opening runner: mine descent, bears, arrows, boulders, zip-lines]
        │  cart brakes into a lit industrial cavern
        ▼
[Chamber 0 — SMELTING FACILITY]   <- Bull meeting + Winchester hand-off
        │  no protocol mechanic; pure story + tutorial for the new verbs
        ▼
[Runner or short walk]  ->  first protocol chamber (Fort Knox)
```

The profile names **Fort Knox** as the first major destination after the
meeting ("or the next white-paper chamber that best fits 'using the
protocol'"). That reorders the journey from the earlier draft — see
`spec/STORY_OUTLINE.md`.

## The space

A working smelting facility deep in the mine: pour-crucibles tipping molten
gold, casting molds, ingot racks, ore-cart rails feeding in, lanterns and
timber framing, miners still working in the background. Heat haze and glow are
the dominant light source — this is the warmest, brightest space the player
has seen since entering the mine, deliberately, after a dark high-speed runner
stretch.

**Build note:** this is a rough industrial cavern, not architecture — so it is
**not a Pascal chamber**. Build it with the runner/mine toolchain (see
`spec/CHAMBER_ARCHITECTURE_PLAN.md` §4, which reaches the same conclusion for
the first chamber). Pascal is for the formal protocol interiors.

## Beat sheet

1. **Arrival.** The cart brakes out of the runner tunnel into heat and light.
   Control hands over to walking. No threat present — this is a breather beat
   immediately after the chaos of the runner.
2. **Find the Bull.** He is seated among the gold, whiskey in hand, cigar lit,
   not remotely alarmed by the stranger who just arrived. Staging matches
   `inferno_bull_smelting.jpeg`.
3. **The drink.** They share a drink and a cigar. This is the character beat —
   the Bull says little; what he says lands. Candidate line:
   *"You made it this far. That's rarer than you think."* (`vo_bull_made_it`)
4. **Sizing up.** The Bull takes Lil Blunt's measure. Dry, unhurried, no
   hostility — the profile's "lazy confidence."
5. **The Winchester hand-off.** He hands over the Winchester 1886 — Lil
   Blunt's first long gun, and a permanent unlock for chamber sections.
   Line: *"Take the rifle. You're gonna need more than a pickaxe from here
   on."* (`vo_bull_take_rifle`)
6. **Verb teach.** A safe target in the facility (a rack of empty molds, a
   swinging crucible) teaches aim / fire / cover. These are *additive* — the
   runner's duck/jump remain unchanged for later runner stretches.
7. **The terms.** The Bull makes clear he is not a sidekick:
   *"I don't do sidekicks. But I'll walk with you a stretch."*
   (`vo_bull_no_sidekicks`)
8. **The promise.** Lil Blunt promises that when this is over, he'll take the
   Bull to the new Smoke Lounge as repayment — the line that ties Episode 2
   back to the Smoke Realm. Bull's answer:
   *"When this is over... you owe me a seat in that Smoke Lounge."*
   (`vo_bull_smoke_lounge`)
9. **Exit toward Fort Knox.** The Bull falls in as companion. Save flags:
   `companion = inferno_bull`, `weapon = winchester_1886`.
   Parting line available for the walk out:
   *"The mine don't care how long you've been down here. It only cares if
   you're still standing."* (`vo_bull_still_standing`)

## Voice

All five lines above are **generated and committed** —
`src/assets/sounds/voice/vo_bull_*.mp3`, played via
`AudioManager.play_voice("vo_bull_made_it")` etc.

The Bull speaks with an **original voice designed and owned by this project**:
`uWE48TmsTuIjyh2ifoNL` ("Inferno Bull", ElevenLabs `generated` category),
created from the character profile via Voice Design rather than picked off the
shelf. It measures ~78-89 Hz median pitch across the shipped lines — genuine
bass, against ~100-120 Hz for typical adult male speech — with `speed: 0.80`
for the profile's "slow, measured" delivery. Defined in
`assets/audio-manifest.json`; see `spec/INFERNO_BULL_CHARACTER_PROFILE.md` §5
for how it was chosen and measured.

## What this beat must NOT do

- No protocol mechanic. No GOLD minted, staked, or claimed here. The economy
  starts at Fort Knox.
- No invented Inferno numbers. The Bull embodies the Inferno/Blaze
  relationship narratively; the only protocol facts in play are the real ones
  (TitanX-minted, 8×24h cycles, 90% buy-and-burn, "BULLISH ON BLAZE").
- The Bull never becomes playable. Lil Blunt remains the sole protagonist.

## Open questions
- Does combat occur here at all, or is the facility entirely safe? The profile
  implies a calm meeting; the verb-teach beat (6) needs a target but not
  necessarily an enemy. Recommend: no live enemies in Chamber 0 — save the
  first armed fight for the approach to Fort Knox, so the gun's first real use
  has stakes.
- Length. This is a breather between two high-intensity stretches; it should
  probably run 90-150s, but that's a playtest answer.
