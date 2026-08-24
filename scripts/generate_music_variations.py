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
        "wood chamber folk, 3+3+2 branching pulse",
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
        "stop-time punk for the cricket's jump and landing", True,
    ),
    "autumn_explore": TrackSpec(
        "autumn_explore", 84.0, 5, 4, 8, 1,
        "dry chamber five-four whose fifth beat is left empty",
    ),
    "autumn_boss": TrackSpec(
        "autumn_boss", 126.0, 6, 8, 16, 1,
        "psychedelic six-eight with false stereo thrush echoes", True,
    ),
    "winter_explore": TrackSpec(
        "winter_explore", 108.0, 6, 8, 16, 4,
        "warm sparse six-eight pulse (dotted-quarter = 72)",
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
    "autumn_explore": (0.70, 1.00),
    "autumn_boss": (0.72, 0.94, 1.00, 0.80),
    "winter_explore": (0.66, 0.82, 1.00, 0.74),
    "winter_boss": (0.74, 1.00, 0.84),
}

PEAK_TARGETS = {
    "spring_explore": 0.80,
    "summer_explore": 0.80,
    "autumn_explore": 0.72,
    "winter_explore": 0.62,
    "spring_boss": 0.86,
    "summer_boss": 0.86,
    "autumn_boss": 0.86,
    "winter_boss": 0.86,
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
        value = math.sin(phase) * attack * math.exp(-6.0 * progress) * gain
        buffer.left[target] += value * 0.707
        buffer.right[target] += value * 0.707


def add_snare(buffer: StereoBuffer, spec: TrackSpec, start_q: float, gain: float, seed: int) -> None:
    add_noise_hit(buffer, spec, start_q, 0.105, gain, seed, 0.08, "bright")
    add_note(buffer, spec, start_q, 0.18, 50.0, gain * 0.42, "muted", -0.06)


def add_tom(buffer: StereoBuffer, spec: TrackSpec, start_q: float, midi_note: float,
            gain: float, pan: float = 0.0) -> None:
    add_note(buffer, spec, start_q, 0.20, midi_note, gain, "muted", pan)


def bar_start(spec: TrackSpec, bar: int) -> float:
    return bar * spec.quarter_beats_per_bar


def render_spring_explore(spec: TrackSpec) -> StereoBuffer:
    buffer = StereoBuffer(round(spec.duration * RATE))
    motif = (2, 3, 4, 5, 4)
    response = (4, 5, 6, 7, 6)
    for bar in range(spec.bars):
        base = bar_start(spec, bar)
        for accent, position in enumerate((0.0, 1.5, 3.0)):
            add_note(buffer, spec, base + position, 0.22, penta_midi(7 + accent % 2), 0.075, "wood", -0.30 + accent * 0.30)
        for step in range(8):
            if step in (2, 5):
                continue
            add_noise_hit(buffer, spec, base + step * 0.5, 0.035, 0.020 if step else 0.032,
                          1000 + bar * 16 + step, 0.35, "bright")
        add_note(buffer, spec, base, 0.52, penta_midi(2 - 5), 0.085, "bass", 0.0)
        if bar % 2 == 0:
            add_note(buffer, spec, base + 2.5, 0.38, penta_midi(0 - 5), 0.065, "bass", 0.0)
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
            add_noise_hit(buffer, spec, base + position, 0.030, 0.042,
                          2200 + bar * 16 + step, -0.35 if step % 2 else 0.35, "bright")
        for position, degree in ((0.0, 2 - 5), (0.75, 3 - 5), (1.5, 2 - 5), (2.5, 0 - 5)):
            if final_stop and position >= 2.5:
                continue
            add_note(buffer, spec, base + position, 0.30, penta_midi(degree), 0.055, "bass", 0.0)
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
        for position in (1.0, 3.0):
            add_snare(buffer, spec, base + position, 0.090, 3000 + bar * 8 + int(position))
        for step in range(16):
            position = step * 0.25 + (0.055 if step % 2 else 0.0)
            add_noise_hit(buffer, spec, base + position, 0.025, 0.018 if step % 4 else 0.030,
                          3100 + bar * 32 + step, -0.26 if step % 2 else 0.26, "bright")
        for position, degree in ((0.0, 3 - 5), (0.75, 4 - 5), (1.5, 3 - 5), (2.25, 5 - 5), (3.5, 4 - 5)):
            add_note(buffer, spec, base + position, 0.28, penta_midi(degree), 0.085, "bass", 0.0)
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
            add_noise_hit(buffer, spec, base + position, 0.030, 0.043,
                          4100 + bar * 16 + step, 0.28 if step % 2 else -0.28, "bright")
        for step in range(8):
            position = step * 0.5
            if stop_bar and position >= 2.5:
                continue
            degree = (3, 3, 4, 3, 5, 4, 3, 2)[step] - 5
            add_note(buffer, spec, base + position, 0.22, penta_midi(degree), 0.045, "bass", 0.0)
            add_dyad(buffer, spec, base + position, 0.16, (degree + 5, degree + 7), 0.120,
                     "rock", -0.22 if step % 2 == 0 else 0.22)
        if stop_bar:
            add_note(buffer, spec, base + 3.35, 0.22, penta_midi(3 + 10), 0.125, "metal", 0.0)
        else:
            for index, degree in enumerate(jump_motif):
                add_note(buffer, spec, base + 0.25 + index * 0.625, 0.20,
                         penta_midi(degree + 5), 0.120, "rock", 0.42)
    return buffer


def render_autumn_explore(spec: TrackSpec) -> StereoBuffer:
    buffer = StereoBuffer(round(spec.duration * RATE))
    falling = (1, 0, -1, -2, -1)
    for bar in range(spec.bars):
        base = bar_start(spec, bar)
        for position in (0.0, 2.5):
            add_noise_hit(buffer, spec, base + position, 0.050, 0.032,
                          5000 + bar * 8 + int(position * 2), -0.28 if position else 0.28, "bright")
        add_noise_hit(buffer, spec, base + 1.5, 0.16, 0.026, 5100 + bar, 0.10, "dark")
        for position, degree in ((0.0, 1 - 5), (2.0, -1 - 5), (3.25, 0 - 5)):
            add_note(buffer, spec, base + position, 0.46, penta_midi(degree), 0.080, "pizz", 0.0)
        for index, (position, degree) in enumerate(zip((0.25, 1.0, 1.75, 2.5, 3.25), falling)):
            add_note(buffer, spec, base + position, 0.34 if index < 4 else 0.48,
                     penta_midi(degree + 5), 0.095, "pizz", -0.32 if bar % 2 == 0 else 0.32)
        add_dyad(buffer, spec, base + 2.75, 0.26, (1, 3), 0.043, "metal", 0.35)
    return buffer


def render_autumn_boss(spec: TrackSpec) -> StereoBuffer:
    buffer = StereoBuffer(round(spec.duration * RATE))
    truth = (1, 0, -1, -2, -1)
    for bar in range(spec.bars):
        base = bar_start(spec, bar)
        for position in (0.0, 1.5):
            add_kick(buffer, spec, base + position, 0.135)
        add_snare(buffer, spec, base + 1.0, 0.100, 6000 + bar)
        for step in range(6):
            add_noise_hit(buffer, spec, base + step * 0.5, 0.040, 0.030 if step % 3 else 0.043,
                          6100 + bar * 12 + step, -0.42 if step % 2 else 0.42, "bright")
        for position, degree in ((0.0, 1 - 5), (1.0, 0 - 5), (1.5, -1 - 5), (2.5, 0 - 5)):
            add_note(buffer, spec, base + position, 0.30, penta_midi(degree), 0.065, "bass", 0.0)
        degree = truth[bar % len(truth)]
        add_note(buffer, spec, base + 0.25, 0.45, penta_midi(degree + 10), 0.105, "echo", 0.0)
        add_note(buffer, spec, base + 0.75, 0.34, penta_midi(degree + 11), 0.070, "buzz", -0.78)
        add_note(buffer, spec, base + 1.25, 0.30, penta_midi(degree + 9), 0.065, "echo", 0.78)
        if bar % 4 != 3:
            add_dyad(buffer, spec, base + 2.0, 0.30, (degree + 10, degree + 12), 0.065,
                     "rock", -0.12 if bar % 2 else 0.12)
        else:
            add_note(buffer, spec, base + 2.15, 0.28, penta_midi(1 + 10), 0.095, "metal", 0.0)
    return buffer


def render_winter_explore(spec: TrackSpec) -> StereoBuffer:
    buffer = StereoBuffer(round(spec.duration * RATE))
    circle = (4, 5, 6, 7, 6)
    for bar in range(spec.bars):
        base = bar_start(spec, bar)
        add_note(buffer, spec, base, 0.38, penta_midi(4 - 5), 0.082, "warm", 0.0)
        if bar % 2 == 1:
            add_note(buffer, spec, base + 1.5, 0.32, penta_midi(0 - 5), 0.060, "warm", 0.0)
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
            add_noise_hit(buffer, spec, base + position, 0.034, 0.020 if step % 4 else 0.034,
                          7100 + bar * 16 + step, 0.22 if step % 2 else -0.22, "bright")
        hit_positions = (0.0, 0.75, 1.5, 2.75) if not stop_bar else (0.0, 0.75)
        for index, position in enumerate(hit_positions):
            degree = (4, 4, 5, 3)[index] - 5
            add_note(buffer, spec, base + position, 0.34, penta_midi(degree), 0.105, "bass", 0.0)
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
    finish_mix(buffer, spec)
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
