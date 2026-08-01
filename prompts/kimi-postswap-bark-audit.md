# Kimi K3 — post-voice-swap bark path re-verification (findings-first)

Context: Lil Blunt's 5 action barks were just regenerated against the real
custom voice (the audio FILES changed; no code changed in this swap). You
previously audited this bark system and caught a real bug (a vo_death bark
placed inside `Player.die()` was dead code because
`GameManager.take_damage()` transitions to GAME_OVER *before* `die()` runs,
so `die()`'s `if StateMachine.is_dead(): return` guard fires first). That
fix was applied — vo_death now sits on the killing-blow branch inside
`take_damage()`.

Re-verify, against the CURRENT code inlined below:

1. **vo_death still fires.** Confirm the current placement actually runs on
   a normal health death, and that it cannot ALSO fire from `pit_death()`
   in the same sequence in a way that double-plays (note the 5.0s per-id
   cooldown in `play_bark`).
2. **vo_hurt cannot fire on the fatal hit** (must be else-branch only).
3. **Attack cooldown vs clip length.** `vo_attack` cooldown is 3.0s and the
   regenerated clip is ~1.2s. Confirm 3.0s cannot cause self-interruption,
   and that all three hit paths (axe / flame_projectile / fire_breath)
   share the same id so one cooldown governs them collectively.
4. **`play_bark` correctness**: per-id cooldown map, silent no-op on
   missing file, no music ducking, no interference with `play_voice()`'s
   announcer player, and no node leak (it replaces `_bark_player` and also
   connects `finished` to `queue_free` — confirm that pair cannot
   double-free or leave a dangling reference).
5. **Companion reachability**: confirm `_on_talk_pressed` in
   `pause_menu.gd` is connected from BOTH `level_base.gd` and
   `secret_realm.gd`, and that `main_menu.gd` also exposes it, so the panel
   is reachable even if the pause key misbehaves on some platform.

Findings-first: SEVERITY — file:line — issue — fix. If everything is clean,
say so plainly and briefly; do not invent findings.

## Files
@include src/autoload/audio_manager.gd
@include src/player/player.gd
@include src/ui/pause_menu.gd
@include src/ui/companion_panel.gd
