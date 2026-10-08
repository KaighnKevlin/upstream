"""Shared mixing and measuring helpers for the track scripts (factory, siege).

Claude can't hear the renders, so these measure what the ear would notice:
how loud each part is while it's sounding, section by section, and peaks.
"""
import subprocess
from pathlib import Path

import numpy as np
from pedalboard.io import AudioFile

SR = 44100
RENDERS = Path(__file__).parent / "renders"


def db(x):
    return 20 * np.log10(float(np.sqrt((x ** 2).mean())) + 1e-9)


def loud(x, win=0.05, skip_silence=True):
    """How loud a part sounds while it's sounding: the 90th-percentile loudness
    of 50 ms slices, skipping silence. Plain averages under-rate sparse clicks.
    With skip_silence=False a part that only rings out briefly reads as quiet."""
    w = int(win * SR)
    m = x[:, : x.shape[1] // w * w].reshape(2, -1, w)
    r = np.sqrt((m ** 2).mean(axis=(0, 2)))
    if skip_silence:
        r = r[r > 10 ** (-70 / 20)]
    r = np.maximum(r, 1e-6)
    return 20 * np.log10(np.percentile(r, 90)) if r.size else -120.0


def balance(x, target):
    return x * 10 ** ((target - loud(x)) / 20)


def fit(x, n):
    """Trim or pad a stem to exactly n samples (renders can differ by a sample)."""
    return x[:, :n] if x.shape[1] >= n else np.pad(x, ((0, 0), (0, n - x.shape[1])))


def limit(x, ceiling_db=-1.0, block=256):
    """Gentle peak limiter: turn down only the short blocks that would poke over."""
    ceil = 10 ** (ceiling_db / 20)
    nb = -(-x.shape[1] // block)
    pad = np.pad(np.abs(x).max(axis=0), (0, nb * block - x.shape[1]))
    peaks = pad.reshape(nb, block).max(axis=1)
    g = np.minimum(1.0, ceil / np.maximum(peaks, 1e-9))
    g = np.minimum(g, np.minimum(np.roll(g, 1), np.roll(g, -1)))    # look ahead/behind
    for i in range(1, nb):                                         # slow recovery
        g[i] = min(g[i], g[i - 1] + 0.002)
    env = np.interp(np.arange(x.shape[1]), np.arange(nb) * block + block / 2, g)
    return x * env


def report(stems, mix, sections):
    """Loudness of every part in every section; sections = [(name, start_s, end_s)]."""
    names = list(stems)
    print(f"{'section':9}" + "".join(f"{k[:7]:>8}" for k in names) + "     MIX")
    for name, a, b in sections:
        s, e = int(a * SR), int(b * SR)
        row = []
        for k in names:
            seg = stems[k][:, s:e]
            v = loud(seg, skip_silence=False)
            row.append(f"{v:8.1f}" if v > -60 else f"{'-':>8}")
        print(f"{name:9}" + "".join(row) + f"{loud(mix[:, s:e], skip_silence=False):8.1f}")


def export(mix, name):
    RENDERS.mkdir(exist_ok=True)
    wav, mp3 = RENDERS / f"{name}.wav", RENDERS / f"{name}.mp3"
    with AudioFile(str(wav), "w", SR, 2) as f:
        f.write(mix)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav),
                    "-b:a", "192k", str(mp3)], check=True)
    return mp3
