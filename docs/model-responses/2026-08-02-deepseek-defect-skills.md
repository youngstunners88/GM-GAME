<!-- dispatched: deepseek/deepseek-v4-flash
     prompt: prompts/deepseek-defect-guard-skills.md
     files inlined: 0
     tokens: 1843 in / 2457 out
     cost: $0.0009
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
```yaml
.claude/skills/blaze-rush-lifecycle/SKILL.md
```
```markdown
---
name: blaze-rush-lifecycle
description: Run after adding/modifying any Blaze-Rush-like secret mode exit/checkpoint logic.
---

# Blaze Rush Lifecycle Audit

1. **Exit returns to originating level**: Does `_exit_to_level()` use the actual `level_index` from the run's launch context (not a hardcoded integer like `1`)?  
   - [ ] PASS: Uses stored `originating_level_index` variable  
   - [ ] FAIL: Hardcoded level slot found (see defect #1: `save_checkpoint(1, ...)` wrote to wrong slot)

2. **Visible exit control**: Is there a UI button or keybind visible at all times during the secret mode (not hidden behind a menu)?  
   - [ ] PASS: Exit control always visible  
   - [ ] FAIL: No exit control or only accessible via pause menu

3. **Checkpoint slot restoration**: Does exiting call `save_checkpoint(level_index, id, pos)` with the correct level's dictionary key?  
   - [ ] PASS: Uses same `level_index` as the level that launched the mode  
   - [ ] FAIL: Writes to a different level's slot (causes "game restarted" feel on return)

4. **Spawn on return**: Does `LevelBase._spawn_player()` find a checkpoint under its own `level_data.level_index` key after exit?  
   - [ ] PASS: Checkpoint exists and player spawns at saved position  
   - [ ] FAIL: Falls through to default spawn (defect #1 symptom)
```

```yaml
.claude/skills/ladder-top-exit-guard/SKILL.md
```
```markdown
---
name: ladder-top-exit-guard
description: Run after placing any new ladder.tscn instance in a level script, or after editing a ladder's position.
---

# Ladder Top-Exit Offset Audit

1. **Custom offset set**: Does the ladder instance have a non-default `top_exit_offset`?  
   - [ ] PASS: Custom offset configured  
   - [ ] FAIL: Uses default `(0,-20)` — proceed to check #2

2. **Default offset verified**: If using default `(0,-20)`, does the ladder's top_y + (-20) land within a platform's x-range?  
   - [ ] PASS: Player stands on solid ground after topping out  
   - [ ] FAIL: Player drops in open air (see defect #2: level_01 ladder at x=2345)

3. **Platform proximity check**: Is there a platform within 20px vertically of the ladder's top, with x-range covering the ladder's x?  
   - [ ] PASS: Platform exists and overlaps  
   - [ ] FAIL: No platform or x-mismatch (needs custom offset computed per-instance)

4. **Consistency with tuned ladders**: Compare against level_02's ladders (which have correct computed offsets) — does this ladder's placement follow the same pattern?  
   - [ ] PASS: Matches tuned pattern  
   - [ ] FAIL: Untuned default used where mechanism exists but data is missing
```

```yaml
.claude/skills/collectible-walkthrough/SKILL.md
```
```markdown
---
name: collectible-walkthrough
description: Run after adding any new Area2D collectible scene or modifying an existing one's collision/placement.
---

# Collectible Walk-Through Audit

1. **Signal type**: Does the collectible use `body_entered` (not `area_entered` or velocity-gated check)?  
   - [ ] PASS: Uses `body_entered`  
   - [ ] FAIL: Uses other signal or manual velocity check

2. **Collision mask**: Does the Area2D's `collision_mask` include the player's physics body layer?  
   - [ ] PASS: Mask matches player layer  
   - [ ] FAIL: Mask excludes player (collectible invisible to body)

3. **Vertical placement**: Is the collectible's shape positioned so a standing/walking player can touch it (y ≤ player's head height + 10px)?  
   - [ ] PASS: Reachable while standing/walking  
   - [ ] FAIL: Only reachable via jump arc (see defect #4: likely height placement issue, not code defect)

4. **Multiple triggers**: Does the collectible prevent double-collection (e.g., `monitoring = false` after first pickup)?  
   - [ ] PASS: Disables after first collection  
   - [ ] FAIL: Can be collected multiple times per body entry
```

```yaml
.claude/skills/stomp-attack/SKILL.md
```
```markdown
---
name: stomp-attack
description: Run when implementing or verifying a head-stomp/jump-attack mechanic against enemies.
---

# Stomp Attack Implementation Audit

1. **Direction check**: Does the stomp only trigger when the player is ABOVE the enemy (y position check, not side/below)?  
   - [ ] PASS: Fires only from above  
   - [ ] FAIL: Triggers from any direction

2. **Damage direction**: Does the stomp damage the enemy (not the player)?  
   - [ ] PASS: Enemy takes damage  
   - [ ] FAIL: Player takes damage or no damage applied

3. **Player bounce**: Does the player receive an upward velocity impulse after successful stomp?  
   - [ ] PASS: Player bounces up  
   - [ ] FAIL: No bounce (player falls through or lands normally)

4. **No double-fire**: Does the stomp path avoid conflicting with existing hazard/boulder contact-damage paths?  
   - [ ] PASS: Separate state or cooldown prevents double-damage  
   - [ ] FAIL: Stomp and contact-damage both fire on same collision

5. **Code existence**: Confirm stomp mechanic actually exists in codebase (see defect #5: currently NO stomp mechanic exists).  
   - [ ] PASS: Stomp code present  
   - [ ] FAIL: No stomp mechanic implemented yet
```

```yaml
.claude/skills/boss-chase-ai-auditor/SKILL.md
```
```markdown
---
name: boss-chase-ai-auditor
description: Run after implementing or modifying any boss's aggressive-movement state (CHARGE, CHASE, PURSUE).
---

# Boss Chase AI Audit

1. **Live position tracking**: Does the boss re-read the player's `global_position` every frame during the chase state?  
   - [ ] PASS: Updates target each frame  
   - [ ] FAIL: Uses stale snapshot from state entry (see defect #6: `charge_target = p.global_position` never updated)

2. **Gap/jump handling**: Can the boss navigate gaps or ledges? Is there a `max_jump_gap` or similar landing-distance gate?  
   - [ ] PASS: Has gap-jumping logic with distance check  
   - [ ] FAIL: Falls into pits or gets stuck on ledges

3. **Telegraph before aggression**: Is there a visual/audio cue before the boss enters the chase state (e.g., wind-up animation, sound)?  
   - [ ] PASS: Telegraph present  
   - [ ] FAIL: Boss instantly chases without warning

4. **Ranged attacks during movement**: Can the boss perform ranged attacks WHILE moving, or only in a separate stationary state?  
   - [ ] PASS: Ranged attacks possible during movement (or intentionally separate)  
   - [ ] FAIL: Ranged attacks locked to stationary state only (see defect #6: PATROL and CHARGE mutually exclusive)

5. **State machine clarity**: Are chase and attack states clearly separated (not overlapping or blocking each other)?  
   - [ ] PASS: Clean state transitions  
   - [ ] FAIL: States block each other (e.g., cannot attack while moving)
```

```yaml
.claude/skills/tool-hold-anchor/SKILL.md
```
```markdown
---
name: tool-hold-anchor
description: Run after adding/modifying any held-tool/weapon sprite attachment logic.
---

# Tool Hold Anchor Audit

1. **Grip point anchoring**: Is the tool sprite anchored to a specific grip point (e.g., hand position), not sprite-center?  
   - [ ] PASS: Anchored to grip point  
   - [ ] FAIL: Uses sprite-center (drags long assets to feet on short character)

2. **Texture dimensions verified**: Is the positioning math verified against the ACTUAL exported texture dimensions (not assumed)?  
   - [ ] PASS: Uses actual texture size from import  
   - [ ] FAIL: Uses hardcoded or assumed dimensions

3. **Visual confirmation**: Has a screenshot been reviewed to confirm the tool appears at the correct position (hand/grip) in-game?  
   - [ ] PASS: Screenshot confirmed  
   - [ ] FAIL: No visual verification (see defect #7: needs browser evidence)

4. **Existing code review**: Check `lil_blunt_visual.gd::set_tool()` — does it already have grip-anchored positioning math with comments about prior fixes?  
   - [ ] PASS: Code already has fix comments  
   - [ ] FAIL: No existing anchoring logic (defect may be stale build issue)
```

```yaml
.claude/skills/stage-progress-blocker-scanner/SKILL.md
```
```markdown
---
name: stage-progress-blocker-scanner
description: Run after adding/modifying any campaign level (Level 1/2/3) or its geometry/triggers.
---

# Stage Progress Blocker Audit

1. **Camera limits match level bounds**: Does the player's Camera2D `limit_right` (and `limit_bottom`) match this level's `bounds.x` (and `bounds.y`)?  
   - [ ] PASS: Limits match level bounds  
   - [ ] FAIL: Uses stale default from another level (see defect #3: hardcoded `3400` on Level 2/3 with `bounds.x = 4400`)

2. **Per-level override**: Does `LevelBase._setup_camera_limits()` (or equivalent) set limits from `level_data.bounds` after player spawn?  
   - [ ] PASS: Override exists and uses level bounds  
   - [ ] FAIL: No override (camera frozen at wrong limit, player walks off-screen)

3. **Ladder/platform data match geometry**: Do all ladder placements have `top_exit_offset` values that match actual platform positions in this level?  
   - [ ] PASS: All offsets verified against geometry  
   - [ ] FAIL: Untuned defaults that may drop player in open air (see defect #2)

4. **Critical path reachability**: Is every ladder, platform, and trigger reachable from the level's starting position without sequence breaks?  
   - [ ] PASS: All critical path elements reachable  
   - [ ] FAIL: Element unreachable (player cannot progress)

5. **Boss arena visibility**: If this level has a boss, does the camera clamp allow the player to see the boss spawn area (not cut off at wrong limit)?  
   - [ ] PASS: Boss arena visible within camera limits  
   - [ ] FAIL: Boss spawns beyond camera clamp (see defect #3: boss "unseen" on arrival)
```