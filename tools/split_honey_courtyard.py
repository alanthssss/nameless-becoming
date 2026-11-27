"""Separate the approved #427 panorama into a game plate, registered paint and props.

Run with the full-size 1586x992 final panorama as input and art/ as output.
Registration coordinates are in the playable 1280x800 viewport. Pinning them
here keeps the scale hanger, sheets and visitor independent of game resolution.
Requires Pillow, NumPy and OpenCV. No game save or RNG is involved.
"""
import argparse
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw


def extract(input_path: Path, output: Path):
    art = Image.open(input_path).convert("RGB")
    assert art.size == (1586, 992), "Expected the approved full-size panorama"
    sx, sy = art.width / 1280, art.height / 800
    raw = np.array(art)
    base = raw.copy()

    def point(x, y):
        return round(x * sx), round(y * sy)

    def mask(shape):
        matte = Image.new("L", art.size)
        ImageDraw.Draw(matte).polygon([point(x, y) for x, y in shape], fill=255)
        return matte

    def feather(matte, radius):
        return cv2.GaussianBlur(np.array(matte), (0, 0), radius * sx)[:, :, None] / 255

    def layer(matte, replacement, radius=0.6):
        alpha = feather(matte, radius)
        base[:] = (base * (1 - alpha) + replacement * alpha).astype(np.uint8)

    # Reconstruct the shop wall and its horizontal counter grain from adjacent
    # wood in the same picture. The rooted post and its single upper hook remain.
    yy, xx = np.indices(base.shape[:2])
    x, y = xx / sx, yy / sy
    def sample(px, py):
        return cv2.remap(raw, (px*sx).astype("float32"), (py*sy).astype("float32"), cv2.INTER_LINEAR)
    wood_x = 315 + 18*np.sin(x*.030 + y*.007)
    wood = sample(wood_x, y)
    # Across the narrow rod the unpainted back wall continues from both sides.
    wall_high, wall_low = sample(wood_x, y*0 + 424), sample(wood_x, y*0 + 445)
    t = np.clip((y-424)/21,0,1)[:,:,None]
    band = (y >= 424) & (y <= 445)
    wood[band] = (wall_high*(1-t)+wall_low*t)[band]
    for contour, radius in [
        ([(247,419),(257,419),(258,433),(249,436),(245,430)], .8),
        ([(241,427),(414,424),(414,440),(241,445)], 1.25),
        ([(249,435),(257,435),(276,462),(284,469),(285,482),(288,485),
          (293,489),(289,496),(254,499),(233,495),(222,486),(220,477),
          (226,465)], 2.4),
        ([(368,435),(381,435),(383,447),(391,453),(394,474),(400,478),
          (397,485),(355,485),(354,472),(357,455),(365,445)], 2.2),
    ]:
        layer(mask(contour), wood, radius)
    # Continue the water from the clear right-hand half under the original
    # baked frog. The runtime visitor can now be either species on each visit.
    frog_mask = mask([(62,680),(72,673),(82,671),(88,668),(103,667),
                     (110,672),(117,674),(116,686),(110,691),(116,695),
                     (115,701),(93,705),(75,703),(63,697)])
    water = sample(133 - (x-90)*.32, 680 + (y-684)*.69 - (x-90)*.11)
    layer(frog_mask, water, 1.9)
    # Put the visit's second stone where the frog used to be. Its source is
    # the other stone in this bowl, with a lower silhouette and cooler tone.
    stone = [(43,669),(46,664),(50,661),(58,658),(65,659),(71,662),
             (74,666),(75,671),(72,675),(65,678),(53,679),(46,677),(42,674)]
    stone_mask = np.array(mask(stone))
    warp = np.float32([[.85,0,point(88-.85*59,0)[0]],[0,.69,point(0,689-.69*669)[1]]])
    stone_paint = cv2.warpAffine(raw,warp,art.size)
    stone_paint = np.clip(stone_paint*[.83,.94,.94],0,255)
    layer(cv2.warpAffine(stone_mask,warp,art.size),stone_paint,.55)
    # The player and attendants own flight; clear the concept's little sky bee.
    sky_bee = np.zeros(raw.shape[:2],np.uint8)
    cv2.ellipse(sky_bee, point(1009,158), point(20,21), 0, 0, 360, 255, -1)
    base[:] = cv2.inpaint(base, sky_bee, 4 * sx, cv2.INPAINT_TELEA)

    # The sheet and stone are one detachable illustrated layer. Dark wood
    # underneath its curl comes from the tray's own lower rail.
    sheet = [(703,356),(878,359),(882,355),(891,350),(903,349),(913,352),
             (917,357),(917,364),(914,370),(888,445),(881,463),
             (873,469),(859,472),(841,472),(642,461)]
    grain = sample(315 + 21*np.sin(x*.023), 477 + 9*np.sin(y*.07+x*.002))
    layer(mask(sheet), np.clip(grain*[.39,.31,.27], 0, 255), .65)
    Image.fromarray(base).save(output / "honey-inner-courtyard.webp", quality=94, method=6)

    # Keep illustrated contours and pigment grain when swapping which brush
    # stroke carries teal. Both strokes retain the texture of the original.
    sheet_mask = mask(sheet)
    sheet_box = (*point(640,347), *point(920,474))
    colors = raw.astype(np.float32)
    red, green, blue = colors.transpose(2, 0, 1)
    primary = np.clip((green-red+5)/32, 0, 1)
    secondary = np.clip((red-green-13)/31, 0, 1)
    x, y = xx/sx, yy/sy
    primary *= (x > 706) & (x < 894) & (y > 371) & (y < 427)
    secondary *= (x > 743) & (x < 845) & (y > 404) & (y < 458)
    paper_zone = ((x > 658) & (x < 910) & (y > 356) & (y < 468))
    paper = np.clip((green-155)/38, 0, 1)*np.clip((34-abs(red-green))/16, 0, 1)*paper_zone
    for name, main, second in [
        ("pond", [-12, 3, 22], [0, -3, 1]),
        ("meadow", [36, -40, 13], [-38, 27, 22])
    ]:
        rgb = colors + paper[:,:,None]*[-4,-1,8]
        rgb += primary[:,:,None]*main + secondary[:,:,None]*second
        patch = Image.fromarray(rgb.clip(0,255).astype(np.uint8)).convert("RGBA")
        patch.putalpha(sheet_mask)
        patch.crop(sheet_box).save(output / f"honey-flight-sheet-{name}.webp", lossless=True, method=6)

    # Drawn at their registered scale in a single small transparent atlas.
    # Tuples contain target atlas positions and source silhouettes.
    parts = [
        ((0,0), (225,463,283,493), [(227,470),(232,467),(238,465),(243,464),(252,465),(259,464),(267,465),(271,468),(278,469),(281,475),(276,482),(264,489),(251,492),(239,489),(229,482),(226,476)]),
        ((65,0), (359,448,389,478), [(367,451),(373,448),(380,450),(385,454),(388,463),(385,471),(380,475),(370,476),(364,473),(360,467),(360,459),(363,454)]),
        ((104,0), (200,374,230,403), [(205,383),(212,378),(220,377),(225,379),(228,385),(227,393),(222,399),(212,402),(205,399),(202,393),(203,387)]),
        ((145,0), (223,325,264,360), [(230,328),(239,326),(251,327),(256,329),(256,333),(262,338),(259,341),(255,343),(257,348),(254,354),(249,358),(235,358),(229,355),(227,350),(229,342),(223,341),(225,336),(230,333)]),
    ]
    atlas = Image.new("RGBA",(208,40))
    for destination, bounds, shape in parts:
        # Supersample the output silhouettes at the native painting scale.
        component = art.convert("RGBA")
        component.putalpha(mask(shape))
        x1,y1,x2,y2 = bounds
        cut = component.crop((*point(x1,y1),*point(x2,y2)))
        atlas.paste(cut.resize((x2-x1,y2-y1),Image.Resampling.LANCZOS),destination)
    atlas.save(output / "honey-steelyard-goods.webp", lossless=True, method=6)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("panorama", type=Path)
    parser.add_argument("art_directory", type=Path)
    args = parser.parse_args()
    extract(args.panorama, args.art_directory)
