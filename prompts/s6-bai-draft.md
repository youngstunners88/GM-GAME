@include prompts/_s6_facts.md

# YOUR ROLE: B.AI extra-hands lane — parallel design draft

Draft a compact spec for the Diamond Vault clerk stake/crush flow (T1). Cover:
1. State: current holdings shown ($DIAMONDS tokens + Blaze Diamonds).
2. Step 1: choose how many $DIAMONDS to stake (clamp 0..owned).
3. Step 2: choose how many Blaze Diamonds to crush (clamp 0..owned, and
   0..stack limit).
4. Confirm -> apply. Propose a simple readable crush rule (one line).
5. Edge cases: zero owned, over-clamp, double-confirm.
Keep it under 300 words, as a numbered flow a Godot dev can implement directly.
