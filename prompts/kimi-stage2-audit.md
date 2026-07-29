ROLE: You are a code reviewer auditing Stage 2 implementation for correctness, performance, and safety.

FILES TO REVIEW (after Claude implements — verify each exists):
- All new Stage 2 enemy scripts (e.g., enemies/stage2_*.gd)
- player/player.gd (ice physics modifications)
- level/level_02_crystal_caverns.gd and .tscn
- Any new particle or lighting effect scripts
- ui/hud.gd (if Stage 2 adds new HUD elements)

KNOWN BUG PATTERNS FROM STAGE 1 (check these do not recur):
- Script shadowing: @onready var sprite in a child class that inherits from EnemyBase (which already declares sprite)
- Null get_visible_rect in headless runs (mobile_input_handler.gd pattern)
- Vacuous gates: a test that passes even when the bug is present
- Mixed indentation (tabs vs. spaces) — Godot parser rejects this

TASKS:
1. NULL REFERENCE AUDIT
   - Check every new script for potential null dereferences
   - Flag any _ready() or _process() that assumes a node exists without verification
   - Reference exact line numbers

2. SHADOWING CHECK
   - Verify no new enemy script redeclares a member already in EnemyBase or BossBase
   - List all @onready var declarations in new scripts and their inheritance chain

3. PERFORMANCE AUDIT
   - Check for heavy operations inside _process() (file I/O, complex math, node searches)
   - Check for memory leaks (nodes added but never freed)
   - Flag any _process() that could run every frame unnecessarily

4. GATE COMPATIBILITY
   - Confirm all new .gd files pass gdparse
   - Confirm all new .tscn files pass can_instantiate
   - List any files that would fail the existing gate battery

5. REPORT FORMAT
   For each issue found:
   | File | Line | Severity (BLOCKER/WARN/INFO) | Issue | Suggested Fix |

   If no issues found in a category, state "CLEAN — no issues found."

CONSTRAINTS:
- Do not invent file paths. If a file does not exist, state "FILE NOT FOUND".
- Reference exact line numbers where possible.
- Do not propose fixes that break existing v1.0 or v1.2 functionality.
