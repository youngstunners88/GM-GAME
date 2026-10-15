# PROMPT_EPISODE2_SURFACE_TO_TOWN_DRAW_SPEC.md
# Episode 2 Narrative Update — Surface Exit → Quad → Town Entry → Certificate → Bar Draw (2026-10-14)

**Status:** Active narrative lock for the surface-to-town transition and first town conflict.  
**Supersedes** prior assumptions of an immediate town arrival or direct Fort Knox express.  
**Preserves** existing underground runner, smelting facility Bull meeting, Winchester hand-off, and current quad transition beats.  
**Scope of this document:** Sequence from surface exit through Bull’s arrival after the draw. Everything after Bull arrives at the bar remains open and will be extended in a follow-up.

**Give this file to Claude Code** alongside the existing Episode 2 architecture (`artifacts/episode2-gold-mine/spec/`) and prior narrative locks.

---

## Locked Sequence (Surface → Town Draw)

### 1. Surface Exit + Quad Ride (current behavior preserved)
- Lil Blunt and Inferno Bull surface from the underground / smelting facility.
- They walk to the quad exactly as currently implemented.
- They mount and head toward town.
- On the way, balaclava bears attack. Lil Blunt shoots them. **No change to this combat.**
- The closer they get to town, the bears stop appearing / disappear.
- No formal meetings with other people on the trail.
- Optional atmospheric presence only: 1–2 distant riders on horseback (or walking figures) who do not interact. They exist to imply the road is not empty, not to trigger dialogue or combat.

### 2. Bull’s Departure Instructions
- Before or as they near the town edge, Inferno Bull tells Lil Blunt he has a Blondie to see.
- He will meet Lil Blunt at the bar for a whiskey.
- He instructs Lil Blunt to go to the certificate office first and get the sheriff to get him a certificate.
- Bull then leaves (first deliberate disappearance). Lil Blunt continues alone into town.

### 3. Certificate Office + Sheriff
- Lil Blunt goes to the certificate office (one of the buildings shown in the Gold Mine town visualization).
- The sheriff is present and involved.  
  **Sheriff identity lock:** Jake (JakeX / TitanX ecosystem tribute character). Cigarette in mouth. Recognizable as the TitanX founder-meme figure elevated into a Western lawman role. He is not a random NPC; he is the on-screen identification of the broader TitanX ecosystem inside the Gold Mine town.
- The sheriff directs Lil Blunt (certificate process / next step). Exact certificate mechanics stay faithful to the whitepaper (non-transferable claims, share requirements, etc.) but do not need to be fully resolved in this beat—direction is sufficient.
- After the sheriff interaction, Lil Blunt is pointed toward (or simply finds) the bar.

### 4. Bar Arrival (Lil Blunt alone)
- Lil Blunt reaches the bar long before Inferno Bull.
- He orders a whiskey and pays with a quarter Bitcoin.
- Someone in the bar notices the payment.
- This notice immediately sparks the confrontation / draw.

### 5. The Draw — Conditions
- Opponent’s demand / negotiation:  
  **“Give me a bitcoin or I give you the map to the auction where they can get more intel.”**
- Stakes: Die and pay BTC, or kill and get the map.
- Lil Blunt has no backing at this moment (Bull is not present).
- The sheriff decides to be his witness. This is the only reason the draw proceeds under formal (or at least witnessed) conditions rather than an immediate ambush.
- Outcome possibilities remain open for implementation, but the narrative contract is: the map to the auction (further intel) is the prize for winning the draw; losing means payment or death.

### 6. Bull Arrives
- After the draw is underway or concluded, Inferno Bull arrives at the bar.
- This is the first reappearance after his Blondie exit.
- How he reacts, whether he intervenes, and what happens next are **not locked** in this document. They are the starting point for the next narrative pass.

---

## Design Notes for Claude Code

- **Reputation without exposition:** Bull’s mixed standing in town is implied by the fact that he has business (a Blondie) and that the sheriff is willing to act as witness for someone associated with him, but it is not explained in dialogue yet.
- **Town as place, not skip:** The certificate office and bar are the first two concrete locations from the town visualization that the player physically enters. Later chambers (Auctions, Stockpile, Reserve, Treasury, Fort Knox) remain available for the continuation.
- **Bitcoin as narrative trigger:** The quarter-Bitcoin payment is the visible spark. Do not invent additional tokenomics; it is a practical, high-value payment that draws unwanted attention.
- **Sheriff Jake role (this beat only):** Witness and director. He gets Lil Blunt a certificate path and stands as witness so the draw has structure. Deeper TitanX ecosystem ties can be expanded later.
- **Bull presence pattern established:** Disappears for the certificate + early bar, reappears after the draw begins. This pattern should continue in later sections (he is not present for every situation).
- **Existing locks still in force after this point:**  
  - Later Fort Knox approach involves lock elements (not an immediate gold grab).  
  - Inferno Bull sacrifice beat still occurs around securing those lock elements.  
  - AwesomeX (dragon) still rescues him.  
  These remain downstream of the bar draw and are not redefined here.

---

## Immediate Implementation Guidance

1. Preserve the current surface-to-quad transition and bear-shooting stretch exactly.
2. Add the fading of bear encounters as the player approaches town.
3. Implement the short Bull dialogue that sets the Blondie / bar / certificate-office instructions, then remove him from the scene.
4. Certificate office scene with Sheriff Jake (cigarette, TitanX-ecosystem visual identity).
5. Bar scene: Lil Blunt alone, whiskey, quarter-Bitcoin payment noticed, draw triggered under the stated conditions, sheriff as witness.
6. Bull arrival timed after the draw has started or resolved.
7. Do not invent protocol numbers. Map only what the Gold Mine whitepaper already states when chambers are expanded later.
8. Update `STATUS.md` and any Episode 2 story outline to point at this file as the current surface-to-town lock.

---

## Open for Next Pass (explicitly not locked)

- Exact outcome handling of the draw (player win / lose branches).
- What Bull does or says when he arrives.
- Sequence and gameplay of the auction (the map’s destination) and subsequent town facilities.
- Precise nature of the “lock elements” that later trigger the Fort Knox sacrifice beat.
- How much of the town remains semi-open versus strictly sequential chambers.

**This file moves the narrative forward without closing the rest of the arc.**  
The gold rush continues. The town is no longer a poster. Claude Code now has a concrete sequence from surface exit through the bar draw.