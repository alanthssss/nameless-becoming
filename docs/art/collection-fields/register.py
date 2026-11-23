"""Register the painted shoreline to the existing collision guide. Authoring only.

Run with Pillow, NumPy and SciPy. Coordinates in the JSON are pairs of
destination and source landmarks on an 824 x 477 preview of the full world.
"""
import json
from pathlib import Path

import numpy as np
from PIL import Image
from scipy.interpolate import RBFInterpolator
from scipy.ndimage import label

ART = Path(__file__).resolve().parent
GAME_ART = ART.parents[2] / "prototypes" / "swarm-flight" / "art"
GUIDE_SIZE = np.array([824.0, 477.0])


def register(region):
    source = Image.open(ART / f"{region}-source.png").convert("RGB")
    width, height = source.size
    scale = np.array([width, height]) / GUIDE_SIZE
    coords = np.asarray(json.loads((ART / f"{region}-registration.json").read_text()))
    # Pin the outside water/woodland to the canvas so shoreline corrections
    # cannot fold the last columns beyond the painted panorama.
    border = [[824, y, 824, y] for y in range(20, 470, 30)]
    coords = np.vstack([coords, border])
    offsets = coords[:, 2:] - coords[:, :2]
    warp = RBFInterpolator(coords[:, :2], offsets, kernel="thin_plate_spline", smoothing=2)
    xs = list(range(0, width, 16)) + [width]
    ys = list(range(0, height, 16)) + [height]
    grid = np.stack(np.meshgrid(xs, ys), axis=-1).astype(float)
    samples = grid + warp(grid.reshape(-1, 2) / scale).reshape(grid.shape) * scale
    samples[:, 0, 0] = samples[0, :, 1] = 0
    samples[:, -1, 0] = width
    samples[-1, :, 1] = height
    samples = np.clip(samples, [0, 0], [width - 0.01, height - 0.01])
    horizontal = np.diff(samples, axis=1)[:-1]
    vertical = np.diff(samples, axis=0)[:, :-1]
    area = horizontal[..., 0] * vertical[..., 1] - horizontal[..., 1] * vertical[..., 0]
    if np.any(area <= 0):
        raise ValueError(f"Folded registration mesh in {region}")
    mesh = []
    for row, (top, bottom) in enumerate(zip(ys, ys[1:])):
        for col, (left, right) in enumerate(zip(xs, xs[1:])):
            quad = samples[[row, row + 1, row + 1, row], [col, col, col + 1, col + 1]]
            mesh.append(((left, top, right, bottom), tuple(quad.ravel())))
    aligned = source.transform(source.size, Image.Transform.MESH, mesh, Image.Resampling.BICUBIC)
    aligned.save(GAME_ART / f"collection-{region}.webp", quality=94, method=6)



def extract_blossoms():
    sheet = Image.open(ART / "blossoms-source.png").convert("RGBA")
    half = sheet.width // 2
    for i, name in enumerate(["blue", "violet"]):
        tile = sheet.crop((i * half, 0, (i + 1) * half, sheet.height))
        components, _ = label(np.asarray(tile.getchannel("A")) > 96)
        sizes = np.bincount(components.ravel())
        sizes[0] = 0
        rows, cols = np.where(components == sizes.argmax())
        tile = tile.crop((int(cols.min()) - 3, int(rows.min()) - 3,
                          int(cols.max()) + 4, int(rows.max()) + 4))
        tile.thumbnail((160, 160), Image.Resampling.LANCZOS)
        tile.save(GAME_ART / f"collection-{name}-bloom.webp", lossless=True, method=6)


if __name__ == "__main__":
    extract_blossoms()
    for name in ["pond", "meadow"]:
        register(name)
