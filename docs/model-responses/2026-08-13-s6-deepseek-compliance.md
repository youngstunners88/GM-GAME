<!-- dispatched: deepseek/deepseek-v4-pro
     prompt: prompts/s6-deepseek-compliance.md
     files inlined: 1
     tokens: 1119 in / 473 out
     cost: $0.0024
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
**Compliance / regression cross-check for Session-6 planned work:**

1. **No hardcoded wallet/contract addresses**  
   - Vault clerk interaction: in-game dialog + goldmine_system counters only. No mention of on-chain calls, no address strings.  
   **Verdict: PASS**

2. **Weed/diamond content positive & chill; enemies not weed-themed**  
   - Vault clerk is a character, not an enemy. Stage-2 boss fires diamond/crystal shards (minerals, not weed). Stage-3 boss chase fix is movement-only.  
   **Verdict: PASS**

3. **Web export must stay non-threaded**  
   - No threading APIs used in goldmine_system.gd save/load, blaze_rush.gd counter, boss projectile swaps, or chase logic changes.  
   **Verdict: PASS**

4. **Save/load compatibility for `blaze_diamonds` counter**  
   - **Risk:** If `blaze_diamonds` is not defaulted in `load_save_data`, a save without the key will throw on `data.blaze_diamonds`. Must use `data.get("blaze_diamonds", 0)` or set a class default when key is missing.  
   **Verdict: RISK** — needs explicit default guard.

5. **Godot 4.3 `var x := <Variant>` parse-error trap**  
   - Any new code assigning from `get_first_node_in_group()`, `get_node()`, or similar must use explicit types. Vault clerk scene instantiation and boss projectile swaps are the high-risk spots.  
   **Verdict: RISK** — needs lint check on all new files/touched methods.

---

**One regression test most likely to catch a mistake:**

- **Test name:** `test_old_save_loads_without_blaze_diamonds`  
- **What it does:** Calls `load_save_data` with a dict containing the current save schema *minus* `blaze_diamonds`. Asserts no crash and `blaze_diamonds == 0`. This catches both the missing-key crash and the missing-default-class-var crash in one shot.