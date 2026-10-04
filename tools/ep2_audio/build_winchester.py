#!/usr/bin/env python3
"""Build the first-person Winchester sounds from ElevenLabs takes (skill ep2-winchester-sound).

Founder 2026-10-04: "the sound of the winchester is horrid!!! it needs to sound dangerous ... not like a toy".
The old samples were revolver prompts, 1.2 s and dry: two were 98 % thump below 150 Hz with no crack, one was all
crack with no body. A rifle that reads as dangerous needs all three: a broadband CRACK at the onset, a heavy BODY
below 150 Hz, and a long cavern ECHO tail (1.5 s+).

Recipe per variant: main take (crack + body) + a second take's rumble as the echo layer at -10..-12 dB, both trimmed to
their onset, plus a high-passed CRACK transient (first 90 ms of a crack-heavy take); +3 dB presence shelf at 2.5 kHz for the crack, compressor, limiter, peak-normalised to -1 dBFS.
  python3 tools/ep2_audio/build_winchester.py .farm/winchester   (takes from scratchpad gen; see the skill)
"""
import subprocess, sys
from pathlib import Path
import numpy as np

SRC = Path(sys.argv[1] if len(sys.argv) > 1 else ".farm/winchester")
OUT = Path("src/assets/sounds")
VARIANTS = {   # out id: (main take, echo take, echo gain dB)
    "ep2_winchester_shot_1": ("ep2_winchester_shot_2_t1", "ep2_winchester_shot_3_t1", -12.0),
    "ep2_winchester_shot_2": ("ep2_winchester_shot_2_t0", "ep2_winchester_shot_3_t0", -12.0),
    "ep2_winchester_shot_3": ("ep2_winchester_shot_2_t1", "ep2_winchester_shot_3_t0", -10.0),
}
SR = 44100


def load(p: Path) -> np.ndarray:
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", str(p), "-ac", "1", "-ar", str(SR), "-f", "f32le", "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.float32).copy()


def onset(x: np.ndarray) -> int:
    """First sample within 20 dB of the peak, minus 3 ms of lead-in."""
    a = np.abs(x)
    return max(int(np.argmax(a > a.max() * 0.1)) - int(0.003 * SR), 0)


def save(x: np.ndarray, out: Path, chain: str) -> None:
    tmp = out.with_suffix(".f32")
    tmp.write_bytes(x.astype(np.float32).tobytes())
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(SR), "-ac", "1", "-i", str(tmp),
                    "-af", chain, "-ac", "2", "-b:a", "160k", str(out)], check=True)
    tmp.unlink()
    # peak-normalise to -1 dBFS in a second pass (measured, not guessed)
    det = subprocess.run(["ffmpeg", "-hide_banner", "-i", str(out), "-af", "volumedetect", "-f", "null", "-"],
                         capture_output=True, text=True).stderr
    mx = float(det.split("max_volume:")[1].split("dB")[0])
    fixed = out.with_name(out.stem + "_n.mp3")
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(out), "-af", f"volume={-1.0 - mx:.2f}dB",
                    "-b:a", "160k", str(fixed)], check=True)
    fixed.replace(out)


# No compressor: the takes arrive already squashed (RMS -6 dB) and compressing again made a flat 600 ms wall of
# noise with no punch. Instead the body is SHAPED (full for 60 ms, then e^-t/0.5 s), the crack sits on top, and a
# limiter only catches the crack's first milliseconds.
SHOT_CHAIN = "highshelf=f=2500:g=3,alimiter=limit=0.92:attack=0.5:release=40,afade=t=out:st=2.3:d=0.45"
def crack_layer() -> np.ndarray:
    """The supersonic CRACK: the first 90 ms of the crack-heavy take, high-passed at 1.6 kHz (one-pole x4),
    exponentially decayed, at 0 dB (it IS the peak). This is what makes it snap like a rifle instead of thud like a toy."""
    c = load(SRC / "ep2_winchester_shot_1_t0.mp3")
    c = c[onset(c):onset(c) + int(0.09 * SR)].astype(np.float64)
    k = np.exp(-2.0 * np.pi * 1600.0 / SR)
    for _ in range(4):
        y = np.zeros_like(c); prev_x = prev_y = 0.0
        for i, v in enumerate(c):
            prev_y = k * (prev_y + v - prev_x); prev_x = v; y[i] = prev_y
        c = y
    c *= np.exp(-np.arange(len(c)) / (0.025 * SR))
    c /= max(np.abs(c).max(), 1e-9)
    return c.astype(np.float32)


CRACK = crack_layer()
for vid, (main, echo, gain) in VARIANTS.items():
    m = load(SRC / f"{main}.mp3"); m = m[onset(m):]
    e = load(SRC / f"{echo}.mp3"); e = e[onset(e):]
    n = min(int(2.75 * SR), max(len(m), len(e)))
    mix = np.zeros(n, np.float32)
    t = np.arange(n) / SR
    shape = np.exp(-np.maximum(t - 0.06, 0.0) / 0.5)
    mix[:min(n, len(m))] += m[:n] / max(np.abs(m).max(), 1e-9) * shape[:len(m[:n])] * 0.7
    mix[:min(n, len(e))] += e[:n] / max(np.abs(e).max(), 1e-9) * (10 ** (gain / 20.0))
    mix[:len(CRACK)] += CRACK
    mix /= max(np.abs(mix).max(), 1e-9)
    save(mix, OUT / f"{vid}.mp3", SHOT_CHAIN)
    print("built", vid)

lever = load(SRC / "ep2_winchester_lever_t0.mp3")
a = np.abs(lever)
start = max(int(np.argmax(a > a.max() * 0.05)) - int(0.01 * SR), 0)
save(lever[start:start + int(0.75 * SR)], OUT / "ep2_winchester_lever.mp3",
     "lowshelf=f=200:g=3,afade=t=out:st=0.6:d=0.15")
print("built ep2_winchester_lever")
