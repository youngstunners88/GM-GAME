# FOUNDER PROMPT — Session 9: Real browser chase capture + lock hysteresis + proper voices

**Baseline:** master `bc2e5c2` · source `f28020e` · export `67f7615` (Session 8).  
**Hard-refresh before FIXED.** https://youngstunners88.itch.io/lil-blunt-adventure

**Founder status:** Session 8 shipped dialogue/NPCs/art; **S2 chase still not fixed live**; S3 chase held.  
**Founder now:** real ElevenLabs secret is in **environments**. Rate limit **~96%** — **other models must carry maximum load**. Do not solo.

---

## MULTI-MODEL + B.AI + QWEN — MAXIMUM LOAD (non-negotiable)

| Lane | Role | Required |
|------|------|----------|
| **Fable-5** | Lead implementer (hysteresis, chase, voice wire) | YES |
| **Grok 4.5** | Chase feel / arena readability | YES |
| **Kimi K3** | Lock-band math, hysteresis design, real-arena numbers | YES |
| **DeepSeek** | Compliance | YES |
| **Qwen** (latest on OpenRouter; VL for capture frames) | Vision on browser frames + parallel analysis | **YES — never idle** |
| **B.AI** (`BAI_API_KEY`) | Extra capacity under rate pressure | YES if present |
| **Claude** | Orchestrate, Playwright capture, gates — **not** sole designer | YES |

Dispatch **Fable + Grok + Kimi + Qwen** **before** large code edits. Log all. Retry OpenRouter failures — never drop a role silently.

---

## T1 — Voices (ELEVENLABS env is ready)

Founder pastes working secret into environments (Session 8 `ELEVENLABS_2` was a key **ID**, not `sk_` — invalid).

1. Presence-only check for working key(s): prefer `ELEVENLABS_2` if it is now a real `sk_` secret; else `ELEVENLABS_API_KEY` / `ELEVENLABS_API`. **Never print values.**
2. Regenerate **Mira Ledger Voss** lines on the correct workspace.
3. Regenerate **Gideon “Goldwater” Vale** with a **thick hillbilly / western cowboy** voice (not a generic premade if a better match exists on the account).
4. Wire greet / stake-crush / farewell (Mira) and Fort Knox dialogue (Gideon). Stepped E-dialogue from S8 stays.
5. STATUS: which env name worked (name only), voice IDs, no secrets.

---

## T2 — Stage 2 chase: lock hysteresis + **real browser capture**

Session 8 honesty stands: climb-lock band re-armed on player hops; headless gates can pass while live still reads as hover.

**Required this session:**
1. Implement **lock hysteresis** (or equivalent durable fix) so the climb-lock does **not** re-arm on every hop and pin the boss in the 700px arena. Kimi designs; Fable implements.
2. **Real in-browser Playwright (or equivalent) capture** of the Stage 2 Distributor fight — not headless-only claims. Record frames / travel distance while player kites and jumps.
3. Gate: sustained horizontal pursuit under **player jump** conditions. Prove pre-fix fails if possible.
4. **Do not** write FIXED in STATUS unless capture shows chase. If still weak, say so and ship the hysteresis + capture evidence.

---

## T3 — Stage 3 final boss: horizontal chase

- No jump-in-place only. Horizontal pursuit in real arena.
- Prefer same browser-capture discipline if feasible; at minimum real-arena gate with kite path.
- Keep damage, facing, no ledge suicide.

---

## T4 — Do not reopen green S8 items

Mira floor/face/stepped dialogue, Gideon NPC presence, Bitcoin sun restore, emblems, pool distinctness, golden platforms — **leave unless** founder sends a new fail screenshot.

---

## TASK ORDER

1. Fetch master; record live build id.  
2. **Full multi-model dispatch first** (Fable + Grok + Kimi + Qwen + B.AI).  
3. T1 voices (env presence-only).  
4. T2 hysteresis + **browser capture** S2.  
5. T3 S3 horizontal chase.  
6. Gates → deploy → STATUS (capture paths, model logs, honest chase verdict).

---

## OUT OF SCOPE

Episode 2, video, legal, DeFi, printing keys, claiming chase FIXED without browser evidence, inventing new vault systems.

---

## Definition of done

- Mira + Gideon VO on working ElevenLabs secret (cowboy accent for Gideon).  
- S2: hysteresis shipped + **browser fight capture** logged; chase FIXED only if capture proves it.  
- S3: horizontal chase gated.  
- Full model deck including Qwen logged.  
- Gates green; build id live; rate-limit aware (prefer model parallelization over Claude solo loops).

**Start:** Fetch → **Fable + Grok + Kimi + Qwen first** → T1–T3 → gates → deploy.
