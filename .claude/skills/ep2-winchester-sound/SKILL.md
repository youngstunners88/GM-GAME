---
name: ep2-winchester-sound
description: Make the Episode 2 first-person Winchester sound heavy and DANGEROUS (never a toy) - crack + body + cavern echo, measured, layered, on its own pool, with the lever rack after each shot. TRIGGER on "the winchester / rifle sounds horrid / like a toy / weak / thin / not dangerous", any edit to WINCHESTER_* in smelting_facility.gd, ep2_winchester_*.mp3, tools/ep2_audio/build_winchester.py, or a new long gun anywhere in the game.
---
# Why (founder 2026-10-04)
"The sound of the winchester is horrid!!! it needs to sound dangerous for goodness sake not like a toy." The hideout
rifle was firing the RUNNER's revolver samples (`ep2_gun_fire_1..3`, 1.2 s, generated from revolver prompts) through
`play_sfx` at 0 dB. Measured: two were 98 % energy below 150 Hz with no crack (a thud), one was all crack and no body
(a cap gun). None had an echo tail. A big-bore rifle in a cavern needs all three layers.

# The three layers, and how to measure them (not by ear alone)
| layer | what | measured target |
|---|---|---|
| CRACK | broadband transient, first 20-50 ms | the sample's PEAK sits in the first 20 ms; > 2 kHz share of the first 50 ms >= 0.10 |
| BODY | the boom, < 150 Hz | low<150 share of the first 0.5 s >= 0.6; -4..-8 dB re peak through 0.4 s |
| ECHO | rolling cavern tail | above -35 dB re peak for >= 2.0 s |
Envelope check (dB re peak at 0, .04, .1, .2, .4, .6, 1.0, 1.5, 2.0 s) shipped: `0 -4 -4 -6 -8 -11 -17 -22 -18`.
A FLAT `0 0 0 0 0 0` over 600 ms means a compressor/limiter turned it into a wall of noise with no punch: the
ElevenLabs takes arrive pre-squashed (RMS -6 dB), so NEVER compress them again; shape the body with an envelope.

# Pipeline
1. Prompts live in `assets/audio-manifest.json` (`ep2_winchester_shot_1..3`, `ep2_winchester_lever`, 2.8 s / 1.0 s,
   `prompt_influence` 0.6). Name the gun, the cartridge (.45-70), the room (wooden mine cavern), and "dangerous,
   realistic, no music". Generate 2 takes each into `.farm/winchester/` with a small script that calls
   `generate_audio.post()` for those ids only (the full generator also re-creates missing film voices into src).
2. Pick by measurement: the take with a vertical broadband line at the onset in a spectrogram is the CRACK+BODY main;
   a rumble-heavy take with a long decay is the ECHO layer.
3. `python3 tools/ep2_audio/build_winchester.py .farm/winchester` trims each take to its onset, shapes the body
   (full 60 ms, then e^-t/0.5 s), adds the echo at -10..-12 dB, adds a high-passed (1.6 kHz) 90 ms CRACK from the
   crack-heavy take as the peak, +3 dB shelf at 2.5 kHz, a limiter that only catches the crack, then peak-normalises
   to -1 dBFS (`volumedetect`, two-pass).
4. Wiring (`smelting_facility.gd`): `_play_winchester()` round-robins three `AudioStreamPlayer`s at
   `WINCHESTER_DB` (+4) with 0.96-1.03 pitch, so a quick second shot never cuts the first one's echo; the lever
   (`WINCHESTER_LEVER`) racks `WINCHESTER_LEVER_DELAY` (0.38 s) later from the facility's own clock.
   The runner's revolver keeps `ep2_gun_fire_*` / `ep2_revolver_blast_*` - different gun, different sound.

# Gate
`tests/ep2_hideout_corrections_test.tscn` (samples present, >= 2.0 s tails, pool round-robin, lever after the shot).
Re-run the envelope/low-share measurement whenever a sample changes; paste the numbers in the commit.
# Never
Reuse a pistol sample for a long gun; ship a gun sound you only checked exists; compress an already-loud take;
play a 2.75 s sample through one shared player (the next shot chops the echo).
