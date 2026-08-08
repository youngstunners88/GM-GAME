<!-- dispatched: moonshotai/kimi-k3
     prompt: prompts/kimi-vo-event-audit.md
     files inlined: 4
     tokens: 18621 in / 29829 out
     cost: $0.5033
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
## FINDINGS

**CRITICAL — player.gd:376-393 — `take_damage()` is a shared funnel for killing and survivable blows.** `GameManager.take_damage()` (called at :382) clamps health to 0 (game_manager.gd:212-213), then `if GameManager.player_health <= 0: die()` (:385-386) branches. A naive `play_bark("vo_hurt")` at the top of `take_damage()` fires on the fatal hit too, immediately before `vo_death`. **Fix:** `vo_hurt` goes ONLY in the `else` branch (:387-393), beside `AudioManager.play_sfx("damage")` at :393. The early-returns at :380 (not-PLAYING, i-frames) already protect both paths.

**HIGH — game_manager.gd:218 vs player.gd:518 — two GAME_OVER transitions on one death path; StateMachine semantics unverifiable.** `GameManager.take_damage()` already calls `StateMachine.change_state(GAME_OVER)` at gm:218 BEFORE `Player.die()` runs; `die()` then re-guards on `is_dead()` (:514) and re-attempts `change_state(GAME_OVER)` (:518). `state_machine.gd` was not provided, so whether `die()`'s body actually executes on health-deaths cannot be confirmed from these files. **Fix:** safest `vo_death` site is the branch at player.gd:385-386 itself (runs exactly once per killing blow; all guards already passed). If placed inside `die()`, verify `is_dead()`/`change_state` behavior first.

**HIGH — audio_manager.gd:259-276 — reusing `play_voice()` for barks cuts the announcer and pumps music.** :266-267 `queue_free()`s the playing voice line (a bark during `stage1_intro`/`boss1_intro` kills it, and the killed line's `finished` never fires, orphaning its music-restore); :272-274 + :282-284 spawn duck/restore tweens on EVERY bark. **Fix:** dedicated bark path, separate player(s), no duck (see Q4).

**HIGH — vo_attack has NO call site in the provided files.** Axe/flame/fire-breath hit-confirm code lives in the scripts behind `res://src/combat/axe.tscn`, `flame_projectile.tscn`, `fire_breath.tscn` (preloaded at combat_handler.gd:11-13) — none provided. And `enemy.take_damage()` CANNOT be the funnel: it's source-blind and also called by stomp (player.gd:596), diamond/torch aura (player.gd:606-608, enabled at :248), and ground-pound AoE (player.gd:318) — keying `vo_attack` off it would bark on stomps/burns/pounds. **Fix:** provide the projectile scripts; bark at the projectile's hit-confirm. Do NOT put it in `_throw_axe`/`_throw_fan`/`_throw_flame` (combat_handler.gd:78-106) — those are button-press sites, explicitly wrong per spec.

**MEDIUM — combat_handler.gd:90-92 — one fan input spawns 3 axes; each connect would triple-fire `vo_attack` in the same instant.** Fire breath (:115-123) is a channel with unknown tick cadence (`fire_breath.gd` missing). **Fix:** 0.4s min-interval on `vo_attack` (= `AXE_COOLDOWN`, the fastest throw cadence at :21) collapses fan bursts to one bark while allowing per-throw barks.

**MEDIUM — game_manager.gd:131 — `mark_boss_defeated()` is idempotent per save.** `if boss_id in defeated: return` means `vo_boss_hype` placed after that guard fires only on the FIRST-EVER defeat of each boss — replays get silence. **Fix:** bark BEFORE the guard, or in the boss's death script (not provided); also note no caller of `mark_boss_defeated()` appears in the provided files — verify the call chain exists.

**MEDIUM — game_manager.gd:207-210 — diamond absorb runs the survive branch with zero health lost.** `take_damage` deactivates diamond and returns; health stays >0, so player.gd:387-393 executes (hurt anim, "damage" sfx — and your `vo_hurt`). Consistent with existing sfx, but get design sign-off; if "real damage only," compare `player_health` before/after gm:382.

**LOW — player.gd:550-554 — same-frame double powerup pickup.** Two overlapping "powerup" areas fire two `area_entered` signals → two `activate_power_up()` calls → double bark. Also, purple and fly route through the same funnel but aren't in the hook's major list. **Fix:** 0.5s cooldown on `vo_collect_major`; decide purple/fly inclusion.

**LOW — game_manager.gd:217 vs :233 — `player_died` conflates health-death and pit-death.** Both `take_damage()` and `lose_life()` emit it. Wiring `vo_death` to that signal double-sources it and clashes with the pit's "fall" scream (player.gd:486). **Fix:** never source `vo_death` from `player_died`.

**INFO — player.gd:483-511 — `pit_death()` is fully separate** from `take_damage`/`die()`: own scream (:486), own analytics (:489), never calls `die()`. `vo_death` should skip pits by design (a sound already plays). If a pit bark is ever wanted, its site is inside `pit_death()`.

**INFO — player.gd:380,392 — `vo_hurt` spam is already capped at 1 Hz** by the 1.0s invincibility granted at :392 and checked at :380. No extra cooldown needed.

---

## Q1 — Call sites

| Hook | Site | Notes |
|---|---|---|
| `vo_hurt` | player.gd:387-393 (else branch of `take_damage`), anchor beside :393 | Single clean funnel. Enemy `deal_damage` impls not provided — assuming they call `Player.take_damage`, this holds. |
| `vo_death` | player.gd:385-386 (killing-blow branch) — robust; or inside `die()` after :518-519 pending StateMachine check | Excludes pit by construction. |
| `vo_attack` | **None in provided files.** Required: hit-confirm in the axe / flame_projectile / fire_breath scripts (scenes at combat_handler.gd:11-13). `enemy.take_damage` is source-blind — unusable. | 3 projectile types = 3 sites unless a shared projectile base exists. |
| `vo_collect_major` | game_manager.gd:244 `activate_power_up()`, beside `play_sfx("powerup")` at :248 | Type-aware (gate to blaze/big/diamond/torch/pickaxe if purple/fly excluded). Coins/rings structurally excluded (gm:190, :195 never touch this). player.gd:553-554 is the entry point but type-blind. |
| `vo_boss_hype` | Defeat: game_manager.gd:129 `mark_boss_defeated()`, BEFORE the :131 guard (or boss death script — missing). Phase escalation: **no site in provided files** — boss scripts missing (`BossVoiceSystem` referenced at player.gd:522-525 but not provided). | Verify callers of `mark_boss_defeated` exist. |

## Q2 — Hurt vs. death

Same path, one branch point. `take_damage()` → gm:382 → health clamped (gm:212-213) → `player_health <= 0` ? `die()` (:386) : survive branch (:387-393). Exact guard: place `vo_hurt` strictly inside the `else`. Do not place it before :385 under any circumstances.

## Q3 — Spam/cooldowns (derived from code cadence)

| Hook | Risk | Cooldown |
|---|---|---|
| `vo_hurt` | Multi-hit contact: capped by existing 1.0s i-frames (:392/:380) | 0 (i-frames suffice) |
| `vo_death` | Once per death; guarded | 0 |
| `vo_attack` | **Highest.** 3-axe fan same-instant connects; fire-breath ticks (unknown); throws every 0.4s | **0.4s** (= `AXE_COOLDOWN`) |
| `vo_collect_major` | Same-frame double `area_entered` only; pickups otherwise sparse | 0.5s |
| `vo_boss_hype` | Rare by design; defeat funnel idempotent | 0 (revisit if phase-escalation source pulses — boss scripts missing) |

## Q4 — `play_voice()` collision

Not acceptable to share. Recommendation: add a dedicated `play_bark()` in AudioManager modeled on `play_sfx()` (:240-252): fire-and-forget `AudioStreamPlayer` on the SFX bus, **no music duck** (at `vo_attack` cadence, ducking = constant music pumping; during Blaze the base player is paused, making the duck tween doubly pointless), polyphonic so a `vo_attack` never cuts `vo_death`/`vo_boss_hype`, per-hook cooldown timestamps inside `play_bark()`. Resolve via existing `_resolve_audio()` against a barks subfolder. Announcer `play_voice()` stays untouched.

## Q5 — Damage-source attribution

`last_damage_source` (gm:36-39) is analytics-only; its writers (enemies/hazards) are not in the provided files. `die()` already prefers `BossVoiceSystem._active_boss_id` over it (:522-529) — that same read is available at the `vo_death` site if you want a "died to boss" variant. Pit death never reaches `die()`; it has its own scream and its own analytics (:489). Despite the gm:37 comment listing "pit", nothing provided writes `last_damage_source = "pit"` — attribution for pits is the direct `report_metric` call only. Structural recommendation: exclude pits from `vo_death`; the existing "fall" scream owns that moment.

## Missing files (blocking)

`state_machine.gd` (is_dead/change_state semantics — Finding 2); axe/flame_projectile/fire_breath scripts (vo_attack site + breath tick rate); enemy scripts (deal_damage → take_damage assumption; last_damage_source writers); boss scripts (phase-escalation site; mark_boss_defeated callers; BossVoiceSystem); powerup collectible scripts (collect() → activate_power_up confirmation). Line numbers are counted from the unnumbered paste — treat as ±1.