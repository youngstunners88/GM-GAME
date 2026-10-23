---
name: gm-game-transition-dialogue
description: Prevent actor self-interruption and dead air in SmokeRealm story transitions; honor silent boss NFT rewards and use deterministic movement/speech choreography.
---

# Dialogue during transitions

The 2026-10-23 founder request supersedes older instructions to speak after a boss NFT jingle and to describe the lift handle.

- NftIssuer._play_congrats: boss kind returns after jingle; preserve the card, all six IDs, issuance, retry and honest ICP timestamps. Test kind keeps its existing line. Do not solve presentation by changing award logic.
- MineLiftChamber: no vo_bull_lift_lever in any active show. Retain the physical reach, handle swing and lift sound. Let an incoming carried line finish before the next scripted line. The daylight objective and physical exit convey arrival without a blocking narration.
- FacilityShow uses a deterministic _hold clock. A call to _begin_carry_line starts speech while a walk/reach continues. Before the next speaker use an until predicate on _hold <= 0. Do not add fixed waits guessed from text length, and never replace a line mid-sentence just to make a cut faster.
- Quad: speak the reveal while reaching/brushing; Lil Blunt answers while both approach the bike; mount speech plays during the climb. Wait for actual motion completion before riding. Keep Deep Mining 3 and the engine tied to mounting, never the reveal.

Evidence: record line_spoken IDs and deterministic timestamps across normal/fast input; assert the forbidden line never appears, boss voice never starts after the old 1.7-second timer window, and legitimate protocol-test speech still works. Observe/audio-review the player-facing sequence where possible; source checks alone cannot prove sound playback.
