#!/usr/bin/env python3
"""Synthesize the Episode 2 wildlife and stampede layers (founder residual 2026-11-05).

The trail's vultures had no voice at all, and the buffalo herd reused one low-pitched horse-hoof loop. No wildlife recording ships
in the repo and the ElevenLabs / text-to-audio keys are not on this box, so the layers are built here from first principles -
license-clean, deterministic (fixed seeds), regenerated with one command:

    python3 tools/ep2_audio/synth_wildlife.py       # needs numpy + ffmpeg

  vulture_wings.ogg       6.0 s seamless loop: air over a spread wing, a slow soft downbeat, no cartoon screech.
  vulture_cry.ogg         1.4 s one-shot: the turkey vulture's hiss/rasp, low and breathy.
  stampede_rumble.ogg     8.0 s seamless loop: ground and chest, 30-70 Hz, slow breathing.
  stampede_hooves.ogg     8.0 s seamless loop: many hooves at ~1.2 strikes each per second, near and far bodies.
  stampede_pass.ogg       4.2 s one-shot: the herd arrives, passes close, and thins out behind.
  bison_hit.ogg           0.8 s one-shot: a heavy, wet body hit, not a wooden knock.

The trail room fades the rumble and hooves up as the herd closes and plays the pass-by once, under the music rather than in place
of it. Every path has a code fallback, so a pack that has not mounted yet is quiet, never broken.
"""
from __future__ import annotations

import subprocess
import sys
import wave
from pathlib import Path

import numpy as np

SR = 44100
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "src/episode2/extras/audio/trail"


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
    w0 = 2.0 * np.pi * f0 / SR
    alpha = np.sin(w0) / (2.0 * q)
    b0, b1, b2 = alpha, 0.0, -alpha
    a0, a1, a2 = 1.0 + alpha, -2.0 * np.cos(w0), 1.0 - alpha
    b0, b1, b2, a1, a2 = b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0
    y = np.empty_like(x)
    x1 = x2 = y1 = y2 = 0.0
    for i in range(x.size):
        v = b0 * x[i] + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1 = x1, x[i]
        y2, y1 = y1, v
        y[i] = v
    return y


def _place(buf: np.ndarray, grain: np.ndarray, t: float, gain: float) -> None:
    """Add a grain at time t, wrapping around the loop end so the seam stays exact."""
    start = int(round(t * SR)) % buf.size
    end = start + grain.size
    if end <= buf.size:
        buf[start:end] += grain * gain
    else:
        k = buf.size - start
        buf[start:] += grain[:k] * gain
        buf[: end - buf.size] += grain[k:] * gain


def _loop_bed(n: int, make, seed: int) -> np.ndarray:
    fade = int(0.8 * SR)
    rng = np.random.default_rng(seed)
    x = make(n + fade, rng)
    w = np.linspace(0.0, 1.0, fade)
    out = x[:n].copy()
    out[:fade] = out[:fade] * w + x[n:] * (1.0 - w)
    return out


def vulture_wings() -> np.ndarray:
    n = int(6.0 * SR)
    rng = np.random.default_rng(1931)
    t = np.arange(n) / SR
    out = _loop_bed(n, lambda m, r: _onepole_lp(_biquad_bp(_noise(m, r), 640.0, 0.75), 1400.0), 13)
    out /= np.max(np.abs(out)) + 1e-9
    out *= 0.30 + 0.10 * np.sin(2.0 * np.pi * t / 6.0)
    # Two soft downbeats in the loop: a vulture glides more than it flaps.
    for k in (0.6, 3.5):
        ln = int(0.75 * SR)
        tt = np.arange(ln) / SR
        flap = _noise(ln, rng)
        flap = _biquad_bp(flap, 380.0, 0.8) + 0.45 * _biquad_bp(flap, 1150.0, 1.1)
        env = np.sin(np.clip(tt / 0.75, 0.0, 1.0) * np.pi) ** 2
        flap *= env * 0.55
        _place(out, flap, k, 0.55)
    return out


def vulture_cry() -> np.ndarray:
    rng = np.random.default_rng(1932)
    n = int(1.4 * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    # A low, breathy hiss with a rough edge, falling at the end. No bright cartoon scream.
    hiss = _noise(n, rng)
    hiss = _biquad_bp(hiss, 1250.0, 0.9) + 0.55 * _biquad_bp(hiss, 2350.0, 1.4)
    env = np.clip(t / 0.08, 0.0, 1.0) * np.exp(-np.clip(t - 0.18, 0.0, None) / 0.42)
    out += hiss * env * 0.42
    # The throat: a slow descending rasp under the breath.
    f = 132.0 * np.exp(-t * 0.42)
    rasp = np.sin(2 * np.pi * np.cumsum(f) / SR) * (0.55 + 0.45 * np.sin(2 * np.pi * 27.0 * t))
    out += rasp * env * 0.14
    return out


def stampede_rumble() -> np.ndarray:
    n = int(8.0 * SR)
    t = np.arange(n) / SR
    rng = np.random.default_rng(1933)
    out = _loop_bed(n, lambda m, r: _onepole_lp(_onepole_lp(_noise(m, r), 60.0), 38.0), 17)
    out /= np.max(np.abs(out)) + 1e-9
    out *= 0.55 + 0.10 * np.sin(2.0 * np.pi * t / 8.0)
    for f, gain in ((31.25, 0.32), (43.75, 0.22), (62.5, 0.12)):
        out += np.sin(2.0 * np.pi * f * t) * gain
    return out


def stampede_hooves() -> np.ndarray:
    n = int(8.0 * SR)
    rng = np.random.default_rng(1934)
    out = np.zeros(n)
    # Twelve animals at a heavy gallop: about 1.15 strikes each per second, spread across the herd.
    strikes = int(8.0 * 12.0 * 1.15)
    for k in range(strikes):
        at = (k / strikes) * 8.0 + rng.uniform(-0.012, 0.012)
        ln = int(0.20 * SR)
        tt = np.arange(ln) / SR
        f0 = rng.uniform(52.0, 84.0)
        thump = np.sin(2 * np.pi * f0 * tt * (1.0 - 0.55 * tt)) * np.exp(-tt / 0.035)
        click = _biquad_bp(_noise(ln, rng), rng.uniform(900.0, 1900.0), 1.8) * np.exp(-tt / 0.012)
        body = np.sin(2 * np.pi * rng.uniform(115.0, 165.0) * tt) * np.exp(-tt / 0.055) * 0.30
        grain = thump * 1.0 + click * 0.45 + body
        near = 0.55 + 0.45 * rng.random()
        _place(out, grain, at, near * 0.75)
    # A low bed of the herd itself.
    bed = _loop_bed(n, lambda m, r: _onepole_lp(_noise(m, r), 90.0), 19)
    bed /= np.max(np.abs(bed)) + 1e-9
    out += bed * 0.20
    return out


def stampede_pass() -> np.ndarray:
    n = int(4.2 * SR)
    t = np.arange(n) / SR
    rng = np.random.default_rng(1935)
    out = np.zeros(n)
    # The wall of air: a broad rush that peaks at the closest point and thins behind.
    rush = _biquad_bp(_noise(n, rng), 520.0, 0.65) + 0.35 * _biquad_bp(_noise(n, rng), 1700.0, 0.9)
    env = np.exp(-((t - 1.55) / 0.85) ** 2)
    out += rush * env * 0.75
    # The ground moves: a sub drop at the pass.
    sub = np.sin(2 * np.pi * np.cumsum(74.0 * np.exp(-t * 0.9)) / SR) * np.exp(-np.clip(t - 1.1, 0.0, None) / 0.55)
    out += sub * np.clip((t - 0.65) / 0.4, 0.0, 1.0) * 0.36
    # Three near hooves over the top, then the herd is behind him.
    for at, gain in ((1.42, 0.85), (1.70, 0.72), (1.98, 0.46)):
        ln = int(0.24 * SR)
        tt = np.arange(ln) / SR
        thump = np.sin(2 * np.pi * 58.0 * tt * (1.0 - 0.5 * tt)) * np.exp(-tt / 0.05)
        click = _biquad_bp(_noise(ln, rng), 1350.0, 1.7) * np.exp(-tt / 0.015)
        grain = thump * 1.0 + click * 0.5
        i0 = int(at * SR)
        out[i0:i0 + ln] += grain * gain
    return out


def bison_hit() -> np.ndarray:
    rng = np.random.default_rng(1936)
    n = int(0.8 * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    # The mass: a 95 -> 42 Hz drop with a short pitch envelope.
    f = 95.0 * np.exp(-t * 4.2) + 42.0
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.16)
    out += body * 0.90
    # The wet meat of the hit.
    meat = _onepole_lp(_noise(n, rng), 900.0) * np.exp(-t / 0.055)
    out += meat * 0.55
    # A hide slap and a little bone.
    slap = _biquad_bp(_noise(n, rng), 360.0, 1.2) * np.exp(-t / 0.040)
    out += slap * 0.42
    bone = np.sin(2 * np.pi * 1730.0 * t) * np.exp(-t / 0.012) * 0.10
    out += bone
    return out


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
        elif line.startswith("True peak:") and len(line.split()) > 1:
            peak = float(line.split()[1])
    return lufs, peak


def _write(name: str, x: np.ndarray, target_lufs: float, drive: float = 1.0) -> Path:
    x = x / (np.max(np.abs(x)) + 1e-9)
    if drive > 1.0:
        x = np.tanh(x * drive) / np.tanh(drive)
    x = x * 0.89
    wav = OUT / (name + ".wav")
    with wave.open(str(wav), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767.0).astype("<i2").tobytes())
    ogg = OUT / (name + ".ogg")
    lufs, peak = _measure(wav)
    gain = min(target_lufs - lufs, -1.0 - peak)
    subprocess.run(["ffmpeg", "-y", "-hide_banner", "-loglevel", "error", "-i", str(wav), "-af", f"volume={gain:.2f}dB",
                    "-ar", str(SR), "-ac", "1", "-c:a", "libvorbis", "-q:a", "4", str(ogg)], check=True)
    wav.unlink()
    got, got_peak = _measure(ogg)
    print(f"  {name}: {got:.1f} LUFS, true peak {got_peak:.1f} dBTP (gain {gain:+.1f} dB)")
    return ogg


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    jobs = (
        ("vulture_wings", vulture_wings, -24.0, 1.0),
        ("vulture_cry", vulture_cry, -18.0, 1.0),
        ("stampede_rumble", stampede_rumble, -18.0, 1.0),
        ("stampede_hooves", stampede_hooves, -17.0, 1.6),
        ("stampede_pass", stampede_pass, -15.0, 1.2),
        ("bison_hit", bison_hit, -13.0, 1.4),
    )
    for name, fn, target, drive in jobs:
        p = _write(name, fn(), target, drive)
        print(f"{p.relative_to(ROOT)}  {p.stat().st_size} B")
    return 0


if __name__ == "__main__":
    sys.exit(main())
