<!-- dispatched: x-ai/grok-4.5
     prompt: prompts/grok-distributor-spectacle.md
     files inlined: 0
     tokens: 1919 in / 3065 out
     cost: $0.0222
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
1. **Movement Threat** — **Hoard Gravity**
- **Mechanic:** Distributor clutches all three ETH orbs to his chest and activates a radial pull field that drags Lil Blunt toward his body (and toward any pits under the arena). He keeps floating on his patrol line while the field is live; the threat is forced repositioning, not a dash. Pull is a constant horizontal+vertical attract toward his origin for the duration—no homing charge, no straight-line slam at last position.
- **Telegraph:** Orbs snap inward and pulse violet → two concentric dashed rings (simple `_draw()` arcs) shrink onto him over **0.65s** → rising bass hum + crystal chime. Field only starts after the rings fully collapse. Readable reaction window every time.
- **Counter-play:** Jump and run *against* the vector; use ladders and existing ledges to break line-of-pull; Blaze Mode’s speed makes escape trivial. Standing still is punished; vertical pathing is rewarded. Field does light chip only if you actually touch his body hitbox—not the field itself.
- **Phase scaling:**  
  - P1: 1.4s duration, mild pull, alone (no orbs thrown during it).  
  - P2: 1.8s, stronger pull, he may fire a 3-orb fan *the instant the field ends*.  
  - P3: 2.2s, strongest pull, field can overlap the start of a shard volley, and he blinks 40px up before activating so the pull yanks you off floors toward open air.

2. **Token Spectacle** — player-favorable only; non-holders get the exact base fight
- **DIAMONDS — Prism Pools:** Three faint cyan diamond prisms (Sprite2D + CPUParticles2D sparkle) idle at fixed arena anchors representing the three payout pools. Player attacks that pass through a prism leave a bright refraction trail and, for 1.5s, slightly enlarge the Distributor’s vulnerable hitbox draw (easier to read, same damage). Pure aim/spectacle help for the signature moment.
- **GOLD — Gilded Seams:** Thin gold ColorRect ledges etch into the left/right crystal walls at two heights when phase 2 starts. One-way footholds (collide from above only) so vertical recovery after a bad pull is safer. They never block his attacks.
- **SMOKE — Haze Softener:** Any Blaze Mode active during the fight leaves short-lived cyan-violet puff clouds (CPUParticles2D). Enemy orbs that pass through a cloud drop to ~60% speed for the rest of their flight. Does not alter orb count or pattern—only softens projectiles for holders.

3. **Signature Skill Moment** — **Forced Distribution**
- **Mechanic:** Every thrown ETH orb spawns with a **0.35s unstable window** (bright white-cyan flash + expanded sparkle). If the player’s attack hitbox connects with the orb in that window, the orb **redirects** straight at the Distributor’s chest and explodes on contact for **1 damage outside the normal vulnerable state**, then vanishes in a payout burst (gold coin + ETH-glyph particles raining upward—“distributed”).
- **Input:** Same attack already used on the boss. No new button. Timing + positioning only.
- **Reward:**  
  - 1 redirected orb = 1 free damage + big juice.  
  - Redirect every orb in a single volley = **POOL DRAIN**: immediate stun into an extended VULNERABLE, plus 1 bonus damage, screen-wide cyan flash, and the line “distribution enforced…”.  
  Body hits during normal VULNERABLE still work exactly as now—this is optional skill damage on top, the thing players will clip and describe.
- **Why it fits:** His whole premise is hoarding the three pools. The player’s skill expression is literally taking the rewards from him and forcing them back. Ties orbs, theme, and the Auditor’s “damage outside the window” beat without copying reflect-shards.

4. **Phase Readability**
- **→ Phase 2 (HP 4):** Hard violet palette shift on body and orbs (`#5a3d99` dominate). Cracks spiderweb across his torso (simple Sprite2D overlay or `_draw()` lines). One heavy screen shake + descending crystal chime. Taunt: “recalculating allocation…”. Orb count steps to 5; homing turns on; first Gilded Seams appear for GOLD holders.
- **→ Phase 3 (HP 2):** Body core blows out to near-white cyan, outer shell goes deep navy with violent particle shed. Continuous low rumble + faster patrol bob. Second shake + pitch-up stinger. Taunt: “liquidating remaining pools.”. Orbs go 5-fast; Hoard Gravity reaches max and can overlap throws; unstable flash on orbs becomes snappier (still 0.35s, but spawn cadence is tighter so the window feels scarcer).

5. **What I'd cut**
- **Ship no matter what:** Hoard Gravity + Forced Distribution. They fix the two real failures (no positional pressure, no skill moment) and make him feel like the DIAMONDS boss instead of Auditor-lite.
- **Ship next:** Phase readability cues (palette, cracks, taunts). Cheap and stop the “did the fight just get harder?” confusion.
- **Cut first if time dies:** All three token spectacles. They are delight, not structure; the base fight must already be complete and fair without them. If one token perk survives, keep DIAMONDS Prism Pools—it directly services the signature moment.