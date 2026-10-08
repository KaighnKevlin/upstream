"""Hand-built numpy instruments for the marble-machine sounds.

Each function returns a mono float32 one-shot; `place` drops it into a
stereo buffer at a time and pan. Wood and metal are modelled as a few
"ringing" sine partials that die away at different speeds (modal synthesis).
"""
import numpy as np

SR = 44100


def _t(seconds):
    return np.arange(int(seconds * SR)) / SR


def smooth(x, n):
    """Crude low-pass: moving average over n samples."""
    return np.convolve(x, np.ones(n) / n, mode="same")


def modes(t, partials):
    """Sum of decaying sines: partials = [(freq, amp, decay_per_sec)]."""
    out = np.zeros_like(t)
    for f, a, d in partials:
        if f < SR / 2.2:
            out += a * np.sin(2 * np.pi * f * t) * np.exp(-t * d)
    return out


def place(buf, sig, sec, pan=0.0, gain=1.0):
    """Add mono `sig` into stereo `buf` at `sec`; pan -1 (left) .. +1 (right)."""
    s = int(sec * SR)
    if s >= buf.shape[1]:
        return
    sig = sig[: buf.shape[1] - s] * gain
    left, right = np.sqrt((1 - pan) / 2), np.sqrt((1 + pan) / 2)
    buf[0, s:s + sig.size] += sig * left
    buf[1, s:s + sig.size] += sig * right


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


# --- pitched -----------------------------------------------------------------
def mallet(midi, vel=1.0, rng=None):
    """Wooden bar struck with a soft mallet (marimba-like)."""
    f = hz(midi)
    t = _t(1.4)
    base = 2.5 + f / 350                      # higher bars die faster
    body = modes(t, [(f, 1.0, base), (f * 3.93, 0.28, base * 3.5),
                     (f * 9.2, 0.06, base * 7)])
    noise = (rng or np.random.default_rng(0)).uniform(-1, 1, t.size)
    strike = smooth(noise, 6) * np.exp(-t * 500) * 0.25
    attack = 1 - np.exp(-t * 3000)
    return ((body * attack + strike) * vel * 0.5).astype(np.float32)


def bell(midi, vel=1.0):
    """Small glassy bell (FM: an inharmonic overtone that fades fastest)."""
    f = hz(midi)
    t = _t(3.5)
    index = 2.2 * np.exp(-t * 3) + 0.3
    mod = np.sin(2 * np.pi * f * 3.5 * t) * index
    tone = np.sin(2 * np.pi * f * t + mod) * np.exp(-t * 1.1)
    shimmer = 0.15 * np.sin(2 * np.pi * f * 2.0 * t) * np.exp(-t * 2.5)
    attack = 1 - np.exp(-t * 1500)
    return ((tone + shimmer) * attack * vel * 0.45).astype(np.float32)


# --- clockwork ---------------------------------------------------------------
def tick(f=3200.0, vel=1.0, rng=None):
    """One escapement click: tiny metal ring plus a snap of noise."""
    t = _t(0.04)
    ring = modes(t, [(f, 1.0, 350), (f * 2.31, 0.5, 600), (f * 0.62, 0.4, 250)])
    noise = (rng or np.random.default_rng(1)).uniform(-1, 1, t.size)
    snap = (noise - smooth(noise, 4)) * np.exp(-t * 1800) * 0.6
    return ((ring + snap) * vel * 0.5).astype(np.float32)


def ratchet(n=14, gap=0.045, rng=None):
    """Gear winding: a run of clicks that speeds up slightly."""
    rng = rng or np.random.default_rng(2)
    out = np.zeros(int((n * gap + 0.1) * SR), dtype=np.float32)
    at = 0.0
    for i in range(n):
        c = tick(2600 + 150 * (i % 2) + rng.uniform(-60, 60), 0.5 + 0.4 * i / n, rng)
        s = int(at * SR)
        out[s:s + c.size] += c
        at += gap * (1 - 0.3 * i / n)
    return out


def marble_roll(seconds=1.6, rng=None):
    """A marble rolling down a wooden track and dropping into a cup."""
    rng = rng or np.random.default_rng(3)
    out = np.zeros(int((seconds + 0.6) * SR), dtype=np.float32)
    t = _t(seconds)
    # Rumble of the roll: dark noise that swells as it speeds up.
    rumble = smooth(rng.uniform(-1, 1, t.size), 60) * (t / seconds) ** 1.5 * 0.5
    out[: t.size] += rumble
    # Joints in the track: clicks that come closer together.
    at = 0.0
    while at < seconds:
        frac = at / seconds
        c = tick(rng.uniform(2200, 3800), 0.15 + 0.35 * frac, rng)
        s = int(at * SR)
        out[s:s + c.size] += c
        at += 0.13 - 0.09 * frac + rng.uniform(0, 0.02)
    # Clack into the cup, then a hollow wooden thunk.
    end = int(seconds * SR)
    tc = _t(0.25)
    clack = modes(tc, [(3100, 0.8, 90), (5300, 0.5, 140), (7900, 0.25, 200)])
    out[end:end + tc.size] += clack.astype(np.float32)
    thunk = modes(tc, [(380, 0.9, 30), (1050, 0.3, 60)])
    s = end + int(0.03 * SR)
    out[s:s + tc.size] += thunk.astype(np.float32)
    return out * 0.6


def drip(rng):
    """Cave water drip: a short 'plink' whose pitch rises."""
    t = _t(0.18)
    f0 = rng.uniform(700, 1300)
    freq = f0 * (1 + 1.4 * (1 - np.exp(-t * 55)))
    phase = 2 * np.pi * np.cumsum(freq) / SR
    env = np.exp(-t * 32) * (1 - np.exp(-t * 2500))
    return (np.sin(phase) * env * 0.5).astype(np.float32)


# --- kit ---------------------------------------------------------------------
def felt_kick(vel=1.0):
    """Round, soft kick: like a padded mallet on a big drum."""
    t = _t(0.6)
    freq = 50 + 70 * np.exp(-t * 25)
    phase = 2 * np.pi * np.cumsum(freq) / SR
    body = np.sin(phase) * np.exp(-t * 6.5)
    knock = modes(t, [(160, 0.25, 40)])
    return (np.tanh((body + knock) * 1.6) * vel * 0.8).astype(np.float32)


def woodblock(vel=1.0, pitch=1.0):
    t = _t(0.2)
    return (modes(t, [(820 * pitch, 1.0, 55), (2150 * pitch, 0.45, 90),
                      (3900 * pitch, 0.15, 160)]) * vel * 0.6).astype(np.float32)


def shaker(vel=1.0, rng=None):
    t = _t(0.12)
    noise = (rng or np.random.default_rng(4)).uniform(-1, 1, t.size)
    hiss = noise - smooth(noise, 3)
    env = (1 - np.exp(-t * 180)) * np.exp(-t * 45)
    return (hiss * env * vel * 0.35).astype(np.float32)


# --- siege kit ---------------------------------------------------------------
def hard_kick(vel=1.0, rng=None):
    """Punchy kick: fast pitch drop, a click on top, pushed into a little grit."""
    t = _t(0.5)
    freq = 46 + 160 * np.exp(-t * 38)
    body = np.sin(2 * np.pi * np.cumsum(freq) / SR) * np.exp(-t * 7)
    noise = (rng or np.random.default_rng(20)).uniform(-1, 1, t.size)
    click = (noise - smooth(noise, 3)) * np.exp(-t * 900) * 0.35
    return (np.tanh((body + click) * 2.4) * vel * 0.7).astype(np.float32)


def snare(vel=1.0, rng=None):
    t = _t(0.35)
    body = modes(t, [(185, 0.7, 28), (330, 0.35, 40)])
    noise = (rng or np.random.default_rng(21)).uniform(-1, 1, t.size)
    rattle = (noise - smooth(noise, 5)) * np.exp(-t * 16) * 0.8
    return (np.tanh((body + rattle) * 1.5) * vel * 0.55).astype(np.float32)


def hat(vel=1.0, rng=None, open_=False):
    t = _t(0.35 if open_ else 0.08)
    noise = (rng or np.random.default_rng(22)).uniform(-1, 1, t.size)
    hiss = noise - smooth(noise, 2)
    hiss = hiss - smooth(hiss, 2)
    return (hiss * np.exp(-t * (9 if open_ else 70)) * vel * 0.3).astype(np.float32)


def war_drum(f=80.0, vel=1.0, rng=None):
    """Big low drum (taiko-like): skin pitch bends down as it settles."""
    t = _t(1.2)
    freq = f * (1 + 0.6 * np.exp(-t * 18))
    body = np.sin(2 * np.pi * np.cumsum(freq) / SR) * np.exp(-t * 4)
    over = modes(t, [(f * 2.3, 0.3, 14), (f * 3.6, 0.15, 22)])
    noise = (rng or np.random.default_rng(23)).uniform(-1, 1, t.size)
    slap = smooth(noise, 8) * np.exp(-t * 120) * 0.6
    return (np.tanh((body + over + slap) * 1.8) * vel * 0.7).astype(np.float32)


def anvil(vel=1.0):
    """Struck metal: clashing overtones that ring a long time."""
    t = _t(2.0)
    return (modes(t, [(1130, 1.0, 5), (2710, 0.6, 7), (3980, 0.45, 9),
                      (5570, 0.25, 13), (7300, 0.12, 18)]) * vel * 0.35).astype(np.float32)


def riser(seconds, rng=None):
    """Rush of noise that gets brighter and louder, ending in a cut."""
    rng = rng or np.random.default_rng(24)
    n = int(seconds * SR)
    noise = rng.uniform(-1, 1, n)
    out = np.zeros(n)
    k = 24
    for i in range(k):                      # brighten in steps: less smoothing
        a, b = i * n // k, (i + 1) * n // k
        w = max(1, int(40 * (1 - i / k)))
        out[a:b] = (noise - smooth(noise, 40))[a:b] * 0.3 + smooth(noise, w)[a:b]
    t = np.arange(n) / SR
    sweep = 0.25 * np.sin(2 * np.pi * np.cumsum(150 * 8 ** (t / seconds)) / SR)
    return ((out + sweep) * (t / seconds) ** 2.5 * 0.6).astype(np.float32)


def boom(vel=1.0, rng=None):
    """Deep impact for the start of a big section."""
    t = _t(3.0)
    freq = 34 + 60 * np.exp(-t * 8)
    sub = np.sin(2 * np.pi * np.cumsum(freq) / SR) * np.exp(-t * 1.6)
    noise = (rng or np.random.default_rng(25)).uniform(-1, 1, t.size)
    crack = smooth(noise, 12) * np.exp(-t * 14) * 0.5
    return (np.tanh((sub + crack) * 1.8) * vel * 0.8).astype(np.float32)


# --- choir -------------------------------------------------------------------
# A voice is a buzzing source (the vocal cords) shaped by resonances of the
# mouth ("formants"). Which resonances are strong decides the vowel.
VOWELS = {   # (centre Hz, width Hz, strength) for a low male voice
    "oh": [(400, 90, 1.0), (750, 110, 0.55), (2400, 160, 0.18)],
    "ah": [(650, 100, 1.0), (1080, 120, 0.5), (2650, 180, 0.22)],
    "oo": [(320, 80, 1.0), (620, 100, 0.35), (2350, 160, 0.08)],
}


def choir_source(notes, n, voices=6, seed=40, attack=0.45, tail=0.8):
    """Ensemble of buzzing voices. notes = [(start_s, dur_s, midi, vel)].
    Each singer is slightly out of tune, with their own wobble (vibrato).
    A short attack and tail turns it into shouted stabs."""
    rng = np.random.default_rng(seed)
    buf = np.zeros((2, n), np.float32)
    for start, dur, midi, vel in notes:
        t = _t(dur + tail)
        env = np.minimum(1, t / attack) * np.clip((dur + tail - t) / tail, 0, 1) ** 1.5
        for _ in range(voices):
            cents = rng.normal(0, 7)
            rate, depth = rng.uniform(4.6, 5.8), rng.uniform(10, 22)
            wob = depth * np.sin(2 * np.pi * rate * t + rng.uniform(0, 6.3))
            wob *= np.minimum(1, t / 0.8)           # vibrato creeps in, like real singers
            f = hz(midi) * 2 ** ((cents + wob) / 1200)
            phase = np.cumsum(f) / SR + rng.uniform()
            saw = 2 * (phase % 1) - 1
            breath = rng.uniform(-1, 1, t.size) * 0.12
            v = ((saw + breath) * env * vel / voices).astype(np.float32)
            place(buf, v, start, pan=rng.uniform(-0.7, 0.7))
    return buf


def formant(x, vowel):
    """Shape a buzzing source into a sung vowel (one big FFT filter)."""
    spec = np.fft.rfft(x, axis=1)
    f = np.fft.rfftfreq(x.shape[1], 1 / SR)
    h = np.full_like(f, 0.015)
    for fc, bw, a in VOWELS[vowel]:
        h += a / (1 + ((f - fc) / (bw / 2)) ** 2)
    h *= 1 / (1 + (f / 4000) ** 4)
    return np.fft.irfft(spec * h, n=x.shape[1], axis=1).astype(np.float32)


def duck(n, hits, depth=0.6, release=0.25):
    """Sidechain 'pumping': a gain curve that dips at each kick and swells back."""
    pulse = np.zeros(n)
    for h in hits:
        s = int(h * SR)
        if s < n:
            pulse[s] = 1.0
    k = np.exp(-np.arange(int(release * 4 * SR)) / (release * SR))
    env = np.minimum(1.0, np.convolve(pulse, k)[:n])
    attack = smooth(env, int(0.008 * SR))         # don't click on the dip
    return (1 - depth * np.maximum(env, attack)).astype(np.float32)


# --- panic -------------------------------------------------------------------
def shriek(seconds, lo=72, rise=12, voices=8, rng=None):
    """Screeching string cluster: neighbouring notes all sliding upward together."""
    rng = rng or np.random.default_rng(60)
    t = _t(seconds)
    out = np.zeros((2, t.size), np.float32)
    climb = rise * (t / seconds) ** 1.6
    for i in range(voices):
        f = hz(lo + i * 0.5 + climb + rng.normal(0, 0.1))
        f = f * (1 + 0.006 * np.sin(2 * np.pi * rng.uniform(5.5, 7) * t))
        saw = 2 * ((np.cumsum(f) / SR + rng.uniform()) % 1) - 1
        env = np.minimum(1, t / 0.3) * np.minimum(1, (seconds - t) / 0.05)
        place(out, (saw * env / voices).astype(np.float32), 0, pan=rng.uniform(-0.9, 0.9))
    return out


def siren(seconds, lo=620, hi=880, period=0.9):
    """Two-tone air-raid wail."""
    t = _t(seconds)
    f = lo + (hi - lo) * (0.5 - 0.5 * np.cos(2 * np.pi * t / period))
    ph = 2 * np.pi * np.cumsum(f) / SR
    tone = np.sin(ph) + 0.35 * np.sin(2 * ph) + 0.15 * np.sin(3 * ph)
    env = np.minimum(1, t / 0.4) * np.minimum(1, (seconds - t) / 0.4)
    return (tone * env * 0.3).astype(np.float32)


# --- strange textures (throne v3) ---------------------------------------------
def pluck(midi, vel=1.0, ring=1.2, bright=0.6, rng=None):
    """Plucked string (Karplus-Strong): a burst of noise fed round a loop the
    length of one wave, losing a little each pass, which is how a real string
    rings and darkens."""
    rng = rng or np.random.default_rng(90)
    f = hz(midi)
    N = max(2, int(round(SR / f)))
    total = int((ring + 0.1) * SR)
    burst = rng.uniform(-1, 1, N)
    burst = bright * burst + (1 - bright) * smooth(burst, 4)
    burst += 0.5 * np.sin(2 * np.pi * np.arange(N) / N)   # keep the note itself strong
    d = 10 ** (-3 / (f * ring))                       # ring = seconds to fade 60 dB
    y = np.zeros(total + N + 1)
    y[1:N + 1] = burst
    for i in range(N + 1, total + 1, N):
        e = min(i + N, total + 1)
        y[i:e] = d * 0.5 * (y[i - N:e - N] + y[i - N - 1:e - N - 1])
    y = y[1:total + 1]
    y = y - smooth(y, 200)                            # drop the low thump of the loop
    return (y * vel * 0.6).astype(np.float32)


def bowed_metal(f0=220.0, seconds=6.0, rng=None):
    """Bow drawn across a cymbal or metal plate: clashing overtones that swell
    in slowly, each one beating gently against a near-twin."""
    rng = rng or np.random.default_rng(91)
    t = _t(seconds)
    out = np.zeros_like(t)
    for ratio, a in ((1, 1.0), (2.76, 0.6), (5.40, 0.4), (8.93, 0.25), (13.3, 0.12)):
        for det in (1.0, 1.0 + rng.uniform(0.002, 0.005)):
            out += a * np.sin(2 * np.pi * f0 * ratio * det * t + rng.uniform(0, 6.3))
    env = (1 - np.exp(-t / 1.6)) * np.clip((seconds - t) / (seconds * 0.45), 0, 1)
    return (out * env * 0.12).astype(np.float32)


def heartbeat(vel=1.0):
    """Lub-dub: two low thumps."""
    t = _t(0.6)
    def thump(f, a):
        freq = f * (1 + 0.5 * np.exp(-t * 30))
        return a * np.sin(2 * np.pi * np.cumsum(freq) / SR) * np.exp(-t * 14)
    lub = thump(52, 1.0)
    dub = np.zeros_like(t)
    s = int(0.22 * SR)
    dub[s:] = thump(60, 0.7)[: t.size - s]
    return (np.tanh((lub + dub) * 1.5) * vel * 0.8).astype(np.float32)


def wind(seconds, rng=None):
    """Cave wind: noise whose pitch-band drifts slowly up and down (a howl).
    Filtered in overlapping slices, each with a band centred somewhere new."""
    rng = rng or np.random.default_rng(92)
    n, frame, hop = int(seconds * SR), 4096, 2048
    noise = rng.uniform(-1, 1, n + frame)
    out = np.zeros(n + frame)
    win = np.hanning(frame)
    freqs = np.fft.rfftfreq(frame, 1 / SR)
    steps = n // hop + 1
    drift = np.cumsum(rng.normal(0, 0.06, steps))
    drift = smooth(drift - drift.mean(), 9)
    for k in range(steps):
        a = k * hop
        fc = 380 * 2 ** np.clip(drift[k], -1.2, 1.5)
        band = np.exp(-0.5 * (np.log2(np.maximum(freqs, 1) / fc) / 0.18) ** 2)
        band += 0.3 * np.exp(-0.5 * (np.log2(np.maximum(freqs, 1) / (fc * 2.02)) / 0.12) ** 2)
        spec = np.fft.rfft(noise[a:a + frame] * win) * band
        out[a:a + frame] += np.fft.irfft(spec, n=frame) * win
    out = out[:n]
    t = np.arange(n) / SR
    gust = 0.6 + 0.4 * np.sin(2 * np.pi * t / 5.3 + 1) * np.sin(2 * np.pi * t / 3.1)
    return (out * gust / (np.abs(out).max() + 1e-9) * 0.5).astype(np.float32)


def warble(x, rate=0.7, cents=35):
    """Make a sound drift out of tune, like a warped old music box or tape."""
    depth = (2 ** (cents / 1200) - 1) * SR / (2 * np.pi * rate)
    i = np.arange(x.size)
    warp = i + depth * np.sin(2 * np.pi * rate * i / SR)
    return np.interp(warp, i, x).astype(np.float32)


# --- forge -------------------------------------------------------------------
def hammer(midi, vel=1.0, rng=None):
    """Hammer on an anvil, tuned: a metal ring at a pitch plus the dull thud
    of the blow."""
    f = hz(midi)
    t = _t(1.2)
    ring = modes(t, [(f, 1.0, 4.5), (f * 2.41, 0.5, 7), (f * 3.52, 0.3, 10),
                     (f * 4.93, 0.15, 14)])
    noise = (rng or np.random.default_rng(120)).uniform(-1, 1, t.size)
    thud = smooth(noise, 10) * np.exp(-t * 90) * 0.7 + modes(t, [(140, 0.6, 35)])
    return (np.tanh((ring * 0.6 + thud) * 1.3) * vel * 0.55).astype(np.float32)


def bellows(seconds, rng=None):
    """One push of the bellows: a soft dark whoosh that swells and falls."""
    t = _t(seconds)
    noise = (rng or np.random.default_rng(121)).uniform(-1, 1, t.size)
    air = smooth(noise, 30) - smooth(noise, 300)
    env = np.sin(np.pi * t / seconds) ** 2
    return (air * env * 1.6).astype(np.float32)


def crackle(seconds, density=14, rng=None):
    """Fire: random pops and snaps, plus a low roar."""
    rng = rng or np.random.default_rng(122)
    n = int(seconds * SR)
    out = np.zeros(n, np.float32)
    roar = smooth(rng.uniform(-1, 1, n), 80) * 0.25
    out += roar.astype(np.float32)
    for _ in range(int(seconds * density)):
        s = rng.integers(0, n - 2000)
        t = _t(0.02)
        pop = rng.uniform(-1, 1, t.size) * np.exp(-t * rng.uniform(300, 900))
        out[s:s + t.size] += (pop * rng.uniform(0.1, 0.6)).astype(np.float32)
    return out


def hiss(seconds, rng=None):
    """Steam: bright noise that bursts out and dies away (hot metal quenched)."""
    t = _t(seconds)
    noise = (rng or np.random.default_rng(123)).uniform(-1, 1, t.size)
    bright = noise - smooth(noise, 3)
    env = (1 - np.exp(-t * 40)) * np.exp(-t * 3 / seconds)
    return (bright * env * 0.5).astype(np.float32)


# --- the Upstream ------------------------------------------------------------
def endless_rise(seconds, period=12.0, base=55.0, layers=7, chord=(0, 7)):
    """Shepard tone: stacked octaves all gliding upward; each fades in at the
    bottom and out at the top, so the sound seems to rise forever.
    `chord` adds the same illusion on other notes (in half steps, e.g. a fifth)."""
    t = _t(seconds)
    pos = (t / period) % 1.0
    out = np.zeros_like(t)
    for semis in chord:
        for k in range(layers):
            octave = (k + pos) % layers                     # 0..layers, wraps at the top
            f = base * 2 ** (octave + semis / 12)
            amp = np.exp(-0.5 * ((octave - layers / 2) / (layers / 6)) ** 2)
            out += amp * np.sin(2 * np.pi * np.cumsum(f) / SR)
    return (out / (layers * len(chord)) * 1.5).astype(np.float32)


def sparkle(midi, vel=1.0):
    """Tiny glassy ping, high and short (light glinting off rising ore)."""
    f = hz(midi)
    t = _t(0.9)
    return (modes(t, [(f, 1.0, 5), (f * 2.0, 0.3, 9), (f * 4.2, 0.1, 16)])
            * (1 - np.exp(-t * 800)) * vel * 0.35).astype(np.float32)


# --- lab ---------------------------------------------------------------------
def bubble(rng):
    """One bubble popping up through liquid: a round 'bloop' whose pitch rises."""
    t = _t(0.08)
    f0 = rng.uniform(350, 1100)
    freq = f0 * (1 + 6 * t)                     # rises as the bubble shrinks
    env = np.exp(-t * rng.uniform(40, 70)) * (1 - np.exp(-t * 4000))
    return (np.sin(2 * np.pi * np.cumsum(freq) / SR) * env * 0.4).astype(np.float32)


def bubbling(seconds, rate=6.0, rng=None):
    """A flask on the boil: bubbles in little clusters."""
    rng = rng or np.random.default_rng(180)
    buf = np.zeros((2, int(seconds * SR)), np.float32)
    at = 0.0
    while at < seconds - 0.2:
        for _ in range(rng.integers(1, 4)):
            place(buf, bubble(rng), at + rng.uniform(0, 0.06), rng.uniform(-0.6, 0.6),
                  rng.uniform(0.3, 1.0))
        at += rng.exponential(1 / rate)
    return buf


# --- the depths --------------------------------------------------------------
def bat_chirps(rng):
    """A clockwork bat: 3-5 tiny chirps that swoop down in pitch."""
    out = np.zeros(int(0.5 * SR), np.float32)
    at = 0
    for _ in range(rng.integers(3, 6)):
        t = _t(0.035)
        f = rng.uniform(4500, 6500) * (1 - 0.45 * t / 0.035)
        chirp = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * t / 0.035)
        s = int(at * SR)
        out[s:s + t.size] += (chirp * 0.4).astype(np.float32)
        at += rng.uniform(0.05, 0.09)
    return out


def magma(rng):
    """A slow, heavy bubble of molten rock: low, thick 'blorp'."""
    t = _t(0.35)
    f0 = rng.uniform(70, 140)
    freq = f0 * (1 + 2.5 * t)
    env = np.exp(-t * 9) * (1 - np.exp(-t * 300))
    body = np.sin(2 * np.pi * np.cumsum(freq) / SR) + 0.3 * np.sin(4 * np.pi * np.cumsum(freq) / SR)
    return (np.tanh(body * env * 1.5) * 0.6).astype(np.float32)


def groan_source(seconds, start_midi=40, drop=5, rng=None):
    """Something huge, far below: a buzzing voice sliding down. Run it
    through formant(..., 'oo') to make it a groan."""
    rng = rng or np.random.default_rng(210)
    t = _t(seconds)
    buf = np.zeros((2, t.size), np.float32)
    for _ in range(4):
        m = start_midi - drop * (t / seconds) ** 0.7 + rng.normal(0, 0.15)
        f = hz(m) * (1 + 0.01 * np.sin(2 * np.pi * rng.uniform(2, 3.5) * t))
        saw = 2 * ((np.cumsum(f) / SR + rng.uniform()) % 1) - 1
        env = np.sin(np.pi * t / seconds) ** 1.5
        place(buf, (saw * env * 0.3).astype(np.float32), 0, rng.uniform(-0.5, 0.5))
    return buf
