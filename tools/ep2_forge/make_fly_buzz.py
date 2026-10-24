"""Synthesise the jail privy's fly buzz as a seamless 2 s loop (skill ep2-jail-privy).

    uv run --with numpy python3 tools/ep2_forge/make_fly_buzz.py --out src/episode2/extras/jail/fly_buzz.wav

Three house flies: each a wing-beat tone (190-240 Hz, a sawtooth-like stack of six harmonics) whose pitch wobbles as it turns and
whose loudness swells as it passes close and away, over a thin bed of wing hiss. Every frequency is a whole number of cycles in the
loop and every wobble integrates to zero, so the loop has no click at its seam. 22.05 kHz mono 16-bit, about 88 KB.
"""
import argparse
import wave

import numpy as np

SR = 22050
LOOP = 2.0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    n = int(SR * LOOP)
    t = np.arange(n) / SR
    rng = np.random.default_rng(7)
    out = np.zeros(n)
    # (base Hz, pitch-wobble Hz, wobble depth, swell Hz, phase) - all multiples of 1/LOOP so the loop closes
    flies = [(196.0, 3.0, 0.07, 0.5, 0.0), (221.5, 5.0, 0.05, 1.0, 1.7), (238.0, 4.0, 0.06, 1.5, 3.1)]
    for f0, fw, depth, sw, ph in flies:
        # instantaneous phase of a tone whose frequency is f0 * (1 + depth sin(2 pi fw t)): the sin integrates to zero over the loop
        phase = 2 * np.pi * f0 * t - (f0 * depth / fw) * np.cos(2 * np.pi * fw * t + ph) + (f0 * depth / fw)
        tone = sum(np.sin(k * phase) / k ** 1.15 for k in range(1, 7))
        swell = 0.35 + 0.65 * (0.5 + 0.5 * np.sin(2 * np.pi * sw * t + ph)) ** 1.6
        out += tone * swell
    hiss = rng.normal(0, 1, n)
    hiss = np.convolve(hiss, np.ones(6) / 6, mode="same")          # soft: the air off the wings, not static
    out += hiss * 0.18
    out /= np.max(np.abs(out)) * 1.05
    pcm = (out * 32767 * 0.8).astype("<i2")
    with wave.open(a.out, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print("@@", a.out, n, "samples")


if __name__ == "__main__":
    main()
