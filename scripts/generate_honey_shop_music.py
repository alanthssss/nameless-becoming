#!/usr/bin/env python3
"""Render Honey's eight-bar counter dance to a stereo WAV and a game-ready Ogg.

Usage: python3 scripts/generate_honey_shop_music.py --wav /path/to/preview.wav
Add --ogg /path/to/honey_counter.ogg to also encode the runtime asset.
"""

import argparse
import subprocess
from pathlib import Path

from generate_music_variations import (
    RATE, StereoBuffer, TrackSpec, add_bass_hit, add_hat, add_kick, add_noise_hit,
    add_note, add_rim, integrated_lufs, write_wav,
)


SPEC = TrackSpec("honey_counter", 112, 4, 4, 8, 4, "Honey counter dance")
# Each bar gives the bass root, its short reply, and the notes tapped on the counter.
CHANGES = (
    (45, 52, (60, 64)), (43, 50, (59, 62)), (41, 48, (57, 60)), (43, 47, (59, 64)),
    (45, 52, (60, 64)), (48, 43, (60, 67)), (38, 45, (57, 65)), (40, 47, (56, 62)),
)
# (quarter-beat, MIDI pitch, duration in beats). Two jars trade the tune across
# bars; the last answer lands below the first and leaves the downbeat clear.
JARS = (
    ((0.75, 69, .32), (1.25, 64, .16), (1.50, 67, .60)),
    ((0.50, 64, .40), (1.50, 62, .25), (2.75, 67, .48)),
    ((0.75, 69, .32), (1.25, 64, .18), (1.50, 72, .50), (2.50, 69, .23)),
    ((1.00, 67, .45), (2.25, 64, .32), (2.75, 62, .60)),
    ((0.75, 69, .32), (1.25, 64, .16), (1.50, 67, .60), (3.25, 72, .20)),
    ((0.50, 67, .35), (1.50, 64, .25), (2.75, 69, .48)),
    ((0.75, 69, .32), (1.25, 72, .19), (1.50, 74, .48), (2.50, 69, .32)),
    ((0.50, 67, .40), (1.50, 64, .38), (2.50, 59, .58)),
)


def render() -> StereoBuffer:
    buffer = StereoBuffer(round(SPEC.duration * RATE))
    for bar, (root, reply, chord) in enumerate(CHANGES):
        first = bar * 4
        closing = bar == 7
        # A damped downbeat and three walking pickups against the steady feet.
        for beat in ((0, 1, 2) if closing else (0, 1, 2, 3)):
            add_kick(buffer, SPEC, first + beat, .50 if beat % 2 == 0 else .36)
        for beat, pitch, length, gain in (
            (0, root, .57, .45), (.75, root + 12, .18, .29),
            (1.50, reply, .46, .40), (2.25, root, .32, .38),
        ):
            add_bass_hit(buffer, SPEC, first + beat, pitch, gain, length)
        if not closing:
            add_bass_hit(buffer, SPEC, first + 3.50, reply, .32, .33)
        # A wooden counter slap on two and four; the right hand answers offbeat.
        for beat in ((1,) if closing else (1, 3)):
            add_rim(buffer, SPEC, first + beat, .11, bar * 31 + beat, -.13)
            add_noise_hit(buffer, SPEC, first + beat + .025, .072, .12, bar * 53 + beat, .13, "dark")
        for beat in ((.50, 2.50) if closing else (.50, 1.75, 2.50, 3.25)):
            add_note(buffer, SPEC, first + beat, .16, chord[0], .16, "muted", -.28)
            add_note(buffer, SPEC, first + beat + .018, .13, chord[1], .15, "clav", .22)
        for step in range(6 if closing else 8):
            gain = .055 if step % 2 else .022
            add_hat(buffer, SPEC, first + step * .5 + .014, gain, bar * 13 + step, .30)
        if bar in (1, 3, 5):
            add_hat(buffer, SPEC, first + 3.75, .043, 170 + bar, -.29)
        for beat, pitch, length in JARS[bar]:
            side = -.28 if bar % 2 == 0 else .28
            add_note(buffer, SPEC, first + beat, length, pitch, .28, "mallet", side)
            add_note(buffer, SPEC, first + beat, length * .45, pitch - 12, .12, "wood", side)
            add_note(buffer, SPEC, first + beat + .12, length, pitch, .033, "mallet", -side)
    # Match the seasonal pair at mix time. Preserve transient headroom for the till.
    peak = max(max(map(abs, buffer.left)), max(map(abs, buffer.right)))
    scale = min(10 ** ((-18.0 - integrated_lufs(buffer)) / 20), .78 / peak)
    for channel in (buffer.left, buffer.right):
        for i in range(len(channel)):
            channel[i] *= scale
    return buffer


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--wav", type=Path, required=True)
    parser.add_argument("--ogg", type=Path)
    args = parser.parse_args()
    write_wav(args.wav, render())
    if args.ogg:
        subprocess.run([
            "ffmpeg", "-nostdin", "-loglevel", "error", "-y", "-i", str(args.wav),
            "-c:a", "libvorbis", "-q:a", "6", "-metadata", "title=Honey Counter",
            "-metadata", "artist=Honey", str(args.ogg),
        ], check=True)


if __name__ == "__main__":
    main()
