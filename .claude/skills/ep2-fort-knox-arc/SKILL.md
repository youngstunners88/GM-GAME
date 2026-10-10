---
name: ep2-fort-knox-arc
description: The founder's LOCKED story arc for Episode 2 after the hideout - the Fort Knox run, Inferno Bull's sacrifice, AwesomeX's rescue - and the rules every world-build, chamber, vehicle, set-piece or voice-line task must obey. READ FIRST before any Episode 2 world-build, chamber, quad, spy point, decoy building, vault, bear line, AwesomeX or Inferno-sacrifice work. TRIGGER on "Fort Knox", "AwesomeX", "DragonX", "decoy", "quad", "spy point", "sacrifice", "rescue", "prep pass", "the stake", "bear line", "vault approach", "next scene", "story arc", "what comes after the woods".
---

# The file that wins

`PROMPT_EPISODE2_FORT_KNOX_AWESOMEX_FOUNDATION.md` (repo root, the founder's words, committed verbatim). "World-build tools read this file
first." If a later prompt contradicts the sacrifice or puts Bull home safe before AwesomeX, **the file wins until the founder edits it.**
This skill is the working summary; when they disagree, the file is right.

Why it exists: on 2026-10-09 the founder - furious that the interlude rooms had Lil Blunt unarmed in a third-person view - handed over the
arc and said "we need to start laying the groundwork ... create the necessary skills to create amazing high quality hyper realism scenes".
He also said "of course we are not going to build it all out in one prompt". So the job is **prep**: references, models, set dressing, the
geometry the later playable beats need. It is not the playable claim.

# Hard rules (verbatim from the file; tests/ep2_fort_knox_arc_test.gd locks them)

1. **Do not implement the ride until the founder says the prep pass is open.** (The passive quad ride to the ridge that the founder asked
   for on 10-09 is built; the CLAIM RUN - shooting bears from the back seat - is not.)
2. **Do not invent a second plot.**
3. **Three hearts max, already locked for the descent. Do not add a second health system.**
4. **Do not put Diamonds in this chapter.** (Diamonds stay in Episode 1. No Diamond shard, aura, line or UI here.)
5. **The Auction waits.** Do not open it on this run.
6. **No pickup-truck gun ending.** One quad, then none. The machine guns are AwesomeX's.
7. **Inferno Bull is never killed.** He is taken or pinned; "the player must believe he is lost"; he is rescued.
8. **Lil Blunt is the PLAYER, first person, with the Winchester in his hands** (`ep2-interlude-chain` rule 7). Never slung, never unarmed.

# The run, in order (and where each step stands)

| # | Step | What happens | Status 2026-10-09 |
|---|---|---|---|
| 1 | Leave the hideout | target practice over, walk out together, Bull drives, Lil Blunt rides | BUILT as groundwork: lava river -> mine lift -> bear woods (`ep2-interlude-chain`) |
| 2 | The quad - CLAIM RUN | Lil Blunt shoots bears from the back seat | **NOT BUILT** (prep pass closed). The passive ride to the ridge exists. |
| 3 | Spy point | they stop where the vault road AND a neighbouring building are both visible; they do not ride in | BUILT as the woods' last beat (spyglass, 6 bears). Slice ends "TO BE CONTINUED" |
| 4 | Decoy | Lil Blunt shoots the quad into that building; it EXPLODES; bears go to the fire; the quad is spent | **NOT BUILT** - prep: building + explosion references (`decoy_building`) |
| 5 | The gold | on foot, first person, ONE load. Fort Knox is the stake, not a loot closet | **NOT BUILT** - the door + one carry-out pile are the Pascal spec: do not redesign |
| 6 | Inferno sacrificed | Bull stays so Lil Blunt can get the load out; taken or pinned, not dead on screen | **NOT BUILT** |
| 7 | Trail back | Lil Blunt returns ALONE with the gold and a line of bears behind him; the decoy did not kill the trail | **NOT BUILT** - prep: wide trail (`return_trail`) |
| 8 | AwesomeX | a dragon with machine guns hits the bear line, opens a path; does not replace Bull, does not take the stake | **NOT BUILT** - prep: entrance + design (`awesomex_entrance`) |
| 9 | Rescue | Lil Blunt and AwesomeX go back for Bull; he is pulled out; the gold is still theirs | **NOT BUILT** - prep: rescue mark (`bull_rescue_mark`) |

Why they are not safe even after the toast: the bears can follow a trail. That fact pays off on step 7.

# Cast lock

- **Lil Blunt** - player. Shoots on the quad, shoots the decoy, carries the gold, comes back with the bears, goes back for Bull.
- **Inferno Bull** - driver, then sacrifice, then rescued. NOT killed. (Out of Blaze; bullish on that fire; "the sacrifice is the heat he already claimed".)
- **AwesomeX** - third, late, a DRAGON, machine guns, rescue. NOT on the quad. NOT in the vault. He is "the burn that cleared the door, not the owner of the vault".

# Protocol: spoken, not lectured

- Blaze is why Bull is in the smelter. Gold Mine is why they ride: **quad = the claim, decoy = the crush, Fort Knox = the stake, the load that
  survives = the melt.** One Bitcoin already bought the rifle; the dragon does not get a second price on this beat.
- AwesomeX: DragonX, minted against TitanX, buy-and-burn; "AwesomeX for the Win!", `#Built2Burn`; "he leads the bulls and he burns things".
  His brand logo is GREEN (docs.awesomex.win, www.awesomex.win). On screen: guns and fire at the bear breach, then he helps pull Bull out.
  Never put a price, a yield, a buy call or a wallet/contract address in game text (CLAUDE.md global rules).
- Lines are short, in character, never a lecture. Inferno speaks at natural pace (ElevenLabs speed >= 1.0, voice `uWE48TmsTuIjyh2ifoNL`).

# What the world tools must be able to build (PREP ONLY - no playable claim)

| Prep item (the founder's list) | Reference id (`tools/ep2_forge/fort_knox_refs.json`) | Already in the game |
|---|---|---|
| Hideout exit onto a road the quad can use | `exit_road` | wood road `WoodsQuadChamber.RIDE_TRAIL` (4.4 m wide) |
| The quad itself (one quad, then none) | `flame_quad` (+ turnaround) | **MODELLED** (2026-10-10): `src/episode2/assets/vehicles/flame_quad.glb` from `tools/ep2_blender/build_flame_quad.py`; Inferno sits on it (seated clip + hands on the grips), Lil Blunt kneels on the rack. Paint is baked per panel from 3D position (flames across both fender crowns); what is still short of the reference is listed in `docs/model-responses/2026-10-10-flame-quad-fidelity.md`. The old box quad stays as the fallback `_build_box_quad()` |
| Spy point: sightline to a neighbouring building AND the vault approach | `spy_point` | ridge + ferns + log, camp only |
| Building that takes the quad and reads as an EXPLOSION, not a grey box | `decoy_building` (intact + exploding) | - |
| Vault approach (NOT the door) | `vault_approach` | - |
| Fort Knox door + one carry-out pile | **Pascal spec: `artifacts/episode2-gold-mine/chambers/02_CHAMBER_FORT_KNOX_VAULT.md`, `assets/chambers/fort_knox/`** | do not redesign |
| Return trail wide enough for a bear line behind Lil Blunt | `return_trail` | - |
| AwesomeX entrance: air or furnace, machine guns visible, a path back to where Bull was pinned | `awesomex_entrance` (+ turnaround) | - |
| Bull rescue mark: he is DOWN, not a corpse | `bull_rescue_mark` | - |

Build each through `ep2-hyperreal-scene-pipeline` (reference -> model -> engine capture -> fidelity loop).

# Procedure for any Episode 2 task

1. Read the foundation file and this skill. Identify which row of the run you are touching.
2. Row is BUILT / GROUNDWORK -> fix, polish, extend. Row is NOT BUILT and the task says "implement/play/shoot" -> **stop**: ask whether the
   founder has opened the prep pass; otherwise do the prep item only.
3. New story chambers extend `Ep2Interlude` (first person, rifle in hands). Resolve with `next_chamber` / `end_session`.
4. Never a second plot, never Diamonds, never a truck, never a second health system, never kill Bull, never AwesomeX on the quad.
5. Gate: `tests/ep2_fort_knox_arc_test.tscn` (rules) + `tests/ep2_interlude_test.tscn` (the chain). When the founder DOES open a step, update
   the test's expected beats AND the status table above in the same commit.
