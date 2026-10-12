"""Turn Blender truck renders into pixel-art sprite sheets, one per team colour.

  python tools/compose_trucks.py <render_dir> <out_dir>

Sheet layout: 64 columns (headings) x 3 rows (flat, nose up, nose down), FRAME px each.
"""
import os
import sys
from PIL import Image

HEADINGS = 64
PITCHES = 3
FRAME = 40

TEAMS = {
    "red": [(96, 12, 12), (172, 24, 20), (228, 56, 40), (255, 140, 110)],
    "yellow": [(124, 88, 0), (204, 160, 0), (250, 214, 32), (255, 248, 156)],
    "blue": [(12, 30, 112), (24, 72, 192), (56, 124, 240), (148, 194, 255)],
    "gray": [(64, 64, 70), (124, 124, 132), (184, 184, 192), (236, 236, 242)],
}
# Fixed palette for the non-body parts.
PALETTE = [(16, 16, 18), (44, 44, 48), (90, 90, 96), (150, 150, 150), (210, 210, 205),
           (70, 104, 140), (120, 160, 196), (255, 236, 140)]
OUTLINE = (12, 8, 6, 255)


def nearest(c, pal):
    return min(pal, key=lambda p: (p[0] - c[0]) ** 2 + (p[1] - c[1]) ** 2 + (p[2] - c[2]) ** 2)


def ramp6(anchors):
    """Stretch a dark->light 4-colour ramp to 6 tones."""
    out = []
    for i in range(6):
        u = i * 3 / 5
        a, b = anchors[int(u)], anchors[min(3, int(u) + 1)]
        f = u - int(u)
        out.append(tuple(round(a[k] + (b[k] - a[k]) * f) for k in range(3)))
    return out


def is_body(r, g, b):
    return r - g > 40 and b - g > 40 and abs(r - b) < 50


def convert(im, ramp):
    im = im.convert("RGBA").resize((FRAME, FRAME), Image.BOX)
    px = im.load()
    out = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    po = out.load()
    for y in range(FRAME):
        for x in range(FRAME):
            r, g, b, a = px[x, y]
            if a < 110:
                continue
            if a < 255:  # un-premultiply-ish: edge pixels came from transparent bg
                k = 255.0 / a
                r, g, b = min(255, int(r * k)), min(255, int(g * k)), min(255, int(b * k))
            if is_body(r, g, b):
                lum = max(r, b) / 255.0
                idx = min(5, max(0, int(lum * 6.8) - 1))
                po[x, y] = ramp[idx] + (255,)
            else:
                po[x, y] = nearest((r, g, b), PALETTE) + (255,)
    # 1px dark outline around the silhouette
    res = out.copy()
    pr = res.load()
    for y in range(FRAME):
        for x in range(FRAME):
            if po[x, y][3] != 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < FRAME and 0 <= ny < FRAME and po[nx, ny][3] != 0:
                    pr[x, y] = OUTLINE
                    break
    return res


def main():
    src, dst = sys.argv[1], sys.argv[2]
    os.makedirs(dst, exist_ok=True)
    frames = {}
    for p in range(PITCHES):
        for h in range(HEADINGS):
            frames[(p, h)] = Image.open(os.path.join(src, "frame_p%d_h%02d.png" % (p, h)))
    for team, ramp in TEAMS.items():
        sheet = Image.new("RGBA", (FRAME * HEADINGS, FRAME * PITCHES), (0, 0, 0, 0))
        for (p, h), im in frames.items():
            sheet.paste(convert(im, ramp6(ramp)), (h * FRAME, p * FRAME))
        sheet.save(os.path.join(dst, "truck_%s.png" % team))
        print("wrote", team)


if __name__ == "__main__":
    main()
