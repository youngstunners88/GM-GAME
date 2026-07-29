# Evidence — A. Exclusive Blaze Mode Audio

## Root cause
`GameManager.activate_power_up("blaze")` called `AudioManager.play_sfx("fresh_boost")`,
spawning a NEW AudioStreamPlayer on the SFX bus while the level music kept
playing on the Music bus — the two overlapped ("mesh of noise"). `fresh_boost.ogg`
is a 1.5 MB full-length stinger, so the overlap was egregious.

## Fix
Added a central, token-guarded music-override API to `src/autoload/audio_manager.gd`:
`push_music_override(path)` saves + PAUSES the base track (position preserved),
plays Blaze music EXCLUSIVELY on the Music bus, returns a monotonic token;
`release_music_override(token)` resumes the base track once — stale tokens
no-op, so a scene change / death / second pickup can't revive an old track.
`play_playlist` calls `_drop_override_for_new_music()` so a level/boss music
change supersedes an active override. GameManager routes blaze/purple activate
→ push, deactivate + reset_level + reset_session → release. AudioManager remains
the SOLE owner of every music player (no new uncontrolled players).

## Verification
- CODE INSPECTION: only `current_music_player` OR `_override_player` is audible
  on the Music bus at a time; base is `stream_paused=true`, not layered.
- REAL EXPORT: game boots to PLAYING in the local Godot 4.3 web export (see
  gameplay-boot-after-corrections.png) with no audio errors in console.
- Edge cases covered in code: rapid 2nd pickup (token bump), scene change
  (release rebuilds from saved context or no-ops), missing asset (push still
  returns a token, base untouched), boss transition (play_playlist drops
  override). SFX/VO unchanged (separate bus, separate players).
- PASS (code + boot). Remaining: a by-ear human playtest is the final
  confirmation of "only Blaze audible" — steps in the final report.
