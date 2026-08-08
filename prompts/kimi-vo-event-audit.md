# Kimi K3 — action-VO event call-site audit (findings-first)

Godot 4.3 project. We are adding **Lil Blunt's own character voice** (short
onomatopoeia barks) on a small set of pronounced player actions. This is
NOT the existing announcer VO (a separate ElevenLabs voice already used for
`stage1_intro`, `boss1_intro`, etc. via `AudioManager.play_voice()`).

Your job: find the EXACT call sites where each bark should fire, and flag
every spam/double-fire/ordering trap before any code is written.

**Findings first**: SEVERITY — file:line — issue — fix. No preamble.

## The five hooks

| Hook | Intended trigger |
|------|------------------|
| `vo_hurt` | Player takes damage and SURVIVES |
| `vo_death` | Player's death / last hit — must NOT also fire `vo_hurt` |
| `vo_attack` | A thrown axe/torch **CONNECTS** with an enemy — not on button press, not on a miss |
| `vo_collect_major` | Major power-up pickup (blaze/big/diamond/torch/pickaxe) — NOT regular coins/rings |
| `vo_boss_hype` | Rare: boss phase escalation or boss defeat |

## Specific questions

1. **Exact call sites.** For each of the five hooks, give the precise
   `file:line` (or function) where the call belongs, based on the real code
   below. If a hook has NO clean single call site (e.g. attack-connect is
   handled in several places), say so and list them all.
2. **Hurt vs. death double-fire.** `Player.take_damage()` — trace whether a
   killing blow passes through the same path as a survivable hit. If a
   naive `play_bark("vo_hurt")` at the top of `take_damage()` would ALSO
   fire on the fatal hit (immediately before/with `vo_death`), state that
   and give the exact guard.
3. **Spam risk per hook.** Which of these five can fire many times per
   second in normal play? Specifically consider: multi-hit contact damage,
   the fire-breath / multi-axe spread attack (several projectiles from ONE
   input, each potentially connecting), rapid pickup chains. For each,
   recommend a concrete cooldown in seconds — derived from the actual
   cadence in the code, not guessed.
4. **Existing `play_voice()` collision.** `AudioManager.play_voice()` is
   SINGLE-SLOT: a new call `queue_free()`s the currently playing voice
   player and ducks music. If Lil Blunt's barks reuse that same path, a
   bark fired during a stage-intro or boss-intro line would CUT OFF that
   announcer line, and every bark re-triggers a music duck/restore tween.
   Is that acceptable, or does the bark need its own separate player? Give
   a concrete recommendation.
5. **Damage-source attribution.** `GameManager.last_damage_source` is set
   by several damage paths. Does anything already distinguish "died to
   boss" vs "fell in pit" in a way `vo_death` should respect (e.g. no bark
   on a pit death because a different sound already plays)?

## Files

@include src/player/player.gd
@include src/player/combat_handler.gd
@include src/autoload/audio_manager.gd
@include src/autoload/game_manager.gd
