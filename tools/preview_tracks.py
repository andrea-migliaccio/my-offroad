"""Quick layout check for assets/tracks.json: draws every track and reports clearance.

  python tools/preview_tracks.py [out.png]
"""
import json
import math
import sys
from PIL import Image, ImageDraw

HW = 15
MIN_GAP = 2 * HW + 8


def catmull(points, steps=24):
    n = len(points)
    out = []
    for i in range(n):
        p0, p1, p2, p3 = points[i - 1], points[i], points[(i + 1) % n], points[(i + 2) % n]
        for s in range(steps):
            t = s / steps
            t2, t3 = t * t, t * t * t
            out.append(tuple(0.5 * ((2 * p1[k]) + (-p0[k] + p2[k]) * t + (2 * p0[k] - 5 * p1[k] + 4 * p2[k] - p3[k]) * t2
                                   + (-p0[k] + 3 * p1[k] - 3 * p2[k] + p3[k]) * t3) for k in range(2)))
    return out


def resample(poly, ds=2.0):
    pts = poly + [poly[0]]
    out = [pts[0]]
    acc = 0.0
    for a, b in zip(pts, pts[1:]):
        seg = math.dist(a, b)
        while acc + seg >= ds:
            u = (ds - acc) / seg
            a = (a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * u)
            out.append(a)
            seg = math.dist(a, b)
            acc = 0.0
        acc += seg
    return out


def main():
    data = json.load(open("assets/tracks.json"))
    sheet = Image.new("RGB", (320 * 4, 240 * 2), (0, 0, 0))
    for ti, tr in enumerate(data["tracks"]):
        s = resample(catmull(tr["points"]))
        n = len(s)
        L = n * 2.0
        worst = 1e9
        skip = int(60 / 2)
        for i in range(0, n, 2):
            for j in range(0, n, 2):
                dd = min(abs(i - j), n - abs(i - j))
                if dd > skip:
                    worst = min(worst, math.dist(s[i], s[j]))
        # curvature: min radius via three-point circle
        min_r = 1e9
        for i in range(n):
            a, b, c = s[i - 4], s[i], s[(i + 4) % n]
            ab, bc, ca = math.dist(a, b), math.dist(b, c), math.dist(c, a)
            area = abs((b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])) / 2
            if area > 1e-6:
                min_r = min(min_r, ab * bc * ca / (4 * area))
        xs = [p[0] for p in s]
        ys = [p[1] for p in s]
        ok = "OK " if worst >= MIN_GAP and min_r > HW else "BAD"
        print(f"{ok} {tr['name']:16s} len={L:6.0f} gap={worst:5.1f} minR={min_r:5.1f} x=[{min(xs):.0f},{max(xs):.0f}] y=[{min(ys):.0f},{max(ys):.0f}]")
        im = Image.new("RGB", (320, 240), (40, 30, 20))
        d = ImageDraw.Draw(im)
        d.rectangle((0, 0, 319, 38), fill=(60, 60, 70))
        for p in s:
            d.ellipse((p[0] - HW, p[1] - HW, p[0] + HW, p[1] + HW), fill=(176, 112, 56))
        cols = {"jump": (255, 255, 255), "hill": (255, 200, 0), "bumps": (200, 80, 200), "mud": (60, 30, 10), "water": (40, 90, 200)}
        for f in tr["features"]:
            c = int(f["t"] * n) % n
            half = int(f.get("len", 30) / 4)
            for k in range(c - half, c + half):
                p = s[k % n]
                d.ellipse((p[0] - 4, p[1] - 4, p[0] + 4, p[1] + 4), fill=cols[f["type"]])
        st = s[int(tr["start_t"] * n) % n]
        d.rectangle((st[0] - 2, st[1] - HW, st[0] + 2, st[1] + HW), fill=(0, 255, 0))
        nxt = s[(int(tr["start_t"] * n) + 8) % n]
        d.line((st[0], st[1], nxt[0], nxt[1]), fill=(255, 0, 0), width=2)
        d.text((4, 4), tr["name"], fill=(255, 255, 255))
        sheet.paste(im, ((ti % 4) * 320, (ti // 4) * 240))
    sheet.save(sys.argv[1] if len(sys.argv) > 1 else "_render/tracks_preview.png")


if __name__ == "__main__":
    main()
