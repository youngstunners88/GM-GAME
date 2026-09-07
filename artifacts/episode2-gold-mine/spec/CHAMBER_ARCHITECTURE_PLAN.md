# Episode 2 — Chamber Architecture Plan (Pascal Editor)

Deliverable for the founder's Pascal spec (`FOUNDER_PROMPT_V4_ADDENDUM.md`,
Immediate Task 2: footprints, key zones, interactive points, runner enter/exit
for each Pascal chamber). Layouts reviewed with Grok 4.5
(`docs/model-responses/2026-09-07-grok-ep2-chamber-architecture.md`), verified
and adjusted here rather than pasted.

**Status:** Fort Knox is **built** as a real Pascal scene
(`assets/chambers/fort_knox/fort_knox_shell.pascal.json`, validated). The other
four are specified below but not yet built.

---

## 0. What Pascal can and cannot do here (verified 2026-09-07, not assumed)

The founder's spec assumes "build in Pascal → export GLB" is one headless
pipeline. **Half of that is true.** Verified empirically, not from docs:

| Capability | Verdict | Evidence |
|---|---|---|
| Author chambers headlessly (levels, walls, openings, zones, items) | ✅ **Works** | `tools/pascal/build_fort_knox.mjs` builds the whole Fort Knox shell over MCP stdio; `validate_scene` → `{"valid":true,"errors":[]}` |
| Export scene as JSON | ✅ Works | `export_json` returns the full node graph |
| Query/measure/collision-check | ✅ Works | `check_collisions` → `{"collisions":[]}` |
| **Export GLB headlessly** | ❌ **Does not work** | Pascal's own `export_glb` tool returns `{"status":"not_implemented","reason":"GLB export requires the Three.js renderer, which is browser-only"}` |

**Why GLB export can't be headless:** `exportSceneToGlb(sceneGroup, nodes)` in
`@pascal-app/editor/src/lib/glb-export.ts` takes a **live rendered
`THREE.Object3D`**, and calls `requestAnimationFrame` and
`WebGPUTextureUtils`. It needs the running editor in a browser with WebGPU —
this container has no GPU, and Pascal ships no headless renderer path.

**So the real pipeline is:**

```
build_*.mjs (headless, here)  ->  *.pascal.json  ->  open in Pascal editor
(browser, one click)  ->  GLB  ->  assets/chambers/<name>/  ->  game engine
```

This is *better* than the spec's assumption in one way: the layout is
**code, versioned in git, reproducible and reviewable** — not a hand-dragged
scene someone has to redo. The browser is needed only for the final render/
export step.

### Two upstream defects you have to know about
Both are bugs in `@pascal-app/mcp@0.3.2`, not in our code:
1. **`zod` must be pinned to `4.3.5`.** Pascal declares `"zod": "^4.3.5"`, but
   on the current `4.5.4` every node-creating tool dies with
   `Duplicate discriminator value "undefined"`. Reproduced under both node and
   bun; pinning 4.3.5 fixes it completely.
2. **The package ships 179 extensionless relative ESM imports** while being
   `"type": "module"` — fine under a bundler, invalid under plain Node ESM. Run
   the server under `bun`, or under node with `tools/pascal/ext-resolver.mjs`.

Both workarounds are documented in the header of `tools/pascal/build_fort_knox.mjs`.

---

## 1. Division of labour (confirming the founder's split)

| Content | Tool | Why |
|---|---|---|
| Runner track, rails, zip-lines, rocky tunnels, organic mine | Existing runner toolchain (Godot 3D graybox today; headless `bpy` for props) | Free-form + physics-driven; Pascal has no vocabulary for it |
| The five protocol chamber **interiors** | **Pascal** | Walls, levels, openings, zones — exactly its vocabulary |
| First Chamber (Miner Shaft) | **Hybrid** — see §4 | Rocky entrance is not Pascal's job; the formal interior half is |
| Gameplay (shooting, Bull companion, protocol logic, enemies) | Game engine, never Pascal | Pascal chambers are architectural shells |

---

## 2. The five chambers

Scale note: Lil Blunt is treated as ~1.7m for doors/ceilings; runner rails sit
2.5m apart, so every entry apron is ≥4m wide to accept the cart.

### 2.1 Fort Knox Vault — 24 × 16m — **BUILT**
Staking + melt. Long hall so the lock-up reads as processional; combat is a
mid-range cover fight down the long axis.

| Zone | Extent (m) |
|---|---|
| Entry apron | y 0–3, full width |
| Staking hall | x 2–22, y 3–12 |
| Melt furnace alcove | x 17–24, y 5–11 (7 × 6) |
| Exit throat | x 10–14, y 14–16 |

- **Primary interaction: the melt furnace mouth, ~(20.5, 8)**, at the *back* of
  the alcove. The player must step inside to commit a melt while the fight
  continues in the hall — the mechanic costs you position, which is the point.
- Perimeter 0.6m thick × 6m high. Alcove partitions 0.4m.
- Openings: 4m entry (south), 4m exit throat (north), 4m alcove mouth. Entry
  and exit are on **opposite** walls, forcing a through-line past the furnace.
- Cover: two 1.2m screens at x=7 (y 5–9) and x=13 (y 7–11) — deliberately
  staggered, not a symmetrical shooting gallery; three 1.2m staking lockers
  along the north wall positioned to feed the exit throat, not block it.

### 2.2 Gold Rush Auction Hall — 28 × 20m + 3m side galleries
Weekly 7-day XAUT auction. The biggest, most open floor — a public event.

| Zone | Extent (m) |
|---|---|
| Entry doors | south, x 12–16 |
| Public floor | x 2–26, y 3–14 |
| Shared bid pool (sunken 0.4m, railed) | centre ~(14, 9), Ø ~6 |
| Auctioneer dais (+0.6m) | x 10–18, y 16–19 |
| Side galleries (walkable, z=3.0) | x 0–2 and x 26–28 |

- **Primary interaction: the bid pool rail at (14, 9)** — dead centre and
  deliberately exposed. Depositing into a live shared pool should mean standing
  in the open; the fight orbits the pool.
- Signature cover: the pool rail + dais lip (0.6–1.0m) as ring cover; galleries
  give high ground without blocking the deposit.

### 2.3 Stockpile Depot (interior) — 22 × 14m
Forfeited GOLD matched with wBTC, then burned or injected as liquidity.
Warehouse/rail-depot: linear bays, tight lanes, closer-quarters fighting.

| Zone | Extent (m) |
|---|---|
| Rail-dock entry | west, y 5–9 |
| Receiving floor | x 0–6, full depth |
| Match bays (3 stalls) | x 7–15, at y 1–4 / 5–9 / 10–13 |
| Burn-vs-LP decision gate | x 16–19, y 5–9 |
| Exit to track | east, x 20–22, y 5–9 |

- **Primary interaction: the match crane / hopper at (17.5, 7)**, at the end of
  the bay run — one commit point for match → burn-or-LP. The fight pushes
  west→east through the stalls.
- Signature cover: cargo crates and bay partitions at 1.2m in a deliberately
  *asymmetric* 3-bay grid, forcing the player to slice each angle.

### 2.4 Claim Certificate Office — 14 × 10m
A certificate costs 22,000 Fort Knox shares + 0.5 XAUT and is
non-transferable. The tightest, most formal space — least "arena."

| Zone | Extent (m) |
|---|---|
| Vestibule | x 4–10, y 0–2.5 |
| Queue / bench hall | y 2.5–5.5, full width |
| Clerk counter (1.1m top) | x 1–13, y 5.5–7 |
| Issuing desk (secure) | x 4–10, y 7–9.5 |
| Exit side door | east, x 12–14, y 3–5 |

- **Primary interaction: the issuing desk ledger at (7, 8.5)**, behind the
  counter — the player has to cross the queue hall and get past the counter
  under fire. The high cost of the certificate is expressed as a choke, not a
  wide-open button.
- Signature cover: the continuous 1.1m clerk counter plus overturned bench
  islands — a desk fight with no long lanes.

### 2.5 Treasury / Sovereign Vault — 18 × 14m + 2.5m mezzanine
Protocol-owned positions, view-only. Prestige and finality.

| Zone | Extent (m) |
|---|---|
| Security foyer | x 5–13, y 0–3 |
| Approach nave | x 3–15, y 3–9 |
| Glass vault face | x 4–14, y 9–11 |
| Mezzanine overwatch (z=2.5) | x 0–2 and 16–18, y 3–8 |
| Exit | side wall, y 4–7 (never through the vault) |

- **Primary interaction: the vault view plinth at (9, 9.5)**, centred on the
  glass — ceremonial and axial, matching a view-only mechanic.
- Signature cover: paired 1.8m columns down the nave with 2m gaps, plus the
  mezzanine balustrade for vertical threat.

---

## 3. Cover and sightline rules (apply to all five)

- Two height tiers only: **1.2m** (crouch/stand-peek, the primary tier) and
  **1.8m** (full block, used sparingly). Nothing above 2.0m in open floor — it
  wrecks third-person camera readability.
- Cover pieces **4–6m apart** centre-to-centre; keep **≥2m** lanes clear so the
  Bull companion can path (a companion stuck on geometry is the fastest way to
  make an ally feel broken).
- Floor budget: **25–35%** of walkable area behind cover, **65–75% open**.
- **No dead corners**: every perimeter pocket needs a ≥1.5m route back to the
  main space, or nothing spawns there.
- No sightline longer than **18m** without an intervening 1.2m piece.

---

## 4. First Chamber (Miner Shaft) — hybrid decision

**Decision: hybrid, and Pascal is the junior partner.**

The First Chamber is where the Inferno Bull appears and hands over the
Winchester 1886 (`chambers/01_CHAMBER_MINER_SHAFT.md`). Its identity is a
*rough mine shaft*, not a building — rock walls, timber supports, a drill rig.
That is exactly what Pascal is not for.

- **Not Pascal:** the shaft itself, the rocky entrance, the ore chutes, the
  cart rails in and out.
- **Pascal (optional):** only if the vesting area becomes a built structure
  inside the shaft — a formal machine room around the Miner Rig, with real
  walls and a door. Worth it only if that room needs architectural fidelity.
- **Recommendation:** build the First Chamber graybox *without* Pascal first.
  It is the story-critical beat and shouldn't wait on an asset pipeline. Add a
  Pascal-built interior later only if the rig room justifies it.

This keeps the founder's hard rule intact — the Bull/Winchester beat is
narrative, and tooling stays secondary to it.

---

## 5. Runner ↔ chamber entry/exit staging

Not a flush loading door — that reads as a teleport and breaks the "one
continuous place" goal.

**Entry:** the runner track ends in a 6–8m **brake tunnel** (runner toolchain,
not Pascal) opening into a 3m-deep apron *inside* the Pascal shell, at least as
wide as the rails. Same floor material either side of the lip so the seam
doesn't read. The cart stays visible at rest on a spur. First cover sits ≥4m
inside, so the dismount is safe but not idle.

**Exit:** the reverse, through a clearly lit throat ≥2m wide aimed back at the
cart spur, with a 2–3m re-mount slab aligned to the rails and the cart already
facing out. The camera holds the chamber behind the player until cart speed
crosses a threshold, then the runner toolchain takes over.

**The same apron serves both directions**, so the chamber reads as one place
entered and left — not two separate transitions.

---

## 6. Build order

Fort Knox (**done** — locks the vocabulary) → Claim Office (smallest, stress-
tests the tight-space rules) → Stockpile → Treasury → Auction Hall (largest,
gallery complexity last).

## 7. Open questions
- Whether the Auction Hall galleries and Treasury mezzanine should be real
  second levels in Pascal or baked as raised platforms — affects how the
  engine's navmesh is generated.
- Item/prop catalogue: Pascal has a `place_item` catalogue, but whether its
  furniture reads as "1800s frontier gold mine" is unverified. Props may need
  to come from the `bpy` pipeline instead and be placed engine-side.
- None of these layouts are playtested. They are buildable specifications, not
  proven fun.
