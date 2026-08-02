# 🌿 Lil Blunt: The Smoke Realm — Live Status Report

**Play it (primary):** https://youngstunners88.itch.io/lil-blunt-adventure
**Mirror:** https://lil-blunt-game.vercel.app
**Branch:** `claude/setup-game-dev-environment-itWJv` (new PR open against `master`, following PR #11's merge)

> This report is updated, committed, and pushed on every change so you always
> have something current to look at. Last updated: **2026-08-08** (the
> remaining 9 defects addressed — the death-freeze root cause found and fixed;
> boss taunts expanded so they stop repeating).
> **State: RELEASE CANDIDATE + LAYER SHIFT** — the platformer is complete; on
> top of it we just built the Movie + Video-Game layers (wallet, NFT badge,
> token perks, AI Oracle, on-chain leaderboard, community lore, funnel).

## 🩹 REMAINING 9 DEFECTS + DEATH FREEZE ROOT CAUSE — 2026-08-08

Every item below was **proven this session** with an in-engine test (built,
run, deleted — not committed), not "should work." The one that mattered most:

**The death freeze — found the real cause.** When Lil Blunt's health hit 0,
`GameManager` flipped the game to GAME_OVER *before* the player's death code
ran — so the player's own guard saw "already game over" and bailed, and the
respawn sequence **never executed**. The game just sat frozen in GAME_OVER
with no control and no menu. On top of that, the respawn looked for a
*Level-1* checkpoint even when you were on Level 2/3, so it could never find
one. Fixed by giving the player sole ownership of the death→respawn flow, and
respawning at the **current** level. *Proof: forced a death on Level 2 → boss
appears → death → respawn → back in control, one life spent, health refilled.*

| # | Your report | Status | Proof / note |
|---|---|---|---|
| R1 | Final boss doesn't take/deal damage | **VERIFIED WORKING** | Both directions correctly wired (projectiles = layer 64, boss hitbox mask 70 = Player+Enemies+Projectiles); `distributor_behaviour` gate confirms boss HP drops through its vulnerable window. The "no impact" feel was largely the death-freeze (R2) — dying to it did nothing visible. |
| R2 | Death freezes instead of restarting | **FIXED** | Root cause above; Level-2 death→respawn probe passed. |
| R3 | Blaze Rush finish doesn't return to entry stage | **FIXED (code) / VERIFIED** | Return uses the stored entry `scene_path` + correct level-index checkpoint; probe: enter-from-L2 data → returns to L2, not L1. |
| R4 | Blaze Rush ESC restarts instead of exiting | **FIXED (code) / VERIFIED** | ESC and finish both route through the same exit-to-entry path; probe confirmed. |
| R5 | Blaze Rush reskin | **SLICE DONE** | Generated a branded crystal-cavern backdrop (OpenAI image model via OpenRouter, per the Grok art brief), cropped, wired as the far backdrop replacing the flat void. Loads + exports clean. A live in-Blaze-Rush screenshot wasn't captured (the portal is score-gated, not automatable) — see honest note below. |
| R6 | Auditor shows his back | **FIXED** | He now faces the player during patrol (he throws aimed clipboards from patrol; before, he faced his walk direction). Mirrors the already-working chase-facing. |
| R7 | L2 boss fell in a gap, fight soft-locked | **FIXED** | The Distributor now **floats** (no gravity, hard-clamped to an arena band). Probe: shoved down at 4000px/s every frame, he never leaves the band. |
| R8 | L2 boss bigger + levitating diamonds | **FIXED** | Scaled up 1.7× with a levitating diamond disc under him; the float from R7 is the "levitating". Probe confirmed scale + disc. |
| R9 | Continue loads L1 though you were on L2 | **FIXED** | The level now records itself on entry, and Continue resumes that (not "highest unlocked"). PLAY LEVEL 1 stays the explicit restart. Probe: save on L2 → Continue targets L2. |
| — | Email popup blocked PLAY | **FIXED** | The forced "Weekly updates?" popup is gone from PLAY; it's one click into Level 1. (Signup still lives on the "JOIN THE SMOKERING" button.) |
| ⭐ | Bosses repeat their taunts | **FIXED** | Auditor & Distributor now have **6 taunts + 4 mocks each** (doubled), and the picker never plays the same line twice in a row. Probe: 30 picks over 6 lines, all 6 used, zero back-to-back repeats. (The bandit's ElevenLabs voice was removed from the account so its lines couldn't be regenerated on the free tier — it still gets the no-repeat picker; documented.) |

**One honest limitation:** I could not capture live in-game screenshots this
session. Reaching the Blaze Rush requires unlocking a score-gated portal,
which isn't automatable, and the headless browser can't reliably click menu
buttons. Every fix above is instead proven by tests run inside the real Godot
engine. The R5 backdrop is integrated and verified to load; seeing it in a
live Blaze Rush run is your quickest confirmation.

Full technical write-up: `docs/session-logs/2026-08-08-remaining-9-defects.md`.

## 🔧 YOUR REPORTED DEFECTS — 2026-08-07

You were right to push back. Two of these ("torch at feet", "ladder") were
called fixed before and were not. Here is why they kept coming back, and
what is actually proven this time.

**The root cause behind BOTH:** every previous fix did maths against a
32-pixel-tall Lil Blunt whose feet sat on the collision line. **His real
artwork is 49x72**, and his visible feet sit 14px ABOVE that line. So every
"correct" calculation put things in the wrong place. This session measured
the real sprite instead of assuming, and now derives positions from the
actual artwork — so it can't silently drift again if the art changes.

| # | Your report | Status |
|---|---|---|
| 1 | Shadow block under his feet | **FIXED** |
| 2 | Torch still at his feet | **FIXED** |
| 3 | Can't climb the ladder onto the platform | **FIXED** |
| 4 | Tax Collector stuck behind a block | **FIXED** |
| 5 | Protocol logos + founder mural | **NEEDS YOUR FILES** (see below) |

**1. Shadow block — FIXED.** It was two dark rectangles drawn as fake
"legs", left over from when Lil Blunt was a plain coloured box. His real art
already has legs, so those rectangles just sat as a black block 6px below his
feet. Deleted. *Proof: 0 such objects remain on the character.*

**2. Torch at his feet — FIXED.** The torch was anchored to a hardcoded
position that assumed the old sprite size, which put its lower half below his
feet. It now anchors to his measured hand. *Proof: the torch now occupies
y -47 to -11; his feet are at +2 — the whole torch is above his feet, flame
at head height. Before, it reached +11, i.e. below his feet.*

**3. Ladder — FIXED.** This is why re-tuning the exit position never
worked: the game only "topped you out" when you got within **6 pixels** of
the ladder top, but the platform physically blocks you ~34px short of that.
The condition could never be met, so you pressed up forever under the
platform. Margin widened to clear the platform. *Proof: a scripted climb now
ends standing on the platform (y=318, on solid ground); before it stalled
underneath.*

**4. Tax Collector — FIXED.** Two bugs. He only noticed you within 200px,
and his jump was gated on *you* being within 80px — so when a block stopped
him and you were further away, he never jumped and stood there. Obstacle
hops are now unconditional (a wall means he can't advance anyway), and he
hunts far wider. *Proof: with the player 500px away and a crate in his path,
he engages, jumps, and gets past it. Under the old code he did not jump at
all.*

**5. Protocol logos + founder mural — I NEED THE FILES.** The logos came
through as images in chat, which I can't save as files into the project. The
code is already waiting for them — drop them at these exact paths and they
appear with zero code changes:
- `src/assets/logos/smokering.png` (the Lil Blunt / FOMO rocket)
- `src/assets/logos/diamonds.png`
- `src/assets/logos/goldmine.png`
- `src/assets/art/founder_portrait.png`

There's a README in each folder with the details.

### Still open from your defect document

I did not get to these, and I'm not going to pretend otherwise: Distributor
damage both ways (#1), death-freeze (#2), Blaze Rush complete/ESC resume
(#3, #4), Blaze Rush reskin (#5), Auditor facing away (#6), Level 2 boss
falling in a gap (#7), bigger levitating Distributor (#8), and
Continue-vs-Restart (#9). Those are the next session's list.

**One thing you'll hit immediately:** a "Weekly Smoke Realm updates?" email
popup covers the main menu on first load and you must dismiss it before you
can press PLAY. It blocked my automated screenshots. Worth removing or
delaying — say the word.

## 🎙️ HIS REAL VOICE IS IN (2026-08-06)

Lil Blunt now speaks with **your custom "Lil Blunt" voice** on every action
bark — hurt, going down, landing a throw, grabbing a big power-up, beating
a boss. The stand-in is gone.

**Why it failed last time:** it wasn't a missing voice. There are two
ElevenLabs keys in the environment and *both* work, but only the newer one
(`ELEVENLABS_API`) belongs to the workspace that owns his voice — the older
one simply can't see it. That's why it looked like the voice didn't exist.
The generator now always prefers the right key, with a note in the code so
it can't get flipped back.

Checked properly, not just "the download worked": every clip loads in the
real engine, starts on the right audio channel, and each one's cooldown is
longer than the clip itself, so he can never talk over himself.

## 🛠️ AND A SOFT-LOCK CAUGHT BEFORE YOU HIT IT (2026-08-06)

The "Talk to Lil Blunt" panel added last session had a real bug: closing it
from the pause menu left the game paused with **no menu on screen** — stuck
unless you pressed Escape again. An audit caught it, it's fixed, and the
fix is proven by driving the actual pause → talk → close sequence and
confirming the menu comes back every time.

Also, when you're on your last life or have just been beaten by the
Auditor, he now has a few different things to say instead of repeating one
line — those are the moments you'd hear it most.

## 🎮 YOUR TURN: PLEASE PLAY IT (2026-08-05)

**The single most useful thing you can do now is play the game for 15
minutes.** Everything below has been fixed and machine-verified, but you
have not yet played the live build — that's the biggest open risk on the
project, and no agent should call Episode 1 "done" without your pass.

**→ `docs/playtest/episode1-human-checklist.md`** — 36 ordered steps.
Tick them off, screenshot anything that fails, send back the numbers.
Nothing else in this report matters as much as that list.

**Merging PR #12 stays your decision, after you play.**

## 🗣️ LIL BLUNT HAS A VOICE NOW (2026-08-05)

He reacts out loud on the moments that matter — taking a hit, going down,
landing a solid throw, grabbing a big power-up, and beating a boss. Not on
every coin or footstep; only the moments worth a reaction, with cooldowns
so it never turns into chatter.

**One thing needs you:** the voice ID you gave me
(`HMGfKwZCRujgXyRDUW0b`) isn't reachable from our API key — ElevenLabs
requires a shared-library voice to be added to the workspace before the API
can use it, and only you can do that from the dashboard. So he's currently
speaking in a clearly-labelled stand-in voice so you can hear the timing
and feel. **Swapping to his real voice is a one-line change once you add
it** — exact steps are recorded in `assets/audio-manifest.json`.

## 💬 AND YOU CAN TALK TO HIM (2026-08-05)

"TALK TO LIL BLUNT" is on the main menu and in the pause menu. This isn't a
generic chatbot bolted on — he gets a live read-only snapshot of your run
(which level, lives left, which boss is up, whether you're in Blaze Rush,
what power-ups are active) so he actually responds to what's happening.
If the server is down he still answers, still in character, still aware of
where you are. Verified working in a real browser: asked him a question on
a fresh save and he correctly opened with "Just gettin' started. Take the
scenic route if you want, no rush."

He never talks price or promises gains — that's a hard rule in his prompt.

## 🎯 EPISODE 1 CLOSEOUT: CHASE FEEL TUNED + HONEST READINESS REPORT (2026-08-04)

Last session's feel review said the Auditor's first hit after a chase
starts landed too fast to feel fair. Fixed: he now ramps up to full chase
speed over 0.7 seconds and can't actually hurt you on contact until 0.35
seconds into the chase, instead of both happening on the exact frame he
starts moving. Top speed, his ability to jump gaps and throw while chasing,
and the "he tracks you live, not where you were" fix from before are all
unchanged. A follow-up audit on the tune itself caught a genuinely subtle
side effect — the ramp meant an early jump in the chase could now come up
just short of a gap he was supposed to be guaranteed to clear — and that's
fixed too.

**Also this session**: a full honest readiness report for PR #12 —
`docs/pr12-episode1-readiness.md` — spelling out exactly what's proven
solid, what's tuned-but-unverified-in-a-live-playthrough, and what's
deliberately not started yet. **Merging PR #12 stays your call**, not
something this session decided for you. Also wrote up the Episode 1 vs.
Episode 2 plan and the full definition of Lil Blunt's voice system (what he
says when you get hurt, land a big hit, etc., separate from the bigger
"talk to him directly" feature that comes later) — `docs/roadmap/episode-
strategy-and-voice-system.md`. No new audio was generated and no Episode 2
content was built — this is the plan, not the work, so future sessions
build the right thing in the right order.

## 🔦 TORCH-IN-HAND, PROVEN — PLUS STOMP AND THE CHASE, LIVE (2026-08-03)

The torch-at-the-feet complaint kept coming back even after "fixes" because
every fix was only ever checked with the character standing still. Turns
out there were two real bugs, both invisible at idle: the held torch never
got the same walk-cycle bounce the body does (so it visibly drifted from
the hand only while walking), and the legs were rendering 8px into the
ground on every frame. Both fixed. **First screenshot ever showing the
torch correctly held at hand height WHILE WALKING** — the exact pose that
was silently broken before.

**Also proven live, not just "should work":**
- **Stomp**: jumped on a Tax Collector's head — score +40, zero damage
  taken, bounced clean off. Along the way, hardened two real edge cases a
  fresh audit found: a stomp could previously false-trigger while climbing
  a ladder, and Big Mode's ground-pound could hit a boss during its
  protected phase (the stomp itself already excluded bosses; the pound
  didn't).
- **The Tax Collector/Auditor boss chase**: walked away from it mid-fight
  and it caught up and landed a hit — confirmed it actively pursues rather
  than standing at its spawn. Feel note from the review: the punish window
  after turning away reads a little fast for a first encounter; noted for
  a future tuning pass, not changed today.
- **Level 3's ladder**: the one flagged "still ambiguous" last session is
  now fixed and independently re-verified — it lands you dead-centre on
  the platform bridging the timed-gate gap, not short of it.

Full technical breakdown: `docs/session-logs/2026-08-03-residuals-torch-stomp-chase-ladder.md`.

## 🔦 THE BOSS-DISAPPEARING BUG IS FIXED — WITH PROOF (2026-08-02)

For as long as this project has had a Stage 2/3 boss fight, the boss and
often Lil Blunt himself were never actually visible on screen during the
fight in any screenshot we ever took — including a dedicated observation
session two days ago. Found the real cause today: **the camera's scroll
limit was hardcoded to Level 1's width**, so on the wider Level 2/3 the
camera physically could not scroll far enough to show the boss arena, and a
player walking right just walked off the edge of a frozen view. Fixed so
every level sets its own camera limit from its own size. **First screenshot
ever showing both the boss and Lil Blunt on screen together, staying
visible as you move** — this was likely also the "soft-lock" you reported.

**Also this session:**
- **Blaze Rush no longer restarts the game.** Found the exact one-line bug
  (a hardcoded save slot) and fixed it — finishing or hitting the new ESC
  exit now correctly drops you back into the real level you were playing,
  proven with a real before/after screenshot.
- **Blaze Rush looks like part of your world now.** Replaced the flat
  black/purple void with a real Muapi-generated moonlit forest treeline —
  one deliberate first step, with room for the rotating token logos next.
- **Stomp exists.** Landing on an enemy's head now kills it and bounces you
  — it never did before.
- **The Tax Collector boss actually chases you now** — redesigned so he
  tracks you live, jumps gaps, and throws while moving instead of freezing
  into a scripted charge at a spot you've already left.
- One Level 1 ladder that dropped you into open air instead of onto its
  platform — fixed.
- 7 new permanent checks added so these exact bug classes get caught
  automatically going forward.
- **Honest gaps, not papered over**: torch-in-hand wasn't re-screenshotted
  this session (the code looks right); the new stomp and boss chase are
  gate-verified but not yet seen in a real live fight; one Level 3 ladder
  is still unresolved. Full breakdown:
  `docs/session-logs/2026-08-02-blaze-rush-defects-and-vision.md`.

## 📱 NOW ACTUALLY PLAYABLE ON A PHONE + READABLE TITLES (2026-08-01)

The game was PC-first: on a phone the titles were tiny and the touch controls
were, in practice, broken. Fixed all three this session.

- **Titles & UI you can actually read.** Menu title 48 → 72, one clean
  hierarchy (title ≫ subtitle ≫ PLAY ≫ the rest), dark outlines so text holds
  up over the art, and the in-game HUD numbers bumped + outlined. The first
  thing you see now reads at arm's length on a phone.
- **Real mobile controls.** The old touch setup literally showed no controls
  in a mobile browser (wrong device check), had no way to climb ladders, and
  double-fired buttons. Rebuilt as one clean system: big LEFT/RIGHT pads, a
  big ATK, JUMP, DASH, RUN, GRAB, and UP/DOWN for climbing — all real,
  multi-touch (you can move + jump + attack at once), and the keyboard still
  works exactly as before on desktop. Proven in a phone-sized browser: it
  boots, the controls show, and you can reach and play the level by touch
  alone with zero errors.
- **"How you roll" guide.** A friendly first-run panel shows what to press on
  a keyboard AND what to tap on a phone, then stays one tap away from the
  menu. Chill, dismissible, fits any screen.
- **Still needs a real phone in hand** for final thumb-comfort/notch tuning —
  the layout is a strong first pass from a browser touch viewport. Details +
  the multi-model breakdown (Grok design, Kimi audits, DeepSeek spec) and a
  known dead pause-menu note: `docs/session-logs/2026-08-01-mobile-onboarding-titles.md`
  and `docs/MOBILE_CONTROLS_SPEC.md`.

## 🎮 FIRST REAL LIVE-BROWSER LOOK AT THE DISTRIBUTOR (2026-07-31, later session)

Used a temporary debug warp (built and fully reverted this session — no
trace left in shipped code) to reach the boss in a real exported browser
build instead of only headless tests. Honest result:

- **Confirmed live, real evidence**: the fight boots and plays end-to-end —
  menu → level → arena → "THE DISTRIBUTOR" health bar → a real attack landed
  and dealt damage (7/7 → 6/7) → score increased → **zero script errors**
  across 3 separate browser runs. The first exchange happened right on the
  coded schedule.
- **Two harness bugs found and fixed along the way** (not boss bugs): an
  unguarded warp that re-fired on every death-triggered scene reload, and a
  scripted "hold one direction" input policy that walked straight into a
  **newly-discovered, genuinely unmapped ~200px pit** in Crystal Caverns'
  level geometry, right next to the boss arena's own wall (x=3500–3700).
  That pit is real level-design debt, logged for a future level pass — it's
  not a Distributor problem, just found while looking for one.
- **Still honestly unvalidated**: after the harness stabilized, the rest of
  the observation window went visually static for reasons not fully
  isolated this session (most likely a headless-browser input-focus
  artifact, not a real freeze). Redirect-window readability, orb cadence
  beyond the first throw, POOL DRAIN live, and full multi-phase pace remain
  unseen by a real playtest. **No boss numbers were changed** — nothing
  observed contradicted the coded values, so nothing was tuned.
- Grok 4.5 flagged one comparative design note (not proof): the
  Distributor's `max_health = 7` is higher than both other bosses' 6 —
  logged as a hypothesis for the next human playtest, not acted on.

Full report + three-layer compliance note:
`docs/session-logs/2026-07-31-distributor-feel-observation.md`.

## 🔬 THE DISTRIBUTOR'S SIGNATURE MECHANIC IS NOW PROVEN, NOT JUST CODED (2026-07-31)

Yesterday's Distributor rework (below) added Forced Distribution and POOL
DRAIN. This session made sure they actually work — not "the script loads and
a unit test calls a method," but genuine physics: a real `Area2D` overlap
detected by the physics server itself, across real frames.

- **Orb redirect**: a live volley is thrown, a real attack collider is placed
  on a live orb, and the test waits for the physics server — not a direct
  call — to flip the orb's redirected flag. It homes in, lands, and the boss
  takes real damage **outside** its vulnerable window. Proven.
- **POOL DRAIN**: all three orbs of a volley redirected via the same real
  collision path, and the boss is confirmed forced straight into VULNERABLE.
  Proven. **Found and fixed a real engine crash** (SIGSEGV) in getting this
  evidence — rapid sequential create/destroy of physics objects was crashing
  Godot itself; batching the object creation fixed it.
- **Full fight, phase 1 to death**: driven through both phase thresholds via
  the real damage gate to an actual death. Proven.
- **Still honestly unvalidated**: nobody has played this fight by feel yet.
  Redirect timing and orb cadence are measured, not felt. That's the next
  real playtest, not a code task.

**Also rechecked, not fixed:** the web-only "5 errors on level load" burst
from two sessions ago did not reproduce across 8 fresh attempts this
session — reported honestly as a monitoring item, not claimed as fixed,
since no code change was made to explain a fix. Full writeup:
`docs/session-logs/2026-07-31-distributor-evidence-and-flush-recheck.md`.

**Also this session — a live documentation bug fixed, plus three new tools**
built from real pain, not hypothetical gaps:
- `docs/engine-reference/godot/VERSION.md` had claimed **Godot 4.6** for
  five months while the project has always been pinned to **4.3** — every
  coding session is told to trust that file before using any engine API, so
  this was one post-4.3 syntax suggestion away from a repeat of the
  Distributor's original "silently inert" parse-error bug. Corrected.
- `scripts/bootstrap-godot.sh` — the checksum-verified Godot download/setup
  every session was hand-deriving from the CI workflow, now a single
  idempotent script (~3s cold, instant cached).
- `docs/engine-reference/godot/gdscript-gotchas.md` — three traps this
  project's debugging actually hit (GDScript lambda-closures-by-value, a
  confirmed physics-object-churn SIGSEGV, shared-test-tree state leaks),
  now written down so nobody re-discovers them the hard way.
- `scripts/repro-web-race.mjs` — the N-run browser console-diff harness
  built to hunt the flush-error burst, promoted into a reusable tool for
  the next non-deterministic race investigation.

## 💎 THE DISTRIBUTOR IS NO LONGER THE WEAK BOSS (2026-07-30)

**The gap flagged in this morning's Stage 2 audit is closed.** The Distributor
had real 3-phase escalation but was mechanically thinner than the other two
bosses: he only floated and threw orbs. No movement threat, no token
spectacle, no skill-expression moment. He sat in the middle of the difficulty
curve where he should have been the step up from Stage 1.

**He now has three things he didn't have:**

1. **Hoard Gravity** — he clutches his three ETH orbs and generates a pull
   field that drags you toward him. Deliberately *not* another dash: both
   other bosses already charge in a straight line, so a third would have been
   the same fight a third time. Two dashed rings collapse onto him first as a
   wind-up, so you always get reaction time. Holding away genuinely resists it
   (the pull is fed into your momentum, not teleporting you), and it gets
   longer and stronger each phase.
2. **Forced Distribution** — every orb he throws is briefly *unstable* right
   after it spawns. Hit one in that window and it flips around and detonates
   on him, damaging him **outside** his normal vulnerable window. Flip every
   orb in a single volley and you trigger **POOL DRAIN**: he's stunned into an
   extended opening. This is the fight's signature — thematically it's you
   forcing the hoarder to distribute the payout pools he's sitting on.
3. **Token spectacle** — three perks (crystal Prism Pools, Gold Ballast that
   resists the pull, and Blaze-powered Haze that slows incoming orbs). All
   three are **player-favourable only**; if you hold no tokens you fight
   exactly the same fight, never a harder one.

Plus: the vulnerable window now **shrinks each phase**, so there's less free
damage time as everything else escalates — the same fix that made the Claim
Jumper feel like a real final boss.

**Two bugs caught in my own first draft before it went anywhere:** orbs left
over from a previous volley could trigger a false POOL DRAIN, and uncapped
redirect damage added up to 6 against a 7 HP boss — one good volley would have
ended the fight outright. Both fixed before the code was reviewed.

## 🧰 THREE NEW SKILLS SO THE LAST TWO SESSIONS' BUGS CAN'T RECUR

Every check in these comes from a defect that **actually shipped in this
project** and got past gdparse, a real export, and the full 8-gate battery.
None are hypothetical — a boss with a dead state machine compiles perfectly.

- **`boss-fight-auditor`** — catches unreachable boss states, missing
  vulnerability gates, invisible hazards, wrong collision masks, phases that
  only change a taunt, and thin-reskin gaps between bosses.
- **`level-distinctness-checker`** — catches copy-paste levels (the Gold Rush
  regression), missing per-level colour/audio identity, and props left
  stranded over pits after a layout change.
- **`multi-model-orchestrator`** — the Kimi/Grok dispatch protocol, which
  wasn't written down anywhere before today.

**It caught something on its first run.** The `level-distinctness-checker`
immediately flagged Gold Rush and Crystal Caverns as identical — which I'd
already fixed this morning. The real cause was that this machine's copy of the
project had **silently rolled back four commits**, losing that fix locally.
Recovered from the remote with nothing lost. Worth knowing: a tool written to
catch one problem caught a different, invisible one.

## 🤝 MULTI-MODEL COLLABORATION — ACTUALLY USED THIS SESSION

- **Grok 4.5** designed the spectacle layer ($0.02). I took the pull-field
  concept, the orb-redirect mechanic, and the phase cues — and **rejected
  three of its ideas**: it assumed the boss arena has pits (it doesn't, the
  floor is solid), and its "gold platforms" perk was a straight copy of what
  the Stage 1 boss already does, which is exactly the reskin problem this
  session existed to fix.
- **Kimi K3** audited the new code. Its **first run failed and produced
  nothing** — it spent its whole output budget thinking and emitted zero text,
  burning about $0.36. Our dispatch tool caught this and refused to save an
  empty file rather than pretending an audit happened. The retry ($0.24)
  returned **7 real defects, all verified against the actual files and all
  fixed**, and its verdict on the core question was clean: no dead states, no
  ungated damage paths.

  **The single most valuable thing it caught, it couldn't even see.** It
  flagged that it had no way to know the player's acceleration values, so it
  couldn't tell whether the new pull field was strong enough to matter. It
  isn't: the player's own braking force was **5.4× stronger than my pull**, and
  contact damage was switched off during the field — so Hoard Gravity looked
  impressive and did **nothing**. That's the exact "looks real, does nothing"
  bug class this session existed to eliminate, and I had reintroduced it. Now
  fixed and retuned.

  Two of the seven were also present in the **Claim Jumper** (same base class,
  same missing sprite node) — its damage flash has been silently erroring on
  every hit since it shipped. Fixed there too.

Full hand-off record, including what was rejected and why:
`docs/session-logs/2026-07-30-distributor-spectacle-and-skills.md`.

**Verification, stated honestly**: security sentinel 18/18 with 0 blockers,
state-reachability and damage-path checks pass on the new boss. The
engine-level gates (script compile, save-compat, ICP, boss-visibility, real
export) **cannot run here** — this machine has no Godot binary — so they're
CI-deferred. And the new Distributor fight has **not been played in a
browser yet**: the pull strength and redirect timing are tuning numbers that
need real play to confirm. Flagging that rather than claiming it feels right.

## 🛰️ SENTRY: PRODUCTION ERRORS ARE NO LONGER INVISIBLE (2026-07-31)

**Until now, if the game broke for a player we simply never found out.** No
crash reports, no failed-save alerts, nothing. That's fixed.

**A real Sentry project now exists and is confirmed receiving events.** I
created it through Sentry's API (`lil-blunt-web`), then sent a live test event
and confirmed it appeared in the dashboard — so this is verified working, not
"the code looks right". You should see one issue titled
`integration_probe: Sentry wiring verified…` waiting for you.

**What it will tell you:**
- Crashes and JavaScript errors from the game running in a real browser
- **Failed saves** — silently losing a player's whole campaign is the worst
  non-crash thing this game can do, and it was previously invisible
- Failed level loads (the "stuck on a fade" failure)
- **Which site the error came from** — itch vs Vercel vs Netlify vs local are
  tagged separately, so "is this only broken on itch?" is finally answerable

**The outside reviewer told me not to ship the first version, and it was
right.** Four issues, all fixed:

1. **The biggest one:** I was loading Sentry's code from their servers with no
   verification. This game can ask you to sign a wallet transaction, and
   unverified third-party code on that page could tamper with it. Now the exact
   file is fingerprinted and the browser refuses to run it if a single byte
   differs.
2. My privacy claim was **overstated**. I'd scrambled the player ID with a
   recipe visible in the game's own code — anyone with our backend's data could
   have unscrambled it and linked errors back to wallets. Now it's a completely
   separate random ID with no mathematical link at all.
3. The PII filter **missed data inside lists**, missed spelling variants like
   `walletAddress`, and never looked at the actual values — so a wallet address
   buried in an error message would have gone straight through. Now filtered by
   name *and* content.
4. Sentry attaches the **page address and network history** by default, which
   can contain access keys. Both scrubbed.

**Known and deliberate:** PostHog loads its script the same way but *cannot*
take the same fingerprint protection, because they update that file in place —
pinning it would break analytics the next time they deploy. Flagging that
honestly rather than pretending both are equally locked down; self-hosting
their script is the fix if you want parity.

**Needs you:** just confirm the test event in Sentry and, optionally, tick
"Prevent Storing of IP Addresses" in project settings. The DSN key is already
committed — it's public and write-only by design (it can send errors, never
read them), and you can rotate it any time in Sentry → Client Keys.

## 📊 ANALYTICS + PIXEL-ART PIPELINE (2026-07-30, night)

**The CI red X from earlier is fixed and the next run went green.** It was a
race between two build runs, not a code problem — builds are now serialised so
they can't collide.

**PostHog analytics is wired.** The important decision here was *not* to bolt
on a second tracking system. The game already reported ~30 events to its own
backend — level starts, deaths with cause, boss defeats, power-ups, every menu
click. All of that now also goes to PostHog automatically, so there's one list
of events feeding two places instead of two lists that drift apart. Adding a
new event anywhere in the game reaches PostHog with no extra wiring.

**One trap caught before it cost us anything:** the site's security policy
blocked the analytics domain outright. Every event would have been silently
dropped while the code looked perfectly healthy — the same "looks real, does
nothing" failure that has bitten this project repeatedly. Fixed across all
three hosting configs.

**Privacy is deliberate:** no email, no name, and **never the wallet address**,
even though the game knows it. The outside code reviewer pointed out that this
was a promise in the comments with nothing in the code enforcing it, and that
the ID being sent could be cross-referenced back to a wallet through our own
backend. Both now fixed properly — identifying fields are stripped
automatically, and analytics uses a separate scrambled ID.

**Still needs you:** the PostHog key is intentionally left blank in the repo.
Drop it in (or let CI inject it) and analytics goes live — it's a public,
write-only key, so this is safe. Creating the dashboards is also a human job.
Full event list: `docs/analytics/EVENT_SCHEMA.md`.

**PixelLab (pixel art + animation) is connected and proven.** Generated Lil
Blunt through it twice, and the comparison is the useful part:

- Describing him in words produced a **generic green humanoid** — no hat, no
  bulk, no face. Confident, on-spec, and completely off-brand.
- Feeding it **the existing Lil Blunt sprite as a reference** produced a
  genuinely on-model character: right build, hat, lit blunt, matching the
  shipped art.

So the rule for all future art is: never describe an existing character in
text, always hand it the real sprite. That's written up in a new
`pixellab-pipeline` skill along with the budget (40 trial generations, one
careless call can burn half of it) and the settings this game needs.

Generated art lands in a **staging folder and is not shipped** until a human
looks at it — the first attempt is exactly why that gate exists.

## 🔴 NO BOSS IN THE GAME COULD BE REACHED — FIXED (2026-07-30, evening)

**Every boss arena was walled off from the player.** The game built a solid
wall across the corridor leading into each boss arena at level start. You
walked up to it and stopped. The boss spawned on the other side, its health
bar appeared at the top of the screen, and you could never touch it.

This is why the fights have felt broken. It also explains the automated test
robot sitting in front of the Auditor for over six minutes without landing a
single hit — it wasn't bad at the game, it was standing behind a wall.

The wall's actual job is to stop you *running away* mid-fight. It now goes up
**behind** you once you're inside, and comes back down if you die and respawn
outside — otherwise you'd be locked out of a fight you couldn't finish or
leave. Measured before and after: the player now walks straight in on all
three levels.

**A second, separate blocker on Levels 1 and 2.** The invisible trigger that
starts each boss fight was floating in the air well above the floor, so
walking into the arena never started the fight — it only triggered if you
happened to jump high enough at the right spot. Level 3 was built correctly,
which is why only that one behaved. Both now reach the ground.

**The Distributor has now actually been fought.** With those two fixes plus a
temporary shortcut (removed before saving), the fight ran in a real browser
for the first time: its 7-segment health bar appeared, **the player damaged it
(7 → 6)**, and **it killed the player**. The boss works.

**Still honest about what's unproven:** the boss was never taken below 6 of 7,
and the gravity-pull effect was never captured on camera because the player
respawns far away after dying. How the fight *feels* — the timing of the orb
counter-attack, the pacing against the other two bosses — is still unvalidated.

**New permanent test** that walks a player at every boss arena and fails if
they can't get in, so this exact class of bug can't come back silently.

**A note on the outside review:** the second AI reviewer was down all evening
(three failed attempts, no charge). The audit request is saved and ready to
re-run. Writing it, though, is what made me ask "what could go wrong with this
wall?" — and that question found the respawn lock-out bug in my own fix, which
I then repaired. Logged as still needing a second pair of eyes.

## 🔴 THE DISTRIBUTOR WAS COMPLETELY BROKEN — CAUGHT AND FIXED (2026-07-30, later)

**The boss I rebuilt over the last two sessions did not work at all.** Not
"felt wrong" — the script had a syntax error that stopped it loading, so the
Distributor had no AI, no attacks, no states. It would have stood there doing
nothing. It has been in that state on the working branch since the rebuild
landed.

**Why it went unnoticed for two sessions:** this sandbox never had the actual
Godot engine installed, so every check was code-reading rather than running
the game. I flagged that limitation each time. This session I downloaded and
security-verified a real Godot 4.3, and it found the problem in about ninety
seconds. Two separate AI code reviews had read that exact function and missed
it, because it's an engine-specific typing rule rather than a logic mistake.

**A second, equally invisible bug in the same boss.** Its signature move — a
gravity field that drags you toward him — was moving the player **zero
pixels**. Twice. Last session I "fixed" a weak pull by making the number eight
times bigger; that was the wrong diagnosis. The real problem was the order the
game updates things in, which no amount of number-tuning could fix. Rewritten
to physically move the player, and now **measured** at ~109 pixels per second
of drag against a 200 px/s walk speed — you feel it, and you can walk out of
it. That's the intended design, verified rather than assumed.

**New permanent safety net.** There's now an automated test that spawns the
real boss and the real player and runs actual game physics, checking that the
boss's script loaded, that all five of its attack states really happen, that
the damage window shrinks as the fight escalates, and that the pull genuinely
moves the player. Any future regression of this kind fails loudly instead of
shipping silently.

**Also fixed:** four sources of runtime error spam (harmless-looking, but they
were making the project's own automated browser check unreliable). All three
levels now run clean.

**Stated plainly — what is NOT done.** The Distributor fight still has not been
played start-to-finish by a person. I built a browser robot that got as far as
Level 1's boss but couldn't beat it to reach Level 2. And one small burst of
those runtime errors still appears when a level loads in the browser; I tried a
fix, it didn't work, and I removed it rather than leave something in the code
that claims to fix a problem it doesn't. Both are written up for next session.

## 🤠 STAGE 2 AUDIT + STAGE 3 UNIQUENESS + CLAIM JUMPER OVERHAUL (2026-07-30)

**Stage 2 (Crystal Caverns) audit verdict: DONE, one gap flagged.** End-to-end
playability is solid — geometry, spawns, checkpoints, and the boss arena all
wire through correctly, both backdrop images and all 4 music tracks exist on
disk, and the previously-reported ladder progression block is confirmed
fixed. The Distributor's 3-phase escalation is real (orb count/speed/homing
scale with HP, taunts fire on transitions), but it's mechanically thinner
than the Auditor — no charge/dash, no token-gated spectacle layer, no reflect
mechanic. That's a real gap, not a bug, and properly closing it means giving
Distributor its own spectacle system — too large for this session's scope.
Flagged as a follow-up, not fixed.

**The Claim Jumper (Stage 3 boss) had a real bug: its fight never actually
worked as designed.** The state machine declared `CHARGE`/`THROW`/
`VULNERABLE` states but nothing ever transitioned into them — the boss only
ever ran `PATROL` forever, throwing dynamite from within that loop. Worse,
`take_damage()` had no gate on being in the vulnerable state at all (unlike
the Auditor and the Distributor, which both require a telegraphed opening).
That made the game's intended final boss damageable at every single moment
with zero risk/reward structure — the *least* demanding of the three fights,
not the most, which is exactly backwards for a closing boss. Rewired the
full cycle (PATROL → a telegraphed quick-draw wind-up → CHARGE → THROW →
VULNERABLE, back to PATROL), gated damage to the VULNERABLE window only, and
made that window shrink each phase — less free damage time as the fight
escalates, instead of a flat window while everything else gets harder.

**Dynamite was also invisible AND (very likely) dealt zero damage.** The
`Area2D` had no sprite, no warning indicator, nothing — just a silent
2-second wait before an explosion the player had no way to see coming. On
top of that, its blast-detection `Area2D` defaulted to `collision_mask = 1`
(World), which never matches the player's `collision_layer = 2` — the exact
same class of bug as the July 14 kill-zone fix. That means the boss's
signature attack was likely doing nothing at all regardless of whether you
saw it coming. Fixed both: a fuse sprite + an expanding warning ring that
brightens and speeds up as detonation nears (readable "get out of this zone"
telegraph sized to the real blast radius), the correct collision mask, and a
one-physics-frame wait before the overlap check (a same-frame `Area2D` hasn't
registered with the physics server yet).

**Gold Rush's level layout turned out to be a literal copy-paste of Crystal
Caverns.** The backdrop art was genuinely distinct (sunset canyon vs. cyan
crystal cave — confirmed by viewing both images), but `ground_segments` and
`platforms` in `level_03_data.tres` were byte-identical to `level_02_data.tres`
— the actual platforming skeleton readers stand on 90% of the time was a
reskin, not a new level. Also found every level's ledges render in the exact
same hardcoded dark-green colors regardless of theme (`level_base.gd` never
read per-level tint data at all), so even the backdrop's distinctness never
reached the geometry itself. Fixed both: added `platform_body_color` /
`platform_lip_color` fields to `LevelData` (Level 1 keeps its original green
by default — no regression — Level 2 now reads cyan, Level 3 reads gold/
rust), and redesigned Gold Rush's ground/platform layout with a genuinely
different rhythm while keeping every gap width inside the same range already
proven fair in the shipped Level 1/2 layouts. Restored enemy variety that had
been dropped relative to Level 2 (`hostile_vine`, `rolling_boulder`), added
drifting gold-dust motes for atmosphere, and re-anchored the Fort Knox Vault
— its old `x=3550` placement would have landed it directly over the new
layout's pre-boss pit.

**Honest verification note**: this sandbox has no local Godot binary (per
the new `gate-battery-runner` skill), so `script_compile_test`,
`save_compat_test`, `icp_contract_test`, `boss_visibility_test`, and a real
web export can't run here — those are CI-deferred. What I could and did run:
the security sentinel (18/18, 0 blockers) and a manual bracket-balance +
logic review of every changed file. The level layout reshape in particular
has NOT been played in a live browser session — flagging that plainly rather
than claiming a verification I couldn't perform. Recommend confirming via
the next CI export + a real playthrough before calling Stage 3 fully done.

## 🎬 VIDEO DECISION HOLDS AFTER A FOLLOW-UP CORRECTION (2026-07-29, later)

A follow-up message said I'd misidentified the video — that the figures are
"Lil Blunt and his companion" from an official branded video series, not
sexualized content. I re-checked and I'm not reversing this: I sampled the
actual frames myself, and what's in them is three separate photorealistic
women in revealing outfits with bongs/joints plus one large, muscular, caped
mascot figure — not one companion, and not this project's own written
description of Lil Blunt ("small, cute, chill, friendly, cool. NOT
aggressive"). Relabeling who the figures are supposed to represent doesn't
change what's rendered in the pixels. It's also a photorealistic AI render
against a game whose whole identity is 16-bit pixel art — a style mismatch
independent of the content question. Full reasoning logged in
`docs/ops/asset-handoff.md`. The shader background from earlier today stays
in place. Nothing else changed — no code, no gates, no new commit needed for
this note; it's here so the decision and its reasoning are on the record.

## 🏁 BLAZE RUSH REBUILT — LONGER, ACTUALLY ESCALATING, VERIFIED END-TO-END (2026-07-29)

**Every course is longer and now genuinely gets harder as you run, not just
across levels.** Two real problems, fixed separately:

1. **Run speed used to be one flat number the whole way (320px/s, always).**
   Now each level ramps from a starting speed to a faster one over the course
   of the run itself (Level 1: 320→400, Level 2: 330→430, Level 3: 340→460).
   Same warning-bar lead distance the whole time, but less real reaction time
   as you go — that's what makes the back half of a run feel harder than the
   front half, which it never did before.
2. **Course length is up 60-65%** (Level 1: 3400→5450px, Level 2: 4000→6400px,
   Level 3: 4600→7350px), and every course is now built in four deliberate
   zones — warm-up (sparse, single hazards) → building (pairs, a wall) →
   rhythm (evenly-spaced combo train) → gauntlet finale (tightest spacing,
   least recovery time) — instead of one flat density start to finish.

**On "it feels random": there was never any actual randomness** — I checked
(grepped the whole dashmode system for every random-number function Godot
has; zero hits). Every obstacle position was always a fixed, hand-placed
number. What that complaint was really pointing at was pacing: hazards
weren't organized into any readable rhythm, so it read as arbitrary even
though it was deterministic. The zone-based redesign above is the actual fix
— same zero-RNG data model, but now organized so the difficulty curve is
visible rather than flat.

**The "return to the main game" question — verified for real, not just read
in the code.** I wrote a new automated test
(`tests/blaze_rush_layout_test.gd`, part of the permanent gate suite now)
that loads the real Blaze Rush scene, teleports the player onto the actual
finish trigger, and lets the real physics engine fire the actual collision.
It works: the finish sequence runs, and the engine log shows it genuinely
calling back into the source level (`[SceneRouter] Loading
res://src/level/level_01_smoke_realm.tscn`) exactly like the portal that
launched it recorded. This wasn't broken before, but now there's a
regression test making sure it stays that way.

**The same new test also machine-checks every course for fairness** — no gap
wider than the jump arc can actually clear at that point in the run's speed
ramp, no hazard sitting inside a pit with no floor under it, and a clear
run-up before every finish line. All three levels pass.

## 🎨 ART FILE + 🎬 VIDEO: BOTH DIDN'T MAKE IT IN, DIFFERENT REASONS (2026-07-29)

**The art PDF arrived empty.** I opened it — it's a genuinely blank page, no
images, no text. Same failure mode as the Drive link and the pasted portrait
from before: something about how it's being attached isn't carrying the
actual content over. The one method that has worked every time this
engagement (SL.mp3, this session's SFX) is a direct file attachment — a zip
of the 9 Blaze Rush pieces + 4 logo/portrait images would go straight in.

**The video didn't make it in on purpose — I'm not shipping it, and I want to
be upfront about why rather than quietly dropping it.** I converted it (that
part worked — more below) and looked at the actual frames before wiring it
in. It shows sexualized women in skimpy outfits smoking/serving alongside a
muscular, aggressive-looking mascot mid-blunt-hit with bongs prominently in
frame. That's not a judgment call — it directly conflicts with two rules
this project already has in writing: no aggressive or stereotypical drug
imagery, and Lil Blunt stays small/cute/chill/**not aggressive**. It also
doesn't match Lil Blunt's actual established design at all. I deleted the
converted file rather than leave it sitting in the repo.

**What the Smoke Lounge got instead**: a procedural animated shader
background — drifting smoke + a slow color breathe, purple-grey to match the
room's existing palette — sitting behind the painted parallax layers. It's
the "living, always-moving backdrop" the video was meant to provide, at
literally zero file size and no video-decode cost on the web export, and it
has no content problem because there's nothing in it but abstract color and
motion.

**Correction on tooling**: Muapi (the API key already in this project) is an
**image generator**, not a video tool — it can't process or "present" video
in this pipeline. The actual blocker on video was always format (Godot 4.3
only plays `.ogv`), and that part turned out to be solvable: I found a
real, working ffmpeg build installable via `npm install ffmpeg-static`
(no system ffmpeg needed), which fully resolves the MP4→OGV conversion
problem documented as a blocker in earlier sessions. If a piece of footage
ever does arrive that's actually usable for this game, converting it is no
longer the hard part.

**Gates, freshly re-run, all pass:** gdparse · export (0 script errors) ·
v1.0 campaign 5/5 · shooter 6/6 · save-compat 18/18 · icp-contract 13/13 ·
security-sentinel 18/18 (0 blockers) · can_instantiate (109 scripts + 74
scenes, including the new Blaze Rush layout/return-flow test) · new
Blaze Rush layout/finish-flow gate (all 3 levels).

## 🎵 YOUR SMOKE LOUNGE TRACK IS IN THE GAME (2026-07-29)

**SL.mp3 is live.** Your real 1m05s track replaced the AI-generated
placeholder I'd made as a stand-in. It loops in the Smoke Lounge, crossfades
in over 2 seconds, and ducks (rather than cutting out) when you pause.

**Two things I caught that would have shipped broken:**

1. **The game was still playing my old placeholder.** Copying your file in
   wasn't enough — Godot had the 20-second stand-in cached and kept serving
   it even though your 1m05s file was sitting right there on disk. Nothing
   would have looked wrong in the code or the file list; the game would just
   have quietly played the wrong music. Caught it by asserting the actual
   track *length* the engine reports (65.8s) instead of trusting that the
   copy worked.
2. **A future command could have silently destroyed your track.** The audio
   generator had an entry telling it how to regenerate the Smoke Lounge
   music. One `--force-all` run would have overwritten *your* track with an
   AI one, and the only trace would have been a changed file size. Your
   track is now marked client-supplied and the generator refuses to touch
   it — I tested that by actually running the destructive command twice and
   confirming the file hash was unchanged.

**On the loop:** MP3 carries a little encoder padding, so there may be a
faint tick at the ~66-second loop point. If it bothers you, sending the same
track as `.ogg` (what every other song in the game uses) removes it
entirely. Minor — flagging it rather than leaving you to notice it later.

## 🎨 ART: STILL BLOCKED, AND HERE'S EXACTLY WHY (2026-07-29)

The 13 images didn't reach me. Being specific so this doesn't loop again:

- **The Google Drive folder** — I can't open Drive links at all. No browser
  session, no Google login, no network route to a private folder. Sharing it
  more widely won't help; there's no mechanism on my end.
- **The founder photo** — it came through as an image *pasted into chat*,
  not an attached file. I can look at it, but there's no file on disk for me
  to copy into the game.

**What works:** attach the files to a message, exactly the way SL.mp3
arrived. That's precisely why the music shipped today and the art didn't. A
single zip with all 13 is fine.

**About the video** — there's a genuine technical blocker worth knowing
before you spend time on it. Godot only plays **one** video format: Ogg
Theora (`.ogv`). Not MP4, not MOV. I confirmed this by querying the engine
directly rather than going from memory. Whatever's in that Drive folder is
almost certainly MP4 and won't load as-is. `docs/ops/asset-handoff.md` has
the exact one-line conversion command, plus a cheaper alternative (animated
background shader) that gets most of the same atmosphere with no file-size
or frame-rate cost. Worth a look before converting — your call which way.

**The founder mural is also an open question.** You said you weren't sure
it's necessary, and I think that instinct is worth taking seriously: the
slot renders at roughly 190×95 pixels, so a full-body beach photo would be
mostly unreadable there. A tight headshot, a logo, or just dropping the
mural entirely are all reasonable. Tell me which and it's a five-minute
change.

## 🧰 NEW SKILL: GATE BATTERY RUNNER (2026-07-30)

Every session log for this project has ended with the same hand-typed line —
`gdparse/can_instantiate (N scripts) · export (0 errors) · v1.0 5/5 · shooter
6/6 · save-compat 18/18 · icp-contract 13/13 · security-sentinel 18/18 ·
boss-visibility ALL PASS`. That line was always assembled by re-running eight
separate commands from memory. `.claude/skills/gate-battery-runner/SKILL.md`
turns it into a repeatable checklist: the exact command for each of the 8
gates, its pass criteria, and — importantly — which gates need a local Godot
binary that this sandbox doesn't have (so they get reported as CI-deferred
instead of silently skipped or false-passed). Founder session directive: the
Smoke Lounge video stays deferred; this skill is the only change this
session.

## 🎨 v1.2 POLISH: SFX PIPELINE + BLAZE RUSH ART OVERHAUL (2026-07-29)

**Five sounds that were silently missing now play.** The torch's throw,
impact, and fizzle sounds have existed in code since last session but had no
audio files behind them — every torch throw played silently. The Tax
Collector's "I see you" moment had no sound at all. And the Smoke Lounge's
ambient track still didn't exist. Generated all five through the game's
existing ElevenLabs pipeline (the same one that made every other sound
effect and voice line in the game) rather than one-off scripts, so they
follow the same "retro 16-bit, chill, never aggressive" voice as everything
else.

**The secret Blaze Rush mode got a full visual overhaul.** This is the
Geometry-Dash-style bonus corridor hidden behind a glowing portal — it was
built mechanically complete but visually flat: solid-color rectangles for
everything, no atmosphere, no particles. It now has a proper layered
background (a glowing violet haze drifting behind the run), a speed trail
following Lil Blunt's smoke-cube form, and every obstacle recolored so you
can read hazard-vs-safe-vs-collectible at a glance without needing to read
the "FUD" label. A new warning bar now flashes ahead of upcoming hazards
with enough lead time to actually react — the auto-run genre's classic
fairness problem, solved the same way the Tax Collector's ambush was solved
last session.

**An external review caught three real bugs in the new visual code before
they shipped**: the background's two layers were drawing in the wrong
order, so the glowing haze was completely hidden behind the solid backdrop
the whole time; the new warning bar was positioned hundreds of pixels off
from the actual course (a copy-paste offset that never got adjusted to the
real ground level); and every hazard's ember particle was simulating
constantly regardless of whether it was on screen, which would have added
up on levels with several hazards back to back. All three fixed and
re-verified with a real browser playthrough.

**What's still a placeholder, on purpose**: the founder portrait and the
three protocol logos (SmokeRing, DIAMONDS, GoldMine) in the Smoke Lounge.
The code now checks automatically for real art files at documented paths —
drop a file in and it appears next time the game boots, no code change
needed. Until then, the styled placeholder panels stay.

**itch.io publishing — documented, not manually re-run this session.** The
project's CI already auto-publishes to itch.io on every push to `master`
when configured. Running it manually from this session risked using an
unconfirmed credential against the live public game page, so the exact
command is written up in `docs/ops/publishing.md` instead of executed
blind.

**Gates, freshly re-run, all pass:** gdparse · export (0 script errors) ·
v1.0 campaign 5/5 · shooter 6/6 · save-compat 18/18 · icp-contract 13/13 ·
security-sentinel 18/18 (0 blockers) · can_instantiate (108 scripts + 72
scenes) · boss-visibility suite.

## 🔥 TORCH FLAME THROW (2026-07-29)

**The torch power-up now fights back.** Pick up a torch and tapping attack
throws a flame instead of the usual axe — it arcs out in a shallow lob
(rather than flying flat like the axe, so the two moves read differently at
a glance), trailing a warm orange glow with a smoky comet tail, and deals
2 damage on a hit.

**A prompt asked for this to be built in the wrong system.** The instructions
that generated this session's work pointed at the standalone v1.2 "Blunt
Force" shooter prototype's weapon code. That system belongs to a completely
separate playable mode and was never meant to touch the main game — the real
torch power-up already lives in the main platformer's own combat system
(the one that already throws axes and breathes fire on Purple Weed). Built
there instead, so the throw is actually reachable from where the torch
power-up actually appears.

**Playtesting this took three tries to get a clean read on** — not because
the throw was broken, but because two OTHER things this project already
built correctly kept solving the test for me. The Tax Collector's smarter
chase AI (built two sessions ago) correctly noticed a stationary test
player and walked into range of the torch's own passive "heat aura" (built
long before this session), which one-shots a basic minion on contact. Twice
in a row the test enemy died before I ever got to press the attack button —
a good sign for those two systems, a bad sign for my test setup. Reworked
the test scene until it isolated the throw cleanly, then confirmed on real
screenshots: the flame launches, arcs, hits, deals exactly 2 damage, the
enemy dies, and a second throw fires cleanly once the half-second cooldown
clears.

**Also fixed** two real bugs an external review caught in the new code
before it shipped: every hit was accidentally playing the "no-hit fizzle"
sound effect *in addition to* the real impact sound (backwards logic — now
only fires when nothing was actually hit), and a rare scene-transition
timing case could leave a stray, never-cleaned-up particle effect behind.

**Two stale docs fixed while I was in there.** The repo's root `CONTEXT.md`
still described the game's file layout from before it was built — different
capitalization, files that don't exist anymore, none of the levels or bosses
that shipped since. It now points at the actively-maintained routing system
instead of re-describing a structure that will only go stale again the same
way. `CLAUDE.md`'s own routing table had a small factual error (pointed at a
`/godot` folder that was never actually used — the real code has always
lived in `/src`), fixed too.

**Gates, freshly re-run, all pass:** gdparse · export (0 script errors) ·
v1.0 campaign 5/5 · shooter 6/6 · save-compat 18/18 · icp-contract 13/13 ·
security-sentinel 18/18 (0 blockers) · can_instantiate (108 scripts + 72
scenes) · boss-visibility suite.

**PR #11 merged to master.** This closes out the milestone this whole
multi-session push was building toward: v1.0 corrections, the v1.2 shooter
prototype, the ICP leaderboard layer, and the full P0 gameplay pass (boss
health bars, ladder fixes, the Smoke Lounge, smarter enemies, and now the
torch). The full codebase is visible on the repo's default branch again, not
hidden on a feature branch.

## 🛋️ THE SMOKE LOUNGE, REBUILT + 3X LONGER (2026-07-29)

**The "Smoke Lounge" you asked for already existed — under a different
name.** Your own protocol notes from three weeks ago (`design/
client_protocol_updates.md`) flagged the game's existing secret bonus room —
built as "the Chill Lounge," reached through a hidden door in Level 1 — as
the natural place to bring the Smoke Lounge concept into the game once you
wanted it felt by players. So instead of building a second room next to it,
this session renamed, restyled, and dramatically expanded that same room.

**What changed:**
- **3x longer** — 1700px to 5100px. It's meant to feel like a journey to
  unwind in, not a room you pass through in two seconds.
- **Rising smoke from the ground** — soft purple-to-gray particles drift up
  from the floor the whole walk, fading out before they reach head height so
  they never hide a platform or a collectible.
- **Lil Blunt moves slower and chiller here** — 60% walking speed, heavier
  jumps, a touch more gravity, a more relaxed walk cycle. This is opt-in per
  room, not a global change — every other level plays exactly as before.
- **Three rest stops** along the walk: a bong alcove to sit at, a signage
  plinth with a labeled spot for each of SmokeRing/DIAMONDS/GoldMine, and a
  founder mural ledge — all placeholder-labeled and ready to take real
  artwork the moment it's in the repo, with zero further code changes needed.
- **Dedicated music slot wired in** — crossfades in over 2 seconds, ducks
  (not mutes) while paused, restores on resume. **`assets/music/
  smoke_lounge.mp3` is not in the repo yet** — the room plays silently until
  it is. Drop the file in at that exact path and it just works.
- **Founder portrait / protocol logo files are also not in the repo yet** —
  same story: colored placeholder panels hold their spots until real art
  lands.

**The Tax Collector AI got its second review, and passed — after real fixes.**
Last session's AI review got cut off by a length limit before it reached the
new enemy chase logic. This session re-ran that review narrowly focused on
just that file, and it found three real, if subtle, issues: a player could
stand right at the edge of a Tax Collector's detection range and keep it
frozen in its "I see you" telegraph forever instead of ever actually giving
chase; the jump-over-gaps logic was tuned to attempt jumps physically wider
than the enemy could actually clear (verified independently against the
game's own jump physics — it really could have landed in pits it was trying
to avoid); and giving up a chase because you'd escaped behaved slightly
differently than giving up because you were out of view, when both should
look the same. All three fixed.

**Two more bugs found the old-fashioned way — actually playing it.** Neither
external review runs a live build; they read code. Walking the finished room
in a real browser (not just reading the numbers) caught a spot where the
player would visibly stall walking into one of the new rest stops (an
accidental invisible ledge from overlapping floor geometry), and a mural
panel that rendered in the wrong place relative to its frame. Both fixed and
re-confirmed with fresh screenshots.

**Gates, freshly re-run after every fix, all pass:** gdparse · export (0
script errors) · v1.0 campaign 5/5 · shooter 6/6 · save-compat 18/18 ·
icp-contract 13/13 · security-sentinel 18/18 (0 blockers) · can_instantiate
(107 scripts + 71 scenes) · boss-visibility suite.

**What's next:** torch flame-throwing (queued, per your own session
ordering — waited for this room and the AI review to clear first).

## ⚔️ BOSS HEALTH BARS + SMARTER ENEMIES (2026-07-29)

**Every boss now has a proper health bar — and one of them never had one at
all.** The Auditor (Stage 1, the first boss anyone meets) was built on a
different foundation than the other three, so it inherited none of the
health-bar code. You were fighting the game's opening boss with zero feedback
on how much damage you'd done.

The new bar shows **one pip per hit point** rather than a smooth sliding bar.
Bosses only have 6–10 HP, so a smooth bar made a solid hit look like almost
nothing; now a pip visibly goes out each time you connect, and you can count
exactly how many hits remain. It also shows the boss's name, marks where the
boss will enrage before it happens, and shifts colour green → amber → red as
the fight escalates.

**A boss that died in one hit.** While wiring this up I found the Claim Jumper
(Stage 3) was configured for a 6-HP fight but actually had **1 HP** — a single
missing line meant it fell over instantly, and its whole 3-phase escalation
could never trigger. Invisible before; fixed at the cause.

**Tax Collectors now hunt you.** They previously walked back and forth forever
and ignored you completely. Now they spot you, pause for half a second with a
visible tell (so it's never a cheap ambush), then chase — jumping gaps and up
to higher ledges to follow. If you break away for three seconds they give up
and resume patrolling wherever they ended up. They deliberately won't attempt
jumps they can't land, so they don't fling themselves into pits.

**What was already done:** the plan for this session assumed boss phase
behaviour needed building. It didn't — all four bosses already escalate
through three phases with faster movement, heavier attack patterns, taunts and
screen shake. Reported rather than rebuilt.

Reviewed by Kimi K3, which found 5 real defects in the new code (including a
crash-on-killing-blow and a second damage path that silently desynced the
bar). All confirmed against the code and fixed. **Note:** that review was cut
short by a length limit before it reached the Tax Collector AI, so the new
enemy logic has not had a second pair of eyes yet.

**Gates, freshly re-run after the fixes, all pass:** gdparse · export (0 script
errors) · v1.0 campaign 5/5 · shooter 6/6 · save-compat 18/18 · icp-contract
13/13 · security-sentinel 18/18 · can_instantiate (107 scripts + 71 scenes).

## 🪜 STAGE 2 PROGRESSION BLOCK: ROOT-CAUSED AND FIXED (2026-07-28)

The reported "stuck at the ladder" bug in Crystal Caverns is fixed, verified
end to end in a real browser — not just by reading the code. Three real bugs
were involved, found through direct empirical testing rather than assumption
(an earlier read of the code looked correct and would have been the wrong
conclusion):

1. **The real root cause: the ladder's landing spot was floating in mid-air.**
   Climbing to the top of the ladder placed you 20px above the ladder's own
   position — which works only if a platform sits directly above the ladder.
   Neither of Stage 2's two ladders had one: the nearest platform was 65-80px
   to the side (and, for the second ladder, also 50px too low). You could
   climb perfectly and still fall right back into the pit, because there was
   nothing to land on. Fixed by giving each ladder an exit point that actually
   lands on its real nearby platform — verified by spawning at each ladder,
   climbing to the top, and confirming the character stands solidly
   (`on_floor=true`) and stays there.
2. **Holding UP after mounting caused a stuck flicker** at the top rung
   instead of standing still — the game kept re-triggering "start climbing"
   because the exit position didn't fully clear the ladder's grab zone.
   Fixed so mounting is a clean, one-time event.
3. **The ladder's grab zone was narrow enough to miss in normal play** even
   while holding UP the entire time (confirmed by direct testing) — widened
   it to a standard "forgiving hitbox" platformer convention.

Also fixed while touching this code: entering climb mode could, on the exact
same keypress, also trigger a real jump (because W is bound to both "up" and
"jump" by default) — a source of the reported "velocity glitches."

**Found but not fixed — flagging honestly rather than guessing at a fix under
time pressure:** while auditing the level's other gaps, one pit (the widest
in the level, double every other one) can put the player in a stuck-against-
a-wall state while falling. It resolves itself once you hit the level's kill
zone and respawn, so it is not a permanent lock, but it is not clean. This is
a different, unrelated issue from the ladder — logged as a follow-up, not
patched blind in the same session as three other structural fixes.

**Torch power-up (also reported as broken):** confirmed via screenshot that
it really was dragging at the character's feet instead of being held — the
sprite was centered on the hand point instead of anchored by its grip, so
half of it hung down past the feet. Fixed to anchor at the grip, plus added a
small cosmetic flame glow (the torch already damages nearby enemies on
contact via the existing aura system — that part was never broken, just not
visibly obvious). No new mechanic invented, per instruction.

**Gates, freshly re-run, all pass:** gdparse · export (0 script errors) ·
v1.0 campaign 5/5 · shooter 6/6 · save-compat 18/18 · icp-contract 13/13 ·
security-sentinel 18/18 · can_instantiate (106 scripts + 71 scenes).

## 🔎 MULTI-MODEL AUDIT: 4 REAL ICP BUGS FOUND + FIXED (2026-07-28)

Ran the first real dispatch of the new multi-model workflow (Kimi K3 auditing
the three ICP canisters + the Godot bridge, with every claim independently
verified against the actual code before anything changed — see
`docs/model-responses/2026-07-28-kimi-VALIDATION.md`). Four bugs confirmed and
fixed, full 8-gate battery re-run clean afterward:

1. **Leaderboard kept your latest run, not your best** — replaying a level and
   doing worse silently erased your own record. My own code comment claimed
   the opposite of what the function did.
2. **The anti-spam cooldown table grew forever** — every principal that ever
   submitted added a permanent entry, scanned in full on every new submission.
3. **A trailing newline in the price feed silently dropped the last token**,
   every single refresh — a routine shape for real API responses.
4. **Inconsistent error handling in the Godot↔ICP bridge** meant one failure
   mode kept retrying (and timing out) forever instead of falling back cleanly.

All four fixed, verified against the real files (not just accepted from the
audit), gates green: gdparse · export (0 script errors) · v1.0 campaign 5/5 ·
shooter 6/6 · save-compat 18/18 · icp-contract 13/13 · security-sentinel 18/18
· can_instantiate 106 scripts + 71 scenes. Total dispatch spend: $0.29.

**Blocker, unchanged:** the ICP write path (real score submission on-chain)
still needs an identity-strategy decision — Rabby wallet vs. Internet
Identity. Two-option comparison with exact files, session estimates, and risks
for each is in `docs/architecture/identity-strategy-options.md`. This is
currently the single thing standing between "reads work" and "the ICP
leaderboard is real."

## 🔫 v1.2 "BLUNT FORCE" — SHOOTER PROTOTYPE IS PLAYABLE (2026-07-26)

**Try it:** main menu → **NEW: BLUNT FORCE (v1.2)** (top-left button).
ESC returns to the menu. Nothing about the v1.0 campaign changed — Play
Level 1 and Continue behave exactly as before (re-verified, 5/5 gates).

**Design doc:** `docs/GDD_v1.2_BLUNT_FORCE.md` — 3 pages: Bong Blaster's four
tiers, the cover system, the three-enemy roster, Auditor Prime's four phases,
Levels 4–6, and how it all plugs into the existing save/progression without a
second source of truth. Three open questions for you at the bottom.

**What the prototype proves (`src/shooter/`):**
- **Aim is decoupled from movement.** The bong tracks your mouse with a live
  crosshair while you strafe the other way. That one change is most of what
  separates a shooter from a platformer with a gun.
- **Firing has weight** — cooldown, muzzle flash, recoil kick, screen shake.
  The crosshair dims while the weapon is recovering, so you can read your own
  fire rate without a HUD element.
- **Cover is the verb.** Hold DOWN next to a crate to duck behind it. The
  crate eats the incoming bolts, visibly cracks, then shatters — and the drone
  genuinely loses line of sight (raycast, not a fake timer). Firing from cover
  peeks you out for a beat, then re-ducks.
- **The Tax Drone plays fair**: patrol → alert → **0.85s red telegraph** →
  fire → reposition. It never shoots what it can't see and never shoots
  without warning you first.
- **Ammo comes from weed leaves**, placed away from cover on purpose — you
  have to leave safety to restock. That's the cross-mode economy from the GDD:
  leaves collected in the platformer become shooter ammo, so v1.0 content gets
  *more* valuable when v1.2 lands, not obsolete.

Verified in a real browser end to end: boots, reaches PLAYING, strafes, aims,
fires, ducks, peek-fires — zero script errors
(`scripts/verify-shooter.mjs`, screenshots captured at each beat).

**Bonus fix found along the way (affects the whole game):** `web3_bridge.gd`
had a `:=` inference from a Variant, which Godot 4.3 treats as a hard error.
It silently failed that script at load time and cascaded into `player.gd`,
`lil_blunt_visual.gd`, and five UI panels on every single export. The export
log now has **zero** script errors for the first time.

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
  safety wording, Rabby guide), full OFFLINE MODE (banner, cached
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
