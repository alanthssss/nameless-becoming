#!/usr/bin/env python3
"""Measure the rendered music loops and write a durable audition report.

The analyzer intentionally uses only Python's standard library so the objective
checks do not depend on a workstation DAW.  It samples 64 Hann-windowed FFTs per
track, which is sufficient for regression gates without pretending to replace
human listening.
"""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import math
import struct
import sys
import wave
from array import array
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MUSIC = ROOT / "godot" / "assets" / "music"
OUTPUT = MUSIC / "analysis.json"
FFT_SIZE = 4096
FFT_WINDOWS = 64
WINDOW = tuple(0.5 - 0.5 * math.cos(math.tau * index / (FFT_SIZE - 1)) for index in range(FFT_SIZE))
THRESHOLDS = {
    "sample_rate": 44_100,
    "channels": 2,
    "max_loop_seam_dbfs": -50.0,
    "max_low_mid_share": 0.70,
    "max_low_mid_occupancy": 0.80,
    "min_spectral_centroid_hz": 350.0,
    "min_active_dynamic_range_db": 3.0,
    "min_autumn_dropout_ms": 750,
    "max_stereo_correlation": 0.995,
    "max_same_season_cosine": 0.92,
}


def load_specs():
    path = ROOT / "scripts" / "generate_music_variations.py"
    module_spec = importlib.util.spec_from_file_location("music_generator", path)
    if module_spec is None or module_spec.loader is None:
        raise RuntimeError(f"cannot import {path}")
    module = importlib.util.module_from_spec(module_spec)
    sys.modules[module_spec.name] = module
    module_spec.loader.exec_module(module)
    return module.TRACKS


def percentile(values: list[float], percent: float) -> float:
    if not values:
        return 0.0
    ordered = sorted(values)
    position = (len(ordered) - 1) * percent / 100.0
    lower = int(position)
    upper = min(len(ordered) - 1, lower + 1)
    fraction = position - lower
    return ordered[lower] * (1.0 - fraction) + ordered[upper] * fraction


def fft_power(samples: list[float]) -> list[float]:
    """Iterative radix-2 FFT; only the real-signal positive spectrum is returned."""
    size = len(samples)
    values = [complex(samples[index] * WINDOW[index], 0.0) for index in range(size)]
    target = 0
    for index in range(1, size):
        bit = size >> 1
        while target & bit:
            target ^= bit
            bit >>= 1
        target ^= bit
        if index < target:
            values[index], values[target] = values[target], values[index]
    length = 2
    while length <= size:
        angle = -math.tau / length
        root = complex(math.cos(angle), math.sin(angle))
        half = length // 2
        for start in range(0, size, length):
            twiddle = 1.0 + 0.0j
            for offset in range(half):
                even = values[start + offset]
                odd = values[start + offset + half] * twiddle
                values[start + offset] = even + odd
                values[start + offset + half] = even - odd
                twiddle *= root
        length <<= 1
    return [value.real * value.real + value.imag * value.imag for value in values[:size // 2 + 1]]


def read_pcm(path: Path) -> tuple[int, int, array, array]:
    with wave.open(str(path), "rb") as source:
        rate = source.getframerate()
        channels = source.getnchannels()
        width = source.getsampwidth()
        frames = source.getnframes()
        payload = source.readframes(frames)
    if width != 2 or channels != 2:
        raise ValueError(f"{path.name}: expected stereo 16-bit PCM")
    interleaved = array("h")
    interleaved.frombytes(payload)
    if struct.pack("=h", 1) != struct.pack("<h", 1):
        interleaved.byteswap()
    left = array("f", (interleaved[index] / 32768.0 for index in range(0, len(interleaved), 2)))
    right = array("f", (interleaved[index] / 32768.0 for index in range(1, len(interleaved), 2)))
    return rate, channels, left, right


def correlation(left: array, right: array) -> float:
    count = len(left)
    left_mean = sum(left) / count
    right_mean = sum(right) / count
    covariance = left_energy = right_energy = 0.0
    for left_value, right_value in zip(left, right):
        left_delta = left_value - left_mean
        right_delta = right_value - right_mean
        covariance += left_delta * right_delta
        left_energy += left_delta * left_delta
        right_energy += right_delta * right_delta
    return covariance / max(1e-20, math.sqrt(left_energy * right_energy))


def active_dynamic_range(mono: array, rate: int) -> float:
    window = max(1, round(rate * 0.4))
    hop = max(1, round(rate * 0.2))
    levels: list[float] = []
    for start in range(0, len(mono) - window + 1, hop):
        energy = sum(value * value for value in mono[start:start + window]) / window
        level = 10.0 * math.log10(max(energy, 1e-20))
        if level > -50.0:
            levels.append(level)
    return percentile(levels, 95.0) - percentile(levels, 10.0)


def longest_dropout_ms(left: array, right: array, rate: int) -> int:
    """Measure consecutive 50 ms windows below -45 dBFS."""
    window = max(1, round(rate * 0.050))
    longest = current = 0
    for start in range(0, len(left) - window + 1, window):
        energy = sum(
            (left[index] * left[index] + right[index] * right[index]) * 0.5
            for index in range(start, start + window)
        ) / window
        if 10.0 * math.log10(max(energy, 1e-20)) < -45.0:
            current += 1
            longest = max(longest, current)
        else:
            current = 0
    return longest * 50


def analyze_track(path: Path, spec) -> tuple[dict[str, float | int | str], list[float]]:
    rate, channels, left, right = read_pcm(path)
    frames = len(left)
    mono = array("f", ((left[index] + right[index]) * 0.5 for index in range(frames)))
    sum_square = sum(value * value for value in left) + sum(value * value for value in right)
    rms = math.sqrt(sum_square / (frames * 2))
    peak = max(max(abs(value) for value in left), max(abs(value) for value in right))
    seam = max(abs(left[0] - left[-1]), abs(right[0] - right[-1]))

    available = max(0, frames - FFT_SIZE)
    positions = [round(index * available / max(1, FFT_WINDOWS - 1)) for index in range(FFT_WINDOWS)]
    spectra: list[list[float]] = []
    frame_rms: list[float] = []
    for start in positions:
        frame = list(mono[start:start + FFT_SIZE])
        spectra.append(fft_power(frame))
        frame_rms.append(math.sqrt(sum(value * value for value in frame) / FFT_SIZE))
    average = [sum(spectrum[index] for spectrum in spectra) / len(spectra) for index in range(FFT_SIZE // 2 + 1)]
    frequencies = [index * rate / FFT_SIZE for index in range(len(average))]

    audible = [index for index, frequency in enumerate(frequencies) if 20.0 <= frequency <= 10_000.0]
    low_mid = [index for index, frequency in enumerate(frequencies) if 40.0 <= frequency < 250.0]
    high = [index for index, frequency in enumerate(frequencies) if 1_000.0 <= frequency <= 10_000.0]
    total_energy = sum(average[index] for index in audible)
    low_mid_energy = sum(average[index] for index in low_mid)
    high_energy = sum(average[index] for index in high)
    centroid = sum(frequencies[index] * average[index] for index in audible) / max(1e-20, total_energy)
    cumulative = 0.0
    rolloff = frequencies[audible[-1]]
    for index in audible:
        cumulative += average[index]
        if cumulative >= total_energy * 0.85:
            rolloff = frequencies[index]
            break

    occupied = 0
    for spectrum, level in zip(spectra, frame_rms):
        spectrum_total = sum(spectrum[index] for index in audible)
        ratio = sum(spectrum[index] for index in low_mid) / max(1e-20, spectrum_total)
        low_rms = level * math.sqrt(ratio)
        if 20.0 * math.log10(max(low_rms, 1e-20)) > -35.0:
            occupied += 1

    log_edges = [2.0 ** (math.log2(30.0) + index / 24.0) for index in range(round((math.log2(8000.0) - math.log2(30.0)) * 24) + 1)]
    vector: list[float] = []
    for lower, upper in zip(log_edges, log_edges[1:]):
        vector.append(math.sqrt(sum(average[index] for index, frequency in enumerate(frequencies) if lower <= frequency < upper)))
    norm = math.sqrt(sum(value * value for value in vector))
    vector = [value / max(1e-20, norm) for value in vector]

    expected_frames = round(spec.duration * rate)
    result: dict[str, float | int | str] = {
        "source_sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        "sample_rate": rate,
        "channels": channels,
        "frames": frames,
        "expected_frames": expected_frames,
        "duration_seconds": round(frames / rate, 6),
        "bpm": spec.bpm,
        "meter": f"{spec.numerator}/{spec.denominator}",
        "bars": spec.bars,
        "style": spec.description,
        "rms_dbfs": round(20.0 * math.log10(max(rms, 1e-20)), 3),
        "peak_dbfs": round(20.0 * math.log10(max(peak, 1e-20)), 3),
        "crest_db": round(20.0 * math.log10(max(peak / max(rms, 1e-20), 1e-20)), 3),
        "active_dynamic_range_db": round(active_dynamic_range(mono, rate), 3),
        "longest_dropout_ms": longest_dropout_ms(left, right, rate),
        "spectral_centroid_hz": round(centroid, 3),
        "rolloff_85_hz": round(rolloff, 3),
        "low_mid_40_250_share": round(low_mid_energy / max(1e-20, total_energy), 5),
        "high_1k_10k_share": round(high_energy / max(1e-20, total_energy), 5),
        "low_mid_occupancy": round(occupied / len(spectra), 5),
        "stereo_correlation": round(correlation(left, right), 5),
        "loop_seam_dbfs": round(20.0 * math.log10(max(seam, 1e-6)), 3),
    }
    return result, vector


def cosine(first: list[float], second: list[float]) -> float:
    return sum(left * right for left, right in zip(first, second))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=OUTPUT)
    args = parser.parse_args()
    specs = load_specs()
    tracks: dict[str, dict[str, float | int | str]] = {}
    vectors: dict[str, list[float]] = {}
    failures: list[str] = []
    for name, spec in specs.items():
        metrics, vector = analyze_track(MUSIC / f"{name}.wav", spec)
        tracks[name] = metrics
        vectors[name] = vector
        if metrics["sample_rate"] != THRESHOLDS["sample_rate"]:
            failures.append(f"{name}: sample rate")
        if metrics["channels"] != THRESHOLDS["channels"]:
            failures.append(f"{name}: channels")
        if metrics["frames"] != metrics["expected_frames"]:
            failures.append(f"{name}: not an integer-bar render")
        if metrics["loop_seam_dbfs"] > THRESHOLDS["max_loop_seam_dbfs"]:
            failures.append(f"{name}: loop seam")
        if metrics["low_mid_40_250_share"] > THRESHOLDS["max_low_mid_share"]:
            failures.append(f"{name}: low-mid energy")
        if metrics["low_mid_occupancy"] > THRESHOLDS["max_low_mid_occupancy"]:
            failures.append(f"{name}: continuous low-mid occupancy")
        if metrics["spectral_centroid_hz"] < THRESHOLDS["min_spectral_centroid_hz"]:
            failures.append(f"{name}: spectral centroid")
        if metrics["active_dynamic_range_db"] < THRESHOLDS["min_active_dynamic_range_db"]:
            failures.append(f"{name}: active dynamic range")
        if name.startswith("autumn_") and metrics["longest_dropout_ms"] < THRESHOLDS["min_autumn_dropout_ms"]:
            failures.append(f"{name}: missing four-bar reset dropout")
        if metrics["stereo_correlation"] > THRESHOLDS["max_stereo_correlation"]:
            failures.append(f"{name}: effectively mono")

    similarities: dict[str, float] = {}
    for season in ("spring", "summer", "autumn", "winter"):
        similarity = cosine(vectors[f"{season}_explore"], vectors[f"{season}_incident"])
        similarities[season] = round(similarity, 5)
        if similarity > THRESHOLDS["max_same_season_cosine"]:
            failures.append(f"{season}: explore/incident spectrum too similar")

    report = {
        "method": "64 sampled 4096-point Hann FFTs; automated regression evidence, not a listening verdict",
        "thresholds": THRESHOLDS,
        "tracks": tracks,
        "same_season_explore_incident_cosine": similarities,
        "passed": not failures,
        "failures": failures,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    for name, metrics in tracks.items():
        print(
            f"{name:15s} low={metrics['low_mid_40_250_share']:.3f} "
            f"occupancy={metrics['low_mid_occupancy']:.3f} "
            f"centroid={metrics['spectral_centroid_hz']:.0f}Hz "
            f"seam={metrics['loop_seam_dbfs']:.1f}dBFS"
        )
    print("same-season cosine:", " ".join(f"{name}={value:.3f}" for name, value in similarities.items()))
    if failures:
        for failure in failures:
            print("FAIL", failure)
        raise SystemExit(1)
    try:
        output_label = args.output.relative_to(ROOT)
    except ValueError:
        output_label = args.output
    print(f"MUSIC ANALYSIS PASSED -> {output_label}")


if __name__ == "__main__":
    main()
