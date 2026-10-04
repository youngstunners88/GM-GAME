#!/usr/bin/env python3
"""Lift the quiet DIALOGUE of the founder's film without touching its music (skill ep2-film-loudness).

Founder 2026-10-04: "make the volume of the video louder". Measured: the film's integrated loudness is -16 LUFS
and it peaks at 0 dBFS, so a plain gain boost clips. The problem is the DIALOGUE: seconds 6-25 sit at -25..-35 LUFS
(Bull and Lil Blunt talking) while the music and effects sit at -13..-17. The fix is a gain RIDE, not a boost:
  * short-term level every 100 ms (400 ms window), gain = target - level, clamped to [0, MAX_UP_DB],
  * fast attack (down) / slow release (up) smoothing so it never pumps,
  * applied only before SONG_START and faded out by SONG_FULL, so the stage theme in the film keeps its exact
    level and character (the game continues that theme from the same position; skill ep2-theme-song-handoff),
  * a final limiter (alimiter) so nothing clips.
  python3 tools/ep2_audio/loudify_film.py in.wav out.wav
"""
import sys
import numpy as np
import scipy.io.wavfile as w

TARGET_LUFS = -9.0   # founder round 2: louder still       # where the dialogue should sit (the film's own loud parts are -13..-17; speech must lead)
MAX_UP_DB = 24.0
GATE_LUFS = -50.0         # below this it is silence/room tone: do not ride noise up
SONG_START, SONG_FULL = 25.0, 27.0
HOP, WIN = 0.1, 0.4

sr, x = w.read(sys.argv[1])
x = x.astype(np.float64) / (32768.0 if x.dtype == np.int16 else 1.0)
n = len(x)
mono = x.mean(1) if x.ndim > 1 else x
hop, win = int(HOP * sr), int(WIN * sr)
centres, levels = [], []
for i in range(0, n - win, hop):
    seg = mono[i:i + win]
    rms = np.sqrt(np.mean(seg ** 2)) + 1e-9
    levels.append(20 * np.log10(rms) + 3.0)          # approximate LUFS offset for speech
    centres.append((i + win / 2) / sr)
levels = np.array(levels)
gain = np.clip(TARGET_LUFS - levels, 0.0, MAX_UP_DB)
gain[levels < GATE_LUFS] = 0.0
# smooth: release (gain going up) slow, attack (gain going down) fast
sm = np.zeros_like(gain)
for k in range(len(gain)):
    prev = sm[k - 1] if k else 0.0
    a = 0.7 if gain[k] < prev else 0.35
    sm[k] = prev + (gain[k] - prev) * a
t_s = np.arange(n) / sr
g_t = np.interp(t_s, centres, sm)
fade = np.clip((SONG_FULL - t_s) / (SONG_FULL - SONG_START), 0.0, 1.0)   # 1 before the song, 0 once it is full
g_lin = 10 ** (g_t * fade / 20.0)
y = x * (g_lin[:, None] if x.ndim > 1 else g_lin)
# (the ffmpeg alimiter pass after this script is the ceiling; the int16 clip below only guards overflow)
w.write(sys.argv[2], sr, (np.clip(y, -1, 1) * 32767).astype(np.int16))
print("max gain %.1f dB; mean gain before song %.1f dB" % (sm.max(), sm[np.array(centres) < SONG_START].mean()))
