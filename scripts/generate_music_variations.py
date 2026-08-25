#!/usr/bin/env python3
"""Render eight loopable leitmotif arrangements for the Godot prototype.

The score keeps one five-note identity, but it does not keep one backing track.
All seasons draw from the same C-D-E-G-A pitch field and place a different note
at the centre: spring/E, summer/G, autumn/D and winter/A.  The hive can therefore
return to C without treating the five-tone idea as five Western key labels.

No samples or third-party packages are required.  Every sound is synthesized,
the output is deterministic 44.1 kHz stereo PCM, and every duration is derived
from an integer number of bars.
"""

from __future__ import annotations

import argparse
import math
import random
import struct
import wave
from array import array
from dataclasses import dataclass
from pathlib import Path


RATE = 44_100
TAU = math.tau
TABLE_SIZE = 16_384
ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "godot" / "assets" / "music"
PENTATONIC = (0, 2, 4, 7, 9)  # 宫、商、角、徵、羽 over C
SINE_TABLE = tuple(math.sin(TAU * index / TABLE_SIZE) for index in range(TABLE_SIZE))


@dataclass(frozen=True)
class TrackSpec:
    name: str
    bpm: float  # quarter-note BPM; compound-meter pulse is noted in description
    numerator: int
    denominator: int
    bars: int
    centre_degree: int
    description: str
    boss: bool = False

    @property
    def quarter_beats_per_bar(self) -> float:
        return self.numerator * 4.0 / self.denominator

    @property
    def total_quarter_beats(self) -> float:
        return self.bars * self.quarter_beats_per_bar

    @property
    def duration(self) -> float:
        return self.total_quarter_beats * 60.0 / self.bpm


TRACKS = {
    "spring_explore": TrackSpec(
        "spring_explore", 104.0, 4, 4, 12, 2,
        "wood-electronic chamber folk, 3+3+2 pulse and sparse synthesized dizi turns",
    ),
    "spring_boss": TrackSpec(
        "spring_boss", 148.0, 4, 4, 16, 2,
        "wing-beat breakbeat with clipped spring cadences", True,
    ),
    "summer_explore": TrackSpec(
        "summer_explore", 116.0, 4, 4, 12, 3,
        "syncopated funk with hocketed gathering motif",
    ),
    "summer_boss": TrackSpec(
        "summer_boss", 172.0, 4, 4, 16, 3,
        "stop-time punk with clipped synthesized dizi punctuation", True,
    ),
    "autumn_explore": TrackSpec(
        "autumn_explore", 124.0, 4, 4, 16, 1,
        "amber-circuit electro-funk with antiphonal stepped hooks, sparse seed pickups and four-bar air gaps",
    ),
    "autumn_boss": TrackSpec(
        "autumn_boss", 128.0, 4, 4, 16, 1,
        "post-punk dub lure with finite echo taps and stop-time industrial counterphrases", True,
    ),
    "winter_explore": TrackSpec(
        "winter_explore", 108.0, 6, 8, 16, 4,
        "warm sparse six-eight pulse with two synthesized xiao-like breaths (dotted-quarter = 72)",
    ),
    "winter_boss": TrackSpec(
        "winter_boss", 96.0, 4, 4, 12, 4,
        "half-time rock with charge, silence and collision", True,
    ),
}

MACRO_GAINS = {
    "spring_explore": (0.72, 1.00, 0.84),
    "spring_boss": (0.74, 0.94, 1.00, 0.80),
    "summer_explore": (0.76, 1.00, 0.86),
    "summer_boss": (0.84, 1.00, 0.76, 0.94),
    "autumn_explore": (0.84, 1.00, 0.90, 0.82),
    "autumn_boss": (0.88, 1.00, 0.94, 0.84),
    "winter_explore": (0.66, 0.82, 1.00, 0.74),
    "winter_boss": (0.74, 1.00, 0.84),
}

PEAK_TARGETS = {
    "spring_explore": 0.80,
    "summer_explore": 0.80,
    "autumn_explore": 0.70,
    "winter_explore": 0.62,
    "spring_boss": 0.86,
    "summer_boss": 0.86,
    "autumn_boss": 0.76,
    "winter_boss": 0.86,
}

# These two roles were selected in a dedicated direction gate.  Loudness is
# normalized after the common peak/loop finishing pass so a louder crest does
# not win the final A/B merely because it was rendered hotter.
AUTUMN_LOUDNESS_TARGETS = {
    "autumn_explore": -17.3,
    "autumn_boss": -18.7,
}

# A machine-readable arrangement contract keeps the selected hierarchy honest:
# Z's post-punk/dub backbone is present in all 16 bars and receives nine full
# bars; T is a seven-bar upper counterphrase, including only the final bar of
# the closure.  Tests import this contract instead of trusting prose comments.
AUTUMN_BOSS_STRUCTURE = {
    "z_backbone_bars": tuple(range(16)),
    "z_full_bars": (0, 1, 2, 3, 8, 10, 12, 13, 14),
    "t_counter_bars": (4, 5, 6, 7, 9, 11, 15),
    "dub_send_bars": (0, 2, 8, 12),
}


# Every oscillator uses genuine upper partials.  In particular there is no
# 0.5-frequency component: bass comes from a written bass note, not a permanent
# artificial sub-octave hidden inside every string voice.
INSTRUMENTS = {
    "wood": ((1.0, 0.78), (2.0, 0.15), (3.0, 0.07), 0.004, 0.055, 0.18, 0.02),
    "mallet": ((1.0, 0.70), (2.01, 0.18), (3.98, 0.12), 0.002, 0.050, 0.20, 0.01),
    "buzz": ((1.0, 0.40), (2.0, 0.22), (3.0, 0.16), (5.0, 0.13), (7.0, 0.09), 0.003, 0.035, 0.11, 0.03),
    "muted": ((1.0, 0.58), (2.0, 0.23), (3.0, 0.12), (4.0, 0.07), 0.003, 0.045, 0.12, 0.03),
    "clav": ((1.0, 0.48), (2.0, 0.24), (3.0, 0.17), (5.0, 0.11), 0.002, 0.035, 0.09, 0.02),
    "pizz": ((1.0, 0.72), (2.0, 0.18), (3.0, 0.10), 0.004, 0.070, 0.24, 0.04),
    "metal": ((1.0, 0.48), (2.45, 0.28), (4.05, 0.16), (6.10, 0.08), 0.002, 0.080, 0.24, 0.00),
    "echo": ((1.0, 0.52), (2.0, 0.17), (3.0, 0.13), (4.0, 0.10), (6.0, 0.08), 0.008, 0.100, 0.30, 0.04),
    "ice": ((1.0, 0.42), (2.65, 0.28), (4.05, 0.20), (6.20, 0.10), 0.002, 0.090, 0.18, 0.00),
    "warm": ((1.0, 0.74), (2.0, 0.17), (3.0, 0.09), 0.012, 0.100, 0.34, 0.06),
    "bass": ((1.0, 0.78), (2.0, 0.16), (3.0, 0.06), 0.004, 0.060, 0.17, 0.10),
    "bass_pick": ((1.0, 0.56), (2.0, 0.23), (3.0, 0.13), (4.0, 0.08), 0.002, 0.035, 0.10, 0.01),
    "rock": ((1.0, 0.34), (2.0, 0.23), (3.0, 0.16), (4.0, 0.11), (5.0, 0.09), (7.0, 0.07), 0.003, 0.045, 0.22, 0.22),
}


class StereoBuffer:
    def __init__(self, frames: int) -> None:
        self.frames = frames
        self.left = array("f", [0.0]) * frames
        self.right = array("f", [0.0]) * frames


VOICE_CACHE: dict[tuple[str, int, int], array] = {}


def penta_midi(degree: int, base_c: int = 60) -> int:
    """Return a MIDI note for an arbitrarily rotated five-tone degree."""
    octave, index = divmod(degree, len(PENTATONIC))
    return base_c + PENTATONIC[index] + octave * 12


def midi_hz(note: float) -> float:
    return 440.0 * (2.0 ** ((note - 69.0) / 12.0))


def _render_voice(instrument: str, midi_note: float, frames: int) -> array:
    key = (instrument, round(midi_note * 100), frames)
    cached = VOICE_CACHE.get(key)
    if cached is not None:
        return cached

    *partial_entries, attack, release, decay_seconds, sustain = INSTRUMENTS[instrument]
    partials = tuple(partial_entries)
    result = array("f", [0.0]) * frames
    frequency = midi_hz(midi_note)
    phase = 0.0
    phase_step = frequency * TABLE_SIZE / RATE
    attack_frames = max(1, round(attack * RATE))
    release_frames = max(1, round(release * RATE))
    decay_value = 1.0
    decay_step = math.exp(-1.0 / max(1.0, decay_seconds * RATE))
    nyquist = RATE * 0.49
    active_partials = tuple((ratio, gain) for ratio, gain in partials if frequency * ratio < nyquist)

    for index in range(frames):
        attack_gain = min(1.0, index / attack_frames)
        release_gain = min(1.0, (frames - 1 - index) / release_frames)
        decay_gain = sustain + (1.0 - sustain) * decay_value
        value = 0.0
        for ratio, partial_gain in active_partials:
            table_index = int(phase * ratio) % TABLE_SIZE
            value += SINE_TABLE[table_index] * partial_gain
        result[index] = value * attack_gain * release_gain * decay_gain
        phase += phase_step
        if phase >= TABLE_SIZE * 256:
            phase %= TABLE_SIZE
        decay_value *= decay_step

    VOICE_CACHE[key] = result
    return result


def _pan_gains(pan: float) -> tuple[float, float]:
    angle = (max(-1.0, min(1.0, pan)) + 1.0) * math.pi * 0.25
    return math.cos(angle), math.sin(angle)


def add_note(buffer: StereoBuffer, spec: TrackSpec, start_q: float, length_q: float,
             midi_note: float, gain: float, instrument: str, pan: float = 0.0) -> None:
    start = round(start_q * 60.0 / spec.bpm * RATE)
    frames = max(2, round(length_q * 60.0 / spec.bpm * RATE))
    if start >= buffer.frames or start + frames <= 0:
        return
    voice = _render_voice(instrument, midi_note, frames)
    left_gain, right_gain = _pan_gains(pan)
    first = max(0, -start)
    last = min(frames, buffer.frames - start)
    left = buffer.left
    right = buffer.right
    for local in range(first, last):
        value = voice[local] * gain
        target = start + local
        left[target] += value * left_gain
        right[target] += value * right_gain


def add_dyad(buffer: StereoBuffer, spec: TrackSpec, start_q: float, length_q: float,
             degrees: tuple[int, int], gain: float, instrument: str, pan: float = 0.0,
             octave: int = 0) -> None:
    add_note(buffer, spec, start_q, length_q, penta_midi(degrees[0] + octave * 5), gain, instrument, pan - 0.12)
    add_note(buffer, spec, start_q, length_q, penta_midi(degrees[1] + octave * 5), gain * 0.86, instrument, pan + 0.12)


def add_bass_hit(buffer: StereoBuffer, spec: TrackSpec, start_q: float, midi_note: float,
                 gain: float, length_q: float = 0.30, pan: float = 0.0) -> None:
    """Layer a written bass note with a brief upper-octave pick transient.

    The upper layer makes the rhythm readable on small speakers without turning
    the entire arrangement into a louder low-frequency carpet.
    """
    add_note(buffer, spec, start_q, length_q, midi_note, gain, "bass", pan)
    add_note(buffer, spec, start_q, min(length_q * 0.52, 0.16), midi_note + 12.0,
             gain * 0.24, "bass_pick", pan + 0.05)


def add_noise_hit(buffer: StereoBuffer, spec: TrackSpec, start_q: float, length: float,
                  gain: float, seed: int, pan: float = 0.0, colour: str = "bright") -> None:
    start = round(start_q * 60.0 / spec.bpm * RATE)
    frames = max(2, round(length * RATE))
    rng = random.Random(seed)
    left_gain, right_gain = _pan_gains(pan)
    previous = 0.0
    for local in range(frames):
        target = start + local
        if target < 0 or target >= buffer.frames:
            continue
        attack = min(1.0, local / max(1, round(0.0015 * RATE)))
        decay = (1.0 - local / frames) ** (3.0 if colour == "bright" else 2.0)
        raw = rng.uniform(-1.0, 1.0)
        if colour == "bright":
            sample = raw - previous * 0.92
        else:
            sample = raw * 0.58 + previous * 0.42
        previous = raw
        value = sample * attack * decay * gain
        buffer.left[target] += value * left_gain
        buffer.right[target] += value * right_gain


def add_hat(buffer: StereoBuffer, spec: TrackSpec, start_q: float, gain: float,
            seed: int, pan: float = 0.0, is_open: bool = False) -> None:
    """Add a deliberately synthetic open/closed hat articulation."""
    length = 0.115 if is_open else 0.032
    add_noise_hit(buffer, spec, start_q, length, gain, seed, pan, "bright")
    if is_open:
        add_note(buffer, spec, start_q, 0.15, 102.0, gain * 0.13, "metal", pan * 0.65)


def add_rim(buffer: StereoBuffer, spec: TrackSpec, start_q: float, gain: float,
            seed: int, pan: float = 0.0) -> None:
    """Add a short rim/woodblock accent, useful for ghost-note hierarchy."""
    add_noise_hit(buffer, spec, start_q, 0.024, gain * 0.62, seed, pan, "bright")
    add_note(buffer, spec, start_q, 0.075, 86.0, gain, "wood", pan)


GESTURE_VOICES = {
    # These are sound-design gestures, not sampled instruments.  The names
    # describe articulation and register: breathy attack for dizi/xiao, bowed
    # portamento and delayed vibrato for erhu.
    "dizi": (((1.0, 0.68), (2.0, 0.09), (3.0, 0.15), (5.0, 0.08)), 0.018, 0.075, 0.105, 5.7, 0.10),
    "xiao": (((1.0, 0.82), (2.0, 0.05), (3.0, 0.09), (5.0, 0.04)), 0.060, 0.135, 0.125, 4.8, 0.08),
    "erhu": (((1.0, 0.52), (2.0, 0.24), (3.0, 0.13), (4.0, 0.07), (5.0, 0.04)), 0.035, 0.110, 0.055, 5.4, 0.21),
}


def add_gesture_lead(buffer: StereoBuffer, spec: TrackSpec, start_q: float, length_q: float,
                     midi_start: float, midi_end: float, gain: float, voice: str,
                     seed: int, pan: float = 0.0) -> None:
    """Synthesize one sparse breath/bow gesture with portamento and vibrato.

    It intentionally avoids a General MIDI imitation.  Only the timing,
    register and motion allude to a dizi, xiao or erhu articulation.
    """
    start = round(start_q * 60.0 / spec.bpm * RATE)
    frames = max(2, round(length_q * 60.0 / spec.bpm * RATE))
    partials, attack_seconds, release_seconds, noise_gain, vibrato_rate, vibrato_depth = GESTURE_VOICES[voice]
    attack_frames = max(1, round(attack_seconds * RATE))
    release_frames = max(1, round(release_seconds * RATE))
    rng = random.Random(seed)
    left_gain, right_gain = _pan_gains(pan)
    phase = 0.0
    previous_noise = 0.0
    for local in range(frames):
        target = start + local
        if target < 0 or target >= buffer.frames:
            continue
        progress = local / max(1, frames - 1)
        glide = progress * progress * (3.0 - 2.0 * progress)
        vibrato_ramp = max(0.0, min(1.0, (progress - 0.22) / 0.22))
        vibrato = math.sin(TAU * vibrato_rate * local / RATE) * vibrato_depth * vibrato_ramp
        note = midi_start + (midi_end - midi_start) * glide + vibrato
        phase += midi_hz(note) * TABLE_SIZE / RATE
        tonal = 0.0
        for ratio, partial_gain in partials:
            if midi_hz(note) * ratio < RATE * 0.49:
                tonal += SINE_TABLE[int(phase * ratio) % TABLE_SIZE] * partial_gain
        raw_noise = rng.uniform(-1.0, 1.0)
        if voice == "dizi":
            breath = raw_noise - previous_noise * 0.90
        else:
            breath = raw_noise * 0.28 + previous_noise * 0.72
        previous_noise = raw_noise
        attack = min(1.0, local / attack_frames)
        release = min(1.0, (frames - 1 - local) / release_frames)
        envelope = attack * release
        value = (tonal + breath * noise_gain) * envelope * gain
        buffer.left[target] += value * left_gain
        buffer.right[target] += value * right_gain


def add_kick(buffer: StereoBuffer, spec: TrackSpec, start_q: float, gain: float = 0.18) -> None:
    start = round(start_q * 60.0 / spec.bpm * RATE)
    frames = round(0.145 * RATE)
    phase = 0.0
    for local in range(frames):
        target = start + local
        if target < 0 or target >= buffer.frames:
            continue
        progress = local / frames
        frequency = 112.0 * ((54.0 / 112.0) ** progress)
        phase += TAU * frequency / RATE
        attack = min(1.0, local / max(1, round(0.0015 * RATE)))
        body = math.sin(phase) + math.sin(phase * 2.0) * 0.14
        click = math.sin(TAU * 1650.0 * local / RATE) * math.exp(-58.0 * progress) * 0.13
        value = (body * math.exp(-6.0 * progress) + click) * attack * gain
        buffer.left[target] += value * 0.707
        buffer.right[target] += value * 0.707


def add_snare(buffer: StereoBuffer, spec: TrackSpec, start_q: float, gain: float, seed: int) -> None:
    add_noise_hit(buffer, spec, start_q, 0.105, gain, seed, 0.08, "bright")
    add_noise_hit(buffer, spec, start_q + 0.035, 0.055, gain * 0.24, seed + 1, -0.16, "bright")
    add_note(buffer, spec, start_q, 0.18, 50.0, gain * 0.42, "muted", -0.06)


def add_tom(buffer: StereoBuffer, spec: TrackSpec, start_q: float, midi_note: float,
            gain: float, pan: float = 0.0) -> None:
    add_note(buffer, spec, start_q, 0.20, midi_note, gain, "muted", pan)


def mix_buffer(target: StereoBuffer, source: StereoBuffer, gain: float = 1.0) -> None:
    for index in range(target.frames):
        target.left[index] += source.left[index] * gain
        target.right[index] += source.right[index] * gain


def _autumn_envelope(index: int, frames: int, attack: float, release: float,
                     decay: float, sustain: float) -> float:
    attack_frames = max(1, round(attack * RATE))
    release_frames = max(1, round(release * RATE))
    attack_gain = min(1.0, index / attack_frames)
    release_gain = min(1.0, (frames - 1 - index) / release_frames)
    decay_gain = sustain + (1.0 - sustain) * math.exp(-index / max(1.0, decay * RATE))
    return attack_gain * release_gain * decay_gain


def add_autumn_voice(buffer: StereoBuffer, spec: TrackSpec, start_q: float,
                     length_q: float, note: float, gain: float, voice: str,
                     seed: int, pan: float = 0.0) -> None:
    """Add a stepped-pitch autumn voice without portamento or a held drone."""
    start = round(start_q * 60.0 / spec.bpm * RATE)
    frames = max(2, round(length_q * 60.0 / spec.bpm * RATE))
    if start >= buffer.frames:
        return
    left_gain, right_gain = _pan_gains(pan)
    phase = 0.0
    phase_step = TAU * midi_hz(note) / RATE
    rng = random.Random(seed + start + round(note * 17))
    low_state = 0.0

    for local in range(min(frames, buffer.frames - start)):
        if voice == "amber_gate":
            env = _autumn_envelope(local, frames, 0.002, 0.035, 0.12, 0.03)
            mod = math.sin(phase * 2.0) * 1.35 * math.exp(-local / max(1.0, RATE * 0.08))
            raw = 0.78 * math.sin(phase + mod) + 0.22 * math.sin(phase * 3.0)
        elif voice == "husk_bass":
            env = _autumn_envelope(local, frames, 0.003, 0.055, 0.16, 0.18)
            raw = 0.72 * math.sin(phase) + 0.20 * math.sin(phase * 2.0) + 0.08 * math.sin(phase * 3.0)
            low_state += 0.18 * (raw - low_state)
            raw = math.tanh(low_state * 1.25)
        elif voice == "dry_chord":
            env = _autumn_envelope(local, frames, 0.002, 0.040, 0.11, 0.04)
            raw = math.tanh(1.35 * (0.58 * math.sin(phase) + 0.26 * math.sin(phase * 2.0) + 0.16 * math.sin(phase * 4.0)))
        elif voice == "wire_pick":
            env = _autumn_envelope(local, frames, 0.001, 0.035, 0.09, 0.025)
            raw = math.tanh(1.8 * (0.45 * math.sin(phase) + 0.27 * math.sin(phase * 3.0)
                                   + 0.18 * math.sin(phase * 7.0) + 0.10 * math.sin(phase * 11.0)))
        elif voice == "dub_stab":
            env = _autumn_envelope(local, frames, 0.004, 0.070, 0.18, 0.06)
            raw = 0.60 * math.sin(phase) + 0.24 * math.sin(phase * 2.0) + 0.16 * math.sin(phase * 4.0)
            low_state += 0.10 * (raw - low_state)
            raw = low_state
        elif voice == "iron_pulse":
            env = _autumn_envelope(local, frames, 0.001, 0.030, 0.12, 0.025)
            raw = math.tanh(2.2 * (0.32 * math.sin(phase) + 0.27 * math.sin(phase * 2.0)
                                   + 0.20 * math.sin(phase * 4.0) + 0.13 * math.sin(phase * 9.0)
                                   + 0.08 * math.sin(phase * 13.0)))
        elif voice == "rust_bell":
            env = _autumn_envelope(local, frames, 0.001, 0.080, 0.14, 0.0)
            raw = 0.52 * math.sin(phase) + 0.31 * math.sin(phase * 2.71) + 0.17 * math.sin(phase * 4.19)
        else:
            raise ValueError(f"unknown autumn voice: {voice}")

        if voice in {"wire_pick", "iron_pulse"} and local < RATE * 0.012:
            raw += rng.uniform(-1.0, 1.0) * 0.055 * (1.0 - local / (RATE * 0.012))
        value = raw * env * gain
        target = start + local
        buffer.left[target] += value * left_gain
        buffer.right[target] += value * right_gain
        phase += phase_step


def add_autumn_chord(buffer: StereoBuffer, spec: TrackSpec, start_q: float,
                     length_q: float, notes: tuple[int, ...], gain: float,
                     voice: str, seed: int, pan: float = 0.0) -> None:
    spread = 0.14
    divisor = math.sqrt(len(notes))
    for index, note in enumerate(notes):
        offset = (index - (len(notes) - 1) / 2.0) * spread
        add_autumn_voice(buffer, spec, start_q, length_q, note, gain / divisor,
                         voice, seed + index * 37, pan + offset)


def add_autumn_dub_reply(buffer: StereoBuffer, spec: TrackSpec, start_q: float,
                         notes: tuple[int, ...], gain: float, seed: int,
                         latest_q: float) -> None:
    """Write one dry lure and three finite, tempo-locked dark replies."""
    add_autumn_chord(buffer, spec, start_q, 0.34, notes, gain, "dub_stab", seed)
    for tap, (offset, tap_gain, pan) in enumerate((
        (0.75, 0.44, -0.46),
        (1.50, 0.25, 0.42),
        (2.25, 0.13, -0.24),
    )):
        if start_q + offset < latest_q:
            add_autumn_chord(buffer, spec, start_q + offset, 0.22, notes,
                             gain * tap_gain, "dub_stab", seed + 100 + tap * 17, pan)


def bar_start(spec: TrackSpec, bar: int) -> float:
    return bar * spec.quarter_beats_per_bar


def render_spring_explore(spec: TrackSpec) -> StereoBuffer:
    buffer = StereoBuffer(round(spec.duration * RATE))
    motif = (2, 3, 4, 5, 4)
    response = (4, 5, 6, 7, 6)
    for bar in range(spec.bars):
        base = bar_start(spec, bar)
        add_kick(buffer, spec, base, 0.065)
        if bar % 2 == 0:
            add_kick(buffer, spec, base + 2.5, 0.043)
        add_rim(buffer, spec, base + 1.5, 0.024, 900 + bar, -0.22)
        for accent, position in enumerate((0.0, 1.5, 3.0)):
            add_note(buffer, spec, base + position, 0.22, penta_midi(7 + accent % 2), 0.075, "wood", -0.30 + accent * 0.30)
        for step in range(8):
            if step in (2, 5):
                continue
            add_noise_hit(buffer, spec, base + step * 0.5, 0.035, 0.020 if step else 0.032,
                          1000 + bar * 16 + step, 0.35, "bright")
        add_bass_hit(buffer, spec, base, penta_midi(2 - 5), 0.085, 0.52)
        if bar % 2 == 0:
            add_bass_hit(buffer, spec, base + 2.5, penta_midi(0 - 5), 0.065, 0.38)
        if bar % 4 == 3:
            add_gesture_lead(buffer, spec, base + 2.92, 0.70, penta_midi(7), penta_midi(8),
                             0.052, "dizi", 1200 + bar, 0.34)
        else:
            add_dyad(buffer, spec, base + 3.0, 0.28, (2, 4), 0.046, "mallet", -0.08)
        degrees = motif if bar % 2 == 0 else response
        positions = (0.25, 0.75, 1.25, 2.0, 2.75)
        instrument = "wood" if bar % 2 == 0 else "mallet"
        pan = -0.42 if bar % 2 == 0 else 0.42
        for index, (position, degree) in enumerate(zip(positions, degrees)):
            add_note(buffer, spec, base + position, 0.30 if index < 4 else 0.46,
                     penta_midi(degree), 0.105, instrument, pan)
    return buffer


def render_spring_boss(spec: TrackSpec) -> StereoBuffer:
    buffer = StereoBuffer(round(spec.duration * RATE))
    clipped = (2, 3, 4)
    for bar in range(spec.bars):
        base = bar_start(spec, bar)
        final_stop = bar % 4 == 3
        for position in ((0.0, 1.5, 2.75) if not final_stop else (0.0, 1.5)):
            add_kick(buffer, spec, base + position, 0.13)
        for position in (1.0, 3.0):
            if final_stop and position >= 3.0:
                continue
            add_snare(buffer, spec, base + position, 0.120, 2100 + bar * 8 + int(position * 2))
        for step in range(8):
            position = step * 0.5
            if final_stop and position >= 2.5:
                continue
            add_hat(buffer, spec, base + position, 0.042, 2200 + bar * 16 + step,
                    -0.35 if step % 2 else 0.35, step == 7)
        if not final_stop and bar % 2 == 1:
            add_rim(buffer, spec, base + 2.5, 0.028, 2250 + bar, 0.30)
        for position, degree in ((0.0, 2 - 5), (0.75, 3 - 5), (1.5, 2 - 5), (2.5, 0 - 5)):
            if final_stop and position >= 2.5:
                continue
            add_bass_hit(buffer, spec, base + position, penta_midi(degree), 0.055, 0.30)
        for index, degree in enumerate(clipped):
            position = (0.25, 0.75, 1.25)[index]
            add_note(buffer, spec, base + position, 0.23, penta_midi(degree + 5), 0.150, "buzz", -0.30)
            if bar % 4 == 2 and index == 1:
                add_note(buffer, spec, base + position + 0.12, 0.16, penta_midi(degree + 5) + 1, 0.055, "buzz", 0.38)
        if not final_stop:
            add_dyad(buffer, spec, base + 2.0, 0.22, (2, 4), 0.080, "rock", 0.12, -1)
    return buffer


def render_summer_explore(spec: TrackSpec) -> StereoBuffer:
    buffer = StereoBuffer(round(spec.duration * RATE))
    motif = (3, 4, 5, 6, 5)
    for bar in range(spec.bars):
        base = bar_start(spec, bar)
        for position in (0.0, 1.5, 2.75):
            add_kick(buffer, spec, base + position, 0.14)
        if bar % 2 == 1:
            add_kick(buffer, spec, base + 3.5, 0.058)
        for position in (1.0, 3.0):
            add_snare(buffer, spec, base + position, 0.090, 3000 + bar * 8 + int(position))
        for ghost_index, position in enumerate((0.75, 2.75)):
            add_rim(buffer, spec, base + position, 0.026, 3050 + bar * 4 + ghost_index,
                    -0.28 if ghost_index == 0 else 0.28)
        for step in range(16):
            position = step * 0.25 + (0.055 if step % 2 else 0.0)
            add_hat(buffer, spec, base + position, 0.018 if step % 4 else 0.030,
                    3100 + bar * 32 + step, -0.26 if step % 2 else 0.26, step in (7, 15))
        for position, degree in ((0.0, 3 - 5), (0.75, 4 - 5), (1.5, 3 - 5), (2.25, 5 - 5), (3.5, 4 - 5)):
            add_bass_hit(buffer, spec, base + position, penta_midi(degree), 0.085, 0.28)
        for position in (0.5, 1.75, 2.5, 3.25):
            degree = 3 if int(position * 4) % 2 == 0 else 4
            add_dyad(buffer, spec, base + position, 0.17, (degree, degree + 2), 0.063,
                     "muted", 0.35 if position < 2.0 else -0.35)
        for index, degree in enumerate(motif):
            position = (0.25, 0.875, 1.625, 2.625, 3.375)[index]
            add_note(buffer, spec, base + position, 0.19, penta_midi(degree + 5), 0.083,
                     "clav" if index % 2 == 0 else "mallet", -0.48 if index % 2 == 0 else 0.48)
    return buffer


def render_summer_boss(spec: TrackSpec) -> StereoBuffer:
    buffer = StereoBuffer(round(spec.duration * RATE))
    jump_motif = (3, 6, 4, 7, 5)
    for bar in range(spec.bars):
        base = bar_start(spec, bar)
        stop_bar = bar % 4 == 3
        for position in (0.0, 2.0, 2.75):
            if stop_bar and position > 2.0:
                continue
            add_kick(buffer, spec, base + position, 0.17)
        for position in (1.0, 3.0):
            if stop_bar and position >= 3.0:
                continue
            add_snare(buffer, spec, base + position, 0.13, 4000 + bar * 8 + int(position))
        for step in range(8):
            position = step * 0.5
            if stop_bar and position >= 2.5:
                continue
            add_hat(buffer, spec, base + position, 0.043, 4100 + bar * 16 + step,
                    0.28 if step % 2 else -0.28, step in (3, 7))
        if not stop_bar:
            add_rim(buffer, spec, base + 2.5, 0.030, 4150 + bar, 0.34)
        for step in range(8):
            position = step * 0.5
            if stop_bar and position >= 2.5:
                continue
            degree = (3, 3, 4, 3, 5, 4, 3, 2)[step] - 5
            add_bass_hit(buffer, spec, base + position, penta_midi(degree), 0.045, 0.22)
            add_dyad(buffer, spec, base + position, 0.16, (degree + 5, degree + 7), 0.120,
                     "rock", -0.22 if step % 2 == 0 else 0.22)
        if stop_bar:
            add_gesture_lead(buffer, spec, base + 3.16, 0.42, penta_midi(13), penta_midi(14),
                             0.060, "dizi", 4300 + bar, 0.18)
        else:
            for index, degree in enumerate(jump_motif):
                add_note(buffer, spec, base + 0.25 + index * 0.625, 0.20,
                         penta_midi(degree + 5), 0.120, "rock", 0.42)
    return buffer


def render_autumn_explore(spec: TrackSpec) -> StereoBuffer:
    mix = StereoBuffer(round(spec.duration * RATE))
    drums = StereoBuffer(mix.frames)
    bass = StereoBuffer(mix.frames)
    hook = StereoBuffer(mix.frames)
    texture = StereoBuffer(mix.frames)
    roots = (38, 38, 41, 43, 41, 45, 43, 38,
             38, 41, 43, 45, 41, 43, 45, 38)
    section_drop = (1.00, 2.00, 2.50, 1.25)

    for bar in range(spec.bars):
        base = bar_start(spec, bar)
        section = bar // 4
        stop_after = section_drop[section] if bar % 4 == 3 else 4.0

        # K's half-time circuit remains the whole-track skeleton.  Each fourth
        # bar stops early enough to create a musically obvious reset.
        if 0.0 < stop_after:
            add_kick(drums, spec, base, 0.130)
        if 2.0 < stop_after:
            add_snare(drums, spec, base + 2.0, 0.078, 5000 + bar)
        if bar % 2 == 0 and 2.75 < stop_after:
            add_kick(drums, spec, base + 2.75, 0.066)
        for step in ((0.5, 1.5, 3.25) if bar % 2 == 0 else (0.75, 2.5, 3.5)):
            if step < stop_after:
                add_noise_hit(drums, spec, base + step, 0.028, 0.024,
                              5050 + bar * 16 + round(step * 4),
                              -0.24 if step < 2.0 else 0.24, "bright")

        root = roots[bar]
        bass_cell = ((0.0, root), (1.5, root + 7), (2.75, root + 12))
        if section == 0:
            bass_cell = ((0.0, root), (2.75, root + 12))
        for step, note in bass_cell:
            if step < stop_after:
                add_autumn_voice(bass, spec, base + step, 0.31, note, 0.235,
                                 "husk_bass", 5100 + bar * 32 + round(step * 8))

        transposition = (0, 3, 0, 2)[section]
        cell_a = ((0.0, 62), (0.5, 69), (1.0, 65))
        cell_b = ((2.5, 67), (3.0, 72), (3.5, 69))
        if bar % 2 == 1:
            cell_b = ((2.5, 65), (3.0, 72), (3.5, 67))
        for step, note in cell_a + cell_b:
            if step < stop_after:
                add_autumn_voice(hook, spec, base + step, 0.20 if step <= 1.0 else 0.18,
                                 note + transposition, 0.245 if step <= 1.0 else 0.215,
                                 "amber_gate", 5200 + bar * 64 + round(step * 8),
                                 -0.08 if step < 2.0 else 0.08)

        if bar in {1, 5, 9, 13} and 1.75 < stop_after:
            chord = (50, 57, 62) if section % 2 == 0 else (53, 60, 65)
            add_autumn_chord(texture, spec, base + 1.75, 0.25, chord, 0.175,
                             "dry_chord", 5300 + bar)
        # Q contributed only an opening pickup idea.  Its later high event
        # density is intentionally absent from this arrangement.
        if bar == 0:
            add_noise_hit(texture, spec, base + 1.75, 0.034, 0.052, 5400,
                          -0.30, "bright")
        elif bar == 1:
            add_noise_hit(texture, spec, base + 3.50, 0.034, 0.045, 5401,
                          0.30, "bright")

    mix_buffer(mix, drums, 0.88)
    mix_buffer(mix, bass, 0.90)
    mix_buffer(mix, hook, 0.96)
    mix_buffer(mix, texture, 0.74)
    return mix


def render_autumn_boss(spec: TrackSpec) -> StereoBuffer:
    mix = StereoBuffer(round(spec.duration * RATE))
    drums = StereoBuffer(mix.frames)
    drive = StereoBuffer(mix.frames)
    hook = StereoBuffer(mix.frames)
    effects = StereoBuffer(mix.frames)
    roots = (38, 38, 41, 43, 38, 45, 43, 38,
             41, 43, 38, 45, 38, 41, 43, 38)
    industrial_cells = (
        ((0.0, 38), (0.5, 38), (1.0, 41), (2.5, 43), (3.0, 38)),
        ((0.0, 38), (0.5, 45), (1.5, 43), (2.0, 41), (3.5, 38)),
        ((0.0, 41), (0.5, 41), (1.0, 43), (2.75, 45)),
        ((0.0, 38), (0.75, 38), (2.5, 50)),
    )
    section_drop = (2.50, 1.50, 2.25, 1.00)

    for bar in range(spec.bars):
        base = bar_start(spec, bar)
        section = bar // 4
        stop_after = section_drop[section] if bar % 4 == 3 else 4.0
        z_full = bar in AUTUMN_BOSS_STRUCTURE["z_full_bars"]
        t_counter = bar in AUTUMN_BOSS_STRUCTURE["t_counter_bars"]
        root = roots[bar]

        if z_full:
            for step in (0.0, 2.0):
                if step < stop_after:
                    add_kick(drums, spec, base + step, 0.165)
            for step in (1.0, 3.0):
                if step < stop_after:
                    add_snare(drums, spec, base + step, 0.092, 6000 + bar * 4 + round(step))
            for eighth in range(8):
                step = eighth * 0.5
                if step < stop_after:
                    add_hat(drums, spec, base + step, 0.046 if eighth % 2 else 0.058,
                            6100 + bar * 16 + eighth, -0.42 if eighth % 2 else 0.42,
                            eighth == 7)

            for eighth in range(8):
                step = eighth * 0.5
                if step >= stop_after:
                    continue
                if eighth in {0, 4}:
                    note = root
                elif eighth in {3, 6}:
                    note = root + 24
                else:
                    note = root + 12 + (5 if eighth == 5 else 0)
                add_autumn_voice(drive, spec, base + step, 0.25, note, 0.265,
                                 "wire_pick", 6200 + bar * 32 + eighth,
                                 -0.14 if eighth % 2 else 0.14)
            if bar in {1, 2, 8, 12, 13}:
                phrase = (62, 65, 67, 72) if bar < 8 or bar == 12 else (65, 67, 72, 69)
                for step, note in zip((0.0, 0.75, 1.5, 2.25), phrase):
                    if step < stop_after:
                        add_autumn_voice(hook, spec, base + step, 0.20, note, 0.225,
                                         "wire_pick", 6300 + bar * 32 + round(step * 8),
                                         -0.04 if step < 1.5 else 0.04)
        else:
            # Even during T's counterphrase, Z keeps the downbeat, backbeat and
            # low wire-pick answer.  T therefore interrupts a continuing lure
            # instead of replacing it with a second unrelated song.
            add_kick(drums, spec, base, 0.150)
            if 2.0 < stop_after:
                add_snare(drums, spec, base + 2.0, 0.076, 6050 + bar)
            for step, pan in ((0.50, -0.34), (2.50, 0.34)):
                if step < stop_after:
                    add_hat(drums, spec, base + step, 0.037,
                            6150 + bar * 8 + round(step * 2), pan)
            for step, note, pan in ((0.0, root, 0.12), (2.0, root + 12, -0.12)):
                if step < stop_after:
                    add_autumn_voice(drive, spec, base + step, 0.30, note, 0.235,
                                     "wire_pick", 6250 + bar * 8 + round(step * 2), pan)

        if bar in AUTUMN_BOSS_STRUCTURE["dub_send_bars"]:
            chord = (50, 57, 62) if bar in {0, 8, 12} else (53, 60, 65)
            add_autumn_dub_reply(effects, spec, base + 0.25, chord, 0.255,
                                 6400 + bar, base + stop_after)

        if t_counter:
            transpose = 0 if section == 1 else (3 if bar == 9 else 5 if bar == 11 else 0)
            cell = industrial_cells[bar % 4]
            for step, note in cell:
                if step >= stop_after:
                    continue
                voiced_note = note + transpose + 12
                if step >= 2.0:
                    voiced_note += 12
                add_autumn_voice(drive, spec, base + step, 0.25 if step < 2.0 else 0.31,
                                 voiced_note, 0.275, "iron_pulse",
                                 6500 + bar * 32 + round(step * 8),
                                 -0.16 if round(step * 4) % 2 else 0.16)
                if step in {2.5, 2.75}:
                    add_kick(drums, spec, base + step, 0.135)
            if bar % 4 != 3:
                for step in (0.25, 1.75, 3.50):
                    if step < stop_after:
                        add_hat(drums, spec, base + step, 0.038,
                                6650 + bar * 16 + round(step * 4),
                                -0.38 if step < 2.0 else 0.38)
            if bar in {5, 6, 9, 11, 15}:
                for step, note, pan in ((1.50, 74, -0.20), (2.00, 69, 0.20)):
                    if step < stop_after:
                        add_autumn_voice(effects, spec, base + step, 0.24, note, 0.145,
                                         "rust_bell", 6700 + bar * 8 + round(step * 2), pan)
            if bar in {5, 9} and 2.75 < stop_after:
                add_noise_hit(effects, spec, base + 2.75, 0.16, 0.068,
                              6750 + bar, 0.16, "dark")

    mix_buffer(mix, drums, 0.98)
    mix_buffer(mix, drive, 0.82)
    mix_buffer(mix, hook, 0.90)
    mix_buffer(mix, effects, 0.94)
    return mix


def render_winter_explore(spec: TrackSpec) -> StereoBuffer:
    buffer = StereoBuffer(round(spec.duration * RATE))
    circle = (4, 5, 6, 7, 6)
    for bar in range(spec.bars):
        base = bar_start(spec, bar)
        add_kick(buffer, spec, base, 0.050)
        add_noise_hit(buffer, spec, base + 1.5, 0.085, 0.014, 6800 + bar, 0.16, "dark")
        add_bass_hit(buffer, spec, base, penta_midi(4 - 5), 0.072, 0.38)
        if bar % 2 == 1:
            add_bass_hit(buffer, spec, base + 1.5, penta_midi(0 - 5), 0.054, 0.32)
        for position, pan in ((0.75, -0.52), (2.25, 0.52)):
            if (bar + int(position * 2)) % 3 != 0:
                add_note(buffer, spec, base + position, 0.24, penta_midi(9 + bar % 3), 0.066, "ice", pan)
        if bar % 2 == 0:
            for index, degree in enumerate(circle[:3]):
                add_note(buffer, spec, base + 0.25 + index * 0.68, 0.28,
                         penta_midi(degree + 5), 0.073, "mallet", -0.25 + index * 0.25)
        else:
            add_note(buffer, spec, base + 1.0, 0.40, penta_midi(circle[3] + 5), 0.070, "warm", 0.25)
            add_note(buffer, spec, base + 2.0, 0.38, penta_midi(circle[4] + 5), 0.068, "warm", 0.0)
        if bar % 4 == 3:
            add_dyad(buffer, spec, base + 2.4, 0.34, (5, 7), 0.048, "warm", 0.0)
        if bar in (3, 11):
            gesture_pan = -0.30 if bar == 3 else 0.30
            add_gesture_lead(buffer, spec, base + 0.42, 1.08, penta_midi(7), penta_midi(6),
                             0.043, "xiao", 6900 + bar, gesture_pan)
            add_gesture_lead(buffer, spec, base + 1.88, 0.58, penta_midi(5), penta_midi(6),
                             0.033, "xiao", 6950 + bar, -gesture_pan)
    return buffer


def render_winter_boss(spec: TrackSpec) -> StereoBuffer:
    buffer = StereoBuffer(round(spec.duration * RATE))
    for bar in range(spec.bars):
        base = bar_start(spec, bar)
        phase = bar % 4
        stop_bar = phase == 3
        for position in ((0.0, 2.5) if not stop_bar else (0.0,)):
            add_kick(buffer, spec, base + position, 0.235)
        if not stop_bar:
            add_snare(buffer, spec, base + 2.0, 0.125, 7000 + bar)
        for step in range(8):
            position = step * 0.5
            if stop_bar and position >= 1.5:
                continue
            add_hat(buffer, spec, base + position, 0.020 if step % 4 else 0.034,
                    7100 + bar * 16 + step, 0.22 if step % 2 else -0.22, step == 7)
        hit_positions = (0.0, 0.75, 1.5, 2.75) if not stop_bar else (0.0, 0.75)
        for index, position in enumerate(hit_positions):
            degree = (4, 4, 5, 3)[index] - 5
            add_bass_hit(buffer, spec, base + position, penta_midi(degree), 0.105, 0.34)
            add_dyad(buffer, spec, base + position, 0.28, (degree + 5, degree + 8), 0.074,
                     "rock", -0.18 if index % 2 else 0.18)
        if phase == 2:
            for index, position in enumerate((2.0, 2.5, 2.875, 3.125, 3.375, 3.625)):
                add_tom(buffer, spec, base + position, 45 - index * 0.7, 0.080 + index * 0.006,
                        -0.45 + index * 0.18)
        if stop_bar:
            add_note(buffer, spec, base + 3.0, 0.38, penta_midi(14), 0.115, "ice", 0.0)
            add_note(buffer, spec, base + 3.45, 0.30, penta_midi(10), 0.085, "ice", 0.18)
    return buffer


RENDERERS = {
    "spring_explore": render_spring_explore,
    "spring_boss": render_spring_boss,
    "summer_explore": render_summer_explore,
    "summer_boss": render_summer_boss,
    "autumn_explore": render_autumn_explore,
    "autumn_boss": render_autumn_boss,
    "winter_explore": render_winter_explore,
    "winter_boss": render_winter_boss,
}


def saturate_mix(buffer: StereoBuffer, drive: float) -> None:
    """Apply a track-local VCA-like crest clamp before loudness matching."""
    ceiling = math.tanh(drive)
    for channel in (buffer.left, buffer.right):
        for index, sample in enumerate(channel):
            channel[index] = math.tanh(sample * drive) / ceiling


def apply_macro_dynamics(buffer: StereoBuffer, spec: TrackSpec) -> None:
    """Give each four-bar phrase a real rise/drop instead of flat normalization."""
    gains = MACRO_GAINS[spec.name]
    section_quarters = spec.quarter_beats_per_bar * 4.0
    section_frames = round(section_quarters * 60.0 / spec.bpm * RATE)
    transition_frames = max(1, round(0.5 * 60.0 / spec.bpm * RATE))
    for section, current_gain in enumerate(gains):
        start = section * section_frames
        end = buffer.frames if section == len(gains) - 1 else min(buffer.frames, start + section_frames)
        previous_gain = gains[section - 1] if section > 0 else current_gain
        for index in range(start, end):
            local = index - start
            if section > 0 and local < transition_frames:
                fraction = local / transition_frames
                smooth = fraction * fraction * (3.0 - 2.0 * fraction)
                gain = previous_gain + (current_gain - previous_gain) * smooth
            else:
                gain = current_gain
            buffer.left[index] *= gain
            buffer.right[index] *= gain


def finish_mix(buffer: StereoBuffer, spec: TrackSpec) -> None:
    frames = buffer.frames
    left_mean = sum(buffer.left) / max(1, frames)
    right_mean = sum(buffer.right) / max(1, frames)
    for index in range(frames):
        buffer.left[index] -= left_mean
        buffer.right[index] -= right_mean
    fade_frames = min(round(0.008 * RATE), frames // 8)
    for index in range(fade_frames):
        gain = math.sin((index / max(1, fade_frames - 1)) * math.pi * 0.5) ** 2
        buffer.left[index] *= gain
        buffer.right[index] *= gain
        mirror = frames - 1 - index
        buffer.left[mirror] *= gain
        buffer.right[mirror] *= gain
    peak = max(max(abs(value) for value in buffer.left), max(abs(value) for value in buffer.right), 1e-9)
    target_peak = PEAK_TARGETS[spec.name]
    scale = target_peak / peak
    for index in range(frames):
        buffer.left[index] *= scale
        buffer.right[index] *= scale
    buffer.left[0] = buffer.right[0] = buffer.left[-1] = buffer.right[-1] = 0.0


def _biquad(samples: array, b0: float, b1: float, b2: float,
            a1: float, a2: float) -> array:
    result = array("f", [0.0]) * len(samples)
    x1 = x2 = y1 = y2 = 0.0
    for index, sample in enumerate(samples):
        output = b0 * sample + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        result[index] = output
        x2, x1 = x1, sample
        y2, y1 = y1, output
    return result


def _k_weight_44k1(samples: array) -> array:
    """ITU-R BS.1770 K-weighting at the generator's fixed 44.1 kHz."""
    stage_one = _biquad(
        samples,
        1.530841230050347, -2.650979995154729, 1.169079079921586,
        -1.663655113256020, 0.712595428073225,
    )
    return _biquad(
        stage_one,
        1.0, -2.0, 1.0,
        -1.989169673629795, 0.989199035787039,
    )


def integrated_lufs(buffer: StereoBuffer) -> float:
    weighted = (_k_weight_44k1(buffer.left), _k_weight_44k1(buffer.right))
    block = round(0.400 * RATE)
    hop = round(0.100 * RATE)
    energies = []
    for start in range(0, buffer.frames - block + 1, hop):
        energy = sum(
            sum(value * value for value in channel[start:start + block]) / block
            for channel in weighted
        )
        loudness = -0.691 + 10.0 * math.log10(max(energy, 1e-20))
        if loudness >= -70.0:
            energies.append(energy)
    if not energies:
        return -120.0
    ungated = -0.691 + 10.0 * math.log10(sum(energies) / len(energies))
    threshold = ungated - 10.0
    gated = [
        energy for energy in energies
        if -0.691 + 10.0 * math.log10(max(energy, 1e-20)) >= threshold
    ]
    return -0.691 + 10.0 * math.log10(sum(gated) / len(gated))


def normalize_autumn_loudness(buffer: StereoBuffer, target_lufs: float) -> None:
    measured = integrated_lufs(buffer)
    scale = 10.0 ** ((target_lufs - measured) / 20.0)
    projected_peak = max(
        max(abs(value) for value in buffer.left),
        max(abs(value) for value in buffer.right),
    ) * scale
    # Leave more than a dB of sample-peak headroom for inter-sample peaks.  A
    # failure here means the arrangement needs crest control, not silent clip.
    if projected_peak > 0.82:
        raise RuntimeError(
            f"autumn loudness target would exceed the peak fence: {projected_peak:.4f}"
        )
    for channel in (buffer.left, buffer.right):
        for index in range(len(channel)):
            channel[index] *= scale


def write_wav(path: Path, buffer: StereoBuffer) -> None:
    interleaved = array("h")
    append = interleaved.append
    for left, right in zip(buffer.left, buffer.right):
        append(max(-32767, min(32767, round(left * 32767))))
        append(max(-32767, min(32767, round(right * 32767))))
    if struct.pack("=h", 1) != struct.pack("<h", 1):
        interleaved.byteswap()
    with wave.open(str(path), "wb") as output:
        output.setnchannels(2)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(interleaved.tobytes())


def render_track(name: str) -> Path:
    spec = TRACKS[name]
    buffer = RENDERERS[name](spec)
    apply_macro_dynamics(buffer, spec)
    if name == "autumn_explore":
        saturate_mix(buffer, 1.70)
    elif name == "autumn_boss":
        saturate_mix(buffer, 1.55)
    finish_mix(buffer, spec)
    if name in AUTUMN_LOUDNESS_TARGETS:
        normalize_autumn_loudness(buffer, AUTUMN_LOUDNESS_TARGETS[name])
    path = OUTPUT / f"{name}.wav"
    write_wav(path, buffer)
    print(
        f"{path.relative_to(ROOT)} | {spec.bpm:g} BPM | "
        f"{spec.numerator}/{spec.denominator} | {spec.bars} bars | "
        f"{spec.duration:.3f}s | {spec.description}"
    )
    return path


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--track", choices=tuple(TRACKS), action="append",
                        help="render only the named track; may be supplied repeatedly")
    args = parser.parse_args()
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for name in (args.track or tuple(TRACKS)):
        render_track(name)


if __name__ == "__main__":
    main()
