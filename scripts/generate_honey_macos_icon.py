"""Build the Honey ICNS from its painted source. Requires macOS, iconutil and Pillow."""
from pathlib import Path
import subprocess
import tempfile

from PIL import Image, ImageDraw


PROJECT = Path(__file__).resolve().parents[1] / "prototypes" / "swarm-flight"
CANVAS_SIZE = 1024
TILE_SIZE = 824
CORNER_RADIUS = 185


def make_icon(source):
    art = source.convert("RGBA")
    # Remove the painted transparent surround before applying the macOS silhouette.
    bounds = art.getchannel("A").point(lambda alpha: 255 if alpha >= 128 else 0).getbbox()
    tile = art.crop(bounds).resize((TILE_SIZE, TILE_SIZE), Image.Resampling.LANCZOS)
    opaque = Image.new("RGB", tile.size, (17, 58, 37))
    opaque.paste(tile, mask=tile.getchannel("A"))

    supersample = 3
    mask_size = TILE_SIZE * supersample
    mask = Image.new("L", (mask_size, mask_size))
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, mask_size - 1, mask_size - 1), CORNER_RADIUS * supersample, fill=255
    )
    inset = (CANVAS_SIZE - TILE_SIZE) // 2
    icon = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE))
    icon.paste(opaque, (inset, inset), mask.resize(tile.size, Image.Resampling.LANCZOS))
    return icon


def main():
    with Image.open(PROJECT / "icon.png") as source:
        icon = make_icon(source)
    with tempfile.TemporaryDirectory() as directory:
        iconset = Path(directory) / "Honey.iconset"
        iconset.mkdir()
        for points in (16, 32, 128, 256, 512):
            for density, suffix in ((1, ""), (2, "@2x")):
                pixels = points * density
                image = icon.resize((pixels, pixels), Image.Resampling.LANCZOS)
                image.save(iconset / f"icon_{points}x{points}{suffix}.png")
        subprocess.run(
            ["iconutil", "-c", "icns", str(iconset), "-o", str(PROJECT / "honey-macos.icns")],
            check=True,
        )


if __name__ == "__main__":
    main()
