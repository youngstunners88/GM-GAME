<!-- dispatched: deepseek/deepseek-v4-flash
     prompt: prompts/deepseek-compliance-note.md
     files inlined: 0
     tokens: 1659 in / 610 out
     cost: $0.0004
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
1. **Followed.** Defects found and fixed first (root causes via code reading), then guard-skills (DeepSeek draft landed as `.claude/skills/`), then aesthetics (one vertical slice only after all fixes and gate battery passed). No reversal or interleaving.

2. **Used as intended.** Fable-5 drafted stomp-attack and Auditor redesign. Claude verified output, catching a parse-error trap: `var p := get_first_node_in_group(...)` returns untyped `Node` → `p.global_position` is a Variant, causing a hard parse error in Godot 4.3. Fix applied before landing.

3. **Handled honestly.** No screenshots existed at session start; when they arrived mid-turn, Claude used native vision and stated the deviation openly. No need to block more—the vision task was completed.

4. **No violation.** All fixes touched only defect-related code (blaze rush, camera limits, ladder positions, stomp attack, Auditor redesign). No mobile overlay, titles, How-To-Play, or observability wiring from prior sessions were altered.

5. **COMPLIANT**