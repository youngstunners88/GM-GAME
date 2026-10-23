---
name: gm-game-transition-repair
description: Repair Episode 1 reward and Episode 1–2 / lift–woods / quad handoffs from founder feedback; use the component skills, implement, measure and ship.
---

# Transition repair workflow

Source: https://docs.google.com/document/d/1V5_GH8g7z15yiSypN-DNI4FHpHCOLhdMFcqURYwGP_E/edit (2026-10-23).

Read AGENTS.md, smokerealm-resume and the default manifest first. Preserve concurrent work, title/access locks, NFT contract and the nonthreaded Godot 4.3 export.

1. Record each requested behavior in docs/founder-feedback/2026-10-23_transitions.md. Keep measured causes, source paths, evidence and open limits per complaint.
2. Use gm-game-transition-dialogue for reward/actor speech; gm-game-location-continuity for the lift window and handoff pose. Use ep2-seamless-transition for the Episode 1–2 critical loading path, ep2-no-blackouts for chamber prebuild, and ep2-interlude-chain for first-person control and finite resources.
3. Shorten idle time by overlapping movement with complete dialogue. Never overlap speakers or cut required speech. Remove the specifically rejected handle line. Boss NFTs use card + jingle; protocol-test rewards retain their existing speech.
4. Only opening-runner assets may block Episode 2 entry. Later rooms warm during the runner. Preserve the approved film, last-frame cover, earned story entry, menu access gate and error recovery.
5. Capture the same player view immediately before/after a doorway and the whole reveal-to-ride action. Verify handoff position/gaze, visible weapon, no fade, no frame-sized teleport, leaf clearance and correct music start. A headless test does not prove visual quality.
6. Run tests/transition_feedback_test.tscn, nft_issuer_test, transition_director_test, ep2_interlude_test and relevant session/facility checks; then the pinned compile, full CI, fresh-pack and security gates required by smokerealm-ship. Verify the actual source SHA, upload and public BUILD before saying live.

Skills exist to execute repairs. A written recipe is not a gameplay fix. Save precise unchecked limitations and continue until implemented/tested/released or a concrete external blocker is established.
