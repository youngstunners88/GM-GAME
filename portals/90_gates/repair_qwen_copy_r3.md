<!-- dispatched: qwen/qwen3.8-max-prime
     prompt: prompts/portals/repair_qwen_copy.md
     files inlined: 1
     images attached: 0
     tokens: 3118 in / 3072 out
     cost: $0.0493
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
FACT_LOCK: FAIL

```json
[
  {
    "path": "gold.stops[3].line",
    "text": "The weekly Rush: forfeited GOLD for XAUT. Posted here.",
    "problem": "Pillar says 'forfeit GOLD to compete for XAUT' (auction/competition). Copy says 'forfeited GOLD for XAUT', which reads as a direct exchange and drops the competitive mechanic. Also drops 'Gold' from the proper name 'Gold Rush' and omits 'auctions'.",
    "fix": "The weekly Gold Rush: forfeit GOLD to compete for XAUT. Posted here."
  }
]
```