#!/usr/bin/env python3
"""Turn a hummed recording into notes Claude can use in a track.

Kaighn hums a tune into a voice memo; this finds the pitch every 20 ms,
groups steady stretches into notes, snaps them to the nearest note of A minor
and to the 90 BPM 8th-note grid, prints the note list, and renders a music-box
playback to renders/<name>.mp3 so he can check it was heard right.

    .venv/bin/python hum.py hums/<file>.m4a [name] [--bpm 90] [--no-snap]
"""
import subprocess
import sys
from pathlib import Path

import numpy as np

import instruments as inst
from mixing import SR, balance, export, limit

NAMES = ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]
A_MINOR = {9, 11, 0, 2, 4, 5, 7, 8}     # A natural minor plus G# (E major's note)


def load(path):
    raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", str(path), "-ac", "1",
                          "-ar", str(SR), "-f", "f32le", "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.float32)


def pitch_track(x, hop=0.02, win=0.05, fmin=70, fmax=900):
    """Pitch (Hz, or 0 when not humming) every `hop` seconds. Autocorrelation
    with the YIN tweak (cumulative-mean normalisation) to avoid octave slips."""
    h, w = int(hop * SR), int(win * SR)
    lo, hi = int(SR / fmax), int(SR / fmin)
    loud = np.sqrt(np.convolve(x ** 2, np.ones(w) / w, mode="same"))
    gate = max(np.percentile(loud, 95) * 0.12, 1e-4)
    out = []
    for s in range(0, len(x) - w - hi, h):
        if loud[s + w // 2] < gate:
            out.append(0.0)
            continue
        f = x[s:s + w + hi]
        d = np.array([np.sum((f[:w] - f[k:k + w]) ** 2) for k in range(hi)])
        cmn = d[1:] * np.arange(1, hi) / np.maximum(np.cumsum(d[1:]), 1e-12)
        cand = np.where(cmn[lo:] < 0.15)[0]
        if not cand.size:
            out.append(0.0)
            continue
        k = cand[0] + lo
        while k + 1 < hi - 1 and cmn[k] < cmn[k - 1]:     # slide to the dip's bottom
            k += 1
        out.append(SR / (k))
    return np.array(out), hop


def notes_from(track, hop, min_len=0.09):
    """Group frames into notes: a new note starts at silence or a pitch jump."""
    midi = np.where(track > 0, 69 + 12 * np.log2(np.maximum(track, 1) / 440), np.nan)
    notes, start, buf = [], None, []
    for i, m in enumerate(list(midi) + [np.nan]):
        if start is not None and (np.isnan(m) or abs(m - np.median(buf)) > 0.7):
            if (i - start) * hop >= min_len:
                notes.append([start * hop, (i - start) * hop, float(np.median(buf))])
            start, buf = None, []
        if not np.isnan(m):
            if start is None:
                start = i
            buf.append(m)
    return notes


def tidy(notes, bpm, snap=True):
    """Move the tune into a comfortable octave, snap to A minor and the beat grid."""
    if not notes:
        return []
    step = 60 / bpm / 2                                   # 8th notes
    first = notes[0][0]
    out = []
    for start, dur, m in notes:
        m = round(m)
        if snap and m % 12 not in A_MINOR:
            m = min((m - 1, m + 1), key=lambda c: (c % 12 not in A_MINOR, abs(c - m)))
        b = round((start - first) / step)
        length = max(1, round(dur / step))
        if out and out[-1][0] == b:                       # two notes on one slot: keep the longer
            if length > out[-1][1]:
                out[-1] = [b, length, m]
            continue
        out.append([b, length, m])
    # shift by octaves so the tune sits around the music box's sweet spot (A4-A5)
    centre = np.median([m for _, _, m in out])
    k = round((76 - centre) / 12) * 12
    return [(b / 2, ln / 2, m + k) for b, ln, m in out]   # (beat, beats, midi)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    bpm = float(sys.argv[sys.argv.index("--bpm") + 1]) if "--bpm" in sys.argv else 90
    if "--bpm" in sys.argv:
        args.remove(sys.argv[sys.argv.index("--bpm") + 1])
    src = Path(args[0])
    name = args[1] if len(args) > 1 else f"hum_{src.stem}"
    x = load(src)
    track, hop = pitch_track(x)
    tune = tidy(notes_from(track, hop), bpm, snap="--no-snap" not in sys.argv)

    print(f"{len(tune)} notes (beat, length in beats, note):")
    for b, ln, m in tune:
        print(f"    ({b:g}, {ln:g}, {m}),   # {NAMES[m % 12]}{m // 12 - 1}")

    beat = 60 / bpm
    end = (tune[-1][0] + tune[-1][1]) * beat + 3 if tune else 3
    buf = np.zeros((2, int(end * SR)), np.float32)
    for b, ln, m in tune:
        inst.place(buf, inst.bell(m), b * beat, pan=0.1)
    for b in range(int(end / beat)):                     # soft click so the beat is audible
        inst.place(buf, inst.tick(2400, 0.25), b * beat)
    print(export(limit(balance(buf, -18)), name))


if __name__ == "__main__":
    main()
