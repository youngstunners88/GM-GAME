# FOUNDER PROMPT — Session 5: Live verify Session 4 + heavy multi-model

**Baseline:** master merge `5d8c003` · source `17c87f3` · export `3bb3247` (Session 4).  
**Founder has not playtested yet.** Hard-refresh itch **before** any FIXED claims.  
https://youngstunners88.itch.io/lil-blunt-adventure

---

## MULTI-MODEL — LOAD-BEARING (mandatory, do not solo)

New session may have empty prior context. **Other models carry the load.**

| Model | Role | Required |
|-------|------|----------|
| **Fable-5** | Lead any code fixes from live fails | YES |
| **Grok 4.5** | Vault “feels like a place” / full-env readability | YES |
| **Kimi K3** | Boss chase numbers, damage paths, respawn distance | YES |
| **DeepSeek** | Compliance matrix | YES |
| **Qwen vision** | Screenshot fail analysis when founder attaches images | YES if images |
| **Claude** | Orchestrate, gates, STATUS — **not** sole designer | YES |

Dispatch **Fable + Grok + Kimi before** any large edit. Log under `docs/model-responses/`. Retry OpenRouter failures — never silently drop a role.

---

## PART A — Live verification matrix (do first)

After hard-refresh, confirm (code/gates + founder screenshots if any):

| ID | Claim from Session 4 | How to check |
|----|----------------------|--------------|
| V1 | Diamond Vault = **full separate scene** (not hole) | Stage 2 → vault door → different backdrop/env; stake diamonds works |
| V2 | Fort Knox = **full gold environment** | Stage 3 → vault door → full env; exit returns near entry |
| V3 | Vault **exit** returns to exact/near stage entry position | Exit → same stage, not wrong level |
| V4 | S2 boss **chases** + **crystal/shard** projectiles (not S1 clone) | Fight Distributor; must pursue + distinct crystal attacks |
| V5 | S3 boss **damages**, **faces** player, **advances** horizontally | Explosion/contact hurts; not back-facing; not only jump-in-place |
| V6 | **Hammer / axe** breaks intended blocks | Throw breaks Destructible targets |
| V7 | S3 death **respawns near death** | Die → appear near death, not far decoy |

**Rules:**
- If founder is **silent** or says OK → record Part A green in STATUS; do **not** invent rework.
- If founder attaches **fail screenshots** → Part B: fix **only** those items. Narrow scope.
- Do **not** reopen Session 4 items without new live evidence.
- Do **not** claim FIXED without hard-refresh + evidence.

---

## PART B — Only if founder reports fails

1. Multi-model dispatch first (targeted to the fail).  
2. Root-cause in real scenes/arenas.  
3. Gate that fails on old behavior.  
4. Deploy; publish build id.

Priority if multiple fails: **V4 S2 chase/crystals** and **V1/V2 full vault env** over cosmetic tuning.

---

## PART C — Optional polish (only if Part A fully green)

Only if founder explicitly wants tuning (not default):
- S3 boss aggression / TTK feel numbers  
- Vault pacing / stake UX clarity  
- Stage 3 aesthetic touch-ups (if still flat after full-env)

Still multi-model for any non-trivial change.

---

## OUT OF SCOPE

Episode 2 chapter, video, legal, DeFi enable, undoing vault scene architecture without fail proof, “improvements” with no founder signal.

---

## Definition of done

- Hard-refresh build id recorded.  
- Part A matrix filled in STATUS (pass / fail / untested by founder).  
- Any fails fixed with multi-model log + gates.  
- No solo implementation.  
- Deploy only if code changed.

**Start:** Fetch master → confirm live export id → Part A matrix → multi-model first if any Part B → gates → deploy if needed.
