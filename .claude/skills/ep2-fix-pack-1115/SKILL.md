---
name: ep2-fix-pack-1115
description: Router and gate for the 2026-11-15 founder fix pack (New Fixes.md) - 3 licenses, Rich/Utah speech and gun reveal, Dude horses and auto-greet, Logan's 3-sentence LP lesson, one continuous ridge and auction road, Rich collects the shipment, auctioneer voice ID, GM OG Smoke on the road. Use FIRST on any of those items; it routes to the focused skill and lists the files and the proof each one needs.
argument-hint: "plan | item <1-8> | proof"
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
---

# Fix pack 1115: what the founder said, where it lives, which skill owns it

Source: founder's "New Fixes.md" (Drive, 2026-11-15). Several of these are **repeats** ("still 4", "still all brown", "I told you this must be one world"). A repeat means the last fix was not proven in the real renderer. Do not claim a fix without the proof in the last column.

| # | Founder said | Files | Skill | Proof |
|---|---|---|---|---|
| 1 | Still 4 certificates, want 3 | `chamber/gold_town.gd` (`LICENSE_TIERS`, `_build_license_wall`, `MINISTER1_LINES`, header) | `ep2-count-and-copy-sync` | grep finds no "four"/4th tier anywhere; wall renders 3 |
| 2a | Rich keeps speaking while player trades | `actors/ep2_armory_intro.gd`, `chamber/ep2_armory_shop.gd` | `ep2-npc-conversation-flow` | trade open for the whole line, line still finishes |
| 2b | Put gold down, free hands, turn, lift the gun (no body invert) | `ep2_armory_intro.gd`, `ep2_armory_pose.gd`, `ep2_armory_brain.gd` | `ep2-hands-free-reveal` | frame strip of the hand-off, no pop |
| 2c | Glitch/slowdown while talking to Utah and Rich | same + frame-time probe | `ep2-npc-conversation-flow` section "slowdown" | frame ms before/after |
| 3a | Dude horses all brown, only one selectable | `chamber/ep2_stable_yard.gd`, `level/stable_horses.gd` | `ep2-horse-color-choice` | screenshot: white, brown, black; pick each |
| 3b | Mount without waiting; rude/goodbye if he leaves; auto-greet; shorter speech | `ep2_stable_yard.gd` | `ep2-npc-conversation-flow` | scripted run: pay mid-line, mount; walk off mid-line |
| 3c | Logan: 3 sentences on liquidity, auto-start | `chamber/logans_lake.gd` | `ep2-npc-conversation-flow`, `ep2-count-and-copy-sync` | 3 sentences, plain words, starts on sight |
| 4 | Ridge path and auction road are one world, no E-teleport | `chamber/river_cover.gd`, `chamber/auction_road.gd` | `ep2-one-world-no-e-teleport` | continuous player-position trace, no jump > 1 step |
| 5 | Rich collects the shipment | `river_cover.gd` (`_build_utah`, `_utah_arrives`, `_tick_dock`, `_hand_off_line`) | `ep2-promised-actor-beat` | frames: Rich at dock, crate leaves with him |
| 6 | Auctioneer voice ID `X0KF3ROqwE8cLCsWuhs6` | `chamber/ep2_auction_house.gd`, `assets/town-audio.json` | `ep2-voice-id-lock` | json id, generated clips, played in `_say` |
| 7 | GM OG Smoke plays on the road to the auction | `auction_road.gd`, AudioManager | `ep2-road-music-cue` | audible at road entry, ducks under speech, not restarted |

## Order of work
1. Run `ep2-build-logic` and `ep2-founder-intake` checklists once, then do items in this order: 1, 6 (data, cheap), 2 and 3 (shared conversation code, do the shared fix once), 5, 4, 7. Item 4 touches the most files; do it with a clean tree.
2. Work inline, sliced reads, filtered output (`token-efficiency`). No subagents unless asked.
3. Check the pack margin before adding any asset: `scripts/pack-gate-fresh.sh`. New audio and GLBs go in streamed extras, never the main pack.
4. Log to the Obsidian vault as you go (standing rule), no permission asks.
5. End with `always-ship-live`: ci-gates-local.sh, CI green, butler/itch tag confirmed. "Live" is said only after that; the founder has not verified earlier builds, so say "not founder-verified".

## Rules that apply to every item
- No unrequested visual changes (`feedback-no-unrequested-visual-changes`): only the named thing changes. Prove the rest is untouched.
- The founder's words are the spec. Quote the sentence you are fixing in the commit body and in the report.
- A repeat complaint gets a regression test that fails with the fix removed.
- Report what you did not check (phone layout, second playthrough).
