# FOUNDER PROMPT — Session 6: Diamond Vault utility + pure crystal boss + S3 chase + Fort Knox depth + B.AI

**Baseline:** master Session 4/5 lineage (`5d8c003` / later). Hard-refresh before FIXED.  
**Founder live notes:** Vault looks better but **no real diamond utility**; S2 still fires **circles**; S3 still **jumps in place** (must chase); Fort Knox needs **more development**.  
**Rate limits:** Claude subscription tight — **other models must carry maximum load**. Activate **B.AI** as extra hands.

---

## MULTI-MODEL + B.AI — LOAD-BEARING (non-negotiable)

| Lane | Role | Required |
|------|------|----------|
| **Fable-5** (OpenRouter) | Lead implementer: stake UI, boss projectiles, S3 chase, Fort Knox content | YES |
| **Grok 4.5** | Vault clerk dialogue / protocol fantasy; Fort Knox identity | YES |
| **Kimi K3** | S2 projectile purity; S3 chase numbers in real arena; stake limits math | YES |
| **DeepSeek** | Compliance | YES |
| **Qwen vision** | If screenshots attached | If present |
| **B.AI** (`BAI_API_KEY` in env) | Extra Claude-compatible capacity for bulk design + parallel drafts | YES — configure this session |
| **Claude (this process)** | Orchestrate, wire, gates — **not** sole designer | YES |

**B.AI activation (config only — never print keys):**
1. Confirm presence only: `BAI_API_KEY` or `ANTHROPIC_AUTH_TOKEN` in environment (length, not value).
2. Follow prior B.AI integration pattern:
   - Project `.claude/settings.local.json` (gitignored): `ANTHROPIC_BASE_URL=https://api.b.ai`, auth from env, `ANTHROPIC_API_KEY=""`.
   - Optional thin `scripts/bai-call.mjs` or multi-model skill note: B.AI as parallel lane when rate-limited.
3. OpenRouter remains primary for **Grok**. B.AI = extra hands for Claude-compatible bulk.
4. STATUS: “B.AI configured / not configured” with reason — no secrets.

Dispatch **Fable + Grok + Kimi (+ B.AI draft if configured) before** large gameplay edits. Log all responses.

---

## T1 — Diamond Vault: real utility (not decoration)

Founder:
> not projecting utility for diamonds collected… interesting way for Lil Blunt to **speak to a character** that asks **how many diamond tokens** to **store in the vault** and **how many blaze diamonds** he wants to **crush** according to **stack limit from collections**.

**Required:**
- A **vault character / clerk / attendant** Lil Blunt can talk to (dialogue panel minimum).
- Flow:
  1. Show current holdings (diamond tokens / $DIAMONDS and Blaze Diamonds from collections — real economy counters).
  2. Ask how many **diamond tokens to store/stake** in the vault (clamp 0..owned).
  3. Ask how many **Blaze Diamonds to crush** (clamp 0..owned / stack limit).
  4. Confirm → apply economy changes (stake via existing `stake_diamonds` or extend; crush converts/burns with simple readable rules — document in STATUS).
- Must feel like a **gamified DIAMONDS protocol** action, not a coin pile.
- Exit still returns to Stage 2 near entry.

Gates: can open dialogue; clamps respected; balances change; cannot stake more than owned.

---

## T2 — Stage 2 boss: diamonds + shards ONLY

- Firing diamonds is progress.
- **Remove / stop circle (orb) attacks** that make him read like Stage 1.
- Attacks must be **diamonds and diamond/crystal shards only** (distinct geometry/VFX).
- Still must **chase** in real arena.

Gate: no circle/orb projectile in active S2 boss rotation; shard/diamond projectiles spawn; chase closes distance.

---

## T3 — Stage 3 boss: must **chase** (not jump-in-place)

Founder: improved hit effect, but **only jumps in one spot** — wants **chase**.

- Horizontal pursuit toward Lil Blunt in real arena (not statue + vertical hop only).
- Keep damage working; face player; do not reintroduce ledge suicide.
- Gate: travels meaningful horizontal distance while player kites (Kimi numbers).

---

## T4 — Fort Knox: more development

- Deeper than current gold room: second chamber or platforming beat, clearer GOLD MINE identity, at least one more meaningful interactable (beyond coins).
- Still full environment; exit resumes Stage 3 near entry.
- Grok: identity pass so it does not feel like a reskin of Diamond Vault.

---

## TASK ORDER

1. Fetch master; note live build id.  
2. **B.AI config** (presence-only) + multi-model dispatch **first**.  
3. T1 Diamond Vault clerk + stake/crush.  
4. T2 S2 projectiles pure crystals/diamonds.  
5. T3 S3 horizontal chase.  
6. T4 Fort Knox depth.  
7. Full gates → deploy → STATUS (model logs + B.AI status).

---

## OUT OF SCOPE

Episode 2 full chapter, video, legal essays, DeFi on-chain enable, printing API keys, undoing full-scene vault architecture.

---

## Definition of done

- Vault clerk dialogue + stake diamonds + crush Blaze Diamonds with real clamps.  
- S2 boss: diamonds/shards only, no circles; still chases.  
- S3 boss: chases horizontally.  
- Fort Knox noticeably more developed.  
- B.AI wired or honest blocker logged.  
- Multi-model log present; gates green; build id live.

**Start:** Fetch → **B.AI + Fable + Grok + Kimi first** → T1–T4 → gates → deploy.
