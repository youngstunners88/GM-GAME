# FOUNDER PROMPT — Real vault sections + S2 chase/crystals STILL broken + S3 boss pressure

**Baseline:** master `8371caa` / export `804e81b` (protocol_vault drop-in + ladder shipped). Hard-refresh before FIXED.  
**Keep:** larger final boss scale; vault downward entrance idea; distinct-from-Blaze/Lounge architecture.

---

## MULTI-MODEL — MANDATORY EVERY SESSION

| Model | Role | Required |
|-------|------|----------|
| **Fable-5** | Lead: vault interior layout + boss pressure | YES |
| **Grok 4.5** | Vault “complete section” readability / protocol identity | YES |
| **Kimi K3** | S2 chase numbers in **real** arena; S3 DPS vs player; vault soft-lock | YES |
| **DeepSeek** | Compliance matrix | YES |
| **Qwen** | Vision if founder screenshots attached | If present |
| **Claude** | Orchestrate — **not** sole designer | YES |

Dispatch **Fable + Grok + Kimi before** large edits. Log `docs/model-responses/`. Retry failed model IDs — do not solo.

---

## FOUNDER LIVE VERDICT (do not argue)

### Vaults — incomplete
Current Diamond Vault / Fort Knox are **not** acceptable as shipped:
> “needs to be **complete sections of their own**; not just a hole in the ground with a ladder and tokens.”

**Required upgrade (both vaults):**
- Readable **interior space**: multiple platforms or chambers, not a single pit floor.
- **Hazards or guards** appropriate to protocol (crystal threats / security vibe for Diamond Vault; fortified / gold-security vibe for Fort Knox).
- **At least 2 interactable types** beyond a coin pile (e.g. breakables, lever/door, protocol pickup, short combat beat, or score objective).
- Clear **progress loop**: enter → explore/fight/collect → meaningful reward → climb out.
- Still **downward entry + upward exit**; no soft-lock; still distinct from Blaze Rush and Smoke Lounge full-scene loads if that architecture stays.
- Gates: enter, traverse interior, claim reward, exit; no void death from ladder/axe interactions.

Diamond Vault must feel like a **DIAMONDS** strongroom section. Fort Knox must feel like a **GOLD MINE** vault section — not a reskin of the same empty box.

### Stage 2 boss — STILL broken
- **Still does not chase** Lil Blunt live (founder, again).
- **Not firing diamonds / crystals / crystal shards** as requested.
- Treat prior “FIXED” chase + crystal claims as **failed live**. Re-root-cause inside **real Stage 2 arena walls**.  
- Gate must fail on old behavior and pass only when: (1) boss closes distance while player kites, (2) crystal/shard projectiles actually spawn and can threaten the player.

### Stage 3 boss — size OK, fight too easy
- Bigger = good. **Ineffective / too easy to kill** = not done.
- Raise real pressure: sustained chase or attack cadence, meaningful damage, fewer free DPS windows — without reintroducing ledge suicide.
- Gate: fight is not trivial under normal play (Kimi: time-to-kill / hit rate bounds).

---

## TASK ORDER

1. Fetch master; note live build id.  
2. **Multi-model dispatch first** (vault interior brief + S2/S3 boss audits).  
3. **T1** — Expand Diamond Vault into a complete section.  
4. **T2** — Expand Fort Knox into a complete section (same bar, different protocol identity).  
5. **T3** — Stage 2 boss: real chase + crystal/shard fire in shipped arena.  
6. **T4** — Stage 3 boss: effective pressure / harder kill.  
7. Full gates → deploy → STATUS with model sections + honest live limits.

---

## OUT OF SCOPE

Video, Episode 2 chapter, legal pages, DeFi enable, undoing downward entry, full stage redesign outside the vault regions.

---

## Definition of done

- Both vaults are **sections**, not hole+ladder+coins.  
- S2 boss **chases and shoots crystals** in real arena (gated).  
- S3 boss is a real threat, not a damage sponge statue.  
- Multi-model log present; gates green; build id published.

**Start:** Fetch → **Fable + Grok + Kimi first** → T1–T4 → gates → deploy.
