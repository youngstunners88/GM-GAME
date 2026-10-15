---
name: jev-decision-gate
description: Ask bounded typed Jev decisions over measured gate evidence; use the shared Jev 1.14 routing skill for current direct TypeSafe and explicit OpenRouter/image handling.
---

# Measured Jev decisions

Read `.claude/skills/jev-1-14-routing/SKILL.md` first. The user selected direct TypeSafe for Jev 1.14 on 2026-10-15, using configured TYPESAFE / TYPESAFE_API_KEY. OpenRouter remains explicitly available for older text integrations and Microsoft Decision, using its own credential. Do not switch providers automatically.

Keep deterministic calculations/tests local. Send a small state and typed `noul` (portable `boolean`), named `choice` or ordered `score` questions with clear instructions/criteria. Reuse `scripts/jev.mjs`, which validates input, bounds text/images, maps boolean to noul and validates responses. >=0.8 means yes, <=0.2 no, and the middle is uncertain. A semantic decision is not permission or evidence of a deployed game.

```sh
python3 scripts/seam-smudge-gate.py --json /path/to/frames/ > gate.json
node scripts/jev.mjs --from-gate gate.json
# Explicit existing OpenRouter route:
JEV_PROVIDER=openrouter node scripts/jev.mjs --from-gate gate.json
```

Legacy metric CLI exits: 0 ship, 1 block, 2 uncertain, 3 transport/usage error. Generic `--request` mode returns typed results without mislabeling an arbitrary design choice as a ship/block vote. No automatic retries/fallback on 401/403/422/429/529/timeouts; retain the outcome and continue independent work.

The September Jev 1.13 base64-as-text experiment remains historical evidence of an incorrect image request. It is superseded by the documented file-byte asset protocol in the 1.14 routing skill. Proper encoding still needs live API and paired image-control evidence before a vision verdict is trusted. Direct TypeSafe and the supplied docs are currently blocked by cloud proxy CONNECT 403; do not invent model limits, rates or successful review.
