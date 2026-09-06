# Chamber 5 — Claim Certificate Office (Gold Certificate NFTs)

**White-paper element:** Gold Certificate NFTs — **non-transferable**
membership passes for users meeting long-term Fort Knox staking requirements;
they grant eligibility for consideration in certain XAUT distribution pools.
(WP §Future/Phase 2 — Gold Certificate NFTs.)

**Real constants (`goldmine_system.gd`):** `CERT_SHARES_REQUIRED = 22000`
(Fort Knox shares needed per certificate), `CERT_PRICE_XAUT = 0.5` (XAUT cost
per certificate), `TREASURY_NFT_PCT = 0.50` (50% of treasury flow directed to
Gold Claim Cert holders).

## The 3D shooter/RPG encounter

A formal, wood-panelled claims office: a registrar's desk, a vault of blank
certificates, an eligibility board showing the player's current Fort Knox
share count vs. the **22,000** requirement.
1. **Eligibility check (real mechanic):** the office reads the player's Fort
   Knox shares (earned in Chamber 2). If `shares >= 22000` AND the player can
   pay `CERT_PRICE_XAUT = 0.5` XAUT, the claim is available.
2. **Claim (real mechanic):** interact with the registrar → mint the
   **non-transferable** Gold Claim Certificate. It is a membership pass, not a
   tradeable token — the encounter must communicate that clearly (the WP is
   explicit it's non-transferable).
3. **Encounter framing (proposed):** lower-combat, RPG/dialogue-forward — a
   bureaucratic gauntlet (paperwork, a suspicious registrar) rather than a
   firefight. A deliberate pacing valley between combat chambers. If the
   player is under-qualified (<22,000 shares), the chamber teaches what's
   needed and routes them back — no invented shortcut.

**Reward on exit:** the certificate (a persistent, non-transferable flag on
the player), granting eligibility for XAUT-pool consideration per
`TREASURY_NFT_PCT`. No promised payout beyond "eligibility" — the WP only
promises eligibility, so the game must not promise more.

## Open questions
- Is this chamber gated (can't complete without 22,000 shares from Ch.2), or
  always enterable with the claim simply unavailable until qualified?
- How is "non-transferable / eligibility only" surfaced so players aren't
  misled into expecting a guaranteed XAUT drop?
