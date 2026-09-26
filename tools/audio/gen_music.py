"""The soundtrack: "Clockwork Nocturne", a slow, looping music-box piece.

    python3 tools/audio/gen_music.py

Writes assets/audio/nocturne.wav (22050 Hz, mono, 16-bit, seamless loop).
Layers, all synthesised here (no samples):
  - a soft pad on a i-VI-III-VII progression in D minor (Dm, Bb, F, C),
    four bars each, with a slow tremolo
  - a music-box melody: plucked tines (a sine with a bright, fast-decaying
    partial) wandering over D minor pentatonic in eighth notes, phrased in
    two-bar calls and answers with rests, the second pass varied
  - clockwork: a soft tick on every beat and a lower tock between
  - a low bell at the top of each chord
The tail is wrapped onto the start so the loop has no seam.
"""
import math, random, struct, wave, os

SR = 22050
BPM = 84
BEAT = 60.0 / BPM
BARS = 32
LEN = int(SR * BEAT * 4 * BARS)
buf = [0.0] * LEN
r = random.Random(7)


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12.0)


def add(start, samples):
    i0 = int(start * SR)
    for k, v in enumerate(samples):
        buf[(i0 + k) % LEN] += v        # wrap: the tail lands on the start


def tine(f, dur, amp):
    n = int(SR * dur)
    out = []
    for i in range(n):
        t = i / SR
        env = math.exp(-t * 3.2) * min(1.0, t * 400)
        v = math.sin(2 * math.pi * f * t) + 0.35 * math.sin(2 * math.pi * f * 2.0 * t) * math.exp(-t * 9) \
            + 0.12 * math.sin(2 * math.pi * f * 4.01 * t) * math.exp(-t * 18)
        out.append(v * env * amp)
    return out


def pad(fs, dur, amp):
    n = int(SR * dur)
    out = []
    for i in range(n):
        t = i / SR
        env = min(1.0, t / 1.2) * min(1.0, (dur - t) / 1.2)
        trem = 0.85 + 0.15 * math.sin(2 * math.pi * 0.25 * t)
        v = sum(math.sin(2 * math.pi * f * t + k) + 0.25 * math.sin(2 * math.pi * f * 2 * t) for k, f in enumerate(fs))
        out.append(v * env * trem * amp / len(fs))
    return out


def tick(amp, bright):
    n = int(SR * 0.03)
    out = []
    lp = 0.0
    for i in range(n):
        x = r.uniform(-1, 1)
        lp += (x - lp) * bright
        out.append(lp * math.exp(-i / SR * 180) * amp)
    return out


def bell(f, amp):
    n = int(SR * 3.5)
    out = []
    for i in range(n):
        t = i / SR
        env = math.exp(-t * 1.3) * min(1.0, t * 300)
        v = math.sin(2 * math.pi * f * t) + 0.5 * math.sin(2 * math.pi * f * 2.76 * t) * math.exp(-t * 2.5) \
            + 0.25 * math.sin(2 * math.pi * f * 5.4 * t) * math.exp(-t * 4)
        out.append(v * env * amp)
    return out


# the progression: roots and chord tones (MIDI), four bars each, twice
chords = [(38, [50, 53, 57]), (34, [46, 50, 53]), (41, [53, 57, 60]), (36, [48, 52, 55])] * 2
bar = BEAT * 4
for ci, (root, tones) in enumerate(chords):
    t0 = ci * 4 * bar
    add(t0, pad([midi(root), midi(root + 7)] + [midi(x) for x in tones], 4 * bar + 1.0, 0.16))
    add(t0, bell(midi(root + 12), 0.10))

# the music box: D minor pentatonic, two octaves up
scale = [62, 65, 67, 69, 72, 74, 77, 79, 81, 84]
phrases = []
for p in range(8):                       # 8 two-bar phrases, then a varied repeat
    idx = r.randint(2, 6)
    notes = []
    for step in range(16):               # eighth notes
        if step in (7, 15) or (step % 4 == 3 and r.random() < 0.45):
            notes.append(None)           # breathe
            continue
        idx = max(0, min(len(scale) - 1, idx + r.choice([-2, -1, -1, 0, 1, 1, 2])))
        notes.append(scale[idx])
    phrases.append(notes)
for half in range(2):
    for p, notes in enumerate(phrases):
        t0 = (half * 16 + p * 2) * bar
        for step, n in enumerate(notes):
            if n is None:
                continue
            if half == 1 and r.random() < 0.25:
                n += r.choice([-3, 2, 5])  # the repeat wanders a little
            add(t0 + step * BEAT / 2 + r.uniform(0, 0.012), tine(midi(n), 1.6, 0.13))
            if step % 8 == 0 and r.random() < 0.5:
                add(t0 + step * BEAT / 2, tine(midi(n - 12), 1.8, 0.07))   # a low echo

# clockwork
for b in range(BARS * 4):
    add(b * BEAT, tick(0.10, 0.35))
    add(b * BEAT + BEAT / 2, tick(0.06, 0.12))

peak = max(abs(v) for v in buf) or 1.0
out = os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'audio', 'nocturne.wav')
with wave.open(out, 'wb') as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(b''.join(struct.pack('<h', int(v / peak * 0.8 * 32767)) for v in buf))
print('wrote nocturne.wav: %.1f s loop' % (LEN / SR))
