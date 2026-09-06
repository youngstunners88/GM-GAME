# Chamber 1 — Miner Shaft (GOLD Mining)

**White-paper element:** GOLD Mining. Start a fixed **100-day Miner**, pay with
ETH (optionally Diamonds), earn GOLD at **1%/day**, may claim early forfeiting
the unvested remainder. (WP `docs/whitepapers/GoldMine.md` §Overview.)

**Real constants (from `src/autoload/goldmine_system.gd` — do not invent):**
`MINER_VESTING_DAYS = 100`, earn rate 1%/day, `DIAMOND_BURN_PCT = 0.20` (20%
of Diamonds paid are permanently burned), early claim forfeits unvested GOLD
into the per-level `auction_gold_pool`.

## The 3D shooter/RPG encounter

A working industrial mine shaft: drill rigs, ore chutes, a central **Miner
Rig** console. Lil Blunt enters from the runner track.

**Objective:** start a Miner and keep it running to a claim point.
1. **Interact** with the Miner Rig → choose payment (ETH, or ETH+Diamonds for
   a faster/heavier miner). This is a real protocol choice, dramatized.
2. **Vesting-under-pressure (proposed):** while the rig spins up its yield
   bar (a compressed stand-in for the 100-day / 1%-day vest — 1 in-game bar =
   the 100-day curve), the chamber applies pressure the player must survive:
   collapsing supports, ore-cart hazards, and/or Tax-Collector-lineage
   enemies trying to sabotage the rig (pickaxe melee + ranged weapon).
3. **Claim decision (real mechanic):** an **Early Claim** lever is always
   available. Pull early = take partial GOLD now, **forfeit the unvested
   remainder** (visibly dumped into the auction pool). Hold to full vest =
   full GOLD, but longer under pressure. This is the white paper's actual
   early-claim-forfeit tradeoff made into a risk/reward combat decision.

**Reward on exit:** GOLD credited to the shared balance per how far the vest
bar filled; any forfeited portion routed to `auction_gold_pool` (feeds
Chamber 3). 20% of any Diamonds spent are burned per `DIAMOND_BURN_PCT`.

## Enemies / threats — RESOLVED, 2026-09-06 (see Story integration below)
The founder's story-first spec makes Chamber 1 the site of the Bull/Winchester
hand-off, and its threat is the same balaclava bears from the runner, not a
new Tax-lineage grunt. That resolves part of the open question below: combat
here is **mandatory** — it's the vehicle for teaching the player the new
chamber verbs (aim/shoot/cover) and for the Bull's introduction. The
"vesting-under-pressure" idea from the original design (below) still holds;
the pressure source is now specifically the bear assault, not a placeholder.

## Story integration — First Chamber = Bull entrance + Winchester hand-off
(Per `spec/FOUNDER_PROMPT_V3_ADDENDUM.md`, the founder's story-first spec;
beat structure reviewed by Grok 4.5,
`docs/model-responses/2026-09-06-grok-ep2-story-outline.md`, verified against
this chamber's existing mechanic rather than pasted verbatim.)

This chamber is the **mandatory** introduction of the Inferno Bull companion
and the Winchester 1886 — the founder's hard rule that this must happen in
the *first* chamber, before any others. Beat sheet, merged with the vesting
mechanic above rather than replacing it:

1. **Enter / read the room** — Lil Blunt drops from the minecart into the
   shaft floor. The Miner Rig console (existing mechanic, above) is visible
   but not yet interactive-for-combat — no gun yet, ambient/soft bear
   presence only (sets up the threat without a fair fight).
2. **Interact with the Miner Rig** — the existing mechanic: choose payment
   (ETH, or ETH+Diamonds), start the vest. This is what triggers the
   pressure phase, not a separate button.
3. **Bull trigger** — the vesting bar starting is the scripted threshold:
   as the rig spins up, a gate/collapse cuts easy retreat and the Inferno
   Bull enters as an ally. Telegraphed as Blaze-tied (visual/VO nod to
   Episode 1's Blaze Mode — real tokenomics link: Inferno's own docs say
   it is "BULLISH ON BLAZE"), not a generic sidekick reveal.
4. **Winchester hand-off** — short scripted/interactive beat (Bull presents
   the rifle, player hold-to-take or proximity-confirm, equip montage) —
   not a silent floor pickup, not a full unskippable cutscene if avoidable.
5. **Verb teach** — one throwaway target (a destructible crate, or a single
   stunned bear) teaches aim/shoot/cover-peek. These verbs are *additive* to
   the runner's duck/jump, not a replacement — later runner segments still
   use duck/jump exactly as before.
6. **Vesting-under-pressure = the allied bear fight** — 1-2 waves of
   balaclava bears attack while the Miner Rig's yield bar fills (the
   100-day/1%-day vest, compressed into this bar per the existing design).
   The Bull fights on his own AI loop (ranged/support per the companion
   slots below) and is unkillable-or-down-and-recoverable here so this beat
   can't soft-lock a struggling player. The **Early Claim lever is still
   always available** during the fight — pull early for partial GOLD now
   (forfeiting the unvested remainder into `auction_gold_pool`, unchanged
   from the existing mechanic) if the fight is going badly.
7. **Blaze beat (on-theme, optional)** — a brief window where the Bull's
   presence enables/amplifies a Blaze-styled buff, citing only the real
   Inferno facts already established (8×24h cycles, 90% buy-and-burn,
   "bullish on Blaze") — no invented Inferno numbers.
8. **Chamber clear + exit** — vesting bar fills (or early claim is pulled)
   and the last bear wave clears → Bull bark + stinger → hard gate opens
   toward Fort Knox; the reverse path stays blocked. Save flag:
   `companion = bull`, `weapon = winchester_1886` (see companion/antagonist
   architecture in `spec/STORY_OUTLINE.md` §3-4 for how this generalizes to
   later companions/weapons without rewriting this chamber).

**Reward on exit (unchanged from the original mechanic):** GOLD credited per
how far the vest bar filled; forfeited portion (if early-claimed) routed to
`auction_gold_pool`; 20% of any Diamonds spent burned per `DIAMOND_BURN_PCT`.

## Open questions (updated — some resolved above, some still open)
- ~~Is combat required?~~ **Resolved: yes, mandatory** — it's how the Bull
  and Winchester are introduced.
- Time-compression ratio for the 100-day vest into one encounter — still
  open (needs playtesting, not a design-doc answer).
- Exact wave count/pacing for the bear assault (Grok proposed 1-2 waves;
  not tuned).
- Whether the Winchester equip beat is a short cutscene or a live
  interactive prompt — both are viable, founder/playtest call.
