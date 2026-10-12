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


def scale2x(im):
    """EPX / Scale2x: doubles size, rounding diagonals instead of making blocks."""
    w, h = im.size
    src = im.load()
    out = Image.new("RGBA", (w * 2, h * 2))
    dst = out.load()

    def P(x, y):
        return src[min(w - 1, max(0, x)), min(h - 1, max(0, y))]
    for y in range(h):
        for x in range(w):
            p, a, b, c, d = P(x, y), P(x, y - 1), P(x + 1, y), P(x - 1, y), P(x, y + 1)
            e0 = a if (c == a and c != d and a != b) else p
            e1 = b if (a == b and a != c and b != d) else p
            e2 = c if (d == c and d != b and c != a) else p
            e3 = d if (b == d and b != a and d != c) else p
            dst[2 * x, 2 * y], dst[2 * x + 1, 2 * y], dst[2 * x, 2 * y + 1], dst[2 * x + 1, 2 * y + 1] = e0, e1, e2, e3
    return out


def scale3x(im):
    """AdvMAME3x / Scale3x."""
    w, h = im.size
    src = im.load()
    out = Image.new("RGBA", (w * 3, h * 3))
    dst = out.load()

    def P(x, y):
        return src[min(w - 1, max(0, x)), min(h - 1, max(0, y))]
    for y in range(h):
        for x in range(w):
            A, B, C = P(x - 1, y - 1), P(x, y - 1), P(x + 1, y - 1)
            D, E, F = P(x - 1, y), P(x, y), P(x + 1, y)
            G, Hh, I = P(x - 1, y + 1), P(x, y + 1), P(x + 1, y + 1)
            o = [E] * 9
            if B != Hh and D != F:
                o[0] = D if D == B else E
                o[1] = B if (D == B and E != C) or (B == F and E != A) else E
                o[2] = F if B == F else E
                o[3] = D if (D == B and E != G) or (D == Hh and E != A) else E
                o[5] = F if (B == F and E != I) or (Hh == F and E != C) else E
                o[6] = D if D == Hh else E
                o[7] = Hh if (D == Hh and E != I) or (Hh == F and E != G) else E
                o[8] = F if Hh == F else E
            for k in range(9):
                dst[3 * x + k % 3, 3 * y + k // 3] = o[k]
    return out


def strip(frames):
    w = max(f.width for f in frames)
    h = max(f.height for f in frames)
    im = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        im.paste(f, (i * w, 0))
    return im


def main():
    os.makedirs(OUT, exist_ok=True)
    # Track sprites at 2x, menu art at 3x (960x540 build).
    scale2x(draw(MONEY)).save(f"{OUT}/money.png")
    scale2x(draw(NITRO)).save(f"{OUT}/nitro.png")
    draw(NITRO).save(f"{OUT}/nitro_small.png")
    scale3x(draw(TROPHY)).save(f"{OUT}/trophy.png")
    scale2x(draw(FLAME)).save(f"{OUT}/flame.png")
    scale2x(draw(PUFF)).save(f"{OUT}/puff.png")
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
    strip([scale2x(f) for f in frames]).save(f"{OUT}/flagman.png")
    strip([scale3x(draw(i)) for i in (ICON_NITRO, ICON_TIRES, ICON_SHOCKS, ICON_ACCEL, ICON_SPEED)]).save(
        f"{OUT}/shop_icons.png")
    # Icon used by Godot (64x64): red truck frame upscaled.
    try:
        sheet = Image.open(f"{OUT}/truck_red.png")
        fr = sheet.crop((40 * 8, 0, 40 * 9, 40)).resize((80, 80), Image.NEAREST).crop((8, 8, 72, 72))
        fr.save("icon.png")
    except FileNotFoundError:
        pass
    print("pixel art written")


if __name__ == "__main__":
    main()
