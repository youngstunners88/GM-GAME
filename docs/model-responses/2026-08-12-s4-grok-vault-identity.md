<!-- dispatched: x-ai/grok-4.5
     prompt: prompts/s4-grok-vault-identity.md
     files inlined: 1
     tokens: 3490 in / 2968 out
     cost: $0.0248
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
# Full-Environment Vaults — Design Spec

## 1. What makes a vault read as “a place you travelled to”

**Shared recipe (both vaults, from Smoke Lounge):**
- Separate scene load (not a pit)
- ≥2 parallax backdrop layers at different scroll speeds
- Own palette (no stage colors bleeding in)
- Long horizontal walk (not a single screen)
- One signature moment unique to that vault
- Return portal at the far end (or mid-loop with clear exit bay)

---

### DIAMONDS Vault — Crystal Cavern Protocol Hall

| Axis | Spec |
|---|---|
| **Layout** | ~4800–5600 px wide × ~720 px tall. **4 bays** in a shallow arc: (1) Arrival ledge → (2) Commit dais → (3) Pool gallery → (4) Exit / return portal. Ceiling lowers slightly in bay 2 so the stake terminal feels enclosed. |
| **Palette** | Deep indigo stone `RGB(18, 22, 48)`, ice-cyan crystal `RGB(120, 230, 255)`, amethyst accent `RGB(160, 80, 220)`, cold white specular `RGB(230, 245, 255)`, void shadow `RGB(8, 10, 28)`. **No gold, no warm browns.** |
| **Parallax** | L0 (far): vast crystal geode wall, scroll 0.15. L1 (mid): hanging spires / refracted light shafts, scroll 0.35. Optional L2 dust motes / prism particles, scroll 0.55. Floor tile is local (scroll 1.0). |
| **Signature moment** | **The Refracting Dais** — walk up to a cut diamond on a plinth; when you commit, a beam splits into **three colored shafts** hitting three pool alcoves on the back wall. That split *is* the three-payout-pool read. Nothing in Smoke Lounge or Fort Knox does a light-split. |

Distinct from Smoke Lounge: cold mineral, vertical crystal language, no lounge furniture / haze.  
Distinct from Fort Knox: no forge heat, no metal, no coin stacks.

---

### FORT KNOX — Gold-Mine Forge Vault

| Axis | Spec |
|---|---|
| **Layout** | ~5200–6000 px wide × ~720 px tall. **5 bays**: (1) Blast-door arrival → (2) Weighing floor → (3) Vault gate / stake terminal → (4) Cert press → (5) Return rail / portal. Slight downhill grade arrival→gate so depth reads as “deeper into the mountain.” |
| **Palette** | Charcoal iron `RGB(32, 28, 24)`, furnace orange `RGB(255, 120, 40)`, molten gold `RGB(255, 190, 50)`, brass rail `RGB(180, 140, 70)`, soot black `RGB(12, 10, 8)`. **No cyan, no amethyst.** |
| **Parallax** | L0 (far): mine-shaft timber + distant furnace glow, scroll 0.12. L1 (mid): hanging chains, pipework, sparkwheels, scroll 0.30. L2: ember drift / heat shimmer, scroll 0.50. |
| **Signature moment** | **The Seal Press** — after staking, a mechanical press stamps a **Gold Claim Cert** plaque that drops into your view (short tween, chunky thud). That stamp *is* Fort Knox. Diamonds never stamps; Smoke Lounge never forges. |

---

## 2. Diamond-stake loop (gamified protocol example)

**Primitives used:** `collect_diamonds` / `diamonds_balance` / `diamonds_changed`, plus a **new** DIAMONDS-side stake that mirrors `stake_in_fort_knox` (facts: no `stake_diamonds` yet — this is the clean add). Three payout pools = three alcoves the beam can favor.

### On-screen interaction (no text wall)

**What you walk up to:** the Refracting Dais (bay 2). Proximity prompt = single icon row, not paragraphs:
- Diamond count pip (from `diamonds_balance`)
- Three pool totems (A / B / C) as distinct crystal colors
- Duration lever (Short / Mid / Long) as a physical crank with 3 detents

**Choice beats (exact):**

1. **Approach** — dais glows; HUD diamonds pulse once.
2. **Set amount** — left/right on a hopper: 25% / 50% / 75% / 100% of `diamonds_balance` (not free-type). Hopper shows spend vs keep as two stacks.
3. **Pick pool** — walk/input to one of three floor plates; the matching shaft brightens, others dim.  
   - Pool A = steady (low variance)  
   - Pool B = balanced  
   - Pool C = volatile (high variance)  
   Color alone carries risk tier (e.g. A cool blue, B violet, C hot magenta).
4. **Set duration** — crank: Short / Mid / Long. Longer = higher share weight + longer “lock” VFX on the hopper (chains/ice).
5. **Commit** — confirm input. Beam splits; spent diamonds leave the hopper into the shaft; **shares** appear as small crystal chits stacked on the chosen alcove.
6. **Resolve (readable payoff/risk)** — a short spin-down (1.5–2.5s): alcove either  
   - **Surges** (payout: chits → diamond return > stake),  
   - **Holds** (neutral / small gain), or  
   - **Cracks** (partial loss — see §4).  
   Numbers pop as big float text on the chits only (+/−), not a modal.

**Payoff read:** chit count × pool glow intensity.  
**Risk read:** crack VFX + red float on the same chits; pool C cracks more often, A almost never.

**Mapping to real protocol idea:** three pools = three payout paths; duration = commitment weight; shares = stake receipt. Implementation detail for eng: add `stake_diamonds(amount, pool_id, tier) -> shares` mirroring `stake_in_fort_knox`; do **not** fake this only with `collect_diamonds` burn (burn is entry tax, not stake).

---

### Fort Knox equivalent (GOLD)

**Primitives:** `stake_in_fort_knox(amount, days_committed) -> shares`, `fort_knox_shares`, `gold_balance`, certs as the visible receipt.

**Walk up to:** Vault Gate terminal + Seal Press (bays 3–4).

**Choice beats:**
1. Approach gate — gold balance pulses.
2. Amount hopper: 25/50/75/100% of `gold_balance`.
3. **Days crank:** two detents only (matches real API) — **288** (base) and **2888** (2× shares). Lever shows a thin vs thick bar; 2888 slams heavier and lights a second furnace.
4. Commit — gold pours into a crucible; `stake_in_fort_knox` returns shares.
5. **Seal Press** stamps **Gold Claim Cert** (one cert sprite per stake action; cert shows share count as embossed pips). Shares also tick on a wall counter (`fort_knox_shares`).

**Payoff:** cert + share counter up; optional melt bonus beat later via `melt_gold` if you want a second bay interaction (not required for v1).  
**Risk:** gold stake is commitment/illiquidity, not coin-flip loss — risk reads as **time lock** (crucible sealed, clock ring), not crack/loss. Distinct from Diamonds’ pool variance.

---

## 3. Enter / return read

Reuse proven plumbing: `secret_door`-style entrance → vault scene → `return_portal` → `secret_return` / `level_base._spawn_player()` resume.

### Entrance (deliberate departure — Blaze-class)

| Cue | Diamonds Vault | Fort Knox |
|---|---|---|
| **In-stage object** | Freestanding **geode arch** (not a hole). Mouth shows a slice of the cavern parallax already scrolling slowly. | **Blast door / bank gate** in a stone facade; bar-slit glow of furnace orange inside. |
| **Player action** | Walk into arch (Area2D). Brief hold / prompt optional; no fall-down. | Walk into door threshold. |
| **Visual transition** | 0.35–0.5s indigo iris wipe + crystal chime; next frame full cavern palette. | 0.35–0.5s black bar “door shut” then furnace bloom into forge palette. |
| **Audio** | Whoosh up + high crystalline hit (pitch ↑). | Heavy lock clank + low furnace bed (pitch ↓). |
| **Rule** | One-visit-per-stage via existing `is_side_entrance_used` / `mark_side_entrance_used` if you want parity with Smoke Lounge; or allow re-entry if stake loop needs multiple visits — **pick one and badge the arch** (sealed runes vs open). |

Copy line of feel: *“I stepped through a door into another place,”* never *“I fell in a pit.”*

### Exit (land back in the stage)

| Cue | Both vaults |
|---|---|
| **Object** | `return_portal` instance in final bay — same family as Smoke Lounge/Blaze exit, skinned per vault (cyan ring vs brass ring). |
| **Visual** | Touch → reverse wipe (cavern iris out / door bars open) → stage palette snaps back. |
| **Audio** | Reverse of enter (chime down / lock unlock). |
| **Spawn** | Existing resume: `secret_return.position + Vector2(40,-50)` on the entry stage. Player faces away from arch so the read is “I came back out.” |
| **Failsafe** | Same belt-and-braces as Blaze (`dash_return` / checkpoint 990+level pattern only if vault exit watchdog needed). Never soft-lock. |

---

## 4. Reward vs stake risk (fair protocol demo, not punishment)

**Principle:** Staking is a **demo of variance + commitment**, not a sink that can brick the run.

### Floor rules (Diamonds)
- **Never lose more than 50% of the staked amount** on a single commit (hard floor).
- **Unstaked diamonds are untouchable** — hopper only spends what player assigned.
- **First stake of the visit is insurance-protected:** loss floor tightens to 20% (tutorial fairness).
- **Pool A** cannot go negative expected value on Short duration (steady pool teaches the loop).
- **Visible EV before commit:** the three shafts show a small preview meter (safe / mid / wild bands) — iconography only, no whitepaper text.
- On loss: crack VFX + red float, but immediately show **remaining balance** and a “kept” stack so the player sees they still have diamonds.
- Optional: partial loss converts a slice to **shares still live** (you lost liquid diamonds but retain a weaker claim) — reads as protocol, not theft.

### Floor rules (Fort Knox / GOLD)
- No RNG burn on stake — risk is **duration lock** only (288 vs 2888).
- Cancel/early-exit is either disallowed (seal is seal) or returns gold minus a **small visible fee** (fee pip on the cert). Prefer: seal holds until return-to-stage; shares persist in `fort_knox_shares`.
- Player always leaves with either gold or shares+cert — **never zero both** from one action.

### Readability checklist
- Pre-commit: amount, pool/tier, risk band.  
- Post-commit: same chits/certs mutate (gain glow / crack / stamp).  
- No modal essay; one float number + one VFX verb.

---

## Missing facts (named, not guessed)
- Exact member name confirmation for `diamonds_balance` (facts say verify).
- Whether DIAMONDS three pools have canonical names/weights in the whitepaper (A/B/C above are design placeholders).
- Intended re-entry policy (once per stage vs free re-enter for multiple stakes).
- Whether vault scenes already have asset paths for the “wide painted backdrops” (art exists per founder; **file paths not in facts**).
- Confirm `SceneRouter.load_scene` + `secret_return` dict shape if vaults should share Smoke Lounge’s exact keys vs Blaze’s `dash_return`.

**Eng hook summary:** replace rejected `protocol_vault.gd` pit with `secret_door`-style entrance + new vault scenes modeled on `secret_realm.gd` + `return_portal`; diamond loop needs new stake API; Fort Knox uses live `stake_in_fort_knox`.