# Claude Code Workflow — Economy / Points / ICP Build

**Paste the block in §1 into Claude Code to run the build.** It implements
`docs/design/economy_points_system_design.md` in gated phases, game-first so every
step ships and is playable before any chain work. Nothing here breaks offline play.

---

## 0. Guardrails (always apply)

- **Game stays playable with zero chain** — ICP is additive (ADR-ICP). A dead
  canister must never cost a run.
- **Data-driven values** — all point/multiplier numbers live in `config.json`
  (`economy` block), never hardcoded (CLAUDE.md rule).
- **Security gate is mandatory** — the moment a leaderboard / on-chain write is
  added, the `game-security-sentinel` re-audits (real backend surface appears).
  Never hardcode a wallet/contract address; the game never holds a key; web export
  stays non-threaded.
- **Every phase: headless gate that FAILS pre-change and PASSES post-change**, then
  `scripts/security-sentinel.sh` (18/18), then STATUS + commit + push + PR + merge +
  verify butler live (the established pipeline).
- **Trust model = S (social ledger) until the founder says V** (see design §7).

---

## 1. PASTE-READY PROMPT

```
Implement the Lil Blunt economy/points/ICP system per
docs/design/economy_points_system_design.md, in this phase order. Each phase:
add a real-physics/logic gate that fails before and passes after, run the
security sentinel, update STATUS, commit, push, open a draft PR, merge to master
after CI+butler verify. Keep the game fully playable offline at every phase.

PHASE 1 — Data-drive the economy (no behaviour change yet)
- Add an `economy` block to config.json: pickup base scores + multiplier constants
  (MULT_MAX 3.0, ATTEMPT_STEP 0.2, MULT_MIN 1.0, bonus values + BONUS_CAP), all
  from design §2b/§3.
- Add a loader + `ScoreSystem` autoload (src/autoload/score_system.gd) exposing
  base_value(pickup) and excellence_multiplier(attempts, flags).
- GATE: score_system_test — attempt 1 -> 3.0x, attempt 10 -> 1.2x, attempt 11 ->
  1.0x (floor), bonus stack caps at BONUS_CAP.

PHASE 2 — Banked vs run score (the death/stakes rule)
- GameManager: add banked_score. add_score credits run_score. On LEVEL_COMPLETE,
  banked_score += run_score then run_score = 0. boss_contact_restart zeroes ONLY
  run_score + current-run lives; banked_score and protocol tokens untouched.
- displayed_total = banked_score + run_score everywhere the HUD reads score.
- Extend save_session/load_session with banked_score + per-level bests.
- GATE: banking_test — clear L1 (bank), take boss contact in L2 (run lost, banked
  kept), reload save (banked restored). Protocol tokens survive both.

PHASE 3 — Per-level Summary + Continue/Save&Quit
- New LevelSummary scene shown by StateMachine on LEVEL_COMPLETE before Scene-
  Router advances: base, multiplier + why, section score, banked total, tokens.
- Two buttons: Continue (advance) / Save & Quit (save_session + main menu).
- GATE: level_summary_flow_test — summary appears on clear, Continue advances,
  Save&Quit persists + returns to menu, Continue-from-menu restores banked_score.

PHASE 4 — Final Score + on-chain emit (Trust model S)
- After the Claim Jumper dies: FinalScore screen with grand total + a
  "Save to Blockchain" button.
- Extend icp_backend.gd with submit_score(): emit the design §8 score_event
  (final:true) via the sentinel-approved window.parent.postMessage template; no
  direct key handling in the game. Include run_hash (cheap integrity token).
- SECURITY SENTINEL re-audit (new write surface) — must pass. Update
  docs/security/GAME_SECURITY_CHECKLIST.md N/A items now that a leaderboard exists.
- GATE: submit_score_emits_test — the postMessage payload matches the schema and
  only fires on the final screen / player confirm.

PHASE 5 — ICP canister via Caffeine (backend)
- Use the Caffeine tools to create a Motoko canister smoke_realm_ledger:
  submit(principal, banked_score, holdings, run_hash) with value CAPS + a
  tamper-evident event log, and leaderboard() read. Deploy; put its id in
  config.json.icp.player_registry_canister_id.
- Wire icp_backend.gd read path to the new canister (leaderboard already reads by
  canister id).
- GATE: icp_backend_offline_test — with an empty/invalid canister id the game
  plays fully and reads fall back (ADR rule); with a stub id the endpoint URL is
  built correctly.

PHASE 6 — Website bridge (separate repo: lil-blunt-smoke-realm)
- In the website: listen for score_event, run II/wallet auth, relay signed writes
  to the canister; post icp_identity back so the game shows "signed in as …".
- This is a task in THAT repo (this session's GitHub tools are scoped to gm-game).
- GATE (website side): a Playwright test that the iframe receives icp_identity and
  the canister receives a capped submit.

Stop after each phase for founder hard-refresh sign-off before the next.
```

---

## 2. Skills to use / author

### Use (already in repo)
- **`economy-designer`** (agent) — balance the multiplier curve + pickup values.
- **`game-logic`**, **`game-flow`** — GameManager/StateMachine/SceneRouter changes.
- **`design-system`**, **`create-architecture`** / **`architecture-decision`** — write
  the ADR for the ledger + trust model (CLAUDE.md: every new system needs an ADR).
- **`game-security-sentinel`** + **`secure-build-checklist`** — mandatory re-audit at
  Phase 4/5 (leaderboard + on-chain write is a new surface).
- **`itch-deploy`** / **`release-game`** — ship each phase.
- **Caffeine app skill** + **Motoko skill** (fetch at build time):
  `https://skills.internetcomputer.org/skills/caffeine-app/SKILL.md` and
  `.../skills/motoko/SKILL.md` — for the canister in Phase 5.

### Author (new, so findings persist)
1. **`gm-economy-ledger`** — the single source of truth for the token taxonomy
   (3 classes), pickup values, the multiplier formulas, and the banked-vs-run
   death rule. Do-not-regress: banked never lost; base always kept; values stay in
   config.json.
2. **`gm-icp-caffeine-bridge`** — the postMessage contract (design §8), the
   submit/read canister interface, and the trust rules (client score untrusted;
   canister caps; game holds no key; addresses only in config.json).
3. **`gm-level-summary-flow`** — the LEVEL_COMPLETE → Summary → Continue/Save&Quit
   → FinalScore → Save-to-Blockchain state contract, so the flow can't regress into
   a soft-lock (ties into the existing freeze/soft-lock gates).

---

## 3. Definition of done (per the founder brief)

- [ ] Coins/rings/tokens/lives each have ONE defined rule (design §2).
- [ ] First-attempt Blaze Rush = max multiplier; 10th = floored, still fair (§3b).
- [ ] Per-level summary screen; player picks Continue or Save & Quit (§5).
- [ ] Final boss → final score → Save to Blockchain via ICP (§6).
- [ ] Boss catch = lose current-level points + lives; **previous levels stay banked** (§4).
- [ ] Game ↔ website ↔ canister contract implemented both sides (§8).
- [ ] Security sentinel green after the leaderboard/on-chain surface is added.
- [ ] Founder hard-refresh sign-off at each phase.
```
