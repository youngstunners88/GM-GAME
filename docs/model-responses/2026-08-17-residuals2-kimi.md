<!-- dispatched: moonshotai/kimi-k3
     prompt: prompts/residuals2-kimi.md
     files inlined: 3
     tokens: 23736 in / 12009 out
     cost: $0.2513
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
# Audit — Session Fixes

## 1. Boss Spawn Grace — code is sound; the "FIXED" claim is not yet supported

**What's verifiably correct in the provided files:**
- Lifecycle ordering is right. `_enter_tree()` fires before `_ready()`, the `hitbox.body_entered` connection happens in `_ready()`, so `_spawn_grace_until_msec` is always set before any contact callback can fire. No path reads it uninitialized (and the `0` default fails to pre-fix behavior, not to a crash).
- No double-free/lifecycle risk: the grace state is a plain `int`, nothing to clean up. `_exit_tree()` is untouched.
- Interaction with `_boss_restart_pending`: no conflict. Grace filters by time window at the call site; the pending guard dedupes restarts inside GameManager. They're orthogonal. Caveat: `game_manager.gd` was not provided, so I'm taking `_boss_restart_pending`'s existence from your question, not from code I've read.
- Known limitation (acceptable): `body_entered` fires once on entry. A player who enters the hitbox at t=0.5s and stays overlapped past t=1.2s is never restarted. Given `HOVER_CLEARANCE=130` / `PULL_FLOOR_MARGIN=72` make sustained overlap structurally unlikely, this is fine — but it's a swallowed-contact window, not a contact cooldown.

**Three gaps that must close before anyone says "FIXED" to the founder:**

1. **`EnemyBase._enter_tree()` is unverified — and this fix's own rationale indicts it.** The comment correctly observes that bosses override `_ready()` without `super()`, so base-class logic must live in a hook nobody shadows. BossBase has now done exactly that to EnemyBase: if `enemy_base.gd` defines `_enter_tree()`, `BossBase._enter_tree()` shadows it **for every boss in the game** and doesn't call `super()`. That would be the same bug class this fix describes, introduced by this fix. `enemy_base.gd` was not provided — this is a required check, not a nicety.

2. **The grace anchors to tree entry, not fight start.** The comment says "after the boss enters the fight"; the code implements "after the boss enters the tree." These are only equivalent if the Distributor is instanced at fight trigger. Internal evidence supports that (`_ready()` reads Web3Bridge balances "at fight start" and builds the health bar — a bar visible from level load would have been reported long ago), but the stage-2 spawn/trigger script was not provided. **If the boss rides in the level scene from load, this entire fix is a no-op and the founder's next refresh says "still broken" for the third time.** Verify the spawn path before claiming anything.

3. **The 1.2s number looks guessed against your own evidence.** The captures say death "within ~2s"; grace covers `< 1.2s`. If either captured death timestamp lands in [1.2s, 2.2s), this fix does not cover it. You have Playwright captures with timestamps — check them. If any death is past 1.2s, either extend the window or tie grace end to the boss's first scripted action (`throw_timer=2.2s`) rather than a flat constant.

Also: grace is **opt-in per boss contact handler**. `distributor.gd` opts in (verified). `claim_jumper.gd` was described as modified but not provided — unverified. `auditor.gd` (Stage 1) was never mentioned — if it has the same contact-restart pattern and doesn't check `is_spawn_grace_active()`, the identical spawn-kill survives on Stage 1. And per this repo's own stated standard ("claim FIXED only with capture," per the T6 comment in this very file), there is no post-fix capture in evidence here.

**Verdict: NO-BLOCKER on the code as written (worst case is a no-op, unless gap 1 is real, in which case it's a bosses-wide regression). BLOCKER on shipping a "FIXED" claim until gaps 1–3 and the claim_jumper/auditor opt-ins are verified and a post-fix capture exists.**

## 2. NPC VO Ducking — `play_voice()` itself is race-safe; the call site is the risk

**In the provided code:**
- No double-free. A replaced player's `finished` never fires (queue_free doesn't emit it), the connection dies with the node, and `_on_voice_finished` only ever runs for the live `_voice_player`. Null-then-recreate ordering is safe in both interleavings.
- Duck/restore composition across rapid lines is correct: A ducked → B replaces A → no spurious restore (A's finish never fires) → B's finish restores once. Music stays ducked for the whole exchange. Good.
- Cosmetic-only wrinkle: if a line starts during `play_playlist`'s 1s fade-in (exactly when a scene-entry NPC greeting fires), the duck tween and fade-in tween fight over `volume_db` on the same player. The fade-in wins after ~0.2s and the duck is partially defeated. Self-corrects, the +6dB still carries the line. Not a blocker.
- Pre-existing gap now more visible: `_override_player` (Blaze music) is never ducked — only `current_music_player` is. VO during Blaze mode competes with full-volume override music. Was already true for the announcer; NPC lines make it more frequent.

**The concurrency answer:** single-slot means newest-wins, so yes — an NPC line will hard-cut an in-flight stage-intro/victory line and vice versa, and **Mira and Gideon will cut each other off** if an exchange fires lines without awaiting the previous one's finish. Whether any of that actually happens depends on two files not provided:
- `src/level/vault_realm.gd` — is dialogue sequential with awaits, or fired back-to-back? If the latter, truncated exchanges will read as a bug, not "newest wins."
- `boss_voice_system.gd` — if `BossVoiceSystem.say()` routes through `play_voice()`, boss barks share the slot with NPC lines (structurally unlikely to collide if the vault has no bosses, but unverified).

One silent-failure mode worth stating: `play_voice()` resolves only under `res://src/assets/sounds/voice/` and **silently no-ops on a missing file**. If the old NPC `_play_vo` loaded from a different directory or with different ids, this change ships as *no NPC VO at all* with zero errors. Confirm the assets resolve in the export.

**Verdict: NO-BLOCKER, conditional on vault_realm.gd showing awaited/sequential dialogue and correct VO ids.**

## 3. `force_first` — mechanism correct; the "callers unaffected" claim is inaccurate

Rotation behavior after the first track is verifiably unchanged: `_on_music_track_finished()` calls `_play_next_in_playlist()` with defaults, so auto-advance still randomizes with no-repeat filtering, `_last_track` is set correctly after a forced first, and single-track playlists behave as before.

But: `play_playlist()` hardcodes `_play_next_in_playlist(true, true)` for **every caller**. Level 2, Level 3, and every boss arena (per the comment, bosses use the same two-song shuffle model) now open on their playlist's first track deterministically — previously random, and previously a retry after a boss-contact restart could open on the other track. That's a global behavior change, not "Levels 2/3 unaffected." It's low-risk and arguably an improvement (consistent level identity), but if the founder only mandated determinism for Level 1, the honest implementation is a `force_first: bool = false` parameter on `play_playlist()` passed `true` only by `level_01_smoke_realm.gd`. Minor: the comment says "always paths[0]" but it's actually `found[0]` — first *existing* track after the ResourceLoader filter. `level_01_smoke_realm.gd` was not provided, so I can't confirm the oxbow track is actually first in the array.

**Verdict: NO-BLOCKER. Recommend scoping the parameter; correct the comment.**

## 4. Blaze Leaf SFX — unverifiable from provided files, but the safety nets check out

`game_manager.gd` was not provided, so the core claim ("no longer calls `push_music_override`") can't be audited. What I can confirm from `audio_manager.gd`:
- A leftover 12s timer calling `release_music_override(stale_token)` is harmless — the monotonic token no-ops it, even if Purple Weed pushed an override in the meantime. The token design does its job.
- `play_sfx("blaze_ignite")` silently no-ops if the asset is missing from the pck. The founder asked for "an awesome unique sound" — if `blaze_ignite.{ogg,mp3}` isn't in the export, this fix ships as *a silent pickup*, which is exactly the kind of "FIXED" that gets rejected. Confirm the file ships.

**Verdict: NO-BLOCKER, pending the game_manager.gd diff and asset presence in the export.**

---

## Summary

| Fix | Code verdict | Ship-claim verdict |
|---|---|---|
| 1. Spawn grace | Sound as written | **BLOCKED** — verify `EnemyBase._enter_tree`, boss spawn timing, claim_jumper/auditor opt-in, death timestamps vs 1.2s, post-fix capture |
| 2. NPC VO | Race-safe | NO-BLOCKER pending vault_realm.gd call-site review |
| 3. force_first | Correct, but globally scoped | NO-BLOCKER — "L2/L3 unaffected" claim is wrong; scope it or own the change |
| 4. Blaze SFX | Unverifiable here | NO-BLOCKER pending diff + asset-in-pck confirmation |

**Missing files needed to close this audit:** `enemy_base.gd`, the Level 2 boss spawn/trigger script, `claim_jumper.gd`, `auditor.gd`, `vault_realm.gd`, `boss_voice_system.gd`, `game_manager.gd`, `level_01_smoke_realm.gd`.

The pattern to watch: fixes 1 and 4 both degrade *silently* in their failure modes (expired grace window, missing audio asset). Given the founder's history with false "FIXED" claims, those two specifically need positive evidence — a capture and an asset check — not absence-of-error.