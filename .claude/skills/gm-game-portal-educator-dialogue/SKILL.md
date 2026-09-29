---
name: gm-game-portal-educator-dialogue
description: Write education-room content - stop names, room titles, and multi-aspect governor dialogue that teaches the real protocol. TRIGGER when the founder says governors/advisors should speak more, repeat themselves, feel detached from the protocol, a stop name or room title is random, or an info card is too thin.
---

# Educator dialogue (founder 2026-09-30)

Data lives in `src/protocol_portals/data/portal_copy.json` -> `<protocol>.stops[]`:
`{id, name, line, aspects: [3 x 2-3 sentences]}`. `line` = first sentence of aspect 0 (used in summaries).
- **Never repeat.** `StudyRoom._next_aspect()` rotates aspects on each approach / E press, so a returning
  player hears a NEW angle (e.g. Burn Engine: how the burn works -> why a sink -> culture token).
- **Overlay + balloon show the full aspect** (2-3 sentences, no one-liners; education is the point).
- **Real protocol, real names.** Stops are named for the actual mechanism: Burn Engine, Smoke Lounge,
  Omni-Chain Hub, BLAZE Forge, Scarcity Scale, Vault & Crush Press, Handler Bridge, Vesting Clock,
  Fort Knox Window, Melt Bonus Press, Gold Rush Board. Prop metaphors must be obvious (fire pit = burn).
  If the founder would ask "what the f*** is that?", rename it.
- **Room titles** follow `<PROTOCOL> 101: <place>` (SMOKE 101: The 420 Lounge).
- **Facts** come from the Gitbooks (smokering / diamonds / goldmine) and the locked quiz banks. No APYs, seed
  phrases, contract addresses or unverified numbers. Quiz facts in `data/quiz_*.json` must stay true.
- Voice: chill, confident teacher in the governor's own voice (Pauly new-school, Kane mechanic, Rich recorder).
- After editing text run `python3 scripts/gen_portal_vo.py` (see `gm-game-portal-voice`), then the room test + captures.

## Facts the founder corrected
- **SMOKE chains:** Solana, Robinhood Chain, Ethereum, BASE, BSC. NOT PulseChain. Check chain lists with him before writing them.
- The crate stop is named "Stash From The Smoke Lounge" (it is the weed stash, not the lounge itself).
