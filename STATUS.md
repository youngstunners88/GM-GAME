# 🌿 Lil Blunt: The Smoke Realm — Live Status Report

**Play it (primary):** https://youngstunners88.itch.io/lil-blunt-adventure
**Mirror:** https://lil-blunt-game.vercel.app
**Branch:** `claude/setup-game-dev-environment-itWJv` · **PR #2**

> This report is updated, committed, and pushed on every change so you always
> have something current to look at. Last updated: **2026-07-18** (Layer Shift
> + PR #5 review fixes verified: browser boot 5/5 gates, web3 bridge loads).
> **State: RELEASE CANDIDATE + LAYER SHIFT** — the platformer is complete; on
> top of it we just built the Movie + Video-Game layers (wallet, NFT badge,
> token perks, AI Oracle, on-chain leaderboard, community lore, funnel).

## 🟢 THE STACK IS LIVE (2026-07-20)

**Backend deployed and answering**: https://lil-blunt-backend.teacherchris37.workers.dev
Ask the Oracle in-game — Mistral answers in character, live. Leaderboard,
analytics, adaptive difficulty, and the whole email engine (welcome sequence,
Monday digests, milestones, referrals, AI support triage) are ACTIVE on
`smokering-notifications@agentmail.to`. You received the first production
Welcome email as the E2E proof. First Monday digest stops at Drafts for your
approval (DIGEST_DRAFT_ONLY=1). Cross-chain token perks are live server-side
(SMOKE on Base + DIAMONDS/GOLD on Ethereum, read correctly no matter the
wallet's chain).

**Kimi K3 stress-test gate (mandatory, passed)**: 90-file GDScript sweep +
full architecture review + player-copy review. Real catches fixed same-day —
incl. a wallet-connect race that made every FIRST connect silently fail, a
mail-scanner-can-delete-your-data footgun, referral hardening (confirmed
subscribers only), an Oracle daily cost circuit-breaker, and 5 tagline
rewrites (the "no rug pulls, promise" line is gone — Kimi was right, that
reads like a red flag). Full trail: `KIMI_AUDIT_FEEDBACK.md`.

**In the next build (this push)**: 50 reviewed share taglines, FOLLOW ON X
button, polished onboarding copy, all audit fixes.

## ⚡ ACTIVATION SPRINT (2026-07-19 evening) — one credential from fully live

- **Email is REAL now**: created `smokering-notifications@agentmail.to` and
  sent you a live test email (check your inbox!). A Kimi-drafted weekly
  newsletter is sitting in AgentMail marked needs_approval — nothing sends
  without you. Free-tier caps found: no 2nd inbox / no custom domain —
  a plan upgrade unlocks support@smokering.game.
- **Your token contracts are verified and wired**: I checked all three
  ON-CHAIN before touching config — SMOKE is on Base; DIAMONDS + GOLD are on
  Ethereum (not Base!). Built a cross-chain read endpoint so perks work no
  matter which chain a player's wallet is on. Privacy preserved: reads are
  stateless, addresses never stored.
- **In the game build**: "NEW TO CRYPTO?" onboarding (plain-English, exact
  safety wording, MetaMask guide), full OFFLINE MODE (banner, cached
  leaderboard, offline Oracle FAQ, queued analytics that sync on reconnect),
  @smokering25 + t.me/LilBluntdotWin on every share/button, rotating share
  taglines (Kimi refreshes weekly, you approve).
- **Content engine RUNNING**: this week's taglines + 5 X drafts for
  @smokering25 are in `marketing/assets/` — paste-ready.
- **Ops budget documented**: `docs/OPERATIONS_BUDGET.md` (~$10–50/mo now).
- **The one blocker**: the Cloudflare key you provided is valid but has no
  account access, so I couldn't deploy the Worker. Fix = 1 minute: grab your
  Account ID from the Cloudflare dashboard sidebar → set CLOUDFLARE_ACCOUNT_ID
  → I run `./scripts/deploy-backend.sh` (it does literally everything else).

## 🏗 NEW — ICM RESTRUCTURE + COACH'S SECURITY GATE + L2/L3 DEPTH (2026-07-19)

- **ICM Architect structure** (your coach's framework, github.com/RinDig/icm-architect):
  the repo now opens with `00-welcome.md` → `01-architecture.md` → `02-status.md`,
  and four track nodes (`godot-client/`, `backend/`, `marketing/`, `docs/`) each
  carrying context / current-state / next-task / decision-log. A fresh session
  can walk in cold and know exactly what to do — nothing physically moved, so
  zero risk to res:// paths or CI.
- **Coach's secure-build-checklist is now a CI gate**: `scripts/security-audit.ts`
  (33+ checks, stack-adapted) blocks deploys on critical/high, uploads
  `security-report.json`, comments blockers on the PR. Its first run caught
  two REAL gaps — we collected emails with no ToS/Privacy and no data
  export/delete flow. Both fixed properly: `terms.md` + `privacy.md` written,
  and real `/data-export` + `/data-delete` endpoints added (linked in every
  email footer). Gate now green: 28 pass / 0 fail. Manual gates:
  `DEFI_REVIEW.md` (contract addresses + no-approvals posture) and
  `ANDROID_EXPORT_SECURITY.md` (pre-committed for a future Android build).
- **Levels 2 & 3 got the full depth treatment** (`LEVEL_23_EXTEND.md`):
  Crystal Caverns — mirrored crystal one-way arc, two full-height shaft
  ladders, 3 secret walls. Gold Rush — pressure-plate TIMED-GATE run onto a
  golden coin lane, ladder, 3 secret walls, and the token-gated
  **FORT KNOX VAULT** community room before the boss.
- **Both Mistral keys validated (HTTP 200)** — the Oracle is fully unblocked
  the moment the backend deploys. Key #2 wired as automatic failover.
  Vibe CLI installed (v2.21.0); `vibe --setup` is interactive — yours to run.

## 🕹 NEW — LEVEL DEPTH AS VIDEO-GAME LAYER (2026-07-19, task #23)

Level 1 got deeper — and every mechanic serves data or marketing, not just
platforming. Full mapping + analytics schema: **`LEVEL_DEPTH.md`**.

- **Invisible adaptive difficulty**: the level reads YOUR death heatmap and
  quietly adjusts (slower Tax Collectors, boulder warnings, extra checkpoint,
  a Hint Leaf for heavy retriers). No UI — it just feels right.
- **Secret walls** (shimmering blocks): community lore, Smoke Tips, referral
  codes — wallet holders find Diamond Shards 20% of the time.
- **Three routes per section**: Speedrunner (high one-way chain, coin-rich),
  Casual (the original), Explorer (secrets + the Hall of Blaze).
- **Ladders + one-way platforms** with climbing (W/S + arrows), placed as
  escape routes out of the deadliest pit approaches.
- **Token-gated boss spectacle**: DIAMONDS → reflectable Diamond Surge shards;
  GoldMine → golden safe platforms at phase 3; SMOKE → Blaze lasts 2× in the
  fight. No wallet → the exact standard fight, zero penalty.
- **Snapshot Moments** at checkpoints (F12/P → pre-filled X share) and the
  **Hall of Blaze** (token-gated room: community graffiti + weekly top-10).
- **Kimi K3 via OpenRouter** (key validated ✅): support-triage LLM tier,
  1-call/week digest blurb, and `scripts/kimi-review.sh` — cheap-token
  GDScript review. This is now the working LLM layer while the Mistral key
  is missing.

## 📬 NEW — AGENTMAIL MARKETING ENGINE (2026-07-19)

The game can now talk to players by email — capture, campaigns, support, and
your founder digest — via AgentMail, all inside the existing backend. Setup
guide: **`AGENTMAIL_SETUP.md`**. Additive only; nothing existing changed.
Hardened after adversarial review (abuse quotas, double opt-in, signed
webhooks) and **browser-verified end-to-end**: boot 5/5 gates with the new
stricter check that requires real gameplay, not just a quiet console. Bonus:
that stricter check exposed and fixed a shipped UI bug — the wallet/Oracle/
leaderboard menu buttons had been rendering off-screen; they're visible now.

| Feature | Layer | State |
|---|---|---|
| Optional email capture on first play (consent checkbox, skippable forever) | 🎬 | ✅ In game |
| Welcome sequence (immediate / day-3-if-idle / day-7) | 🎮 | ✅ Code complete |
| **Monday weekly digest** — personal rank, delta, death stats + boss tips, top 3, CTAs | 🎮 | ✅ Code complete |
| Milestone emails (first Auditor kill, top-10) | 🎮 | ✅ Code complete |
| **Founder digest to you every Monday** (players, wallets, CTA clicks, referral conversion, Oracle top questions) | 🎬 | ✅ Code complete |
| Two-way AI support (support@smokering.game → AI-drafted replies, human-review labels) | 🎮 | ✅ Code complete |
| Referral engine (invite a friend + 48h follow-up + conversion tracking) | 🎮 | ✅ In game + backend |

**To activate** (one-time, ~20 min): AgentMail API key → verify
`smokering.game` DNS (SPF/DKIM/DMARC) → create 2 inboxes → set worker vars →
`wrangler deploy`. Every step is copy-paste in `AGENTMAIL_SETUP.md`.
Compliance is built-in: consent required, one-click unsubscribe on every email,
1-email/player/day cap, idempotent sends. Security: checklist **Section G**.
(Facebook/Instagram/TikTok deliberately excluded for now — reasoning in the doc.)

## 🚀 LAYER SHIFT (your coach's value-stack framework, shipped)

We moved the game up the stack: **📖 Book** (the platformer, unchanged) →
**🎬 Movie** (baked-in SmokeRing/DIAMONDS/GoldMine context) → **🎮 Video Game**
(interactive + self-improving from player data). Full mapping in
**`LAYER_SHIFT.md`**. What was built:

| Feature | Layer | State |
|---|---|---|
| Wallet-gated **"SmokeRing Survivor" NFT badge** after the boss | 🎬 Movie | Code complete — needs your ERC-721 address |
| **Token-tied perks** (SMOKE→Blaze 30s, GoldMine→golden skin, DIAMONDS→Crystal portal) via real `balanceOf` | 🎬 Movie | Code complete — needs your token addresses |
| **Mistral Oracle NPC** — chill stoner-sage who knows your lore | 🎮 Video Game | Code + backend proxy complete — needs a **working Mistral key** |
| **On-chain-identity leaderboard** (top 20, `0x1234…5678`) | 🎮 Video Game | Code + backend complete — needs backend deployed |
| **Community lore submission** → top-voted become loading tips | 🎮 Video Game | Code + backend complete — needs backend deployed |
| **Funnel**: JOIN THE SMOKERING + VIEW YOUR NFT + anon click tracking | 🎬/🎮 | Telegram link live; rest needs contract/backend |

**Everything degrades gracefully** — with no wallet/backend/contracts the game
plays exactly as before. Activation is config-only (no code changes): fill
`config.json` + deploy `backend/`. **3 one-time inputs from you:** a valid
`MISTRAL_API_KEY`, a deployed backend URL, and your real contract addresses.
Security re-audit for the new backend/wallet surface: `GAME_SECURITY_CHECKLIST.md`
**Section F** (all green now; two deploy-time P0s — rate-limiting + CORS — noted
in `backend/README.md`).

## 🎉 BUILD IS ON ITCH.IO — one click left: hit Publish

The full pipeline went **green end-to-end** (2026-07-12): secret scan ✅,
Godot export ✅, browser-verified ✅, **butler upload to itch.io ✅** — the
current build (feel pass + combat) is sitting on your project's `html5`
channel right now.

The public page still shows 404 because the project is saved as **Draft** —
itch.io hides drafts from everyone except you. Final step, ~10 seconds:

1. Open your project → **Edit game**
2. Under **Uploads**, confirm the butler build is there and check
   **"This file will be played in the browser"** if it isn't already
3. Set **Visibility → Public** and Save

Then https://youngstunners88.itch.io/lil-blunt-adventure is live for the
world. Every future push to the branch auto-deploys — no more manual steps,
ever.

---

## ▶️ What works right now

| System | State |
|---|---|
| Boots & plays on mobile/desktop | ✅ Live |
| Controls (run / jump / double-jump / sprint / dash) | ✅ In build |
| **Combat: axe throw + purple 3-axe fan + ETH-flask fire breath** | ✅ **NEW** — key `J`/`Enter`, mobile `ATK` |
| 3 levels + boss arenas | ✅ Load & spawn |
| Painted key-art backdrops (your art) | ✅ **NEW** — GM Forest, Crystal Caves, Gold Rush |
| Boss backdrop swap (Tax Collector / Crystalline Bureaucrat / Bandit) | ✅ **NEW** |
| Collectibles: coins, ETH rings, GOLD, wBTC, Diamonds | ✅ |
| Combo system + score multiplier | ✅ |
| Blaze Rush secret runs (Geometry-Dash) | ✅ unlock at score thresholds |
| GoldMine economy (GOLD/wBTC/XAUT/Diamond, whitepaper split) | ✅ |
| Browser auto-verification gate (catches crashes pre-deploy) | ✅ |

## 🎨 Art status

- **Backgrounds:** purpose-made client environments — GM Forest, Crystal
  Caves, Gold Mine interior, FOMO boss arena. DONE.
- **Lil Blunt:** REAL pixel-art sprites in-game — cowboy (L1/L3), miner &
  crystal outfits (L2), auto-swapped per level. DONE this update.
- **Bosses:** real sprites — IRS Tax Collector, Crystalline Bureaucrat,
  Bandit mine-cart. DONE this update.
- **Enemies / collectibles:** REAL AI-generated pixel sprites in-game — Tax
  Collector minion, fly, boulder, hostile vine, coin, ETH ring, GOLD nugget,
  Diamond shard. DONE this update (generated via Muapi/Flux, bg-removed,
  downscaled to game size).
- **New items:** Purple Weed power-up plant, Pickaxe & Torch tools — all with
  real sprites, placed in all 3 levels.

## ✅ SECURITY: leaked-key incident RESOLVED (git history scrubbed)

The secret scanner had caught two Ethereum private keys (plus a pile of API
keys/JWTs) buried in the repo's very first commit — an old "workspace backup"
from before the game existed, since public. **Fixed this session:** git history
was rewritten twice with `git filter-repo` to (1) drop every trading-bot file
and redact both key strings, then (2) strip the entire non-game workspace
backup, keeping only the 26 real game paths. Force-pushed to all three branches.
A full-history secret scan is now **clean** (verified: 0 key occurrences). You
confirmed the keys were unknown to you and held no funds, so no rotation was
needed — the scrub is the close-out. Full incident + before/after in
`docs/security/audit-log.md`.

## 🔧 Known gaps → next up (priority order)

1. **Full walk/jump frame animation** for Lil Blunt (a procedural run-bob +
   jump stretch ships now; hand-drawn frames still welcome).
2. **Level design depth** — more platforming, secrets, reasons to explore.
3. **SFX pass** — music is IN (12 tracks); jump/coin/damage sounds still placeholder.
4. **Weed Leaf + Magic Mushroom sprites** (the last two placeholder squares).

## 🌐 Hosting: moved to itch.io (root cause of "sometimes doesn't play" found)

The intermittent boot failures were traced to the web export's **threaded
mode**, which requires SharedArrayBuffer — a browser feature that silently
fails without special server headers, in many iframes, and on some mobile
browsers. Fixes shipped:

- Export switched to **non-threaded** — boots everywhere, no special headers,
  no more silent failures.
- **itch.io is now the primary platform** — game-native CDN (no cold starts),
  built-in discovery/analytics, and 90M+ players/month. Vercel stays as a mirror.
- CI now auto-packages an itch-ready zip **and auto-deploys via butler**
  (itch.io's official CLI) once the `BUTLER_API_KEY` secret is added.

## 🗓 Changelog (newest first)

- **2026-07-17 (depth & dynamics: bosses, stakes, secret realm)**
  - **Bosses have voices + personalities**: 33 taunt lines across 3 distinct
    ElevenLabs voices — the Tax Auditor (condescending), the Crystalline
    Bureaucrat (cold corporate), the Bandit (unhinged) — firing on spawn,
    every 8–12s, on hits, at phase changes, and on death. All crypto-flavored.
  - **Bosses are threatening now**: 3 HP-scaled phases each, with aimed ranged
    attacks that escalate — clipboard 1→triple, ETH orbs 3→5-homing, dynamite
    that lands on you 1→3 sticks. (The most elaborate set-pieces — audit beams,
    teleport pedestals, runaway cart — are a documented follow-up.)
  - **Raised stakes**: a **lives** system (3). Falling in a pit now plays a
    devastating sound and costs a **life**, not just health — respawn at
    checkpoint if lives remain, game over to menu when out. LIVES shown on HUD.
  - **Your track is in the game**: shuffled into all 3 stage rotations (never
    the boss fights), crossfading with the existing themes.
  - **Walk read**: added swinging legs + body lean so he clearly walks and
    faces his direction. (Full hand-drawn leg/arm frames still want sprite
    sheets — see ASSET_MANIFEST.)
  - **NEW secret realm — the Chill Lounge**: a hidden glowing door → a
    decorative bonus stage with real parallax **depth** (two matched Muapi
    backdrops at very different scroll speeds = a 3D feel in 2D), announcer
    commentary on the way in/around/out, bonus crypto coins + health, and a
    portal that returns you to the **exact door** you entered. New
    `game-secret-realm-forge` skill masters authoring these.
  - Kept the lounge **tasteful/atmospheric** (velvet couches, glowing bongs,
    cosmic neon, relaxed silhouettes) rather than sexualized, per the game's
    own content rules — flagged for you.
  - **Still open / need input**: `MONID_API_KEY` is set but I can't identify
    the service — send a docs link and I'll wire it. And the big Part-3/4
    suite from the earlier brief (ladders, one-way tunnels, breakable secret
    walls, 3-key ETH-shard boss gating + completion %, live crypto ticker) is
    NOT built yet — no QuickNode key for the ticker either. Next session.

- **2026-07-16 (playability fixes + crypto-visual overhaul)** — acting on
  your playtest feedback:
  - **Falling into a ditch now kills + restarts** — this was a real bug: the
    pit's detector was on the wrong collision layer and never saw the player.
  - **Attacking is now discoverable** — the axe throw (J / mobile ATK) always
    worked, but nothing told you; added a control hint at level start. He
    throws a pickaxe-axe, so it reads as attacking with an item.
  - **THE BONG** — a rare bonus pickup, hidden high/hard-to-reach in every
    level. Smoke it → 10 seconds of flight (hold jump to rise). "BONG LIFT-OFF."
  - **Coins are crypto now** — Ethereum in the Smoke Realm, Solana in Crystal
    Caverns, Bitcoin in the GoldMine, each worth more than a plain coin.
  - **Platforms are literal blockchain blocks** — glowing cyan crystal cubes
    with hash etchings, tiled across every ledge. The theme is in the geometry.
  - **Backgrounds regenerated** cohesive + premium (Muapi Flux) — each realm
    its palette with a shared floating-blockchain-cube motif; the muddy
    3-layer parallax that made them look cheap is gone.
  - **Every placeholder square eliminated** — real sprites for the weed leaf,
    magic mushroom, health heart, and a clean gold coin (replacing the smiley);
    FX sparkles now use a soft dot texture instead of rendering as hard squares.
  - **New `game-aesthetics-forge` skill** — masters the Muapi art pipeline
    (API contract, transparent-sprite keying, crypto art-direction rules);
    self-activates whenever art looks cheap or a new asset needs generating.

- **2026-07-13 (THE GAME HAS A VOICE — full audio pass + branded mirror)**
  - **Every silent action now has a real sound.** All 12 missing SFX
    generated via ElevenLabs (your API key) with prompts engineered for the
    game's chill 16-bit identity: jump, double-jump, coin, ETH-ring shimmer,
    damage (soft "ouch", never violent), dash, power-up fanfare, axe throw,
    hit, explosion, fire breath, error blip.
  - **An announcer.** 9 voiceover lines in one consistent laid-back
    storyteller voice: title drop on the menu, an intro for each stage
    ("Level One… The Smoke Realm. Stay chill, Lil Blunt."), a callout for
    each boss, a victory line, and a game-complete line. Music auto-ducks
    −8dB while he speaks, then swells back.
  - **New `game-audio-forge` skill** — the whole pipeline is one command
    (`python3 scripts/generate_audio.py`), fully data-driven from
    `assets/audio-manifest.json`, with the SFX prompt-engineering rules
    written down so future sounds match. Any new `play_sfx()` call
    triggers regeneration automatically per the skill's activation rules.
  - **New mirror on YOUR domain (via your Cloudflare)**: a `gh-pages` build
    branch is pushed and auto-refreshes on every CI export. One click from
    you and the game is live at **https://mnguniproject.co.za/GM-GAME/** —
    repo → Settings → Pages → Source: "Deploy from a branch" →
    `gh-pages` / root → Save. Your Cloudflare proxy (already fronting the
    domain) gives it HTTPS + CDN caching worldwide. Note: the Cloudflare
    API token you added is zone-scoped (DNS-level) — I verified it can
    manage DNS on mnguniproject.co.za but not Pages/Workers/zone-settings;
    if you ever want me to go further there (redirects, headers at the
    edge), a token with Pages + Zone-Settings permissions unlocks it.
  - **Browser-Use key**: noted and reserved — its best use is automated
    live-page QA on the real itch.io page (checking the actual embed, on
    real mobile viewports) the moment you flip the page Public. Local
    pre-deploy testing is already covered by the Playwright harness.

- **2026-07-13 (content completeness + autonomous security sentinel)**
  - **Content audit found and fixed 2 real gaps**: the checkpoint system
    (full save/restore code existed) was wired with a hardcoded level index
    — a Level 2/3 checkpoint would have silently overwritten Level 1's save
    slot — and **zero checkpoints were ever placed in any level**, so it was
    dead code end-to-end. Fixed the level-index bug and added 2 mid-level
    checkpoints to each of the 3 levels. Also found Levels 2 and 3 had **zero
    health pickups** anywhere — added 2 to each.
  - **Investigated a 4th boss-looking file** (`bandit_boss.gd/.tscn`) not
    wired into any level. Conclusion: it's an earlier, simpler draft
    superseded by `claim_jumper.gd` (Level 3's actual, more complete boss —
    integrated with the GoldMine Auction/Fort Knox economy). Not a gap;
    flagged as dead code worth archiving in a future cleanup, left untouched
    to avoid downgrading the shipped fight.
  - **New autonomous security layer**: `scripts/security-sentinel.sh` — 18
    checks (secrets, GDScript-equivalent injection/RCE, deploy integrity,
    wallet-UI trust, CI hygiene), adapted from an uploaded generic SaaS
    checklist into this game's actual client-only architecture. Includes a
    check the *previous* checklist didn't have and genuinely needed: a
    64-hex private-key scan — the earlier wallet-address regex only matched
    40-hex addresses and would **not** have caught the private keys that
    leaked into this repo's history two days ago. Wired into 3 layers so it
    runs without ever being asked: mid-session (new `game-security-sentinel`
    skill, self-activates on security-relevant edits), every release
    (`release-game.sh` Step 1), and every CI push (new workflow step,
    independent of any chat session). All 18 checks pass clean right now.

- **2026-07-12 (P0–P2 polish pass → RELEASE CANDIDATE)** — the "final 10%"
  sweep, all in one push:
  - **Parallax depth**: every level's key art now scrolls in 3 layers (slow
    cooled far / main mid / fast foreground strip) — the world finally has
    depth when you run. Boss-arena art swap still works across all layers.
  - **Animation pipeline**: full state-driven system (idle/run/jump_up/
    jump_down/attack/hurt/death for Lil Blunt; idle/walk/attack/hurt/death +
    `animation_finished` for bosses). Wired and live — drop the frame sheets
    from `ASSET_MANIFEST.md` in and it animates with zero code changes.
  - **FX pack**: coin sparkles, enemy-death explosions, dash trails, orbiting
    Diamond aura, victory confetti — all spawned via a new EffectSpawner.
  - **HUD juice**: floating damage numbers, combo counter that pops and heats
    white→gold→red, white screen-flash + heart-row shake on damage.
  - **Menu glow-up**: GM Forest key art behind the title, drifting smoke,
    floating ETH rings, button hover/focus glow, `v1.0.0 — BLOCK 420` tag.
  - **Feel extras**: tiered screen shake (pickup/hit/boss), camera zooms to
    0.85 for boss fights and back on victory, smoke-dissolve and
    diamond-shatter scene transitions (bosses exit through the diamond wipe).
  - **Audio**: per-realm reverb (forest/cave/mine/boss), music now
    duck-crossfades between stage and boss themes instead of hard-cutting,
    coins/impacts play positionally in 2D space.
  - **Security audit (12-item, all .gd files)**: 1 real fix — save-file
    values are now clamped (a hand-edited save could load 9999 health);
    everything else clean. Full table in `SECURITY_AUDIT.md`.
  - Deviations from the brief, with reasons: no ColorRect frame placeholders
    (real sprites already ship — building the system instead of regressing
    art), and TileMap platform migration deferred (platforms are already
    data-driven in `.tres` resources; TileSet authoring needs an editor
    session + art extraction — documented for a follow-up).

- **2026-07-12 (SHIPPED TO ITCH.IO)** — first successful butler deploy: the
  email gate cleared, the pinned-fingerprint secret-scan false positives were
  resolved, and run 29201398665 pushed the browser-verified build (feel pass +
  combat + PR-review fixes) to the `html5` channel. Awaiting one owner click
  (Draft → Public). Also merged the external PR #4 review: web/mobile touch
  detection fixed for the Web export (touch controls + ATK button now appear on
  itch mobile), vines are hittable by axe & fire breath, the CI export-commit
  now lands before the deploy step (stale-mirror bug), and a checksum-fallback
  shell bug was fixed.

- **2026-07-12 (combat + cleanup)** — LIL BLUNT CAN FIGHT BACK:
  - **Axe throw** is the new base attack — press `J`/`Enter` (or the mobile
    `ATK` button) and Lil Blunt hurls a spinning axe that kills a minion or
    shatters a boulder. 0.4s between throws.
  - **Purple Weed now supercharges the attack**, exactly as you asked: a tap
    throws a **three-axe fan** (mob-clear), and *holding* the button makes him
    **swig the ETH flask and breathe a cone of fire** that burns everything in
    front of him. Purple is now a true triple-threat (speed + multi-axe + fire).
  - Built as a self-contained `CombatHandler` (movement code untouched); full
    design + numbers in `docs/architecture/adr-combat-system.md`. Follow-ups
    scoped: ground-slam stomp, spin attack, axe ammo.
  - **Removed the demo wallet-connect feature entirely** (your call — it was
    unnecessary): the WALLET DEMO button, the Web3Manager, and the boss
    score-submit stubs are all gone. Security gate updated so wallet UI can
    only ever return *with* explicit DEMO labeling.
  - **Security incident closed** — git history scrubbed clean of the old leaked
    keys (see security section above).

- **2026-07-12 (feel pass + security incident)** — GAMEPLAY FEEL PASS: the
  game finally *feels* like a 16-bit platformer, not a physics demo.
  - **Jump arc**: falls 1.65× faster than it rises (same jump height, ~12%
    less airtime) — the classic snappy arc. Terminal velocity added.
  - **Run**: proper acceleration ramp (~0.1s to full speed) and crisp stops,
    replacing instant start/stop. Dash, knockback, and wall-jump momentum now
    carry and bleed off naturally instead of vanishing after one frame.
  - **Forgiveness**: coyote time up to 6 frames, jump buffer to 0.12s.
  - **Camera lookahead**: the view leads the direction you're moving (±56px)
    and peeks down during fast falls — you see where you're going.
  - **Impact**: hits now have hitstop (70ms freeze-frame) + stronger
    knockback; hard landings squash (that animation existed but was never
    wired); air dash is 2× run speed and flattens your arc — an actual move.
  - Full numbers + rationale: `docs/architecture/adr-gameplay-feel.md`.
  - **SECURITY**: gitleaks (added last audit) caught two real Ethereum
    private keys in pre-game git history from a March workspace-backup
    commit — repo is public, keys are burned. Owner notified (see notice
    above), incident logged in `docs/security/audit-log.md`, wasm false
    positives allowlisted via `.gitleaks.toml`, history scrub pending
    owner approval.

- **2026-07-12 (itch key)** — itch.io API key added to the environment and
  verified live: authenticated successfully as `youngstunners88`, downloaded
  + SHA-256-verified butler 15.28.0, attempted a real push of the current
  build. Blocked only by the game page not existing yet (`invalid game` —
  itch.io requires the page to be created via their web UI first, no API for
  it). Everything else in the pipeline is proven end-to-end and ready to fire
  the instant the page exists — see the action-needed section above.
- **2026-07-12 (security)** — SECURITY CHECKLIST ADAPTED + AUTOMATED: took the
  general "vibe-coded SaaS app" security checklist you provided and rewrote
  it against what this game actually is (client-only static Godot export, no
  backend/DB/accounts/payments) — see `docs/security/GAME_SECURITY_CHECKLIST.md`.
  Ran the first audit (`docs/security/audit-log.md`): all real checks PASS
  (no leaked secrets, DEMO wallet labeling intact, no hardcoded addresses,
  non-threaded export intact, postMessage origin-checked). Found and fixed
  one gap: CI had no secret-scanner, now runs `gitleaks` on every push and
  fails the build on any finding. Found one open item needing a human with
  Vercel access: the live mirror is missing 3 headers (CSP, nosniff,
  referrer-policy) that are defined in `vercel.json` but not appearing on the
  live response — likely a stale deploy. **This audit now runs automatically,
  unprompted, on every `/release-game`** (Step 1/6) — it blocks the release
  if secrets leak, a real wallet address gets hardcoded, or the threaded-export
  bug regresses. No need to ask for a security check going forward.
- **2026-07-12 (music)** — REAL MUSIC IN-GAME: your 12 tracks wired with a
  shuffle system — every stage cycles its two songs at random (never the same
  one twice in a row), every boss fight has its own two-song rotation, and
  the final boss (Bandit, Level 3) gets its dedicated pair. Blaze/Purple
  power-ups now hit with the fresh-boost jingle. Also hardened CI against a
  push race that failed one export run.
- **2026-07-12 (later)** — ART PASS + TOOLS & PURPLE POWER (GitHub access
  restored — all queued work is pushed):
  - **11 real sprites generated** (Muapi/Flux, 16-bit style, transparent,
    game-sized) and wired in: Tax Collector minion, fly, boulder, hostile
    vine, coin, ETH ring, GOLD nugget, Diamond shard, purple weed plant,
    pickaxe, torch. Placeholder squares for enemies/collectibles are GONE.
  - **NEW: Purple Weed power-up** — the flagship strain: faster + higher than
    Blaze Mode, rapid auto-puffs, royal purple glow (15s). In all 3 levels.
  - **NEW: Tools Lil Blunt can carry** — Pickaxe (smashes boulders, breaks
    blocks by walking into them, 2× GOLD mining yield) and Torch (heat aura
    damages nearby enemies, warm glow — made for Crystal Caverns). Tool shows
    in his hand while active.
  - **Run animation** — procedural run-bob + existing jump stretch/land
    squash; walking finally reads as motion, not a sliding statue.
  - Vine hitbox now matches its visual (used to hit below while drawn above).
- **2026-07-12** — SECURITY + STABILITY SWEEP (specialist audit, bug hunt,
  stress test):
  - **Stress test built & passed** (`scripts/stress-game.mjs`): 45s random
    input mashing, 40 rapid pause toggles, 45s travel soak — zero crashes,
    zero errors, memory flat at ~45MB (no leaks).
  - **Security audit (10 findings, all addressed or accepted)**: fake
    "wallet connected / TX submitted" flow relabeled to explicit DEMO mode
    (no fake tx hashes — real-brand trust risk); postMessage origin checks
    both directions (launcher + game); CI supply chain pinned (butler 15.28.0
    + SHA-256, Godot verified against official SHA-512 sums); CSP +
    nosniff + referrer headers added to the mirror.
  - **5 gameplay bugs fixed** (from crash-hunt): HUD showing stale hearts
    after every level change; player death during boss victory soft-locking
    the game to main menu; scene-load failure permanently freezing the
    session (now recovers); wBTC/GOLD double-collection exploit; mine cart
    fast/slow types never applying (day-88/day-288 economy was dead code).
  - **HUD glyph fix**: emoji icons (tofu boxes on web) replaced with real
    heart pips + text labels — HUD is finally readable in production.
- **2026-07-11** — Verification harness PROVEN against the real game: headless
  Chromium now boots the build, clicks PLAY LEVEL 1, and screenshots live
  gameplay (Lil Blunt + HUD + GM Forest — evidence in `game-verify-level.png`).
  Hardened `scripts/verify-game.mjs` (real boot detection — a splash screen no
  longer counts as a pass; WebGL/SwiftShader flags; benign-warning filtering).
  Fixed audio error spam (`audio_manager.gd` now skips missing placeholder
  tracks). GitHub push still blocked (403) — commits queued locally.
- **2026-07-10** — itch.io migration: root-caused intermittent boot failures
  (threaded export → SharedArrayBuffer dependency), switched to non-threaded
  export, built full itch.io pipeline (CI butler auto-deploy + itch-ready zip
  artifact + `scripts/deploy_itch.sh`), new `/itch-deploy` skill. Awaiting
  owner's itch.io page + `BUTLER_API_KEY` secret to go live.
- **2026-07-09 (verified+live)** — Sprite build browser-verified (cowboy Lil
  Blunt standing on GM Forest platforms, 0 errors), deployed to production,
  and **merged to master** — the repo homepage now shows the full project.
- **2026-07-09 (later)** — REAL CHARACTER ART IN-GAME: client sprites wired
  for Lil Blunt (cowboy/miner/crystal outfits, per-level swap, feet-aligned)
  and all bosses (Tax Collector, Crystalline Bureaucrat, Bandit cart).
  Purpose-made environments replace cropped backdrops. New /sprite-pipeline
  skill. Rules added: keep master current + model advice each response.

- **2026-07-09** — Real painted backdrops from client key art wired into all 3
  levels + boss arenas; platforms restyled to read over art; key art archived
  in `assets/keyart/`. Living STATUS report + always-push rule added.
  **Browser-verified (GM Forest renders, 0 errors) + deployed to production.**
  Remaining eyesore now = enemies/coins/character are still small shapes over
  the art — that's the next sprite pass (needs image-gen key or supplied PNGs).
- **2026-07-08** — Fixed 5 layered defects that made the game unplayable
  (boot, 8 parse errors, missing input map, black-screen scene load, empty
  level data). Added browser verification harness + `/game-graphics`,
  `/playtest-web`, `/export-deploy` skills.
