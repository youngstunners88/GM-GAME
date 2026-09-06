<!-- dispatched: x-ai/grok-4.5
     prompt: prompts/grok-ep2-story-outline.md
     files inlined: 0
     tokens: 1731 in / 2109 out
     cost: $0.0161
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
# Episode 2 — Story-first structure (outline + First Chamber)

## 1. Story outline structure

**Sequence:** Opening runner (mine descent, bear hazards, rails) → **Chamber 1: Miner Shaft** (100-day / 1%-day vesting pillar; Bull entrance + Winchester; first armed fight) → runner (deeper rails, same hazard verbs) → **Chamber 2: Fort Knox Vault** (lock/melt stakes; 2,888-day / 3x melt / +900% share constants as spatial pressure) → runner with first above-ground break (mine mouth → frontier track) → **Chamber 3: Gold Rush Auction Hall** (7-day XAUT weekly auction as timed public arena) → short frontier runner → **Chamber 4: Stockpile Depot** (liquidity/stockpile as warehouse defense) → **Chamber 5: Claim Certificate Office** (22,000 FK shares + 0.5 XAUT certificate as gated paperwork/heist clear) → final runner (return descent or fortified approach) → **Chamber 6: Treasury / Sovereign Vault** (end-stakes hold).

**Underground vs frontier:** Miner Shaft, Fort Knox, Treasury stay underground — shafts, locks, and sovereign reserve read as deep mine architecture and match “descent” framing. Auction Hall, Stockpile Depot, and Claim Office justify above-ground/frontier — public bidding, warehousing, and certificate desks are town/outpost spaces and give the tone shift room without renaming pillars. Bull hand-off is locked to Chamber 1; after that, stakes escalate from “survive the shaft” → “break the vault economy” → “fight in the open market” → “settle the treasury.”

---

## 2. First Chamber beat sheet (Miner Shaft → Fort Knox exit)

1. **Enter / read the room** — Lil Blunt drops from minecart into a graybox shaft floor; vesting pillar readable as a long gated channel or timed lock wall (100-day / 1%-day as environmental meter, not new econ). No gun yet. Soft bear pressure or ambient threat only.
2. **Bull trigger** — Scripted threshold (inner gate / blaze-marked door / collapse that cuts retreat). Inferno Bull enters as ally AI — telegraphed as Blaze-tied (visual/VO cue to Episode 1 Blaze Mode), not comic relief. Combat still locked until hand-off completes.
3. **Winchester hand-off** — Short *scripted interactive beat*: Bull presents Winchester 1886 → player hold-to-take (or proximity confirm) → equip montage. Not a full cutscene lock if avoidable; not a silent floor pickup. Establishes Bull as grantor of the shooter fantasy.
4. **Verb teach** — One throwaway target (destructible crate / single stunned bear): aim, shoot, optional light cover peek. Explicitly *adds* chamber verbs (aim / fire / cover) on top of runner duck-jump; does not replace them for later runners.
5. **Allied bear fight** — 1–2 waves of balaclava bears. Bull fights on his own loop (see §3). Player uses gun + cover; duck/jump only if chamber keeps a hazard lane. Bull is unkillable or down-and-recover here so the beat can’t softlock.
6. **Blaze beat (optional but on-theme)** — Brief window where Bull’s presence enables or amplifies a Blaze-styled burst (player damage/move buff), citing the real “BULLISH ON BLAZE” link — no new Inferno numbers.
7. **Chamber clear signal** — Objective complete = vesting gate opens *or* wave clear + Bull bark + stinger. UI/pathing: hard gate on the cart/tunnel toward Fort Knox; reverse path stays blocked.
8. **Exit** — Bull mounts follow behavior onto the out-rail; player boards; load runner segment tagged “toward Fort Knox.” Save flag: `companion = Bull`, `weapon = Winchester1886`.

---

## 3. Companion architecture (design slots)

**Recommend: max 1 active companion in gameplay** (story can preview others). One ally keeps shooter readability, cover, and VO clean; a second body needs formation, friendly-fire, and split objectives you don’t want in the first companion pass. Party of 2+ can be a later opt-in slot, not the default.

**Minimal slots so Companion #2 doesn’t rewrite Bull:**
| Slot | Purpose |
|------|--------|
| **Identity** | id, display name, theming hooks (e.g. Blaze/Inferno), unlock flag |
| **Presence** | 0 or 1 `active_companion`; equip/unequip on chamber enter/exit or story gate |
| **Follow** | formation mode (tight / loose / hold) + matchmaker to player navmesh; no player possession |
| **Combat** | stance (aggressive / defensive / hold) + allowed verb set (melee, ranged, support buff) + target filter; damage/down rules |
| **Orders (optional thin)** | 0–2 player callouts max (e.g. “on me” / “hold”) — shared API, per-companion anim/VO only |
| **Bark router** | event keys (`on_enter`, `on_weapon_grant`, `on_wave_start`, `on_player_down`, `on_clear`, `on_idle`) → VO table; companions register lines, core sends events |
| **Grant table** | what they can hand the player (weapon, key, buff) once; data-driven, not Bull-hardcoded |

Bull is then one row in that table (ranged/support, Blaze bark set, Winchester grant). Next companion = new row + content, same runner/chamber loop.

---

## 4. Antagonist behavior categories (chamber; 4 max)

| Category | Behavior | Why it’s distinct |
|----------|----------|-------------------|
| **Thrower / lobber** | Stays mid-long range; arcs projectiles that map to old runner reads (high = jump window, low = duck/cover). Chamber version is *on-screen* and shootable. | Preserves arrow/boulder literacy; pressure is dodge-timing, not aim duel. |
| **Melee rusher** | Closes distance fast; forces hip-fire, backpedal, or Bull peel. | Threat is space denial via contact; opposite of lobber. |
| **Cover camper / picket** | Holds angles, peeks, suppresses; low mobility until flushed. | Demands player aim/cover verbs and companion flank; not solved by jump/duck. |
| **Area-denial setter** | Places lingering zones (fire, dust, barricade, alarm cone) that reshape the arena for N seconds. | Fights the *map*, not the hitbox; supports “variety later” without new core verbs. |

**Extension rule:** New antagonists (non-bear) = new art + one of these four patterns (+ tuning). Do not add a fifth category until one of these is proven redundant in playtests. Off-screen runner throwers stay the existing duck/jump hazard path; chambers use on-screen agents in the table above so the runner core loop stays untouched.

---

**Open questions (no fabrication):** Inferno — only 8×24h cycles, 90% buy-and-burn, “BULLISH ON BLAZE” used; need real constants if Bull buffs, economy UI, or cycle timers should be numeric in-chamber. Confirm Chamber 1 pillar label with founder if they wanted a non-vesting “antechamber” before Miner Shaft naming.