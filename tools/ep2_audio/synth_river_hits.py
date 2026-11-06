#!/usr/bin/env python3
"""Synthesize the day-88 river's hit layers (ep2-world-common-sense, founder 2026-11-05: "bullets do nothing to the raft", "shot bandits
stay on the raft").

No timber-hit or splash recording ships in the repo and no text-to-audio key is on this box, so, like the wildlife layers
(tools/ep2_audio/synth_wildlife.py), these are built from first principles: license-clean, deterministic (fixed seeds), one command:

    python3 tools/ep2_audio/synth_river_hits.py       # needs numpy + ffmpeg

  raft_hit.ogg      0.5 s one-shot: a rifle ball into wet logs - a dull knock and a short splinter crackle, no ring.
  raft_break.ogg    1.6 s one-shot: the lashings give: a few cracks, logs knocking apart, the water taking them.
  body_splash.ogg   1.2 s one-shot: a man's weight into fast water - the slap, the plunge, the wash closing over.

Streamed with the Episode 2 extras (src/episode2/extras/audio/river/): the main pack has no margin. The river plays each only when the
file exists, so before the pack mounts it is quiet, never broken.
"""
from __future__ import annotations

import subprocess
import sys
import wave
from pathlib import Path

import numpy as np

SR = 44100
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "src/episode2/extras/audio/river"


def _onepole_lp(x: np.ndarray, cutoff: float) -> np.ndarray:
    a = np.exp(-2.0 * np.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1.0 - a) * v + a * acc
        y[i] = acc
    return y


def _hp(x: np.ndarray, cutoff: float) -> np.ndarray:
    return x - _onepole_lp(x, cutoff)


def _env(n: int, attack: float, decay: float) -> np.ndarray:
    t = np.arange(n) / SR
    return np.minimum(1.0, t / max(attack, 1e-4)) * np.exp(-t / decay)


def _place(buf: np.ndarray, grain: np.ndarray, t: float, gain: float) -> None:
    i = int(t * SR)
    j = min(buf.size, i + grain.size)
    if i < buf.size:
        buf[i:j] += grain[: j - i] * gain


def _knock(rng: np.random.Generator, f: float, decay: float) -> np.ndarray:
    n = int(SR * decay * 6)
    t = np.arange(n) / SR
    body = np.sin(2 * np.pi * f * t + rng.uniform(0, 6.28)) * np.exp(-t / decay)
    thump = _onepole_lp(rng.standard_normal(n), 700.0) * _env(n, 0.001, decay * 0.6)
    return body * 0.6 + thump * 2.5


def _crackle(rng: np.random.Generator, length: float, density: float, bright: float) -> np.ndarray:
    n = int(SR * length)
    out = np.zeros(n)
    for _ in range(int(length * density)):
        g = int(SR * rng.uniform(0.002, 0.008))
        grain = _hp(rng.standard_normal(g), bright) * np.exp(-np.arange(g) / (g * 0.3))
        _place(out, grain, rng.uniform(0, length * 0.9) ** 1.6 / max(length ** 0.6, 1e-3), rng.uniform(0.2, 1.0))
    return out


def raft_hit() -> np.ndarray:
    rng = np.random.default_rng(8801)
    buf = np.zeros(int(SR * 0.5))
    _place(buf, _knock(rng, 190.0, 0.035), 0.0, 1.0)
    _place(buf, _crackle(rng, 0.18, 220, 2500.0), 0.004, 0.35)
    return buf


def raft_break() -> np.ndarray:
    rng = np.random.default_rng(8802)
    buf = np.zeros(int(SR * 1.6))
    for k, t in enumerate((0.0, 0.11, 0.27, 0.46)):
        _place(buf, _crackle(rng, 0.12, 380, 1800.0), t, 0.7 - 0.1 * k)
        _place(buf, _knock(rng, rng.uniform(120.0, 210.0), 0.05), t + 0.01, 0.8)
    for t in (0.55, 0.72, 0.95):
        _place(buf, _knock(rng, rng.uniform(90.0, 140.0), 0.07), t, 0.5)                 # logs knocking apart
    n = int(SR * 1.2)
    wash = _onepole_lp(rng.standard_normal(n), 1400.0) * _env(n, 0.15, 0.45)
    _place(buf, wash, 0.4, 0.5)
    return buf


def body_splash() -> np.ndarray:
    rng = np.random.default_rng(8803)
    buf = np.zeros(int(SR * 1.2))
    n = int(SR * 0.08)
    slap = _hp(rng.standard_normal(n), 900.0) * _env(n, 0.0015, 0.025)
    _place(buf, slap, 0.0, 1.0)
    n = int(SR * 0.5)
    plunge = _onepole_lp(rng.standard_normal(n), 500.0) * _env(n, 0.01, 0.12)
    _place(buf, plunge, 0.01, 1.4)
    n = int(SR * 1.0)
    wash = _onepole_lp(_hp(rng.standard_normal(n), 300.0), 2600.0) * _env(n, 0.06, 0.32)
    _place(buf, wash, 0.05, 0.6)
    for _ in range(14):                                                                     # droplets falling back
        g = int(SR * 0.012)
        drop = np.sin(2 * np.pi * rng.uniform(900, 2200) * np.arange(g) / SR) * np.exp(-np.arange(g) / (g * 0.25))
        _place(buf, drop, rng.uniform(0.12, 0.7), rng.uniform(0.05, 0.18))
    return buf


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


def _write(name: str, x: np.ndarray, target_lufs: float) -> Path:
    x = x / (np.max(np.abs(x)) + 1e-9) * 0.89
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
    for name, fn, target in (("raft_hit", raft_hit, -16.0), ("raft_break", raft_break, -15.0), ("body_splash", body_splash, -16.0)):
        p = _write(name, fn(), target)
        print(f"{p.relative_to(ROOT)}  {p.stat().st_size} B")
    return 0


if __name__ == "__main__":
    sys.exit(main())
