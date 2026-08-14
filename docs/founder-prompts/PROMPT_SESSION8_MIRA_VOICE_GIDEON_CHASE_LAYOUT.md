# FOUNDER PROMPT — Session 8: Mira voice + facing + slow dialogue + Gideon + art swaps + S2/S3 chase + layout

**Baseline:** master `3d75a1c` / export `31f7795` (Session 7). Hard-refresh before FIXED.  
**Founder live after S7:** Mira improved but needs voice/facing/farewell; dialogue too fast; scale/threat art wrong; S2 **still no chase**; Bitcoin sun bad; Fort Knox layout/pools/platforms; final boss still jump-in-place; new characters/art provided.

**Limits:** running low — **maximum multi-model load**. Do not solo.

---

## MULTI-MODEL + B.AI + QWEN — MANDATORY FULL DECK

| Lane | Role | Required |
|------|------|----------|
| **Fable-5** | Lead implementer | YES |
| **Grok 4.5** | Dialogue pacing, character placement, layout hierarchy | YES |
| **Kimi K3** | S2/S3 chase numbers in **real arenas**; dialogue open delay | YES |
| **DeepSeek** | Compliance | YES |
| **Qwen** (latest on OpenRouter; VL if screenshots) | Vision on fails + parallel analysis | **YES — never idle** |
| **B.AI** (`BAI_API_KEY`) | Extra capacity | YES if key present |
| **Claude** | Orchestrate only | YES |

Dispatch **Fable + Grok + Kimi + Qwen** before large edits. Log everything. Retry failures.

**ElevenLabs:** use env key **`ELEVENLABS_2`** (presence-only; never print value) for **new** character voices this session.

---

## FOUNDER ART / CHARACTERS (wire these)

| Asset | Notes |
|-------|--------|
| **Mira Ledger Voss** | Vault clerk — enhance behavior + **new ElevenLabs voice** via `ELEVENLABS_2` |
| **Gideon “Goldwater” Vale** | Fort Knox speaker — founder art (cowboy, scales, cigar, BTC). **Thick hillbilly / western cowboy accent** voice via `ELEVENLABS_2` |
| **Redesigned Gold Scale** | Drive `1hDJgugs14ZvnbT92hMhTPYxTK2PgWWUp` — **replace** misplaced/random scale |
| **New threat / emblem art** | Drive `1A7JumYDawsAZFmDQri-EOUKlU7BbbqSN` — replace weak random object |
| Screenshots | placement arrows, pools, platforms, boss idle |

Do not invent alternate characters when founder art exists.

---

## T1 — Mira Ledger Voss (behavior + voice)

- **Voice:** create new ElevenLabs voice with `ELEVENLABS_2`; wire lines when she speaks (greet / stake / crush / farewell).  
- **Standing:** same floor level as Lil Blunt (not floating / wrong Y).  
- **Facing:** turns to face Lil Blunt when he passes / is nearby.  
- **Farewell:** when player approaches vault exit / end of interaction zone, play farewell line.  
- **Dialogue speed:** pressing **E** must **not** snap the full conversation instantly — player must have time to **read and decide** (step-through lines or hold-to-confirm; no instant dump).

## T2 — Stage 2 boss chase (AGAIN)

- Founder: **still does not chase** after S7.  
- Re-root-cause in **real Stage 2 arena**.  
- Gate must show sustained horizontal pursuit; honest live note if headless green but live may differ.

## T3 — Final boss still jump-only

- Must **chase horizontally**, not only jump up/down in place.  
- Keep damage/facing; no ledge suicide.

## T4 — Art / prop corrections

- **Bitcoin sun:** restore **previous** (better) sun — current rejected.  
- **Gold Scale:** founder **redesign**; remove random non-threatening object.  
- **Threat object:** founder new design.  
- **288 / 2888 Day Pool:** primary pool **larger** and **visually distinct**; labels clear.

## T5 — Fort Knox layout + Gideon

- Wire **Gideon “Goldwater” Vale** (dialogue + cowboy accent VO).  
- **Shift layout** so hierarchy is readable.  
- Highlighted platforms → **golden**.  
- Scale and interactables visible, not buried.

## T6 — Dialogue decision time

- E-to-talk panels: paced, stepped; large readable controls.

---

## TASK ORDER

1. Fetch master; record build id.  
2. **Fable + Grok + Kimi + Qwen (+ B.AI)** first.  
3. ElevenLabs voices: Mira + Gideon via `ELEVENLABS_2`.  
4. T1 Mira; T2 S2 chase; T3 final chase.  
5. T4 art; T5 Fort Knox + Gideon + golden platforms.  
6. Gates → deploy → STATUS (full model log; no secrets).

---

## OUT OF SCOPE

Episode 2 chapter, video, legal, DeFi enable, printing API keys, claiming S2 chase FIXED without honest language.

---

## Definition of done

- Mira: voice, same level, faces player, farewell, slow dialogue.  
- Gideon: Fort Knox, cowboy accent VO.  
- Founder scale/threat/sun art; pools distinct; golden platforms; layout readable.  
- S2 + final boss horizontal chase (gated + honest live note).  
- All models logged including Qwen; gates green; build id live.

**Start:** Fetch → **full multi-model dispatch first** → T1–T6 → gates → deploy.
