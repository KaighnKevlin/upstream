"""Surge XT sound designs, one function per part.

Surge exposes many settings as strings ("250.0 ms", "7 voices"), so `put`
snaps a number to the nearest valid value instead of making callers spell
the exact string. Times are given in milliseconds: Surge mixes "ms" and "s"
labels on one setting, so units are converted before comparing (without
that, 30 ms snapped to "30.04 s").
"""
import re

_NUM = re.compile(r"(-?\d+(?:\.\d+)?)\s*(ms|s|kHz|Hz)?\b")
_SCALE = {"s": 1000.0, "kHz": 1000.0}


def _value(label):
    m = _NUM.search(label)
    return float(m.group(1)) * _SCALE.get(m.group(2), 1.0) if m else None


def put(synth, key, value):
    p = synth.parameters[key]
    if isinstance(value, (int, float)) and p.valid_values and isinstance(p.valid_values[0], str):
        nums = [(abs(_value(v) - value), v) for v in p.valid_values if _value(v) is not None]
        value = min(nums)[1]
    setattr(synth, key, value)


def apply(synth, settings):
    for k, v in settings.items():
        put(synth, k, v)


# Classic oscillator shape: -100 triangle-ish, 0 saw, +100 square.
def setup_pad(s):
    """Warm, wide, slow-breathing chords."""
    apply(s, {
        "a_osc_1_type": "Classic", "a_osc_1_shape": 0.0,
        "a_osc_1_unison_voices": 7, "a_osc_1_unison_detune": 14,
        "a_osc_2_mute": False, "a_osc_2_type": "Classic", "a_osc_2_shape": -80.0,
        "a_osc_2_octave": -1.0, "a_osc_2_volume": -6.0,
        "a_osc_drift": 40.0,
        "a_filter_1_type": "LP 24 dB", "a_filter_1_cutoff": 1100.0,
        "a_filter_1_resonance": 10.0,
        "a_amp_eg_attack": 900, "a_amp_eg_decay": 1000,
        "a_amp_eg_sustain": 85.0, "a_amp_eg_release": 2200,
        "a_volume": -8.0,
    })


def setup_arp(s):
    """Plucky retro square: the ticking machinery."""
    apply(s, {
        "a_osc_1_type": "Classic", "a_osc_1_shape": 100.0,
        "a_filter_1_type": "LP 12 dB", "a_filter_1_cutoff": 1400.0,
        "a_filter_1_resonance": 25.0,
        "a_filter_1_feg_mod_amount": 30,
        "a_filter_eg_attack": 0, "a_filter_eg_decay": 160,
        "a_filter_eg_sustain": 0.0, "a_filter_eg_release": 100,
        "a_amp_eg_attack": 0, "a_amp_eg_decay": 220,
        "a_amp_eg_sustain": 0.0, "a_amp_eg_release": 120,
        "a_volume": -8.0,
    })


def setup_bass(s):
    """Round, slightly growly mono bass."""
    apply(s, {
        "a_play_mode": "Mono",
        "a_osc_1_type": "Classic", "a_osc_1_shape": 0.0,
        "a_osc_2_mute": False, "a_osc_2_type": "Sine", "a_osc_2_octave": -1.0,
        "a_osc_2_volume": -3.0,
        "a_filter_1_type": "LP 24 dB", "a_filter_1_cutoff": 450.0,
        "a_filter_1_resonance": 20.0, "a_filter_1_feg_mod_amount": 24,
        "a_filter_eg_attack": 0, "a_filter_eg_decay": 200,
        "a_filter_eg_sustain": 10.0,
        "a_amp_eg_attack": 2, "a_amp_eg_decay": 300,
        "a_amp_eg_sustain": 60.0, "a_amp_eg_release": 80,
        "a_volume": -6.0,
    })


def setup_lead(s):
    """Hollow, slightly detuned melody voice."""
    apply(s, {
        "a_osc_1_type": "Classic", "a_osc_1_shape": 60.0,
        "a_osc_1_unison_voices": 2, "a_osc_1_unison_detune": 8,
        "a_osc_drift": 30.0,
        "a_filter_1_type": "LP 24 dB", "a_filter_1_cutoff": 2200.0,
        "a_filter_1_resonance": 15.0,
        "a_amp_eg_attack": 40, "a_amp_eg_decay": 400,
        "a_amp_eg_sustain": 80.0, "a_amp_eg_release": 700,
        "a_volume": -8.0,
    })


def setup_cave_pad(s):
    """Darker, slower pad for Factory: swells open like a brass section far away."""
    apply(s, {
        "a_osc_1_type": "Classic", "a_osc_1_shape": 0.0,
        "a_osc_1_unison_voices": 5, "a_osc_1_unison_detune": 10,
        "a_osc_2_mute": False, "a_osc_2_type": "Classic", "a_osc_2_shape": -100.0,
        "a_osc_2_octave": -1.0, "a_osc_2_volume": -4.0,
        "a_osc_drift": 50.0,
        "a_filter_1_type": "LP 24 dB", "a_filter_1_cutoff": 650.0,
        "a_filter_1_resonance": 8.0, "a_filter_1_feg_mod_amount": 18,
        "a_filter_eg_attack": 1800, "a_filter_eg_decay": 2500,
        "a_filter_eg_sustain": 40.0, "a_filter_eg_release": 2000,
        "a_amp_eg_attack": 1200, "a_amp_eg_decay": 1500,
        "a_amp_eg_sustain": 85.0, "a_amp_eg_release": 2500,
        "a_volume": -8.0,
    })


def setup_soft_bass(s):
    """Round, gentle bass: mostly sine, a touch of edge."""
    apply(s, {
        "a_play_mode": "Mono",
        "a_osc_1_type": "Classic", "a_osc_1_shape": -100.0, "a_osc_1_volume": -6.0,
        "a_osc_2_mute": False, "a_osc_2_type": "Sine", "a_osc_2_octave": 0.0,
        "a_osc_2_volume": 0.0,
        "a_filter_1_type": "LP 24 dB", "a_filter_1_cutoff": 380.0,
        "a_filter_1_resonance": 10.0,
        "a_amp_eg_attack": 15, "a_amp_eg_decay": 600,
        "a_amp_eg_sustain": 70.0, "a_amp_eg_release": 250,
        "a_volume": -6.0,
    })


def setup_siege_drone(s):
    """Dark, buzzing low chords with a slow throb in the filter."""
    apply(s, {
        "a_osc_1_type": "Classic", "a_osc_1_shape": 0.0,
        "a_osc_1_unison_voices": 5, "a_osc_1_unison_detune": 18,
        "a_osc_2_mute": False, "a_osc_2_type": "Classic", "a_osc_2_shape": 0.0,
        "a_osc_2_octave": -1.0, "a_osc_2_volume": -3.0,
        "a_osc_drift": 30.0,
        "a_filter_1_type": "LP 24 dB", "a_filter_1_cutoff": 900.0,
        "a_filter_1_resonance": 30.0,
        "a_amp_eg_attack": 300, "a_amp_eg_decay": 1000,
        "a_amp_eg_sustain": 90.0, "a_amp_eg_release": 900,
        "a_volume": -8.0,
    })


def setup_siege_lead(s):
    """Brassy, slightly snarling melody: a war horn made of saw waves."""
    apply(s, {
        "a_osc_1_type": "Classic", "a_osc_1_shape": 0.0,
        "a_osc_1_unison_voices": 3, "a_osc_1_unison_detune": 12,
        "a_osc_drift": 20.0,
        "a_filter_1_type": "LP 24 dB", "a_filter_1_cutoff": 1500.0,
        "a_filter_1_resonance": 20.0, "a_filter_1_feg_mod_amount": 24,
        "a_filter_eg_attack": 60, "a_filter_eg_decay": 500,
        "a_filter_eg_sustain": 30.0, "a_filter_eg_release": 300,
        "a_amp_eg_attack": 30, "a_amp_eg_decay": 400,
        "a_amp_eg_sustain": 85.0, "a_amp_eg_release": 400,
        "a_volume": -8.0,
    })
