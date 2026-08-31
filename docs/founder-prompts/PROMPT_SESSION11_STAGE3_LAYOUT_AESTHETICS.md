# FOUNDER PROMPT — Session 11: Stage 3 layout + aesthetics + S10 open items

**Baseline:** master after Session 10 merge (`b715a026` / live export from CI #170).  
**Play URL:** https://youngstunners88.itch.io/lil-blunt-adventure — **hard-refresh before FIXED claims.**  
**Primary skills:** `gm-game-founder-executor` + **`stage3-gold-rush-layout-aesthetics`** + `level-distinctness-checker` + `multi-model-orchestrator` + `env-secrets-and-apis`

---

## Why this session exists

Session 10 shipped: vault Security Sentinels, no gold machine in Diamond Vault, Gideon E-close, final-boss statue fix, non-threaded export, boss-warp captures, CI #170 green + butler deploy.

Founder has **repeatedly** said Stage 3's **basic platform layout and overall design** still feel wrong / "shitty." That is the primary work. Secondary work is the honest leftovers from Session 10.

---

## Session 10 open items (do not bury)

| ID | Item | Required action this session |
|----|------|------------------------------|
| **T4** | Walk-block (forced jump) | **Needs founder screenshot** of the exact spot. If attached → pinpoint collider/geometry and fix. If not attached → STATUS stays NEEDS SCREENSHOT; do not invent a fix. |
| **T5** | Circled layout / camera readability | Same: screenshot-gated. Partial vault floor work already shipped; do not claim full FIXED without the circle. |
| **T6** | S2 Distributor "does overhead tracking feel like chasing?" | Design call. Frames already in `docs/captures/2026-08-14-s10/` (s2-*). **Do not claim FIXED.** Either (a) accept overhead ride + Hoard Gravity as the intended flying-boss feel and document it, or (b) if founder says "must descend," change contact-kill rules and implement a true close. Wait for founder eyes on the frames. |
| **T7** | Final boss statue | Already FIXED + regression-gated in S10 — do not reopen unless live regression. |

---

## Multi-model (mandatory) — use OPENROUTER_2

Session 10 hit a hard **403 on openrouter.ai** under the primary key. Founder has provided **`OPENROUTER_2`**.

1. Run `env-secrets-and-apis` first (names only). Confirm `OPENROUTER_2` and/or `OPENROUTER_API_KEY` presence.
2. Prefer **`OPENROUTER_2`** for this session's dispatches. If the orchestrator script only reads `OPENROUTER_API_KEY`, temporarily export  
   `OPENROUTER_API_KEY="$OPENROUTER_2"` **in the shell for the dispatch only** — never print or commit the value.
3. Required lanes before large Stage 3 layout edits:

| Lane | Role |
|------|------|
| **Fable-5 / Claude lead** | Implementation + gates + STATUS |
| **Grok 4.5** | Stage 3 layout rhythm, density, gold identity, camera readability |
| **Kimi K3** | Geometry vs jump fairness, walk-block collision audit, distinctness vs L2 |
| **DeepSeek** | Compliance matrix against this prompt |
| **Qwen VL** | If T4/T5 screenshots are attached — read the circled regions |

If OpenRouter still 403s on both keys, log it in STATUS, continue with in-harness specialist agents, and **do not** silently skip the design pass.

---

## Primary goal — Stage 3 platform layout + aesthetics

Use skill **`stage3-gold-rush-layout-aesthetics`**.

### T1 — Platform layout (highest priority)

- Audit `ground_segments` + `platforms` in `level_03_data.tres` against L2.
- Make the **rhythm** read as Gold Rush (longer claim trails, purposeful height changes, wide approach into boss arena) — not L2 crystal stepping with gold paint.
- Keep every main-path gap **jump-legal** at real player sprint + single jump.
- Main path must be **walkable** (no invisible forced-jump blockers on flat ground).
- Re-run **`level-distinctness-checker`**. FAIL if still a reskin.

### T2 — Aesthetics / protocol identity

- Gold / steel / Bitcoin-orange hierarchy; no leftover cyan-crystal dominance.
- Remove or relocate remaining functionless clutter (old "orange rectangle" class if any remain).
- Keep dust particles, Fort Knox door, timed gate, Gold Rush Reserve readable.
- Camera: if a set-piece clips, extend limits on approach or move the prop — do not leave unreadable hierarchy.

### T3 — Fort Knox + set-piece anchors stay intact

Do not break:

- Timed Gold Gate (~1520) + pressure plate
- Fort Knox vault door (~2690) → full separate realm
- Gold Rush Reserve (~3420)
- Boss arena 3700–4400

After any move, prove reachability.

### T4 / T5 — Screenshot-gated only

- If founder attaches the two screenshots → fix those exact regions and gate/probe them.
- If not attached → leave as OPEN in STATUS. Proactive geometry scan is allowed; claiming FIXED without the circle is not.

### T6 — S2 chase design call (honest)

- Review `docs/captures/2026-08-14-s10/s2-*`.
- Write a clear STATUS recommendation: keep overhead flying-boss rules **or** change contact-kill so he can descend.
- **No code change on T6 unless founder explicitly chooses (b).**

---

## Task order

1. Fetch master; record live build id; hard-refresh note in STATUS.
2. `env-secrets-and-apis` → confirm OPENROUTER_2 path.
3. **Multi-model dispatch first** (Grok layout + Kimi geometry + DeepSeek matrix). Log under `docs/model-responses/`.
4. T1 layout → T2 aesthetics → distinctness checker.
5. T4/T5 only if screenshots present.
6. T6 write-up only (unless founder already answered in this session).
7. Full gate battery + Security Sentinel → deploy path → STATUS.

---

## Out of scope

Episode 2, new economies, legal, DeFi, inventing art files, claiming S2 chase FIXED without founder design call, reopening S10 T7 without live regression evidence, printing any API key values.

---

## Definition of Done

- [ ] Stage 3 platform **rhythm** is intentionally distinct from L2 (checker PASS / DISTINCT).
- [ ] Main path walkable; no known invisible walk-block on audited spans.
- [ ] Gold Rush visual hierarchy clearer (palette + clutter pass documented).
- [ ] Set-piece anchors intact and reachable.
- [ ] T4/T5: FIXED with proof **or** explicit NEEDS SCREENSHOT.
- [ ] T6: written design recommendation from real captures; no false FIXED.
- [ ] Multi-model logged (or OpenRouter failure logged honestly).
- [ ] Gates green; build id live or "not deployed" stated; STATUS updated.

**Start:** Fetch → env scan → multi-model (OPENROUTER_2) → Stage 3 layout skill → gates → STATUS.
