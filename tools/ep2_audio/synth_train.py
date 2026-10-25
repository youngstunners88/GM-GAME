#!/usr/bin/env python3
"""Synthesize the Episode 2 steam train's sound (founder 2026-10-25: "Train inaudible when it passes").

The town's train (Ep2TownLife) crosses the valley at 7 m/s and had no sound at all. No train recording ships in the repo, the
ElevenLabs / VARCO keys are not on this box, and the open text-to-audio models are non-commercial, so the sound is built here from
first principles - license-clean, deterministic (fixed seeds), regenerated with one command:

    python3 tools/ep2_audio/synth_train.py            # writes the two .ogg files below (needs numpy + ffmpeg)

  town_train_run.ogg      12.0 s seamless loop: firebox rumble, exhaust chuffs (4 per driving-wheel turn), rod clank, rail-joint
                          clickety-clack of the locomotive + 3 cars, a little steam hiss.
  town_train_whistle.ogg  a three-chime steam whistle: two short toots and a long one.

Physics used (so it matches the picture): 7 m/s, 1.52 m driving wheels -> 1.47 turns/s -> 5.5 chuffs/s (66 in the loop); 12 m
rails -> a joint every 1.714 s (7 in the loop); wheelsets 2.1 m apart inside a bogie, bogies 9 m apart.
"""
from __future__ import annotations

import subprocess
import sys
import wave
from pathlib import Path

import numpy as np

SR = 44100
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "src/episode2/extras/audio/town"
LOOP_S = 12.0
SPEED = 7.0


def _noise(n: int, rng: np.random.Generator) -> np.ndarray:
    return rng.standard_normal(n).astype(np.float64)


def _onepole_lp(x: np.ndarray, cutoff: float) -> np.ndarray:
    a = np.exp(-2.0 * np.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(x.size):
        acc = (1.0 - a) * x[i] + a * acc
        y[i] = acc
    return y


def _biquad_bp(x: np.ndarray, f0: float, q: float) -> np.ndarray:
    """RBJ band-pass (constant 0 dB peak)."""
    w0 = 2.0 * np.pi * f0 / SR
    alpha = np.sin(w0) / (2.0 * q)
    b0, b1, b2 = alpha, 0.0, -alpha
    a0, a1, a2 = 1.0 + alpha, -2.0 * np.cos(w0), 1.0 - alpha
    b0, b1, b2, a1, a2 = b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0
    y = np.zeros_like(x)
    x1 = x2 = y1 = y2 = 0.0
    for i in range(x.size):
        v = b0 * x[i] + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1 = x1, x[i]
        y2, y1 = y1, v
        y[i] = v
    return y


def _place(buf: np.ndarray, grain: np.ndarray, t: float, gain: float) -> None:
    """Add `grain` at time t (seconds), wrapping around the loop end so the loop stays seamless."""
    start = int(round(t * SR)) % buf.size
    end = start + grain.size
    if end <= buf.size:
        buf[start:end] += grain * gain
    else:
        k = buf.size - start
        buf[start:] += grain[:k] * gain
        buf[: end - buf.size] += grain[k:] * gain


def _loop_bed(n: int, make, seed: int) -> np.ndarray:
    """A noise bed that loops: render n + fade samples and cross-fade the tail over the head."""
    fade = int(0.8 * SR)
    rng = np.random.default_rng(seed)
    x = make(n + fade, rng)
    w = np.linspace(0.0, 1.0, fade)
    out = x[:n].copy()
    out[:fade] = out[:fade] * w + x[n:] * (1.0 - w)
    return out


def train_run() -> np.ndarray:
    n = int(LOOP_S * SR)
    rng = np.random.default_rng(1886)
    out = np.zeros(n)
    # 1. the rumble: firebox roar + wheels on steel, brown-ish noise, slow breathing
    rumble = _loop_bed(n, lambda m, r: _onepole_lp(_onepole_lp(_noise(m, r), 160.0), 90.0), 7)
    rumble /= np.max(np.abs(rumble)) + 1e-9
    t = np.arange(n) / SR
    rumble *= 0.55 + 0.08 * np.sin(2.0 * np.pi * t / LOOP_S * 3.0)
    out += rumble * 0.55
    # 2. the exhaust chuffs: 66 in the loop (5.5/s), accent strong-weak-mid-weak, each a band-passed noise burst + a low thump
    chuffs = 66
    period = LOOP_S / chuffs
    accent = [1.0, 0.62, 0.84, 0.58]
    for k in range(chuffs):
        ln = int(0.16 * SR)
        g = _noise(ln, rng)
        g = _biquad_bp(g, 900.0 + rng.uniform(-120, 120), 0.8) + 0.5 * _biquad_bp(g, 2600.0, 1.2)
        env = np.exp(-np.arange(ln) / (0.045 * SR))
        env[: int(0.004 * SR)] *= np.linspace(0.0, 1.0, int(0.004 * SR))
        g *= env
        thump_t = np.arange(int(0.06 * SR)) / SR
        thump = np.sin(2.0 * np.pi * 58.0 * thump_t) * np.exp(-thump_t / 0.018)
        g[: thump.size] += thump * 1.6
        jitter = rng.uniform(-0.006, 0.006)
        _place(out, g, k * period + jitter, accent[k % 4] * 0.9)
    # 3. rod clank: a dull metallic tick once per driving-wheel turn (every 4 chuffs)
    for k in range(0, chuffs, 4):
        ln = int(0.05 * SR)
        tt = np.arange(ln) / SR
        tick = (np.sin(2 * np.pi * 410 * tt) + 0.6 * np.sin(2 * np.pi * 1130 * tt)) * np.exp(-tt / 0.012)
        _place(out, tick, k * period + 0.07, 0.22)
    # 4. rail joints: every 12 m (1.714 s); each wheelset clacks; loco (2 bogies) + 3 cars (2 bogies each)
    joint = 12.0 / SPEED
    joints = int(round(LOOP_S / joint))
    bogies = [0.0, 9.0, 13.0, 22.0, 26.0, 35.0, 39.0, 48.0]       # metres behind the front wheel
    for j in range(joints):
        for bi, b in enumerate(bogies):
            for axle in (0.0, 2.1):
                ln = int(0.07 * SR)
                tt = np.arange(ln) / SR
                g = _noise(ln, rng)
                g = _biquad_bp(g, 2300.0 + 300.0 * rng.standard_normal(), 2.5) * np.exp(-tt / 0.010)
                g += np.sin(2 * np.pi * (1650 + 40 * bi) * tt) * np.exp(-tt / 0.025) * 0.5
                _place(out, g, j * joint + (b + axle) / SPEED, 0.42 if bi < 2 else 0.30)
    # 5. a little steam hiss from the cylinders
    hiss = _loop_bed(n, lambda m, r: _biquad_bp(_noise(m, r), 5200.0, 0.7), 11)
    hiss /= np.max(np.abs(hiss)) + 1e-9
    out += hiss * 0.05
    return out


def whistle() -> np.ndarray:
    rng = np.random.default_rng(1887)
    notes = [370.0, 466.2, 554.4]          # F#4, Bb4, C#5: the old three-chime chord
    blasts = [(0.0, 0.32), (0.46, 0.30), (0.92, 1.55)]
    total = 3.0
    n = int(total * SR)
    out = np.zeros(n)
    t = np.arange(n) / SR
    vib = 1.0 + 0.004 * np.sin(2 * np.pi * 5.2 * t)
    for start, dur in blasts:
        env = np.zeros(n)
        a, r = 0.06, 0.22
        i0, i1 = int(start * SR), int((start + dur) * SR)
        i1r = min(n, i1 + int(r * SR))
        env[i0:i1] = 1.0
        ramp = int(a * SR)
        env[i0:i0 + ramp] = np.linspace(0, 1, ramp) ** 1.5
        env[i1:i1r] = np.linspace(1, 0, i1r - i1) ** 2
        glide = 1.0 - 0.04 * np.exp(-np.clip(t - start, 0, None) / 0.05) * (t >= start)
        for f in notes:
            phase = np.cumsum(2 * np.pi * f * vib * glide / SR)
            tone = np.sin(phase) + 0.35 * np.sin(2 * phase) + 0.12 * np.sin(3 * phase)
            out += tone * env * 0.28
        breath = _biquad_bp(_noise(n, rng), 1800.0, 0.9) * env * 0.12
        out += breath
    return out


def _write(name: str, x: np.ndarray, drive: float = 1.0) -> Path:
    x = x / (np.max(np.abs(x)) + 1e-9)
    if drive > 1.0:
        # stateless tanh saturation: tames the clack/thump peaks so the bed can sit at -16 LUFS (and the loop seam stays exact)
        x = np.tanh(x * drive) / np.tanh(drive)
    x = x * 0.89
    wav = OUT / (name + ".wav")
    with wave.open(str(wav), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767.0).astype("<i2").tobytes())
    ogg = OUT / (name + ".ogg")
    # loudness: the run sits at -16 LUFS (the town theme's level), the whistle a little hotter. ONE fixed gain (not loudnorm's
    # time-varying one, which would break the loop seam), capped so the true peak stays <= -1 dBTP.
    target = -16.0 if name == "town_train_run" else -14.0
    lufs, peak = _measure(wav)
    gain = min(target - lufs, -1.0 - peak)
    subprocess.run(["ffmpeg", "-y", "-hide_banner", "-loglevel", "error", "-i", str(wav), "-af", f"volume={gain:.2f}dB",
                    "-ar", str(SR), "-ac", "1", "-c:a", "libvorbis", "-q:a", "4", str(ogg)], check=True)
    wav.unlink()
    got, got_peak = _measure(ogg)
    print(f"  {name}: {got:.1f} LUFS, true peak {got_peak:.1f} dBTP (gain {gain:+.1f} dB)")
    return ogg


def _measure(path: Path) -> tuple[float, float]:
    r = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", str(path), "-af", "ebur128=peak=true", "-f", "null", "-"],
                       capture_output=True, text=True)
    lufs = peak = 0.0
    for line in r.stderr.splitlines():
        line = line.strip()
        if line.startswith("I:"):
            lufs = float(line.split()[1])
        elif line.startswith("Peak:"):
            peak = float(line.split()[1])
    return lufs, peak


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, fn, drive in (("town_train_run", train_run, 5.0), ("town_train_whistle", whistle, 1.0)):
        p = _write(name, fn(), drive)
        print(f"{p.relative_to(ROOT)}  {p.stat().st_size} B")
    return 0


if __name__ == "__main__":
    sys.exit(main())
