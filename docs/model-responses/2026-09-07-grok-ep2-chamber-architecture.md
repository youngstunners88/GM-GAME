<!-- dispatched: x-ai/grok-4.5
     prompt: prompts/grok-ep2-chamber-architecture.md
     files inlined: 0
     tokens: 1495 in / 2327 out
     cost: $0.0170
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
# Episode 2 — Five Chamber Layouts

## 1. Footprints

| Chamber | Footprint (m) | Levels | Justification |
|---|---|---|---|
| **Fort Knox Vault** | 24 × 16 | 1 + raised catwalk optional | Staking duration + melt multiplier need a long hall (processional lock-up) and a partitioned furnace; combat is mid-range cover fight down the long axis. |
| **Gold Rush Auction Hall** | 28 × 20 | 1 + 3m gallery on long sides | Weekly public auction = biggest, most open floor; sightlines across a shared pool; gallery gives vertical combat without splitting the crowd. |
| **Stockpile Depot** | 22 × 14 | 1 | Warehouse/rail-depot: linear bays, forklift-scale aisles; matched wBTC/GOLD flow reads as cargo handling; tighter lanes = closer CQB. |
| **Claim Certificate Office** | 14 × 10 | 1 | Bureaucracy + high cost (22k shares + 0.5 XAUT) = compressed, formal rooms; short sightlines, desk cover, least “arena.” |
| **Treasury / Sovereign Vault** | 18 × 14 | 1 + 2.5m viewing mezzanine | Prestige + view-only protocol positions: axial approach to a glass vault face; mezzanine for overwatch, not a second combat floor. |

Multi-level only where it serves the mechanic (auction = spectators; treasury = observation). Fort Knox catwalk is optional and non-load-bearing for the melt loop.

---

## 2. Zones + primary interaction point

### Fort Knox Vault — 24 × 16 (origin = SW corner; entry on south)
- **Entry apron** — y=0–3, full width  
- **Staking hall** — y=3–12, x=2–22 (open floor, locker bays along N wall)  
- **Cover lane** — centre line, two screens (see §5)  
- **Melt furnace alcove** — east, x=17–24, y=5–11 (7 × 6)  
- **Exit throat** — north wall, x=10–14, y=14–16  

**Primary interaction: Melt furnace mouth** at ~(20.5, 8), alcove centre.  
Why: fight stays in the main hall; player dips into alcove to commit melt; Bull holds hall; enemies cannot spawn behind furnace without crossing open sightline from entry.

### Gold Rush Auction Hall — 28 × 20
- **Entry doors** — south, x=12–16  
- **Public floor** — y=3–14, x=2–26  
- **Shared bid pool (sunken 0.4m or railed circle)** — centre ~(14, 9), Ø ~6m  
- **Auctioneer dais** — north, y=16–19, x=10–18, raised +0.6m  
- **Side galleries** — x=0–2 and x=26–28, z=3.0, walkable  

**Primary interaction: Bid pool rail** at (14, 9).  
Why: mechanic is “deposit into live shared pool”; interaction is central and exposed — combat orbits the pool; galleries give high ground without blocking the deposit.

### Stockpile Depot — 22 × 14
- **Rail-dock entry** — west, y=5–9  
- **Receiving floor** — x=0–6, full depth  
- **Match bays** (3 stalls) — x=7–15, y=1–4 / 5–9 / 10–13  
- **Burn/LP decision gate** — x=16–19, y=5–9  
- **Exit to track** — east wall, x=20–22, y=5–9  

**Primary interaction: Match crane / hopper** at (17.5, 7), decision gate.  
Why: forfeited GOLD → match wBTC → burn or LP is a single commit point at end of the bay run; fight pushes west→east through stalls; cover is cargo, not architecture spam.

### Claim Certificate Office — 14 × 10
- **Vestibule** — y=0–2.5, x=4–10  
- **Queue / bench hall** — y=2.5–5.5, full width  
- **Clerk counter** — y=5.5–7, x=1–13, counter top 1.1m  
- **Issuing desk (secure)** — y=7–9.5, x=4–10  
- **Exit side door** — east, x=12–14, y=3–5  

**Primary interaction: Issuing desk stamp/ledger** at (7, 8.5), behind counter.  
Why: cost is high and non-transferable — player must cross queue + counter under fire; tight space makes the desk the natural choke, not a wide arena button.

### Treasury / Sovereign Vault — 18 × 14
- **Security foyer** — y=0–3, x=5–13  
- **Approach nave** — y=3–9, x=3–15  
- **Glass vault face** — y=9–11, x=4–14 (view-only positions behind)  
- **Mezzanine overwatch** — z=2.5, y=3–8, x=0–2 and 16–18  
- **Exit** — west or east side at y=4–7 (not through vault)  

**Primary interaction: Vault view plinth / reader** at (9, 9.5), centred on glass.  
Why: mechanic is view protocol-owned positions — interaction is ceremonial and axial; combat is in the nave; mezzanine is Bull/ally or enemy overwatch, not the button location.

---

## 3. Cover and sightlines

**Global rule (all five)**  
- Cover height tiers: **1.2m** (crouch/stand-peek, primary) and **1.8m** (full block, sparse).  
- No cover taller than 2.0m in the open floor (keeps third-person camera readable).  
- Spacing: cover pieces **4–6m apart** centre-to-centre; leave **≥2m** lanes for Bull pathing.  
- Floor budget: **~25–35%** of walkable area behind cover footprint; **65–75% open**.  
- Avoid dead corners: every perimeter pocket needs a **≥1.5m** exit back to main space, or no spawn there.  
- Long sightlines ≤ **18m** without an intervening 1.2m piece (breaks sniper cheese in halls).

**Per-chamber distinct cover feature**

| Chamber | Signature cover |
|---|---|
| Fort Knox | Two **1.2m interior screens** parallel to short axis (see §5) — classic lane fight. |
| Auction Hall | **Pool rail + dais lip** (0.6–1.0m) as ring cover; galleries as soft high cover (balustrade 1.0m). |
| Stockpile | **Cargo crates / bay partitions** 1.2m in a 3-bay grid — angled, not symmetric; forces slice-the-pie. |
| Claim Office | **Clerk counter continuous 1.1m** + overturned bench islands — desk-fight, no long lanes. |
| Treasury | **Paired column pairs** on nave (1.8m thick, 2m wide gaps) + mezzanine balustrade — formal pillars, vertical threat. |

---

## 4. Entry/exit staging

Do not use a flush loading door. **Entry:** runner track ends in a **6–8m brake tunnel** (still runner toolchain) that opens into a **3m deep × track-width apron** inside the Pascal shell — same floor material as the chamber, cart visible at rest on a spur, waist gate or arch at the apron lip; player dismounts into walk with the chamber already framed (no black frame). Place first cover **≥4m** inside so the dismount is safe but not idle. **Exit:** reverse — a **clearly lit throat** (2m wide min) aimed back at the cart spur; on approach, a 2–3m **re-mount slab** aligned to the rails, cart facing out; camera holds chamber behind until cart speed crosses a threshold, then runner toolchain owns the tunnel. Same apron serves both directions so the loop reads as one place, not two teleports.

---

## 5. Fort Knox first-pass changes

Keep **24 × 16** and **6m walls / 0.6m thick**. Change these:

1. **Melt alcove** — keep 7 × 6 on east, but open it with a **4m-wide mouth** (not a narrow door). Furnace mouth at back of alcove, not flush to main hall — player commits inside; fight stays outside.  
2. **Cover screens** — two at x=6 and x=12 is even and boring. Shift to **x=7 and x=13**, offset on y (e.g. screen A at y=5–9, screen B at y=7–11) so lanes are staggered, not a shooting gallery. Height **1.2m**, length **4m**, thickness **0.4m**.  
3. **Add staking lockers** as 1.2m cover along the **north wall** (y≈14, three bays) — ties mechanic to cover, feeds exit throat at x=10–14.  
4. **Entry on south, exit on north** (not same wall) — enforces through-line past melt. Apron 3m at south per §4.  
5. **Drop optional full catwalk** for v1; if needed later, a single **1.5m-wide east–west run** at z=3 along y=12 only, stairs at west — don’t ring the room (pathing traps).  
6. **No dead SE/NE corners** behind furnace: either seal with wall or leave **2m return gap** north of alcove so Bull/enemies circulate.

---

**Build order suggestion:** Fort Knox (vocab lock) → Claim Office (small stress test) → Stockpile → Treasury → Auction Hall (largest, gallery complexity).