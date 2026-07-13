# 🌿 Lil Blunt: The Smoke Realm — Live Status Report

**Play it (primary):** https://youngstunners88.itch.io/lil-blunt-adventure
**Mirror:** https://lil-blunt-game.vercel.app
**Branch:** `claude/setup-game-dev-environment-itWJv` · **PR #2**

> This report is updated, committed, and pushed on every change so you always
> have something current to look at. Last updated: **2026-07-12**.
> **State: RELEASE CANDIDATE — awaiting final art assets** (animation frame
> sheets + Weed Leaf/Mushroom sprites; specs in `ASSET_MANIFEST.md`).

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
