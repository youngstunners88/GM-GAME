<!-- dispatched: x-ai/grok-4.5
     prompt: prompts/grok-chase-tune-numbers.md
     files inlined: 0
     tokens: 821 in / 372 out
     cost: $0.0039
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
**Recommendation:** do both, lightly.

1. **Speed ramp:** start PURSUE at **55%** of `pursue_speed` and lerp to **100% over 0.7s**. (Phase scaling still applies to the final top speed; ramp only delays when you hit it.)
2. **Hitbox grace:** keep contact damage **off for 0.35s** after PURSUE starts, then enable it.

ALERT (0.6s) already telegraphs intent; this only separates “he’s moving” from “full speed + touch = damage.” Total time to full punish ≈ 0.7s speed / 0.35s hitbox from chase start—retreat after trigger is no longer an instant life tax, top speed and live tracking stay unchanged.