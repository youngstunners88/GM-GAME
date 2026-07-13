# Security Audit — Full GDScript Pass (2026-07-12)

Scope: every `.gd` file in `src/` (67 source files) against the 12-item
release checklist. Companion docs: `docs/security/GAME_SECURITY_CHECKLIST.md`
(pipeline/deploy surface) and `docs/security/audit-log.md` (incident history,
including the git-history key-leak scrub completed earlier today).

| # | Check | Result | Evidence / action |
|---|-------|--------|-------------------|
| 1 | No hardcoded API keys / passwords / tokens | **PASS** | `grep -riE "(api_key\|password\|secret\|token\|private_key)\s*[:=]\s*['\"][A-Za-z0-9+/_-]{8,}"` over `src/` → 0 hits. CI gitleaks scans every push as a backstop. |
| 2 | File writes only under `user://` | **PASS** | Only `FileAccess.open` sites are `game_manager.gd` save/load on `const SAVE_PATH := "user://save.json"`. No `res://` writes at runtime. |
| 3 | No non-HTTPS network requests | **PASS** | No `http://` URLs in game code. The game makes no outbound requests at all; the only browser interaction is same-origin `postMessage`. |
| 4 | No dynamic code execution | **PASS (accepted use)** | No `Expression`/`OS.execute`. `combo_system.gd` uses `JavaScriptBridge.eval` with **fixed template strings** whose only variable part is a `JSON.stringify`-encoded payload, posted strictly to `window.location.origin`. No user input reaches the eval. |
| 5 | No user input in file paths / OS.execute | **PASS** | Save path is a compile-time const; `OS.execute` absent. |
| 6 | Exports have sane defaults; loaded values clamped | **FIXED THIS AUDIT** | `load_session()` read `user://save.json` (player-editable) without bounds: 9999-health/level-42 saves corrupted state, and `max_health` was read *after* clamping-relevant `player_health`. Now: load order corrected, `max_health` clamped 1–10, `player_health` 1–max, `current_level` 1–3, currencies floored at 0. |
| 7 | No unyielded infinite loops | **PASS** | No `while true` in any `.gd` (the one grep hit is a doc-comment). |
| 8 | Signal cleanup | **PASS (by design)** | All cross-node connections are made from scene-node context; Godot disconnects automatically when the connecting node frees. Autoload→autoload connections live for the process lifetime by design. No manual `_exit_tree` disconnects required. |
| 9 | Tween lifetime | **PASS (by design)** | Every tween is `create_tween()` on the animated node (or `label.create_tween()` etc.), so it dies with its node. No orphaned SceneTree tweens. |
| 10 | AudioStreamPlayer cleanup | **PASS** | SFX players free on `finished`; positional `play_sfx_at` players likewise; music players free on track switch (ducked fade → `queue_free`) and on `finished`. |
| 11 | Collision-layer hygiene | **PASS** | Layers: World 1 / Player 2 / Enemies 4 / Collectibles 8 / PowerUps 16 / Hazards 32 / Projectiles 64. Player projectiles (axe 36, fire cone 36) mask enemies+hazards only — they cannot hit the player. Player hurtbox masks 60 (enemies/hazards/etc.), never World, no self-overlap exploit found. |
| 12 | No debug prints / temp code | **PASS (3 accepted)** | Three structured `[SceneRouter]` load-progress prints remain **intentionally**: they are the only scene-load diagnostics visible in a web-export console and were load-bearing when root-causing the itch.io boot failure. No other prints, no commented-out temp code. |

## Findings summary

- **1 fixed:** unclamped save deserialization (item 6) — tamper-resistance fix in `game_manager.gd`.
- **2 accepted with rationale:** fixed-template `JavaScriptBridge.eval` (item 4), SceneRouter diagnostics (item 12).
- **0 open.**

Re-run trigger: any new `FileAccess`, `JavaScriptBridge`, network, or save-format
change re-opens items 2–6 (see SECURITY-GATE rule in CLAUDE.md — the release
pipeline's quick gate runs unprompted on every ship).
