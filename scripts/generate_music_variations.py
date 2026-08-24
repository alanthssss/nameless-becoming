#!/usr/bin/env python3
"""Generate eight deterministic leitmotif variations for the Godot prototype.

The files are intentionally self-contained candidates: no external samples and no
copyrighted melody.  One five-note motif is re-orchestrated for four field loops
and destabilised for the matching boss loops.
"""

from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path


RATE = 22_050
DURATION = 24.0
TAU = math.tau
ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "godot" / "assets" / "music"
MOTIF = [0, 2, 4, 7, 4, 2, 0, -1]
PENTA = [0, 2, 4, 7, 9]


def hz(root: float, semitone: float) -> float:
    return root * (2.0 ** (semitone / 12.0))


def envelope(t: float, length: float, attack: float, release: float) -> float:
    if t < 0.0 or t >= length:
        return 0.0
    return min(1.0, t / max(attack, 1e-5), (length - t) / max(release, 1e-5))


def oscillator(phase: float, timbre: str) -> float:
    sine = math.sin(phase)
    if timbre == "wood":
        return sine * 0.72 + math.sin(phase * 2.01) * 0.20 + math.sin(phase * 3.0) * 0.08
    if timbre == "reed":
        return sine * 0.55 + math.sin(phase * 3.0) * 0.25 + math.sin(phase * 5.0) * 0.10
    if timbre == "string":
        return sine * 0.64 + math.sin(phase * 2.0) * 0.15 + math.sin(phase * 0.5) * 0.18
    if timbre == "glass":
        return sine * 0.58 + math.sin(phase * 2.7) * 0.22 + math.sin(phase * 4.1) * 0.08
    return sine


def add_note(buffer: list[float], start: float, length: float, frequency: float,
             gain: float, timbre: str, attack: float = 0.018, release: float = 0.18) -> None:
    start_i = max(0, int(start * RATE))
    end_i = min(len(buffer), int((start + length) * RATE))
    for i in range(start_i, end_i):
        local = i / RATE - start
        env = envelope(local, length, attack, release)
        phase = TAU * frequency * local
        buffer[i] += oscillator(phase, timbre) * env * gain


def add_pad(buffer: list[float], root: float, chords: list[list[int]], bar: float,
            gain: float, frozen: bool = False) -> None:
    for bar_index in range(math.ceil(DURATION / bar)):
        chord = chords[bar_index % len(chords)]
        start = bar_index * bar
        for degree in chord:
            frequency = hz(root * 0.5, degree)
            length = bar * (1.45 if frozen else 1.08)
            add_note(buffer, start, length, frequency, gain, "glass" if frozen else "string", 0.35, 0.7)


def add_percussion(buffer: list[float], beat: float, density: int, gain: float, seed: int) -> None:
    rng = random.Random(seed)
    step = beat / density
    count = int(DURATION / step)
    for n in range(count):
        if density > 1 and n % density not in (0, density - 1):
            continue
        start_i = int(n * step * RATE)
        length = int(0.055 * RATE)
        for j in range(length):
            i = start_i + j
            if i >= len(buffer):
                break
            env = (1.0 - j / length) ** 3
            noise = rng.uniform(-1.0, 1.0)
            thump = math.sin(TAU * (74.0 if n % density == 0 else 1600.0) * j / RATE)
            buffer[i] += (noise * 0.35 + thump * 0.65) * env * gain


def compose(family: int, boss: bool) -> list[float]:
    buffer = [0.0] * int(RATE * DURATION)
    roots = [220.0, 246.94, 196.0, 164.81]
    bpm = [94.0, 132.0, 82.0, 62.0][family]
    if boss:
        bpm *= [1.22, 1.16, 1.12, 1.08][family]
    beat = 60.0 / bpm
    step = beat * (0.5 if family == 1 else 1.0)
    timbre = ["wood", "reed", "string", "glass"][family]
    root = roots[family]

    chords = [[0, 4, 7], [2, 5, 9], [0, 4, 9], [-3, 2, 7]]
    if boss:
        # The same harmony is displaced rather than replaced, so the family link
        # remains audible while the phrase feels out of joint.
        chords = [[0, 4, 7], [1, 5, 8], [-2, 4, 9], [0, 3, 7]]
    add_pad(buffer, root, chords, beat * 4.0, 0.030 if boss else 0.038, family == 3)

    total_steps = int(DURATION / step) + 1
    for n in range(total_steps):
        degree = MOTIF[n % len(MOTIF)]
        phrase = n // len(MOTIF)
        if family == 2:
            degree = -MOTIF[n % len(MOTIF)] + 7
        if family == 3:
            degree = MOTIF[(n // 2) % len(MOTIF)] if n % 2 == 0 else -99
        if boss:
            if family == 0 and n % 8 in (6, 7):
                degree = -99  # the mosquito steals each cadence
            elif family == 1 and n % 4 == 1:
                degree += 1  # shifted accents and false landing
            elif family == 2 and n % 8 in (2, 5):
                add_note(buffer, n * step + step * 0.22, step * 0.8, hz(root, degree + 6), 0.045, "reed")
            elif family == 3 and phrase % 2 == 0:
                degree = degree if n % 4 == 0 else -99
        if degree <= -90:
            continue
        length = step * ([0.82, 0.46, 0.72, 1.7][family])
        gain = 0.115 if boss else 0.095
        add_note(buffer, n * step, length, hz(root, degree), gain, timbre,
                 0.008 if family in (0, 1) else 0.06, 0.12 if family in (0, 1) else 0.45)
        if not boss and family == 0 and n % 8 in (4, 5, 6):
            add_note(buffer, n * step, length * 0.65, hz(root * 2.0, degree + 7), 0.025, "glass")

    bass_step = beat * 2.0
    for n in range(int(DURATION / bass_step) + 1):
        degree = PENTA[n % len(PENTA)]
        if boss and n % 4 == 2:
            degree -= 1
        add_note(buffer, n * bass_step, bass_step * 0.9, hz(root * 0.5, degree),
                 0.070 if boss else 0.052, "string", 0.04, 0.35)

    if family == 1 or boss:
        add_percussion(buffer, beat, 2 if family == 1 else 1, 0.085 if boss else 0.060, 700 + family)
    elif family == 0:
        add_percussion(buffer, beat * 2.0, 1, 0.026, 710)

    peak = max(max(abs(value) for value in buffer), 1e-9)
    scale = 0.82 / peak
    return [math.tanh(value * scale * 1.3) * 0.86 for value in buffer]


def write_wav(path: Path, samples: list[float]) -> None:
    with wave.open(str(path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        frames = b"".join(struct.pack("<h", max(-32767, min(32767, int(sample * 32767)))) for sample in samples)
        output.writeframes(frames)


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    names = ["spring", "summer", "autumn", "winter"]
    for family, name in enumerate(names):
        for boss in (False, True):
            suffix = "boss" if boss else "explore"
            path = OUTPUT / f"{name}_{suffix}.wav"
            write_wav(path, compose(family, boss))
            print(path.relative_to(ROOT))


if __name__ == "__main__":
    main()
