<!-- dispatched: moonshotai/kimi-k3
     prompt: prompts/kimi-postswap-bark-audit.md
     files inlined: 4
     tokens: 14539 in / 21155 out
     cost: $0.3609
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
# Bark re-verification — findings

## Findings

**HIGH (soft-lock on platforms without a pause key; MEDIUM elsewhere) — companion_panel.gd:60-62 + pause_menu.gd:39-41 — closing the companion never re-shows the pause menu.** `close()` does `visible = false` and `get_tree().paused = false` but never frees the panel, so `tree_exited` never fires and the re-show callback connected at pause_menu.gd:39 never runs. End state after closing: StateMachine is still PAUSED (so `player.gd:93` keeps gameplay gated off), the tree is unpaused, and the pause menu is hidden. Only recovery is `ui_cancel` (pause_menu.gd:11-16) — a soft-lock exactly on the "pause key misbehaves" platforms item 5 worries about. Same bug leaks one invisible panel per Talk open (pause_menu.gd:33 instantiates fresh every click; old ones are never freed). **Fix:** `close()` should `queue_free()` the panel so `tree_exited` fires, and stop force-unpausing on return-to-menu — either let the opener own pause state, or re-assert `get_tree().paused = true` inside the pause_menu.gd:39 callback when `StateMachine.is_paused()`.

**UNVERIFIED — item 3 (attack bark call sites): required files not provided.** No `vo_attack` call exists anywhere in the four provided files — player.gd contains no axe, flame_projectile, or fire_breath code. I cannot confirm the shared id or the 3.0s value. Needed: the three scripts implementing those hit paths. What I *can* confirm at the mechanism level: **if** all three call `play_bark("vo_attack", 3.0)`, the shared id means one entry in `_bark_last_played` governs them collectively (audio_manager.gd:306-309), and 3.0s cooldown > ~1.2s clip means a same-id retrigger can only pass after the clip finished — no self-interruption via the single-slot replacement at :319-321. Note cross-id preemption is possible by design: one `_bark_player` slot, so vo_hurt/vo_death can cut an attack bark mid-clip ("newest replaces old", comment at :289-291).

**UNVERIFIED — item 5 (connections): required files not provided.** `_on_talk_pressed` exists at pause_menu.gd:32 and its body is sound, but the button→handler connection lives in pause_menu.tscn, and level_base.gd, secret_realm.gd, and main_menu.gd were not provided. I cannot confirm either level connects it or that main_menu exposes it. Needed: those four files.

## Verified clean

1. **vo_death fires; no double-play.** Fires at player.gd:382 on the killing-blow branch — the bark call has no state guard, so the GAME_OVER transition inside `GameManager.take_damage()` (per prior audit; GameManager.gd not re-provided) can't block it. Fires once: later `take_damage()` calls hit the `is_playing()` guard at :371. `pit_death()` (:490) uses the same id `"vo_death"` with the same 5.0s cooldown, so a pit-then-real-death sequence within 5s is absorbed at audio_manager.gd:306-309; `pit_death`'s own `is_dead()` guard (:484) covers the reverse order. By-design tradeoff, not a defect: a health death within 5s of a pit bark plays no vo_death (documented at player.gd:487-489).
2. **vo_hurt is else-branch only** (:393). Separate per-id cooldown keys also mean a recent vo_hurt can never suppress vo_death.
4. **`play_bark` is correct.** Per-id map (:296, :306-309); silent no-op on missing/unloadable file (:311-315); cooldown stamped only after successful load (:318); never touches `current_music_player` or `_voice_player`. No double-free/dangling ref: the `finished → queue_free` callable (:327) binds to the specific instance at connect time, so an old node's `finished` cannot free the new node; the old node is `queue_free`'d before the reference is rebound (:319-321); and repeated `queue_free` within a frame is a safe no-op. Bounded at one live node — finish or replacement always frees it.

Net: bark path itself is clean against the current code. The one real defect is in the companion-panel close path, and two of your five items need files that weren't included to sign off on.