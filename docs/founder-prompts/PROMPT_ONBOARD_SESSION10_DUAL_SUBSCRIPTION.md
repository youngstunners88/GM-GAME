# FOUNDER PROMPT — Full onboard + Session 10 (dual-subscription handoff)

**You are Claude Code on a NEW subscription.** The founder’s primary Claude weekly limit is exhausted. After **Sunday**, the original subscription returns and **two sessions may run in parallel**. Read this entire document before editing anything.

**Repo:** `youngstunners88/GM-GAME`  
**Live game:** https://youngstunners88.itch.io/lil-blunt-adventure  
**Engine:** Godot 4.3 · HTML5 · protocols **$SMOKE / $DIAMONDS / $GOLD** (and Blaze Diamonds / TitanX economy)  
**Character:** Lil Blunt · Episode 1 = three stages + Blaze Rush + Smoke Lounge + Diamond Vault + Fort Knox  

**Hard-refresh itch before any FIXED claim.** Deploy via butler when CI is green. Never print API key values.

---

## 0. Dual-session rules (critical)

| Phase | What to do |
|-------|------------|
| **Now → Sunday** | You are the **active** implementer. Own Session 10 tasks below. Fetch master first every turn. |
| **After Sunday** | Founder’s **original** Claude subscription returns. **Two sessions may run.** |
| **Coordination** | Always `git fetch` + work on a **named branch** (`claude/session10-<short-topic>` or continue open PR). Do **not** force-push master. Prefer sequential merges via PR. If both sessions touch the same files, stop and STATUS-note a conflict risk. |
| **Double-up** | After Sunday, **both** sessions must still use **multi-model** (OpenRouter + B.AI). More Claude capacity ≠ solo coding. |
| **Truth source** | `STATUS.md` + latest `docs/session-logs/` + master commits. If your local clone is stale, rebase before claiming.

---

## 1. What the game is

Lil Blunt is a **2D platformer** marketing the Smoke / Diamonds / Gold protocols. Players run stages, enter **Blaze Rush** (geometry-dash-style), **Smoke Lounge**, and protocol **vaults**:

| Set-piece | Stage | Role |
|-----------|--------|------|
| **Diamond Vault** | Stage 2 | Full scene · Mira Ledger Voss · stake diamonds / crush Blaze Diamonds |
| **Fort Knox** | Stage 3 | Full scene · Gideon “Goldwater” Vale · gold scale / pools / platforms |
| **Blaze Rush** | Per-stage | Protocol logos, flaming diamonds, ESC/finish return to stage |
| **Bosses** | L1 Auditor · L2 Distributor · L3 Claim Jumper / final | Must **chase**, face player, deal/take damage |

**Non-negotiable workflow (every session):**
1. Fetch master first  
2. **Multi-model BEFORE large edits:** Fable-5, Grok 4.5, Kimi K3, DeepSeek, **Qwen (never idle)**, B.AI if key present  
3. Gates + Security Sentinel 18/18  
4. Deploy · record build id · honest STATUS (no false FIXED)  
5. Founder prompts live under `docs/founder-prompts/`

---

## 2. What already shipped (do not reopen without new fail evidence)

Rough lineage (master moved through Session 7–9):

- **Vaults** are full separate scenes (not shallow pits) with return near entry  
- **Mira Ledger Voss:** floor-level, faces player, stepped E dialogue, farewell, VO (workspace key)  
- **Gideon “Goldwater” Vale:** Fort Knox NPC, cowboy-intent VO  
- Readable vault labels (larger + outline), stake/crush big buttons  
- Gold Scale art, pools (2888 primary larger/distinct), golden Assay platforms  
- Bitcoin sun restored; security emblems attempted  
- S2 projectile range improved; **lock hysteresis** shipped for chase (S9) — **not proven fixed live**  
- Browser capture of S2 fight **failed** (could not reach boss without debug warp)  
- S3 chase repeatedly regressed (jump-only → frozen)

**Open founder decisions already recorded elsewhere:** BLAZE DIAMONDS naming, TitanX on boss death, etc. Prefer existing STATUS over reinventing economy rules.

---

## 3. Session 10 — MUST FIX (founder screenshots + anger)

These are **live fails after Session 9**. Priority order:

### T1 — Diamond Vault props
- **Remove the golden machine** from Diamond Vault (gold theme only — it does not belong here).  
- Replace useless **triangle** with **DIAMOND VAULT SECURITY SENTINEL** (founder threatening art).  
- Sentinel must be **smaller** than the current oversized prop.

### T2 — Fort Knox props
- Replace useless **triangle** with **FORT KNOX SECURITY SENTINEL**.  
- **Smaller** than current oversized version.

### T3 — Dialogue: E again does nothing
- Second **E** must advance / close / continue correctly. No dead input. Keep stepped pacing (not instant dump).

### T4 — Walk block
- Path where Lil Blunt **cannot walk forward** and must jump — invisible collider or bad geometry. Make flat ground walkable.

### T5 — Layout / camera
- Set-piece or UI still unreadable at the edge. **Reposition** or **extend camera/background** when approaching so the stage remains coherent.

### T6 — Stage 2 boss still does not chase
- Hysteresis alone did not satisfy founder.  
- Add **test-only** `?boss=2` (or equivalent) warp for Playwright.  
- **Real browser capture** of Distributor fight (kite + jumps).  
- Further fix if capture shows idle. **Claim FIXED only with capture or founder OK.**

### T7 — Stage 3 final boss frozen
- Must **move and chase** — not still, not jump-in-place-only.  
- Optional `?boss=3` warp. Keep damage, facing, no ledge suicide.

---

## 4. Multi-model + env (rate-limit survival)

| Model | Role |
|-------|------|
| **Fable-5** | Lead implementation |
| **Grok 4.5** | Layout, sentinel scale, camera |
| **Kimi K3** | Chase math, collision, hysteresis |
| **DeepSeek** | Compliance |
| **Qwen** (latest / VL) | Screenshot vision + parallel analysis — **never idle** |
| **B.AI** | Extra Claude-compatible capacity |
| **Double-pass** | Second Kimi + Qwen pass on chase + walk-block before ship |

**Keys (presence-only, never print values):**  
`OPENROUTER_API_KEY`, `BAI_API_KEY`, `ELEVENLABS_API_KEY` / `ELEVENLABS_API_KEY2` / `ELEVENLABS_api_KEY2`, `BUTLER_API_KEY` / `ITCH_API_KEY`, PostHog/Sentry if already wired.

ElevenLabs: if a real `sk_` works under `ELEVENLABS_API_KEY2`, improve Gideon toward **thick western/cowboy**. Do not block gameplay on voice if keys fail — log env **names** only.

---

## 5. Task order this session

1. `git fetch` · confirm master HEAD · note live export id  
2. **Dispatch Fable + Grok + Kimi + Qwen (+ B.AI) first** — attach founder fail list  
3. T1–T2 sentinels + remove gold machine from Diamond Vault  
4. T3 E-glitch · T4 walk-block · T5 camera/layout  
5. T6 `?boss=2` + browser capture + chase · T7 S3 chase  
6. Second model pass on chase/walk-block  
7. Full gates · Security Sentinel · PR · deploy · STATUS with honest chase language  

**Related prompt (detail):** `docs/founder-prompts/PROMPT_SESSION10_SENTINELS_CHASE_WALK_DIALOGUE.md` — execute in the same spirit if both are present; this onboard doc is the **source of truth for context**.

---

## 6. Definition of done

- No gold machine in Diamond Vault  
- Both Security Sentinels in place and **smaller** than the broken oversized props  
- E works on second press  
- Walk path clear  
- Layout/camera readable  
- S2: warp + browser capture + honest chase verdict  
- S3: not a statue — chases/moves  
- Multi-model (+ double-pass) logged  
- Gates green · build id on itch · hard-refresh note for founder  

---

## 7. Out of scope

Episode 2 chapter, Smoke Lounge video, legal/DeFi enable, inventing systems the founder did not ask for, claiming chase FIXED without evidence, clobbering master from two sessions without PR discipline.

---

**Start now:** Fetch master → multi-model dispatch → Session 10 T1–T7 → gates → deploy.  
After Sunday: expect a second Claude session; cooperate via branches/PRs and shared STATUS — **double capacity, still multi-model.**
