"""Extract the #333 folio from the approved b538f93 concept (Pillow + NumPy).

Usage: python tools/split_honey_pause_folio.py CONCEPT.png prototypes/swarm-flight/art
All coordinates below use the unscaled book crop. No lettering, slot or scene
is exported with the page. The atlas contains the original brass/ink artwork.
"""
import argparse
import hashlib
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SOURCE_HASH = "d5c88123d0fee685751f424d40599b634704ad94387f4fbb8f7c8a592255c7ba"


def split(source: Path, output: Path):
    if hashlib.sha256(source.read_bytes()).hexdigest() != SOURCE_HASH:
        raise ValueError("Expected the approved full-size Honey pause concept from #442")
    original = Image.open(source).convert("RGB").crop((82, 95, 655, 914))
    book = original.copy()
    # Repair the printed areas using adjacent unprinted ivory paper. Mirror
    # each join to keep the grain continuous, including underneath the button.
    grain = np.asarray(original.crop((83, 377, 524, 401)))
    yy, xx = np.indices((book.height, book.width))

    def reflected(index, extent):
        return np.minimum(index % (2 * extent), 2 * extent - 1 - index % (2 * extent))

    paper = Image.fromarray(grain[reflected(yy, grain.shape[0]), reflected(xx, grain.shape[1])])
    patches = Image.new("L", book.size)
    erase = ImageDraw.Draw(patches)
    for box in [(95, 60, 359, 98), (88, 112, 360, 192), (88, 194, 527, 210),
                (90, 216, 249, 258), (74, 274, 543, 380), (84, 400, 530, 619),
                (86, 641, 530, 701), (83, 722, 525, 778)]:
        erase.rectangle(box, fill=255)
    book.paste(paper, mask=patches.filter(ImageFilter.GaussianBlur(3)))
    outline = [(12, 797), (12, 720), (12, 710), (11, 699), (14, 694),
               (14, 135), (10, 131), (10, 123), (15, 122), (15, 64),
               (17, 50), (23, 42), (46, 35), (52, 18), (57, 13), (85, 10),
               (90, 12), (100, 34), (526, 38), (556, 64), (559, 71),
               (561, 782), (533, 806), (43, 802), (20, 800)]
    matte = Image.new("L", book.size)
    ImageDraw.Draw(matte).polygon(outline, fill=255)
    # The curled ribbon arches over a small opening above the top edge.
    ImageDraw.Draw(matte).polygon([(81, 33), (86, 18), (94, 33)], fill=0)
    book.putalpha(matte.filter(ImageFilter.GaussianBlur(.65)))
    book.save(output / "honey-pause-folio.webp", quality=94, method=6)

    atlas = Image.new("RGBA", (452, 164))
    brass = original.crop((84, 281, 532, 376))
    green = np.asarray(brass.crop((22, 19, 79, 77)))
    gy, gx = np.indices((brass.height, brass.width))
    fill = Image.fromarray(green[reflected(gy, green.shape[0]), reflected(gx, green.shape[1])])
    cover = Image.new("L", brass.size)
    ImageDraw.Draw(cover).rectangle((78, 17, 382, 76), fill=255)
    brass.paste(fill, mask=cover.filter(ImageFilter.GaussianBlur(2)))
    edge = Image.new("L", brass.size)
    ImageDraw.Draw(edge).rounded_rectangle((2, 3, 442, 88), radius=21, fill=255)
    brass.putalpha(edge.filter(ImageFilter.GaussianBlur(.8)))
    atlas.paste(brass, (0, 0))
    # Recover ink coverage against ivory, so highlighted rows can tint the paper.
    for x, box in [(0, (98, 403, 168, 453)), (72, (98, 476, 168, 526)),
                   (144, (98, 549, 168, 599)), (216, (492, 409, 518, 443))]:
        pix = np.asarray(original.crop(box)).astype(float)
        alpha = np.clip((235 - pix[:, :, 0]) / (235 - 105), 0, 1)
        icon = Image.new("RGBA", (pix.shape[1], pix.shape[0]), "#624320")
        icon.putalpha(Image.fromarray((255 * alpha).astype("uint8")))
        atlas.paste(icon, (x, 100))
    play = original.crop((169, 302, 213, 351))
    alpha = np.clip((np.asarray(play)[:, :, 0].astype(float) - 92) / 125, 0, 1)
    play.putalpha(Image.fromarray((255 * alpha).astype("uint8")))
    atlas.paste(play, (250, 100))
    atlas.save(output / "honey-pause-marks.webp", lossless=True, method=6)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("concept", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    split(args.concept, args.output)
