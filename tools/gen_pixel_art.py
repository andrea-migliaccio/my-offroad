"""Hand-drawn pixel art (as ASCII maps) -> PNGs in assets/sprites.

  python tools/gen_pixel_art.py
"""
import os
from PIL import Image

OUT = "assets/sprites"

PAL = {
    ".": None,
    "k": (12, 8, 6),        # outline
    "w": (240, 240, 240),
    "g": (150, 150, 150),
    "d": (90, 90, 96),
    "r": (220, 40, 30),
    "R": (140, 20, 16),
    "y": (250, 214, 32),
    "Y": (190, 140, 10),
    "b": (60, 120, 230),
    "B": (24, 60, 150),
    "G": (40, 190, 70),
    "e": (20, 110, 40),
    "s": (232, 176, 128),   # skin
    "S": (176, 116, 72),
    "t": (170, 120, 60),    # bag
    "T": (110, 72, 34),
    "o": (240, 150, 40),
    "c": (90, 200, 240),
}

MONEY = """
...kkkk...
..kTttTk..
...kTTk...
..kttttk..
.kttyyttk.
kttyttyttk
ktttyytttk
ktttttyttk
kttyyyyttk
.kttTTttk.
..kkkkkk..
"""

NITRO = """
...kkk...
..kgwgk..
.kkkkkkk.
kbcbbbbBk
kbcbwbbBk
kbcwwwbBk
kbcbwbbBk
kbcbbbbBk
kbcbbbbBk
kBBBBBBBk
.kkkkkkk.
"""

# Flagman: 14x22 frames. Flag colour placeholder 'f' (filled per variant).
FLAG_DOWN = """
..............
.....kkkk.....
....kssssk....
....ksksks....
....kssssk....
.....kssk.....
....kwwwwk....
...kwwwwwwk...
..kswwwwwwsk..
..ksdwwwwdsk..
..ksdwwwwdsk..
..kfkwwwwkfk..
..kfkwwwwkfk..
..kffkkkkffk..
...k.kddk.kk..
.....kddk.....
.....kddk.....
.....kdkdk....
.....kdkdk....
.....kdkdk....
....kkkkkkk...
..............
"""

FLAG_UP = """
kkkkkk........
kffffkk.......
kfffffk.......
kfffffkkkkk...
kkkkkkkssssk..
.....kksksks..
......kssssk..
......kkssk...
......kwwwwk..
.....kwwwwwwk.
.....kwwwwwwsk
.....kdwwwwdsk
.....kdwwwwdsk
.....kkwwwwkk.
......kwwwwk..
......kkddk...
.......kddk...
.......kddk...
.......kdkdk..
.......kdkdk..
......kkkkkkk.
..............
"""

FLAG_WAVE = """
..............
.kkkkkk.......
.kffffkk......
.kfffffkkkkk..
.kffffkkssssk.
.kkkkkksksksk.
......kssssk..
......kkssk...
......kwwwwk..
.....kwwwwwwk.
.....kwwwwwwsk
.....kdwwwwdsk
.....kdwwwwdsk
.....kkwwwwkk.
......kwwwwk..
......kkddk...
.......kddk...
.......kddk...
.......kdkdk..
.......kdkdk..
......kkkkkkk.
..............
"""

TROPHY = """
..kkkkkkkkkk..
.kyyyyyyyyyYk.
kkyyywyyyyyYkk
kykyywyyyyyYky
kykyywyyyyyYky
.kkyyyyyyyyYk.
...kyyyyyyYk..
....kyyyyYk...
.....kyyYk....
......kYk.....
......kYk.....
.....kyyYk....
...kkkkkkkk...
...kTTTTTTk...
...kttttttk...
...kkkkkkkk...
"""

ICON_TIRES = """
....kkkkkk....
..kkddddddkk..
.kddkkkkkkddk.
.kdk......kdk.
kdk..kkkk..kdk
kdk.kggggk.kdk
kdk.kgwwgk.kdk
kdk.kgwwgk.kdk
kdk.kggggk.kdk
kdk..kkkk..kdk
.kdk......kdk.
.kddkkkkkkddk.
..kkddddddkk..
....kkkkkk....
"""

ICON_SHOCKS = """
.....kkkk.....
.....kggk.....
....kkwwkk....
....kggggk....
...kkkkkkkk...
....kyk.......
.....kyk......
....kyk.......
.....kyk......
....kyk.......
.....kyk......
...kkkkkkkk...
....kggggk....
.....kkkk.....
"""

ICON_ACCEL = """
..............
....kkkkkk....
..kkggggggkk..
.kgggwgggwggk.
.kggggggggggk.
kgwgggggrgggwk
kggggggrggggk.
kggggkrgggggk.
kgggkkkgggggk.
kgwgkkkggggwk.
.kggggggggggk.
..kkkkkkkkkk..
..............
..............
"""

ICON_SPEED = """
..............
..........kk..
.........kyyk.
..kkkkk.kyyk..
.......kyyk...
.kkkkk.kyyyyk.
.......kkyyk..
..kkkk..kyyk..
.......kyyk...
.kkkkk.kyk....
.......kk.....
..............
..............
..............
"""

ICON_NITRO = """
.....kkkk.....
....kgwwgk....
...kkkkkkkk...
...kbcbbbBk...
...kbcbbbBk...
...kbcbwbBk...
...kbcwwwBk...
...kbcbwbBk...
...kbcbbbBk...
...kbcbbbBk...
...kbcbbbBk...
...kBBBBBBk...
...kkkkkkkk...
..............
"""

FLAME = """
..kk....
.koyk...
koyywkk.
koyywwwk
koyywkk.
.koyk...
..kk....
"""

PUFF = """
.ww.
wwgw
wggw
.ww.
"""


def draw(art, extra=None):
    rows = [r for r in art.strip("\n").split("\n")]
    w = max(len(r) for r in rows)
    im = Image.new("RGBA", (w, len(rows)), (0, 0, 0, 0))
    pal = dict(PAL)
    if extra:
        pal.update(extra)
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            c = pal.get(ch)
            if c:
                im.putpixel((x, y), c + (255,))
    return im


def strip(frames):
    w = max(f.width for f in frames)
    h = max(f.height for f in frames)
    im = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        im.paste(f, (i * w, 0))
    return im


def main():
    os.makedirs(OUT, exist_ok=True)
    draw(MONEY).save(f"{OUT}/money.png")
    draw(NITRO).save(f"{OUT}/nitro.png")
    draw(TROPHY).save(f"{OUT}/trophy.png")
    draw(FLAME).save(f"{OUT}/flame.png")
    draw(PUFF).save(f"{OUT}/puff.png")
    # Flagman: down, up(green), wave(green), up(white), wave(white), up(checker), wave(checker)
    green = {"f": (40, 190, 70)}
    white = {"f": (240, 240, 240)}
    checker_up = draw(FLAG_UP, white)
    checker_wave = draw(FLAG_WAVE, white)
    for im in (checker_up, checker_wave):
        for y in range(im.height):
            for x in range(im.width):
                if im.getpixel((x, y)) == (240, 240, 240, 255) and y < 6 and x < 7:
                    if (x + y) % 2:
                        im.putpixel((x, y), (20, 20, 20, 255))
    frames = [draw(FLAG_DOWN, {"f": (220, 40, 30)}), draw(FLAG_UP, {"f": (220, 40, 30)}),
              draw(FLAG_UP, green), draw(FLAG_WAVE, green),
              draw(FLAG_UP, white), draw(FLAG_WAVE, white),
              checker_up, checker_wave]
    strip(frames).save(f"{OUT}/flagman.png")
    strip([draw(ICON_NITRO), draw(ICON_TIRES), draw(ICON_SHOCKS), draw(ICON_ACCEL), draw(ICON_SPEED)]).save(
        f"{OUT}/shop_icons.png")
    # Icon used by Godot (64x64): red truck frame upscaled.
    try:
        sheet = Image.open(f"{OUT}/truck_red.png")
        fr = sheet.crop((24 * 4, 0, 24 * 5, 24)).resize((64, 64), Image.NEAREST)
        fr.save("icon.png")
    except FileNotFoundError:
        pass
    print("pixel art written")


if __name__ == "__main__":
    main()
