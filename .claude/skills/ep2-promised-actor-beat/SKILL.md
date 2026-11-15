---
name: ep2-promised-actor-beat
description: When the story says character X does Y (Rich collects the shipment), X must be seen doing Y on screen, in place, witnessing what the story says he witnesses. A line of dialogue saying it happened is not the beat. Use for the river dock shipment, crane and crate, Utah/Rich hand-off, and any "X arrives / collects / witnesses" request. TRIGGER on "Rich is supposed to collect the shipment", "never comes", "waits", "witnesses", "collects".
argument-hint: "audit | plan | proof"
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
---

# The promised beat must be performed

Founder 2026-11-15: "Rich is supposed to collect the shipment!!!" (a prior founder residual, still open.) The header of `chamber/river_cover.gd` still encodes the old version: "Utah waits... Rich never comes". `_hand_off_line()` is Utah congratulating the player. The code does the opposite of what was asked.

## Where it lives
`src/episode2/chamber/river_cover.gd`: header ~L16-19, `_build_utah`, `_utah_arrives`, `_tick_dock`, `_hand_off_line()`, `_build_dock`, `_place_crate`, `Beat.DOCK`, crane and crate. Rich is a streamed/extras character (`ep2_extras.pck`); check he is loadable here and check the pack margin before adding any asset.

## Required behavior
- Rich is **at the dock** by the time the shoot ends (arrives while the shoot runs or when it ends: pick whichever the scene already stages; he must witness the **end** of the shoot).
- He **collects** the shipment: walks to the crate, interacts physically (crane/crate handling, loads or takes it), and the crate leaves with him or onto his transport. The crate is not a static prop that stays behind.
- Utah's role updates to match (he no longer waits for a Rich who never comes). Rewrite `_hand_off_line()` so Rich's pickup is the hand-off; keep the lines short (`ep2-npc-conversation-flow`) and in the right voices (`ep2-voice-id-lock`).
- Follow Rich's canon (`ep2-narrative-canon`; armory notes in memory `gm-game-armory-two-story`): same body, voice and outfit as in the armory.
- Update the file header so it no longer contradicts the behavior.

## Method
1. Read `_tick_dock` and the Beat state flow; draw the order of events in 6-8 lines before coding.
2. Add Rich as an actor in `_build_*`; script his walk with the existing walk/pose clips (`ep2-character-motion-qa`), not a teleport (`ep2-one-world-no-e-teleport`).
3. Crate handling uses real contact points (`ep2-prop-contact-animation`).
4. The crate's final state is checked in code (`_crate_collected`), not just the animation.

## Proof
- Frame strip: Rich arriving, at the dock during the end of the shoot, taking the crate, leaving. No frame where the crate or Rich pops.
- Test: after the shoot's end, `_crate_collected` is true and the crate is no longer at the dock.
- Report the final order of events and what was not checked.
