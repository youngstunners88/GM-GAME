You are Kimi K3 auditing a batch of fixes for a Godot 4.3 platformer, responding
to a furious founder's "hard refresh, still broken" report. Review for
correctness/regression risk. Be skeptical.

CONTEXT: PR #36 and PR #38 were coded correctly weeks ago but sat as UNMERGED
DRAFTS — the founder's hard refresh saw the pre-fix state. Both now merged.
That part needs no review.

NEW code this session:

1. BOSS SPAWN GRACE. Real-browser captures (fresh local export, Playwright,
   two independent runs against the actual exported build) caught the player
   dying to Distributor boss-body contact within ~2s of the fight starting —
   before his first scripted action (throw_timer=2.2s). Full level restart
   each time. Fix, in full:

@include src/boss/boss_base.gd

   And in distributor.gd / claim_jumper.gd, `_on_hitbox_body_entered` now has
   this added right after the `body.is_in_group("player") and
   body.has_method("take_damage")` check, BEFORE the existing
   `GameManager.boss_contact_restart()` call:
   ```
   if is_spawn_grace_active():
       return
   ```
   IMPORTANT: neither boss calls super() in _ready() (pre-existing pattern in
   this codebase — each boss fully reimplements its own add_to_group/
   _setup_health_bar inline), so the grace timer is set in _enter_tree()
   instead, which neither boss overrides, guaranteeing it always runs.

2. NPC VO DUCKING (vault_realm.gd): Mira/Gideon's _play_vo used to build its
   own throwaway AudioStreamPlayer on "Master" bus at unity gain, no ducking.
   Now calls `AudioManager.play_voice(name)` — the SAME single-slot mechanism
   already used for the stage announcer, which does: bus="SFX",
   volume_db=6.0, and tweens current_music_player.volume_db to -14.0 while
   the line plays, restoring to 0.0 after. `name` is derived by stripping
   "res://src/assets/sounds/voice/" and the extension from the original path.

3. LEVEL 1 MUSIC: root cause of "a different song playing every time I boot"
   was AudioManager._play_next_in_playlist() picking RANDOMLY even on the
   very FIRST call of play_playlist() (candidates = full list since
   _last_track starts unset). Fix: play_playlist() now calls
   `_play_next_in_playlist(true, true)` — a new `force_first: bool = false`
   param that, when true, sets `path = _playlist[0]` instead of the random
   pick. Later auto-advances on track-finish call the function with default
   args (force_first=false) and still randomize as before.
   Also: removed level01_theme_alt.ogg entirely (founder: "remove this song
   completely" — duration-matched the founder's 3rd linked file), added
   level01_theme_oxbow.mp3 (founder's 2nd linked file) to Level 1's playlist
   array, kept level01_theme.ogg (founder's 1st linked file, duration-matched)
   as array[0].

4. BLAZE LEAF SFX (game_manager.gd activate_power_up): weed_leaf pickup
   (power_up_type "blaze") used to hijack the whole level's music via
   `AudioManager.push_music_override(...)` for its 12s duration, under a
   combined `if type == "blaze" or type == "purple":` branch. Founder: "don't
   change the music... make an awesome unique sound instead" (specifically
   about the weed leaf, shown in a screenshot). Split into:
   `if type == "blaze": AudioManager.play_sfx("blaze_ignite")` (a new
   1.1s ElevenLabs-generated one-shot SFX) `elif type == "purple":` (unchanged
   push_music_override — Purple Weed is a separate, rarer flagship power-up
   the founder did not flag).

Questions:
- Any race condition, double-free, or lifecycle bug in the spawn-grace fix
  given Godot's _enter_tree/_ready order, and GameManager.boss_contact_restart()
  being guarded by its own _boss_restart_pending flag?
- Does force_first in play_playlist correctly preserve existing behavior for
  Level 2/3 (they call play_playlist too but don't need always-first, just
  normal rotation) — confirm their callers are unaffected by the new param
  defaulting to false.
- Any concern with routing NPC VO through the single-slot play_voice() (shared
  with stage-intro/boss-intro/victory lines) — could Mira/Gideon dialogue ever
  play CONCURRENTLY with one of those and get cut off in a way that reads as a
  bug rather than "newest line wins"?
- Overall BLOCKER / NO-BLOCKER verdict per fix, concise.
