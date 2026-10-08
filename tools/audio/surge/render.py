#!/usr/bin/env python3
"""Render a Dungeon-of-the-Endless-style track to MP3.

Composition is plain Python (lists of notes); each part is played through its
own Surge XT instance via pedalboard, given effects, then mixed and exported.

    .venv/bin/python render.py [name]      -> renders/<name>.mp3
"""
import subprocess
import sys
from pathlib import Path

import mido
import numpy as np
from pedalboard import (Chorus, Compressor, Delay, Gain, HighpassFilter,
                        Limiter, LowpassFilter, Pedalboard, Reverb, load_plugin)
from pedalboard.io import AudioFile

SR = 44100
BPM = 100
BEAT = 60 / BPM            # seconds per beat
BAR = 4 * BEAT
SURGE = "/Library/Audio/Plug-Ins/VST3/Surge XT.vst3"
HERE = Path(__file__).parent

# --- harmony -----------------------------------------------------------------
# A minor: Am - F - Dm - E. Sad, a little ominous, with a pull back to the top.
CHORDS = [
    [57, 60, 64],   # Am
    [53, 57, 60],   # F
    [50, 53, 57],   # Dm
    [52, 56, 59],   # E (major - the G# is the "uh oh" note)
]
ROOTS = [45, 41, 38, 40]

# --- structure: (bars, set of active layers) -----------------------------------
SECTIONS = [
    (8,  {"pad"}),                                       # alone in the dark
    (8,  {"pad", "arp"}),                                # the machinery wakes up
    (16, {"pad", "arp", "bass", "drums"}),               # something is coming
    (16, {"pad", "arp", "bass", "drums", "lead"}),       # the wave
    (8,  {"pad", "arp"}),                                # quiet again
]
TOTAL_BARS = sum(b for b, _ in SECTIONS)


def active(layer):
    """Yield the bar indices where `layer` plays."""
    bar = 0
    for n, layers in SECTIONS:
        if layer in layers:
            yield from range(bar, bar + n)
        bar += n


def chord_for(bar):
    return bar % len(CHORDS)


# --- note writers: each returns [(start_sec, dur_sec, midi_note, velocity)] ----
def pad_notes():
    out = []
    for bar in active("pad"):
        c = chord_for(bar)
        for n in CHORDS[c] + [CHORDS[c][0] - 12]:
            out.append((bar * BAR, BAR * 0.98, n, 70))
    return out


def arp_notes():
    out = []
    for bar in active("arp"):
        c = CHORDS[chord_for(bar)]
        pattern = [c[0], c[1], c[2], c[0] + 12, c[2], c[1]] * 3   # ticking 16ths
        for i, n in enumerate(pattern[:16]):
            vel = 95 if i % 4 == 0 else 70
            out.append((bar * BAR + i * BEAT / 4, BEAT / 4 * 0.6, n + 12, vel))
    return out


def bass_notes():
    out = []
    for bar in active("bass"):
        r = ROOTS[chord_for(bar)]
        for beat in (0, 1.5, 2, 3.5):            # syncopated pulse
            out.append((bar * BAR + beat * BEAT, BEAT * 0.45, r - 12, 100))
    return out


LEAD = [  # (beat offset within 4-bar phrase, length in beats, note)
    (0, 3, 76), (3, 1, 74), (4, 2, 72), (6, 2, 71),
    (8, 3, 74), (11, 1, 72), (12, 4, 71),
]


def lead_notes():
    out = []
    bars = list(active("lead"))
    for bar in bars[::4]:
        for off, length, n in LEAD:
            out.append((bar * BAR + off * BEAT, length * BEAT * 0.95, n, 85))
    return out


def render_part(notes, setup, seconds):
    synth = load_plugin(SURGE)
    setup(synth)
    msgs = []
    for start, dur, note, vel in notes:
        msgs.append(mido.Message("note_on", note=note, velocity=vel, time=start))
        msgs.append(mido.Message("note_off", note=note, velocity=0, time=start + dur))
    return synth(msgs, duration=seconds, sample_rate=SR, num_channels=2)


def level(x, target_db):
    """Scale a stem so its loudness while playing (ignoring silence) is target_db."""
    mono = np.abs(x).mean(axis=0)
    playing = x[:, mono > 1e-4]
    rms = np.sqrt((playing ** 2).mean()) if playing.size else 1.0
    return x * (10 ** (target_db / 20) / rms)


def drums(seconds):
    """Simple synthesized kick + hat; Surge is overkill for these."""
    out = np.zeros((2, int(seconds * SR)), dtype=np.float32)
    t = np.arange(int(0.4 * SR)) / SR
    kick = np.sin(2 * np.pi * (45 + 90 * np.exp(-t * 30)) * t) * np.exp(-t * 9)
    th = np.arange(int(0.05 * SR)) / SR
    hat = np.random.default_rng(1).uniform(-1, 1, th.size) * np.exp(-th * 90) * 0.25
    for bar in active("drums"):
        for beat in range(4):
            s = int((bar * BAR + beat * BEAT) * SR)
            if beat in (0, 2):
                out[:, s:s + kick.size] += kick * 0.9
            h = int((bar * BAR + (beat + 0.5) * BEAT) * SR)
            out[:, h:h + hat.size] += hat
    return out


# --- sounds ------------------------------------------------------------------
from sounds import setup_arp, setup_bass, setup_lead, setup_pad  # noqa: E402


def main():
    name = sys.argv[1] if len(sys.argv) > 1 else "sketch_v1"
    seconds = TOTAL_BARS * BAR + 4      # tail for reverb

    pad = render_part(pad_notes(), setup_pad, seconds)
    pad = Pedalboard([LowpassFilter(1800), Chorus(depth=0.3, mix=0.4),
                      Reverb(room_size=0.9, wet_level=0.45, dry_level=0.6)])(pad, SR)
    pad = level(pad, -22)

    arp = render_part(arp_notes(), setup_arp, seconds)
    arp = Pedalboard([HighpassFilter(250),
                      Delay(delay_seconds=BEAT * 0.75, feedback=0.35, mix=0.3),
                      Reverb(room_size=0.7, wet_level=0.3)])(arp, SR)
    arp = level(arp, -25)

    bass = render_part(bass_notes(), setup_bass, seconds)
    bass = Pedalboard([LowpassFilter(900), Compressor(-18, 4)])(bass, SR)
    bass = level(bass, -22)

    lead = render_part(lead_notes(), setup_lead, seconds)
    lead = Pedalboard([Delay(delay_seconds=BEAT, feedback=0.4, mix=0.35),
                       Reverb(room_size=0.95, wet_level=0.5)])(lead, SR)
    lead = level(lead, -23)

    kit = Pedalboard([Reverb(room_size=0.4, wet_level=0.15)])(drums(seconds), SR)
    kit = level(kit, -24)

    parts = [pad, arp, bass, lead, kit]
    n = min(p.shape[1] for p in parts)       # renders can differ by a sample
    mix = sum(p[:, :n] for p in parts)
    mix = Pedalboard([Gain(4), Compressor(threshold_db=-14, ratio=2.5),
                      Limiter(threshold_db=-1.0)])(mix, SR)

    out = HERE / "renders"
    out.mkdir(exist_ok=True)
    wav = out / f"{name}.wav"
    with AudioFile(str(wav), "w", SR, 2) as f:
        f.write(mix)
    mp3 = out / f"{name}.mp3"
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav),
                    "-b:a", "192k", str(mp3)], check=True)
    peak = float(np.abs(mix).max())
    rms_db = 20 * np.log10(float(np.sqrt((mix ** 2).mean())) + 1e-9)
    print(f"{mp3}  {seconds:.0f}s  peak={peak:.2f}  rms={rms_db:.1f}dB")


if __name__ == "__main__":
    main()
