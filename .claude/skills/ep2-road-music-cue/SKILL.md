---
name: ep2-road-music-cue
description: Put a named song on a place in Episode 2 and make it behave - starts when the player is on the road to the auction, ducks under speech, does not restart, fades on leaving. First use - "GM OG Smoke" on the auction road. TRIGGER on "the song that should be playing", "on the way to the auction", "GM OG Smoke", "music cue", "play this track in".
argument-hint: "plan | wire | proof"
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
---

# A song for a place

Founder 2026-11-15: "The song that should be playing on the way to the auction, once Lil Blunt is on the road to the auction, should be GM OG Smoke."
Source file (founder's, Drive): "GM OG Smoke (Remastered x3).mp3", file id `15sgElxQRJG89rZweIl4k6UzzS-Ko1VYh`, ~2.3 MB. The game currently has `src/assets/music/smoke_lounge.mp3` among others; do **not** substitute a similar track.

## Steps
1. **Get the file**: download via the Drive connector into an empty directory in the scratchpad, then copy into the repo. Verify with `ffprobe` (duration, codec, bitrate) and listen to the first 10 s. Keep the original untouched.
2. **Convert and size**: Godot web builds prefer Ogg Vorbis; encode at a modest bitrate (about 96-128 kbps) and loop-check the tail. ~2 MB mp3 is already a pack-margin risk: put it in **streamed extras**, not the main pack, and run `scripts/pack-gate-fresh.sh`. Memory: the extras pck and main pack margins are tight on this branch.
3. **Find the music API**: `AudioManager` (`play_track`, `play_track_from`, `ep2-theme-song-handoff`). Register the track under an id (e.g. `gm_og_smoke`) wherever tracks are listed.
4. **Trigger by position**: arm it from the road itself (`chamber/auction_road.gd`, the road's start segment `ARRIVE_S` onward), when the player is *on* the road, not at the chamber boundary and not via E. Start on entry, crossfade in 1-2 s over whatever plays.
5. **Behavior**: ducks under speech for the whole line (`ep2-voice-duck`), does not restart if the player steps off and on, loops or ends gracefully at the porch, fades out as the auction hall takes over (the hall owns its own sound). No overlap with another track.
6. Content rules from `game-audio-forge` apply to anything new generated; this one is the founder's own song.

## Proof
- Test: entering the road sets the current track id to `gm_og_smoke` exactly once; leaving fades it; speech while on the road reduces music volume and restores it only after the last line.
- Real-renderer take with audio; if audio cannot be heard in this environment, say so and give the measured track state log.
- Report the file size, where it ships (extras), and the pack gate margin.
