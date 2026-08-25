#!/usr/bin/env python3
"""Render four disposable autumn music direction sketches.

These files are for choosing a direction, not for replacing the game's eight
shipping loops.  The renderer refuses to run if any shipping WAV differs from
the pinned baseline, writes only below ``outputs/`` by default, and uses a
standalone autumn-specific synth/mix path.  It deliberately contains none of
the rejected 84 BPM 5/4 exploration material or 126 BPM 6/8 boss skeleton.

No third-party Python packages are required.  The synthesis and BS.1770-4
loudness meter are deterministic at 48 kHz; ffmpeg is used only by the separate
local verification command documented in the generated manifest.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import random
import shutil
import stat
import struct
import subprocess
import tempfile
import wave
from array import array
from dataclasses import asdict, dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = ROOT / "outputs" / "autumn-direction-sketches"
OUTPUT_ROOT = ROOT / "outputs"
OUTPUT_SENTINEL_NAME = ".nameless-autumn-direction-render"
OUTPUT_SENTINEL = "nameless-autumn-direction-render:v1\n"
RATE = 48_000
TAU = math.tau

# This is both a scope fence and a regression lock.  Direction work must not
# silently turn into edits of the production music set.
OFFICIAL_WAV_SHA256 = {
    "autumn_boss.wav": "d9ff59d8de8fb35c9200251dc7ce18eb7740dd71d17cb5f44004eb51c92c6d84",
    "autumn_explore.wav": "e22b01786dfb50041aa76f3fb43ea769ce5239bd9f2c7f7e9bafb74bb3dd1d66",
    "spring_boss.wav": "df1b22d280ba3e3d18627d48bea1ad02cb1f2164007176180e6d39b1f438b3ed",
    "spring_explore.wav": "b443b5efe895bb5365c2b66d135def4656a6b2a409bbd3757c4784ce5bea4f6c",
    "summer_boss.wav": "7fcdbc2d35242f8981ce11d48844443621fd1a3ad00104d44fe721c1bf7e634e",
    "summer_explore.wav": "9ea49bc76c610dc0fcad3c74d3a308662637d48558a68cf2d7f216c1d239f353",
    "winter_boss.wav": "a11aaca193b51483d572e9411854970940e7d12e43b86001f6226e3cc915eeaa",
    "winter_explore.wav": "26f5e344a6f83fb8beba8574b2db687c8b7015927113c3d21af750e294902910",
}


@dataclass(frozen=True)
class SketchSpec:
    key: str
    role: str
    bpm: int
    bars: int
    target_lufs: float
    seed: int
    internal_direction: str
    phrase: str = "4+4 bars"
    meter: str = "4/4"
    pitch_motion: str = "stepped only; no portamento"
    legacy_material: str = "none"

    @property
    def seconds_per_beat(self) -> float:
        return 60.0 / self.bpm

    @property
    def duration(self) -> float:
        return self.bars * 4.0 * self.seconds_per_beat


SPECS = {
    "explore_seed_funk": SketchSpec(
        "explore_seed_funk", "explore", 108, 8, -17.3, 8_251,
        "dry electro-funk / seed-machine syncopation",
    ),
    "explore_amber_circuit": SketchSpec(
        "explore_amber_circuit", "explore", 124, 8, -17.3, 8_419,
        "half-time amber circuit / antiphonal step sequencer",
    ),
    "boss_postpunk_dub": SketchSpec(
        "boss_postpunk_dub", "boss", 128, 8, -18.7, 9_073,
        "electronic post-punk / discrete filtered dub replies",
    ),
    "boss_stoptime_industrial": SketchSpec(
        "boss_stoptime_industrial", "boss", 120, 8, -18.7, 9_271,
        "stop-time electronic punk / industrial rock",
    ),
}


class StereoBuffer:
    def __init__(self, frames: int) -> None:
        self.frames = frames
        self.left = array("f", [0.0]) * frames
        self.right = array("f", [0.0]) * frames

    def mix(self, source: "StereoBuffer", gain: float = 1.0) -> None:
        for index in range(self.frames):
            self.left[index] += source.left[index] * gain
            self.right[index] += source.right[index] * gain


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def assert_official_wavs_unchanged() -> None:
    music = ROOT / "godot" / "assets" / "music"
    failures = []
    for name, expected in OFFICIAL_WAV_SHA256.items():
        path = music / name
        actual = sha256(path) if path.is_file() else "missing"
        if actual != expected:
            failures.append(f"{name}: expected {expected}, got {actual}")
    if failures:
        raise RuntimeError("shipping WAV scope fence failed:\n" + "\n".join(failures))


def renderer_identity() -> dict[str, object]:
    commit = subprocess.check_output(
        ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True,
    ).strip()
    dirty = bool(subprocess.check_output(
        ["git", "status", "--porcelain"], cwd=ROOT, text=True,
    ).strip())
    return {
        "commit": commit,
        "dirty": dirty,
        "script_sha256": sha256(Path(__file__).resolve()),
    }


def _lexists(path: Path) -> bool:
    return os.path.lexists(path)


def assert_owned_render_output(output: Path) -> None:
    info = os.lstat(output)
    if stat.S_ISLNK(info.st_mode) or not stat.S_ISDIR(info.st_mode):
        raise RuntimeError(f"refusing non-directory or symlink output: {output}")
    marker = output / OUTPUT_SENTINEL_NAME
    try:
        marker_info = os.lstat(marker)
    except FileNotFoundError as error:
        raise RuntimeError(f"refusing unowned output: {output}") from error
    if stat.S_ISLNK(marker_info.st_mode) or not stat.S_ISREG(marker_info.st_mode):
        raise RuntimeError(f"refusing symlink/non-file ownership marker: {marker}")
    if marker.read_text(encoding="utf-8") != OUTPUT_SENTINEL:
        raise RuntimeError(f"refusing unowned output: {output}")


def resolve_safe_output(requested: Path) -> Path:
    OUTPUT_ROOT.mkdir(parents=True, exist_ok=True)
    root = OUTPUT_ROOT.resolve(strict=True)
    lexical_output = requested.expanduser().absolute()
    if _lexists(lexical_output) and stat.S_ISLNK(os.lstat(lexical_output).st_mode):
        raise RuntimeError(f"refusing symlink output: {lexical_output}")
    output = lexical_output.resolve(strict=False)
    if output == root or root not in output.parents:
        raise RuntimeError(f"render output must be a child of {root}")
    output.parent.mkdir(parents=True, exist_ok=True)
    # Resolve again after creating parents so a concurrently introduced parent
    # symlink cannot redirect staging outside the ignored output tree.
    output = output.resolve(strict=False)
    if output == root or root not in output.parents:
        raise RuntimeError(f"render output escaped {root}")
    if _lexists(output):
        assert_owned_render_output(output)
    return output


def install_owned_render(staged: Path, output: Path) -> None:
    if not _lexists(output):
        os.replace(staged, output)
        return

    assert_owned_render_output(output)
    # mkdtemp supplies a non-guessable sibling name.  Remove only the fresh,
    # empty directory so the path can become a rename target.
    backup = Path(tempfile.mkdtemp(prefix=".autumn-direction-backup-", dir=output.parent))
    backup.rmdir()
    # Revalidate immediately before the rename to narrow replacement races.
    assert_owned_render_output(output)
    os.replace(output, backup)
    try:
        os.replace(staged, output)
    except Exception:
        os.replace(backup, output)
        raise
    shutil.rmtree(backup)


def midi_hz(note: float) -> float:
    return 440.0 * 2.0 ** ((note - 69.0) / 12.0)


def pan_gains(pan: float) -> tuple[float, float]:
    angle = (max(-1.0, min(1.0, pan)) + 1.0) * math.pi / 4.0
    return math.cos(angle), math.sin(angle)


def envelope(index: int, frames: int, attack: float, release: float, decay: float, sustain: float) -> float:
    attack_frames = max(1, round(attack * RATE))
    release_frames = max(1, round(release * RATE))
    attack_gain = min(1.0, index / attack_frames)
    release_gain = min(1.0, (frames - 1 - index) / release_frames)
    decay_gain = sustain + (1.0 - sustain) * math.exp(-index / max(1.0, decay * RATE))
    return attack_gain * release_gain * decay_gain


def add_voice(buffer: StereoBuffer, spec: SketchSpec, start_beat: float, length_beats: float,
              note: float, gain: float, voice: str, pan: float = 0.0) -> None:
    """Add one stepped-pitch autumn voice; no voice implements pitch glide."""
    start = round(start_beat * spec.seconds_per_beat * RATE)
    frames = max(2, round(length_beats * spec.seconds_per_beat * RATE))
    if start >= buffer.frames:
        return
    left_gain, right_gain = pan_gains(pan)
    frequency = midi_hz(note)
    phase = 0.0
    phase_step = TAU * frequency / RATE
    rng = random.Random(spec.seed + start + round(note * 17) + sum(ord(char) for char in voice))
    low_state = 0.0

    for local in range(min(frames, buffer.frames - start)):
        if voice == "seed_clav":
            env = envelope(local, frames, 0.0015, 0.025, 0.075, 0.015)
            raw = math.tanh(1.7 * (0.66 * math.sin(phase) + 0.23 * math.sin(phase * 2.0) + 0.11 * math.sin(phase * 5.0)))
        elif voice == "husk_bass":
            env = envelope(local, frames, 0.003, 0.055, 0.16, 0.18)
            raw = 0.72 * math.sin(phase) + 0.20 * math.sin(phase * 2.0) + 0.08 * math.sin(phase * 3.0)
            low_state += 0.18 * (raw - low_state)
            raw = math.tanh(low_state * 1.25)
        elif voice == "amber_gate":
            env = envelope(local, frames, 0.002, 0.035, 0.12, 0.03)
            mod = math.sin(phase * 2.0) * 1.35 * math.exp(-local / max(1.0, RATE * 0.08))
            raw = 0.78 * math.sin(phase + mod) + 0.22 * math.sin(phase * 3.0)
        elif voice == "dry_chord":
            env = envelope(local, frames, 0.002, 0.04, 0.11, 0.04)
            raw = math.tanh(1.35 * (0.58 * math.sin(phase) + 0.26 * math.sin(phase * 2.0) + 0.16 * math.sin(phase * 4.0)))
        elif voice == "wire_pick":
            env = envelope(local, frames, 0.001, 0.035, 0.09, 0.025)
            excitation = 0.60 * math.sin(phase) + 0.28 * math.sin(phase * 3.0) + 0.12 * math.sin(phase * 7.0)
            raw = math.tanh(excitation * 1.8)
        elif voice == "dub_stab":
            env = envelope(local, frames, 0.004, 0.07, 0.18, 0.06)
            raw = 0.60 * math.sin(phase) + 0.24 * math.sin(phase * 2.0) + 0.16 * math.sin(phase * 4.0)
            low_state += 0.10 * (raw - low_state)
            raw = low_state
        elif voice == "iron_pulse":
            env = envelope(local, frames, 0.001, 0.03, 0.12, 0.025)
            raw = math.tanh(2.2 * (0.48 * math.sin(phase) + 0.30 * math.sin(phase * 2.0) + 0.15 * math.sin(phase * 4.0) + 0.07 * math.sin(phase * 9.0)))
        elif voice == "rust_bell":
            env = envelope(local, frames, 0.001, 0.08, 0.14, 0.0)
            raw = 0.52 * math.sin(phase) + 0.31 * math.sin(phase * 2.71) + 0.17 * math.sin(phase * 4.19)
        else:
            raise ValueError(f"unknown autumn voice: {voice}")

        # Only the very short attacks use noise.  There is no sustained hiss or
        # bowed/portamento component that could read as a whine or cat-like cry.
        if voice in {"seed_clav", "wire_pick", "iron_pulse"} and local < RATE * 0.012:
            raw += rng.uniform(-1.0, 1.0) * 0.055 * (1.0 - local / (RATE * 0.012))
        value = raw * env * gain
        target = start + local
        buffer.left[target] += value * left_gain
        buffer.right[target] += value * right_gain
        phase += phase_step


def add_chord(buffer: StereoBuffer, spec: SketchSpec, beat: float, length: float,
              notes: tuple[int, ...], gain: float, voice: str, pan: float = 0.0) -> None:
    spread = 0.16
    for index, note in enumerate(notes):
        offset = (index - (len(notes) - 1) / 2.0) * spread
        add_voice(buffer, spec, beat, length, note, gain / math.sqrt(len(notes)), voice, pan + offset)


def add_kick(buffer: StereoBuffer, spec: SketchSpec, beat: float, gain: float = 0.7) -> None:
    start = round(beat * spec.seconds_per_beat * RATE)
    frames = min(round(0.19 * RATE), buffer.frames - start)
    phase = 0.0
    for local in range(max(0, frames)):
        progress = local / frames
        frequency = 46.0 + 88.0 * math.exp(-progress * 10.0)
        phase += TAU * frequency / RATE
        body = math.sin(phase) * math.exp(-progress * 6.4)
        click = math.sin(phase * 3.7) * math.exp(-progress * 34.0) * 0.16
        value = (body + click) * gain
        buffer.left[start + local] += value * 0.7071
        buffer.right[start + local] += value * 0.7071


def add_noise_hit(buffer: StereoBuffer, spec: SketchSpec, beat: float, seconds: float,
                  gain: float, kind: str, pan: float = 0.0, salt: int = 0) -> None:
    start = round(beat * spec.seconds_per_beat * RATE)
    frames = min(round(seconds * RATE), buffer.frames - start)
    rng = random.Random(spec.seed + round(beat * 10_000) + salt)
    left_gain, right_gain = pan_gains(pan)
    previous = 0.0
    low = 0.0
    for local in range(max(0, frames)):
        progress = local / frames
        raw = rng.uniform(-1.0, 1.0)
        high = raw - previous * 0.92
        low += 0.08 * (raw - low)
        if kind == "hat":
            shaped = high * math.exp(-progress * 8.5)
        elif kind == "snare":
            shaped = (high * 0.76 + math.sin(TAU * 185.0 * local / RATE) * 0.24) * math.exp(-progress * 5.0)
        elif kind == "seed":
            shaped = (high * 0.48 + math.sin(TAU * 2_180.0 * local / RATE) * 0.52) * math.exp(-progress * 13.0)
        elif kind == "thud":
            shaped = (low * 0.68 + math.sin(TAU * 91.0 * local / RATE) * 0.32) * math.exp(-progress * 7.0)
        else:
            raise ValueError(kind)
        attack = min(1.0, local / max(1, round(0.0015 * RATE)))
        value = shaped * attack * gain
        target = start + local
        buffer.left[target] += value * left_gain
        buffer.right[target] += value * right_gain
        previous = raw


def add_dub_reply(bus: StereoBuffer, spec: SketchSpec, beat: float,
                  notes: tuple[int, ...], gain: float) -> None:
    """A finite, audible dub send: dry stab plus three dark tempo taps."""
    add_chord(bus, spec, beat, 0.34, notes, gain, "dub_stab")
    for offset, tap_gain, pan in ((0.75, 0.44, -0.52), (1.50, 0.25, 0.48), (2.25, 0.13, -0.28)):
        if beat + offset < spec.bars * 4.0 - 0.3:
            add_chord(bus, spec, beat + offset, 0.22, notes, gain * tap_gain, "dub_stab", pan)


def render_explore_seed_funk(spec: SketchSpec) -> StereoBuffer:
    mix = StereoBuffer(round(spec.duration * RATE))
    drums = StereoBuffer(mix.frames)
    bass = StereoBuffer(mix.frames)
    hook = StereoBuffer(mix.frames)
    for bar in range(8):
        base = bar * 4.0
        # Bar 4 and bar 8 each make a real hole; the second is longer so the
        # loop breathes before its next downbeat.
        final_hole = 2.35 if bar == 7 else 3.15 if bar == 3 else 4.0
        kick_steps = (0.0, 1.5, 2.75) if bar % 2 == 0 else (0.0, 1.75, 3.25)
        for step in kick_steps:
            if step < final_hole:
                add_kick(drums, spec, base + step, 0.64)
        for step in (1.0, 3.0):
            if step < final_hole:
                add_noise_hit(drums, spec, base + step, 0.12, 0.30, "snare", salt=bar)
        for eighth in range(8):
            step = eighth * 0.5
            if step < final_hole and not (bar in {3, 7} and 1.75 < step < 2.75):
                add_noise_hit(drums, spec, base + step, 0.035, 0.075 if eighth % 2 == 0 else 0.052,
                              "hat", pan=(-0.18 if eighth % 2 else 0.18), salt=100 + bar * 8 + eighth)
        for step in (0.75, 2.25, 2.50):
            if step < final_hole:
                add_noise_hit(drums, spec, base + step, 0.045, 0.085, "seed",
                              pan=(-0.35 if step == 2.25 else 0.35), salt=200 + bar)

        root = (38, 38, 41, 43, 38, 45, 43, 38)[bar]
        riff = ((0.0, root), (0.75, root + 12), (1.5, root + 5), (2.25, root + 10), (3.25, root + 12))
        for step, note in riff:
            if step < final_hole:
                add_voice(bass, spec, base + step, 0.32, note, 0.36, "husk_bass")
        if bar in {1, 2, 5, 6}:
            notes = (62, 65, 69, 67) if bar < 4 else (65, 69, 72, 69)
            for step, note in zip((0.25, 1.25, 2.0, 3.35), notes):
                if step < final_hole:
                    add_voice(hook, spec, base + step, 0.18, note, 0.26, "seed_clav", pan=0.0)
    mix.mix(drums, 0.86)
    mix.mix(bass, 0.92)
    mix.mix(hook, 0.90)
    return mix


def render_explore_amber_circuit(spec: SketchSpec) -> StereoBuffer:
    mix = StereoBuffer(round(spec.duration * RATE))
    pulse = StereoBuffer(mix.frames)
    hook = StereoBuffer(mix.frames)
    texture = StereoBuffer(mix.frames)
    for bar in range(8):
        base = bar * 4.0
        # Deliberately half-time and antiphonal: unlike the funk sketch, each
        # busy cell is answered by open air rather than continuous sixteenths.
        for step in ((0.0, 2.0) if bar not in {3, 7} else (0.0,)):
            add_kick(pulse, spec, base + step, 0.58)
        if bar not in {3, 7}:
            add_noise_hit(pulse, spec, base + 2.0, 0.14, 0.27, "snare", salt=300 + bar)
        for step in ((0.5, 1.5, 2.75) if bar % 2 == 0 else (0.75, 2.5, 3.25)):
            if not (bar in {3, 7} and step > 1.0):
                add_noise_hit(texture, spec, base + step, 0.04, 0.065, "seed",
                              pan=(-0.42 if step < 2 else 0.42), salt=400 + bar)

        cell_a = ((0.0, 62), (0.5, 69), (1.0, 65))
        cell_b = ((2.5, 67), (3.0, 72), (3.5, 69))
        if bar >= 4:
            cell_a = tuple((step, note + (3 if bar in {4, 5} else 0)) for step, note in cell_a)
            cell_b = tuple((step, note + (2 if bar == 6 else 0)) for step, note in cell_b)
        for step, note in cell_a:
            add_voice(hook, spec, base + step, 0.20, note, 0.27, "amber_gate")
        if bar not in {3, 7}:
            for step, note in cell_b:
                add_voice(hook, spec, base + step, 0.18, note, 0.24, "amber_gate")
        if bar in {1, 5}:
            add_chord(texture, spec, base + 1.75, 0.25, (50, 57, 62), 0.20, "dry_chord")
        if bar == 7:
            # Beat 1 onward is intentionally empty before the loop restarts.
            pass
    mix.mix(pulse, 0.88)
    mix.mix(hook, 0.95)
    mix.mix(texture, 0.76)
    return mix


def render_boss_postpunk_dub(spec: SketchSpec) -> StereoBuffer:
    mix = StereoBuffer(round(spec.duration * RATE))
    drums = StereoBuffer(mix.frames)
    drive = StereoBuffer(mix.frames)
    hook = StereoBuffer(mix.frames)
    echo = StereoBuffer(mix.frames)
    roots = (38, 38, 41, 43, 38, 45, 43, 38)
    for bar in range(8):
        base = bar * 4.0
        stop_after = 2.0 if bar == 7 else 2.75 if bar == 3 else 4.0
        for step in (0.0, 2.0):
            if step < stop_after:
                add_kick(drums, spec, base + step, 0.70)
        for step in (1.0, 3.0):
            if step < stop_after:
                add_noise_hit(drums, spec, base + step, 0.13, 0.34, "snare", salt=500 + bar)
        for eighth in range(8):
            step = eighth * 0.5
            if step < stop_after:
                add_noise_hit(drums, spec, base + step, 0.032, 0.074, "hat",
                              pan=(-0.22 if eighth % 2 else 0.22), salt=600 + bar * 8 + eighth)
        root = roots[bar]
        for eighth in range(8):
            step = eighth * 0.5
            if step >= stop_after:
                continue
            note = root + (12 if eighth in {3, 6} else 0) + (5 if eighth == 5 else 0)
            add_voice(drive, spec, base + step, 0.25, note, 0.30, "wire_pick")

        if bar in {1, 2, 5, 6}:
            phrase = (62, 65, 67, 72) if bar < 4 else (65, 67, 72, 69)
            for step, note in zip((0.0, 0.75, 1.5, 2.25), phrase):
                add_voice(hook, spec, base + step, 0.20, note, 0.25, "wire_pick")
        # The effect is an actual finite send with tempo taps, not duplicated
        # dry events presented as "echo".  Nothing is sent in the final bar.
        if bar in {0, 4}:
            add_dub_reply(echo, spec, base + 0.25, (50, 57, 62), 0.28)
        if bar in {2, 6}:
            add_dub_reply(echo, spec, base + 0.50, (53, 60, 65), 0.25)
    mix.mix(drums, 0.87)
    mix.mix(drive, 0.88)
    mix.mix(hook, 0.78)
    mix.mix(echo, 0.86)
    return mix


def render_boss_stoptime_industrial(spec: SketchSpec) -> StereoBuffer:
    mix = StereoBuffer(round(spec.duration * RATE))
    drums = StereoBuffer(mix.frames)
    riff = StereoBuffer(mix.frames)
    metal = StereoBuffer(mix.frames)
    cells = (
        ((0.0, 38), (0.5, 38), (1.0, 41), (2.5, 43), (3.0, 38)),
        ((0.0, 38), (0.5, 45), (1.5, 43), (2.0, 41), (3.5, 38)),
        ((0.0, 41), (0.5, 41), (1.0, 43), (2.75, 45)),
        ((0.0, 38), (0.75, 38), (2.5, 50)),
        ((0.0, 43), (0.5, 43), (1.0, 45), (2.5, 46), (3.0, 43)),
        ((0.0, 43), (0.5, 50), (1.5, 48), (2.0, 46), (3.5, 43)),
        ((0.0, 45), (0.5, 45), (1.0, 48), (2.75, 50)),
        ((0.0, 38), (0.5, 38), (1.0, 50)),
    )
    for bar, cell in enumerate(cells):
        base = bar * 4.0
        for step, note in cell:
            add_voice(riff, spec, base + step, 0.25 if step < 2.0 else 0.32, note, 0.36, "iron_pulse")
            if step in {0.0, 2.5, 2.75}:
                add_kick(drums, spec, base + step, 0.72)
        # Stop-time means percussion follows the written punches; there is no
        # continuous hat carpet covering the rests.
        if bar not in {3, 7}:
            for step in (1.0, 3.0):
                add_noise_hit(drums, spec, base + step, 0.12, 0.34, "snare", salt=700 + bar)
            for step in (0.25, 1.75, 3.5):
                add_noise_hit(drums, spec, base + step, 0.035, 0.060, "hat",
                              pan=(-0.3 if step < 2 else 0.3), salt=800 + bar)
        if bar in {2, 3, 6, 7}:
            for step, note, pan in ((1.5, 74, -0.35), (2.0, 69, 0.35)):
                if not (bar == 7 and step >= 1.5):
                    add_voice(metal, spec, base + step, 0.25, note, 0.18, "rust_bell", pan)
        if bar in {1, 5}:
            add_noise_hit(metal, spec, base + 2.75, 0.18, 0.18, "thud", pan=0.2, salt=900 + bar)
    mix.mix(drums, 0.88)
    mix.mix(riff, 0.90)
    mix.mix(metal, 0.80)
    return mix


RENDERERS = {
    "explore_seed_funk": render_explore_seed_funk,
    "explore_amber_circuit": render_explore_amber_circuit,
    "boss_postpunk_dub": render_boss_postpunk_dub,
    "boss_stoptime_industrial": render_boss_stoptime_industrial,
}


def dc_block(samples: array) -> None:
    previous_input = 0.0
    previous_output = 0.0
    for index, sample in enumerate(samples):
        output = sample - previous_input + 0.995 * previous_output
        samples[index] = output
        previous_input = sample
        previous_output = output


def saturate(buffer: StereoBuffer, drive: float) -> None:
    """Track-local crest shaping; this is not the game's shared music mix."""
    ceiling = math.tanh(drive)
    for channel in (buffer.left, buffer.right):
        for index, sample in enumerate(channel):
            channel[index] = math.tanh(sample * drive) / ceiling


def seal_loop(buffer: StereoBuffer) -> None:
    """Remove inaudible DC-filter residue inside the written final dropout."""
    head = round(0.004 * RATE)
    tail = round(0.040 * RATE)
    for channel in (buffer.left, buffer.right):
        for index in range(head):
            channel[index] *= index / max(1, head - 1)
        for index in range(len(channel) - tail, len(channel)):
            channel[index] = 0.0


def biquad(samples: array, b0: float, b1: float, b2: float, a1: float, a2: float) -> array:
    result = array("f", [0.0]) * len(samples)
    x1 = x2 = y1 = y2 = 0.0
    for index, sample in enumerate(samples):
        output = b0 * sample + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        result[index] = output
        x2, x1 = x1, sample
        y2, y1 = y1, output
    return result


def k_weight(samples: array) -> array:
    # ITU-R BS.1770 K-weighting coefficients at the renderer's fixed 48 kHz.
    stage_one = biquad(samples,
                       1.53512485958697, -2.69169618940638, 1.19839281085285,
                       -1.69065929318241, 0.73248077421585)
    return biquad(stage_one,
                   1.0, -2.0, 1.0,
                   -1.99004745483398, 0.99007225036621)


def integrated_lufs(channels: tuple[array, ...]) -> float:
    weighted = tuple(k_weight(channel) for channel in channels)
    block = round(0.400 * RATE)
    hop = round(0.100 * RATE)
    energies = []
    for start in range(0, len(channels[0]) - block + 1, hop):
        energy = sum(sum(value * value for value in channel[start:start + block]) / block for channel in weighted)
        if -0.691 + 10.0 * math.log10(max(energy, 1e-20)) >= -70.0:
            energies.append(energy)
    if not energies:
        return -120.0
    ungated = -0.691 + 10.0 * math.log10(sum(energies) / len(energies))
    threshold = ungated - 10.0
    gated = [energy for energy in energies if -0.691 + 10.0 * math.log10(max(energy, 1e-20)) >= threshold]
    return -0.691 + 10.0 * math.log10(sum(gated) / len(gated))


def normalize_loudness(buffer: StereoBuffer, target_lufs: float) -> None:
    measured = integrated_lufs((buffer.left, buffer.right))
    gain = 10.0 ** ((target_lufs - measured) / 20.0)
    for channel in (buffer.left, buffer.right):
        for index in range(len(channel)):
            channel[index] *= gain


def quantize(buffer: StereoBuffer) -> tuple[array, array]:
    channels = []
    for source in (buffer.left, buffer.right):
        channels.append(array("f", (round(max(-0.999969, min(0.999969, value)) * 32767.0) / 32767.0 for value in source)))
    return channels[0], channels[1]


def true_peak_db(left: array, right: array) -> float:
    """Conservative four-times cubic inter-sample peak estimate."""
    peak = 0.0
    for channel in (left, right):
        peak = max(peak, max(abs(value) for value in channel))
        for index in range(1, len(channel) - 2):
            p0, p1, p2, p3 = channel[index - 1:index + 3]
            for fraction in (0.25, 0.5, 0.75):
                a = 2.0 * p1
                b = -p0 + p2
                c = 2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3
                d = -p0 + 3.0 * p1 - 3.0 * p2 + p3
                value = 0.5 * (a + b * fraction + c * fraction ** 2 + d * fraction ** 3)
                peak = max(peak, abs(value))
    return 20.0 * math.log10(max(peak, 1e-20))


def longest_dropout_ms(left: array, right: array) -> int:
    window = round(0.050 * RATE)
    longest = current = 0
    for start in range(0, len(left) - window + 1, window):
        energy = sum((left[index] ** 2 + right[index] ** 2) * 0.5 for index in range(start, start + window)) / window
        if 10.0 * math.log10(max(energy, 1e-20)) < -45.0:
            current += 1
            longest = max(longest, current)
        else:
            current = 0
    return longest * 50


def metrics(left: array, right: array) -> dict[str, float | int]:
    stereo_lufs = integrated_lufs((left, right))
    mono = array("f", ((l + r) * 0.5 for l, r in zip(left, right)))
    mono_lufs = integrated_lufs((mono,))
    sample_peak = max(max(abs(value) for value in left), max(abs(value) for value in right))
    seam = max(abs(left[0] - left[-1]), abs(right[0] - right[-1]))
    return {
        "integrated_lufs": round(stereo_lufs, 3),
        # This cubic estimate is deterministic but is not a standards-grade
        # true-peak claim.  The package builder independently runs ffmpeg's
        # oversampled EBU R128 meter and blocks anything above -1 dBTP.
        "cubic_peak_estimate_dbtp": round(true_peak_db(left, right), 3),
        "sample_peak_dbfs": round(20.0 * math.log10(max(sample_peak, 1e-20)), 3),
        "mono_compatibility_loss_db": round(stereo_lufs - mono_lufs - 3.0103, 3),
        "longest_dropout_ms": longest_dropout_ms(left, right),
        "loop_seam_dbfs": round(20.0 * math.log10(max(seam, 1e-20)), 3),
    }


def write_wav(path: Path, left: array, right: array) -> None:
    payload = bytearray(len(left) * 4)
    offset = 0
    for left_value, right_value in zip(left, right):
        struct.pack_into("<hh", payload, offset,
                         round(max(-1.0, min(1.0, left_value)) * 32767.0),
                         round(max(-1.0, min(1.0, right_value)) * 32767.0))
        offset += 4
    with wave.open(str(path), "wb") as target:
        target.setnchannels(2)
        target.setsampwidth(2)
        target.setframerate(RATE)
        target.writeframes(payload)


def render_one(spec: SketchSpec, output: Path) -> dict[str, object]:
    buffer = RENDERERS[spec.key](spec)
    # The circuit and post-punk sketches intentionally use different local
    # saturation stages: a compact VCA-like clamp versus a driven preamp.
    if spec.key == "explore_amber_circuit":
        saturate(buffer, 1.80)
    elif spec.key == "boss_postpunk_dub":
        saturate(buffer, 1.60)
    dc_block(buffer.left)
    dc_block(buffer.right)
    seal_loop(buffer)
    normalize_loudness(buffer, spec.target_lufs)
    left, right = quantize(buffer)
    measured = metrics(left, right)
    path = output / f"{spec.key}.wav"
    write_wav(path, left, right)
    result = {
        **asdict(spec),
        "sample_rate": RATE,
        "channels": 2,
        "duration_seconds": round(len(left) / RATE, 6),
        "wav_sha256": sha256(path),
        "metrics": measured,
    }
    if not 15.0 <= result["duration_seconds"] <= 20.0:
        raise RuntimeError(f"{spec.key}: duration outside sketch range")
    if abs(measured["integrated_lufs"] - spec.target_lufs) > 0.12:
        raise RuntimeError(f"{spec.key}: loudness target missed: {measured['integrated_lufs']}")
    if measured["cubic_peak_estimate_dbtp"] > -1.0:
        raise RuntimeError(f"{spec.key}: deterministic peak estimate exceeds -1 dBTP")
    if measured["longest_dropout_ms"] < 250:
        raise RuntimeError(f"{spec.key}: no meaningful arrangement dropout")
    if measured["mono_compatibility_loss_db"] > 0.8:
        raise RuntimeError(f"{spec.key}: main hook is not mono-safe")
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    assert_official_wavs_unchanged()
    output = resolve_safe_output(args.output)
    staged = Path(tempfile.mkdtemp(prefix=".autumn-direction-stage-", dir=output.parent))
    installed = False
    try:
        tracks = [render_one(spec, staged) for spec in SPECS.values()]
        by_role = {role: [track for track in tracks if track["role"] == role] for role in ("explore", "boss")}
        for role, role_tracks in by_role.items():
            difference = abs(role_tracks[0]["metrics"]["integrated_lufs"] - role_tracks[1]["metrics"]["integrated_lufs"])
            if difference > 0.3:
                raise RuntimeError(f"{role}: role-matched sketches differ by {difference:.3f} LU")

        manifest = {
            "schema_version": "nameless-autumn-direction-sketches/v1",
            "disposition": "direction-only; not game replacement assets",
            "renderer": renderer_identity(),
            "official_wav_scope_fence": OFFICIAL_WAV_SHA256,
            "tracks": tracks,
            "local_ffmpeg_verification": (
                "ffmpeg -nostats -i FILE.wav -filter_complex "
                "ebur128=peak=true:framelog=verbose -f null -"
            ),
        }
        (staged / "manifest.json").write_text(
            json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8",
        )
        (staged / OUTPUT_SENTINEL_NAME).write_text(OUTPUT_SENTINEL, encoding="utf-8")
        assert_official_wavs_unchanged()
        install_owned_render(staged, output)
        installed = True
        assert_official_wavs_unchanged()
        print(json.dumps({"output": str(output), "tracks": tracks}, ensure_ascii=False, indent=2))
    finally:
        if not installed and _lexists(staged):
            shutil.rmtree(staged)


if __name__ == "__main__":
    main()
