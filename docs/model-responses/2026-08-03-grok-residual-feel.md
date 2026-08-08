<!-- dispatched: x-ai/grok-4.5
     prompt: prompts/grok-residual-feel-brief.md
     files inlined: 0
     tokens: 660 in / 330 out
     cost: $0.0033
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
## Residual feel brief — stomp + Auditor chase

**1. Chase punish window**  
Too fast for a first encounter. Losing a life within a couple seconds of turning away reads as “gotcha close” more than readable pressure — especially right after the arena loads and the player is still learning the boss moves. Fair chase is fine; the catch-up landed hard.

**Tune:** one number — give ~0.6–0.8s extra before full chase speed (telegraph / ramp-in). Keep top speed; delay when it peaks so retreat after trigger isn’t an instant life tax.

**2. Stomp / death VFX**  
Bounce-on-contact with score +40 and no life loss is the right stomp read. Missing a death frame in the shot is most likely capture timing (kill + bounce same beat). Still worth one follow-up glance in-session: confirm despawn/death VFX actually plays and isn’t truncated or same-frame hidden under the bounce. Feel is fine; verify the juice isn’t getting eaten.

No code. Residual only.